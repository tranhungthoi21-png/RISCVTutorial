
RISCV_DIR=/home/binh/rv64itool/bin

all: program.bin program.lst program.vo



program.vo: out
	$(RISCV_DIR)/riscv64-unknown-elf-objcopy out -O verilog program.vo

program.bin: out
	$(RISCV_DIR)/riscv64-unknown-elf-objcopy out -O binary program.bin

program.lst: out
	$(RISCV_DIR)/riscv64-unknown-elf-objdump -Dr out > program.lst

out: crt.s main.c
	$(RISCV_DIR)/riscv64-unknown-elf-gcc -ffreestanding -nostartfiles -Os -march=rv64ima_zicsr -mabi=lp64 -Wl,-Ttext-segment=6FFFFF18 crt.s main.c -o out

clean:
	rm -rf *.o out program.lst program.bin program.mem firstStage.o program.vo

