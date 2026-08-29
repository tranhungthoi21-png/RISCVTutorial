/* Standard ASCON (SP 800-232) MMIO driver -- see ascon.h for the contract.
 *
 * Every 64-bit port is little-endian: message byte 0 lands in bits [7:0]. The
 * helpers below are written base-plus-index so a short final block never forms
 * a pointer past the end of the caller's buffer. */

#include "ascon.h"

/* ASCON_REG32 is overridable so this file can be compiled against a simulated
 * peripheral instead of a fixed address. On the target it is a plain volatile
 * MMIO access. */
#ifndef ASCON_REG32
#define ASCON_REG32(off) (*(volatile uint32_t *)((uintptr_t)ASCON_BASE + (off)))
#endif

#define REG32(off) ASCON_REG32(off)

#define POLL_LIMIT 200000u

/* ------------------------------------------------------------------------- */
/* Byte packing -- little-endian                                              */
/* ------------------------------------------------------------------------- */

/* word = bytes[idx..idx+3] loaded little-endian, zero past `len`. */
static uint32_t le32_at(const uint8_t *base, uint32_t idx, uint32_t len)
{
	uint32_t v = 0;

	for (uint32_t i = 0; i < 4; i++)
		if (idx + i < len)
			v |= (uint32_t)base[idx + i] << (8 * i);
	return v;
}

static void le32_store_at(uint8_t *base, uint32_t idx, uint32_t len, uint32_t v)
{
	for (uint32_t i = 0; i < 4; i++)
		if (idx + i < len)
			base[idx + i] = (uint8_t)(v >> (8 * i));
}

/* ------------------------------------------------------------------------- */
/* Handshake                                                                  */
/* ------------------------------------------------------------------------- */

uint32_t ascon_status(void)
{
	return REG32(ASCON_STATUS);
}

static int wait_flag(uint32_t mask, uint32_t want)
{
	uint32_t n = POLL_LIMIT;

	while (((REG32(ASCON_STATUS) & mask) != 0u) != (want != 0u))
		if (--n == 0)
			return ASCON_ETIMEOUT;
	return ASCON_OK;
}

static int wait_in_ready(void) { return wait_flag(ASCON_ST_IN_READY, 1); }
static int wait_not_busy(void) { return wait_flag(ASCON_ST_BUSY, 0); }
static int wait_done(void)     { return wait_flag(ASCON_ST_DONE, 1); }

/* Latch mode and output length, then pulse start. Does not wait: AEAD has to
 * stream its key and nonce in while the engine is still busy, so the wait is
 * the caller's to place. */
static void start_op_raw(uint32_t mode, uint32_t out_blocks)
{
	REG32(ASCON_MODE) = mode;
	REG32(ASCON_OUT_LEN) = out_blocks;
	REG32(ASCON_CTRL) = 1;
}

/* Start a run in `mode`, producing `out_blocks` 64-bit output words, and wait
 * for initialisation to finish. Correct for Hash/XOF/CXOF, which take no key. */
static int start_op(uint32_t mode, uint32_t out_blocks)
{
	start_op_raw(mode, out_blocks);
	return wait_not_busy();
}

/*
 * Feed one 64-bit word taken from base[idx..idx+7], zero-padded past `len`.
 * `last_bytes` is only meaningful when `last` is set; the engine uses it to
 * place the padding bit. last_block, last_bytes and phase_sel are latched by
 * the same register write that raises data_in_valid, so they are already
 * stable when the engine samples them.
 */
static int feed_word(const uint8_t *base, uint32_t idx, uint32_t len,
                     int last, uint32_t last_bytes, int phase_sel)
{
	int rc = wait_in_ready();

	if (rc != ASCON_OK)
		return rc;

	REG32(ASCON_IN_LO) = le32_at(base, idx, len);
	REG32(ASCON_IN_HI) = le32_at(base, idx + 4, len);
	REG32(ASCON_IN_CTRL) = 1u
	                     | ((uint32_t)(last != 0) << 1)
	                     | ((last_bytes & 0xFu) << 2)
	                     | ((uint32_t)(phase_sel != 0) << 6);
	return ASCON_OK;
}

/*
 * Feed one whole phase. A zero-length phase still sends a single empty word
 * with last_block set and last_bytes = 0, which is how SP 800-232's empty
 * string is expressed; the engine handles it natively.
 *
 * `aead` selects the 128-bit rate. Ascon-AEAD128 absorbs 128 bits per block
 * while data_in is 64 bits wide, so the engine uses phase_sel to tell the two
 * halves apart: 0 on the first half makes it wait for the second, 1 on the
 * second half makes it permute. The hash-family modes have a 64-bit rate and
 * permute after every word, so phase_sel stays 0 there.
 */
static int feed_phase(const uint8_t *base, uint32_t len, int aead)
{
	uint32_t idx = 0;

	if (len == 0)
		return feed_word(base, 0, 0, 1, 0, 0);

	/*
	 * last_bytes has different meanings per rate. For the 64-bit modes it is
	 * the valid byte count of the final 64-bit word, 0..8. For AEAD it counts
	 * valid bytes across the whole 128-bit block, 0..15, because the engine
	 * uses it to place the padding byte in x0 (0..7) or x1 (8..15). A final
	 * block that exactly fills the rate cannot be encoded in those 4 bits, so
	 * it is signalled as last_bytes = 0 on the second half; the engine then
	 * permutes and pads a fresh block.
	 */
	for (uint32_t off = 0; off < len; off += 8, idx++) {
		uint32_t left = len - off;
		int last = (left <= 8);
		int phase = aead ? (int)(idx & 1u) : 0;
		uint32_t lb;
		int rc;

		if (!last)
			lb = 0;
		else if (aead)
			lb = len % 16u;   /* 0 here means "block fills the rate" */
		else
			lb = left;

		rc = feed_word(base, off, len, last, lb, phase);
		if (rc != ASCON_OK)
			return rc;
	}
	return ASCON_OK;
}

/* ------------------------------------------------------------------------- */
/* Result readback                                                            */
/* ------------------------------------------------------------------------- */

/*
 * hash register k holds hash_o[255-32k : 224-32k], so 64-bit output word w
 * spans registers 2w (upper half) and 2w+1 (lower half). Little-endian packing
 * puts bytes 8w..8w+3 in the lower half and 8w+4..8w+7 in the upper.
 */
static void read_hash(uint8_t *dst, uint32_t len)
{
	for (uint32_t w = 0; w * 8 < len; w++) {
		le32_store_at(dst, w * 8,     len, REG32(ASCON_HASH + (2 * w + 1) * 4));
		le32_store_at(dst, w * 8 + 4, len, REG32(ASCON_HASH + (2 * w) * 4));
	}
}

/* Same layout for the wrapper's captured output buffer. */
static void read_out_buf(uint8_t *dst, uint32_t len)
{
	for (uint32_t w = 0; w * 8 < len; w++) {
		le32_store_at(dst, w * 8,     len, REG32(ASCON_OUT + (2 * w + 1) * 4));
		le32_store_at(dst, w * 8 + 4, len, REG32(ASCON_OUT + (2 * w) * 4));
	}
}

/* ------------------------------------------------------------------------- */
/* Hash / XOF / CXOF                                                          */
/* ------------------------------------------------------------------------- */

int ascon_hash256(const uint8_t *msg, uint32_t msg_len, uint8_t md[ASCON_HASH256_LEN])
{
	int rc = start_op(ASCON_MODE_HASH, ASCON_HASH256_LEN / 8);

	if (rc != ASCON_OK)
		return rc;

	rc = feed_phase(msg, msg_len, 0);
	if (rc != ASCON_OK)
		return rc;

	rc = wait_done();
	if (rc != ASCON_OK)
		return rc;

	/* Hash256 is exactly four words, so the rolling hash register holds the
	 * whole digest and the capture buffer is not needed. */
	read_hash(md, ASCON_HASH256_LEN);
	return ASCON_OK;
}

static int xof_common(uint32_t mode,
                      const uint8_t *z, uint32_t z_len,
                      const uint8_t *msg, uint32_t msg_len,
                      uint8_t *out, uint32_t out_len)
{
	int rc;

	if (out_len == 0 || (out_len % 8) != 0 || out_len > ASCON_MAX_OUT)
		return ASCON_EINVAL;

	rc = start_op(mode, out_len / 8);
	if (rc != ASCON_OK)
		return rc;

	if (mode == ASCON_MODE_CXOF) {
		/* CXOF absorbs the customization string first, introduced by one
		 * word carrying its length in BITS, then ends that phase and waits
		 * for the engine to fold it in before the message starts. */
		uint8_t zbits[8];
		uint64_t bits = (uint64_t)z_len * 8u;

		for (int i = 0; i < 8; i++)
			zbits[i] = (uint8_t)(bits >> (8 * i));

		rc = feed_word(zbits, 0, 8, 0, 0, 0);
		if (rc != ASCON_OK)
			return rc;

		rc = feed_phase(z, z_len, 0);
		if (rc != ASCON_OK)
			return rc;

		rc = wait_not_busy();
		if (rc != ASCON_OK)
			return rc;
	}

	rc = feed_phase(msg, msg_len, 0);
	if (rc != ASCON_OK)
		return rc;

	rc = wait_done();
	if (rc != ASCON_OK)
		return rc;

	if (REG32(ASCON_STATUS) & ASCON_ST_OUT_OVERFLOW)
		return ASCON_EINVAL;

	read_out_buf(out, out_len);
	return ASCON_OK;
}

int ascon_xof128(const uint8_t *msg, uint32_t msg_len, uint8_t *out, uint32_t out_len)
{
	return xof_common(ASCON_MODE_XOF, (const uint8_t *)0, 0, msg, msg_len, out, out_len);
}

int ascon_cxof128(const uint8_t *z, uint32_t z_len,
                  const uint8_t *msg, uint32_t msg_len,
                  uint8_t *out, uint32_t out_len)
{
	return xof_common(ASCON_MODE_CXOF, z, z_len, msg, msg_len, out, out_len);
}

/* ------------------------------------------------------------------------- */
/* AEAD128                                                                    */
/* ------------------------------------------------------------------------- */

static void write_exp_tag(const uint8_t tag[ASCON_AEAD_TAG_LEN])
{
	/* exp_tag register k holds exp_tag[127-32k : 96-32k]; 64-bit word w spans
	 * registers 2w (upper) and 2w+1 (lower), little-endian as everywhere. */
	for (uint32_t w = 0; w < 2; w++) {
		REG32(ASCON_EXP_TAG + (2 * w + 1) * 4) =
			le32_at(tag, w * 8, ASCON_AEAD_TAG_LEN);
		REG32(ASCON_EXP_TAG + (2 * w) * 4) =
			le32_at(tag, w * 8 + 4, ASCON_AEAD_TAG_LEN);
	}
}

/*
 * One AEAD direction. `in` is plaintext when encrypting and ciphertext when
 * decrypting; `out` receives the other one.
 *
 * The key and nonce are streamed in as four plain data words immediately after
 * start, before any AD. Domain separation between the AD and message phases
 * happens automatically when AD is present; with an empty AD the engine needs
 * an explicit phase_sel pulse instead, which is what the ad_len == 0 branch
 * below does.
 */
static int aead_run(uint32_t mode,
                    const uint8_t key[ASCON_AEAD_KEY_LEN],
                    const uint8_t npub[ASCON_AEAD_NPUB_LEN],
                    const uint8_t *ad, uint32_t ad_len,
                    const uint8_t *in, uint32_t in_len,
                    uint8_t *out, uint8_t tag[ASCON_AEAD_TAG_LEN])
{
	int rc;

	if (in_len > ASCON_MAX_OUT)
		return ASCON_EINVAL;

	/* The engine raises data_in_ready for the key/nonce stream while it is
	 * still busy initialising, so start without waiting and let the per-word
	 * ready handshake pace the transfer. */
	start_op_raw(mode, 0);

	/* Key then nonce, two 64-bit words each, no last_block marking. */
	for (uint32_t w = 0; w < 2; w++) {
		rc = feed_word(key, w * 8, ASCON_AEAD_KEY_LEN, 0, 0, 0);
		if (rc != ASCON_OK)
			return rc;
	}
	for (uint32_t w = 0; w < 2; w++) {
		rc = feed_word(npub, w * 8, ASCON_AEAD_NPUB_LEN, 0, 0, 0);
		if (rc != ASCON_OK)
			return rc;
	}

	rc = wait_not_busy();
	if (rc != ASCON_OK)
		return rc;

	if (ad_len) {
		rc = feed_phase(ad, ad_len, 1);
		if (rc != ASCON_OK)
			return rc;
	} else {
		/* No AD: raise phase_sel so the engine performs domain separation
		 * on an empty associated-data phase. */
		REG32(ASCON_IN_CTRL) = (1u << 6);
		rc = wait_not_busy();
		if (rc != ASCON_OK)
			return rc;
		REG32(ASCON_IN_CTRL) = 0;
	}

	rc = wait_not_busy();
	if (rc != ASCON_OK)
		return rc;

	rc = feed_phase(in, in_len, 1);
	if (rc != ASCON_OK)
		return rc;

	rc = wait_done();
	if (rc != ASCON_OK)
		return rc;

	if (in_len)
		read_out_buf(out, in_len);

	/* The tag occupies hash_o[255:128], i.e. the first two 64-bit words. */
	read_hash(tag, ASCON_AEAD_TAG_LEN);
	return ASCON_OK;
}

int ascon_aead128_encrypt(const uint8_t key[ASCON_AEAD_KEY_LEN],
                          const uint8_t npub[ASCON_AEAD_NPUB_LEN],
                          const uint8_t *ad, uint32_t ad_len,
                          const uint8_t *pt, uint32_t pt_len,
                          uint8_t *ct, uint8_t tag[ASCON_AEAD_TAG_LEN])
{
	return aead_run(ASCON_MODE_ENC, key, npub, ad, ad_len, pt, pt_len, ct, tag);
}

int ascon_aead128_decrypt(const uint8_t key[ASCON_AEAD_KEY_LEN],
                          const uint8_t npub[ASCON_AEAD_NPUB_LEN],
                          const uint8_t *ad, uint32_t ad_len,
                          const uint8_t *ct, uint32_t ct_len,
                          uint8_t *pt, const uint8_t tag[ASCON_AEAD_TAG_LEN])
{
	uint8_t computed[ASCON_AEAD_TAG_LEN];
	int rc;

	/* The engine verifies the tag itself, so hand it the expected value
	 * before starting and read auth_fail afterwards. */
	write_exp_tag(tag);

	rc = aead_run(ASCON_MODE_DEC, key, npub, ad, ad_len, ct, ct_len, pt, computed);
	if (rc != ASCON_OK)
		return rc;

	if (REG32(ASCON_STATUS) & ASCON_ST_AUTH_FAIL) {
		for (uint32_t i = 0; i < ct_len; i++)
			pt[i] = 0;
		return ASCON_EAUTH;
	}

	return ASCON_OK;
}
