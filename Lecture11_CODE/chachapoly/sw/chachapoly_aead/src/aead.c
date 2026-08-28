/* Fused ChaCha20-Poly1305 AEAD driver -- see aead.h for the contract and for
 * the sequencing requirements the RTL imposes. */

#include "aead.h"

#define REG32(off) (*(volatile uint32_t *)((uintptr_t)AEAD_BASE + (off)))

/* A 64-byte block is a handful of ChaCha rounds plus four Poly1305 absorbs; a
 * limit this size only trips when the peripheral is absent or misaddressed. */
#define POLL_LIMIT 200000u

/* ------------------------------------------------------------------------- */
/* Byte packing                                                               */
/* ------------------------------------------------------------------------- */

/*
 * Base-plus-index rather than a pre-offset pointer, so a short final block
 * never forms a pointer past the end of the buffer. `len` is the buffer's valid
 * length; bytes at or beyond it read as zero and are not written.
 */
static uint32_t be32_load_at(const uint8_t *base, uint32_t idx, uint32_t len)
{
	uint32_t v = 0;

	for (uint32_t i = 0; i < 4; i++)
		v = (v << 8) | (idx + i < len ? base[idx + i] : 0u);
	return v;
}

static void be32_store_at(uint8_t *base, uint32_t idx, uint32_t len, uint32_t v)
{
	for (uint32_t i = 0; i < 4; i++)
		if (idx + i < len)
			base[idx + i] = (uint8_t)(v >> (24 - 8 * i));
}

/* out_0/out_1 sit at 0x198, but out_2..out_15 restart at 0x200 rather than
 * continuing at 0x1A0. Fold that discontinuity into one place. */
static uint32_t out_offset(uint32_t word)
{
	return word < 2 ? AEAD_OUT_LO + word * 4
	                : AEAD_OUT_HI + (word - 2) * 4;
}

/* ------------------------------------------------------------------------- */
/* Core plumbing                                                              */
/* ------------------------------------------------------------------------- */

static int wait_ready(void)
{
	uint32_t n = POLL_LIMIT;

	/* `ready` is registered in the wrapper on top of the core's own register,
	 * and an MMIO round trip is far longer than that, so this cannot return a
	 * stale ready left over from before the pulse that started the step. */
	while (REG32(AEAD_READY) != 1)
		if (--n == 0)
			return AEAD_ETIMEOUT;
	return AEAD_OK;
}

/* Load one 64-byte data block, zero-padded past `len`, and its length.
 *
 * `block_len` has to be written before the pulse that consumes it: the core
 * latches the MAC sub-block count and advances its length counter from it, and
 * `cipher_text` is masked combinationally by whatever `block_len` currently
 * holds -- which is also why it must stay put until the output is read back. */
static void load_block(const uint8_t *base, uint32_t off, uint32_t len)
{
	uint32_t left = len - off;

	for (uint32_t w = 0; w < 16; w++)
		REG32(AEAD_IN + w * 4) = be32_load_at(base, off + w * 4, len);

	REG32(AEAD_BLOCK_LEN) = left < AEAD_BLOCK ? left : AEAD_BLOCK;
}

static void read_block(uint8_t *base, uint32_t off, uint32_t len)
{
	for (uint32_t w = 0; w < 16; w++) {
		uint32_t at = off + w * 4;

		if (at >= len)
			break;
		be32_store_at(base, at, len, REG32(out_offset(w)));
	}
}

static void read_tag(uint8_t tag[AEAD_TAG_LEN])
{
	for (uint32_t i = 0; i < AEAD_TAG_LEN / 4; i++)
		be32_store_at(tag, i * 4, AEAD_TAG_LEN, REG32(AEAD_MAC + i * 4));
}

/*
 * One AEAD pass in either direction. `in` is plaintext when encrypting and
 * ciphertext when decrypting; `out` is the other one.
 *
 * The core reads its input from the same register file in both directions and
 * MACs whichever of the two is the ciphertext, so the only difference between
 * the directions is the latched encrypt bit.
 */
static int aead_run(uint32_t encrypt,
                    const uint8_t key[AEAD_KEY_LEN],
                    const uint8_t nonce[AEAD_NONCE_LEN],
                    const uint8_t *ad, uint32_t ad_len,
                    const uint8_t *in, uint32_t in_len,
                    uint8_t *out, uint8_t tag[AEAD_TAG_LEN])
{
	int rc;

	if (in_len == 0)
		return AEAD_EINVAL;

	/* Reset first: it clears `in`, which the key-generation pass requires, and
	 * it is the only way out of the core's terminal state. */
	REG32(AEAD_RST_CORE) = 0;
	REG32(AEAD_RST_CORE) = 1;

	for (uint32_t i = 0; i < AEAD_KEY_LEN / 4; i++)
		REG32(AEAD_KEY + i * 4) = be32_load_at(key, i * 4, AEAD_KEY_LEN);
	for (uint32_t i = 0; i < AEAD_NONCE_LEN / 4; i++)
		REG32(AEAD_NONCE + i * 4) = be32_load_at(nonce, i * 4, AEAD_NONCE_LEN);

	REG32(AEAD_ENCRYPT) = encrypt;
	REG32(AEAD_INIT) = 1;

	rc = wait_ready();
	if (rc != AEAD_OK)
		return rc;

	/* AAD phase: one 16-byte block per pulse, zero-padded. Skipped entirely
	 * when there is no AAD, which leaves the length counter at zero. */
	for (uint32_t off = 0; off < ad_len; off += AEAD_AAD_BLOCK) {
		uint32_t left = ad_len - off;

		for (uint32_t w = 0; w < 4; w++)
			REG32(AEAD_AAD + w * 4) = be32_load_at(ad, off + w * 4, ad_len);

		REG32(AEAD_BLOCK_LEN) = left < AEAD_AAD_BLOCK ? left : AEAD_AAD_BLOCK;
		REG32(AEAD_NEXT) = 1;

		rc = wait_ready();
		if (rc != AEAD_OK)
			return rc;
	}

	/* First data block. The pulse that ends the AAD phase also runs this
	 * block, so its length must already be loaded -- hence load_block before
	 * the finish, not after. */
	load_block(in, 0, in_len);
	REG32(AEAD_FINISH) = 1;

	rc = wait_ready();
	if (rc != AEAD_OK)
		return rc;
	read_block(out, 0, in_len);

	/* Remaining data blocks. */
	for (uint32_t off = AEAD_BLOCK; off < in_len; off += AEAD_BLOCK) {
		load_block(in, off, in_len);
		REG32(AEAD_NEXT) = 1;

		rc = wait_ready();
		if (rc != AEAD_OK)
			return rc;
		read_block(out, off, in_len);
	}

	/* Second finish: absorbs le64(len AAD) || le64(len CT) and emits the tag. */
	REG32(AEAD_FINISH) = 1;

	rc = wait_ready();
	if (rc != AEAD_OK)
		return rc;

	read_tag(tag);
	return AEAD_OK;
}

int aead_encrypt(const uint8_t key[AEAD_KEY_LEN],
                 const uint8_t nonce[AEAD_NONCE_LEN],
                 const uint8_t *ad, uint32_t ad_len,
                 const uint8_t *pt, uint32_t pt_len,
                 uint8_t *ct, uint8_t tag[AEAD_TAG_LEN])
{
	return aead_run(1, key, nonce, ad, ad_len, pt, pt_len, ct, tag);
}

int aead_decrypt(const uint8_t key[AEAD_KEY_LEN],
                 const uint8_t nonce[AEAD_NONCE_LEN],
                 const uint8_t *ad, uint32_t ad_len,
                 const uint8_t *ct, uint32_t ct_len,
                 const uint8_t tag[AEAD_TAG_LEN],
                 uint8_t *pt)
{
	return aead_decrypt_ex(key, nonce, ad, ad_len, ct, ct_len, tag, pt,
	                       (uint8_t *)0);
}

int aead_decrypt_ex(const uint8_t key[AEAD_KEY_LEN],
                    const uint8_t nonce[AEAD_NONCE_LEN],
                    const uint8_t *ad, uint32_t ad_len,
                    const uint8_t *ct, uint32_t ct_len,
                    const uint8_t tag[AEAD_TAG_LEN],
                    uint8_t *pt,
                    uint8_t recomputed[AEAD_TAG_LEN])
{
	uint8_t computed[AEAD_TAG_LEN];
	uint32_t diff = 0;
	int rc;

	rc = aead_run(0, key, nonce, ad, ad_len, ct, ct_len, pt, computed);

	if (recomputed && rc == AEAD_OK)
		for (uint32_t i = 0; i < AEAD_TAG_LEN; i++)
			recomputed[i] = computed[i];
	if (rc != AEAD_OK)
		return rc;

	for (uint32_t i = 0; i < AEAD_TAG_LEN; i++)
		diff |= (uint32_t)(computed[i] ^ tag[i]);

	if (diff) {
		/* The core produces plaintext and tag in one pass, so `pt` is already
		 * written by the time the tag can be checked. Wipe it so a caller that
		 * ignores the return value cannot read unauthenticated plaintext. */
		for (uint32_t i = 0; i < ct_len; i++)
			pt[i] = 0;
		return AEAD_EAUTH;
	}

	return AEAD_OK;
}
