/*
 * ChaCha20-Poly1305 AEAD demo -- RV32 SmallRocket on Arty 100T.
 *
 * SoC config : SmallRocket32ChachaPolyAeadArty100TConfig
 *              (AEAD_chacha_poly @ 0x6400A000)
 * Input: "TRAN HUNG THOI" (14 bytes)
 */

#include <stdint.h>
#include "platform.h"
#include "kprintf.h"
#include "aead.h"
#include "chachapoly_kats.h"

#define REG32(p, i) ((p)[(i) >> 2])
#define MAX_MSG 128

/* ------------------------------------------------------------------------- */
/* Hex helpers -- kprintf only supports %l %x %hx %s %c                      */
/* ------------------------------------------------------------------------- */

static void print_hex_byte(uint8_t v)
{
	kprintf("%hx", (unsigned int)v);
}

static void rfc_hexdump(const uint8_t *b, uint32_t len)
{
	for (uint32_t off = 0; off < len; off += 16) {
		uint32_t n = len - off < 16 ? len - off : 16;

		/* offset */
		print_hex_byte((uint8_t)(off >> 8));
		print_hex_byte((uint8_t)(off & 0xFF));
		kprintf("  ");

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
		if (i) kprintf(":");
		print_hex_byte(b[i]);
	}
	kprintf("\r\n");
}

static int bytes_equal(const uint8_t *a, const uint8_t *b, uint32_t len)
{
	for (uint32_t i = 0; i < len; i++)
		if (a[i] != b[i])
			return 0;
	return 1;
}

/* ------------------------------------------------------------------------- */
/* Input: student name                                                        */
/* ------------------------------------------------------------------------- */

static const uint8_t my_name[]    = "TRAN HUNG THOI";
static const uint32_t my_name_len = 14;

/* ------------------------------------------------------------------------- */

int main(int hartid, char **argv)
{
	static uint8_t ct[MAX_MSG];
	static uint8_t pt[MAX_MSG];
	static uint8_t tag_enc[AEAD_TAG_LEN];
	static uint8_t tag_dec[AEAD_TAG_LEN];
	int rc, tags_match, pt_match;

	REG32(uart, UART_REG_TXCTRL) = UART_TXEN;

	kprintf("\r\nChaCha20-Poly1305 AEAD -- RFC 8439\r\n");
	kprintf("AEAD_chacha_poly @ 0x6400A000, Arty 100T\r\n");
	kprintf("Input: TRAN HUNG THOI\r\n");

	/* ---- encrypt ---------------------------------------------------- */
	rc = aead_encrypt(kat_aead_key, kat_aead_nonce,
	                  kat_aead_aad, sizeof(kat_aead_aad),
	                  my_name, my_name_len, ct, tag_enc);

	if (rc != AEAD_OK) {
		kprintf("\r\nencrypt failed\r\n");
		for (;;) ;
	}

	kprintf("\r\nENCRYPT\r\n");
	kprintf("Key:\r\n");
	rfc_hexdump(kat_aead_key, 32);
	kprintf("Nonce:\r\n");
	rfc_hexdump(kat_aead_nonce, 12);
	kprintf("Associated Data:\r\n");
	rfc_hexdump(kat_aead_aad, sizeof(kat_aead_aad));
	kprintf("Plaintext:\r\n");
	rfc_hexdump(my_name, my_name_len);
	kprintf("Ciphertext:\r\n");
	rfc_hexdump(ct, my_name_len);
	kprintf("Tag:\r\n");
	rfc_tag(tag_enc, AEAD_TAG_LEN);

	/* ---- decrypt ---------------------------------------------------- */
	rc = aead_decrypt_ex(kat_aead_key, kat_aead_nonce,
	                     kat_aead_aad, sizeof(kat_aead_aad),
	                     ct, my_name_len,
	                     tag_enc, pt, tag_dec);

	kprintf("\r\nDECRYPT\r\n");
	if (rc != AEAD_OK && rc != AEAD_EAUTH) {
		kprintf("decrypt failed\r\n");
		for (;;) ;
	}

	kprintf("Ciphertext:\r\n");
	rfc_hexdump(ct, my_name_len);
	kprintf("Tag:\r\n");
	rfc_tag(tag_enc, AEAD_TAG_LEN);
	kprintf("Plaintext recovered:\r\n");
	rfc_hexdump(pt, my_name_len);
	kprintf("Tag recomputed:\r\n");
	rfc_tag(tag_dec, AEAD_TAG_LEN);

	/* ---- compare ---------------------------------------------------- */
	tags_match = bytes_equal(tag_enc, tag_dec, AEAD_TAG_LEN);
	pt_match   = bytes_equal(pt, my_name, my_name_len);

	kprintf("\r\ntag encrypt == tag decrypt : %s\r\n",
	        tags_match ? "YES" : "NO");
	kprintf("plaintext recovered        : %s\r\n",
	        pt_match ? "YES" : "NO");
	kprintf("authentication             : %s\r\n",
	        rc == AEAD_OK ? "OK" : "FAILED");

	kprintf("\r\nDone.\r\n");
	for (;;) ;
}
