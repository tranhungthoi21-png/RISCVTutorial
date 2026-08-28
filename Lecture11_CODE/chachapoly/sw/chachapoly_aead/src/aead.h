/*
 * Bare-metal driver for the fused ChaCha20-Poly1305 AEAD accelerator
 * (AEAD_chacha_poly.v).
 *
 * SoC config : SmallRocket32ChachaPolyAeadArty100TConfig, peripheral @ 0x6400A000.
 *
 * The core runs the entire RFC 8439 construction itself: it derives the
 * Poly1305 one-time key from ChaCha20 block 0, encrypts from block 1, absorbs
 * AAD and ciphertext into the MAC, applies pad16() by masking each block, and
 * appends the le64(len AAD) || le64(len CT) block. Firmware supplies operands
 * and pulses the state machine; it never assembles the MAC input.
 *
 * Byte order is "hex string order": word[i] is the big-endian load of
 * bytes[4i..4i+3]. The embedded cores byte-swap internally, so RFC 8439 byte
 * strings pass through unreversed.
 *
 * Granularity: 64 bytes of message per transaction, 16 bytes of AAD per
 * transaction. `block_len` carries the valid byte count of each.
 *
 * Constraints inherited from the RTL, not chosen here:
 *
 *   - The AAD register is one 128-bit block, absorbed with the core's Poly1305
 *     block length hardwired to 16. Firmware zero-pads each AAD block, which is
 *     what RFC 8439's pad16() calls for.
 *
 *   - `in` must read zero when init is pulsed. The RTL is missing a begin/end
 *     around its state_init branch, so `chacha_input <= plain_text` runs
 *     unconditionally and the key-generation pass XORs whatever `in` holds into
 *     ChaCha20 block 0 -- the block the one-time key comes from. The driver
 *     always pulses the core reset first, which clears `in` in the wrapper.
 *
 *   - The core's final state has no exit, so one operation needs one reset.
 *     aead_encrypt() and aead_decrypt() each reset on entry.
 *
 *   - Message length must be greater than zero. A block_len of 0 would still
 *     run one MAC block while adding nothing to the length counter, producing a
 *     tag that does not match the RFC's empty-message case.
 *
 * All polling is bounded; a dead or misaddressed peripheral yields
 * AEAD_ETIMEOUT rather than a hang.
 */

#ifndef AEAD_H
#define AEAD_H

#include <stdint.h>

#define AEAD_BASE 0x6400A000u

/* Register offsets -- mirrors ChachaPolyAeadRegs in
 * generators/chipyard/src/main/scala/crypto/chacha_poly_aead/chachapolyaeadregs.scala */
#define AEAD_KEY        0x100 /* RW  8 x 32, key bytes 0..31            */
#define AEAD_AAD        0x120 /* RW  4 x 32, one 16-byte AAD block      */
#define AEAD_NONCE      0x130 /* RW  3 x 32, nonce bytes 0..11          */
#define AEAD_IN         0x13C /* RW 16 x 32, one 64-byte data block     */
#define AEAD_RST_CORE   0x17C /* RW  active-low core reset              */
#define AEAD_INIT       0x180 /* W1  pulse init_aead                    */
#define AEAD_NEXT       0x184 /* W1  pulse next_aead                    */
#define AEAD_FINISH     0x188 /* W1  pulse finish_aead                  */
#define AEAD_BLOCK_LEN  0x18C /* RW  valid bytes in this block, 1..64   */
#define AEAD_READY      0x190 /* RO  1 = idle                           */
#define AEAD_ENCRYPT    0x194 /* RW  1 = encrypt; latched at init       */
#define AEAD_OUT_LO     0x198 /* RO  out_0, out_1                       */
#define AEAD_OUT_HI     0x200 /* RO  out_2 .. out_15                    */
#define AEAD_MAC        0x238 /* RO  4 x 32, tag bytes 0..15            */

#define AEAD_KEY_LEN    32
#define AEAD_NONCE_LEN  12
#define AEAD_TAG_LEN    16
#define AEAD_BLOCK      64   /* message bytes per transaction */
#define AEAD_AAD_BLOCK  16   /* AAD bytes per transaction     */

#define AEAD_OK         0
#define AEAD_ETIMEOUT (-1)
#define AEAD_EINVAL   (-2)
#define AEAD_EAUTH    (-3)   /* decrypt: recomputed tag did not match */

/* Encrypt and authenticate. `ct` receives pt_len bytes, `tag` 16 bytes.
 * `ad` may be empty; pt_len must be greater than zero. */
int aead_encrypt(const uint8_t key[AEAD_KEY_LEN],
                 const uint8_t nonce[AEAD_NONCE_LEN],
                 const uint8_t *ad, uint32_t ad_len,
                 const uint8_t *pt, uint32_t pt_len,
                 uint8_t *ct, uint8_t tag[AEAD_TAG_LEN]);

/*
 * Verify and decrypt. The core emits the recovered plaintext and the tag it
 * computed in the same pass, so `pt` is written before the tag is known; on
 * AEAD_EAUTH the driver zeroes it, and callers must treat a non-zero return as
 * "no plaintext".
 */
int aead_decrypt(const uint8_t key[AEAD_KEY_LEN],
                 const uint8_t nonce[AEAD_NONCE_LEN],
                 const uint8_t *ad, uint32_t ad_len,
                 const uint8_t *ct, uint32_t ct_len,
                 const uint8_t tag[AEAD_TAG_LEN],
                 uint8_t *pt);

/*
 * As aead_decrypt(), but also hands back the tag the core recomputed from the
 * ciphertext -- the value the comparison is actually made against. Pass NULL
 * for `recomputed` to ignore it. On AEAD_EAUTH the recomputed tag is still
 * written, since seeing it is the point of asking for it.
 */
int aead_decrypt_ex(const uint8_t key[AEAD_KEY_LEN],
                    const uint8_t nonce[AEAD_NONCE_LEN],
                    const uint8_t *ad, uint32_t ad_len,
                    const uint8_t *ct, uint32_t ct_len,
                    const uint8_t tag[AEAD_TAG_LEN],
                    uint8_t *pt,
                    uint8_t recomputed[AEAD_TAG_LEN]);

#endif /* AEAD_H */
