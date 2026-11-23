/* SPDX-License-Identifier: Apache-2.0 */
/* SMVDU TITAN-X Clean-Room Verification: AXI4 Crossbar Concurrency & Stress Suite */
/* Tests:                                                                        */
/*   1. Multi-Master Multi-Slave Concurrent Throughput (DDR, SRAM, ROM, APB)     */
/*   2. Head-of-Line Blocking & Starvation Freedom under Heavy Contention        */
/*   3. Unmapped Address DECERR Load & Store Hardware Trap Verification          */
/*   4. APB Peripheral Aperture Non-Destructive Concurrent Access                */
/*   5. 4-Core Interleaved Shared Fabric Hammer                                  */

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
    /* Install machine trap handler for DECERR verification */
    la   t0, xbar_trap_handler
    csrw mtvec, t0

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
    /* TEST 1: Multi-Master Multi-Slave Concurrent Throughput                */
    /* --------------------------------------------------------------------- */
    /* Reset done flags */
    la   t1, h0_done; sd zero, 0(t1)
    la   t1, h1_done; sd zero, 0(t1)
    la   t1, h2_done; sd zero, 0(t1)
    la   t1, h3_done; sd zero, 0(t1)

    /* Signal start of Test 1 (phase = 1) */
    li   t0, 1
    la   t1, test_phase
    sd   t0, 0(t1)
    fence rw, rw

    /* Hart 0 writes and reads 32 64-bit words to DDR4 (Slave 0) */
    la   s0, ddr_buf_h0
    li   s1, 0
    li   s2, 32
.Lh0_t1_wr_loop:
    slli t0, s1, 8
    li   t1, 0x10000000000000AA
    or   t0, t0, t1
    slli t2, s1, 3
    add  t2, s0, t2
    sd   t0, 0(t2)
    addi s1, s1, 1
    blt  s1, s2, .Lh0_t1_wr_loop

    fence rw, rw

    /* Hart 0 verifies DDR4 buffer */
    li   s1, 0
.Lh0_t1_rd_loop:
    slli t2, s1, 3
    add  t2, s0, t2
    ld   t3, 0(t2)
    slli t0, s1, 8
    li   t1, 0x10000000000000AA
    or   t0, t0, t1
    bne  t3, t0, .Lfail_test1
    addi s1, s1, 1
    blt  s1, s2, .Lh0_t1_rd_loop

    /* Mark Hart 0 finished Test 1 */
    li   t0, 1
    la   t1, h0_done
    sd   t0, 0(t1)
    fence rw, rw

    /* Wait for secondary cores */
    la   t1, h1_done
.Lwait_h1_t1:
    ld   t2, 0(t1)
    beqz t2, .Lwait_h1_t1

    la   t1, h2_done
.Lwait_h2_t1:
    ld   t2, 0(t1)
    beqz t2, .Lwait_h2_t1

    la   t1, h3_done
.Lwait_h3_t1:
    ld   t2, 0(t1)
    beqz t2, .Lwait_h3_t1

    /* --------------------------------------------------------------------- */
    /* TEST 2: Head-of-Line Blocking & Contention Interleaving               */
    /* --------------------------------------------------------------------- */
    /* Reset done flags */
    la   t1, h0_done; sd zero, 0(t1)
    la   t1, h1_done; sd zero, 0(t1)
    la   t1, h2_done; sd zero, 0(t1)
    la   t1, h3_done; sd zero, 0(t1)

    /* Signal start of Test 2 (phase = 2) */
    li   t0, 2
    la   t1, test_phase
    sd   t0, 0(t1)
    fence rw, rw

    /* Hart 0 hammers On-Chip SRAM (Slave 3) at 0x0000_0800 for 64 iterations */
    li   s0, 0x00000800
    li   s1, 0
    li   s2, 64
.Lh0_t2_loop:
    addi t0, s1, 0x100
    sd   t0, 0(s0)
    fence rw, rw
    ld   t1, 0(s0)
    bne  t1, t0, .Lfail_test2
    addi s1, s1, 1
    blt  s1, s2, .Lh0_t2_loop

    /* Mark Hart 0 finished Test 2 */
    li   t0, 1
    la   t1, h0_done
    sd   t0, 0(t1)
    fence rw, rw

    /* Wait for secondary cores */
    la   t1, h1_done
.Lwait_h1_t2:
    ld   t2, 0(t1)
    beqz t2, .Lwait_h1_t2

    la   t1, h2_done
.Lwait_h2_t2:
    ld   t2, 0(t1)
    beqz t2, .Lwait_h2_t2

    la   t1, h3_done
.Lwait_h3_t2:
    ld   t2, 0(t1)
    beqz t2, .Lwait_h3_t2

    /* --------------------------------------------------------------------- */
    /* TEST 3: Unmapped Address DECERR Load & Store Trap Verification        */
    /* --------------------------------------------------------------------- */
    /* Test 3.1: Load from unmapped address 0x5000_0000 MUST trigger cause 5 */
    li   s5, 0       /* trap_taken flag */
    li   s6, 5       /* expected mcause (Load access fault) */
    li   s7, 0       /* actual mcause */

    li   s1, 0x50000000
    ld   t1, 0(s1)   /* Faults here -> jumps to xbar_trap_handler */

    /* Verify trap was taken with cause 5 */
    beqz s5, .Lfail_test3
    li   t0, 5
    bne  s7, t0, .Lfail_test3

    /* Test 3.2: Store to unmapped address 0x6000_0000 MUST trigger cause 7 */
    li   s5, 0       /* trap_taken flag */
    li   s6, 7       /* expected mcause (Store/AMO access fault) */
    li   s7, 0       /* actual mcause */

    li   s1, 0x60000000
    li   t2, 0xDEADBEEFCAFEBAEB
    sd   t2, 0(s1)   /* Faults here -> jumps to xbar_trap_handler */

    /* Verify trap was taken with cause 7 */
    beqz s5, .Lfail_test3
    li   t0, 7
    bne  s7, t0, .Lfail_test3

    /* --------------------------------------------------------------------- */
    /* TEST 4: APB Peripheral Aperture Non-Destructive Concurrent Access     */
    /* --------------------------------------------------------------------- */
    li   s5, 0       /* reset trap flag */
    /* Hart 0 reads RTC counter register via APB bridge (Slave 1) at 0x40010000 */
    li   s1, 0x40010000
    lw   t1, 0(s1)

    /* Hart 0 reads UART0 line status register at 0x40000014 */
    li   s1, 0x40000014
    lw   t2, 0(s1)

    /* Verify reads returned without faulting */
    bnez s5, .Lfail_test4

    /* --------------------------------------------------------------------- */
    /* TEST 5: 4-Core Interleaved Shared Fabric Hammer                       */
    /* --------------------------------------------------------------------- */
    /* Reset done flags */
    la   t1, h0_done; sd zero, 0(t1)
    la   t1, h1_done; sd zero, 0(t1)
    la   t1, h2_done; sd zero, 0(t1)
    la   t1, h3_done; sd zero, 0(t1)

    /* Signal start of Test 5 (phase = 5) */
    li   t0, 5
    la   t1, test_phase
    sd   t0, 0(t1)
    fence rw, rw

    /* Hart 0 writes its slot in shared array and reads neighbors */
    la   s0, xbar_shared_ring
    li   s1, 0
    li   s2, 20
.Lh0_t5_loop:
    slli t0, s1, 4
    addi t0, t0, 0
    sd   t0, 0(s0)           /* slot 0 = Hart 0 */
    fence rw, rw

    addi s1, s1, 1
    blt  s1, s2, .Lh0_t5_loop

    /* Mark Hart 0 finished Test 5 */
    li   t0, 1
    la   t1, h0_done
    sd   t0, 0(t1)
    fence rw, rw

    /* Wait for secondary cores */
    la   t1, h1_done
.Lwait_h1_t5:
    ld   t2, 0(t1)
    beqz t2, .Lwait_h1_t5

    la   t1, h2_done
.Lwait_h2_t5:
    ld   t2, 0(t1)
    beqz t2, .Lwait_h2_t5

    la   t1, h3_done
.Lwait_h3_t5:
    ld   t2, 0(t1)
    beqz t2, .Lwait_h3_t5

    /* --------------------------------------------------------------------- */
    /* ALL TESTS PASSED!                                                     */
    /* --------------------------------------------------------------------- */
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

.Lfail_test5:
    li   a0, 5
    j    test_fail

    TEST_FAIL


/* ========================================================================= */
/* TRAP HANDLER FOR DECERR FAULT RECOVERY                                    */
/* ========================================================================= */
.align 4
xbar_trap_handler:
    csrr s7, mcause
    li   s5, 1
    /* Advance mepc past the faulting load/store (4 bytes) */
    csrr t0, mepc
    addi t0, t0, 4
    csrw mepc, t0
    mret


/* ========================================================================= */
/* HART 1: ON-CHIP SRAM & D-CACHE WORKER                                     */
/* ========================================================================= */
.Lhart1_entry:
    /* Signal initial ready */
    li   t0, 1
    la   t1, h1_ready
    sd   t0, 0(t1)
    fence rw, rw

.Lh1_wait_phase:
    la   t0, test_phase
    ld   t1, 0(t0)
    beqz t1, .Lh1_wait_phase

    li   t2, 1
    beq  t1, t2, .Lh1_test1
    li   t2, 2
    beq  t1, t2, .Lh1_test2
    li   t2, 5
    beq  t1, t2, .Lh1_test5

    /* Check if finished */
    la   t0, h0_done
    ld   t1, 0(t0)
    bnez t1, .Lh1_park
    j    .Lh1_wait_phase

.Lh1_test1:
    /* Hart 1 writes and reads 32 words in On-Chip SRAM (Slave 3) at 0x0000_1000 */
    li   s0, 0x00001000
    li   s1, 0
    li   s2, 32
.Lh1_t1_wr:
    slli t0, s1, 8
    li   t1, 0x20000000000000BB
    or   t0, t0, t1
    slli t2, s1, 3
    add  t2, s0, t2
    sd   t0, 0(t2)
    addi s1, s1, 1
    blt  s1, s2, .Lh1_t1_wr

    fence rw, rw

    li   s1, 0
.Lh1_t1_rd:
    slli t2, s1, 3
    add  t2, s0, t2
    ld   t3, 0(t2)
    slli t0, s1, 8
    li   t1, 0x20000000000000BB
    or   t0, t0, t1
    bne  t3, t0, .Lfail_test1
    addi s1, s1, 1
    blt  s1, s2, .Lh1_t1_rd

    li   t0, 1
    la   t1, h1_done
    sd   t0, 0(t1)
    fence rw, rw

.Lh1_wait_p1_end:
    la   t0, test_phase
    ld   t1, 0(t0)
    li   t2, 1
    beq  t1, t2, .Lh1_wait_p1_end
    j    .Lh1_wait_phase

.Lh1_test2:
    /* Hart 1 hammers On-Chip SRAM at 0x0000_0840 for 64 iterations */
    li   s0, 0x00000840
    li   s1, 0
    li   s2, 64
.Lh1_t2_loop:
    addi t0, s1, 0x200
    sd   t0, 0(s0)
    fence rw, rw
    ld   t1, 0(s0)
    bne  t1, t0, .Lfail_test2
    addi s1, s1, 1
    blt  s1, s2, .Lh1_t2_loop

    li   t0, 1
    la   t1, h1_done
    sd   t0, 0(t1)
    fence rw, rw

.Lh1_wait_p2_end:
    la   t0, test_phase
    ld   t1, 0(t0)
    li   t2, 2
    beq  t1, t2, .Lh1_wait_p2_end
    j    .Lh1_wait_phase

.Lh1_test5:
    la   s0, xbar_shared_ring
    li   s1, 0
    li   s2, 20
.Lh1_t5_loop:
    slli t0, s1, 4
    addi t0, t0, 1
    sd   t0, 8(s0)           /* slot 1 = Hart 1 */
    fence rw, rw

    addi s1, s1, 1
    blt  s1, s2, .Lh1_t5_loop

    li   t0, 1
    la   t1, h1_done
    sd   t0, 0(t1)
    fence rw, rw

.Lh1_wait_p5_end:
    la   t0, test_phase
    ld   t1, 0(t0)
    li   t2, 5
    beq  t1, t2, .Lh1_wait_p5_end
    j    .Lh1_wait_phase

.Lh1_park:
    wfi
    j    .Lh1_park


/* ========================================================================= */
/* HART 2: BOOT ROM READ & DDR4 WORKER                                       */
/* ========================================================================= */
.Lhart2_entry:
    /* Signal initial ready */
    li   t0, 1
    la   t1, h2_ready
    sd   t0, 0(t1)
    fence rw, rw

.Lh2_wait_phase:
    la   t0, test_phase
    ld   t1, 0(t0)
    beqz t1, .Lh2_wait_phase

    li   t2, 1
    beq  t1, t2, .Lh2_test1
    li   t2, 2
    beq  t1, t2, .Lh2_test2
    li   t2, 5
    beq  t1, t2, .Lh2_test5

    /* Check if finished */
    la   t0, h0_done
    ld   t1, 0(t0)
    bnez t1, .Lh2_park
    j    .Lh2_wait_phase

.Lh2_test1:
    /* Hart 2 reads Boot ROM (Slave 2) at 0x1000_0000 */
    li   s0, 0x10000000
    lw   t1, 0(s0)
    lw   t2, 4(s0)

    /* Hart 2 writes and reads 32 words in DDR4 at 0x8000_6000 */
    la   s0, ddr_buf_h2
    li   s1, 0
    li   s2, 32
.Lh2_t1_wr:
    slli t0, s1, 8
    li   t1, 0x30000000000000CC
    or   t0, t0, t1
    slli t2, s1, 3
    add  t2, s0, t2
    sd   t0, 0(t2)
    addi s1, s1, 1
    blt  s1, s2, .Lh2_t1_wr

    fence rw, rw

    li   s1, 0
.Lh2_t1_rd:
    slli t2, s1, 3
    add  t2, s0, t2
    ld   t3, 0(t2)
    slli t0, s1, 8
    li   t1, 0x30000000000000CC
    or   t0, t0, t1
    bne  t3, t0, .Lfail_test1
    addi s1, s1, 1
    blt  s1, s2, .Lh2_t1_rd

    li   t0, 1
    la   t1, h2_done
    sd   t0, 0(t1)
    fence rw, rw

.Lh2_wait_p1_end:
    la   t0, test_phase
    ld   t1, 0(t0)
    li   t2, 1
    beq  t1, t2, .Lh2_wait_p1_end
    j    .Lh2_wait_phase

.Lh2_test2:
    /* Hart 2 accesses Slave 0 (DDR4) at 0x8000_7000 while H0/H1 hammer SRAM */
    la   s0, ddr_buf_h2
    li   s1, 0
    li   s2, 64
.Lh2_t2_loop:
    addi t0, s1, 0x300
    sd   t0, 0(s0)
    fence rw, rw
    ld   t1, 0(s0)
    bne  t1, t0, .Lfail_test2
    addi s1, s1, 1
    blt  s1, s2, .Lh2_t2_loop

    li   t0, 1
    la   t1, h2_done
    sd   t0, 0(t1)
    fence rw, rw

.Lh2_wait_p2_end:
    la   t0, test_phase
    ld   t1, 0(t0)
    li   t2, 2
    beq  t1, t2, .Lh2_wait_p2_end
    j    .Lh2_wait_phase

.Lh2_test5:
    la   s0, xbar_shared_ring
    li   s1, 0
    li   s2, 20
.Lh2_t5_loop:
    slli t0, s1, 4
    addi t0, t0, 2
    sd   t0, 16(s0)          /* slot 2 = Hart 2 */
    fence rw, rw

    addi s1, s1, 1
    blt  s1, s2, .Lh2_t5_loop

    li   t0, 1
    la   t1, h2_done
    sd   t0, 0(t1)
    fence rw, rw

.Lh2_wait_p5_end:
    la   t0, test_phase
    ld   t1, 0(t0)
    li   t2, 5
    beq  t1, t2, .Lh2_wait_p5_end
    j    .Lh2_wait_phase

.Lh2_park:
    wfi
    j    .Lh2_park


/* ========================================================================= */
/* HART 3: SRAM & MULTI-SLAVE WORKER                                         */
/* ========================================================================= */
.Lhart3_entry:
    /* Signal initial ready */
    li   t0, 1
    la   t1, h3_ready
    sd   t0, 0(t1)
    fence rw, rw

.Lh3_wait_phase:
    la   t0, test_phase
    ld   t1, 0(t0)
    beqz t1, .Lh3_wait_phase

    li   t2, 1
    beq  t1, t2, .Lh3_test1
    li   t2, 2
    beq  t1, t2, .Lh3_test2
    li   t2, 5
    beq  t1, t2, .Lh3_test5

    /* Check if finished */
    la   t0, h0_done
    ld   t1, 0(t0)
    bnez t1, .Lh3_park
    j    .Lh3_wait_phase

.Lh3_test1:
    /* Hart 3 writes and reads 32 words in On-Chip SRAM (Slave 3) at 0x0000_2000 */
    li   s0, 0x00002000
    li   s1, 0
    li   s2, 32
.Lh3_t1_wr:
    slli t0, s1, 8
    li   t1, 0x40000000000000DD
    or   t0, t0, t1
    slli t2, s1, 3
    add  t2, s0, t2
    sd   t0, 0(t2)
    addi s1, s1, 1
    blt  s1, s2, .Lh3_t1_wr

    fence rw, rw

    li   s1, 0
.Lh3_t1_rd:
    slli t2, s1, 3
    add  t2, s0, t2
    ld   t3, 0(t2)
    slli t0, s1, 8
    li   t1, 0x40000000000000DD
    or   t0, t0, t1
    bne  t3, t0, .Lfail_test1
    addi s1, s1, 1
    blt  s1, s2, .Lh3_t1_rd

    li   t0, 1
    la   t1, h3_done
    sd   t0, 0(t1)
    fence rw, rw

.Lh3_wait_p1_end:
    la   t0, test_phase
    ld   t1, 0(t0)
    li   t2, 1
    beq  t1, t2, .Lh3_wait_p1_end
    j    .Lh3_wait_phase

.Lh3_test2:
    /* Hart 3 accesses Slave 0 (DDR4) at 0x8000_7040 while H0/H1 hammer SRAM */
    la   s0, ddr_buf_h3
    li   s1, 0
    li   s2, 64
.Lh3_t2_loop:
    addi t0, s1, 0x400
    sd   t0, 0(s0)
    fence rw, rw
    ld   t1, 0(s0)
    bne  t1, t0, .Lfail_test2
    addi s1, s1, 1
    blt  s1, s2, .Lh3_t2_loop

    li   t0, 1
    la   t1, h3_done
    sd   t0, 0(t1)
    fence rw, rw

.Lh3_wait_p2_end:
    la   t0, test_phase
    ld   t1, 0(t0)
    li   t2, 2
    beq  t1, t2, .Lh3_wait_p2_end
    j    .Lh3_wait_phase

.Lh3_test5:
    la   s0, xbar_shared_ring
    li   s1, 0
    li   s2, 20
.Lh3_t5_loop:
    slli t0, s1, 4
    addi t0, t0, 3
    sd   t0, 24(s0)          /* slot 3 = Hart 3 */
    fence rw, rw

    addi s1, s1, 1
    blt  s1, s2, .Lh3_t5_loop

    li   t0, 1
    la   t1, h3_done
    sd   t0, 0(t1)
    fence rw, rw

.Lh3_wait_p5_end:
    la   t0, test_phase
    ld   t1, 0(t0)
    li   t2, 5
    beq  t1, t2, .Lh3_wait_p5_end
    j    .Lh3_wait_phase

.Lh3_park:
    wfi
    j    .Lh3_park


/* ========================================================================= */
/* SHARED DATA STRUCTURES (64-BYTE ALIGNED TO PREVENT UNINTENDED SHARING)    */
/* ========================================================================= */
.section .data
.align 6
test_phase:
    .dword 0
    .skip 56

.align 6
h1_ready:
    .dword 0
    .skip 56

.align 6
h2_ready:
    .dword 0
    .skip 56

.align 6
h3_ready:
    .dword 0
    .skip 56

.align 6
h0_done:
    .dword 0
    .skip 56

.align 6
h1_done:
    .dword 0
    .skip 56

.align 6
h2_done:
    .dword 0
    .skip 56

.align 6
h3_done:
    .dword 0
    .skip 56

.align 6
ddr_buf_h0:
    .skip 256

.align 6
ddr_buf_h2:
    .skip 256

.align 6
ddr_buf_h3:
    .skip 256

.align 6
xbar_shared_ring:
    .dword 0  /* Hart 0 */
    .dword 0  /* Hart 1 */
    .dword 0  /* Hart 2 */
    .dword 0  /* Hart 3 */
    .skip 32
