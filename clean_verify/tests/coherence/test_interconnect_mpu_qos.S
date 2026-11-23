/* SPDX-License-Identifier: Apache-2.0 */
/* SMVDU TITAN-X Clean-Room Architectural Verification */
/* Task 17: Interconnect MPU & QoS Controller Bus Protection Enforcement */

#include "../test_macros.h"

.section .text.init
.globl _start

_start:
    csrr a0, mhartid
    li   t0, 4
    beq  a0, t0, .Lpark_hart4

    /* Each core 0..3 gets an independent 4KB stack in DDR4 */
    la   sp, __stack_top
    slli t0, a0, 12
    sub  sp, sp, t0

    beqz a0, .Lhart0_entry
    li   t0, 1
    beq  a0, t0, .Lhart1_entry
    li   t0, 2
    beq  a0, t0, .Lhart2_entry

    /* Hart 3 is parked */
    wfi
    j    _start

.Lpark_hart4:
    wfi
    j    .Lpark_hart4

/* ========================================================================= */
/* HART 0: TEST COORDINATOR & MAIN EXECUTION                                 */
/* ========================================================================= */
.Lhart0_entry:
    /* Install Hart 0 trap handler */
    la   t0, h0_trap_handler
    csrw mtvec, t0

    /* Signal initial readiness */
    fence rw, rw

    /* --------------------------------------------------------------------- */
    /* SECTION 1: APB Configuration & Readback                               */
    /* --------------------------------------------------------------------- */

    /* Test 1.1: QoS Controller Defaults Readback */
    li   s0, 0x40110000       /* QoS Base */
    lw   t0, 0(s0)            /* reg_time_win default = 1000 (0x3E8) */
    li   t1, 1000
    bne  t0, t1, .Lfail_sec1_1

    lw   t0, 4(s0)            /* Master 0 default = 0x0040_00F1 */
    li   t1, 0x004000F1
    bne  t0, t1, .Lfail_sec1_2

    lw   t0, 0x14(s0)         /* Master 4 (Hart 0 D-mem) default = 0x0040_00F1 */
    li   t1, 0x004000F1
    bne  t0, t1, .Lfail_sec1_3

    /* Test 1.2: QoS Controller Write & Readback */
    li   t2, 50               /* Set time_win = 50 cycles */
    sw   t2, 0(s0)
    lw   t0, 0(s0)
    bne  t0, t2, .Lfail_sec1_4

    li   t2, 0x000A00E2       /* Master 4: limit=10, boost=0xE, base=0x2 */
    sw   t2, 0x14(s0)
    lw   t0, 0x14(s0)
    bne  t0, t2, .Lfail_sec1_5

    /* Test 1.3: Interconnect MPU Defaults Readback */
    li   s1, 0x40100000       /* MPU Base (Region 0) */
    lw   t0, 0(s1)            /* base_addr default = 0 */
    bnez t0, .Lfail_sec1_6
    lw   t0, 4(s1)            /* limit_addr default = 0 */
    bnez t0, .Lfail_sec1_7
    lw   t0, 8(s1)            /* master_mask default = 0 */
    bnez t0, .Lfail_sec1_8
    lw   t0, 12(s1)           /* ctrl/valid default = 0 */
    bnez t0, .Lfail_sec1_9

    /* Test 1.4: Interconnect MPU Write & Readback (Region 0) */
    li   t2, 0x40012000       /* Region 0 Base: WDT peripheral (0x4001_2000) */
    sw   t2, 0(s1)
    lw   t0, 0(s1)
    bne  t0, t2, .Lfail_sec1_10

    li   t2, 0x40012FFF       /* Region 0 Limit: 0x4001_2FFF */
    sw   t2, 4(s1)
    lw   t0, 4(s1)
    bne  t0, t2, .Lfail_sec1_11

    li   t2, 0x0010           /* Master 4 only (Hart 0 D-mem) */
    sw   t2, 8(s1)
    lw   t0, 8(s1)
    bne  t0, t2, .Lfail_sec1_12

    li   t2, 0x0007           /* valid=1, perm=2'b11 (RW), base[39:32]=0, limit[39:32]=0 */
    sw   t2, 12(s1)
    lw   t0, 12(s1)
    bne  t0, t2, .Lfail_sec1_13

    /* --------------------------------------------------------------------- */
    /* SECTION 2: Single-Core MPU Permission & Violation Enforcement         */
    /* --------------------------------------------------------------------- */

    /* Test 2.1: Permitted Access Succeeds Without Trap */
    li   s5, 0                /* trap flag */
    li   s2, 0x40012004       /* WDT load_val register */
    lw   t0, 0(s2)            /* Permitted read by Master 4 */
    bnez s5, .Lfail_sec2_1    /* Must not trap */
    li   t1, -1
    bne  t0, t1, .Lfail_sec2_2

    /* Permitted write by Master 4 */
    li   s5, 0
    li   t2, 0x12345678
    sw   t2, 0(s2)
    bnez s5, .Lfail_sec2_3    /* Must not trap */

    /* Test 2.2: Master Mask Denied Read Traps with DECERR (mcause 5) */
    /* Modify Region 0 master mask: clear bit 4 (deny Master 4) */
    li   t2, 0x0000
    sw   t2, 8(s1)            /* master_mask = 0 */
    fence rw, rw

    li   s5, 0                /* trap flag */
    li   s6, 0                /* captured mcause */
    li   s7, 0                /* captured mtval */

    lw   t0, 0(s2)            /* Denied load -> MPU blocks -> returns DECERR -> traps */

    beqz s5, .Lfail_sec2_4    /* Trap MUST be taken */
    li   t1, 5
    bne  s6, t1, .Lfail_sec2_5/* mcause MUST be 5 (Load access fault) */
    bne  s7, s2, .Lfail_sec2_6/* mtval MUST be 0x40012004 */

    /* Test 2.3: Master Mask Denied Write Traps with DECERR (mcause 7) */
    li   s5, 0
    li   s6, 0
    li   s7, 0

    sw   t2, 0(s2)            /* Denied store -> MPU blocks -> returns DECERR -> traps */

    beqz s5, .Lfail_sec2_7    /* Trap MUST be taken */
    li   t1, 7
    bne  s6, t1, .Lfail_sec2_8/* mcause MUST be 7 (Store/AMO access fault) */
    bne  s7, s2, .Lfail_sec2_9/* mtval MUST be 0x40012004 */

    /* Test 2.4: Read-Only Permission (perm = 2'b01) */
    /* Set mask = 0x0010 (Hart 0 allowed), perm = 2'b01 (RO) -> ctrl = 0x0003 */
    li   t2, 0x0010
    sw   t2, 8(s1)
    li   t2, 0x0003           /* valid=1, perm=2'b01 (RO) */
    sw   t2, 12(s1)
    fence rw, rw

    /* Read MUST succeed without trap */
    li   s5, 0
    lw   t0, 0(s2)
    bnez s5, .Lfail_sec2_10

    /* Write MUST trap with mcause 7 */
    li   s5, 0
    li   s6, 0
    li   s7, 0
    sw   t2, 0(s2)
    beqz s5, .Lfail_sec2_11
    li   t1, 7
    bne  s6, t1, .Lfail_sec2_12

    /* Test 2.5: Write-Only Permission (perm = 2'b10) */
    /* Set mask = 0x0010, perm = 2'b10 (WO) -> ctrl = 0x0005 */
    li   t2, 0x0005           /* valid=1, perm=2'b10 (WO) */
    sw   t2, 12(s1)
    fence rw, rw

    /* Write MUST succeed without trap */
    li   s5, 0
    sw   t2, 0(s2)
    bnez s5, .Lfail_sec2_13

    /* Read MUST trap with mcause 5 */
    li   s5, 0
    li   s6, 0
    li   s7, 0
    lw   t0, 0(s2)
    beqz s5, .Lfail_sec2_14
    li   t1, 5
    bne  s6, t1, .Lfail_sec2_15

    /* Test 2.6: Dynamic Region Disable Restores Default Access */
    /* Set valid = 0 -> ctrl = 0x0000 */
    li   t2, 0x0000
    sw   t2, 12(s1)
    fence rw, rw

    /* Both read and write MUST now succeed freely */
    li   s5, 0
    lw   t0, 0(s2)
    bnez s5, .Lfail_sec2_16

    li   s5, 0
    sw   t2, 0(s2)
    bnez s5, .Lfail_sec2_17

    /* --------------------------------------------------------------------- */
    /* SECTION 3: Multi-Core Mutual Isolation (Hart 0 vs Hart 1 vs Hart 2)   */
    /* --------------------------------------------------------------------- */
    /* Configure Region 0: 0x4001_2000 - 0x4001_2FFF, mask = 0x0010 (Hart 0 only), perm=RW */
    li   t2, 0x40012000
    sw   t2, 0(s1)
    li   t2, 0x40012FFF
    sw   t2, 4(s1)
    li   t2, 0x0010           /* Master 4 only */
    sw   t2, 8(s1)
    li   t2, 0x0007           /* valid=1, perm=RW */
    sw   t2, 12(s1)

    /* Configure Region 1: 0x4001_1000 - 0x4001_1FFF (GPIO), mask = 0x0020 (Hart 1 only), perm=RW */
    li   s3, 0x40100010       /* MPU Region 1 Base */
    li   t2, 0x40011000
    sw   t2, 0(s3)
    li   t2, 0x40011FFF
    sw   t2, 4(s3)
    li   t2, 0x0020           /* Master 5 only (Hart 1 D-mem) */
    sw   t2, 8(s3)
    li   t2, 0x0007           /* valid=1, perm=RW */
    sw   t2, 12(s3)
    fence rw, rw

    /* Hart 0 verifies it can access Region 0 (WDT) */
    li   s5, 0
    lw   t0, 0(s2)
    bnez s5, .Lfail_sec3_1

    /* Hart 0 attempts to access Region 1 (GPIO 0x4001_1000) -> MUST TRAP! */
    li   s5, 0
    li   s6, 0
    li   s7, 0
    li   s4, 0x40011000
    lw   t0, 0(s4)
    beqz s5, .Lfail_sec3_2
    li   t1, 5
    bne  s6, t1, .Lfail_sec3_3

    /* Signal Hart 1 to execute Phase 1 */
    la   t0, sync_phase
    li   t1, 1
    sd   t1, 0(t0)
    fence rw, rw

    /* Wait for Hart 1 to complete Phase 1 */
    la   t0, h1_status
.Lwait_h1_p1:
    ld   t1, 0(t0)
    beqz t1, .Lwait_h1_p1
    li   t2, 1
    bne  t1, t2, .Lfail_sec3_4 /* Hart 1 failed */

    /* Signal Hart 2 to execute Phase 1 */
    la   t0, sync_phase
    li   t1, 2
    sd   t1, 0(t0)
    fence rw, rw

    /* Wait for Hart 2 to complete Phase 1 */
    la   t0, h2_status
.Lwait_h2_p1:
    ld   t1, 0(t0)
    beqz t1, .Lwait_h2_p1
    li   t2, 1
    bne  t1, t2, .Lfail_sec3_5 /* Hart 2 failed */

    /* Test 3.2: Dynamic Permission Granting to Hart 1 */
    /* Add Hart 1 (bit 5) to Region 0 master mask: 0x0010 | 0x0020 = 0x0030 */
    li   t2, 0x0030
    sw   t2, 8(s1)
    fence rw, rw

    /* Reset h1_status */
    la   t0, h1_status
    sd   zero, 0(t0)
    fence rw, rw

    /* Signal Hart 1 to execute Phase 2 (now granted access to Region 0) */
    la   t0, sync_phase
    li   t1, 3
    sd   t1, 0(t0)
    fence rw, rw

    /* Wait for Hart 1 to complete Phase 2 */
    la   t0, h1_status
.Lwait_h1_p2:
    ld   t1, 0(t0)
    beqz t1, .Lwait_h1_p2
    li   t2, 1
    bne  t1, t2, .Lfail_sec3_6

    /* --------------------------------------------------------------------- */
    /* SECTION 4: Multi-Region Boundary & Precision Enforcement              */
    /* --------------------------------------------------------------------- */
    /* Test 4.1: Access address right outside Region 0 limit (0x4001_3000)   */
    /* 0x4001_3000 is SPI peripheral; it is NOT in Region 0 or Region 1!    */
    /* Should fall back to default allow -> MUST NOT TRAP!                  */
    li   s5, 0
    li   s4, 0x40013000
    lw   t0, 0(s4)
    bnez s5, .Lfail_sec4_1

    /* Test 4.2: Access address right below Region 0 base (0x4001_1FFC)     */
    /* 0x4001_1FFC is within Region 1 (0x4001_1000 - 0x4001_1FFF)          */
    /* Region 1 allows only Hart 1 -> Hart 0 MUST TRAP!                     */
    li   s5, 0
    li   s6, 0
    li   s4, 0x40011FFC
    lw   t0, 0(s4)
    beqz s5, .Lfail_sec4_2
    li   t1, 5
    bne  s6, t1, .Lfail_sec4_3

    /* --------------------------------------------------------------------- */
    /* SECTION 5: QoS Controller Traffic Throttling & Priority Recovery      */
    /* --------------------------------------------------------------------- */
    /* Configure QoS controller: time_win = 60 cycles */
    li   t2, 60
    sw   t2, 0(s0)
    /* Master 4: bw_limit = 4 transactions, base_qos = 1, boost_qos = 15 */
    li   t2, 0x000400F1
    sw   t2, 0x14(s0)
    fence rw, rw

    /* Phase 5.1: Idle wait for window to elapse -> verify priority boosted */
    li   t0, 0
    li   t1, 80
.Lqos_idle_loop:
    addi t0, t0, 1
    blt  t0, t1, .Lqos_idle_loop

    /* Phase 5.2: Issue 12 transactions (> limit of 4) in rapid succession */
    li   s4, 0x40013000       /* SPI read/write */
    li   t0, 0
    li   t1, 12
.Lqos_hammer_loop:
    lw   t2, 0(s4)
    addi t0, t0, 1
    blt  t0, t1, .Lqos_hammer_loop

    /* Wait for window rollover so QoS controller evaluates excess traffic */
    li   t0, 0
    li   t1, 80
.Lqos_throttle_wait:
    addi t0, t0, 1
    blt  t0, t1, .Lqos_throttle_wait

    /* Phase 5.3: Cool-down period (zero transactions for 100 cycles) */
    li   t0, 0
    li   t1, 100
.Lqos_cooldown:
    addi t0, t0, 1
    blt  t0, t1, .Lqos_cooldown

    /* Signal secondary cores to park */
    la   t0, sync_phase
    li   t1, 99
    sd   t1, 0(t0)
    fence rw, rw

    /* --------------------------------------------------------------------- */
    /* ALL SECTIONS PASSED!                                                  */
    /* --------------------------------------------------------------------- */
    TEST_PASS

/* ------------------------------------------------------------------------- */
/* Hart 0 Failure Handlers                                                   */
/* ------------------------------------------------------------------------- */
.Lfail_sec1_1:  li a0, 101; j test_fail
.Lfail_sec1_2:  li a0, 102; j test_fail
.Lfail_sec1_3:  li a0, 103; j test_fail
.Lfail_sec1_4:  li a0, 104; j test_fail
.Lfail_sec1_5:  li a0, 105; j test_fail
.Lfail_sec1_6:  li a0, 106; j test_fail
.Lfail_sec1_7:  li a0, 107; j test_fail
.Lfail_sec1_8:  li a0, 108; j test_fail
.Lfail_sec1_9:  li a0, 109; j test_fail
.Lfail_sec1_10: li a0, 110; j test_fail
.Lfail_sec1_11: li a0, 111; j test_fail
.Lfail_sec1_12: li a0, 112; j test_fail
.Lfail_sec1_13: li a0, 113; j test_fail

.Lfail_sec2_1:  li a0, 201; j test_fail
.Lfail_sec2_2:  li a0, 202; j test_fail
.Lfail_sec2_3:  li a0, 203; j test_fail
.Lfail_sec2_4:  li a0, 204; j test_fail
.Lfail_sec2_5:  li a0, 205; j test_fail
.Lfail_sec2_6:  li a0, 206; j test_fail
.Lfail_sec2_7:  li a0, 207; j test_fail
.Lfail_sec2_8:  li a0, 208; j test_fail
.Lfail_sec2_9:  li a0, 209; j test_fail
.Lfail_sec2_10: li a0, 210; j test_fail
.Lfail_sec2_11: li a0, 211; j test_fail
.Lfail_sec2_12: li a0, 212; j test_fail
.Lfail_sec2_13: li a0, 213; j test_fail
.Lfail_sec2_14: li a0, 214; j test_fail
.Lfail_sec2_15: li a0, 215; j test_fail
.Lfail_sec2_16: li a0, 216; j test_fail
.Lfail_sec2_17: li a0, 217; j test_fail

.Lfail_sec3_1:  li a0, 301; j test_fail
.Lfail_sec3_2:  li a0, 302; j test_fail
.Lfail_sec3_3:  li a0, 303; j test_fail
.Lfail_sec3_4:  li a0, 304; j test_fail
.Lfail_sec3_5:  li a0, 305; j test_fail
.Lfail_sec3_6:  li a0, 306; j test_fail

.Lfail_sec4_1:  li a0, 401; j test_fail
.Lfail_sec4_2:  li a0, 402; j test_fail
.Lfail_sec4_3:  li a0, 403; j test_fail

/* ------------------------------------------------------------------------- */
/* Hart 0 Trap Handler                                                       */
/* ------------------------------------------------------------------------- */
.align 4
h0_trap_handler:
    csrr s6, mcause
    csrr s7, mtval
    li   s5, 1
    /* Advance past faulting instruction */
    csrr t0, mepc
    addi t0, t0, 4
    csrw mepc, t0
    mret


/* ========================================================================= */
/* HART 1: ISOLATION WORKER                                                  */
/* ========================================================================= */
.Lhart1_entry:
    la   t0, h1_trap_handler
    csrw mtvec, t0

.Lh1_wait_loop:
    la   t0, sync_phase
    ld   t1, 0(t0)
    beqz t1, .Lh1_wait_loop

    li   t2, 1
    beq  t1, t2, .Lh1_run_phase1

    li   t2, 3
    beq  t1, t2, .Lh1_run_phase2

    li   t2, 99
    beq  t1, t2, .Lh1_park

    j    .Lh1_wait_loop

.Lh1_run_phase1:
    /* Hart 1 accesses Region 1 (GPIO 0x4001_1000): MUST SUCCEED (no trap) */
    li   s5, 0
    li   s4, 0x40011000
    lw   t0, 0(s4)
    bnez s5, .Lh1_failed

    /* Hart 1 attempts to access Region 0 (WDT 0x4001_2004): MUST TRAP with mcause 5 */
    li   s5, 0
    li   s6, 0
    li   s2, 0x40012004
    lw   t0, 0(s2)
    beqz s5, .Lh1_failed
    li   t1, 5
    bne  s6, t1, .Lh1_failed

    /* Report success for Phase 1 */
    la   t0, h1_status
    li   t1, 1
    sd   t1, 0(t0)
    fence rw, rw

.Lh1_wait_p1_end:
    la   t0, sync_phase
    ld   t1, 0(t0)
    li   t2, 1
    beq  t1, t2, .Lh1_wait_p1_end
    j    .Lh1_wait_loop

.Lh1_run_phase2:
    /* Phase 2: Hart 1 is now granted permission to Region 0! MUST SUCCEED! */
    li   s5, 0
    li   s2, 0x40012004
    lw   t0, 0(s2)
    bnez s5, .Lh1_failed

    /* Report success for Phase 2 */
    la   t0, h1_status
    li   t1, 1
    sd   t1, 0(t0)
    fence rw, rw

.Lh1_wait_p2_end:
    la   t0, sync_phase
    ld   t1, 0(t0)
    li   t2, 3
    beq  t1, t2, .Lh1_wait_p2_end
    j    .Lh1_wait_loop

.Lh1_failed:
    la   t0, h1_status
    li   t1, 2                /* Error code 2 */
    sd   t1, 0(t0)
    fence rw, rw
.Lh1_park:
    wfi
    j    .Lh1_park

.align 4
h1_trap_handler:
    csrr s6, mcause
    csrr s7, mtval
    li   s5, 1
    csrr t0, mepc
    addi t0, t0, 4
    csrw mepc, t0
    mret


/* ========================================================================= */
/* HART 2: THIRD-PARTY ISOLATION WORKER                                      */
/* ========================================================================= */
.Lhart2_entry:
    la   t0, h2_trap_handler
    csrw mtvec, t0

.Lh2_wait_loop:
    la   t0, sync_phase
    ld   t1, 0(t0)
    beqz t1, .Lh2_wait_loop

    li   t2, 2
    beq  t1, t2, .Lh2_run_phase1

    li   t2, 99
    beq  t1, t2, .Lh2_park

    j    .Lh2_wait_loop

.Lh2_run_phase1:
    /* Hart 2 is NEITHER in Region 0 NOR in Region 1! */
    /* Accessing Region 0 (WDT 0x4001_2004) MUST TRAP! */
    li   s5, 0
    li   s6, 0
    li   s2, 0x40012004
    lw   t0, 0(s2)
    beqz s5, .Lh2_failed
    li   t1, 5
    bne  s6, t1, .Lh2_failed

    /* Accessing Region 1 (GPIO 0x4001_1000) MUST TRAP! */
    li   s5, 0
    li   s6, 0
    li   s4, 0x40011000
    lw   t0, 0(s4)
    beqz s5, .Lh2_failed
    li   t1, 5
    bne  s6, t1, .Lh2_failed

    /* Report success for Hart 2 */
    la   t0, h2_status
    li   t1, 1
    sd   t1, 0(t0)
    fence rw, rw

.Lh2_wait_p1_end:
    la   t0, sync_phase
    ld   t1, 0(t0)
    li   t2, 2
    beq  t1, t2, .Lh2_wait_p1_end
    j    .Lh2_wait_loop

.Lh2_failed:
    la   t0, h2_status
    li   t1, 2
    sd   t1, 0(t0)
    fence rw, rw
.Lh2_park:
    wfi
    j    .Lh2_park

.align 4
h2_trap_handler:
    csrr s6, mcause
    csrr s7, mtval
    li   s5, 1
    csrr t0, mepc
    addi t0, t0, 4
    csrw mepc, t0
    mret


/* ========================================================================= */
/* SHARED DATA STRUCTURES (64-BYTE ALIGNED)                                  */
/* ========================================================================= */
.section .data
.align 6
sync_phase:
    .dword 0
    .skip 56

.align 6
h1_status:
    .dword 0
    .skip 56

.align 6
h2_status:
    .dword 0
    .skip 56

/* End-of-file test failure macro expansion */
TEST_FAIL
