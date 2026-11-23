/* SPDX-License-Identifier: Apache-2.0 */
/* TITAN-X Clean-Room Verification: Sv39 Virtual Memory, PTW & TLB Shootdown */

#include "../test_macros.h"

INIT_TEST

    /* ----------------------------------------------------------------- */
    /* Step 1: Set up Root Page Table (Sv39 3-level Gigapage Identity)   */
    /* Allocate 4KB aligned page table in BSS/Data section               */
    /* ----------------------------------------------------------------- */
    la   s0, page_table_l2      /* Physical base of Root Level 2 PT */
    
    /* Zero out 512 entries (4096 bytes) */
    li   t0, 512
    mv   t1, s0
1:  sd   x0, 0(t1)
    addi t1, t1, 8
    addi t0, t0, -1
    bnez t0, 1b

    /* Entry 0: Identity map 0x00000000 - 0x3FFFFFFF (SRAM, BootROM, CLINT, PLIC) */
    /* PPN = 0, Flags = D | A | X | W | R | V (0xEF) */
    li   t2, 0x00000000000000EF
    sd   t2, 0(s0)              /* Entry 0: VPN2 = 0 */

    /* Entry 1: Identity map 0x40000000 - 0x7FFFFFFF (Peripherals, UART0) */
    /* PPN = 0x40000000 >> 12 = 0x40000, Flags = 0xEF */
    /* PTE = (0x40000 << 10) | 0xEF = 0x100000EF */
    li   t2, 0x00000000100000EF
    sd   t2, 8(s0)              /* Entry 1: VPN2 = 1 */

    /* Entry 2: Identity map 0x80000000 - 0xBFFFFFFF (DDR4 DRAM 1GB Gigapage) */
    /* PPN = 0x80000000 >> 12 = 0x80000, Flags = 0xEF */
    /* PTE = (0x80000 << 10) | 0xEF = 0x200000EF */
    li   t2, 0x00000000200000EF
    sd   t2, 16(s0)             /* Entry 2: VPN2 = 2 */

    /* Synchronize page table writes in D-Cache to DDR4 before PTW reads */
    sfence.vma x0, x0


    /* ----------------------------------------------------------------- */
    /* Step 2: Configure satp Register for Sv39 Translation              */
    /* satp = (MODE=8 << 60) | (PPN = page_table_l2 >> 12)              */
    /* ----------------------------------------------------------------- */
    srli t3, s0, 12             /* PPN of root page table */
    li   t4, 8                  /* MODE = Sv39 (8) */
    slli t4, t4, 60
    or   t3, t3, t4             /* satp value */
    csrw satp, t3

    /* Invalidate TLB across all ASIDs and virtual addresses */
    sfence.vma x0, x0

    /* Verify satp register readback */
    TEST_CASE(1, a1, 1,
        csrr t5, satp;
        srli a1, t5, 60;
        li   t6, 8;
        sub  a1, a1, t6;
        seqz a1, a1             /* 1 if MODE == 8 */
    )

    /* ----------------------------------------------------------------- */
    /* Step 3: Switch to Supervisor Mode (S-mode) with MMU active        */
    /* ----------------------------------------------------------------- */
    la   t0, s_mmu_trap_handler
    csrw mtvec, t0

    /* Set mstatus.MPP = 2'b01 (S-mode = 0x0800) */
    li   t0, 0x1800
    csrc mstatus, t0
    li   t0, 0x0800
    csrs mstatus, t0

    /* Configure PMP entry 0 to allow all memory (NAPOT, RWX) for S-mode */
    li   t0, 0x3FFFFFFFFF
    csrw pmpaddr0, t0
    li   t0, 0x1F
    csrw pmpcfg0, t0

    la   t1, s_mmu_test_entry
    csrw mepc, t1
    mret

s_mmu_test_entry:
    /* We are now executing in S-mode with Sv39 paging enabled! */
    /* Read/write test buffer in DDR4 via virtual addressing */
    la   s1, test_mmu_buffer
    li   t1, 0xDEADBEEF12345678
    sd   t1, 0(s1)
    ld   s2, 0(s1)

    TEST_CASE(2, s2, 0xDEADBEEF12345678,
        mv a1, s2
    )

    /* Test sfence.vma shootdown instruction execution */
    sfence.vma x0, x0

    /* Verify memory access still valid after TLB shootdown (forces PTW re-walk) */
    ld   s3, 0(s1)
    TEST_CASE(3, s3, 0xDEADBEEF12345678,
        mv a1, s3
    )

    TEST_PASS
    TEST_FAIL

.align 4
s_mmu_trap_handler:
    csrr s5, mcause
    csrr s6, mepc
    csrr s7, mtval

    PUTCHAR('M')
    PUTCHAR('C')
    PUTCHAR(':')
    /* Print s5 hex (64-bit) */
    li   t4, 60
.Lprint_mc:
    srl  t3, s5, t4
    andi t3, t3, 0xf
    li   t2, 10
    blt  t3, t2, 1f
    addi t3, t3, 'A' - 10
    j    2f
1:  addi t3, t3, '0'
2:  li   t5, UART0_BASE
    sb   t3, 0(t5)
    addi t4, t4, -4
    bgez t4, .Lprint_mc

    PUTCHAR(' ')
    PUTCHAR('P')
    PUTCHAR('C')
    PUTCHAR(':')
    li   t4, 60
.Lprint_pc:
    srl  t3, s6, t4
    andi t3, t3, 0xf
    li   t2, 10
    blt  t3, t2, 1f
    addi t3, t3, 'A' - 10
    j    2f
1:  addi t3, t3, '0'
2:  li   t5, UART0_BASE
    sb   t3, 0(t5)
    addi t4, t4, -4
    bgez t4, .Lprint_pc

    PUTCHAR(' ')
    PUTCHAR('V')
    PUTCHAR('A')
    PUTCHAR(':')
    li   t4, 60
.Lprint_va:
    srl  t3, s7, t4
    andi t3, t3, 0xf
    li   t2, 10
    blt  t3, t2, 1f
    addi t3, t3, 'A' - 10
    j    2f
1:  addi t3, t3, '0'
2:  li   t5, UART0_BASE
    sb   t3, 0(t5)
    addi t4, t4, -4
    bgez t4, .Lprint_va
    PUTCHAR('\n')

    mv   a0, s5
    j    test_fail



.section .data
.align 12
page_table_l2:
    .space 4096
test_mmu_buffer:
    .dword 0

