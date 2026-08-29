#include <stdint.h>

void printChar(char c) {
	static volatile uint32_t* const UART_BASE = (volatile uint32_t*)0x10013000;
    UART_BASE[2] = 1;
    uint32_t probe_tx_fifo;
    do {
        probe_tx_fifo = UART_BASE[0];
    } while (probe_tx_fifo);
    UART_BASE[0] = c;
}


void printStr(const char* p) {
	while (*p) {
		printChar(*p++);
	}
}


static inline uint64_t mtime_read() {
	uint64_t ret;
	asm volatile ("csrr %0, time":"=r"(ret));
	return ret;
}
static const char map_table[] = {
	'0', '1', '2', '3', 
	'4', '5', '6', '7', 
	'8', '9', 'a', 'b', 
	'c', 'd', 'e', 'f'
};
void printHexU64(uint64_t x) {
	printStr("0x");
	for (int i = 60; i >= 0; i -= 4) {
		printChar(map_table[x >> i & 15]);
	}
}

void printHexU32_noX(uint64_t x) {
	for (int i = 28; i >= 0; i -= 4) {
		printChar(map_table[x >> i & 15]);
	}
}
void printHexU32(uint64_t x) {
	printStr("0x");
	for (int i = 28; i >= 0; i -= 4) {
		printChar(map_table[x >> i & 15]);
	}
}
void printHexU8(uint8_t x) {
	printStr("0x");
		printChar(map_table[x >> 4 & 15]);
		printChar(map_table[x >> 0 & 15]);

}


static inline uint32_t rotr32(uint32_t a, int s) {
	return (a >> s) | (a << (32-s));
}


void sha256_soft(uint8_t buffer[], uint64_t byte_length) {


	uint32_t h0 = 0x6a09e667;
	uint32_t h1 = 0xbb67ae85;
	uint32_t h2 = 0x3c6ef372;
	uint32_t h3 = 0xa54ff53a;
	uint32_t h4 = 0x510e527f;
	uint32_t h5 = 0x9b05688c;
	uint32_t h6 = 0x1f83d9ab;
	uint32_t h7 = 0x5be0cd19;

	const uint32_t k[64] = {
		0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
		0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
		0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
		0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
		0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
		0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
		0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
		0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
	};

// Pre-processing (Padding):
// begin with the original message of length L bits
// append a single '1' bit
// append K '0' bits, where K is the minimum number >= 0 such that (L + 1 + K + 64) is a multiple of 512
// append L as a 64-bit big-endian integer, making the total post-processed length a multiple of 512 bits
// such that the bits in the message are: ⟨original message of length L⟩ 1 ⟨K zeros⟩ ⟨L as 64 bit integer⟩ , (the number of bits will be a multiple of 512)
	const uint64_t length_le = 8*byte_length;
	buffer[byte_length++] = 0x80;
	while (byte_length < (512-64)/8) buffer[byte_length++] = 0x00;
	buffer[byte_length++] = length_le >> 56;
	buffer[byte_length++] = length_le >> 48;
	buffer[byte_length++] = length_le >> 40;
	buffer[byte_length++] = length_le >> 32;
	buffer[byte_length++] = length_le >> 24;
	buffer[byte_length++] = length_le >> 16;
	buffer[byte_length++] = length_le >> 8;
	buffer[byte_length++] = length_le >> 0;

	// Process the message in successive 512-bit chunks:
	// break message into 512-bit chunks
	// for each chunk
	uint64_t soft_start = mtime_read();
	{
		// create a 64-entry message schedule array w[0..63] of 32-bit words
		// (The initial values in w[0..63] don't matter, so many implementations zero them here)
		// copy chunk into first 16 words w[0..15] of the message schedule array
		uint32_t w[64];
		for (int i = 0; i < 16; ++i) {
			w[i] =
				((uint32_t)buffer[i * 4 + 0] << 24) |
				((uint32_t)buffer[i * 4 + 1] << 16) |
				((uint32_t)buffer[i * 4 + 2] << 8)  |
				((uint32_t)buffer[i * 4 + 3]);
		}

		// Extend the first 16 words into the remaining 48 words w[16..63] of the message schedule array:
		for (int i = 16; i < 64; ++i) {
			uint32_t s0 = rotr32(w[i-15], 7) ^ rotr32(w[i-15], 18) ^ (w[i-15] >> 3);
			uint32_t s1 = rotr32(w[i-2], 17) ^ rotr32(w[i-2], 19) ^ (w[i-2] >> 10);
			w[i] = w[i-16] + s0 + w[i-7] + s1;
		}
		uint32_t a = h0; uint32_t b = h1; uint32_t c = h2; uint32_t d = h3;
		uint32_t e = h4; uint32_t f = h5; uint32_t g = h6; uint32_t h = h7;

		for (int i = 0; i < 64; ++i) {
			uint32_t S1 = rotr32(e, 6) ^ rotr32(e, 11) ^ rotr32(e, 25);
			uint32_t ch = (e & f) ^ ((~e) & g);
			uint32_t temp1 = h + S1 + ch + k[i] + w[i];
			uint32_t S0 = rotr32(a, 2) ^ rotr32(a, 13) ^ rotr32(a, 22);
			uint32_t maj = (a & b) ^ (a & c) ^ (b & c);
			uint32_t temp2 = S0 + maj;
	
			h = g; g = f; f = e; e = d + temp1;
			d = c; c = b; b = a; a = temp1 + temp2;
		}
		h0 = h0 + a; h1 = h1 + b;
		h2 = h2 + c; h3 = h3 + d;
		h4 = h4 + e; h5 = h5 + f;
		h6 = h6 + g; h7 = h7 + h;
	}
	uint64_t soft_end = mtime_read();
	printStr("\r\n Number of time using software sha256: ");
	printHexU64(soft_end - soft_start);
	printStr("\r\n");
	printHexU32_noX(h0);
	printHexU32_noX(h1);
	printHexU32_noX(h2);
	printHexU32_noX(h3);
	printHexU32_noX(h4);
	printHexU32_noX(h5);
	printHexU32_noX(h6);
	printHexU32_noX(h7);
}


void sha256_hard(uint8_t buffer[], uint64_t byte_length) {


	const uint64_t length_le = 8*byte_length;
	buffer[byte_length++] = 0x80;
	while (byte_length < (512-64)/8) buffer[byte_length++] = 0x00;
	buffer[byte_length++] = length_le >> 56;
	buffer[byte_length++] = length_le >> 48;
	buffer[byte_length++] = length_le >> 40;
	buffer[byte_length++] = length_le >> 32;
	buffer[byte_length++] = length_le >> 24;
	buffer[byte_length++] = length_le >> 16;
	buffer[byte_length++] = length_le >> 8;
	buffer[byte_length++] = length_le >> 0;

	static volatile uint32_t* const SHA256_BASE = (volatile uint32_t*)0x67000000;
	uint64_t hard_start = mtime_read();
	{
		// create a 64-entry message schedule array w[0..63] of 32-bit words
		// (The initial values in w[0..63] don't matter, so many implementations zero them here)
		// copy chunk into first 16 words w[0..15] of the message schedule array
		uint32_t w[16];
		for (int i = 0; i < 16; ++i) {
			w[i] =
				((uint32_t)buffer[i * 4 + 0] << 24) |
				((uint32_t)buffer[i * 4 + 1] << 16) |
				((uint32_t)buffer[i * 4 + 2] << 8)  |
				((uint32_t)buffer[i * 4 + 3]);
			SHA256_BASE[8] = w[i];
		}
		while (SHA256_BASE[8] == 0) { }

	}

	uint64_t hard_end = mtime_read();
	printStr("\r\n  Number of time using hardware sha256: ");
	printHexU64(hard_end - hard_start);
	printStr("\r\n");

	printHexU32_noX(SHA256_BASE[0]);
	printHexU32_noX(SHA256_BASE[1]);
	printHexU32_noX(SHA256_BASE[2]);
	printHexU32_noX(SHA256_BASE[3]);
	printHexU32_noX(SHA256_BASE[4]);
	printHexU32_noX(SHA256_BASE[5]);
	printHexU32_noX(SHA256_BASE[6]);
	printHexU32_noX(SHA256_BASE[7]);
}


int main() {
	printStr("\r\nSHA256 benchmark\r\n");
	uint8_t message[64];
	message[0] = 'a';
	message[1] = 'b';
	message[2] = 'c';
	sha256_hard(message, 3);

	sha256_soft(message, 3);
	return 0;
}
