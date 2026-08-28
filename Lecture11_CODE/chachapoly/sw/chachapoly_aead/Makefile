# Fused ChaCha20-Poly1305 AEAD demo — RV32, 128 kB scratchpad at 0x80000000.
#
# Target SoC: SmallRocket32ChachaPolyAeadArty100TConfig
#             (AEAD_chacha_poly @ 0x6400A000)
#
#   make                     -> build/main.elf, build/main.bin, build/main.dump
#   RISCV=/path make         -> override toolchain prefix
#
# Load the .bin the same way as the other fpga/sw payloads for this board
# (SD card via the sdboot bootrom, or JTAG).

ROOT_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

SRCDIR  = $(ROOT_DIR)src
OBJDIR  = $(ROOT_DIR)obj
BINDIR  = $(ROOT_DIR)build
LINKDIR = $(ROOT_DIR)linker

RISCV   ?= /home/khaiduy/opt/riscv
CROSS   = $(RISCV)/bin/riscv64-unknown-elf-
CC      = $(CROSS)gcc
OBJCOPY = $(CROSS)objcopy
OBJDUMP = $(CROSS)objdump
SIZE    = $(CROSS)size

ARCH    = -march=rv32imac_zicsr_zifencei -mabi=ilp32 -mcmodel=medany
# -fno-tree-loop-distribute-patterns matters here: that pass is on at -O2 and
# rewrites the byte-clearing loops in aead.c and main.c into calls to memset,
# which does not exist in a -nostdlib link. -fno-builtin alone does not disable
# it, because the rewrite happens in the loop optimiser rather than at a
# recognised builtin call site.
CFLAGS = $(CFLAGS_EXTRA) $(ARCH) -O2 -std=gnu11 -Wall -g \
         -ffunction-sections -fdata-sections -fno-common \
         -fno-builtin -fno-tree-loop-distribute-patterns \
         -nostartfiles -nostdlib \
         -I$(ROOT_DIR)/include \
         -I$(ROOT_DIR)/src
LFLAGS  = -static -Wl,--gc-sections -L $(LINKDIR) -T main.lds

CSOURCES = $(wildcard $(SRCDIR)/*.c)
SSOURCES = $(wildcard $(SRCDIR)/*.S)
COBJECTS = $(patsubst $(SRCDIR)/%.c, $(OBJDIR)/%.o, $(CSOURCES))
SOBJECTS = $(patsubst $(SRCDIR)/%.S, $(OBJDIR)/%.o, $(SSOURCES))

elf  := $(BINDIR)/main.elf
bin  := $(BINDIR)/main.bin
dump := $(BINDIR)/main.dump

.PHONY: default elf bin dump clean
default: elf bin dump
	@$(SIZE) $(elf)

$(OBJDIR)/%.o: $(SRCDIR)/%.c
	mkdir -p $(OBJDIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(OBJDIR)/%.o: $(SRCDIR)/%.S
	mkdir -p $(OBJDIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(elf): $(SOBJECTS) $(COBJECTS)
	mkdir -p $(BINDIR)
	$(CC) $(CFLAGS) $(LFLAGS) $^ -o $@

$(bin): $(elf)
	$(OBJCOPY) -O binary $< $@

$(dump): $(elf)
	$(OBJDUMP) -D -S $< > $@

elf:  $(elf)
bin:  $(bin)
dump: $(dump)

clean:
	rm -rf $(OBJDIR) $(BINDIR)
