/* SPDX-License-Identifier: Apache-2.0 */
/* TITAN-X Clean-Room Verification: RV64A Atomic Operations Test */

#include "../test_macros.h"

INIT_TEST

    /* Setup buffer on stack */
    addi s0, sp, 64

    /* ----------------------------------------------------------------- */
    /* Test 1..10: LR.W and SC.W (32-bit Atomic Reservation)             */
    /* ----------------------------------------------------------------- */
    TEST_CASE(1, a1, 0x11223344,
        li    t1, 0x11223344;
        sw    t1, 0(s0);
        lr.w  a1, (s0)
    )

    /* Successful SC.W returns 0 */
    TEST_CASE(2, a1, 0,
        lr.w  t1, (s0);
        li    t2, 0x55667788;
        sc.w  a1, t2, (s0)
    )

    /* Memory verified updated by SC.W */
    TEST_CASE(3, a1, 0x55667788,
        lw    a1, 0(s0)
    )

    /* ----------------------------------------------------------------- */
    /* Test 11..20: LR.D and SC.D (64-bit Atomic Reservation)            */
    /* ----------------------------------------------------------------- */
    TEST_CASE(11, a1, 0x0123456789ABCDEF,
        li    t1, 0x0123456789ABCDEF;
        sd    t1, 0(s0);
        lr.d  a1, (s0)
    )

    /* Successful SC.D returns 0 */
    TEST_CASE(12, a1, 0,
        lr.d  t1, (s0);
        li    t2, 0xFEDCBA9876543210;
        sc.d  a1, t2, (s0)
    )

    /* Memory verified updated by SC.D */
    TEST_CASE(13, a1, 0xFEDCBA9876543210,
        ld    a1, 0(s0)
    )

    /* ----------------------------------------------------------------- */
    /* Test 21..35: AMO.W Operations (32-bit)                            */
    /* ----------------------------------------------------------------- */
    /* AMOSWAP.W: returns old, writes new */
    TEST_CASE(21, a1, 0x12345678,
        li    t1, 0x12345678;
        sw    t1, 0(s0);
        li    t2, 0x76543210;
        amoswap.w a1, t2, (s0)
    )
    TEST_CASE(22, a1, 0x76543210,
        lw    a1, 0(s0)
    )

    /* AMOADD.W */
    TEST_CASE(23, a1, 100,
        li    t1, 100;
        sw    t1, 0(s0);
        li    t2, 50;
        amoadd.w a1, t2, (s0)
    )
    TEST_CASE(24, a1, 150,
        lw    a1, 0(s0)
    )

    /* AMOAND.W */
    TEST_CASE(25, a1, 0x0F0F,
        li    t1, 0x0F0F;
        sw    t1, 0(s0);
        li    t2, 0x00FF;
        amoand.w a1, t2, (s0)
    )
    TEST_CASE(26, a1, 0x000F,
        lw    a1, 0(s0)
    )

    /* AMOOR.W */
    TEST_CASE(27, a1, 0xF0F0,
        li    t1, 0xF0F0;
        sw    t1, 0(s0);
        li    t2, 0x0F0F;
        amoor.w a1, t2, (s0)
    )
    TEST_CASE(28, a1, 0xFFFF,
        lw    a1, 0(s0)
    )

    /* AMOXOR.W */
    TEST_CASE(29, a1, 0xAAAA,
        li    t1, 0xAAAA;
        sw    t1, 0(s0);
        li    t2, 0xFFFF;
        amoxor.w a1, t2, (s0)
    )
    TEST_CASE(30, a1, 0x5555,
        lw    a1, 0(s0)
    )

    /* AMOMIN.W (signed) */
    TEST_CASE(31, a1, 10,
        li    t1, 10;
        sw    t1, 0(s0);
        li    t2, -20;
        amomin.w a1, t2, (s0)
    )
    TEST_CASE(32, a1, -20,
        lw    a1, 0(s0)
    )

    /* AMOMAX.W (signed) */
    TEST_CASE(33, a1, -20,
        li    t2, 50;
        amomax.w a1, t2, (s0)
    )
    TEST_CASE(34, a1, 50,
        lw    a1, 0(s0)
    )

    /* ----------------------------------------------------------------- */
    /* Test 36..45: AMO.D Operations (64-bit)                            */
    /* ----------------------------------------------------------------- */
    /* AMOADD.D */
    TEST_CASE(36, a1, 0x100000000,
        li    t1, 0x100000000;
        sd    t1, 0(s0);
        li    t2, 0x200000000;
        amoadd.d a1, t2, (s0)
    )
    TEST_CASE(37, a1, 0x300000000,
        ld    a1, 0(s0)
    )

    /* AMOMINU.D (unsigned) */
    TEST_CASE(38, a1, -1,
        li    t1, -1;
        sd    t1, 0(s0);
        li    t2, 100;
        amominu.d a1, t2, (s0)
    )
    TEST_CASE(39, a1, 100,
        ld    a1, 0(s0)
    )

    /* AMOMAXU.D (unsigned) */
    TEST_CASE(40, a1, 100,
        li    t2, -1;
        amomaxu.d a1, t2, (s0)
    )
    TEST_CASE(41, a1, -1,
        ld    a1, 0(s0)
    )

    TEST_PASS
    TEST_FAIL
