package chipyard.crypto.chacha_poly_aead

// Register map for the fused ChaCha20-Poly1305 AEAD accelerator (4 KB window).
//
// Offsets are carried over unchanged from the TEE-hardware wrapper this was
// ported from, so software written against that map still works. Every field is
// 32 bits, which is what makes the map valid on an RV32 pbus: RegMapper rejects
// a field crossing a `beatBytes * 8` word boundary and pbus beatBytes is XLen/8.
//
// Byte order is "hex string order" throughout -- word[i] is the big-endian load
// of bytes[4i..4i+3]. Both embedded cores byte-swap internally (ChaCha20's
// l2b(), Poly1305's le()), so RFC 8439 byte strings pass through unreversed.
//
// Note the discontinuity in the output block: out_0/out_1 sit at 0x198/0x19C
// and then out_2 restarts at 0x200. That gap is inherited, not a typo.
object ChachaPolyAeadRegs {
  val key    = 0x100  // RW  8 x 32: key bytes 0..31
  val aad    = 0x120  // RW  4 x 32: one 16-byte AAD block, zero-padded by firmware
  val nonce  = 0x130  // RW  3 x 32: nonce bytes 0..11
  val in     = 0x13C  // RW 16 x 32: one 64-byte data block

  val rst_core  = 0x17C // RW  active-low core reset; also zeroes `in`
  val init      = 0x180 // W1  pulse init_aead
  val next      = 0x184 // W1  pulse next_aead
  val finish    = 0x188 // W1  pulse finish_aead
  val block_len = 0x18C // RW  valid bytes in this block, 1..64
  val ready     = 0x190 // RO  1 = idle
  val encrypt   = 0x194 // RW  1 = encrypt, 0 = decrypt; latched at init

  val out_lo = 0x198  // RO  out_0, out_1
  val out_hi = 0x200  // RO  out_2 .. out_15
  val mac    = 0x238  // RO  4 x 32: tag bytes 0..15
}
