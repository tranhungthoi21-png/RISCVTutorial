package chipyard.crypto.ascon

// Register map for the standard ASCON accelerator (4 KB window).
//
// Backs ascon_engine_std, which implements the four NIST SP 800-232 algorithms:
// Ascon-AEAD128 (as separate encrypt and decrypt modes), Ascon-Hash256,
// Ascon-XOF128 and Ascon-CXOF128.
//
// Every field is 32 bits, which is what keeps the map valid on an RV32 pbus:
// RegMapper rejects a field crossing a `beatBytes * 8` word boundary and pbus
// beatBytes is XLen/8.
//
// BYTE ORDER IS LITTLE-ENDIAN. Byte 0 of a message sits in bits [7:0] of the
// engine's 64-bit data_in, and the digest in hash_o is packed the same way.
// See the byte-order note in ascon.scala.
object ASCONRegs {
  val ctrl      = 0x00 // W1  bit0 = start pulse
  val mode      = 0x04 // RW  [2:0], see ASCONMode
  val out_len   = 0x08 // RW  [10:0] output length in 64-bit blocks
  val status    = 0x0C // RO  see ASCONStatus
  val out_count = 0x10 // RO  number of output words captured since start

  val in_lo   = 0x14 // RW  data_in[31:0]  = message bytes 0..3, little-endian
  val in_hi   = 0x18 // RW  data_in[63:32] = message bytes 4..7, little-endian
  val in_ctrl = 0x1C // W1  bit0 = valid pulse, bit1 = last_block,
                     //     bits[5:2] = last_bytes, bit6 = phase_sel

  val exp_tag = 0x20 // RW  4 x 32: expected tag for decrypt, little-endian
  val hash    = 0x40 // RO  8 x 32: hash_o[255:0], hash(0) = hash_o[255:224]

  // Captured output stream: 16 x 64-bit words as 32 x 32-bit registers.
  // out(2k) is the upper half of word k, out(2k+1) the lower half.
  val out = 0x100
}

object ASCONStatus {
  val busy        = 0x01
  val done        = 0x02 // sticky: set on done_o, cleared by the next start
  val inReady     = 0x04 // engine can accept a data_in word this cycle
  val tagValid    = 0x08 // sticky
  val authFail    = 0x10 // sticky: decrypt tag mismatch
  val outOverflow = 0x20 // more output words produced than the buffer holds
}

// mode_i encoding, from ascon_defs_std.svh. AEAD is split into two modes
// because the engine needs to know at init whether it is verifying a tag.
object ASCONMode {
  val enc  = 0 // Ascon-AEAD128 encrypt
  val dec  = 1 // Ascon-AEAD128 decrypt (checks exp_tag, reports auth_fail)
  val hash = 2 // Ascon-Hash256
  val xof  = 3 // Ascon-XOF128
  val cxof = 4 // Ascon-CXOF128
}

object ASCONParamsConst {
  // Depth of the wrapper's output capture buffer, in 64-bit words. The engine's
  // squeeze loop does not back-pressure -- it permutes and emits a word per
  // iteration regardless of whether anything is reading -- so the wrapper
  // captures the stream into this buffer for the CPU to collect afterwards.
  val outWords = 16
}
