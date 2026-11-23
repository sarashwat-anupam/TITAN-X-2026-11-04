/* SPDX-License-Identifier: Apache-2.0 */
OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY
{
    BOOT_ROM (rx)  : ORIGIN = 0x10000000, LENGTH = 8K
    SRAM     (rwx) : ORIGIN = 0x00000000, LENGTH = 64K
    DDR4     (rwx) : ORIGIN = 0x80000000, LENGTH = 32M
}

SECTIONS
{
    .text : {
        *(.text.init)
        *(.text .text.*)
    } > DDR4

    .rodata : {
        . = ALIGN(8);
        *(.rodata .rodata.*)
    } > DDR4

    .data : {
        . = ALIGN(8);
        *(.data .data.*)
    } > DDR4

    .tohost : {
        . = ALIGN(64);
        *(.tohost)
    } > DDR4

    .bss : {
        . = ALIGN(8);
        __bss_start = .;
        *(.bss .bss.*)
        *(COMMON)
        __bss_end = .;
    } > DDR4

    .stack : {
        . = ALIGN(16);
        . += 0x4000; /* 16KB stack */
        __stack_top = .;
    } > DDR4

    _end = .;
}
