/*
 * ChaCha20-Poly1305 + ASCON AEAD128
 *
 * SoC config : Tiny2RocketConfig
 *              AEAD_chacha_poly  @ 0x6400A000
 *              ascon_engine_std  @ 0x64008000
 *
 * Run 1: ChaCha20-Poly1305 encrypt -> decrypt -> verify tag
 * Run 2: Ascon-AEAD128    encrypt -> decrypt -> verify tag
 */

#include <stdint.h>
#include "platform.h"
#include "kprintf.h"
#include "aead.h"
#include "ascon.h"

#define REG32(p, i) ((p)[(i) >> 2])

/* ------------------------------------------------------------------------- */
/* Input                                                                      */
/* ------------------------------------------------------------------------- */

static const uint8_t  input[]   = "The University of Electro-Communications";
static const uint32_t input_len = 40;

/* ChaCha20-Poly1305 key / nonce / aad */
static const uint8_t chacha_key[32] = {
    0x80,0x81,0x82,0x83, 0x84,0x85,0x86,0x87,
    0x88,0x89,0x8A,0x8B, 0x8C,0x8D,0x8E,0x8F,
    0x90,0x91,0x92,0x93, 0x94,0x95,0x96,0x97,
    0x98,0x99,0x9A,0x9B, 0x9C,0x9D,0x9E,0x9F
};
static const uint8_t chacha_nonce[12] = {
    0x07,0x00,0x00,0x00,
    0x40,0x41,0x42,0x43,
    0x44,0x45,0x46,0x47
};
static const uint8_t  chacha_aad[]   = {
    0x50,0x51,0x52,0x53,
    0xC0,0xC1,0xC2,0xC3,
    0xC4,0xC5,0xC6,0xC7
};
static const uint32_t chacha_aad_len = 12;

/* ASCON key / nonce / aad */
static const uint8_t ascon_key[16] = {
    0x00,0x01,0x02,0x03, 0x04,0x05,0x06,0x07,
    0x08,0x09,0x0A,0x0B, 0x0C,0x0D,0x0E,0x0F
};
static const uint8_t ascon_npub[16] = {
    0x00,0x11,0x22,0x33, 0x44,0x55,0x66,0x77,
    0x88,0x99,0xAA,0xBB, 0xCC,0xDD,0xEE,0xFF
};
static const uint8_t  ascon_ad[]   = { 0x4B,0x32,0x34,0x00,0x00,0x00,0x00,0x00 };
static const uint32_t ascon_ad_len = 8;

/* ------------------------------------------------------------------------- */
/* Hex helpers                                                                */
/* ------------------------------------------------------------------------- */
static int bytes_equal(const uint8_t *a, const uint8_t *b, uint32_t len)
{
    for (uint32_t i = 0; i < len; i++)
        if (a[i] != b[i]) return 0;
    return 1;
}

/* ------------------------------------------------------------------------- */

int main(int hartid, char **argv)
{
    static uint8_t ct[64];
    static uint8_t pt_dec[64];
    static uint8_t tag[16];
    int rc, pt_match;

    REG32(uart, UART_REG_TXCTRL) = UART_TXEN;

    kprintf("Input: The University of Electro-Communications\r\n");

    /* Run 1: ChaCha20-Poly1305 */
    kprintf("\r\nRun 1: ChaCha20-Poly1305\r\n");

    rc = aead_encrypt(chacha_key, chacha_nonce,
                      chacha_aad, chacha_aad_len,
                      input, input_len, ct, tag);

    if (rc != AEAD_OK) { kprintf("Encrypt FAILED\r\n"); goto run2; }

    rc = aead_decrypt(chacha_key, chacha_nonce,
                      chacha_aad, chacha_aad_len,
                      ct, input_len, tag, pt_dec);

    pt_match = bytes_equal(pt_dec, input, input_len);
    kprintf("Tag verifies : %s\r\n", rc == AEAD_OK ? "OK" : "FAILED");
    kprintf("PT recovered : %s\r\n", pt_match ? "YES" : "NO");
    kprintf("Result       : %s\r\n", (rc == AEAD_OK && pt_match) ? "PASS" : "FAIL");

    /* Run 2: ASCON */
run2:
    kprintf("\r\nRun 2: Ascon AEAD128\r\n");

    rc = ascon_aead128_encrypt(ascon_key, ascon_npub,
                               ascon_ad, ascon_ad_len,
                               input, input_len, ct, tag);

    if (rc != ASCON_OK) { kprintf("Encrypt FAILED\r\n"); goto done; }

    rc = ascon_aead128_decrypt(ascon_key, ascon_npub,
                               ascon_ad, ascon_ad_len,
                               ct, input_len, pt_dec, tag);

    pt_match = bytes_equal(pt_dec, input, input_len);
    kprintf("Tag verifies : %s\r\n", rc == ASCON_OK ? "OK" : "FAILED");
    kprintf("PT recovered : %s\r\n", pt_match ? "YES" : "NO");
    kprintf("Result       : %s\r\n", (rc == ASCON_OK && pt_match) ? "PASS" : "FAIL");

done:
    kprintf("\r\nDone.\r\n");
    for (;;) {}
    return 0;
}
