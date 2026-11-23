/* SPDX-License-Identifier: Apache-2.0 */
/* TITAN-X Clean-Room Verification: Privilege Transitions, Traps & CSRs */

#include "../test_macros.h"

INIT_TEST

    /* ----------------------------------------------------------------- */
    /* Test 1..10: Machine CSR Read/Write Operations                     */
    /* ----------------------------------------------------------------- */
    /* Test mscratch read/write */
    TEST_CASE(1, a1, 0xCAFEBABEDEADBEEF,
        li    t1, 0xCAFEBABEDEADBEEF;
        csrw  mscratch, t1;
        csrr  a1, mscratch
    )

    /* Test CSRRS (set bits) */
    TEST_CASE(2, a1, 0xCAFEBABEDEADBEEF,
        li    t1, 0xFF;
        csrrs a1, mscratch, t1 /* a1 gets old value */
    )
    TEST_CASE(3, a1, 0xCAFEBABEDEADBEFF,
        csrr  a1, mscratch
    )

    /* Test CSRRC (clear bits) */
    TEST_CASE(4, a1, 0xCAFEBABEDEADBE00,
        li    t1, 0xFF;
        csrrc x0, mscratch, t1;
        csrr  a1, mscratch
    )

    /* ----------------------------------------------------------------- */
    /* Test 11..20: M-Mode ECALL Trap and MRET                           */
    /* ----------------------------------------------------------------- */
    /* Install trap handler in mtvec */
    la   t0, m_trap_handler
    csrw mtvec, t0

    li   s1, 0       /* Trap execution flag */
    li   s2, 0       /* Trap cause saved */

    ecall            /* Fire M-mode ecall */

    /* After mret, execution resumes here */
    TEST_CASE(11, s1, 1, /* Verify trap handler executed */
        mv a1, s1
    )

    TEST_CASE(12, s2, 11, /* Verify mcause == 11 (Environment call from M-mode) */
        mv a1, s2
    )

    /* ----------------------------------------------------------------- */
    /* Test 21..30: M-mode -> S-mode Transition via MRET                */
    /* ----------------------------------------------------------------- */
    /* Configure mstatus.MPP = 2'b01 (S-mode = 0x800) */
    li   t0, 0x1800
    csrc mstatus, t0
    li   t0, 0x0800
    csrs mstatus, t0

    /* Configure PMP entry 0 to allow all memory (NAPOT, RWX) for S-mode */
    li   t0, 0x3FFFFFFFFF
    csrw pmpaddr0, t0
    li   t0, 0x1F
    csrw pmpcfg0, t0

    la   t1, s_mode_entry
    csrw mepc, t1

    li   s3, 0 /* S-mode executed flag */

    mret /* Switch to S-mode */

s_mode_entry:
    li   s3, 0x5A5A
    /* S-mode ecall: should trap to M-mode with mcause == 9 */
    ecall

    /* After M-mode handles S-mode ecall, returns back here */
    TEST_CASE(21, s3, 0x5A5A,
        mv a1, s3
    )

    TEST_PASS
    TEST_FAIL

/* --------------------------------------------------------------------- */
/* Machine Mode Trap Handler                                             */
/* --------------------------------------------------------------------- */
.align 4
m_trap_handler:
    csrr s2, mcause
    li   s1, 1

    /* Advance mepc past the ecall (4 bytes) */
    csrr t0, mepc
    addi t0, t0, 4
    csrw mepc, t0

    /* If trapped from S-mode, restore MPP to M-mode (2'b11 = 0x1800) so we return in M-mode */
    li   t0, 0x1800
    csrs mstatus, t0

    mret

