/*
 * Bare-metal driver for the standard ASCON accelerator (ascon_engine_std).
 *
 * SoC config : SmallRocket32AsconArty100TConfig, peripheral at 0x64008000.
 *
 * Implements the four NIST SP 800-232 algorithms: Ascon-AEAD128,
 * Ascon-Hash256, Ascon-XOF128 and Ascon-CXOF128, with the SP 800-232 IVs.
 * Empty message, empty AD and empty plaintext are all supported, as the
 * standard requires.
 *
 * BYTE ORDER IS LITTLE-ENDIAN. Message byte 0 goes into bits [7:0] of the
 * engine's 64-bit data_in, and the digest comes back packed the same way.
 * X25519, ChaCha20 and Poly1305 in this tree use the opposite "hex string"
 * order; mixing them up yields a wrong digest rather than an error.
 *
 * Output handling: the engine's squeeze loop does not back-pressure, so the
 * Chisel wrapper captures every emitted word into a buffer that this driver
 * drains afterwards. That buffer is ASCON_OUT_WORDS deep, which caps a single
 * XOF/CXOF request and a single AEAD run at ASCON_MAX_OUT bytes. Longer
 * requests return ASCON_EINVAL rather than silently truncating.
 *
 * All polling is bounded; a dead or misaddressed peripheral yields
 * ASCON_ETIMEOUT rather than hanging.
 */

#ifndef ASCON_H
#define ASCON_H

#include <stdint.h>

#define ASCON_BASE 0x64008000u

/* Register offsets -- mirrors ASCONRegs in
 * generators/chipyard/src/main/scala/crypto/ascon/asconregs.scala */
#define ASCON_CTRL      0x00 /* W1  bit0 = start pulse                     */
#define ASCON_MODE      0x04 /* RW  [2:0]                                  */
#define ASCON_OUT_LEN   0x08 /* RW  [10:0] output length in 64-bit blocks  */
#define ASCON_STATUS    0x0C /* RO                                         */
#define ASCON_OUT_COUNT 0x10 /* RO  output words captured since start      */
#define ASCON_IN_LO     0x14 /* RW  data_in[31:0]                          */
#define ASCON_IN_HI     0x18 /* RW  data_in[63:32]                         */
#define ASCON_IN_CTRL   0x1C /* W1  bit0 valid, bit1 last, [5:2] bytes,
                              *     bit6 phase_sel                         */
#define ASCON_EXP_TAG   0x20 /* RW  4 x 32                                 */
#define ASCON_HASH      0x40 /* RO  8 x 32, hash(0) = hash_o[255:224]      */
#define ASCON_OUT      0x100 /* RO 32 x 32 = 16 x 64-bit captured words    */

/* status bits */
#define ASCON_ST_BUSY         0x01u
#define ASCON_ST_DONE         0x02u /* sticky, cleared by start */
#define ASCON_ST_IN_READY     0x04u
#define ASCON_ST_TAG_VALID    0x08u /* sticky */
#define ASCON_ST_AUTH_FAIL    0x10u /* sticky */
#define ASCON_ST_OUT_OVERFLOW 0x20u

/* mode_i encoding, from ascon_defs_std.svh */
#define ASCON_MODE_ENC  0u
#define ASCON_MODE_DEC  1u
#define ASCON_MODE_HASH 2u
#define ASCON_MODE_XOF  3u
#define ASCON_MODE_CXOF 4u

#define ASCON_HASH256_LEN   32
#define ASCON_AEAD_KEY_LEN  16
#define ASCON_AEAD_NPUB_LEN 16
#define ASCON_AEAD_TAG_LEN  16

/* Must match ASCONParamsConst.outWords in the wrapper. */
#define ASCON_OUT_WORDS 16
#define ASCON_MAX_OUT   (ASCON_OUT_WORDS * 8)

#define ASCON_OK         0
#define ASCON_ETIMEOUT (-1)
#define ASCON_EINVAL   (-2)
#define ASCON_EAUTH    (-3) /* decrypt: engine reported auth_fail */

/* Raw status register, for diagnostics. */
uint32_t ascon_status(void);

/* Ascon-Hash256. msg_len may be 0. */
int ascon_hash256(const uint8_t *msg, uint32_t msg_len, uint8_t md[ASCON_HASH256_LEN]);

/* Ascon-XOF128. msg_len may be 0; out_len must be a non-zero multiple of 8,
 * at most ASCON_MAX_OUT. */
int ascon_xof128(const uint8_t *msg, uint32_t msg_len, uint8_t *out, uint32_t out_len);

/* Ascon-CXOF128. Both the customization string and the message may be empty;
 * out_len is constrained exactly as for ascon_xof128(). */
int ascon_cxof128(const uint8_t *z, uint32_t z_len,
                  const uint8_t *msg, uint32_t msg_len,
                  uint8_t *out, uint32_t out_len);

/* Ascon-AEAD128 encrypt. ad and pt may both be empty. */
int ascon_aead128_encrypt(const uint8_t key[ASCON_AEAD_KEY_LEN],
                          const uint8_t npub[ASCON_AEAD_NPUB_LEN],
                          const uint8_t *ad, uint32_t ad_len,
                          const uint8_t *pt, uint32_t pt_len,
                          uint8_t *ct, uint8_t tag[ASCON_AEAD_TAG_LEN]);

/* Ascon-AEAD128 decrypt and verify. The engine compares the tag in hardware
 * and reports auth_fail, so this returns ASCON_EAUTH on mismatch and zeroes
 * `pt` rather than leaving unauthenticated plaintext in the caller's buffer. */
int ascon_aead128_decrypt(const uint8_t key[ASCON_AEAD_KEY_LEN],
                          const uint8_t npub[ASCON_AEAD_NPUB_LEN],
                          const uint8_t *ad, uint32_t ad_len,
                          const uint8_t *ct, uint32_t ct_len,
                          uint8_t *pt, const uint8_t tag[ASCON_AEAD_TAG_LEN]);

#endif /* ASCON_H */
