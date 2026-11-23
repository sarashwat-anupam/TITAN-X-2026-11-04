/* SPDX-License-Identifier: Apache-2.0 */
/* SMVDU TITAN-X Clean-Room Verification: Multi-Core MESI Cache Coherence Litmus Suite */
/* Tests:                                                                             */
/*   1. Message Passing (MP) with FENCE RW, W and FENCE R, RW                        */
/*   2. Store Buffering (SB) with FENCE RW, RW                                        */
/*   3. Dekker Mutual Exclusion Algorithm (2-Core Contention on Shared Counter)      */
/*   4. Independent Reads of Independent Writes (IRIW) across 4 Harts                 */
/*   5. Hardware MESI Coherence Invalidation & Dirty Intervention Test               */
/*   6. FENCE.I Instruction Cache Invalidation & Self-Modifying Code                  */

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

    beqz a0, .Lhart0_main
    li   t0, 1
    beq  a0, t0, .Lhart1_main
    li   t0, 2
    beq  a0, t0, .Lhart2_main
    li   t0, 3
    beq  a0, t0, .Lhart3_main

.Lpark_hart4:
    wfi
    j    .Lpark_hart4

/* ========================================================================= */
/* HART 0 EXECUTION FLOW (Coordinator & Tester)                             */
/* ========================================================================= */
.Lhart0_main:
    /* Synchronize all 4 cores before starting */
    li   t0, 1
    la   t1, sync_phase
    sw   t0, 0(t1)
    fence rw, rw

    /* Wait for Harts 1, 2, 3 to report ready */
    la   t1, hart1_ready
.Lwait_h1_rdy:
    lw   t2, 0(t1)
    beqz t2, .Lwait_h1_rdy

    la   t1, hart2_ready
.Lwait_h2_rdy:
    lw   t2, 0(t1)
    beqz t2, .Lwait_h2_rdy

    la   t1, hart3_ready
.Lwait_h3_rdy:
    lw   t2, 0(t1)
    beqz t2, .Lwait_h3_rdy

    /* --------------------------------------------------------------------- */
    /* Test 1: Message Passing (MP) Litmus Test                              */
    /* --------------------------------------------------------------------- */
    li   t2, 0xCAFEBABE12345678
    la   t3, mp_data
    sd   t2, 0(t3)
    fence rw, w              /* Ensure data write precedes flag write */
    li   t2, 1
    la   t3, mp_flag
    sd   t2, 0(t3)
    fence rw, rw

    /* Wait for Hart 1 to complete MP verification */
    la   t1, mp_done
.Lwait_mp:
    ld   t2, 0(t1)
    beqz t2, .Lwait_mp

    /* Check if Hart 1 reported pass (1) or fail (0xFF) */
    li   t0, 1
    beq  t2, t0, 1f
    li   a0, 1               /* Exit code 1: MP test failed */
    j    test_fail
1:

    /* --------------------------------------------------------------------- */
    /* Test 2: Store Buffering (SB) Litmus Test                              */
    /* --------------------------------------------------------------------- */
    /* Signal Hart 1 to start SB */
    li   t0, 2
    la   t1, sync_phase
    sw   t0, 0(t1)
    fence rw, rw

    /* Hart 0 SB branch: Store X=1, Fence, Load Y */
    li   t2, 1
    la   t3, sb_x
    sd   t2, 0(t3)
    fence rw, rw
    la   t3, sb_y
    ld   s1, 0(t3)           /* s1 = read(Y) */
    la   t3, sb_r0
    sd   s1, 0(t3)
    fence rw, rw
    li   t2, 1
    la   t3, sb_done0
    sd   t2, 0(t3)
    fence rw, rw

    /* Wait for Hart 1 to finish its SB branch */
    la   t1, sb_done1
.Lwait_sb1:
    ld   t2, 0(t1)
    beqz t2, .Lwait_sb1

    /* Read both results: impossible for both r0==0 and r1==0 */
    la   t1, sb_r0
    ld   t2, 0(t1)
    la   t1, sb_r1
    ld   t3, 0(t1)
    or   t4, t2, t3
    bnez t4, 2f              /* At least one must be 1 */
    li   a0, 2               /* Exit code 2: SB sequential consistency violated */
    j    test_fail
2:

    /* --------------------------------------------------------------------- */
    /* Test 3: Dekker Mutual Exclusion Algorithm                             */
    /* --------------------------------------------------------------------- */
    /* Reset counter and flags */
    la   t1, dekker_counter
    sd   zero, 0(t1)
    la   t1, dekker_turn
    sd   zero, 0(t1)
    la   t1, dekker_flag0
    sd   zero, 0(t1)
    la   t1, dekker_flag1
    sd   zero, 0(t1)
    fence rw, rw

    /* Signal Hart 1 to start Dekker */
    li   t0, 3
    la   t1, sync_phase
    sw   t0, 0(t1)
    fence rw, rw

    /* Hart 0 executes 10 iterations of critical section */
    li   s2, 10              /* loop count */
.Ldekker_h0_loop:
    /* flag0 = 1 */
    li   t2, 1
    la   t3, dekker_flag0
    sd   t2, 0(t3)
    fence rw, rw

    la   t4, dekker_flag1
    la   t5, dekker_turn
.Ldekker_h0_wait:
    ld   t6, 0(t4)
    beqz t6, .Ldekker_h0_enter  /* flag1 == 0, safe to enter */

    /* flag1 is set; check turn */
    ld   t6, 0(t5)
    beqz t6, .Ldekker_h0_wait   /* turn == 0, wait */

    /* turn == 1, back off */
    la   t3, dekker_flag0
    sd   zero, 0(t3)
    fence rw, rw
.Ldekker_h0_turn_wait:
    ld   t6, 0(t5)
    bnez t6, .Ldekker_h0_turn_wait
    li   t2, 1
    la   t3, dekker_flag0
    sd   t2, 0(t3)
    fence rw, rw
    j    .Ldekker_h0_wait

.Ldekker_h0_enter:
    /* === CRITICAL SECTION === */
    la   t1, dekker_counter
    ld   t2, 0(t1)
    addi t2, t2, 1
    sd   t2, 0(t1)
    fence rw, rw
    /* === EXIT CRITICAL SECTION === */
    li   t2, 1
    la   t5, dekker_turn
    sd   t2, 0(t5)           /* turn = 1 */
    la   t3, dekker_flag0
    sd   zero, 0(t3)         /* flag0 = 0 */
    fence rw, rw

    addi s2, s2, -1
    bnez s2, .Ldekker_h0_loop

    /* Signal Hart 0 finished Dekker */
    li   t2, 1
    la   t3, dekker_done0
    sd   t2, 0(t3)
    fence rw, rw

    /* Wait for Hart 1 to finish */
    la   t1, dekker_done1
.Lwait_dekker1:
    ld   t2, 0(t1)
    beqz t2, .Lwait_dekker1

    /* Verify final counter value == 20 (10 from H0 + 10 from H1) */
    la   t1, dekker_counter
    ld   t2, 0(t1)
    li   t0, 20
    beq  t2, t0, 3f
    li   a0, 3               /* Exit code 3: Dekker critical section race */
    j    test_fail
3:

    /* --------------------------------------------------------------------- */
    /* Test 4: Independent Reads of Independent Writes (IRIW) across 4 Cores */
    /* --------------------------------------------------------------------- */
    /* Reset IRIW variables */
    la   t1, iriw_x
    sd   zero, 0(t1)
    la   t1, iriw_y
    sd   zero, 0(t1)
    fence rw, rw

    /* Signal all cores to start IRIW (phase 4) */
    li   t0, 4
    la   t1, sync_phase
    sw   t0, 0(t1)
    fence rw, rw

    /* Hart 0: Writer of X */
    li   t2, 1
    la   t3, iriw_x
    sd   t2, 0(t3)
    fence rw, rw

    /* Wait for Readers (Hart 2 and Hart 3) to complete */
    la   t1, iriw_done2
.Lwait_iriw2:
    ld   t2, 0(t1)
    beqz t2, .Lwait_iriw2

    la   t1, iriw_done3
.Lwait_iriw3:
    ld   t2, 0(t1)
    beqz t2, .Lwait_iriw3

    /* --------------------------------------------------------------------- */
    /* Test 5: Hardware MESI Invalidation & Dirty Intervention Test          */
    /* --------------------------------------------------------------------- */
    /* Initialize mesi_line */
    li   t2, 0x1111222233334444
    la   t3, mesi_line
    sd   t2, 0(t3)
    fence rw, rw

    /* Signal Hart 1 to start MESI test (phase 5) */
    li   t0, 5
    la   t1, sync_phase
    sw   t0, 0(t1)
    fence rw, rw

    /* Wait for Hart 1 to load mesi_line (step 1) */
    la   t1, mesi_step
.Lwait_mesi_step1:
    ld   t2, 0(t1)
    li   t0, 1
    bne  t2, t0, .Lwait_mesi_step1

    /* Hart 0 modifies mesi_line: acquires Modified state, invalidating Hart 1 */
    li   t2, 0xCAFEBABEDEADBEEF
    la   t3, mesi_line
    sd   t2, 0(t3)
    fence rw, rw

    /* Advance to step 2 */
    li   t0, 2
    la   t1, mesi_step
    sd   t0, 0(t1)
    fence rw, rw

    /* Wait for Hart 1 to verify dirty intervention read (step 3) */
.Lwait_mesi_step3:
    ld   t2, 0(t1)
    li   t0, 3
    bne  t2, t0, .Lwait_mesi_step3

    /* Check if Hart 1 reported success */
    la   t1, mesi_result
    ld   t2, 0(t1)
    li   t0, 1
    beq  t2, t0, 5f
    li   a0, 5               /* Exit code 5: MESI dirty intervention mismatch */
    j    test_fail
5:

    /* --------------------------------------------------------------------- */
    /* Test 6: FENCE.I Instruction Cache Invalidation & Self-Modifying Code   */
    /* --------------------------------------------------------------------- */
    /* Generate dynamic instruction in smc_buf:
       addi a1, zero, 42  -> 0x02a00593
       ret (jalr x0, ra)  -> 0x00008067
    */
    la   t1, smc_buf
    li   t2, 0x02a00593
    sw   t2, 0(t1)
    li   t2, 0x00008067
    sw   t2, 4(t1)
    fence rw, w
    fence.i                  /* Invalidate I-cache so modified code is fetched */

    /* Call the dynamically generated function */
    li   a1, 0
    jalr ra, t1

    /* Verify a1 == 42 */
    li   t0, 42
    beq  a1, t0, 6f
    li   a0, 6               /* Exit code 6: FENCE.I execution failed */
    j    test_fail
6:

    /* All tests PASSED! Signal secondary harts to terminate */
    li   t0, 0xFF
    la   t1, sync_phase
    sw   t0, 0(t1)
    fence rw, rw

    TEST_PASS
    TEST_FAIL

/* ========================================================================= */
/* HART 1 EXECUTION FLOW                                                     */
/* ========================================================================= */
.Lhart1_main:
    /* Signal ready */
    li   t0, 1
    la   t1, hart1_ready
    sw   t0, 0(t1)
    fence rw, rw

    /* --- Wait for Test 1: Message Passing --- */
    la   t1, mp_flag
.Lh1_wait_mp_flag:
    ld   t2, 0(t1)
    beqz t2, .Lh1_wait_mp_flag
    fence r, rw              /* Acquire fence: observe data after flag */
    la   t3, mp_data
    ld   t4, 0(t3)
    li   t5, 0xCAFEBABE12345678
    beq  t4, t5, .Lh1_mp_pass
    li   t0, 0xFF            /* Fail flag */
    la   t1, mp_done
    sd   t0, 0(t1)
    fence rw, rw
    j    .Lh1_park
.Lh1_mp_pass:
    li   t0, 1               /* Pass flag */
    la   t1, mp_done
    sd   t0, 0(t1)
    fence rw, rw

    /* --- Wait for Test 2: Store Buffering --- */
    la   t1, sync_phase
.Lh1_wait_sb_phase:
    lw   t2, 0(t1)
    li   t0, 2
    bne  t2, t0, .Lh1_wait_sb_phase

    /* Hart 1 SB branch: Store Y=1, Fence, Load X */
    li   t2, 1
    la   t3, sb_y
    sd   t2, 0(t3)
    fence rw, rw
    la   t3, sb_x
    ld   s2, 0(t3)           /* s2 = read(X) */
    la   t3, sb_r1
    sd   s2, 0(t3)
    fence rw, rw
    li   t2, 1
    la   t3, sb_done1
    sd   t2, 0(t3)
    fence rw, rw

    /* --- Wait for Test 3: Dekker --- */
    la   t1, sync_phase
.Lh1_wait_dekker_phase:
    lw   t2, 0(t1)
    li   t0, 3
    bne  t2, t0, .Lh1_wait_dekker_phase

    li   s2, 10
.Ldekker_h1_loop:
    /* flag1 = 1 */
    li   t2, 1
    la   t3, dekker_flag1
    sd   t2, 0(t3)
    fence rw, rw

    la   t4, dekker_flag0
    la   t5, dekker_turn
.Ldekker_h1_wait:
    ld   t6, 0(t4)
    beqz t6, .Ldekker_h1_enter

    ld   t6, 0(t5)
    li   t0, 1
    beq  t6, t0, .Ldekker_h1_wait

    /* turn == 0, back off */
    la   t3, dekker_flag1
    sd   zero, 0(t3)
    fence rw, rw
.Ldekker_h1_turn_wait:
    ld   t6, 0(t5)
    beqz t6, .Ldekker_h1_turn_wait
    li   t2, 1
    la   t3, dekker_flag1
    sd   t2, 0(t3)
    fence rw, rw
    j    .Ldekker_h1_wait

.Ldekker_h1_enter:
    /* === CRITICAL SECTION === */
    la   t1, dekker_counter
    ld   t2, 0(t1)
    addi t2, t2, 1
    sd   t2, 0(t1)
    fence rw, rw
    /* === EXIT CRITICAL SECTION === */
    la   t5, dekker_turn
    sd   zero, 0(t5)         /* turn = 0 */
    la   t3, dekker_flag1
    sd   zero, 0(t3)         /* flag1 = 0 */
    fence rw, rw

    addi s2, s2, -1
    bnez s2, .Ldekker_h1_loop

    li   t2, 1
    la   t3, dekker_done1
    sd   t2, 0(t3)
    fence rw, rw

    /* --- Wait for Test 4: IRIW --- */
    la   t1, sync_phase
.Lh1_wait_iriw_phase:
    lw   t2, 0(t1)
    li   t0, 4
    bne  t2, t0, .Lh1_wait_iriw_phase

    /* Hart 1: Writer of Y */
    li   t2, 1
    la   t3, iriw_y
    sd   t2, 0(t3)
    fence rw, rw

    /* --- Wait for Test 5: MESI --- */
    la   t1, sync_phase
.Lh1_wait_mesi_phase:
    lw   t2, 0(t1)
    li   t0, 5
    bne  t2, t0, .Lh1_wait_mesi_phase

    /* Step 1: Hart 1 loads mesi_line into its cache */
    la   t3, mesi_line
    ld   t4, 0(t3)
    fence rw, rw

    /* Signal Hart 0 that line is cached (step 1) */
    li   t0, 1
    la   t1, mesi_step
    sd   t0, 0(t1)
    fence rw, rw

    /* Wait for Hart 0 to modify the line (step 2) */
.Lh1_wait_mesi_step2:
    ld   t2, 0(t1)
    li   t0, 2
    bne  t2, t0, .Lh1_wait_mesi_step2

    /* Step 3: Load modified line; triggers L2 dirty intervention */
    ld   t4, 0(t3)
    li   t5, 0xCAFEBABEDEADBEEF
    la   t1, mesi_result
    beq  t4, t5, .Lh1_mesi_pass
    sd   zero, 0(t1)
    j    .Lh1_mesi_done
.Lh1_mesi_pass:
    li   t0, 1
    sd   t0, 0(t1)
.Lh1_mesi_done:
    fence rw, rw
    li   t0, 3
    la   t1, mesi_step
    sd   t0, 0(t1)
    fence rw, rw

.Lh1_park:
    wfi
    j    .Lh1_park

/* ========================================================================= */
/* HART 2 EXECUTION FLOW                                                     */
/* ========================================================================= */
.Lhart2_main:
    li   t0, 1
    la   t1, hart2_ready
    sw   t0, 0(t1)
    fence rw, rw

    /* Wait for IRIW phase */
    la   t1, sync_phase
.Lh2_wait_iriw:
    lw   t2, 0(t1)
    li   t0, 4
    bne  t2, t0, .Lh2_wait_iriw

    /* Reader XY: Wait for X=1, then read Y */
    la   t3, iriw_x
.Lh2_wait_x:
    ld   t4, 0(t3)
    beqz t4, .Lh2_wait_x
    fence r, r
    la   t3, iriw_y
    ld   t5, 0(t3)
    la   t1, iriw_r2_y
    sd   t5, 0(t1)
    fence rw, rw
    li   t0, 1
    la   t1, iriw_done2
    sd   t0, 0(t1)
    fence rw, rw

.Lh2_park:
    wfi
    j    .Lh2_park

/* ========================================================================= */
/* HART 3 EXECUTION FLOW                                                     */
/* ========================================================================= */
.Lhart3_main:
    li   t0, 1
    la   t1, hart3_ready
    sw   t0, 0(t1)
    fence rw, rw

    /* Wait for IRIW phase */
    la   t1, sync_phase
.Lh3_wait_iriw:
    lw   t2, 0(t1)
    li   t0, 4
    bne  t2, t0, .Lh3_wait_iriw

    /* Reader YX: Wait for Y=1, then read X */
    la   t3, iriw_y
.Lh3_wait_y:
    ld   t4, 0(t3)
    beqz t4, .Lh3_wait_y
    fence r, r
    la   t3, iriw_x
    ld   t5, 0(t3)
    la   t1, iriw_r3_x
    sd   t5, 0(t1)
    fence rw, rw
    li   t0, 1
    la   t1, iriw_done3
    sd   t0, 0(t1)
    fence rw, rw

.Lh3_park:
    wfi
    j    .Lh3_park


/* ========================================================================= */
/* SHARED DATA STRUCTURES (Cache-Line Aligned)                               */
/* ========================================================================= */
.section .data
.align 6

sync_phase:
    .word 0
    .align 6

hart1_ready:
    .word 0
    .align 6

hart2_ready:
    .word 0
    .align 6

hart3_ready:
    .word 0
    .align 6

/* Test 1 (MP) */
mp_data:
    .dword 0
    .align 6
mp_flag:
    .dword 0
    .align 6
mp_done:
    .dword 0
    .align 6

/* Test 2 (SB) */
sb_x:
    .dword 0
    .align 6
sb_y:
    .dword 0
    .align 6
sb_r0:
    .dword 0
    .align 6
sb_r1:
    .dword 0
    .align 6
sb_done0:
    .dword 0
    .align 6
sb_done1:
    .dword 0
    .align 6

/* Test 3 (Dekker) */
dekker_flag0:
    .dword 0
    .align 6
dekker_flag1:
    .dword 0
    .align 6
dekker_turn:
    .dword 0
    .align 6
dekker_counter:
    .dword 0
    .align 6
dekker_done0:
    .dword 0
    .align 6
dekker_done1:
    .dword 0
    .align 6

/* Test 4 (IRIW) */
iriw_x:
    .dword 0
    .align 6
iriw_y:
    .dword 0
    .align 6
iriw_r2_y:
    .dword 0
    .align 6
iriw_r3_x:
    .dword 0
    .align 6
iriw_done2:
    .dword 0
    .align 6
iriw_done3:
    .dword 0
    .align 6

/* Test 5 (MESI) */
mesi_line:
    .dword 0x1111222233334444
    .align 6
mesi_step:
    .dword 0
    .align 6
mesi_result:
    .dword 0
    .align 6

/* Test 6 (SMC) buffer */
smc_buf:
    .word 0
    .word 0
    .align 6
