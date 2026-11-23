/* SPDX-License-Identifier: Apache-2.0 */
/* TITAN-X Clean-Room Verification: Hart 4 Monitor Core Isolation Test */

#include "../test_macros.h"

.section .text.init
.option norvc
.globl _start
_start:
    /* Check mhartid: Harts 0..3 park; Hart 4 executes this test suite */
    csrr a0, mhartid
    li   t0, 4
    bne  a0, t0, .Lpark_app_cores

    /* Hart 4 stack setup in SRAM */
    li   sp, 0x00008000
    j    .Lmonitor_entry

.Lpark_app_cores:
    wfi
    j    .Lpark_app_cores

.Lmonitor_entry:
    /* Test 1: Verify Hart 4 mhartid == 4 */
    TEST_CASE(1, a1, 4,
        csrr a1, mhartid
    )

    /* Test 2: Arithmetic & Logic on Hart 4 (RV64I) */
    TEST_CASE(2, a1, 100,
        li   t1, 60;
        li   t2, 40;
        add  a1, t1, t2
    )

    /* Test 3: Multiplier on Hart 4 (RV64M) */
    TEST_CASE(3, a1, 420,
        li   t1, 42;
        li   t2, 10;
        mul  a1, t1, t2
    )

    /* Test 4: Divider on Hart 4 (RV64M) */
    TEST_CASE(4, a1, 42,
        li   t1, 420;
        li   t2, 10;
        div  a1, t1, t2
    )

    /* Test 5: SRAM Direct Read/Write Access from Hart 4 */
    TEST_CASE(5, a1, 0xA5A5A5A5A5A5A5A5,
        li   t1, 0x00001000;
        li   t2, 0xA5A5A5A5A5A5A5A5;
        sd   t2, 0(t1);
        ld   a1, 0(t1)
    )

    TEST_PASS
    TEST_FAIL
