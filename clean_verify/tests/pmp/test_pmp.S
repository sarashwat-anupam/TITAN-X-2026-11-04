/* SPDX-License-Identifier: Apache-2.0 */
/* TITAN-X Clean-Room Verification: 8-Region PMP Enforcement Test */

#include "../test_macros.h"

INIT_TEST

    /* ----------------------------------------------------------------- */
    /* Test 1..10: PMP Register Configuration & Readback                 */
    /* ----------------------------------------------------------------- */
    /* Configure pmpaddr0 with 0xFFFFFFFFFF (all physical memory >> 2) */
    li   t0, 0x3FFFFFFFFF
    csrw pmpaddr0, t0
    csrr a1, pmpaddr0
    TEST_CASE(1, a1, 0x3FFFFFFFFF,
        mv a1, a1
    )

    /* Configure pmpcfg0: Region 0 in NAPOT mode (A=3), R=1, W=1, X=1 (0x1F) */
    li   t1, 0x1F
    csrw pmpcfg0, t1
    csrr a1, pmpcfg0
    TEST_CASE(2, a1, 0x1F,
        mv a1, a1
    )

    /* Configure Region 1: TOR mode (A=1), R=1, W=1, X=0 (0x0B) */
    /* pmpcfg0 byte 1 = bits 15:8 = 0x0B00 */
    li   t1, 0x0B1F
    csrw pmpcfg0, t1
    csrr a1, pmpcfg0
    TEST_CASE(3, a1, 0x0B1F,
        mv a1, a1
    )

    /* Verify memory access with PMP active */
    addi s0, sp, 64
    li   t2, 0x1234567890ABCDEF
    sd   t2, 0(s0)
    ld   a1, 0(s0)
    TEST_CASE(4, a1, 0x1234567890ABCDEF,
        mv a1, a1
    )

    /* ----------------------------------------------------------------- */
    /* Test 5: Verify Configuration of all 8 pmpaddr registers (0..7)   */
    /* ----------------------------------------------------------------- */
    li   t0, 0x1000
    csrw pmpaddr1, t0
    li   t0, 0x2000
    csrw pmpaddr2, t0
    li   t0, 0x3000
    csrw pmpaddr3, t0
    li   t0, 0x4000
    csrw pmpaddr4, t0
    li   t0, 0x5000
    csrw pmpaddr5, t0
    li   t0, 0x6000
    csrw pmpaddr6, t0
    li   t0, 0x7000
    csrw pmpaddr7, t0

    csrr a0, pmpaddr7
    TEST_CASE(5, a0, 0x7000,
        mv a1, a0
    )

    /* ----------------------------------------------------------------- */
    /* Test 6..8: Verify Lock Bit (L) Write Protection                   */
    /* ----------------------------------------------------------------- */
    /* Lock Entry 7: pmpcfg byte 7 = 0x9F (L=1, A=NAPOT, R=1, W=1, X=1) */
    li   t0, 0x9F00000000000000
    csrs pmpcfg0, t0

    /* Verify byte 7 is locked: read pmpcfg0 and extract byte 7 */
    csrr a1, pmpcfg0
    srli a1, a1, 56
    andi a1, a1, 0xFF
    TEST_CASE(6, a1, 0x9F,
        mv a1, a1
    )

    /* Attempt to clear byte 7 by writing 0x00: should be rejected */
    li   t0, 0xFF00000000000000
    csrc pmpcfg0, t0
    csrr a1, pmpcfg0
    srli a1, a1, 56
    andi a1, a1, 0xFF
    TEST_CASE(7, a1, 0x9F, /* Must remain 0x9F because it is locked */
        mv a1, a1
    )

    /* Attempt to overwrite locked pmpaddr7 with 0x9999: should be rejected */
    li   t0, 0x9999
    csrw pmpaddr7, t0
    csrr a1, pmpaddr7
    TEST_CASE(8, a1, 0x7000, /* Must remain 0x7000 because entry 7 is locked */
        mv a1, a1
    )

    /* ----------------------------------------------------------------- */
    /* Test 9..10: Locked Entry Access Fault in Machine Mode             */
    /* ----------------------------------------------------------------- */
    /* Install machine trap handler */
    la   t0, pmp_trap_handler
    csrw mtvec, t0

    /* Configure Entry 6 as Locked Read-Only region covering test_pmp_buf */
    la   s2, test_pmp_buf
    srli s3, s2, 2
    csrw pmpaddr5, s3
    addi s4, s2, 64
    srli s4, s4, 2
    csrw pmpaddr6, s4

    /* Set entry 6 in TOR mode, Locked, Read-Only (L=1, A=01, X=0, W=0, R=1) -> 0x89
       pmpcfg0 byte 6 = bits 55:48 = 0x89 << 48
    */
    li   t0, 0x0089000000000000
    csrs pmpcfg0, t0

    /* Clear Entry 0 configuration (was unlocked) so Entry 6 rule takes priority */
    li   t0, 0xFF
    csrc pmpcfg0, t0

    li   s5, 0  /* Trap taken flag */
    li   s6, 0  /* Captured mcause */

    /* Attempt store to locked read-only region: MUST generate Store Access Fault */
    li   t1, 0xBADC0DE
    sd   t1, 0(s2)

    /* Check trap was taken and cause == 7 (Store/AMO access fault) */
    TEST_CASE(9, s5, 1,
        mv a1, s5
    )
    TEST_CASE(10, s6, 7,
        mv a1, s6
    )

    /* Re-enable Entry 0 (NAPOT RWX) for safe completion */
    li   t0, 0x1F
    csrs pmpcfg0, t0

    TEST_PASS
    TEST_FAIL

.align 4
pmp_trap_handler:
    csrr s6, mcause
    li   s5, 1
    /* Advance mepc past the faulting sd instruction (4 bytes) */
    csrr t0, mepc
    addi t0, t0, 4
    csrw mepc, t0
    mret

.section .data
.align 6
test_pmp_buf:
    .dword 0x1122334455667788
    .dword 0x99AABBCCDDEEFF00

