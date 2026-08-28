#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>

//======================== Keccak Registers ==================================
#define REG_KECCAK_RESET            0x00
#define REG_KECCAK_WRITE_ENABLE     0x08
#define REG_KECCAK_WRITE_DATA       0x10
#define REG_KECCAK_DATA_LEN         0x18
#define REG_KECCAK_END_PACKET       0x20
#define REG_KECCAK_FIN_PACKET       0x28
#define REG_KECCAK_IN_READY         0x30
#define REG_KECCAK_READ_ENABLE      0x38
#define REG_KECCAK_READ_DONE        0x40
#define REG_KECCAK_READ_DATA        0x48
#define REG_KECCAK_OUT_VALID        0x50
#define REG_KECCAK_OUT_READY        0x58
#define REG_KECCAK_MODE             0x60

#define SHA3_224    0
#define SHA3_256    1
#define SHA3_512    2
#define SHAKE128    3
#define SHAKE256    4

// Macro truy xu?t thanh ghi 64-bit an toàn
#define _REG64(base, offset) (*(volatile uint64_t *)((uintptr_t)(base) + (offset)))

void keccak_reset(volatile void *keccakCtrl){
    _REG64(keccakCtrl, REG_KECCAK_END_PACKET) = 0x0000000000000000;
    _REG64(keccakCtrl, REG_KECCAK_FIN_PACKET)  = 0x0000000000000000;
    _REG64(keccakCtrl, REG_KECCAK_RESET)       = 0x0000000000000001;
    for(volatile int i = 0; i < 100; i++){};
    _REG64(keccakCtrl, REG_KECCAK_RESET)       = 0x0000000000000000;
}

void keccak_config(volatile void *keccakCtrl, uint64_t mode, uint64_t len){
    _REG64(keccakCtrl, REG_KECCAK_MODE)      = mode;
    _REG64(keccakCtrl, REG_KECCAK_DATA_LEN) = len;
}

void keccak_write_data(volatile void *keccakCtrl, uint64_t mode, uint64_t *data, int len){
    int line;
         if(mode == 0) line = 18;
    else if(mode == 1) line = 17;
    else if(mode == 2) line = 9;
    else if(mode == 3) line = 21;
    else if(mode == 4) line = 17;
    else                line = 17;

    for (int j = 0; j < ((len >> 3)/line); j++){
        _REG64(keccakCtrl, REG_KECCAK_END_PACKET) = 0x0000000000000000;
        for (int i = (j*line); i < (j+1)*line; i++){
            int timeout = 1000000;
            while(!(_REG64(keccakCtrl, REG_KECCAK_IN_READY))){
                timeout--;
                if (timeout == 0) {
                    printf("ERROR: Timeout waiting for IN_READY in keccak_write_data (mode=%d, i=%d)!\n", (int)mode, i);
                    while(1);
                }
            };
            _REG64(keccakCtrl, REG_KECCAK_WRITE_DATA)   = data[i];
            _REG64(keccakCtrl, REG_KECCAK_WRITE_ENABLE) = 0x0000000000000001;
            _REG64(keccakCtrl, REG_KECCAK_WRITE_ENABLE) = 0x0000000000000000;
        }
        _REG64(keccakCtrl, REG_KECCAK_END_PACKET)  = 0x0000000000000001;
    }
}

void keccak_write_last_data(volatile void *keccakCtrl, uint64_t mode, uint64_t *data, int len){
    int line;
         if(mode == 0) line = 18;
    else if(mode == 1) line = 17;
    else if(mode == 2) line = 9;
    else if(mode == 3) line = 21;
    else if(mode == 4) line = 17;
    else                line = 17;

   _REG64(keccakCtrl, REG_KECCAK_END_PACKET) = 0x0000000000000000;
   for (int i = ((len >> 3)/line) * line; i < (len >> 3) ; i++){
        int timeout = 1000000;
        while(!(_REG64(keccakCtrl, REG_KECCAK_IN_READY))){
            timeout--;
            if (timeout == 0) {
                printf("ERROR: Timeout waiting for IN_READY in keccak_write_last_data (mode=%d, i=%d)!\n", (int)mode, i);
                while(1);
            }
        };
        _REG64(keccakCtrl, REG_KECCAK_WRITE_DATA)   = data[i];
        _REG64(keccakCtrl, REG_KECCAK_WRITE_ENABLE) = 0x0000000000000001;
        _REG64(keccakCtrl, REG_KECCAK_WRITE_ENABLE) = 0x0000000000000000;
   }
   _REG64(keccakCtrl, REG_KECCAK_FIN_PACKET)  = 0x0000000000000001;
}

void keccak_read_data(volatile void *keccakCtrl, uint64_t *hash, int len) {
    int timeout = 1000000;
    while(!(_REG64(keccakCtrl, REG_KECCAK_OUT_VALID))) {
        timeout--;
        if (timeout == 0) {
            printf("ERROR: Timeout waiting for OUT_VALID (current mode)!\n");
            while(1);
        }
    };

    for (int i = 0; i < len; i++){
         _REG64(keccakCtrl, REG_KECCAK_READ_ENABLE)  = 0x0000000000000001;
         _REG64(keccakCtrl, REG_KECCAK_READ_ENABLE)  = 0x0000000000000000;
         while(!(_REG64(keccakCtrl, REG_KECCAK_OUT_READY))){};
         hash[i] = _REG64(keccakCtrl, REG_KECCAK_READ_DATA);
    }
    _REG64(keccakCtrl, REG_KECCAK_FIN_PACKET)  = 0x0000000000000000;
}

void keccak_read_done(volatile void *keccakCtrl){
    _REG64(keccakCtrl, REG_KECCAK_READ_DONE) = 0x0000000000000001;
    _REG64(keccakCtrl, REG_KECCAK_READ_DONE) = 0x0000000000000000;
}

void keccak_hash_again(volatile void *keccakCtrl){
    _REG64(keccakCtrl, REG_KECCAK_FIN_PACKET)  = 0x0000000000000001;
}

// D? li?u d?u vào: "TRAN HUNG THOI" (14 bytes = 112 bits) chuy?n sang Little-Endian 64-bit
uint64_t input_keccak[25] = {
    0x4E5548204E415254ULL, // "TRAN HUNG"
    0x0000494F48542047ULL  // " THOI" + padding 0
};

uint64_t hash[25];
volatile void *keccakCtrl = (void *)0x64004000;

int main(int hartid, char **argv) {
    printf("=================================================\n");
    printf("========= IV. TESTING KECCAK FUNCTIONS ==========\n");
    printf("=================================================\n");

    printf("Input values:\n");
    for(int i = 0; i < 2; i++){ // Ch? in 2 ph?n t? d?u có ch?a d? li?u tên
        printf("Input[%d] = 0x%016lx\n", i, input_keccak[i]);
    }
    printf("\n");

    int line, mode;
    int len = 112; // Chi?u dài thông di?p c?a chu?i "TRAN HUNG THOI" (14 bytes * 8 = 112 bits)
    int hash_len;

    // --- 4.1. SHA3-224 ---
    printf("========= 4.1. TESTING SHA3-224 ==========\n");
    printf("Reset\n");
    printf("Set mode and len\n");
    printf("Reading the hash value\n");
    mode = SHA3_224;
    hash_len = 4; 
    line = 18;
    keccak_reset(keccakCtrl);
    keccak_config(keccakCtrl, mode, len);

    if((len >> 3) >= line){
        keccak_write_data(keccakCtrl, mode, input_keccak, len);
    }
    keccak_write_last_data(keccakCtrl, mode, input_keccak, len);

    keccak_read_data(keccakCtrl, hash, hash_len);
    for(int i = 0; i < hash_len; i++){
        printf("Hash[%d] = 0x%016lx\n", i, hash[i]);
    }
    keccak_read_done(keccakCtrl);
    printf("\n");

    // --- 4.2. SHA3-256 ---
    printf("========= 4.2 TESTING SHA3-256 ==========\n");
    printf("Reset\n");
    printf("Set mode and len\n");
    printf("Reading the hash value\n");
    mode = SHA3_256;
    hash_len = 4; 
    line = 17;
    keccak_reset(keccakCtrl);
    keccak_config(keccakCtrl, mode, len);

    if((len >> 3) >= line){
        keccak_write_data(keccakCtrl, mode, input_keccak, len);
    }
    keccak_write_last_data(keccakCtrl, mode, input_keccak, len);

    keccak_read_data(keccakCtrl, hash, hash_len);
    for(int i = 0; i < hash_len; i++){
        printf("Hash[%d] = 0x%016lx\n", i, hash[i]);
    }
    keccak_read_done(keccakCtrl);
    printf("\n");

    // --- 4.3. SHA3-512 ---
    printf("========= 4.3 TESTING SHA3-512 ==========\n");
    printf("Reset\n");
    printf("Set mode and len\n");
    printf("Reading the hash value\n");
    mode = SHA3_512;
    hash_len = 8; 
    line = 9;
    keccak_reset(keccakCtrl);
    keccak_config(keccakCtrl, mode, len);

    if((len >> 3) >= line){
        keccak_write_data(keccakCtrl, mode, input_keccak, len);
    }
    keccak_write_last_data(keccakCtrl, mode, input_keccak, len);

    keccak_read_data(keccakCtrl, hash, hash_len);
    for(int i = 0; i < hash_len; i++){
        printf("Hash[%d] = 0x%016lx\n", i, hash[i]);
    }
    keccak_read_done(keccakCtrl);
    printf("\n");

    // --- 4.4. SHAKE128 ---
    printf("========= 4.4 TESTING SHAKE-128 ==========\n");
    mode = SHAKE128;
    line = 21;

    // SHAKE128 - L?n d?c 1
    printf("Reset\n");
    printf("Set mode and len\n");
    printf("Reading the hash value\n");
    hash_len = 21;
    keccak_reset(keccakCtrl);
    keccak_config(keccakCtrl, mode, len);
    if((len >> 3) >= line) keccak_write_data(keccakCtrl, mode, input_keccak, len);
    keccak_write_last_data(keccakCtrl, mode, input_keccak, len);
    keccak_read_data(keccakCtrl, hash, hash_len);
    for(int i = 0; i < hash_len; i++) printf("Hash[%d] = 0x%016lx\n", i, hash[i]);
    keccak_read_done(keccakCtrl);
    printf("\n");

    // SHAKE128 - L?n d?c 2
    printf("Reading the hash value\n");
    hash_len = 21;
    keccak_hash_again(keccakCtrl);
    keccak_read_data(keccakCtrl, hash, hash_len);
    for(int i = 0; i < hash_len; i++) printf("Hash[%d] = 0x%016lx\n", i, hash[i]);
    keccak_read_done(keccakCtrl);
    printf("\n");

    // SHAKE128 - L?n d?c 3
    printf("Reading the hash value\n");
    hash_len = 21;
    keccak_hash_again(keccakCtrl);
    keccak_read_data(keccakCtrl, hash, hash_len);
    for(int i = 0; i < hash_len; i++) printf("Hash[%d] = 0x%016lx\n", i, hash[i]);
    keccak_read_done(keccakCtrl);
    printf("\n");

    // SHAKE128 - L?n d?c 4
    printf("Reading the hash value\n");
    hash_len = 1;
    keccak_hash_again(keccakCtrl);
    keccak_read_data(keccakCtrl, hash, hash_len);
    for(int i = 0; i < hash_len; i++) printf("Hash[%d] = 0x%016lx\n", i, hash[i]);
    keccak_read_done(keccakCtrl);
    printf("\n");

    // --- 4.5. SHAKE256 ---
    printf("========= 4.5 TESTING SHAKE-256 ==========\n");
    mode = SHAKE256;
    line = 17;

    // SHAKE256 - L?n d?c 1
    printf("Reset\n");
    printf("Set mode and len\n");
    printf("Reading the hash value\n");
    hash_len = 17;
    keccak_reset(keccakCtrl);
    keccak_config(keccakCtrl, mode, len);
    if((len >> 3) >= line) keccak_write_data(keccakCtrl, mode, input_keccak, len);
    keccak_write_last_data(keccakCtrl, mode, input_keccak, len);
    keccak_read_data(keccakCtrl, hash, hash_len);
    for(int i = 0; i < hash_len; i++) printf("Hash[%d] = 0x%016lx\n", i, hash[i]);
    keccak_read_done(keccakCtrl);
    printf("\n");

    // SHAKE256 - L?n d?c 2
    printf("Reading the hash value\n");
    hash_len = 17;
    keccak_hash_again(keccakCtrl);
    keccak_read_data(keccakCtrl, hash, hash_len);
    for(int i = 0; i < hash_len; i++) printf("Hash[%d] = 0x%016lx\n", i, hash[i]);
    keccak_read_done(keccakCtrl);
    printf("\n");

    // SHAKE256 - L?n d?c 3
    printf("Reading the hash value\n");
    hash_len = 17;
    keccak_hash_again(keccakCtrl);
    keccak_read_data(keccakCtrl, hash, hash_len);
    for(int i = 0; i < hash_len; i++) printf("Hash[%d] = 0x%016lx\n", i, hash[i]);
    keccak_read_done(keccakCtrl);
    printf("\n");

    // SHAKE256 - L?n d?c 4
    printf("Reading the hash value\n");
    hash_len = 13;
    keccak_hash_again(keccakCtrl);
    keccak_read_data(keccakCtrl, hash, hash_len);
    for(int i = 0; i < hash_len; i++) printf("Hash[%d] = 0x%016lx\n", i, hash[i]);
    keccak_read_done(keccakCtrl);
    printf("\n");

    while (1){ }
    return 0;
}
