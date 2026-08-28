package chipyard.crypto.chacha_poly_aead

import chisel3._
import chisel3.util._
import chisel3.util.HasBlackBoxResource

import org.chipsalliance.cde.config.{Field, Parameters, Config}
import freechips.rocketchip.diplomacy._
import freechips.rocketchip.prci._
import freechips.rocketchip.regmapper._
import freechips.rocketchip.subsystem._
import freechips.rocketchip.tilelink._
import freechips.rocketchip.devices.tilelink._
import freechips.rocketchip.util._

// =============================================================================
// Fused ChaCha20-Poly1305 AEAD accelerator -- Chipyard MMIO peripheral.
//
// Core: AEAD_chacha_poly.v, a sequencer wrapped around the same chacha_core and
// poly1305_core this repo already carries. The whole RFC 8439 construction runs
// in hardware: the one-time key is taken from ChaCha20 block 0, the message is
// encrypted from block 1, and the MAC absorbs AAD, ciphertext and the trailing
// le64(len AAD) || le64(len CT) block without firmware assembling any of it.
//
// The sub-modules are byte-identical to the copies inside chacha.preprocessed.v
// and poly1305.preprocessed.v, so those two files are pulled in as-is rather
// than duplicated. Because the resource paths match the ones CHACHATL and
// POLYTL use, a design carrying this peripheral and the separate ChaCha/Poly
// peripherals still sees each module defined exactly once.
//
// Everything the CPU sees is 32 bits wide, and every byte string travels in
// hex-string order (bit 31 of word 0 is byte 0).
//
// Operating sequence, from firmware:
//
//   1. pulse rst_core                            zeroes `in`, arms the core
//   2. write key, nonce, encrypt                 operands; encrypt latches at init
//   3. pulse init, wait ready                    derives the Poly1305 one-time key
//   4. per AAD block: write aad + block_len,     absorbs one 16-byte AAD block
//      pulse next, wait ready
//   5. write in + block_len, pulse finish,       leaves the AAD phase and runs
//      wait ready, read out                      the FIRST data block
//   6. per later block: write in + block_len,    runs one more data block
//      pulse next, wait ready, read out
//   7. pulse finish, wait ready, read mac        absorbs the lengths, emits the tag
//
// Two sequencing requirements come out of the RTL and are easy to get wrong:
//
//   - `in` must read zero when init is pulsed. AEAD_chacha_poly.v is missing a
//     begin/end around its state_init branch, so `chacha_input <= plain_text`
//     executes unconditionally and the key-generation pass XORs whatever `in`
//     holds into ChaCha20 block 0 -- which is where the Poly1305 one-time key
//     comes from. Hence the rst_core pulse in step 1, and hence this wrapper
//     clearing `in` while rst_core is asserted, matching the original wrapper.
//
//   - `block_len` must already hold the FIRST data block's length when the
//     step 5 finish is pulsed, because the state it lands in latches the block
//     count and advances the length counter straight away.
//
// The core has no path back from its terminal state, so one AEAD operation
// needs one rst_core pulse. That suits the requirement above anyway.
//
// One more note for anyone tempted to tidy the RTL. AEAD_chacha_poly.v has a
// second missing begin/end, around valid_block at lines 347-349, and that one
// must be left as it is: adding the begin/end makes valid_block latch, the
// per-block MAC loop terminates early, and every multi-block message gets a
// wrong tag. A single-block message still passes, so it fails quietly. Both
// variants were run against tests/chachapoly_aead_tb.cpp; the state_init fix
// passes, the valid_block fix does not.
// ==============================================================================

case class ChachaPolyAeadParams(
  address: BigInt,
  version: Int = 1
)

case object ChachaPolyAeadKey extends Field[Option[ChachaPolyAeadParams]](None)

class chacha_poly_aead_core extends BlackBox with HasBlackBoxResource {
  override def desiredName = "AEAD_chacha_poly"

  val io = IO(new Bundle {
    val clk          = Input(Clock())
    val reset_n      = Input(Bool())
    val init_aead    = Input(Bool())
    val next_aead    = Input(Bool())
    val finish_aead  = Input(Bool())
    val encrypt_aead = Input(Bool())   

    val key        = Input(UInt(256.W))
    val iv         = Input(UInt(96.W))
    val AAD        = Input(UInt(128.W))
    val block_len  = Input(UInt(7.W))
    val plain_text = Input(UInt(512.W))

    val ready       = Output(Bool())
    val cipher_text = Output(UInt(512.W))
    val tag         = Output(UInt(128.W))
  })

  addResource("/crypto-vsrc/chachapoly/AEAD_chacha_poly.v")
  addResource("/crypto-vsrc/chachapoly/chacha.preprocessed.v")
  addResource("/crypto-vsrc/chachapoly/poly1305.preprocessed.v")
}

class ChachaPolyAeadTL(params: ChachaPolyAeadParams, beatBytes: Int)(implicit p: Parameters)
    extends ClockSinkDomain(ClockSinkParameters())(p) {

  val device = new SimpleDevice("chacha-poly-aead", Seq("uec,chacha-poly-aead-0"))
  val node = TLRegisterNode(
    Seq(AddressSet(params.address, 4096 - 1)),
    device,
    "reg/control",
    beatBytes = beatBytes
  )

  override lazy val module = new ChachaPolyAeadImpl

  class ChachaPolyAeadImpl extends Impl {
    withClockAndReset(clock, reset) {

      val key   = Reg(Vec(8, UInt(32.W)))    // key(0) = bytes 0..3
      val aad   = Reg(Vec(4, UInt(32.W)))
      val nonce = Reg(Vec(3, UInt(32.W)))
      val in    = Reg(Vec(16, UInt(32.W)))

      val rstCoreN = RegInit(true.B)
      val encrypt  = RegInit(false.B)
      val blockLen = RegInit(0.U(7.W))

      /* Driven straight from the bus write, so each is a single-cycle pulse. */
      val initPulse   = WireInit(false.B)
      val nextPulse   = WireInit(false.B)
      val finishPulse = WireInit(false.B)

      val core = Module(new chacha_poly_aead_core)
      core.io.clk     := clock
      core.io.reset_n := rstCoreN

      core.io.key        := Cat(key)      // key(0) lands in [255:224]
      core.io.iv         := Cat(nonce)
      core.io.AAD        := Cat(aad)
      core.io.plain_text := Cat(in)
      core.io.block_len  := blockLen

      core.io.init_aead    := initPulse
      core.io.next_aead    := nextPulse
      core.io.finish_aead  := finishPulse
      core.io.encrypt_aead := encrypt

      /* Clearing `in` under reset is what guarantees the core's key-generation
       * pass sees a zero plaintext -- see the header note. */
      when (!rstCoreN) {
        in.foreach { r => r := 0.U }
      }

      val ready = RegNext(core.io.ready, false.B)

      val outWords = (0 until 16).map { i => core.io.cipher_text(511 - 32 * i, 480 - 32 * i) }
      val macWords = (0 until 4).map { i => core.io.tag(127 - 32 * i, 96 - 32 * i) }

      node.regmap(
        ChachaPolyAeadRegs.key -> RegFieldGroup("key", Some("Key, 8 x 32-bit, hex-string order"),
          key.zipWithIndex.map { case (r, i) =>
            RegField(32, r, RegFieldDesc(s"key_$i", s"key bytes ${4 * i}..${4 * i + 3}"))
          }),

        ChachaPolyAeadRegs.aad -> RegFieldGroup("aad", Some("One 16-byte AAD block, zero-padded"),
          aad.zipWithIndex.map { case (r, i) =>
            RegField(32, r, RegFieldDesc(s"aad_$i", s"aad bytes ${4 * i}..${4 * i + 3}"))
          }),

        ChachaPolyAeadRegs.nonce -> RegFieldGroup("nonce", Some("Nonce, 3 x 32-bit, hex-string order"),
          nonce.zipWithIndex.map { case (r, i) =>
            RegField(32, r, RegFieldDesc(s"nonce_$i", s"nonce bytes ${4 * i}..${4 * i + 3}"))
          }),

        ChachaPolyAeadRegs.in -> RegFieldGroup("in", Some("One 64-byte data block, hex-string order"),
          in.zipWithIndex.map { case (r, i) =>
            RegField(32, r, RegFieldDesc(s"in_$i", s"data bytes ${4 * i}..${4 * i + 3}"))
          }),

        ChachaPolyAeadRegs.rst_core -> Seq(
          RegField(1, rstCoreN, RegFieldDesc("rst_core_n", "Active-low core reset; also clears `in`"))),

        ChachaPolyAeadRegs.init -> Seq(
          RegField.w(1, initPulse, RegFieldDesc("init", "Write 1 to pulse init_aead"))),

        ChachaPolyAeadRegs.next -> Seq(
          RegField.w(1, nextPulse, RegFieldDesc("next", "Write 1 to pulse next_aead"))),

        ChachaPolyAeadRegs.finish -> Seq(
          RegField.w(1, finishPulse, RegFieldDesc("finish", "Write 1 to pulse finish_aead"))),

        ChachaPolyAeadRegs.block_len -> Seq(
          RegField(7, blockLen, RegFieldDesc("block_len", "Valid bytes in this block, 1..64"))),

        ChachaPolyAeadRegs.ready -> Seq(
          RegField.r(1, ready, RegFieldDesc("ready", "1 = idle", volatile = true))),

        ChachaPolyAeadRegs.encrypt -> Seq(
          RegField(1, encrypt, RegFieldDesc("encrypt", "1 = encrypt, 0 = decrypt; latched at init"))),

        ChachaPolyAeadRegs.out_lo -> RegFieldGroup("out_lo", Some("Output block words 0..1"),
          outWords.take(2).zipWithIndex.map { case (w, i) =>
            RegField.r(32, w, RegFieldDesc(s"out_$i", s"output bytes ${4 * i}..${4 * i + 3}", volatile = true))
          }),

        ChachaPolyAeadRegs.out_hi -> RegFieldGroup("out_hi", Some("Output block words 2..15"),
          outWords.drop(2).zipWithIndex.map { case (w, i) =>
            RegField.r(32, w, RegFieldDesc(s"out_${i + 2}", s"output bytes ${4 * (i + 2)}..${4 * (i + 2) + 3}", volatile = true))
          }),

        ChachaPolyAeadRegs.mac -> RegFieldGroup("mac", Some("Tag, 4 x 32-bit, hex-string order"),
          macWords.zipWithIndex.map { case (w, i) =>
            RegField.r(32, w, RegFieldDesc(s"mac_$i", s"tag bytes ${4 * i}..${4 * i + 3}", volatile = true))
          })
      )
    }
  }
}

object ChachaPolyAeadID {
  val nextId = {
    var i = -1; () => { i += 1; i }
  }
}

trait CanHavePeripheryChachaPolyAead { this: BaseSubsystem =>
  private val portName = s"chacha_poly_aead_${ChachaPolyAeadID.nextId()}"

  val chachaPolyAead = p(ChachaPolyAeadKey) match {
    case Some(params) => {
      val a = LazyModule(new ChachaPolyAeadTL(params, pbus.beatBytes))
      a.suggestName(portName)

      a.clockNode := pbus.fixedClockNode
      pbus.coupleTo(portName) { a.node := TLFragmenter(pbus.beatBytes, pbus.blockBytes) := _ }

      Some(a)
    }
    case None => None
  }
}

class WithCHACHAPOLYAEAD(address: BigInt) extends Config((site, here, up) => {
  case ChachaPolyAeadKey => {
    println(f"Setting ChaCha20-Poly1305 AEAD address: 0x${address}%X")
    Some(ChachaPolyAeadParams(address = address))
  }
})
