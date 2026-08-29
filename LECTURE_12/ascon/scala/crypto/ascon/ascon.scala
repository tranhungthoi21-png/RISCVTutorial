package chipyard.crypto.ascon

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

case class ASCONParams(
  address: BigInt,
  version: Int = 1
)

case object ASCONKey extends Field[Option[ASCONParams]](None)

class ascon_engine_std extends BlackBox with HasBlackBoxResource {
  override def desiredName: String = "ascon_engine_std"

  val io = IO(new Bundle {
    val clk_i  = Input(Clock())
    val rst_ni = Input(Bool())     // active LOW

    val start_i         = Input(Bool())
    val mode_i          = Input(UInt(3.W))
    val data_in_i       = Input(UInt(64.W))
    val data_in_valid_i = Input(Bool())
    val last_block_i    = Input(Bool())
    val last_bytes_i    = Input(UInt(4.W))
    val phase_sel_i     = Input(Bool())
    val exp_tag_i       = Input(UInt(128.W))
    val out_len_i       = Input(UInt(11.W))

    val data_out_o       = Output(UInt(64.W))
    val data_out_valid_o = Output(Bool())
    val data_in_ready_o  = Output(Bool())
    val busy_o           = Output(Bool())
    val done_o           = Output(Bool())
    val hash_o           = Output(UInt(256.W))
    val tag_valid_o      = Output(Bool())
    val auth_fail_o      = Output(Bool())
  })

  addResource("/crypto-vsrc/ascon_std/ascon_engine_std.sv")
  addResource("/crypto-vsrc/ascon_std/ascon_ctrl_std.sv")
  addResource("/crypto-vsrc/ascon_std/ascon_dp_std.sv")
  addResource("/crypto-vsrc/ascon_std/ascon_defs_std.svh")
  addResource("/crypto-vsrc/ascon_std/asconp.v")
}

class ASCONTL(params: ASCONParams, beatBytes: Int)(implicit p: Parameters)
    extends ClockSinkDomain(ClockSinkParameters())(p) {

  val device = new SimpleDevice("ascon", Seq("nist,ascon-sp800-232"))
  val node = TLRegisterNode(
    Seq(AddressSet(params.address, 4096 - 1)),
    device,
    "reg/control",
    beatBytes = beatBytes
  )

  override lazy val module = new ASCONImpl

  class ASCONImpl extends Impl {
    withClockAndReset(clock, reset) {

      val nOut = ASCONParamsConst.outWords

      /* A write of 1 sets the register; it clears itself the cycle after, so
       * the engine sees exactly a one-cycle pulse regardless of bus timing. */
      def pulseReg(): Bool = {
        val r = RegInit(false.B)
        when (r) { r := false.B }
        r
      }

      val mode   = RegInit(0.U(3.W))
      val outLen = RegInit(0.U(11.W))
      val inWord = Reg(Vec(2, UInt(32.W)))   // inWord(0) = data_in[31:0]
      val expTag = Reg(Vec(4, UInt(32.W)))   // expTag(0) = exp_tag[127:96]

      val startPulse = pulseReg()
      val validPulse = pulseReg()

      /* Latched alongside the valid pulse by the same in_ctrl write, so they
       * are already stable when the engine samples data_in_valid. */
      val lastBlock = RegInit(false.B)
      val lastBytes = RegInit(0.U(4.W))
      val phaseSel  = RegInit(false.B)

      val core = Module(new ascon_engine_std)
      core.io.clk_i  := clock
      core.io.rst_ni := !reset.asBool

      core.io.start_i         := startPulse
      core.io.mode_i          := mode
      core.io.data_in_i       := Cat(inWord(1), inWord(0))
      /* A blind one-cycle valid pulse loses the word whenever data_in_ready has
       * fallen between the driver's poll and the arrival of its register write,
       * which is several bus cycles later. Hold valid until the engine actually
       * takes it, so the transfer is a real valid/ready handshake and cannot
       * depend on bus timing. */
      val inPending = RegInit(false.B)
      when (validPulse) { inPending := true.B }
      when (inPending && core.io.data_in_ready_o) {
        inPending := false.B
        /* Drop the qualifiers with the word. Leaving last_block asserted lets
         * a later phase's first word be mistaken for a final block, ending the
         * operation early. */
        lastBlock := false.B
        lastBytes := 0.U
        phaseSel  := false.B
      }

      core.io.data_in_valid_i := inPending
      core.io.last_block_i    := lastBlock
      core.io.last_bytes_i    := lastBytes
      core.io.phase_sel_i     := phaseSel
      core.io.exp_tag_i       := Cat(expTag)
      core.io.out_len_i       := outLen

      /* Sticky flags: done_o and the auth results are single-cycle, which MMIO
       * polling would miss. Cleared by the next start. */
      val doneSticky = RegInit(false.B)
      val tagSticky  = RegInit(false.B)
      val authSticky = RegInit(false.B)

      when (core.io.done_o)      { doneSticky := true.B }
      when (core.io.tag_valid_o) { tagSticky  := true.B }
      when (core.io.auth_fail_o) { authSticky := true.B }

      /* Output capture. The squeeze loop free-runs, so every valid word is
       * latched here and read back at the CPU's leisure. */
      val outBuf = Reg(Vec(nOut, UInt(64.W)))
      val outPtr = RegInit(0.U(log2Ceil(nOut + 1).W))
      val outOvf = RegInit(false.B)

      when (core.io.data_out_valid_o) {
        when (outPtr < nOut.U) {
          outBuf(outPtr) := core.io.data_out_o
          outPtr := outPtr + 1.U
        } .otherwise {
          outOvf := true.B
        }
      }

      when (startPulse) {
        doneSticky := false.B
        tagSticky  := false.B
        authSticky := false.B
        outPtr     := 0.U
        outOvf     := false.B
      }

      /* Report ready only when the previous word has been consumed, so firmware
       * never overwrites a word still waiting to be handed over. */
      val inReady = core.io.data_in_ready_o && !inPending

      val status = Cat(
        outOvf, authSticky, tagSticky,
        inReady, doneSticky, core.io.busy_o)

      val hashWords = (0 until 8).map { i => core.io.hash_o(255 - 32 * i, 224 - 32 * i) }
      val outWordsFlat = (0 until 2 * nOut).map { i =>
        if (i % 2 == 0) outBuf(i / 2)(63, 32) else outBuf(i / 2)(31, 0)
      }

      node.regmap(
        ASCONRegs.ctrl -> Seq(
          RegField.w(1, startPulse, RegFieldDesc("start", "Write 1 to pulse start_i"))),

        ASCONRegs.mode -> Seq(
          RegField(3, mode, RegFieldDesc("mode", "0=ENC 1=DEC 2=HASH 3=XOF 4=CXOF"))),

        ASCONRegs.out_len -> Seq(
          RegField(11, outLen, RegFieldDesc("out_len", "Output length in 64-bit blocks"))),

        ASCONRegs.status -> Seq(
          RegField.r(6, status, RegFieldDesc("status", "See ASCONStatus", volatile = true))),

        ASCONRegs.out_count -> Seq(
          RegField.r(log2Ceil(nOut + 1), outPtr,
            RegFieldDesc("out_count", "Output words captured since start", volatile = true))),

        ASCONRegs.in_lo -> Seq(
          RegField(32, inWord(0), RegFieldDesc("in_lo", "data_in[31:0], bytes 0..3 little-endian"))),

        ASCONRegs.in_hi -> Seq(
          RegField(32, inWord(1), RegFieldDesc("in_hi", "data_in[63:32], bytes 4..7 little-endian"))),

        ASCONRegs.in_ctrl -> Seq(
          RegField.w(1, validPulse, RegFieldDesc("valid", "Write 1 to pulse data_in_valid_i")),
          RegField(1, lastBlock,    RegFieldDesc("last_block", "Final block of this phase")),
          RegField(4, lastBytes,    RegFieldDesc("last_bytes", "Valid bytes in the final block, 0..8")),
          RegField(1, phaseSel,     RegFieldDesc("phase_sel", "Phase select, see the engine"))),

        ASCONRegs.exp_tag -> RegFieldGroup("exp_tag", Some("Expected tag for decrypt, 4 x 32-bit"),
          expTag.zipWithIndex.map { case (r, i) =>
            RegField(32, r, RegFieldDesc(s"exp_tag_$i", s"exp_tag bits ${127 - 32 * i}..${96 - 32 * i}"))
          }),

        ASCONRegs.hash -> RegFieldGroup("hash", Some("hash_o, 8 x 32-bit"),
          hashWords.zipWithIndex.map { case (w, i) =>
            RegField.r(32, w, RegFieldDesc(s"hash_$i", s"hash_o bits ${255 - 32 * i}..${224 - 32 * i}",
                                           volatile = true))
          }),

        ASCONRegs.out -> RegFieldGroup("out", Some(s"Captured output stream, $nOut x 64-bit"),
          outWordsFlat.zipWithIndex.map { case (w, i) =>
            RegField.r(32, w, RegFieldDesc(s"out_$i", s"output word ${i / 2} " +
                                           (if (i % 2 == 0) "upper" else "lower"), volatile = true))
          })
      )
    }
  }
}

object ASCONID {
  val nextId = {
    var i = -1; () => { i += 1; i }
  }
}

trait CanHavePeripheryASCON { this: BaseSubsystem =>
  private val portName = s"ascon_${ASCONID.nextId()}"

  val ascon = p(ASCONKey) match {
    case Some(params) => {
      val a = LazyModule(new ASCONTL(params, pbus.beatBytes))
      a.suggestName(portName)

      a.clockNode := pbus.fixedClockNode
      pbus.coupleTo(portName) { a.node := TLFragmenter(pbus.beatBytes, pbus.blockBytes) := _ }

      Some(a)
    }
    case None => None
  }
}

class WithASCON(address: BigInt) extends Config((site, here, up) => {
  case ASCONKey => {
    println(f"Setting ASCON (SP 800-232) address: 0x${address}%X")
    Some(ASCONParams(address = address))
  }
})
