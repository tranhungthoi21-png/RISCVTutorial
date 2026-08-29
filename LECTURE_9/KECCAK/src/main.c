#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
//#include <time.h>
#include <riscv-pk/encoding.h>
#include "platform.h"
#include "kprintf.h"
#include "uart.h"
#define REG32(p, i)	((p)[(i) >> 2])

//======================== Keccak ================================================
#define REG_KECCAK_RESET           0x00
#define REG_KECCAK_WRITE_ENABLE    0x08
#define REG_KECCAK_WRITE_DATA      0x10
#define REG_KECCAK_DATA_LEN        0x18
#define REG_KECCAK_END_PACKET      0x20
#define REG_KECCAK_FIN_PACKET      0x28
#define REG_KECCAK_IN_READY        0x30
#define REG_KECCAK_READ_ENABLE     0x38
#define REG_KECCAK_READ_DONE       0x40
#define REG_KECCAK_READ_DATA       0x48
#define REG_KECCAK_OUT_VALID       0x50
#define REG_KECCAK_OUT_READY       0x58
#define REG_KECCAK_MODE            0x60

#define SHA3_224    0
#define SHA3_256    1
#define SHA3_512    2
#define SHAKE128    3
#define SHAKE256    4

void keccak_reset(void *keccakCtrl){
    _REG64((char *)keccakCtrl, REG_KECCAK_END_PACKET) = 0x0000000000000000;
    _REG64((char *)keccakCtrl, REG_KECCAK_FIN_PACKET)  = 0x0000000000000000;
    _REG64((char *)keccakCtrl, REG_KECCAK_RESET) = 0x0000000000000001;
    for(int i = 0; i < 100; i++){};
    _REG64((char *)keccakCtrl, REG_KECCAK_RESET) = 0x0000000000000000;
}

void keccak_config(void *keccakCtrl, uint64_t mode, uint64_t len){
    _REG64((char *)keccakCtrl, REG_KECCAK_MODE) = mode;
    _REG64((char *)keccakCtrl, REG_KECCAK_DATA_LEN) = len;
}

void keccak_write_data(void *keccakCtrl, uint64_t mode, uint64_t *data, int len){
   int line;
        if(mode == 0) line = 18;
   else if(mode == 1) line = 17;
   else if(mode == 2) line = 9;
   else if(mode == 3) line = 21;
   else if(mode == 4) line = 17;
   else               line = 17;

    for (int j = 0; j < ((len >> 3)/line); j++){
        _REG64((char *)keccakCtrl, REG_KECCAK_END_PACKET) = 0x0000000000000000;
        for (int i = (j*line); i < (j+1)*line; i++){
            while(!(_REG64((char *)keccakCtrl, REG_KECCAK_IN_READY))){};
            _REG64((char *)keccakCtrl, REG_KECCAK_WRITE_DATA)       = data[i];
            _REG64((char *)keccakCtrl, REG_KECCAK_WRITE_ENABLE)     = 0x0000000000000001;
            _REG64((char *)keccakCtrl, REG_KECCAK_WRITE_ENABLE)     = 0x0000000000000000;
        }
        _REG64((char *)keccakCtrl, REG_KECCAK_END_PACKET)  = 0x0000000000000001;
    }
}


void keccak_write_last_data(void *keccakCtrl, uint64_t mode, uint64_t *data, int len){
    int line;
         if(mode == 0) line = 18;
    else if(mode == 1) line = 17;
    else if(mode == 2) line = 9;
    else if(mode == 3) line = 21;
    else if(mode == 4) line = 17;
    else               line = 17;

   _REG64((char *)keccakCtrl, REG_KECCAK_END_PACKET) = 0x0000000000000000;
   for (int i = ((len >> 3)/line) * line; i < (len >> 3) ; i++){
       while(!(_REG64((char *)keccakCtrl, REG_KECCAK_IN_READY))){};
//       kprintf("send the block %d-th\r\n", i);
       _REG64((char *)keccakCtrl, REG_KECCAK_WRITE_DATA)       = data[i];
       _REG64((char *)keccakCtrl, REG_KECCAK_WRITE_ENABLE)     = 0x0000000000000001;
       _REG64((char *)keccakCtrl, REG_KECCAK_WRITE_ENABLE)     = 0x0000000000000000;
   }
   _REG64((char *)keccakCtrl, REG_KECCAK_FIN_PACKET)  = 0x0000000000000001;
}

void keccak_read_data(void *keccakCtrl, uint64_t *hash, int len) {
   while(!(_REG64((char *)keccakCtrl, REG_KECCAK_OUT_VALID))){};
   for (int i = 0; i < len; i++){
        _REG64((char *)keccakCtrl, REG_KECCAK_READ_ENABLE)     = 0x0000000000000001;
        _REG64((char *)keccakCtrl, REG_KECCAK_READ_ENABLE)     = 0x0000000000000000;
        while(!(_REG64((char *)keccakCtrl, REG_KECCAK_OUT_READY))){};
        hash[i] = _REG64((char *)keccakCtrl, REG_KECCAK_READ_DATA);
   };
   _REG64((char *)keccakCtrl, REG_KECCAK_FIN_PACKET)  = 0x0000000000000000;
}

void keccak_read_done(void *keccakCtrl){
    _REG64((char *)keccakCtrl, REG_KECCAK_READ_DONE) = 0x0000000000000001;
    _REG64((char *)keccakCtrl, REG_KECCAK_READ_DONE) = 0x0000000000000000;
}

void keccak_hash_again(void *keccakCtrl){
    _REG64((char *)keccakCtrl, REG_KECCAK_FIN_PACKET)  = 0x0000000000000001;
}


uint64_t input_keccak[25] = {
    0x4E5548204E415254ULL, // "TRAN HUNG"
    0x0000494F48542047ULL  // " THOI" + padding 0
};

uint64_t hash[21];
uint64_t keccakCtrl = (uint64_t *)0x64005000;

int main(int hartid, char **argv) {
  REG32(uart, UART_REG_TXCTRL) = UART_TXEN;
unsigned long start, end;


  kprintf("=================================================\r\n");
  kprintf("========= IV. TESTING KECCAK FUNCTIONS ==========\n\r");
  kprintf("=================================================\r\n");

  kprintf("Input values:\r\n");
  for(int i = 0; i < 25; i++){
     kprintf("Input[%l] = 0x%x\r\n", i, input_keccak[i]);
  }

  int line, mode;
  int len = 200;
  int hash_len;
  kprintf("==========================================\r\n");
  kprintf("========= 4.1. TESTING SHA3-224 ==========\n\r");
  kprintf("=========================================\r\n");

  mode = SHA3_224;
  hash_len = 4;
  line = 18;
  keccak_reset(keccakCtrl);
  kprintf("Reset\r\n");
  keccak_config(keccakCtrl, mode, len);
  kprintf("Set mode and len\r\n");

  if((len >> 3) >= line){
    keccak_write_data(keccakCtrl, mode, input_keccak, len);
  }
    keccak_write_last_data(keccakCtrl, mode, input_keccak, len);

//-----------------------------------------------------------
  keccak_read_data(keccakCtrl, hash, hash_len);
  kprintf("Reading the hash value\r\n");
  for(int i = 0; i < hash_len; i++){
     kprintf("Hash[%l] = 0x%x\r\n", i, hash[i]);
  }
  keccak_read_done(keccakCtrl);
    kprintf("\r\n");

  kprintf("=========================================\r\n");
  kprintf("========= 4.2 TESTING SHA3-256 ==========\n\r");
  kprintf("=========================================\r\n");
  mode = SHA3_256;
  hash_len = 4;
  line = 17;
  keccak_reset(keccakCtrl);
  kprintf("Reset\r\n");
  keccak_config(keccakCtrl, mode, len);
  kprintf("Set mode and len\r\n");

  if((len >> 3) >= line){
    keccak_write_data(keccakCtrl, mode, input_keccak, len);
  }
    keccak_write_last_data(keccakCtrl, mode, input_keccak, len);

  keccak_read_data(keccakCtrl, hash, hash_len);
  kprintf("Reading the hash value\r\n");
  for(int i = 0; i < hash_len; i++){
     kprintf("Hash[%l] = 0x%x\r\n", i, hash[i]);
  }
  keccak_read_done(keccakCtrl);
    kprintf("\r\n");

  kprintf("========================================\r\n");
  kprintf("========= 4.3 TESTING SHA3-512 =========\n\r");
  kprintf("========================================\r\n");
  mode = SHA3_512;
  hash_len = 8;
  line = 9;
  keccak_reset(keccakCtrl);
  kprintf("Reset\r\n");
  keccak_config(keccakCtrl, mode, len);
  kprintf("Set mode and len\r\n");

  if((len >> 3) >= line){
    keccak_write_data(keccakCtrl, mode, input_keccak, len);
  }
    keccak_write_last_data(keccakCtrl, mode, input_keccak, len);

  keccak_read_data(keccakCtrl, hash, hash_len);
  kprintf("Reading the hash value\r\n");
  for(int i = 0; i < hash_len; i++){
     kprintf("Hash[%l] = 0x%x\r\n", i, hash[i]);
  }
  keccak_read_done(keccakCtrl);
  kprintf("\r\n");

  kprintf("=========================================\r\n");
  kprintf("========= 4.4 TESTING SHAKE-128 =========\n\r");
  kprintf("=========================================\r\n");
  mode = SHAKE128;
  hash_len = 21;
  line = 21;
  keccak_reset(keccakCtrl);
  kprintf("Reset\r\n");
  keccak_config(keccakCtrl, mode, len);
  kprintf("Set mode and len\r\n");

  if((len >> 3) >= line){
    keccak_write_data(keccakCtrl, mode, input_keccak, len);
  }
    keccak_write_last_data(keccakCtrl, mode, input_keccak, len);

//-----------------------------------------------------------
  keccak_read_data(keccakCtrl, hash, hash_len);
  kprintf("Reading the hash value\r\n");
  for(int i = 0; i < hash_len; i++){
     kprintf("Hash[%l] = 0x%x\r\n", i, hash[i]);
  }
  keccak_read_done(keccakCtrl);
////-----------------------------------------------------------
  keccak_hash_again(keccakCtrl);
  keccak_read_data(keccakCtrl, hash, hash_len);
  kprintf("Reading the hash value\r\n");
  for(int i = 0; i < hash_len; i++){
     kprintf("Hash[%l] = 0x%x\r\n", i, hash[i]);
  }
  keccak_read_done(keccakCtrl);
////-----------------------------------------------------------
  keccak_hash_again(keccakCtrl);
  keccak_read_data(keccakCtrl, hash, hash_len);
  kprintf("Reading the hash value\r\n");
  for(int i = 0; i < hash_len; i++){
     kprintf("Hash[%l] = 0x%x\r\n", i, hash[i]);
  }
  keccak_read_done(keccakCtrl);
////-----------------------------------------------------------
  keccak_hash_again(keccakCtrl);
  keccak_read_data(keccakCtrl, hash, hash_len);
  kprintf("Reading the hash value\r\n");
  for(int i = 0; i < hash_len; i++){
     kprintf("Hash[%d] = 0x%x\r\n", i, hash[i]);
  }
  keccak_read_done(keccakCtrl);
  kprintf("\r\n");

  kprintf("=========================================\r\n");
  kprintf("========= 4.5 TESTING SHAKE-256 =========\n\r");
  kprintf("=========================================\r\n");
  mode = SHAKE256;
  hash_len = 17;
  line = 17;
  keccak_reset(keccakCtrl);
  kprintf("Reset\r\n");
  keccak_config(keccakCtrl, mode, len);
  kprintf("Set mode and len\r\n");

  if((len >> 3) >= line){
    keccak_write_data(keccakCtrl, mode, input_keccak, len);
  }
    keccak_write_last_data(keccakCtrl, mode, input_keccak, len);

//-----------------------------------------------------------
  keccak_read_data(keccakCtrl, hash, hash_len);
  kprintf("Reading the hash value\r\n");
  for(int i = 0; i < hash_len; i++){
     kprintf("Hash[%l] = 0x%x\r\n", i, hash[i]);
  }
  keccak_read_done(keccakCtrl);
////-----------------------------------------------------------
  keccak_hash_again(keccakCtrl);
  keccak_read_data(keccakCtrl, hash, hash_len);
  kprintf("Reading the hash value\r\n");
  for(int i = 0; i < hash_len; i++){
     kprintf("Hash[%l] = 0x%x\r\n", i, hash[i]);
  }
  keccak_read_done(keccakCtrl);
////-----------------------------------------------------------
  keccak_hash_again(keccakCtrl);
  keccak_read_data(keccakCtrl, hash, hash_len);
  kprintf("Reading the hash value\r\n");
  for(int i = 0; i < hash_len; i++){
     kprintf("Hash[%l] = 0x%x\r\n", i, hash[i]);
  }
  keccak_read_done(keccakCtrl);
////-----------------------------------------------------------
  keccak_hash_again(keccakCtrl);
  keccak_read_data(keccakCtrl, hash, hash_len);
  kprintf("Reading the hash value\r\n");
  for(int i = 0; i < hash_len; i++){
     kprintf("Hash[%d] = 0x%x\r\n", i, hash[i]);
  }
  keccak_read_done(keccakCtrl);

  while (1){ }

  return 0;
}