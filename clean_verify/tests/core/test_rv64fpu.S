/* SPDX-License-Identifier: Apache-2.0 */
/* TITAN-X Clean-Room Verification: RV64F/D IEEE-754 FPU Execution Test */

#include "../test_macros.h"

INIT_TEST

    /* ----------------------------------------------------------------- */
    /* Step 0: Enable FPU in mstatus (mstatus.FS = 2'b11 = 0x6000)       */
    /* ----------------------------------------------------------------- */
    li   t0, 0x00006000
    csrs mstatus, t0

    /* Reset FCSR */
    fscsr x0

    /* ----------------------------------------------------------------- */
    /* Test 1..10: Float to/from Integer & Move Instructions             */
    /* ----------------------------------------------------------------- */
    /* Convert 42 to double, move bits to GPR */
    TEST_CASE(1, a1, 0x4045000000000000, /* 42.0 in IEEE-754 double */
        li       t1, 42;
        fcvt.d.l ft0, t1;
        fmv.x.d  a1, ft0
    )

    /* Convert -42 to double */
    TEST_CASE(2, a1, 0xC045000000000000, /* -42.0 in IEEE-754 double */
        li       t1, -42;
        fcvt.d.l ft0, t1;
        fmv.x.d  a1, ft0
    )

    /* Convert 42.0 double back to integer */
    TEST_CASE(3, a1, 42,
        li       t1, 0x4045000000000000;
        fmv.d.x  ft0, t1;
        fcvt.l.d a1, ft0
    )

    /* ----------------------------------------------------------------- */
    /* Test 11..20: Double Precision Arithmetic (FADD, FSUB, FMUL, FDIV) */
    /* ----------------------------------------------------------------- */
    /* 1.5 + 2.5 = 4.0 (0x4010000000000000) */
    TEST_CASE(11, a1, 0x4010000000000000,
        li       t1, 0x3FF8000000000000; /* 1.5 */
        li       t2, 0x4004000000000000; /* 2.5 */
        fmv.d.x  ft1, t1;
        fmv.d.x  ft2, t2;
        fadd.d   ft0, ft1, ft2;
        fmv.x.d  a1, ft0
    )

    /* 5.0 - 2.5 = 2.5 (0x4004000000000000) */
    TEST_CASE(12, a1, 0x4004000000000000,
        li       t1, 0x4014000000000000; /* 5.0 */
        li       t2, 0x4004000000000000; /* 2.5 */
        fmv.d.x  ft1, t1;
        fmv.d.x  ft2, t2;
        fsub.d   ft0, ft1, ft2;
        fmv.x.d  a1, ft0
    )

    /* 3.0 * 4.0 = 12.0 (0x4028000000000000) */
    TEST_CASE(13, a1, 0x4028000000000000,
        li       t1, 0x4008000000000000; /* 3.0 */
        li       t2, 0x4010000000000000; /* 4.0 */
        fmv.d.x  ft1, t1;
        fmv.d.x  ft2, t2;
        fmul.d   ft0, ft1, ft2;
        fmv.x.d  a1, ft0
    )

    /* 15.0 / 3.0 = 5.0 (0x4014000000000000) */
    TEST_CASE(14, a1, 0x4014000000000000,
        li       t1, 0x402E000000000000; /* 15.0 */
        li       t2, 0x4008000000000000; /* 3.0 */
        fmv.d.x  ft1, t1;
        fmv.d.x  ft2, t2;
        fdiv.d   ft0, ft1, ft2;
        fmv.x.d  a1, ft0
    )

    /* FSQRT: sqrt(16.0) = 4.0 (0x4010000000000000) */
    TEST_CASE(15, a1, 0x4010000000000000,
        li       t1, 0x4030000000000000; /* 16.0 */
        fmv.d.x  ft1, t1;
        fsqrt.d  ft0, ft1;
        fmv.x.d  a1, ft0
    )

    /* ----------------------------------------------------------------- */
    /* Test 21..30: Fused Multiply-Add (FMADD, FMSUB)                   */
    /* ----------------------------------------------------------------- */
    /* 2.0 * 3.0 + 4.0 = 10.0 (0x4024000000000000) */
    TEST_CASE(21, a1, 0x4024000000000000,
        li       t1, 0x4000000000000000; /* 2.0 */
        li       t2, 0x4008000000000000; /* 3.0 */
        li       t3, 0x4010000000000000; /* 4.0 */
        fmv.d.x  ft1, t1;
        fmv.d.x  ft2, t2;
        fmv.d.x  ft3, t3;
        fmadd.d  ft0, ft1, ft2, ft3;
        fmv.x.d  a1, ft0
    )

    /* ----------------------------------------------------------------- */
    /* Test 31..40: Sign Injection & Comparisons (FSGNJ, FEQ, FLT, FLE) */
    /* ----------------------------------------------------------------- */
    /* FSGNJ: Copy sign of negative to positive */
    TEST_CASE(31, a1, 0xC000000000000000, /* -2.0 */
        li       t1, 0x4000000000000000; /* +2.0 */
        li       t2, 0x8000000000000000; /* -0.0 */
        fmv.d.x  ft1, t1;
        fmv.d.x  ft2, t2;
        fsgnj.d  ft0, ft1, ft2;
        fmv.x.d  a1, ft0
    )

    /* FEQ: 2.0 == 2.0 -> 1 */
    TEST_CASE(32, a1, 1,
        li       t1, 0x4000000000000000;
        fmv.d.x  ft1, t1;
        feq.d    a1, ft1, ft1
    )

    /* FLT: 2.0 < 3.0 -> 1 */
    TEST_CASE(33, a1, 1,
        li       t1, 0x4000000000000000; /* 2.0 */
        li       t2, 0x4008000000000000; /* 3.0 */
        fmv.d.x  ft1, t1;
        fmv.d.x  ft2, t2;
        flt.d    a1, ft1, ft2
    )

    /* ----------------------------------------------------------------- */
    /* Test 41..45: Divide by Zero Exception Flag in FCSR                */
    /* 1.0 / 0.0 -> +Inf (0x7FF0000000000000) and fcsr.DZ (bit 3 = 8)   */
    /* ----------------------------------------------------------------- */
    TEST_CASE(41, a1, 0x7FF0000000000000,
        fscsr    x0;
        li       t1, 0x3FF0000000000000; /* 1.0 */
        li       t2, 0x0000000000000000; /* 0.0 */
        fmv.d.x  ft1, t1;
        fmv.d.x  ft2, t2;
        fdiv.d   ft0, ft1, ft2;
        fmv.x.d  a1, ft0
    )

    /* Check that DZ flag (bit 3) is set in fcsr */
    TEST_CASE(42, a1, 8,
        frflags  a1;
        andi     a1, a1, 8
    )

    TEST_PASS
    TEST_FAIL
