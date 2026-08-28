/* 64 kB, deliberately conservative.
 *
 * SmallRocket32ChachaPolyConfig requests a 128 kB scratchpad and the build really
 * produces one (mems.conf: "mem_ext depth 32768 width 32" = 128 kB), so 0x20000
 * would be valid for this bitstream. 0x10000 is used anyway because:
 *
 *   - sdboot is built with SRAM_SIZE=0x10000 and parks its own stack at
 *     0x80010000, so 64 kB is the size the bootrom itself assumes;
 *   - the proven-good HW EDHOC firmware links against memory_m3.lds, which is
 *     also 0x10000 (see fpga/sw/edhoc/mk/targets.mk, M3_HW_LDFLAGS);
 *   - the payload is under 3 kB, so the smaller region costs nothing and the
 *     image also boots on an older 64 kB bitstream.
 *
 * crt0.S sets sp = _ram_end, so this directly determines the stack top.
 */
MEMORY
{
  memory_mem (rwx) : ORIGIN = 0x80000000, LENGTH = 0x10000
}
