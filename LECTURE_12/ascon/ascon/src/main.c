/*
 * ASCON (NIST SP 800-232) accelerator demonstration.
 *
 * SoC config : SmallRocket32AsconArty100TConfig
 *              (ascon_engine_std @ 0x64008000)
 * Input: "TRAN HUNG THOI" (14 bytes)
 */

#include <stdint.h>
#include "platform.h"
#include "kprintf.h"
#include "ascon.h"

#define REG32(p, i) ((p)[(i) >> 2])

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

		/* offset in hex */
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

/* ------------------------------------------------------------------------- */
/* Input: student name                                                        */
/* ------------------------------------------------------------------------- */

static const uint8_t name[]    = "TRAN HUNG THOI";
static const uint32_t name_len = 14;

static const uint8_t key[16] = {
    0x00,0x01,0x02,0x03, 0x04,0x05,0x06,0x07,
    0x08,0x09,0x0A,0x0B, 0x0C,0x0D,0x0E,0x0F
};
static const uint8_t npub[16] = {
    0x00,0x11,0x22,0x33, 0x44,0x55,0x66,0x77,
    0x88,0x99,0xAA,0xBB, 0xCC,0xDD,0xEE,0xFF
};
static const uint8_t ad[]    = { 0x4B,0x32,0x34,0x00,0x00,0x00,0x00,0x00 };
static const uint32_t ad_len  = 8;

static const uint8_t z[]     = "student";
static const uint32_t z_len   = 7;

/* ------------------------------------------------------------------------- */

int main(int hartid, char **argv)
{
	uint8_t md[ASCON_HASH256_LEN];
	uint8_t xof_out[32];
	uint8_t cxof_out[32];
	uint8_t ct[64];
	uint8_t pt[64];
	uint8_t tag[ASCON_AEAD_TAG_LEN];
	int rc;

	REG32(uart, UART_REG_TXCTRL) = UART_TXEN;

	kprintf("\r\nASCON -- NIST SP 800-232\r\n");
	kprintf("ascon_engine_std @ 0x64008000, Arty 100T\r\n");
	kprintf("Input: TRAN HUNG THOI\r\n");

	/* ---- Ascon-Hash256 ----------------------------------------------- */
	kprintf("\r\n=== Ascon-Hash256 ===\r\n");
	kprintf("Message:\r\n");
	rfc_hexdump(name, name_len);

	rc = ascon_hash256(name, name_len, md);
	if (rc == ASCON_OK) {
		kprintf("Digest (32 bytes):\r\n");
		rfc_hexdump(md, ASCON_HASH256_LEN);
	} else {
		kprintf("Hash256 FAILED\r\n");
	}

	/* ---- Ascon-XOF128 ------------------------------------------------ */
	kprintf("\r\n=== Ascon-XOF128 ===\r\n");
	kprintf("Message:\r\n");
	rfc_hexdump(name, name_len);

	rc = ascon_xof128(name, name_len, xof_out, 32);
	if (rc == ASCON_OK) {
		kprintf("Output (32 bytes):\r\n");
		rfc_hexdump(xof_out, 32);
	} else {
		kprintf("XOF128 FAILED\r\n");
	}

	/* ---- Ascon-CXOF128 ----------------------------------------------- */
	kprintf("\r\n=== Ascon-CXOF128 ===\r\n");
	kprintf("Customization Z:\r\n");
	rfc_hexdump(z, z_len);
	kprintf("Message:\r\n");
	rfc_hexdump(name, name_len);

	rc = ascon_cxof128(z, z_len, name, name_len, cxof_out, 32);
	if (rc == ASCON_OK) {
		kprintf("Output (32 bytes):\r\n");
		rfc_hexdump(cxof_out, 32);
	} else {
		kprintf("CXOF128 FAILED\r\n");
	}

	/* ---- Ascon-AEAD128 encrypt --------------------------------------- */
	kprintf("\r\n=== Ascon-AEAD128 encrypt ===\r\n");
	kprintf("Key:\r\n");
	rfc_hexdump(key, 16);
	kprintf("Nonce:\r\n");
	rfc_hexdump(npub, 16);
	kprintf("Associated Data:\r\n");
	rfc_hexdump(ad, ad_len);
	kprintf("Plaintext:\r\n");
	rfc_hexdump(name, name_len);

	rc = ascon_aead128_encrypt(key, npub, ad, ad_len,
	                           name, name_len, ct, tag);
	if (rc == ASCON_OK) {
		kprintf("Ciphertext:\r\n");
		rfc_hexdump(ct, name_len);
		kprintf("Tag:\r\n");
		rfc_tag(tag, ASCON_AEAD_TAG_LEN);

		/* ---- Ascon-AEAD128 decrypt ---------------------------------- */
		kprintf("\r\n=== Ascon-AEAD128 decrypt ===\r\n");
		kprintf("Ciphertext:\r\n");
		rfc_hexdump(ct, name_len);
		kprintf("Tag:\r\n");
		rfc_tag(tag, ASCON_AEAD_TAG_LEN);

		rc = ascon_aead128_decrypt(key, npub, ad, ad_len,
		                           ct, name_len, pt, tag);
		if (rc == ASCON_OK) {
			kprintf("Plaintext recovered:\r\n");
			rfc_hexdump(pt, name_len);
			kprintf("Authentication: OK\r\n");
		} else {
			kprintf("AUTH FAILED\r\n");
		}
	} else {
		kprintf("Encrypt FAILED\r\n");
	}

	kprintf("\r\nDone.\r\n");
	for (;;)
		;
}
