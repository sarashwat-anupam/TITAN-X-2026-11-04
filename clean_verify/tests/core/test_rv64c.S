/* SPDX-License-Identifier: Apache-2.0 */
/* TITAN-X Clean-Room Verification: RV64C Compressed Instructions & Unaligned Test */

#include "../test_macros.h"

INIT_TEST

    /* ----------------------------------------------------------------- */
    /* Test 1..10: Basic Compressed ALU & Constants                     */
    /* ----------------------------------------------------------------- */
    TEST_CASE(1, a1, 15,
        c.li a1, 15
    )

    TEST_CASE(2, a1, -1,
        c.li a1, -1
    )

    TEST_CASE(3, a1, 0x12000,
        c.lui a1, 0x12
    )

    TEST_CASE(4, a1, 25,
        c.li   a1, 15;
        c.addi a1, 10
    )

    TEST_CASE(5, a1, -1,
        c.li    a1, -2;
        c.addiw a1, 1
    )

    TEST_CASE(6, a1, 35,
        c.li  a2, 15;
        c.li  a3, 20;
        c.add a2, a3;
        c.mv  a1, a2
    )

    TEST_CASE(7, a1, 5,
        c.li  a2, 20;
        c.li  a3, 15;
        c.sub a2, a3;
        c.mv  a1, a2
    )

    TEST_CASE(8, a1, 0x0F,
        c.li  a2, 0x1F;
        c.andi a2, 0x0F;
        c.mv  a1, a2
    )

    TEST_CASE(9, a1, 0x1F,
        c.li  a2, 0x10;
        c.li  a3, 0x0F;
        c.or  a2, a3;
        c.mv  a1, a2
    )

    TEST_CASE(10, a1, 0x10,
        c.li  a2, 0x1F;
        c.li  a3, 0x0F;
        c.xor a2, a3;
        c.mv  a1, a2
    )

    /* ----------------------------------------------------------------- */
    /* Test 11..20: Compressed Shifts, Loads & Stores                   */
    /* ----------------------------------------------------------------- */
    TEST_CASE(11, a1, 64,
        c.li   a1, 1;
        c.slli a1, 6
    )

    TEST_CASE(12, a1, 1,
        c.li   a2, 16;
        c.srli a2, 4;
        c.mv   a1, a2
    )

    TEST_CASE(13, a1, -1,
        c.li   a2, -4;
        c.srai a2, 2;
        c.mv   a1, a2
    )

    TEST_CASE(14, a1, 0x12345678,
        addi s0, sp, 64;
        li   a2, 0x12345678;
        c.sw a2, 0(s0);
        c.lw a1, 0(s0)
    )

    TEST_CASE(15, a1, 0x1122334455667788,
        addi s0, sp, 64;
        li   a2, 0x1122334455667788;
        c.sd a2, 0(s0);
        c.ld a1, 0(s0)
    )

    /* ----------------------------------------------------------------- */
    /* Test 21..30: Compressed Branches & Jumps                         */
    /* ----------------------------------------------------------------- */
    TEST_CASE(21, a1, 20,
        c.li   a2, 0;
        c.beqz a2, 1f;
        c.li   a1, 10;
        c.j    2f;
    1:  c.li   a1, 20;
    2:
    )

    TEST_CASE(22, a1, 25,
        c.li   a2, 1;
        c.bnez a2, 1f;
        c.li   a1, 10;
        c.j    2f;
    1:  c.li   a1, 25;
    2:
    )

    TEST_CASE(23, a1, 30,
        la     t1, 1f;
        c.jr   t1;
        c.li   a1, 10;
        c.j    2f;
    1:  c.li   a1, 30;
    2:
    )

    /* ----------------------------------------------------------------- */
    /* Test 31..35: Unaligned Instruction Crossing 32-bit Boundary       */
    /* Force 2-byte instruction followed by 4-byte instruction.         */
    /* ----------------------------------------------------------------- */
    TEST_CASE(31, a1, 0x55AA55AA,
        .option push;
        .option norvc;
        .align 2;          /* Align to 4-byte boundary */
        .option pop;
        c.nop;             /* 2-byte instruction: now PC is at 4k + 2 */
        /* Next 32-bit instruction starts at 0x...02 and spans to 0x...06 */
        li     a1, 0x55AA55AA
    )

    TEST_CASE(32, a1, 0x1234567890ABCDEF,
        .option push;
        .option norvc;
        .align 2;
        .option pop;
        c.nop;             /* PC at 4k + 2 */
        li     a1, 0x1234567890ABCDEF
    )

    TEST_PASS
    TEST_FAIL
