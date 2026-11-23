/* SPDX-License-Identifier: Apache-2.0 */
/* SMVDU TITAN-X Clean-Room Verification: Multi-Core MESI Contention Hammer */
/* Tests:                                                                  */
/*   1. 4-Core False Sharing Contention Hammer on a Single 64-Byte Line     */
/*   2. 4-Core True Sharing Sequential Token Ring (MESI State Transitions) */
/*   3. Multi-Core Set Conflict Thrashing (PLRU & Victim Eviction)          */
/*   4. 4-Core Concurrent Atomic Increment Hammer (AMOADD.D Contention)     */

#include "../test_macros.h"

.section .text.init
.globl _start

_start:
    csrr a0, mhartid
    li   t0, 4
    beq  a0, t0, .Lpark_hart4

    /* Each core 0..3 gets an independent 4KB stack */
    la   sp, __stack_top
    slli t0, a0, 12
    sub  sp, sp, t0

    beqz a0, .Lhart0_entry
    li   t0, 1
    beq  a0, t0, .Lhart1_entry
    li   t0, 2
    beq  a0, t0, .Lhart2_entry
    li   t0, 3
    beq  a0, t0, .Lhart3_entry

.Lpark_hart4:
    wfi
    j    .Lpark_hart4

/* ========================================================================= */
/* HART 0: COORDINATOR & TEST RUNNER                                         */
/* ========================================================================= */
.Lhart0_entry:
    /* Wait for secondary cores to report initial ready */
    la   t1, h1_ready
.Lwait_init_h1:
    ld   t2, 0(t1)
    beqz t2, .Lwait_init_h1

    la   t1, h2_ready
.Lwait_init_h2:
    ld   t2, 0(t1)
    beqz t2, .Lwait_init_h2

    la   t1, h3_ready
.Lwait_init_h3:
    ld   t2, 0(t1)
    beqz t2, .Lwait_init_h3

    /* --------------------------------------------------------------------- */
    /* TEST 1: 4-Core False Sharing Contention Hammer on Single 64B Line     */
    /* --------------------------------------------------------------------- */
    /* Initialize canary words 4..7 in the shared cacheline */
    la   s0, fs_line
    li   t1, 0xAAAAAAAA00000004
    sd   t1, 32(s0)
    li   t1, 0xBBBBBBBB00000005
    sd   t1, 40(s0)
    li   t1, 0xCCCCCCCC00000006
    sd   t1, 48(s0)
    li   t1, 0xDDDDDDDD00000007
    sd   t1, 56(s0)
    fence rw, rw

    /* Signal start of Test 1 (phase = 1) */
    li   t0, 1
    la   t1, test_phase
    sd   t0, 0(t1)
    fence rw, rw

    /* Hart 0 hammers word 0 (offset 0) 30 times */
    li   s1, 0
    li   s2, 30
.Lh0_fs_loop:
    li   t0, 0x1000
    add  t0, t0, s1
    sd   t0, 0(s0)
    fence rw, rw
    addi s1, s1, 1
    blt  s1, s2, .Lh0_fs_loop

    /* Mark Hart 0 finished Test 1 */
    li   t0, 1
    la   t1, h0_done
    sd   t0, 0(t1)
    fence rw, rw

    /* Wait for Harts 1, 2, 3 to complete Test 1 */
    la   t1, h1_done
.Lwait_h1_fs:
    ld   t2, 0(t1)
    beqz t2, .Lwait_h1_fs

    la   t1, h2_done
.Lwait_h2_fs:
    ld   t2, 0(t1)
    beqz t2, .Lwait_h2_fs

    la   t1, h3_done
.Lwait_h3_fs:
    ld   t2, 0(t1)
    beqz t2, .Lwait_h3_fs

    /* Verify all 4 words updated correctly and canaries intact */
    ld   t1, 0(s0)
    li   t0, 0x1000 + 29
    bne  t1, t0, .Lfail_test1

    ld   t1, 8(s0)
    li   t0, 0x2000 + 29
    bne  t1, t0, .Lfail_test1

    ld   t1, 16(s0)
    li   t0, 0x3000 + 29
    bne  t1, t0, .Lfail_test1

    ld   t1, 24(s0)
    li   t0, 0x4000 + 29
    bne  t1, t0, .Lfail_test1

    ld   t1, 32(s0)
    li   t0, 0xAAAAAAAA00000004
    bne  t1, t0, .Lfail_test1

    ld   t1, 40(s0)
    li   t0, 0xBBBBBBBB00000005
    bne  t1, t0, .Lfail_test1

    ld   t1, 48(s0)
    li   t0, 0xCCCCCCCC00000006
    bne  t1, t0, .Lfail_test1

    ld   t1, 56(s0)
    li   t0, 0xDDDDDDDD00000007
    bne  t1, t0, .Lfail_test1

    /* --------------------------------------------------------------------- */
    /* TEST 2: 4-Core True Sharing Token Ring (Sequential MESI transitions)  */
    /* --------------------------------------------------------------------- */
    /* Reset done flags */
    la   t1, h0_done; sd zero, 0(t1)
    la   t1, h1_done; sd zero, 0(t1)
    la   t1, h2_done; sd zero, 0(t1)
    la   t1, h3_done; sd zero, 0(t1)

    /* Init token: owner = 0, value = 0 */
    la   s3, token_line
    sd   zero, 0(s3)         /* token_owner = 0 */
    sd   zero, 8(s3)         /* token_value = 0 */
    fence rw, rw

    /* Signal start of Test 2 (phase = 2) */
    li   t0, 2
    la   t1, test_phase
    sd   t0, 0(t1)
    fence rw, rw

    /* Hart 0 participates in 10 full ring rounds (40 total handoffs) */
    li   s4, 0
    li   s5, 10
.Lh0_ring_loop:
.Lh0_ring_spin:
    ld   t1, 0(s3)           /* read owner */
    bnez t1, .Lh0_ring_spin  /* wait until owner == 0 */

    /* Verify current token value matches expected (s4 * 4) */
    ld   t2, 8(s3)
    slli t3, s4, 2
    bne  t2, t3, .Lfail_test2

    /* Increment value and pass to Hart 1 (owner = 1) */
    addi t2, t2, 1
    sd   t2, 8(s3)
    fence rw, rw
    li   t4, 1
    sd   t4, 0(s3)           /* token_owner = 1 */
    fence rw, rw

    addi s4, s4, 1
    blt  s4, s5, .Lh0_ring_loop

    /* Wait for final round handoff back to Hart 0 */
.Lh0_ring_final_wait:
    ld   t1, 0(s3)
    bnez t1, .Lh0_ring_final_wait

    /* Check final token_value == 40 */
    ld   t2, 8(s3)
    li   t0, 40
    bne  t2, t0, .Lfail_test2

    /* Mark Hart 0 finished Test 2 and notify secondary cores to exit ring */
    li   t0, 1
    la   t1, h0_done
    sd   t0, 0(t1)
    fence rw, rw

    /* --------------------------------------------------------------------- */
    /* TEST 3: Multi-Core Set Conflict Thrashing (PLRU & Victim Eviction)     */
    /* --------------------------------------------------------------------- */
    /* Reset done flags */
    la   t1, h0_done; sd zero, 0(t1)
    la   t1, h1_done; sd zero, 0(t1)
    la   t1, h2_done; sd zero, 0(t1)
    la   t1, h3_done; sd zero, 0(t1)

    /* Signal start of Test 3 (phase = 3) */
    li   t0, 3
    la   t1, test_phase
    sd   t0, 0(t1)
    fence rw, rw

    /* Hart 0 alternates writes across 3 distinct tags in Set 7 */
    la   s6, set7_line0
    la   s7, set7_line4
    li   s1, 0
    li   s2, 20
.Lh0_set_loop:
    sd   s1, 0(s6)
    fence rw, rw
    addi t0, s1, 100
    sd   t0, 0(s7)
    fence rw, rw
    addi s1, s1, 1
    blt  s1, s2, .Lh0_set_loop

    /* Mark Hart 0 finished Test 3 */
    li   t0, 1
    la   t1, h0_done
    sd   t0, 0(t1)
    fence rw, rw

    /* Wait for Harts 1, 2, 3 to finish Test 3 */
    la   t1, h1_done
.Lwait_h1_set:
    ld   t2, 0(t1)
    beqz t2, .Lwait_h1_set

    la   t1, h2_done
.Lwait_h2_set:
    ld   t2, 0(t1)
    beqz t2, .Lwait_h2_set

    la   t1, h3_done
.Lwait_h3_set:
    ld   t2, 0(t1)
    beqz t2, .Lwait_h3_set

    /* Verify final values across all conflicting lines */
    ld   t1, 0(s6)
    li   t0, 19
    bne  t1, t0, .Lfail_test3

    ld   t1, 0(s7)
    li   t0, 119
    bne  t1, t0, .Lfail_test3

    la   t3, set7_line1
    ld   t1, 0(t3)
    li   t0, 19
    bne  t1, t0, .Lfail_test3

    la   t3, set7_line2
    ld   t1, 0(t3)
    li   t0, 19
    bne  t1, t0, .Lfail_test3

    la   t3, set7_line3
    ld   t1, 0(t3)
    li   t0, 19
    bne  t1, t0, .Lfail_test3

    /* --------------------------------------------------------------------- */
    /* TEST 4: 4-Core Concurrent Atomic Increment Hammer (AMOADD.D)          */
    /* --------------------------------------------------------------------- */
    /* Reset done flags and atomic counter */
    la   t1, h0_done; sd zero, 0(t1)
    la   t1, h1_done; sd zero, 0(t1)
    la   t1, h2_done; sd zero, 0(t1)
    la   t1, h3_done; sd zero, 0(t1)

    la   s8, shared_atomic_counter
    sd   zero, 0(s8)
    fence rw, rw

    /* Signal start of Test 4 (phase = 4) */
    li   t0, 4
    la   t1, test_phase
    sd   t0, 0(t1)
    fence rw, rw

    /* Hart 0 executes 25 atomic increments */
    li   s1, 0
    li   s2, 25
    li   t2, 1
.Lh0_amo_loop:
.Lh0_lrsc_retry:
    lr.d t0, 0(s8)
    add  t1, t0, t2
    sc.d t3, t1, 0(s8)
    bnez t3, .Lh0_lrsc_retry
    addi s1, s1, 1
    blt  s1, s2, .Lh0_amo_loop

    fence rw, rw
    /* Mark Hart 0 finished Test 4 */
    li   t0, 1
    la   t1, h0_done
    sd   t0, 0(t1)
    fence rw, rw

    /* Wait for Harts 1, 2, 3 to finish Test 4 */
    la   t1, h1_done
.Lwait_h1_amo:
    ld   t2, 0(t1)
    beqz t2, .Lwait_h1_amo

    la   t1, h2_done
.Lwait_h2_amo:
    ld   t2, 0(t1)
    beqz t2, .Lwait_h2_amo

    la   t1, h3_done
.Lwait_h3_amo:
    ld   t2, 0(t1)
    beqz t2, .Lwait_h3_amo

    fence rw, rw
    /* Verify final atomic counter value: 4 cores * 25 increments = 100 */
    ld   t1, 0(s8)
    li   t0, 100
    bne  t1, t0, .Lfail_test4

    /* All 4 tests successfully passed! */
    TEST_PASS

.Lfail_test1:
    li   a0, 1
    j    test_fail

.Lfail_test2:
    li   a0, 2
    j    test_fail

.Lfail_test3:
    li   a0, 3
    j    test_fail

.Lfail_test4:
    li   a0, 4
    j    test_fail

    TEST_FAIL

/* ========================================================================= */
/* HART 1 EXECUTION FLOW                                                     */
/* ========================================================================= */
.Lhart1_entry:
    /* Signal ready to Hart 0 */
    li   t0, 1
    la   t1, h1_ready
    sd   t0, 0(t1)
    fence rw, rw

    /* --- Wait for Test 1 (False Sharing) --- */
    la   t1, test_phase
.Lh1_wait_phase1:
    ld   t2, 0(t1)
    li   t0, 1
    bne  t2, t0, .Lh1_wait_phase1

    /* Hart 1 hammers word 1 (offset 8) 30 times */
    la   s0, fs_line
    li   s1, 0
    li   s2, 30
.Lh1_fs_loop:
    li   t0, 0x2000
    add  t0, t0, s1
    sd   t0, 8(s0)
    fence rw, rw
    addi s1, s1, 1
    blt  s1, s2, .Lh1_fs_loop

    li   t0, 1
    la   t1, h1_done
    sd   t0, 0(t1)
    fence rw, rw

    /* --- Wait for Test 2 (Token Ring) --- */
    la   t1, test_phase
.Lh1_wait_phase2:
    ld   t2, 0(t1)
    li   t0, 2
    bne  t2, t0, .Lh1_wait_phase2

    la   s3, token_line
    la   s9, h0_done
.Lh1_ring_loop:
    /* Check if test finished */
    ld   t0, 0(s9)
    bnez t0, .Lh1_ring_done

    ld   t1, 0(s3)           /* read owner */
    li   t0, 1
    bne  t1, t0, .Lh1_ring_loop

    /* Owner == 1: increment value and pass to Hart 2 */
    ld   t2, 8(s3)
    addi t2, t2, 1
    sd   t2, 8(s3)
    fence rw, rw
    li   t4, 2
    sd   t4, 0(s3)           /* token_owner = 2 */
    fence rw, rw
    j    .Lh1_ring_loop
.Lh1_ring_done:

    /* --- Wait for Test 3 (Set Conflict) --- */
    la   t1, test_phase
.Lh1_wait_phase3:
    ld   t2, 0(t1)
    li   t0, 3
    bne  t2, t0, .Lh1_wait_phase3

    la   s6, set7_line1
    li   s1, 0
    li   s2, 20
.Lh1_set_loop:
    sd   s1, 0(s6)
    fence rw, rw
    addi s1, s1, 1
    blt  s1, s2, .Lh1_set_loop

    li   t0, 1
    la   t1, h1_done
    sd   t0, 0(t1)
    fence rw, rw

    /* --- Wait for Test 4 (Atomic Counter) --- */
    la   t1, test_phase
.Lh1_wait_phase4:
    ld   t2, 0(t1)
    li   t0, 4
    bne  t2, t0, .Lh1_wait_phase4

    la   s8, shared_atomic_counter
    li   s1, 0
    li   s2, 25
    li   t2, 1
.Lh1_amo_loop:
.Lh1_lrsc_retry:
    lr.d t0, 0(s8)
    add  t1, t0, t2
    sc.d t3, t1, 0(s8)
    bnez t3, .Lh1_lrsc_retry
    addi s1, s1, 1
    blt  s1, s2, .Lh1_amo_loop

    fence rw, rw
    li   t0, 1
    la   t1, h1_done
    sd   t0, 0(t1)
    fence rw, rw

.Lh1_park:
    wfi
    j    .Lh1_park

/* ========================================================================= */
/* HART 2 EXECUTION FLOW                                                     */
/* ========================================================================= */
.Lhart2_entry:
    /* Signal ready to Hart 0 */
    li   t0, 1
    la   t1, h2_ready
    sd   t0, 0(t1)
    fence rw, rw

    /* --- Wait for Test 1 (False Sharing) --- */
    la   t1, test_phase
.Lh2_wait_phase1:
    ld   t2, 0(t1)
    li   t0, 1
    bne  t2, t0, .Lh2_wait_phase1

    /* Hart 2 hammers word 2 (offset 16) 30 times */
    la   s0, fs_line
    li   s1, 0
    li   s2, 30
.Lh2_fs_loop:
    li   t0, 0x3000
    add  t0, t0, s1
    sd   t0, 16(s0)
    fence rw, rw
    addi s1, s1, 1
    blt  s1, s2, .Lh2_fs_loop

    li   t0, 1
    la   t1, h2_done
    sd   t0, 0(t1)
    fence rw, rw

    /* --- Wait for Test 2 (Token Ring) --- */
    la   t1, test_phase
.Lh2_wait_phase2:
    ld   t2, 0(t1)
    li   t0, 2
    bne  t2, t0, .Lh2_wait_phase2

    la   s3, token_line
    la   s9, h0_done
.Lh2_ring_loop:
    ld   t0, 0(s9)
    bnez t0, .Lh2_ring_done

    ld   t1, 0(s3)           /* read owner */
    li   t0, 2
    bne  t1, t0, .Lh2_ring_loop

    /* Owner == 2: increment value and pass to Hart 3 */
    ld   t2, 8(s3)
    addi t2, t2, 1
    sd   t2, 8(s3)
    fence rw, rw
    li   t4, 3
    sd   t4, 0(s3)           /* token_owner = 3 */
    fence rw, rw
    j    .Lh2_ring_loop
.Lh2_ring_done:

    /* --- Wait for Test 3 (Set Conflict) --- */
    la   t1, test_phase
.Lh2_wait_phase3:
    ld   t2, 0(t1)
    li   t0, 3
    bne  t2, t0, .Lh2_wait_phase3

    la   s6, set7_line2
    li   s1, 0
    li   s2, 20
.Lh2_set_loop:
    sd   s1, 0(s6)
    fence rw, rw
    addi s1, s1, 1
    blt  s1, s2, .Lh2_set_loop

    li   t0, 1
    la   t1, h2_done
    sd   t0, 0(t1)
    fence rw, rw

    /* --- Wait for Test 4 (Atomic Counter) --- */
    la   t1, test_phase
.Lh2_wait_phase4:
    ld   t2, 0(t1)
    li   t0, 4
    bne  t2, t0, .Lh2_wait_phase4

    la   s8, shared_atomic_counter
    li   s1, 0
    li   s2, 25
    li   t2, 1
.Lh2_amo_loop:
.Lh2_lrsc_retry:
    lr.d t0, 0(s8)
    add  t1, t0, t2
    sc.d t3, t1, 0(s8)
    bnez t3, .Lh2_lrsc_retry
    addi s1, s1, 1
    blt  s1, s2, .Lh2_amo_loop

    fence rw, rw
    li   t0, 1
    la   t1, h2_done
    sd   t0, 0(t1)
    fence rw, rw

.Lh2_park:
    wfi
    j    .Lh2_park

/* ========================================================================= */
/* HART 3 EXECUTION FLOW                                                     */
/* ========================================================================= */
.Lhart3_entry:
    /* Signal ready to Hart 0 */
    li   t0, 1
    la   t1, h3_ready
    sd   t0, 0(t1)
    fence rw, rw

    /* --- Wait for Test 1 (False Sharing) --- */
    la   t1, test_phase
.Lh3_wait_phase1:
    ld   t2, 0(t1)
    li   t0, 1
    bne  t2, t0, .Lh3_wait_phase1

    /* Hart 3 hammers word 3 (offset 24) 30 times */
    la   s0, fs_line
    li   s1, 0
    li   s2, 30
.Lh3_fs_loop:
    li   t0, 0x4000
    add  t0, t0, s1
    sd   t0, 24(s0)
    fence rw, rw
    addi s1, s1, 1
    blt  s1, s2, .Lh3_fs_loop

    li   t0, 1
    la   t1, h3_done
    sd   t0, 0(t1)
    fence rw, rw

    /* --- Wait for Test 2 (Token Ring) --- */
    la   t1, test_phase
.Lh3_wait_phase2:
    ld   t2, 0(t1)
    li   t0, 2
    bne  t2, t0, .Lh3_wait_phase2

    la   s3, token_line
    la   s9, h0_done
.Lh3_ring_loop:
    ld   t0, 0(s9)
    bnez t0, .Lh3_ring_done

    ld   t1, 0(s3)           /* read owner */
    li   t0, 3
    bne  t1, t0, .Lh3_ring_loop

    /* Owner == 3: increment value and pass back to Hart 0 */
    ld   t2, 8(s3)
    addi t2, t2, 1
    sd   t2, 8(s3)
    fence rw, rw
    sd   zero, 0(s3)         /* token_owner = 0 */
    fence rw, rw
    j    .Lh3_ring_loop
.Lh3_ring_done:

    /* --- Wait for Test 3 (Set Conflict) --- */
    la   t1, test_phase
.Lh3_wait_phase3:
    ld   t2, 0(t1)
    li   t0, 3
    bne  t2, t0, .Lh3_wait_phase3

    la   s6, set7_line3
    li   s1, 0
    li   s2, 20
.Lh3_set_loop:
    sd   s1, 0(s6)
    fence rw, rw
    addi s1, s1, 1
    blt  s1, s2, .Lh3_set_loop

    li   t0, 1
    la   t1, h3_done
    sd   t0, 0(t1)
    fence rw, rw

    /* --- Wait for Test 4 (Atomic Counter) --- */
    la   t1, test_phase
.Lh3_wait_phase4:
    ld   t2, 0(t1)
    li   t0, 4
    bne  t2, t0, .Lh3_wait_phase4

    la   s8, shared_atomic_counter
    li   s1, 0
    li   s2, 25
    li   t2, 1
.Lh3_amo_loop:
.Lh3_lrsc_retry:
    lr.d t0, 0(s8)
    add  t1, t0, t2
    sc.d t3, t1, 0(s8)
    bnez t3, .Lh3_lrsc_retry
    addi s1, s1, 1
    blt  s1, s2, .Lh3_amo_loop

    fence rw, rw
    li   t0, 1
    la   t1, h3_done
    sd   t0, 0(t1)
    fence rw, rw

.Lh3_park:
    wfi
    j    .Lh3_park

/* ========================================================================= */
/* DATA SECTION: 64-BYTE ALIGNED LINE ISOLATION                              */
/* ========================================================================= */
.section .data
.align 6

/* Synchronization variables (each on its own 64-byte line) */
test_phase:
    .dword 0
    .align 6

h1_ready:
    .dword 0
    .align 6

h2_ready:
    .dword 0
    .align 6

h3_ready:
    .dword 0
    .align 6

h0_done:
    .dword 0
    .align 6

h1_done:
    .dword 0
    .align 6

h2_done:
    .dword 0
    .align 6

h3_done:
    .dword 0
    .align 6

/* Test 1: Single 64-byte false sharing contention line */
fs_line:
    .dword 0    /* Word 0 (Core 0) */
    .dword 0    /* Word 1 (Core 1) */
    .dword 0    /* Word 2 (Core 2) */
    .dword 0    /* Word 3 (Core 3) */
    .dword 0    /* Word 4 (Canary 0) */
    .dword 0    /* Word 5 (Canary 1) */
    .dword 0    /* Word 6 (Canary 2) */
    .dword 0    /* Word 7 (Canary 3) */
    .align 6

/* Test 2: Token line (True sharing) */
token_line:
    .dword 0    /* token_owner: 0, 1, 2, 3 */
    .dword 0    /* token_value */
    .align 6

/* Test 3: Set 7 conflicting lines (bits [11:6] = 7, tags separated by 4KB = 0x1000) */
/* 4KB offset ensures identical index (bits 11:6) with different tags */
.align 12
    .space 448  /* 7 * 64 bytes = 448 bytes offset -> index = 7 */
set7_line0:
    .dword 0
    .align 12
    .space 448
set7_line1:
    .dword 0
    .align 12
    .space 448
set7_line2:
    .dword 0
    .align 12
    .space 448
set7_line3:
    .dword 0
    .align 12
    .space 448
set7_line4:
    .dword 0
    .align 6

/* Test 4: True sharing atomic counter */
shared_atomic_counter:
    .dword 0
    .align 6
