/*
 * Fused ChaCha20-Poly1305 AEAD demo -- RV32 SmallRocket on Arty 100T.
 *
 * SoC config : SmallRocket32ChachaPolyAeadArty100TConfig
 *              (AEAD_chacha_poly @ 0x6400A000)
 * Scratchpad : 128 kB at 0x80000000
 * UART0      : 0x64000000
 */

#include <stdint.h>
#include "platform.h"
#include "kprintf.h"
#include "aead.h"
#include "chachapoly_kats.h"

#define REG32(p, i) ((p)[(i) >> 2])

/* The RFC 8439 plaintext is 114 bytes; round up for the working buffers. */
#define MAX_MSG 128

static uint32_t rdcycle32(void)
{
	uint32_t v;
	__asm__ volatile ("csrr %0, mcycle" : "=r"(v));
	return v;
}

/* Hàm ph? tr? in m?t byte du?i d?ng mã Hex 2 ký t? (Tránh l?i kprintf thi?u %02x) */
static void print_hex_byte(uint8_t v)
{
	static const char hex[] = "0123456789abcdef";
	kprintf("%c%c", hex[v >> 4], hex[v & 0xF]);
}

/* ------------------------------------------------------------------------- */
/* RFC 8439 style output using kprintf                                       */
/* ------------------------------------------------------------------------- */

static void rfc_hexdump(const uint8_t *b, uint32_t len)
{
	for (uint32_t off = 0; off < len; off += 16) {
		uint32_t n = len - off < 16 ? len - off : 16;

		kprintf("%03u  ", off);

		for (uint32_t i = 0; i < 16; i++) {
			if (i < n) {
				print_hex_byte(b[off + i]);
				kprintf(" ");
			} else {
				kprintf("   ");
			}
		}

		kprintf(" ");
		for (uint32_t i = 0; i < n; i++) {
			uint8_t c = b[off + i];
			kprintf("%c", (c >= 0x20 && c < 0x7f) ? (char)c : '.');
		}
		kprintf("\r\n");
	}
}

static void rfc_tag(const uint8_t *b, uint32_t len)
{
	for (uint32_t i = 0; i < len; i++) {
		if (i)
			kprintf(":");
		print_hex_byte(b[i]);
	}
	kprintf("\r\n");
}

/* ------------------------------------------------------------------------- */
/* Reporting                                                                 */
/* ------------------------------------------------------------------------- */

static uint32_t failures;

__attribute__((unused)) static int bytes_equal(const uint8_t *a, const uint8_t *b, uint32_t len)
{
	for (uint32_t i = 0; i < len; i++)
		if (a[i] != b[i])
			return 0;
	return 1;
}

__attribute__((unused)) static void report(const char *label, int rc, uint32_t cycles,
					const uint8_t *got, const uint8_t *want, uint32_t len)
{
	kprintf("%s: ", label);

	if (rc != AEAD_OK) {
		kprintf("FAIL rc=%u\r\n", (uint32_t)(-rc));
		failures++;
		return;
	}

	kprintf("%u cyc ", cycles);

	if (bytes_equal(got, want, len)) {
		kprintf("PASS\r\n");
		return;
	}

	kprintf("FAIL\r\n      got  ");
	for (uint32_t i = 0; i < len; i++) print_hex_byte(got[i]);
	kprintf("\r\n      want ");
	for (uint32_t i = 0; i < len; i++) print_hex_byte(want[i]);
	kprintf("\r\n");
	failures++;
}

/* ------------------------------------------------------------------------- */
/* Main Program                                                              */
/* ------------------------------------------------------------------------- */

int main(int hartid, char **argv)
{
	static uint8_t ct[MAX_MSG];
	static uint8_t pt[MAX_MSG];
	static uint8_t tag_enc[AEAD_TAG_LEN];
	static uint8_t tag_dec[AEAD_TAG_LEN];
	int rc, tags_match, pt_match;

	// Kích ho?t UART TX Control chu?n t? platform.h
	REG32(uart, UART_REG_TXCTRL) = UART_TXEN;

	kprintf("\r\nChaCha20-Poly1305 AEAD round trip -- RFC 8439 Sec 2.8.2\r\n");
	kprintf("AEAD_chacha_poly @ 0x6400A000, Arty 100T\r\n");

	/* ---- encrypt ---------------------------------------------------- */
	rc = aead_encrypt(kat_aead_key, kat_aead_nonce,
			  kat_aead_aad, sizeof(kat_aead_aad),
			  kat_aead_pt, sizeof(kat_aead_pt), ct, tag_enc);
	if (rc != AEAD_OK) {
		kprintf("\r\nencrypt failed, rc=%u\r\n", (uint32_t)(-rc));
		for (;;)
			;
	}

	kprintf("\r\nENCRYPT\r\n");
	kprintf("Ciphertext:\r\n");
	rfc_hexdump(ct, sizeof(kat_aead_pt));
	kprintf("Tag:\r\n");
	rfc_tag(tag_enc, AEAD_TAG_LEN);

	/* ---- decrypt the ciphertext we just produced --------------------- */
	rc = aead_decrypt_ex(kat_aead_key, kat_aead_nonce,
			     kat_aead_aad, sizeof(kat_aead_aad),
			     ct, sizeof(kat_aead_pt),
			     tag_enc, pt, tag_dec);

	kprintf("\r\nDECRYPT\r\n");
	if (rc != AEAD_OK && rc != AEAD_EAUTH) {
		kprintf("decrypt failed, rc=%u\r\n", (uint32_t)(-rc));
		for (;;)
			;
	}

	kprintf("Plaintext:\r\n");
	rfc_hexdump(pt, sizeof(kat_aead_pt));
	kprintf("Tag recomputed by hardware:\r\n");
	rfc_tag(tag_dec, AEAD_TAG_LEN);

	/* ---- compare ------------------------------------------------------ */
	tags_match = bytes_equal(tag_enc, tag_dec, AEAD_TAG_LEN);
	pt_match   = bytes_equal(pt, kat_aead_pt, sizeof(kat_aead_pt));

	kprintf("\r\ntag encrypt == tag decrypt : %s\r\n", tags_match ? "YES" : "NO");
	kprintf("plaintext recovered        : %s\r\n", pt_match ? "YES" : "NO");
	kprintf("authentication             : %s\r\n", rc == AEAD_OK ? "OK" : "FAILED");

	for (;;)
		;
}
