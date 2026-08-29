.equ SPI_BASE,   0x10034000
.equ GPIO_BASE,  0x10012000
.equ MEMORY_BASE, 0x70000000
.eqv MEMORY_SIZE, (1 << 17) - 16
.equ CLK_MHZ, 50

.section .init
.global _start
_start:
    li sp, MEMORY_BASE+MEMORY_SIZE
    jal main
    j .

