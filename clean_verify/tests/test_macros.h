/* SPDX-License-Identifier: Apache-2.0 */
#ifndef TEST_MACROS_H
#define TEST_MACROS_H

#define UART0_BASE 0x40000000

/* Macro to output a character to UART0 */
#define PUTCHAR(c) \
    li   t5, UART0_BASE; \
    li   t6, c; \
    sb   t6, 0(t5);

/* Standard Test Prologue:
   - Check mhartid: if != 0, park in WFI loop.
   - Hart 0 sets up stack and starts tests.
*/
#define INIT_TEST \
    .section .text.init; \
    .globl _start; \
_start: \
    csrr a0, mhartid; \
    bnez a0, .Lpark_secondary; \
    la   sp, __stack_top; \
    j    .Ltest_entry; \
.Lpark_secondary: \
    wfi; \
    j    .Lpark_secondary; \
.Ltest_entry:

/* Test comparison macro: executes instruction, checks result against expected */
#define TEST_CASE(testnum, testreg, correctval, code...) \
    .globl test_ ## testnum; \
test_ ## testnum: \
    code; \
    li   t0, correctval; \
    beq  testreg, t0, 1f; \
    li   a0, testnum; \
    j    test_fail; \
1:

/* 64-bit Test comparison macro with 64-bit constant */
#define TEST_CASE64(testnum, testreg, correctval, code...) \
    .globl test_ ## testnum; \
test_ ## testnum: \
    code; \
    li   t0, correctval; \
    beq  testreg, t0, 1f; \
    li   a0, testnum; \
    j    test_fail; \
1:

/* Floating point test case */
#define TEST_FP_CASE(testnum, ftestreg, fcorrectval, code...) \
    .globl test_ ## testnum; \
test_ ## testnum: \
    code; \
    fmv.x.d t0, ftestreg; \
    li      t1, fcorrectval; \
    beq     t0, t1, 1f; \
    li      a0, testnum; \
    j       test_fail; \
1:

/* Pass routine */
#define TEST_PASS \
test_pass: \
    PUTCHAR('P'); \
    PUTCHAR('A'); \
    PUTCHAR('S'); \
    PUTCHAR('S'); \
    PUTCHAR('\n'); \
    li   gp, 1; \
.Lpass_loop: \
    j    .Lpass_loop;

/* Fail routine: writes (fail_num << 1) | 1 to gp (x3) and outputs 'FAIL' to UART */
#define TEST_FAIL \
test_fail: \
    PUTCHAR('F'); \
    PUTCHAR('A'); \
    PUTCHAR('I'); \
    PUTCHAR('L'); \
    PUTCHAR(':'); \
    PUTCHAR(' '); \
    slli gp, a0, 1; \
    ori  gp, gp, 1; \
.Lfail_loop: \
    j    .Lfail_loop;

#endif
