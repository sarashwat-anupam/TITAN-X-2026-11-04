/* SPDX-License-Identifier: Apache-2.0 */
/* TITAN-X Clean-Room Verification: RV64I Datapath Stress Test */

#include "../test_macros.h"

INIT_TEST

    /* ----------------------------------------------------------------- */
    /* Test 1..10: Basic Arithmetic & Logical Immediate Operations       */
    /* ----------------------------------------------------------------- */
    TEST_CASE(1, a1, 42,
        addi a1, x0, 42
    )

    TEST_CASE(2, a1, -1,
        addi a1, x0, -1
    )

    TEST_CASE(3, a1, 0x12345000,
        lui  a1, 0x12345
    )

    TEST_CASE(4, a1, 15,
        addi a2, x0, 10;
        addi a1, a2, 5
    )

    TEST_CASE(5, a1, 5,
        addi a2, x0, 10;
        addi a3, x0, 5;
        sub  a1, a2, a3
    )

    TEST_CASE(6, a1, 0x0F,
        addi a2, x0, 0x1F;
        andi a1, a2, 0x0F
    )

    TEST_CASE(7, a1, 0x3F,
        addi a2, x0, 0x30;
        ori  a1, a2, 0x0F
    )

    TEST_CASE(8, a1, 0x30,
        addi a2, x0, 0x3F;
        xori a1, a2, 0x0F
    )

    TEST_CASE(9, a1, 1,
        addi a2, x0, -5;
        addi a3, x0, 5;
        slt  a1, a2, a3
    )

    TEST_CASE(10, a1, 0,
        addi a2, x0, -5;
        addi a3, x0, 5;
        sltu a1, a2, a3
    )

    /* ----------------------------------------------------------------- */
    /* Test 11..20: 64-bit Shifts (SLL, SRL, SRA, SLLI, SRLI, SRAI)       */
    /* ----------------------------------------------------------------- */
    TEST_CASE(11, a1, 0x40,
        addi a2, x0, 1;
        slli a1, a2, 6
    )

    TEST_CASE(12, a1, 0x01,
        addi a2, x0, 0x40;
        srli a1, a2, 6
    )

    TEST_CASE(13, a1, -1,
        addi a2, x0, -4;
        srai a1, a2, 2
    )

    TEST_CASE(14, a1, 0x8000000000000000,
        addi a2, x0, 1;
        slli a1, a2, 63
    )

    TEST_CASE(15, a1, 1,
        addi a2, x0, 1;
        slli a2, a2, 63;
        srli a1, a2, 63
    )

    TEST_CASE(16, a1, -1,
        addi a2, x0, 1;
        slli a2, a2, 63;
        srai a1, a2, 63
    )

    /* ----------------------------------------------------------------- */
    /* Test 21..30: RV64 Word Operations (ADDW, SUBW, SLLW, SRLW, SRAW) */
    /* ----------------------------------------------------------------- */
    TEST_CASE(21, a1, -1,
        addiw a1, x0, -1
    )

    TEST_CASE(22, a1, 0x3FFFFFFF,
        lui   a2, 0x40000;
        addiw a1, a2, -1
    )

    TEST_CASE(23, a1, -0x80000000,
        lui   a2, 0x40000;
        addiw a3, a2, 0;
        addw  a1, a3, a3
    )

    TEST_CASE(24, a1, 0x40,
        addi  a2, x0, 1;
        slliw a1, a2, 6
    )

    TEST_CASE(25, a1, 0x01,
        addi  a2, x0, 0x40;
        srliw a1, a2, 6
    )

    TEST_CASE(26, a1, -1,
        addiw a2, x0, -4;
        sraiw a1, a2, 2
    )

    /* ----------------------------------------------------------------- */
    /* Test 31..40: Branches & Jumps (BEQ, BNE, BLT, BGE, BLTU, BGEU)    */
    /* ----------------------------------------------------------------- */
    TEST_CASE(31, a1, 100,
        addi a2, x0, 10;
        addi a3, x0, 10;
        beq  a2, a3, 1f;
        addi a1, x0, 999;
        j    2f;
    1:  addi a1, x0, 100;
    2:
    )

    TEST_CASE(32, a1, 200,
        addi a2, x0, 10;
        addi a3, x0, 20;
        bne  a2, a3, 1f;
        addi a1, x0, 999;
        j    2f;
    1:  addi a1, x0, 200;
    2:
    )

    TEST_CASE(33, a1, 300,
        addi a2, x0, -10;
        addi a3, x0, 10;
        blt  a2, a3, 1f;
        addi a1, x0, 999;
        j    2f;
    1:  addi a1, x0, 300;
    2:
    )

    TEST_CASE(34, a1, 400,
        addi a2, x0, 10;
        addi a3, x0, -10;
        bge  a2, a3, 1f;
        addi a1, x0, 999;
        j    2f;
    1:  addi a1, x0, 400;
    2:
    )

    TEST_CASE(35, a1, 500,
        addi a2, x0, 10;
        addi a3, x0, -10;
        bltu a2, a3, 1f;
        addi a1, x0, 999;
        j    2f;
    1:  addi a1, x0, 500;
    2:
    )

    TEST_CASE(36, a1, 600,
        la   ra, 2f;
        j    1f;
        addi a1, x0, 999;
    1:  addi a1, x0, 600;
        jr   ra;
    2:
    )

    /* ----------------------------------------------------------------- */
    /* Test 41..50: Load / Store Operations (LB, LH, LW, LD, LBU, LHU, LWU)*/
    /* ----------------------------------------------------------------- */
    /* Allocate test buffer on stack */
    TEST_CASE(41, a1, 0x123456789ABCDEF0,
        li   t1, 0x123456789ABCDEF0;
        sd   t1, 0(sp);
        ld   a1, 0(sp)
    )

    TEST_CASE(42, a1, 0x000000009ABCDEF0,
        lwu  a1, 0(sp)
    )

    TEST_CASE(43, a1, 0xFFFFFFFF9ABCDEF0,
        lw   a1, 0(sp)
    )

    TEST_CASE(44, a1, 0x000000000000DEF0,
        lhu  a1, 0(sp)
    )

    TEST_CASE(45, a1, 0xFFFFFFFFFFFFDEF0,
        lh   a1, 0(sp)
    )

    TEST_CASE(46, a1, 0x00000000000000F0,
        lbu  a1, 0(sp)
    )

    TEST_CASE(47, a1, 0xFFFFFFFFFFFFFFF0,
        lb   a1, 0(sp)
    )

    TEST_CASE(48, a1, 0xA5,
        li   t1, 0xA5;
        sb   t1, 8(sp);
        lbu  a1, 8(sp)
    )

    TEST_CASE(49, a1, 0x5AA5,
        li   t1, 0x5AA5;
        sh   t1, 8(sp);
        lhu  a1, 8(sp)
    )

    TEST_CASE(50, a1, 0x12345678,
        li   t1, 0x12345678;
        sw   t1, 8(sp);
        lwu  a1, 8(sp)
    )

    TEST_PASS
    TEST_FAIL
