/* SPDX-License-Identifier: Apache-2.0 */
/* TITAN-X Clean-Room Verification: RV64M Multiplier/Divider Stress Test */

#include "../test_macros.h"

INIT_TEST

    /* ----------------------------------------------------------------- */
    /* Test 1..10: 64-bit Multiplications (MUL, MULH, MULHU, MULHSU)    */
    /* ----------------------------------------------------------------- */
    TEST_CASE(1, a1, 42,
        li   a2, 6;
        li   a3, 7;
        mul  a1, a2, a3
    )

    TEST_CASE(2, a1, -42,
        li   a2, -6;
        li   a3, 7;
        mul  a1, a2, a3
    )

    TEST_CASE(3, a1, 42,
        li   a2, -6;
        li   a3, -7;
        mul  a1, a2, a3
    )

    TEST_CASE(4, a1, 0,
        li   a2, 1000;
        li   a3, 0;
        mul  a1, a2, a3
    )

    /* MULH: High 64 bits of signed x signed */
    TEST_CASE(5, a1, 0,
        li   a2, 100;
        li   a3, 200;
        mulh a1, a2, a3
    )

    TEST_CASE(6, a1, -1,
        li   a2, -1;
        li   a3, 1;
        mulh a1, a2, a3
    )

    TEST_CASE(7, a1, 0,
        li   a2, -1;
        li   a3, -1;
        mulh a1, a2, a3
    )

    /* MULHU: High 64 bits of unsigned x unsigned */
    TEST_CASE(8, a1, 0xFFFFFFFFFFFFFFFE,
        li   a2, -1;
        li   a3, -1;
        mulhu a1, a2, a3
    )

    /* MULHSU: High 64 bits of signed x unsigned */
    TEST_CASE(9, a1, -1,
        li   a2, -1; /* signed -1 */
        li   a3, 2;  /* unsigned 2 */
        mulhsu a1, a2, a3
    )

    /* MULW: 32-bit multiply with sign extension */
    TEST_CASE(10, a1, -42,
        li   a2, -6;
        li   a3, 7;
        mulw a1, a2, a3
    )

    /* ----------------------------------------------------------------- */
    /* Test 11..20: Division Standard Cases & Corner Cases               */
    /* ----------------------------------------------------------------- */
    TEST_CASE(11, a1, 6,
        li   a2, 42;
        li   a3, 7;
        div  a1, a2, a3
    )

    TEST_CASE(12, a1, -6,
        li   a2, -42;
        li   a3, 7;
        div  a1, a2, a3
    )

    TEST_CASE(13, a1, -6,
        li   a2, 42;
        li   a3, -7;
        div  a1, a2, a3
    )

    TEST_CASE(14, a1, 6,
        li   a2, -42;
        li   a3, -7;
        div  a1, a2, a3
    )

    /* Division by zero corner case: x / 0 = -1 */
    TEST_CASE(15, a1, -1,
        li   a2, 42;
        li   a3, 0;
        div  a1, a2, a3
    )

    TEST_CASE(16, a1, -1,
        li   a2, -42;
        li   a3, 0;
        div  a1, a2, a3
    )

    TEST_CASE(17, a1, -1,
        li   a2, 0;
        li   a3, 0;
        div  a1, a2, a3
    )

    /* Signed overflow corner case: -2^63 / -1 = -2^63 */
    TEST_CASE(18, a1, 0x8000000000000000,
        li   a2, 0x8000000000000000;
        li   a3, -1;
        div  a1, a2, a3
    )

    /* DIVU standard and div-by-zero */
    TEST_CASE(19, a1, 5,
        li   a2, 100;
        li   a3, 20;
        divu a1, a2, a3
    )

    TEST_CASE(20, a1, -1,
        li   a2, 100;
        li   a3, 0;
        divu a1, a2, a3
    )

    /* ----------------------------------------------------------------- */
    /* Test 21..30: Remainder Standard Cases & Corner Cases              */
    /* ----------------------------------------------------------------- */
    TEST_CASE(21, a1, 2,
        li   a2, 44;
        li   a3, 7;
        rem  a1, a2, a3
    )

    TEST_CASE(22, a1, -2,
        li   a2, -44;
        li   a3, 7;
        rem  a1, a2, a3
    )

    TEST_CASE(23, a1, 2,
        li   a2, 44;
        li   a3, -7;
        rem  a1, a2, a3
    )

    TEST_CASE(24, a1, -2,
        li   a2, -44;
        li   a3, -7;
        rem  a1, a2, a3
    )

    /* Remainder by zero corner case: x % 0 = x */
    TEST_CASE(25, a1, 44,
        li   a2, 44;
        li   a3, 0;
        rem  a1, a2, a3
    )

    TEST_CASE(26, a1, -44,
        li   a2, -44;
        li   a3, 0;
        rem  a1, a2, a3
    )

    TEST_CASE(27, a1, 0,
        li   a2, 0;
        li   a3, 0;
        rem  a1, a2, a3
    )

    /* Signed overflow remainder: -2^63 % -1 = 0 */
    TEST_CASE(28, a1, 0,
        li   a2, 0x8000000000000000;
        li   a3, -1;
        rem  a1, a2, a3
    )

    /* REMU standard and rem-by-zero */
    TEST_CASE(29, a1, 4,
        li   a2, 104;
        li   a3, 20;
        remu a1, a2, a3
    )

    TEST_CASE(30, a1, 104,
        li   a2, 104;
        li   a3, 0;
        remu a1, a2, a3
    )

    /* ----------------------------------------------------------------- */
    /* Test 31..40: 32-bit Word Div/Rem Operations (DIVW, DIVUW, REMW, REMUW)*/
    /* ----------------------------------------------------------------- */
    TEST_CASE(31, a1, 6,
        li    a2, 42;
        li    a3, 7;
        divw  a1, a2, a3
    )

    TEST_CASE(32, a1, -6,
        li    a2, -42;
        li    a3, 7;
        divw  a1, a2, a3
    )

    /* 32-bit div by zero: returns -1 sign-extended (0xFFFFFFFFFFFFFFFF) */
    TEST_CASE(33, a1, -1,
        li    a2, 42;
        li    a3, 0;
        divw  a1, a2, a3
    )

    TEST_CASE(34, a1, -1,
        li    a2, 42;
        li    a3, 0;
        divuw a1, a2, a3
    )

    /* 32-bit signed overflow: -2^31 / -1 = -2^31 sign-extended */
    TEST_CASE(35, a1, 0xFFFFFFFF80000000,
        li    a2, -0x80000000;
        li    a3, -1;
        divw  a1, a2, a3
    )

    TEST_CASE(36, a1, 0,
        li    a2, -0x80000000;
        li    a3, -1;
        remw  a1, a2, a3
    )

    TEST_CASE(37, a1, 2,
        li    a2, 44;
        li    a3, 7;
        remw  a1, a2, a3
    )

    TEST_CASE(38, a1, 44,
        li    a2, 44;
        li    a3, 0;
        remw  a1, a2, a3
    )

    TEST_CASE(39, a1, 4,
        li    a2, 104;
        li    a3, 20;
        remuw a1, a2, a3
    )

    TEST_CASE(40, a1, 104,
        li    a2, 104;
        li    a3, 0;
        remuw a1, a2, a3
    )

    TEST_PASS
    TEST_FAIL
