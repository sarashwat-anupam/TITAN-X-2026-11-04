/* SPDX-License-Identifier: Apache-2.0 */
/* SMVDU TITAN-X Multi-Core Constrained-Random Instruction Regression Suite */
/* Target: 4 Cores x 1000 insns x 25 iters = 100000 dynamic instructions */

#include "../test_macros.h"

.section .text.init
.globl _start

_start:
    csrr a0, mhartid
    li   t0, 4
    beq  a0, t0, .Lpark_hart4

    /* Stack setup: private 4KB stack per core */
    la   sp, __stack_top
    slli t0, a0, 12
    sub  sp, sp, t0

    /* Core entry dispatch */
    beqz a0, .Lentry_hart0
    li   t0, 1; beq a0, t0, .Lentry_hart1
    li   t0, 2; beq a0, t0, .Lentry_hart2
    li   t0, 3; beq a0, t0, .Lentry_hart3

.Lpark_hart4:
    wfi
    j    .Lpark_hart4

/* ========================================================================= */
/* HART 0 EXECUTION STREAM                                                */
/* ========================================================================= */
.Lentry_hart0:
    /* Set up private scratchpad memory base pointer in x2 */
    la   x2, scratch_h0
    addi x2, x2, 2047
    addi x2, x2, 1

    /* Preload diverse corner values into registers x4..x31 */
    li   x4, 0x0
    li   x5, 0xffffffffffffffff
    li   x6, 0x7fffffffffffffff
    li   x7, 0x8000000000000000
    li   x8, 0x7fffffff
    li   x9, 0xffffffff80000000
    li   x10, 0xffffffff
    li   x11, 0x5555555555555555
    li   x12, 0xaaaaaaaaaaaaaaaa
    li   x13, 0x1
    li   x14, 0x2
    li   x15, 0xfffffffffffffffe
    li   x16, 0x3f
    li   x17, 0x1f
    li   x18, 0x123456789abcdef0
    li   x19, 0xdeadbeefcafebabe
    li   x20, 0x0
    li   x21, 0xffffffffffffffff
    li   x22, 0x7fffffffffffffff
    li   x23, 0x8000000000000000
    li   x24, 0x7fffffff
    li   x25, 0xffffffff80000000
    li   x26, 0xffffffff
    li   x27, 0x5555555555555555
    li   x28, 0xaaaaaaaaaaaaaaaa
    li   x29, 0x1
    li   x30, 0x2
    li   x31, 0xfffffffffffffffe

    /* Preload private scratchpad with initial deterministic data */
    li   x1, 0x123456789abcdef
    sd   x1, -512(x2)
    addi x1, x1, 0x111
    sd   x1, -384(x2)
    addi x1, x1, 0x111
    sd   x1, -256(x2)
    addi x1, x1, 0x111
    sd   x1, -128(x2)
    addi x1, x1, 0x111
    sd   x1, 0(x2)
    addi x1, x1, 0x111
    sd   x1, 128(x2)
    addi x1, x1, 0x111
    sd   x1, 256(x2)
    addi x1, x1, 0x111
    sd   x1, 384(x2)
    addi x1, x1, 0x111

    /* Initialize loop counter in x1 */
    li   x1, 25
.Lloop_hart0:
    /* --- BEGIN RANDOM INSTRUCTION BLOCK FOR HART 0 --- */
    divu x28, x5, x29
    sltu x8, x31, x28
    sll x13, x5, x29
    srlw x16, x6, x4
    rem x9, x16, x16
    sra x25, x24, x23
    sraiw x19, x28, 6
    mulhsu x4, x24, x16
    slliw x18, x24, 26
    sltiu x12, x5, 276
    remuw x14, x25, x23
    divw x19, x5, x5
    mul x13, x27, x10
    bge x11, x13, fwd_br_h0_0
    addi x14, x14, 1
fwd_br_h0_0:
    beq x10, x7, fwd_br_h0_1
    addi x29, x29, 1
fwd_br_h0_1:
    add x15, x11, x16
    sltiu x8, x8, 1154
    mulhsu x8, x8, x6
    mulhu x28, x31, x8
    slli x17, x28, 51
    addiw x8, x21, 399
    bne x18, x19, fwd_br_h0_2
    addi x26, x26, 1
fwd_br_h0_2:
    sraw x15, x12, x11
    slli x16, x29, 26
    srlw x12, x10, x15
    sh x7, -376(x2)
    sb x7, 301(x2)
    sraiw x28, x12, 4
    lh x17, -488(x2)
    add x5, x17, x18
    ori x9, x5, 216
    sd x9, 464(x2)
    slt x4, x15, x18
    lh x24, 306(x2)
    lhu x30, -474(x2)
    slti x29, x16, 124
    lwu x12, -112(x2)
    ori x14, x29, 80
    or x31, x14, x15
    ld x27, 400(x2)
    sraiw x24, x26, 14
    sub x30, x24, x4
    c.xor x13, x14
    ld x15, -384(x2)
    add x9, x13, x5
    divu x17, x9, x10
    slti x11, x17, 391
    mulhsu x19, x28, x30
    sh x29, -388(x2)
    sllw x25, x30, x12
    sd x25, 160(x2)
    sb x22, -43(x2)
    sb x13, -280(x2)
    ori x28, x23, -1585
    addw x12, x28, x13
    lhu x20, -68(x2)
    or x19, x20, x25
    bge x13, x19, fwd_br_h0_3
    addi x28, x28, 1
fwd_br_h0_3:
    slli x22, x14, 9
    c.mv x28, x7
    sh x22, 212(x2)
    or x22, x27, x16
    sraiw x10, x16, 21
    div x13, x11, x5
    andi x18, x21, 897
    slli x27, x6, 51
    and x10, x18, x12
    sd x27, -448(x2)
    srliw x20, x7, 27
    sh x20, 472(x2)
    c.xor x9, x14
    c.sub x12, x9
    c.sub x10, x9
    sra x5, x13, x19
    srliw x12, x5, 26
    rem x29, x12, x4
    mulw x23, x16, x27
    addiw x30, x26, -1465
    addi x12, x25, 1537
    bgeu x5, x12, fwd_br_h0_4
    addi x20, x20, 1
fwd_br_h0_4:
    mulhsu x26, x12, x23
    mulhu x11, x26, x16
    sb x11, -261(x2)
    sw x21, 120(x2)
    divu x22, x22, x20
    remu x14, x5, x24
    bltu x31, x14, fwd_br_h0_5
    addi x7, x7, 1
fwd_br_h0_5:
    slti x16, x7, -329
    remuw x29, x7, x15
    addw x5, x29, x17
    sb x5, 409(x2)
    lb x11, -456(x2)
    xori x9, x4, 1698
    bge x9, x26, fwd_br_h0_6
    addi x21, x21, 1
fwd_br_h0_6:
    divu x21, x8, x22
    c.addw x14, x9
    bne x15, x10, fwd_br_h0_7
    addi x17, x17, 1
fwd_br_h0_7:
    srl x20, x26, x17
    remuw x25, x20, x11
    lw x7, -204(x2)
    c.add x14, x11
    bge x7, x21, fwd_br_h0_8
    addi x21, x21, 1
fwd_br_h0_8:
    andi x14, x31, 1121
    srli x4, x14, 61
    slliw x27, x14, 28
    mulhu x19, x7, x13
    rem x7, x27, x19
    srli x21, x6, 40
    remw x8, x6, x31
    lh x28, 360(x2)
    mul x21, x8, x17
    remu x18, x18, x12
    or x21, x21, x18
    bne x21, x31, fwd_br_h0_9
    addi x8, x8, 1
fwd_br_h0_9:
    div x25, x22, x14
    srli x29, x7, 32
    sllw x5, x26, x22
    sltu x30, x7, x31
    slti x18, x5, -1809
    sraiw x15, x18, 22
    mulw x6, x18, x9
    addiw x14, x23, 1953
    divu x30, x12, x14
    sh x30, 230(x2)
    add x28, x30, x9
    sd x28, -400(x2)
    mul x7, x28, x8
    remw x8, x10, x11
    andi x4, x8, 858
    slt x12, x4, x30
    srli x15, x12, 42
    sub x30, x23, x15
    bge x30, x15, fwd_br_h0_10
    addi x8, x8, 1
fwd_br_h0_10:
    addi x9, x30, 1541
    slti x15, x9, -763
    lwu x19, -128(x2)
    lb x23, -259(x2)
    c.sub x10, x12
    rem x24, x17, x12
    ld x13, -48(x2)
    xor x29, x27, x13
    slti x30, x13, 1416
    lhu x16, -212(x2)
    srlw x25, x31, x16
    c.sub x12, x13
    slli x23, x30, 28
    remu x5, x22, x23
    slt x14, x5, x14
    bge x21, x14, fwd_br_h0_11
    addi x17, x17, 1
fwd_br_h0_11:
    and x6, x15, x11
    srlw x8, x6, x29
    srlw x14, x8, x12
    bne x14, x21, fwd_br_h0_12
    addi x26, x26, 1
fwd_br_h0_12:
    srli x16, x14, 61
    ld x8, -56(x2)
    divuw x18, x16, x11
    slliw x6, x18, 25
    sltu x7, x6, x28
    slli x9, x7, 29
    mulw x29, x9, x25
    lhu x31, 376(x2)
    divw x26, x31, x23
    addi x26, x31, 195
    lh x23, 44(x2)
    sb x26, 324(x2)
    blt x8, x10, fwd_br_h0_13
    addi x25, x25, 1
fwd_br_h0_13:
    c.addw x12, x13
    slliw x4, x11, 22
    beq x28, x4, fwd_br_h0_14
    addi x13, x13, 1
fwd_br_h0_14:
    add x16, x25, x4
    sll x28, x16, x5
    srli x19, x30, 26
    sll x27, x13, x11
    mulhu x15, x22, x27
    and x30, x16, x15
    slli x19, x15, 10
    lbu x14, 358(x2)
    sll x25, x5, x14
    subw x14, x14, x8
    c.or x8, x15
    sw x8, -320(x2)
    mulhsu x13, x24, x15
    srai x17, x13, 36
    slliw x27, x18, 6
    c.addi x12, 2
    slli x22, x12, 63
    addi x11, x24, 453
    sltu x20, x9, x17
    sltiu x16, x26, -494
    mulhu x6, x11, x16
    sllw x23, x6, x25
    mulh x31, x18, x23
    subw x5, x31, x11
    bgeu x26, x5, fwd_br_h0_15
    addi x28, x28, 1
fwd_br_h0_15:
    sraiw x4, x5, 21
    divuw x18, x4, x11
    xor x27, x4, x20
    lhu x10, 432(x2)
    div x20, x30, x10
    lbu x11, 81(x2)
    sw x11, 416(x2)
    subw x31, x18, x25
    srliw x31, x31, 0
    srlw x6, x31, x10
    sb x6, -228(x2)
    sltu x28, x14, x20
    lwu x5, -412(x2)
    sltiu x18, x28, 470
    andi x17, x28, -1839
    remw x17, x13, x29
    c.mv x17, x17
    srl x30, x17, x31
    lhu x13, 162(x2)
    sraw x7, x24, x29
    lhu x30, -210(x2)
    xor x13, x7, x4
    sll x4, x13, x31
    sd x4, -224(x2)
    sraiw x31, x15, 26
    bge x31, x8, fwd_br_h0_16
    addi x22, x22, 1
fwd_br_h0_16:
    c.or x13, x8
    sraiw x10, x4, 5
    beq x13, x24, fwd_br_h0_17
    addi x19, x19, 1
fwd_br_h0_17:
    add x22, x10, x22
    srl x13, x9, x7
    sd x6, 440(x2)
    blt x13, x26, fwd_br_h0_18
    addi x13, x13, 1
fwd_br_h0_18:
    srl x26, x13, x23
    add x23, x22, x26
    sll x9, x26, x16
    slliw x28, x9, 26
    lh x5, -144(x2)
    and x14, x28, x14
    lwu x9, -480(x2)
    mul x7, x14, x5
    divu x6, x7, x13
    lwu x8, -244(x2)
    srli x23, x28, 62
    ori x21, x23, -1828
    c.and x14, x11
    mulhu x26, x14, x12
    sltiu x27, x28, 1140
    divuw x30, x18, x27
    sraw x8, x30, x29
    bne x30, x30, fwd_br_h0_19
    addi x10, x10, 1
fwd_br_h0_19:
    slti x13, x10, -145
    sd x14, 312(x2)
    lhu x27, 368(x2)
    sllw x25, x30, x19
    srai x18, x27, 60
    sllw x10, x13, x16
    sh x18, -390(x2)
    mulhsu x30, x18, x21
    srlw x23, x16, x13
    blt x23, x25, fwd_br_h0_20
    addi x9, x9, 1
fwd_br_h0_20:
    mulhu x27, x4, x12
    remuw x13, x19, x15
    addw x30, x19, x5
    sra x23, x4, x30
    sra x25, x23, x21
    sll x31, x24, x25
    sltu x23, x31, x15
    sb x25, -176(x2)
    sltiu x22, x28, -937
    addiw x10, x24, 1248
    mul x16, x10, x6
    rem x15, x16, x24
    sll x8, x10, x15
    subw x14, x17, x8
    andi x19, x14, -247
    sw x19, -208(x2)
    bge x8, x20, fwd_br_h0_21
    addi x28, x28, 1
fwd_br_h0_21:
    addw x10, x20, x28
    sw x10, 148(x2)
    divuw x30, x9, x28
    remw x29, x12, x28
    slli x25, x19, 46
    sraw x16, x25, x12
    mulhsu x17, x14, x5
    c.xor x15, x9
    rem x17, x5, x21
    sltiu x12, x30, -616
    sll x22, x16, x12
    srlw x19, x11, x21
    slt x30, x19, x14
    lbu x28, -489(x2)
    slti x13, x28, 403
    sh x13, 406(x2)
    blt x22, x12, fwd_br_h0_22
    addi x17, x17, 1
fwd_br_h0_22:
    srli x5, x10, 25
    bltu x18, x10, fwd_br_h0_23
    addi x15, x15, 1
fwd_br_h0_23:
    remu x28, x21, x29
    c.or x13, x12
    srai x25, x16, 58
    slli x16, x25, 0
    mulh x22, x25, x8
    c.mv x5, x31
    slliw x9, x26, 31
    subw x29, x5, x31
    sraiw x27, x9, 3
    divuw x21, x27, x31
    mulhsu x24, x23, x21
    remuw x28, x21, x20
    slt x19, x8, x28
    div x31, x28, x27
    lhu x26, -474(x2)
    beq x15, x10, fwd_br_h0_24
    addi x28, x28, 1
fwd_br_h0_24:
    sllw x6, x12, x14
    mulw x27, x8, x19
    srliw x31, x27, 4
    addw x28, x31, x14
    addw x27, x31, x4
    c.add x8, x14
    divuw x8, x17, x8
    sll x16, x28, x31
    remw x11, x16, x13
    c.addi x12, -1
    srli x11, x13, 50
    sraiw x29, x19, 2
    sllw x16, x29, x20
    srli x19, x16, 45
    divw x20, x20, x19
    sub x12, x16, x20
    slt x23, x4, x29
    divw x25, x17, x23
    lh x31, -160(x2)
    remw x5, x31, x21
    sub x25, x31, x23
    sraw x17, x25, x8
    sllw x14, x17, x20
    sub x21, x14, x16
    sh x14, 272(x2)
    addiw x13, x9, 1317
    srliw x21, x13, 15
    or x28, x27, x21
    ori x12, x28, 1679
    c.and x13, x11
    sraiw x16, x18, 16
    mulhu x4, x16, x6
    sb x30, 391(x2)
    slti x23, x4, -590
    lw x9, -136(x2)
    remuw x19, x23, x30
    andi x18, x24, 790
    addi x11, x15, -929
    remw x29, x18, x23
    divuw x31, x11, x10
    srliw x13, x29, 8
    remw x22, x8, x6
    srai x8, x22, 43
    c.mv x8, x27
    c.addi x10, -25
    c.sub x15, x15
    add x6, x16, x12
    addi x12, x31, 1319
    c.or x15, x14
    divuw x29, x21, x25
    div x4, x29, x18
    beq x13, x4, fwd_br_h0_25
    addi x6, x6, 1
fwd_br_h0_25:
    addi x23, x26, -1871
    divuw x25, x23, x23
    c.xor x10, x14
    divu x18, x10, x27
    or x15, x18, x9
    andi x19, x15, -716
    srai x19, x19, 33
    lhu x6, -172(x2)
    divw x9, x6, x12
    sub x19, x9, x4
    div x16, x17, x24
    xor x28, x19, x26
    divw x23, x28, x16
    slliw x5, x23, 29
    andi x20, x23, 584
    addw x28, x20, x21
    slti x30, x4, -1475
    lhu x14, -484(x2)
    srlw x29, x7, x21
    mulhsu x27, x14, x22
    divw x12, x15, x5
    subw x18, x23, x12
    sub x7, x10, x7
    lh x29, 178(x2)
    mulw x5, x29, x20
    mulw x28, x12, x5
    add x6, x30, x28
    xori x12, x28, -1309
    srliw x12, x17, 15
    slt x14, x27, x22
    c.addw x9, x12
    srai x31, x23, 34
    slti x10, x9, 756
    bge x16, x29, fwd_br_h0_26
    addi x15, x15, 1
fwd_br_h0_26:
    divuw x4, x30, x21
    divuw x31, x18, x4
    sraw x25, x31, x4
    addw x20, x13, x15
    slliw x13, x13, 18
    mulh x17, x20, x26
    ori x31, x17, 1176
    sd x8, 320(x2)
    xor x9, x31, x4
    c.xor x12, x10
    slti x24, x12, -1257
    beq x12, x8, fwd_br_h0_27
    addi x21, x21, 1
fwd_br_h0_27:
    sll x19, x7, x31
    sh x20, -398(x2)
    xori x5, x12, 1403
    sltiu x5, x5, 368
    sll x19, x5, x16
    rem x20, x20, x25
    addiw x23, x19, 1096
    sll x21, x23, x15
    mulhu x4, x21, x12
    sll x4, x24, x17
    lb x19, 243(x2)
    divu x8, x19, x10
    sra x15, x13, x31
    srli x10, x9, 2
    sb x10, -343(x2)
    srli x24, x13, 58
    bltu x17, x4, fwd_br_h0_28
    addi x11, x11, 1
fwd_br_h0_28:
    slt x7, x24, x8
    beq x19, x7, fwd_br_h0_29
    addi x21, x21, 1
fwd_br_h0_29:
    srl x12, x20, x8
    ori x9, x14, 312
    remu x29, x9, x24
    sraiw x16, x14, 21
    c.sub x10, x13
    sraiw x20, x10, 11
    slli x27, x22, 55
    mulw x23, x20, x10
    srliw x16, x27, 18
    sltu x23, x23, x9
    c.sub x11, x13
    blt x11, x24, fwd_br_h0_30
    addi x15, x15, 1
fwd_br_h0_30:
    mul x27, x11, x15
    sh x26, -140(x2)
    bge x27, x6, fwd_br_h0_31
    addi x24, x24, 1
fwd_br_h0_31:
    and x19, x10, x27
    c.xor x13, x8
    divuw x17, x19, x29
    mulw x14, x10, x17
    srl x19, x17, x31
    and x6, x27, x20
    addw x30, x29, x18
    mulhu x27, x31, x31
    divu x25, x13, x29
    srli x27, x7, 5
    sd x27, -64(x2)
    or x15, x8, x28
    remw x27, x15, x13
    divuw x24, x22, x27
    beq x24, x14, fwd_br_h0_32
    addi x24, x24, 1
fwd_br_h0_32:
    divu x30, x24, x11
    lhu x10, 382(x2)
    addw x10, x28, x10
    srl x11, x10, x6
    blt x15, x14, fwd_br_h0_33
    addi x13, x13, 1
fwd_br_h0_33:
    sra x8, x18, x20
    add x19, x16, x11
    addw x30, x16, x25
    remu x7, x30, x15
    ori x21, x23, -211
    add x22, x10, x21
    mulhsu x6, x15, x19
    mulhsu x29, x24, x6
    lw x23, 208(x2)
    sra x22, x7, x8
    sraiw x25, x22, 13
    sh x25, 336(x2)
    sh x12, 266(x2)
    sraw x7, x12, x5
    lb x31, 510(x2)
    slti x24, x31, 1445
    xor x31, x21, x16
    ori x19, x31, 1937
    sd x19, -304(x2)
    c.xor x15, x8
    srliw x15, x13, 3
    lh x14, -42(x2)
    sw x14, -268(x2)
    remu x27, x18, x5
    lbu x31, -366(x2)
    srl x21, x10, x4
    sub x16, x21, x26
    subw x21, x31, x9
    lbu x28, 132(x2)
    remuw x24, x24, x30
    sub x22, x24, x20
    addi x30, x22, -575
    rem x19, x7, x21
    c.xor x8, x10
    slti x5, x12, 936
    mulh x16, x5, x5
    mulhu x6, x9, x21
    subw x21, x16, x25
    bgeu x23, x21, fwd_br_h0_34
    addi x7, x7, 1
fwd_br_h0_34:
    slliw x14, x22, 16
    sh x5, 370(x2)
    addi x30, x21, -1133
    slliw x27, x17, 2
    sub x21, x27, x4
    srlw x29, x24, x21
    slliw x12, x21, 30
    sltu x24, x17, x29
    bltu x12, x4, fwd_br_h0_35
    addi x31, x31, 1
fwd_br_h0_35:
    ld x10, 440(x2)
    lbu x17, 237(x2)
    sd x10, -512(x2)
    slliw x14, x22, 22
    sub x24, x30, x21
    div x17, x11, x26
    sub x24, x17, x12
    sub x17, x24, x31
    remw x30, x24, x18
    slli x21, x30, 48
    xori x10, x8, 1823
    c.xor x11, x11
    slti x31, x10, 518
    remw x8, x22, x8
    slti x15, x31, 508
    sltu x31, x23, x15
    slt x28, x19, x16
    sd x18, -456(x2)
    c.xor x12, x9
    beq x24, x28, fwd_br_h0_36
    addi x6, x6, 1
fwd_br_h0_36:
    divw x24, x12, x11
    slti x24, x4, -1215
    c.mv x20, x23
    sraiw x26, x24, 31
    slli x19, x6, 15
    and x20, x26, x14
    or x28, x20, x16
    sd x8, -248(x2)
    andi x27, x13, 1925
    sraiw x16, x8, 18
    slt x20, x16, x11
    add x25, x23, x20
    srai x13, x22, 35
    sll x24, x31, x13
    sllw x12, x24, x30
    srai x16, x16, 60
    sllw x29, x16, x21
    addi x5, x29, 207
    or x27, x26, x29
    srl x19, x27, x16
    div x24, x26, x25
    xor x18, x21, x14
    div x16, x30, x27
    remuw x15, x24, x16
    add x29, x16, x12
    bltu x29, x21, fwd_br_h0_37
    addi x31, x31, 1
fwd_br_h0_37:
    ori x4, x29, 1730
    addw x8, x23, x5
    c.addi x10, 23
    or x14, x10, x23
    or x21, x10, x20
    sraw x21, x11, x9
    mul x23, x15, x21
    srl x6, x23, x23
    lb x17, 470(x2)
    sltiu x21, x27, 203
    srai x25, x19, 34
    lw x23, 364(x2)
    c.addi x10, -26
    srl x4, x23, x30
    divuw x21, x28, x20
    bne x4, x25, fwd_br_h0_38
    addi x25, x25, 1
fwd_br_h0_38:
    addw x8, x24, x12
    addiw x5, x11, -372
    remu x10, x31, x5
    mulhu x4, x10, x9
    ori x16, x4, 1225
    sllw x31, x13, x16
    bne x31, x29, fwd_br_h0_39
    addi x20, x20, 1
fwd_br_h0_39:
    mulhu x6, x24, x10
    sra x17, x20, x22
    slti x30, x17, -1675
    slt x18, x9, x30
    srliw x20, x18, 13
    sllw x27, x20, x14
    srl x7, x17, x27
    slliw x25, x7, 30
    mulw x9, x25, x17
    mul x17, x25, x26
    remu x17, x24, x17
    addi x8, x8, 1401
    c.xor x15, x14
    add x8, x15, x12
    sh x15, -458(x2)
    xor x10, x4, x13
    or x22, x10, x16
    lhu x20, 436(x2)
    addw x22, x28, x20
    mulhu x27, x22, x15
    remuw x12, x27, x30
    sra x28, x27, x21
    remuw x10, x11, x19
    xori x27, x27, 1216
    slt x14, x27, x19
    xori x22, x7, 579
    slli x16, x22, 31
    lbu x4, 57(x2)
    sltiu x31, x7, -15
    slti x25, x31, 783
    blt x25, x20, fwd_br_h0_40
    addi x13, x13, 1
fwd_br_h0_40:
    divu x26, x18, x25
    sll x4, x15, x25
    c.addi x15, 7
    lbu x20, -4(x2)
    mulw x27, x20, x23
    ld x29, -440(x2)
    srliw x7, x25, 31
    sraiw x9, x21, 17
    sh x9, 28(x2)
    sb x5, 242(x2)
    sub x10, x30, x23
    slti x19, x10, 1756
    sltu x31, x19, x18
    slli x10, x31, 14
    divu x14, x27, x10
    c.sub x9, x14
    mulhu x7, x20, x9
    bne x12, x11, fwd_br_h0_41
    addi x4, x4, 1
fwd_br_h0_41:
    and x25, x7, x7
    srlw x14, x22, x8
    addiw x15, x24, -452
    and x30, x20, x15
    div x15, x6, x28
    srlw x13, x15, x18
    ori x8, x10, -228
    sw x8, 392(x2)
    c.mv x30, x25
    lhu x8, 170(x2)
    subw x27, x8, x21
    lbu x14, -40(x2)
    srli x11, x15, 52
    lw x31, -252(x2)
    sd x31, 152(x2)
    xor x12, x27, x14
    sllw x31, x29, x12
    sb x31, -337(x2)
    srl x11, x10, x12
    divu x14, x5, x22
    bge x19, x14, fwd_br_h0_42
    addi x6, x6, 1
fwd_br_h0_42:
    bne x14, x4, fwd_br_h0_43
    addi x30, x30, 1
fwd_br_h0_43:
    or x21, x11, x26
    srlw x22, x21, x28
    srl x8, x21, x9
    sltu x4, x14, x8
    xor x11, x10, x4
    and x6, x11, x23
    slti x5, x6, -879
    c.add x8, x10
    sh x5, 260(x2)
    addiw x20, x27, 1129
    addiw x13, x16, 235
    mul x23, x28, x13
    mulh x14, x23, x8
    andi x17, x7, -778
    srl x31, x17, x27
    mulhsu x8, x17, x22
    sllw x10, x25, x11
    sb x8, -256(x2)
    addw x9, x25, x9
    bltu x9, x16, fwd_br_h0_44
    addi x16, x16, 1
fwd_br_h0_44:
    divu x6, x9, x18
    srai x8, x17, 54
    sraiw x29, x26, 17
    mulhsu x12, x29, x8
    bgeu x12, x10, fwd_br_h0_45
    addi x17, x17, 1
fwd_br_h0_45:
    sra x23, x10, x26
    sra x22, x23, x25
    sh x26, -26(x2)
    sraw x17, x4, x31
    slt x15, x17, x27
    srl x13, x22, x15
    c.addi x11, -30
    xori x18, x11, -158
    bge x11, x9, fwd_br_h0_46
    addi x4, x4, 1
fwd_br_h0_46:
    srai x22, x10, 35
    sub x29, x30, x12
    addw x6, x22, x8
    sltiu x10, x6, 659
    srai x31, x4, 51
    srl x22, x21, x18
    srliw x7, x28, 3
    sltiu x24, x22, -1311
    sb x26, -115(x2)
    slli x21, x24, 13
    and x8, x14, x9
    slti x16, x7, -818
    mulhsu x24, x16, x26
    sra x19, x28, x14
    lbu x5, -9(x2)
    c.addw x12, x12
    mulh x22, x8, x12
    mulhsu x22, x22, x6
    c.sub x13, x15
    sb x22, 70(x2)
    mulw x23, x11, x7
    addiw x14, x23, -299
    mul x13, x23, x30
    srai x29, x13, 59
    remu x18, x9, x18
    slli x28, x14, 3
    sltiu x30, x5, -579
    xori x13, x20, -1277
    mulw x10, x22, x20
    srliw x14, x10, 10
    srlw x10, x14, x4
    sb x10, 447(x2)
    addiw x18, x31, -227
    slliw x4, x18, 16
    srlw x6, x4, x30
    c.addi x9, -6
    and x22, x9, x8
    slt x23, x18, x22
    lhu x11, -296(x2)
    bne x23, x31, fwd_br_h0_47
    addi x28, x28, 1
fwd_br_h0_47:
    lh x26, -484(x2)
    xori x26, x30, -1011
    ori x17, x26, 342
    rem x31, x17, x17
    ori x19, x11, -1435
    c.add x13, x14
    lb x6, 72(x2)
    remu x6, x29, x17
    sd x6, -392(x2)
    sllw x26, x26, x5
    ori x6, x31, -2014
    srli x29, x12, 31
    sraiw x14, x6, 5
    mulh x4, x10, x14
    sb x4, -29(x2)
    slli x28, x13, 29
    bltu x17, x9, fwd_br_h0_48
    addi x28, x28, 1
fwd_br_h0_48:
    andi x9, x21, -1279
    sd x7, 328(x2)
    sra x31, x18, x16
    srai x18, x23, 14
    sraw x7, x31, x11
    divu x10, x6, x13
    slt x18, x18, x10
    addw x21, x18, x27
    ld x25, -432(x2)
    mulw x31, x19, x30
    sll x5, x28, x11
    mul x27, x5, x7
    bge x21, x13, fwd_br_h0_49
    addi x28, x28, 1
fwd_br_h0_49:
    sh x27, 108(x2)
    andi x18, x21, 146
    ori x22, x9, 1677
    mulh x11, x22, x22
    slliw x21, x31, 6
    add x8, x21, x14
    lw x18, -376(x2)
    divuw x4, x18, x9
    rem x23, x18, x4
    c.addw x8, x10
    c.sub x13, x12
    beq x20, x13, fwd_br_h0_50
    addi x27, x27, 1
fwd_br_h0_50:
    rem x20, x19, x15
    srli x28, x20, 26
    lbu x19, -98(x2)
    mulw x29, x29, x15
    lw x30, 412(x2)
    lbu x25, -331(x2)
    mulhsu x26, x9, x7
    lhu x10, 242(x2)
    subw x16, x7, x11
    slli x26, x16, 9
    srli x31, x15, 43
    remw x9, x26, x28
    slliw x27, x9, 19
    sltu x12, x9, x10
    and x21, x19, x26
    sd x12, -368(x2)
    c.mv x5, x25
    c.or x11, x8
    addw x9, x28, x11
    slti x24, x9, 932
    c.mv x13, x24
    bgeu x24, x16, fwd_br_h0_51
    addi x30, x30, 1
fwd_br_h0_51:
    slliw x29, x13, 8
    remuw x18, x5, x29
    srliw x20, x29, 3
    sraw x18, x26, x13
    srliw x7, x18, 7
    mul x7, x7, x15
    bne x13, x7, fwd_br_h0_52
    addi x21, x21, 1
fwd_br_h0_52:
    addw x14, x17, x16
    addw x7, x20, x11
    beq x7, x11, fwd_br_h0_53
    addi x5, x5, 1
fwd_br_h0_53:
    sraiw x15, x8, 11
    divw x19, x28, x13
    c.addi x13, 4
    remw x21, x13, x8
    xor x12, x21, x6
    sraiw x8, x12, 11
    mulhu x10, x15, x26
    divuw x26, x8, x13
    subw x25, x29, x26
    lhu x11, 474(x2)
    sra x23, x25, x7
    lh x6, -172(x2)
    beq x6, x12, fwd_br_h0_54
    addi x4, x4, 1
fwd_br_h0_54:
    lw x6, -176(x2)
    slli x19, x26, 13
    lhu x30, -10(x2)
    srl x27, x30, x23
    mulh x26, x30, x19
    lw x23, 312(x2)
    sraiw x27, x26, 2
    sll x19, x23, x24
    lwu x11, 296(x2)
    sraiw x23, x11, 17
    sltiu x31, x11, 752
    sraw x25, x23, x5
    sub x25, x22, x25
    bgeu x22, x6, fwd_br_h0_55
    addi x17, x17, 1
fwd_br_h0_55:
    sllw x29, x24, x6
    srli x25, x29, 28
    blt x26, x11, fwd_br_h0_56
    addi x17, x17, 1
fwd_br_h0_56:
    mulhsu x14, x8, x5
    remu x15, x14, x30
    subw x28, x14, x8
    and x21, x6, x4
    c.add x14, x11
    or x25, x6, x14
    and x26, x14, x27
    mulw x20, x26, x25
    srai x22, x20, 36
    c.sub x14, x13
    c.xor x12, x14
    bge x4, x13, fwd_br_h0_57
    addi x28, x28, 1
fwd_br_h0_57:
    bge x18, x24, fwd_br_h0_58
    addi x29, x29, 1
fwd_br_h0_58:
    slliw x24, x12, 24
    bltu x12, x10, fwd_br_h0_59
    addi x27, x27, 1
fwd_br_h0_59:
    sll x15, x4, x27
    divu x27, x8, x15
    lw x29, -276(x2)
    ori x16, x29, 747
    andi x28, x29, -330
    blt x28, x29, fwd_br_h0_60
    addi x7, x7, 1
fwd_br_h0_60:
    slliw x21, x18, 17
    sltu x17, x29, x4
    c.sub x9, x9
    slliw x24, x9, 19
    srliw x29, x19, 28
    lh x17, -278(x2)
    c.addw x12, x14
    sub x11, x12, x20
    sraiw x27, x21, 8
    addi x19, x27, 674
    remw x18, x19, x7
    remw x17, x18, x7
    sraiw x11, x17, 15
    sub x25, x16, x16
    xor x25, x5, x25
    divu x26, x25, x29
    c.mv x27, x26
    ori x4, x26, -1917
    lwu x14, 40(x2)
    sub x26, x14, x29
    subw x22, x15, x26
    addw x11, x6, x16
    mulw x25, x7, x23
    sw x25, 220(x2)
    divuw x24, x4, x24
    srlw x9, x24, x4
    subw x13, x9, x18
    addiw x17, x12, -437
    and x14, x17, x25
    lhu x23, -422(x2)
    sraw x9, x23, x15
    srli x8, x7, 63
    sltiu x10, x13, 127
    lhu x26, 330(x2)
    srliw x6, x26, 14
    ld x12, -32(x2)
    and x30, x26, x12
    addiw x11, x18, -39
    and x15, x13, x11
    srliw x4, x13, 20
    mulhsu x19, x15, x24
    mulhsu x11, x8, x19
    mulh x19, x19, x26
    slti x25, x21, -1860
    sd x19, -104(x2)
    sh x11, -358(x2)
    remuw x12, x22, x6
    sll x18, x7, x14
    sra x14, x12, x18
    divuw x8, x14, x15
    slt x25, x7, x27
    sll x30, x8, x23
    blt x30, x22, fwd_br_h0_61
    addi x23, x23, 1
fwd_br_h0_61:
    sraw x14, x20, x9
    addi x11, x29, -773
    or x11, x11, x8
    mulhu x22, x17, x7
    srl x9, x6, x22
    c.sub x11, x9
    mulw x26, x15, x11
    sw x15, -444(x2)
    mulw x17, x9, x18
    sh x17, 134(x2)
    rem x17, x29, x14
    sub x8, x7, x15
    sraiw x29, x17, 27
    srlw x16, x29, x19
    srl x13, x16, x4
    or x12, x16, x5
    lh x16, 84(x2)
    slti x22, x16, -414
    sh x22, -210(x2)
    addiw x9, x7, -1164
    xor x14, x9, x4
    remw x9, x24, x25
    sw x25, 112(x2)
    sraw x12, x10, x9
    remw x28, x10, x13
    c.and x15, x15
    xori x27, x23, 602
    slti x23, x17, 1730
    remuw x22, x23, x6
    c.xor x8, x10
    addiw x25, x29, 1072
    addi x16, x21, 364
    addiw x30, x16, -258
    srlw x6, x30, x7
    sw x30, -308(x2)
    lhu x27, -500(x2)
    slli x13, x27, 26
    c.or x13, x14
    sw x29, 372(x2)
    slti x27, x16, 649
    bge x27, x5, fwd_br_h0_62
    addi x22, x22, 1
fwd_br_h0_62:
    srliw x24, x10, 11
    ori x14, x24, -952
    blt x14, x11, fwd_br_h0_63
    addi x13, x13, 1
fwd_br_h0_63:
    mulw x4, x27, x13
    sw x7, -268(x2)
    c.addi x11, 20
    divuw x18, x31, x10
    addi x19, x18, -294
    sltu x12, x19, x29
    beq x27, x27, fwd_br_h0_64
    addi x19, x19, 1
fwd_br_h0_64:
    slt x19, x21, x4
    sh x19, 30(x2)
    div x5, x17, x15
    slliw x18, x5, 14
    ori x30, x30, 603
    sw x18, -312(x2)
    mulw x6, x20, x21
    xori x13, x6, 1467
    add x17, x24, x30
    and x5, x17, x16
    sltiu x26, x30, -464
    add x15, x26, x4
    mul x17, x9, x15
    bgeu x17, x30, fwd_br_h0_65
    addi x26, x26, 1
fwd_br_h0_65:
    remw x21, x6, x28
    addiw x19, x28, 1140
    sraiw x23, x26, 9
    sub x18, x23, x14
    sltu x14, x8, x16
    sll x23, x19, x15
    srli x8, x22, 47
    remw x24, x29, x10
    xor x6, x26, x24
    remw x14, x20, x29
    sltiu x13, x14, -1085
    c.mv x18, x19
    c.add x15, x15
    addiw x28, x18, -1534
    divw x28, x28, x13
    slt x29, x28, x25
    c.mv x15, x20
    srl x30, x29, x15
    mul x16, x9, x29
    sllw x23, x6, x16
    addiw x20, x21, -1508
    sraw x18, x20, x31
    bge x20, x28, fwd_br_h0_66
    addi x4, x4, 1
fwd_br_h0_66:
    remuw x22, x18, x21
    addw x13, x31, x28
    srliw x23, x13, 11
    addiw x18, x23, -1719
    blt x18, x30, fwd_br_h0_67
    addi x17, x17, 1
fwd_br_h0_67:
    xor x30, x26, x19
    beq x13, x30, fwd_br_h0_68
    addi x21, x21, 1
fwd_br_h0_68:
    rem x30, x30, x16
    bge x5, x18, fwd_br_h0_69
    addi x18, x18, 1
fwd_br_h0_69:
    bge x21, x12, fwd_br_h0_70
    addi x17, x17, 1
fwd_br_h0_70:
    mul x25, x30, x6
    sllw x27, x6, x12
    remw x17, x25, x9
    /* --- END RANDOM INSTRUCTION BLOCK FOR HART 0 --- */
    addi x1, x1, -1
    bnez x1, .Lloop_hart0

    /* Hart 0 finished: store completion token */
    la   t1, h0_done
    li   t2, 0xCAFEBABE
    sd   t2, 0(t1)

    /* Hart 0 proceeds to wait for Harts 1..3 */
    j    .Lhart0_completion

/* ========================================================================= */
/* HART 1 EXECUTION STREAM                                                */
/* ========================================================================= */
.Lentry_hart1:
    /* Set up private scratchpad memory base pointer in x2 */
    la   x2, scratch_h1
    addi x2, x2, 2047
    addi x2, x2, 1

    /* Preload diverse corner values into registers x4..x31 */
    li   x4, 0x8000000000000000
    li   x5, 0x7fffffff
    li   x6, 0xffffffff80000000
    li   x7, 0xffffffff
    li   x8, 0x5555555555555555
    li   x9, 0xaaaaaaaaaaaaaaaa
    li   x10, 0x1
    li   x11, 0x2
    li   x12, 0xfffffffffffffffe
    li   x13, 0x3f
    li   x14, 0x1f
    li   x15, 0x123456789abcdef0
    li   x16, 0xdeadbeefcafebabe
    li   x17, 0x0
    li   x18, 0xffffffffffffffff
    li   x19, 0x7fffffffffffffff
    li   x20, 0x8000000000000000
    li   x21, 0x7fffffff
    li   x22, 0xffffffff80000000
    li   x23, 0xffffffff
    li   x24, 0x5555555555555555
    li   x25, 0xaaaaaaaaaaaaaaaa
    li   x26, 0x1
    li   x27, 0x2
    li   x28, 0xfffffffffffffffe
    li   x29, 0x3f
    li   x30, 0x1f
    li   x31, 0x123456789abcdef0

    /* Preload private scratchpad with initial deterministic data */
    li   x1, 0x123456789abcdf00
    sd   x1, -512(x2)
    addi x1, x1, 0x111
    sd   x1, -384(x2)
    addi x1, x1, 0x111
    sd   x1, -256(x2)
    addi x1, x1, 0x111
    sd   x1, -128(x2)
    addi x1, x1, 0x111
    sd   x1, 0(x2)
    addi x1, x1, 0x111
    sd   x1, 128(x2)
    addi x1, x1, 0x111
    sd   x1, 256(x2)
    addi x1, x1, 0x111
    sd   x1, 384(x2)
    addi x1, x1, 0x111

    /* Initialize loop counter in x1 */
    li   x1, 25
.Lloop_hart1:
    /* --- BEGIN RANDOM INSTRUCTION BLOCK FOR HART 1 --- */
    mul x23, x9, x4
    bge x17, x20, fwd_br_h1_0
    addi x9, x9, 1
fwd_br_h1_0:
    remuw x4, x16, x15
    xor x18, x15, x15
    sra x20, x20, x18
    divuw x16, x26, x20
    xor x26, x16, x26
    addiw x11, x26, 855
    div x5, x19, x11
    c.add x11, x8
    c.and x11, x8
    slt x28, x4, x11
    c.mv x22, x11
    addi x31, x17, -501
    c.mv x24, x17
    bge x31, x25, fwd_br_h1_1
    addi x6, x6, 1
fwd_br_h1_1:
    addw x25, x21, x4
    lhu x6, -392(x2)
    bge x6, x6, fwd_br_h1_2
    addi x22, x22, 1
fwd_br_h1_2:
    or x28, x8, x17
    sw x27, 132(x2)
    div x15, x15, x18
    slliw x24, x12, 17
    addiw x16, x24, -1205
    addiw x14, x11, 941
    lbu x20, -174(x2)
    sltiu x23, x17, -306
    c.addw x12, x13
    sra x10, x8, x12
    sll x15, x10, x6
    lh x11, -246(x2)
    mulhu x5, x26, x21
    sraw x5, x5, x29
    mulw x10, x5, x21
    beq x9, x10, fwd_br_h1_3
    addi x22, x22, 1
fwd_br_h1_3:
    sw x22, -148(x2)
    divu x30, x13, x14
    c.and x14, x10
    ori x11, x15, 382
    mulhsu x9, x17, x11
    divuw x22, x9, x13
    c.and x15, x15
    c.add x10, x13
    div x6, x22, x10
    divw x26, x6, x20
    lhu x25, 204(x2)
    c.mv x9, x29
    mulhu x20, x25, x19
    c.xor x14, x12
    slt x22, x4, x25
    lwu x10, 208(x2)
    sw x10, -428(x2)
    divw x24, x7, x21
    andi x28, x8, 1817
    beq x31, x28, fwd_br_h1_4
    addi x10, x10, 1
fwd_br_h1_4:
    mulhu x6, x12, x15
    sd x8, -496(x2)
    slti x23, x15, -606
    slt x25, x23, x20
    beq x23, x7, fwd_br_h1_5
    addi x21, x21, 1
fwd_br_h1_5:
    sh x20, 456(x2)
    remuw x17, x14, x16
    sb x17, -285(x2)
    sh x4, -460(x2)
    srai x7, x15, 39
    c.mv x18, x7
    sra x6, x18, x19
    addiw x31, x15, 1822
    mulh x20, x31, x10
    divu x14, x31, x16
    slliw x15, x20, 17
    lh x28, -20(x2)
    bltu x28, x27, fwd_br_h1_6
    addi x18, x18, 1
fwd_br_h1_6:
    sh x19, -274(x2)
    xor x21, x15, x25
    divu x15, x19, x13
    bge x26, x15, fwd_br_h1_7
    addi x24, x24, 1
fwd_br_h1_7:
    divuw x24, x15, x23
    srliw x6, x8, 20
    sh x6, 196(x2)
    sltu x17, x6, x21
    ori x26, x4, 658
    sb x17, 242(x2)
    bne x9, x23, fwd_br_h1_8
    addi x5, x5, 1
fwd_br_h1_8:
    sraiw x19, x21, 27
    sra x20, x4, x4
    slliw x11, x20, 16
    srliw x15, x11, 21
    divuw x23, x15, x18
    addw x6, x24, x23
    lwu x15, 352(x2)
    sb x6, -228(x2)
    sraiw x12, x12, 14
    slt x25, x12, x27
    mul x19, x30, x25
    sb x19, 388(x2)
    remw x11, x11, x13
    remw x4, x14, x11
    srlw x10, x4, x20
    srliw x28, x4, 4
    sub x27, x28, x24
    divw x25, x27, x18
    srl x9, x12, x9
    lhu x25, 286(x2)
    slli x13, x25, 50
    addiw x9, x24, 2031
    srliw x26, x9, 26
    remw x14, x12, x21
    sra x4, x26, x29
    beq x14, x9, fwd_br_h1_9
    addi x6, x6, 1
fwd_br_h1_9:
    bltu x14, x20, fwd_br_h1_10
    addi x9, x9, 1
fwd_br_h1_10:
    sw x21, 428(x2)
    sd x20, -144(x2)
    sw x5, -352(x2)
    sd x11, -400(x2)
    bne x26, x19, fwd_br_h1_11
    addi x10, x10, 1
fwd_br_h1_11:
    lbu x28, 20(x2)
    xori x22, x13, -1333
    xori x8, x14, -1585
    bge x22, x23, fwd_br_h1_12
    addi x15, x15, 1
fwd_br_h1_12:
    sll x23, x25, x26
    sltiu x27, x23, 1509
    sh x15, 366(x2)
    sb x21, -297(x2)
    sltu x27, x27, x17
    or x18, x10, x4
    add x17, x23, x24
    andi x30, x17, -1112
    addi x16, x17, -938
    remu x31, x30, x23
    xori x13, x14, 1189
    andi x9, x5, 1652
    remw x12, x13, x10
    srli x14, x9, 1
    xori x29, x17, -29
    addw x14, x14, x8
    bne x16, x27, fwd_br_h1_13
    addi x19, x19, 1
fwd_br_h1_13:
    c.add x12, x14
    sw x10, 248(x2)
    sllw x6, x25, x17
    sraw x17, x30, x7
    sltu x4, x17, x17
    sw x17, 268(x2)
    sltiu x13, x11, -9
    sra x6, x25, x8
    sb x19, 207(x2)
    and x26, x11, x15
    sllw x23, x14, x26
    sraiw x5, x23, 4
    rem x5, x26, x4
    sllw x15, x12, x27
    xor x12, x24, x15
    or x31, x20, x12
    lwu x25, -24(x2)
    sraiw x19, x28, 26
    slt x16, x25, x12
    slt x31, x16, x12
    xor x27, x16, x28
    sltiu x29, x27, -1490
    lwu x7, -192(x2)
    divuw x5, x7, x15
    slliw x27, x5, 29
    srl x29, x27, x6
    div x30, x26, x29
    bltu x28, x19, fwd_br_h1_14
    addi x26, x26, 1
fwd_br_h1_14:
    c.xor x10, x12
    slt x28, x18, x5
    slliw x29, x10, 31
    mulhu x18, x29, x12
    sllw x18, x13, x18
    remu x6, x18, x26
    lh x12, 66(x2)
    bge x6, x29, fwd_br_h1_15
    addi x15, x15, 1
fwd_br_h1_15:
    rem x29, x23, x23
    c.addi x13, 30
    slliw x19, x13, 2
    sltiu x16, x22, -1520
    srai x27, x16, 16
    sllw x25, x4, x31
    mulw x20, x25, x9
    blt x20, x7, fwd_br_h1_16
    addi x14, x14, 1
fwd_br_h1_16:
    xori x8, x23, 1005
    c.and x15, x11
    sll x31, x8, x17
    bne x31, x28, fwd_br_h1_17
    addi x27, x27, 1
fwd_br_h1_17:
    divw x6, x31, x22
    sb x21, 335(x2)
    sraw x10, x14, x4
    srlw x17, x4, x22
    slt x13, x16, x17
    sra x16, x22, x13
    ld x24, -272(x2)
    slti x15, x23, 138
    c.or x8, x14
    subw x24, x22, x8
    sll x4, x24, x15
    mulhsu x18, x24, x7
    divw x22, x18, x4
    c.or x9, x12
    sb x6, 21(x2)
    slti x5, x10, -48
    divw x10, x21, x5
    sh x5, 28(x2)
    xor x25, x20, x9
    mulhu x4, x25, x9
    addiw x30, x21, 492
    sub x30, x22, x30
    remu x31, x30, x11
    c.sub x10, x15
    divw x22, x28, x10
    srli x8, x12, 63
    sraiw x20, x17, 6
    remu x13, x10, x20
    sraiw x6, x24, 11
    sw x6, -372(x2)
    srai x6, x27, 61
    xori x19, x29, 782
    div x27, x19, x13
    xori x28, x27, -1406
    sltiu x20, x27, -382
    srlw x5, x19, x20
    lhu x14, 436(x2)
    remw x24, x5, x22
    sra x13, x24, x14
    rem x13, x15, x13
    xor x28, x29, x5
    sltiu x16, x17, -1861
    subw x19, x16, x8
    c.addi x8, 28
    or x9, x19, x15
    mulh x14, x8, x11
    srl x15, x22, x6
    lh x30, -150(x2)
    add x19, x26, x5
    c.or x11, x13
    c.or x15, x10
    divu x27, x11, x5
    divw x29, x27, x24
    sd x29, -472(x2)
    xor x4, x29, x4
    divw x7, x4, x28
    sb x9, 133(x2)
    addw x9, x7, x23
    sllw x5, x21, x4
    sd x5, 216(x2)
    slliw x27, x14, 4
    and x23, x27, x23
    sll x29, x23, x6
    remu x23, x29, x12
    addi x14, x23, 211
    mulhsu x7, x14, x21
    slliw x21, x6, 18
    mulhsu x26, x21, x5
    mulh x16, x26, x27
    sh x15, -270(x2)
    slli x24, x14, 14
    srliw x22, x24, 2
    sllw x25, x22, x29
    bgeu x12, x6, fwd_br_h1_18
    addi x14, x14, 1
fwd_br_h1_18:
    mulhu x23, x12, x12
    srl x12, x6, x29
    sd x23, 504(x2)
    remu x10, x26, x20
    blt x19, x21, fwd_br_h1_19
    addi x20, x20, 1
fwd_br_h1_19:
    slli x9, x15, 53
    sraiw x5, x9, 2
    ld x23, 448(x2)
    add x18, x23, x25
    sb x18, 346(x2)
    lw x30, 120(x2)
    srliw x22, x24, 18
    sra x20, x19, x20
    sb x20, 176(x2)
    xor x4, x9, x29
    sw x29, -188(x2)
    srliw x5, x25, 3
    c.addi x10, -17
    subw x27, x10, x23
    div x24, x29, x4
    lb x16, 403(x2)
    rem x19, x24, x26
    div x8, x4, x12
    sll x7, x8, x13
    and x16, x20, x24
    remu x8, x16, x22
    c.addi x11, 12
    or x16, x27, x13
    lb x6, -387(x2)
    srai x11, x6, 17
    c.or x13, x11
    sltu x12, x28, x9
    slti x22, x28, 1231
    subw x6, x22, x18
    srliw x5, x14, 3
    lh x11, 508(x2)
    lh x22, -244(x2)
    xori x23, x11, -1666
    beq x19, x30, fwd_br_h1_20
    addi x12, x12, 1
fwd_br_h1_20:
    andi x16, x13, -1107
    divu x10, x9, x16
    div x15, x10, x15
    lwu x14, 300(x2)
    add x23, x15, x19
    slti x22, x28, -35
    sb x22, -420(x2)
    srai x5, x6, 15
    slliw x8, x5, 20
    andi x30, x5, -323
    divu x8, x30, x16
    beq x29, x29, fwd_br_h1_21
    addi x31, x31, 1
fwd_br_h1_21:
    rem x15, x8, x8
    divuw x7, x26, x5
    c.addi x13, -18
    slliw x6, x7, 28
    mulw x30, x20, x6
    srlw x4, x30, x18
    lw x22, -492(x2)
    slti x18, x30, 1832
    mulhu x28, x18, x30
    divuw x19, x6, x13
    srli x25, x26, 47
    bltu x25, x28, fwd_br_h1_22
    addi x25, x25, 1
fwd_br_h1_22:
    sllw x4, x29, x28
    divuw x15, x28, x18
    sw x15, -204(x2)
    sub x19, x15, x22
    sh x27, 254(x2)
    c.mv x12, x21
    lw x13, -192(x2)
    div x19, x12, x15
    slliw x25, x24, 31
    c.mv x25, x19
    mulhsu x20, x30, x25
    mulhsu x14, x22, x20
    sb x30, -351(x2)
    srai x25, x31, 60
    slliw x27, x25, 24
    or x20, x27, x12
    sraiw x6, x20, 2
    srai x30, x6, 44
    sh x24, -304(x2)
    lbu x12, -171(x2)
    mulhsu x26, x12, x26
    addiw x29, x7, 2039
    add x5, x29, x28
    c.mv x16, x5
    mulhsu x28, x5, x17
    c.mv x15, x28
    mulw x13, x25, x21
    add x20, x7, x11
    slliw x21, x25, 10
    srai x26, x21, 40
    sub x4, x26, x24
    bge x26, x18, fwd_br_h1_23
    addi x18, x18, 1
fwd_br_h1_23:
    remuw x6, x21, x19
    sh x6, -228(x2)
    divw x26, x21, x24
    mulh x19, x26, x20
    divu x15, x27, x19
    srli x16, x15, 48
    srli x19, x7, 6
    remu x29, x19, x16
    mul x4, x19, x14
    slli x19, x29, 63
    srlw x12, x18, x19
    addi x28, x19, -1698
    sllw x6, x12, x29
    xori x30, x11, -264
    divu x19, x11, x30
    sraiw x22, x19, 10
    remu x31, x22, x28
    sltu x31, x31, x23
    add x26, x31, x29
    slliw x19, x31, 20
    subw x12, x19, x25
    slt x16, x12, x31
    srliw x8, x22, 28
    sraiw x6, x8, 27
    subw x17, x30, x6
    slli x30, x6, 34
    addw x18, x25, x4
    lhu x26, 178(x2)
    xor x16, x26, x7
    andi x24, x16, 1474
    addi x6, x24, 47
    and x4, x24, x5
    add x26, x6, x10
    ori x24, x26, 1712
    subw x23, x10, x9
    sb x23, -394(x2)
    lbu x17, 474(x2)
    c.addw x11, x12
    srliw x20, x17, 6
    andi x13, x20, -136
    bgeu x20, x21, fwd_br_h1_24
    addi x20, x20, 1
fwd_br_h1_24:
    addw x28, x13, x12
    add x17, x20, x24
    sb x29, 298(x2)
    bltu x17, x28, fwd_br_h1_25
    addi x15, x15, 1
fwd_br_h1_25:
    lbu x15, -444(x2)
    divw x8, x12, x15
    or x18, x28, x24
    ld x10, -472(x2)
    sra x8, x10, x31
    c.add x10, x12
    srlw x20, x8, x27
    or x28, x10, x6
    sltiu x17, x22, 1148
    c.and x8, x15
    addi x29, x9, 1725
    add x11, x29, x14
    sh x29, 338(x2)
    sraw x14, x11, x6
    addiw x8, x7, -748
    divw x31, x7, x27
    srliw x15, x10, 15
    srl x27, x26, x20
    or x22, x27, x16
    divuw x5, x23, x23
    lh x8, -96(x2)
    add x18, x18, x8
    slti x31, x5, -670
    srl x18, x11, x16
    bltu x9, x18, fwd_br_h1_26
    addi x21, x21, 1
fwd_br_h1_26:
    sb x5, 197(x2)
    slliw x16, x19, 1
    c.xor x10, x14
    sraw x17, x16, x13
    bgeu x31, x17, fwd_br_h1_27
    addi x31, x31, 1
fwd_br_h1_27:
    lh x6, 426(x2)
    lhu x30, -100(x2)
    addiw x9, x4, -562
    slli x8, x30, 38
    sh x18, -484(x2)
    srliw x15, x13, 19
    remuw x4, x27, x18
    lw x17, 168(x2)
    addiw x28, x4, -231
    mulhu x10, x17, x9
    lw x11, 80(x2)
    bgeu x26, x13, fwd_br_h1_28
    addi x10, x10, 1
fwd_br_h1_28:
    or x29, x5, x6
    addi x21, x16, -851
    sub x6, x16, x28
    remw x15, x5, x13
    add x25, x6, x13
    sraw x29, x25, x18
    lwu x31, -116(x2)
    srl x31, x29, x22
    sw x31, 308(x2)
    srli x24, x31, 37
    sll x6, x24, x17
    srlw x13, x8, x12
    or x20, x18, x11
    xor x27, x20, x28
    rem x7, x27, x10
    subw x8, x7, x11
    srliw x30, x10, 31
    blt x30, x16, fwd_br_h1_29
    addi x27, x27, 1
fwd_br_h1_29:
    mul x16, x25, x19
    c.add x15, x10
    mulh x30, x15, x12
    slt x11, x15, x27
    ori x4, x10, 300
    xor x31, x4, x29
    divuw x29, x31, x24
    mul x12, x25, x29
    slliw x21, x12, 7
    mulw x8, x12, x15
    remuw x27, x15, x6
    sllw x24, x8, x20
    srliw x9, x13, 30
    andi x31, x20, 781
    lw x31, 120(x2)
    lb x7, -415(x2)
    sh x7, -100(x2)
    mulhsu x13, x21, x5
    c.sub x11, x13
    div x16, x11, x14
    c.addw x13, x12
    c.addi x11, 4
    slliw x6, x7, 21
    sraw x19, x11, x15
    srai x28, x15, 22
    mulw x15, x25, x28
    c.sub x9, x12
    srliw x13, x9, 13
    bgeu x13, x13, fwd_br_h1_30
    addi x28, x28, 1
fwd_br_h1_30:
    sltiu x8, x13, -660
    sll x27, x24, x23
    divu x10, x8, x11
    sw x27, 252(x2)
    sw x6, -388(x2)
    srliw x27, x24, 16
    sllw x21, x24, x7
    sw x21, 196(x2)
    srlw x13, x21, x19
    srliw x8, x22, 25
    slliw x31, x5, 0
    lbu x28, 88(x2)
    srlw x12, x31, x8
    blt x6, x9, fwd_br_h1_31
    addi x24, x24, 1
fwd_br_h1_31:
    srliw x19, x29, 9
    addw x6, x19, x17
    sraiw x6, x24, 25
    c.and x12, x14
    sltu x8, x12, x23
    srli x5, x8, 58
    slliw x19, x5, 6
    sra x15, x29, x27
    div x7, x19, x22
    bgeu x7, x25, fwd_br_h1_32
    addi x22, x22, 1
fwd_br_h1_32:
    slli x21, x25, 4
    sraw x24, x21, x14
    sll x27, x24, x7
    mul x22, x24, x30
    sd x20, 224(x2)
    c.addw x8, x9
    mul x4, x8, x20
    bgeu x4, x29, fwd_br_h1_33
    addi x21, x21, 1
fwd_br_h1_33:
    c.addi x12, 1
    sh x12, -238(x2)
    srai x26, x9, 7
    srliw x15, x26, 25
    xor x28, x15, x13
    andi x11, x28, -586
    remuw x27, x11, x27
    slli x17, x6, 1
    bge x17, x25, fwd_br_h1_34
    addi x12, x12, 1
fwd_br_h1_34:
    lhu x22, 168(x2)
    sltiu x29, x22, -2016
    divw x28, x29, x5
    mulhsu x17, x28, x30
    srli x15, x19, 58
    srl x4, x18, x15
    lhu x17, -352(x2)
    xori x21, x17, -197
    c.or x15, x14
    mulhsu x26, x21, x15
    slti x17, x26, 499
    sllw x29, x17, x11
    sraw x25, x16, x19
    srai x12, x25, 63
    srl x27, x24, x8
    srai x12, x17, 20
    remw x18, x12, x11
    srai x6, x18, 0
    srliw x17, x6, 6
    addiw x19, x17, -798
    lh x14, -226(x2)
    sltiu x10, x19, -441
    remu x17, x10, x10
    and x4, x17, x5
    srli x18, x5, 1
    lbu x30, -98(x2)
    sraiw x17, x30, 29
    andi x10, x17, 1264
    mulw x31, x4, x10
    andi x9, x11, -1887
    mulh x28, x4, x9
    lwu x13, -96(x2)
    sb x20, -443(x2)
    sb x27, 393(x2)
    remw x16, x27, x18
    sh x25, 254(x2)
    and x11, x19, x16
    sltiu x11, x17, 136
    slliw x31, x11, 30
    sraiw x16, x15, 7
    lb x20, -502(x2)
    rem x9, x20, x16
    sraiw x11, x9, 26
    mul x27, x6, x29
    sltiu x9, x27, 1920
    subw x30, x9, x18
    addiw x24, x30, -667
    bne x19, x13, fwd_br_h1_35
    addi x26, x26, 1
fwd_br_h1_35:
    bgeu x30, x15, fwd_br_h1_36
    addi x18, x18, 1
fwd_br_h1_36:
    slliw x4, x30, 3
    sllw x31, x4, x12
    sd x13, 288(x2)
    sltiu x31, x31, 497
    srai x31, x25, 37
    bgeu x31, x15, fwd_br_h1_37
    addi x13, x13, 1
fwd_br_h1_37:
    lh x19, -370(x2)
    andi x24, x11, 340
    sb x11, 431(x2)
    div x31, x11, x26
    mulhsu x22, x11, x10
    sraw x26, x31, x8
    lhu x31, -16(x2)
    sd x25, -280(x2)
    subw x13, x26, x26
    ld x10, 408(x2)
    c.xor x12, x13
    srai x31, x12, 41
    addw x24, x31, x13
    addi x10, x21, -492
    bne x20, x31, fwd_br_h1_38
    addi x21, x21, 1
fwd_br_h1_38:
    subw x29, x8, x20
    c.and x9, x15
    remw x19, x9, x6
    srlw x15, x19, x9
    sub x31, x15, x15
    sraiw x23, x21, 28
    addw x28, x31, x24
    lwu x12, -316(x2)
    sraiw x11, x23, 21
    sraw x27, x4, x30
    srlw x21, x27, x27
    sltiu x12, x27, -1930
    srli x10, x12, 29
    and x13, x20, x10
    divw x26, x13, x27
    remu x25, x19, x18
    c.addw x9, x15
    mul x8, x24, x6
    slliw x6, x8, 4
    sraiw x26, x27, 11
    sllw x23, x26, x14
    remuw x31, x6, x27
    sb x31, -338(x2)
    divu x16, x11, x15
    slliw x23, x16, 13
    div x31, x13, x21
    mulhsu x31, x31, x25
    sd x31, -128(x2)
    remw x15, x31, x20
    remu x6, x9, x25
    c.add x15, x9
    mulhsu x10, x19, x15
    c.addw x14, x10
    srlw x18, x28, x28
    blt x15, x18, fwd_br_h1_39
    addi x30, x30, 1
fwd_br_h1_39:
    addi x17, x31, -1916
    div x24, x17, x20
    sraiw x10, x27, 31
    ori x18, x10, 1682
    sh x10, -88(x2)
    bgeu x25, x10, fwd_br_h1_40
    addi x4, x4, 1
fwd_br_h1_40:
    c.addw x8, x9
    ori x17, x12, 505
    rem x10, x17, x4
    c.mv x31, x4
    divw x13, x4, x31
    sub x27, x31, x23
    sh x27, -310(x2)
    xor x31, x27, x21
    remu x24, x7, x31
    sd x9, 296(x2)
    sltiu x18, x6, -288
    sw x12, 48(x2)
    and x5, x5, x19
    slli x22, x5, 3
    sra x12, x22, x28
    addiw x12, x16, 896
    srliw x26, x5, 3
    slliw x17, x12, 17
    mulhsu x13, x26, x7
    addi x13, x17, 1654
    c.and x8, x14
    xor x18, x17, x26
    div x24, x9, x18
    xor x25, x24, x26
    sh x5, -148(x2)
    addiw x22, x6, 390
    c.add x13, x9
    addi x13, x21, -1486
    bge x5, x21, fwd_br_h1_41
    addi x18, x18, 1
fwd_br_h1_41:
    mulhsu x28, x17, x7
    subw x15, x28, x21
    addiw x21, x15, 1915
    ori x5, x21, -1747
    or x23, x5, x13
    xor x17, x25, x21
    addiw x14, x17, 1333
    bge x28, x6, fwd_br_h1_42
    addi x24, x24, 1
fwd_br_h1_42:
    slli x22, x14, 1
    sllw x25, x25, x30
    slliw x17, x22, 24
    addw x16, x17, x21
    divw x5, x16, x23
    lh x23, -132(x2)
    slli x6, x23, 50
    c.addi x11, -9
    lw x18, -512(x2)
    sraiw x4, x22, 1
    mulhu x7, x4, x28
    bgeu x7, x9, fwd_br_h1_43
    addi x18, x18, 1
fwd_br_h1_43:
    divw x30, x20, x13
    sw x30, 36(x2)
    sll x27, x29, x28
    sltu x18, x21, x8
    lw x10, -12(x2)
    slliw x18, x24, 27
    c.sub x10, x11
    bgeu x10, x19, fwd_br_h1_44
    addi x23, x23, 1
fwd_br_h1_44:
    mul x22, x8, x9
    addiw x16, x31, 1046
    lh x12, 28(x2)
    and x25, x17, x26
    sltiu x22, x12, 1267
    sub x28, x22, x8
    addiw x21, x30, 1990
    c.or x13, x9
    lh x19, 272(x2)
    sd x21, -216(x2)
    ori x4, x9, 1372
    addiw x20, x4, -1388
    mulw x18, x6, x30
    remuw x19, x18, x8
    sllw x12, x18, x29
    srl x9, x12, x28
    mulhsu x24, x9, x20
    subw x4, x9, x22
    ori x28, x22, 1515
    addiw x13, x8, 265
    c.add x11, x9
    mulh x11, x11, x27
    lb x9, 405(x2)
    divuw x20, x11, x4
    ori x23, x23, 418
    remuw x24, x23, x19
    mulhu x31, x24, x5
    sltiu x5, x31, -1920
    sraiw x17, x15, 31
    lh x9, 282(x2)
    sb x17, 306(x2)
    slli x24, x17, 49
    mulhsu x9, x12, x24
    srai x25, x14, 2
    sw x25, 272(x2)
    c.mv x19, x25
    andi x26, x25, -1305
    divuw x19, x26, x21
    addiw x9, x17, -170
    bne x19, x23, fwd_br_h1_45
    addi x28, x28, 1
fwd_br_h1_45:
    sh x29, -2(x2)
    sb x9, -72(x2)
    sub x22, x4, x8
    srl x28, x8, x22
    rem x26, x27, x30
    divuw x27, x26, x9
    srlw x20, x10, x27
    mulhu x23, x31, x17
    lwu x25, 180(x2)
    lhu x31, -8(x2)
    remw x26, x8, x31
    divw x6, x31, x7
    sb x10, -144(x2)
    ori x15, x21, -1323
    srlw x15, x11, x15
    addw x6, x15, x9
    srlw x28, x12, x6
    mul x18, x28, x22
    slli x13, x18, 7
    slt x18, x18, x16
    sb x8, 111(x2)
    c.sub x13, x11
    srai x28, x13, 42
    sllw x21, x28, x27
    remuw x9, x28, x24
    and x18, x9, x22
    ld x8, 496(x2)
    sh x25, -16(x2)
    add x23, x27, x24
    blt x30, x26, fwd_br_h1_46
    addi x19, x19, 1
fwd_br_h1_46:
    sraw x8, x5, x6
    srliw x17, x8, 28
    add x10, x17, x5
    addiw x8, x18, 773
    xori x23, x10, -1572
    addw x13, x26, x23
    sraiw x17, x30, 11
    sraiw x15, x7, 10
    mul x4, x15, x18
    c.or x13, x10
    srai x12, x4, 19
    sh x13, 332(x2)
    blt x31, x15, fwd_br_h1_47
    addi x8, x8, 1
fwd_br_h1_47:
    srli x10, x7, 34
    mulw x30, x30, x26
    c.or x13, x10
    srl x18, x22, x13
    xori x28, x30, -89
    rem x31, x28, x8
    slli x23, x31, 37
    c.addw x11, x13
    c.addi x14, -13
    slliw x23, x10, 20
    sd x20, -64(x2)
    remu x4, x13, x7
    ori x16, x13, -17
    mulh x22, x28, x5
    mulhsu x5, x22, x22
    lhu x12, -332(x2)
    sll x17, x6, x29
    sb x17, -98(x2)
    xor x18, x6, x18
    c.or x10, x12
    sw x15, 76(x2)
    xor x28, x5, x24
    sub x23, x8, x23
    mul x11, x9, x10
    rem x16, x11, x5
    xor x11, x11, x19
    addiw x29, x11, -1811
    mulw x29, x30, x29
    srliw x30, x29, 19
    sh x30, 170(x2)
    add x25, x21, x24
    c.mv x19, x13
    bltu x19, x17, fwd_br_h1_48
    addi x23, x23, 1
fwd_br_h1_48:
    sltu x27, x14, x23
    srliw x8, x31, 11
    xor x15, x8, x10
    sb x15, -53(x2)
    sraiw x16, x15, 27
    c.and x10, x15
    addi x6, x14, 1910
    bgeu x6, x6, fwd_br_h1_49
    addi x20, x20, 1
fwd_br_h1_49:
    mulhu x6, x13, x27
    subw x19, x6, x20
    bne x19, x19, fwd_br_h1_50
    addi x25, x25, 1
fwd_br_h1_50:
    sraiw x5, x20, 14
    sra x21, x17, x27
    sltu x31, x21, x26
    remu x18, x31, x14
    bne x18, x23, fwd_br_h1_51
    addi x4, x4, 1
fwd_br_h1_51:
    mulhsu x31, x18, x8
    addiw x14, x31, -158
    slliw x30, x31, 20
    sub x21, x30, x5
    c.and x12, x9
    and x25, x22, x19
    bge x17, x10, fwd_br_h1_52
    addi x17, x17, 1
fwd_br_h1_52:
    c.add x10, x13
    lh x27, -234(x2)
    beq x24, x12, fwd_br_h1_53
    addi x4, x4, 1
fwd_br_h1_53:
    lhu x26, 58(x2)
    sub x10, x26, x23
    sltu x11, x26, x6
    addiw x13, x11, 888
    add x10, x13, x6
    blt x10, x28, fwd_br_h1_54
    addi x16, x16, 1
fwd_br_h1_54:
    subw x5, x30, x23
    c.addi x10, -11
    srliw x14, x5, 25
    addw x9, x14, x23
    mulh x6, x14, x24
    lh x25, -62(x2)
    addw x14, x7, x25
    ld x30, 16(x2)
    mulhsu x10, x6, x30
    sra x31, x4, x20
    divw x9, x26, x31
    divuw x13, x11, x31
    xor x26, x23, x13
    divu x8, x26, x23
    slli x25, x28, 18
    add x23, x25, x19
    addw x11, x20, x8
    c.or x13, x14
    sub x28, x13, x7
    ori x23, x23, 1631
    andi x11, x20, -623
    lb x21, 254(x2)
    srlw x6, x8, x21
    c.xor x9, x15
    bltu x14, x7, fwd_br_h1_55
    addi x12, x12, 1
fwd_br_h1_55:
    bge x19, x16, fwd_br_h1_56
    addi x18, x18, 1
fwd_br_h1_56:
    sllw x11, x8, x5
    srliw x21, x12, 4
    slti x15, x21, -859
    sllw x12, x18, x15
    addw x24, x8, x12
    sd x12, 336(x2)
    divw x4, x19, x30
    slliw x30, x4, 18
    sh x24, 92(x2)
    xori x20, x30, -891
    divuw x4, x20, x17
    sllw x26, x22, x14
    ld x20, -144(x2)
    andi x16, x20, -852
    lhu x5, -240(x2)
    lbu x28, 292(x2)
    remw x19, x13, x28
    addiw x19, x25, -1970
    sraw x12, x31, x23
    lb x30, -478(x2)
    mulhu x30, x30, x8
    c.addw x9, x9
    sltiu x6, x9, 1495
    slliw x12, x7, 6
    slli x4, x6, 0
    mul x5, x12, x18
    mulhu x19, x17, x5
    divw x10, x16, x16
    c.addw x10, x9
    c.or x11, x8
    remu x24, x25, x11
    bne x11, x19, fwd_br_h1_57
    addi x5, x5, 1
fwd_br_h1_57:
    bne x17, x30, fwd_br_h1_58
    addi x31, x31, 1
fwd_br_h1_58:
    c.add x13, x12
    sd x13, -8(x2)
    bltu x10, x22, fwd_br_h1_59
    addi x19, x19, 1
fwd_br_h1_59:
    srliw x16, x23, 11
    rem x8, x16, x9
    c.or x9, x14
    srlw x31, x9, x9
    sltiu x26, x31, 454
    sd x5, -248(x2)
    mulw x15, x26, x19
    sb x15, 245(x2)
    ori x20, x15, -1357
    sraiw x7, x6, 4
    lwu x15, -116(x2)
    c.addw x9, x13
    sh x15, 204(x2)
    rem x28, x21, x25
    sraw x21, x28, x22
    addiw x12, x20, 1008
    srl x15, x21, x13
    c.sub x9, x15
    sraw x12, x15, x29
    srlw x21, x20, x18
    sllw x12, x23, x5
    slt x6, x12, x10
    mulw x30, x6, x14
    sltu x6, x30, x29
    c.and x11, x12
    sltu x28, x12, x11
    blt x22, x31, fwd_br_h1_60
    addi x29, x29, 1
fwd_br_h1_60:
    lwu x29, -208(x2)
    andi x15, x28, -406
    sraiw x15, x26, 0
    srliw x18, x5, 11
    sb x28, 184(x2)
    sh x22, 30(x2)
    srlw x14, x12, x31
    slt x23, x14, x5
    divuw x16, x12, x23
    addi x6, x16, -1524
    sb x6, 316(x2)
    sraw x31, x29, x15
    mulh x22, x31, x13
    sraw x10, x27, x22
    rem x6, x25, x6
    slti x19, x22, 1298
    srl x27, x19, x23
    mul x13, x19, x23
    srlw x28, x13, x4
    addw x23, x28, x13
    sra x18, x28, x23
    mulh x28, x18, x18
    sllw x21, x28, x24
    c.or x13, x15
    subw x24, x6, x17
    srl x18, x13, x7
    c.and x15, x8
    sw x26, 436(x2)
    sra x20, x9, x11
    lh x14, 214(x2)
    slliw x28, x20, 30
    divu x23, x14, x10
    slli x6, x8, 19
    sltu x20, x6, x18
    mul x9, x6, x8
    remuw x16, x27, x9
    mulhu x5, x9, x24
    srliw x25, x16, 18
    slliw x22, x25, 6
    lbu x25, 500(x2)
    xori x31, x24, -524
    lbu x21, 382(x2)
    divu x25, x31, x10
    slliw x19, x21, 19
    sw x19, 408(x2)
    beq x26, x29, fwd_br_h1_61
    addi x14, x14, 1
fwd_br_h1_61:
    addiw x22, x31, -954
    xori x31, x31, -48
    or x12, x8, x31
    lb x29, 317(x2)
    sllw x27, x12, x9
    c.mv x7, x27
    slliw x11, x28, 25
    sraiw x16, x11, 18
    lbu x24, 157(x2)
    or x17, x13, x10
    blt x25, x17, fwd_br_h1_62
    addi x24, x24, 1
fwd_br_h1_62:
    c.addw x14, x13
    srl x22, x14, x9
    sraw x30, x14, x28
    c.xor x14, x15
    xori x20, x18, 1753
    srlw x23, x20, x20
    c.add x15, x10
    slli x4, x23, 33
    srli x6, x16, 44
    /* --- END RANDOM INSTRUCTION BLOCK FOR HART 1 --- */
    addi x1, x1, -1
    bnez x1, .Lloop_hart1

    /* Hart 1 finished: store completion token */
    la   t1, h1_done
    li   t2, 0xCAFEBABE
    sd   t2, 0(t1)

    /* Secondary hart enters low-power sleep */
.Ldone_sleep_h1:
    wfi
    j    .Ldone_sleep_h1

/* ========================================================================= */
/* HART 2 EXECUTION STREAM                                                */
/* ========================================================================= */
.Lentry_hart2:
    /* Set up private scratchpad memory base pointer in x2 */
    la   x2, scratch_h2
    addi x2, x2, 2047
    addi x2, x2, 1

    /* Preload diverse corner values into registers x4..x31 */
    li   x4, 0xffffffff
    li   x5, 0x5555555555555555
    li   x6, 0xaaaaaaaaaaaaaaaa
    li   x7, 0x1
    li   x8, 0x2
    li   x9, 0xfffffffffffffffe
    li   x10, 0x3f
    li   x11, 0x1f
    li   x12, 0x123456789abcdef0
    li   x13, 0xdeadbeefcafebabe
    li   x14, 0x0
    li   x15, 0xffffffffffffffff
    li   x16, 0x7fffffffffffffff
    li   x17, 0x8000000000000000
    li   x18, 0x7fffffff
    li   x19, 0xffffffff80000000
    li   x20, 0xffffffff
    li   x21, 0x5555555555555555
    li   x22, 0xaaaaaaaaaaaaaaaa
    li   x23, 0x1
    li   x24, 0x2
    li   x25, 0xfffffffffffffffe
    li   x26, 0x3f
    li   x27, 0x1f
    li   x28, 0x123456789abcdef0
    li   x29, 0xdeadbeefcafebabe
    li   x30, 0x0
    li   x31, 0xffffffffffffffff

    /* Preload private scratchpad with initial deterministic data */
    li   x1, 0x23456789abcdf011
    sd   x1, -512(x2)
    addi x1, x1, 0x111
    sd   x1, -384(x2)
    addi x1, x1, 0x111
    sd   x1, -256(x2)
    addi x1, x1, 0x111
    sd   x1, -128(x2)
    addi x1, x1, 0x111
    sd   x1, 0(x2)
    addi x1, x1, 0x111
    sd   x1, 128(x2)
    addi x1, x1, 0x111
    sd   x1, 256(x2)
    addi x1, x1, 0x111
    sd   x1, 384(x2)
    addi x1, x1, 0x111

    /* Initialize loop counter in x1 */
    li   x1, 25
.Lloop_hart2:
    /* --- BEGIN RANDOM INSTRUCTION BLOCK FOR HART 2 --- */
    addi x9, x4, 1033
    bge x5, x12, fwd_br_h2_0
    addi x10, x10, 1
fwd_br_h2_0:
    or x19, x22, x14
    srliw x30, x19, 7
    div x15, x31, x30
    slli x16, x4, 12
    sraw x23, x16, x24
    sraiw x26, x15, 26
    addi x20, x26, 1151
    sll x26, x20, x8
    srli x29, x26, 39
    slliw x15, x29, 6
    and x27, x31, x10
    add x23, x27, x23
    sraw x6, x17, x17
    srliw x6, x6, 29
    c.and x13, x13
    sw x15, -452(x2)
    ld x26, 8(x2)
    bge x26, x17, fwd_br_h2_1
    addi x18, x18, 1
fwd_br_h2_1:
    div x25, x19, x6
    sraiw x6, x19, 14
    c.or x8, x14
    sllw x18, x28, x10
    sb x14, -366(x2)
    sd x30, -24(x2)
    mulhsu x18, x13, x12
    c.addi x13, 18
    sll x10, x13, x15
    xori x11, x10, -1230
    mulhsu x23, x10, x14
    ori x7, x11, -1157
    c.addw x14, x14
    c.or x13, x14
    sllw x13, x14, x24
    sraiw x12, x8, 10
    sra x6, x13, x26
    srai x8, x12, 32
    slli x25, x17, 4
    srliw x24, x22, 25
    slti x22, x26, 1676
    mul x15, x22, x5
    sw x7, -476(x2)
    slti x24, x23, -505
    xor x9, x24, x25
    bltu x9, x18, fwd_br_h2_2
    addi x28, x28, 1
fwd_br_h2_2:
    slli x15, x26, 40
    addiw x22, x11, -1340
    lbu x24, -306(x2)
    subw x14, x24, x20
    sraiw x22, x14, 11
    slliw x27, x19, 17
    sw x7, -228(x2)
    lbu x25, 40(x2)
    ori x8, x28, 1023
    add x27, x8, x21
    addi x23, x10, -617
    sh x4, -500(x2)
    addiw x24, x21, 945
    c.add x8, x11
    c.sub x11, x13
    divuw x27, x26, x8
    add x6, x13, x27
    or x10, x22, x6
    andi x23, x29, -1972
    lw x5, -296(x2)
    srai x15, x12, 48
    sb x12, -481(x2)
    remw x14, x30, x21
    sltiu x17, x30, 1714
    lwu x5, 36(x2)
    div x10, x17, x7
    sll x11, x5, x23
    rem x15, x10, x16
    remu x14, x8, x15
    slli x12, x16, 23
    c.addi x10, -23
    subw x7, x10, x23
    sra x18, x29, x22
    lbu x7, 380(x2)
    sraw x27, x7, x7
    subw x22, x7, x5
    srl x6, x22, x31
    bge x6, x11, fwd_br_h2_3
    addi x4, x4, 1
fwd_br_h2_3:
    mulhu x11, x6, x13
    sltu x9, x11, x20
    rem x30, x9, x17
    c.mv x17, x22
    slt x4, x30, x9
    and x11, x17, x31
    sraiw x17, x18, 19
    blt x17, x29, fwd_br_h2_4
    addi x27, x27, 1
fwd_br_h2_4:
    c.add x15, x9
    addiw x19, x15, 895
    srliw x30, x31, 15
    or x8, x30, x27
    srai x12, x12, 31
    divuw x25, x12, x13
    sllw x9, x25, x6
    remw x18, x7, x30
    sw x17, 296(x2)
    addw x9, x30, x26
    blt x14, x20, fwd_br_h2_5
    addi x9, x9, 1
fwd_br_h2_5:
    or x15, x27, x20
    remu x26, x15, x27
    c.addw x15, x14
    sd x15, 200(x2)
    xor x29, x31, x14
    slli x18, x10, 3
    sh x29, 86(x2)
    c.or x11, x15
    rem x17, x25, x5
    slli x31, x17, 41
    sraw x16, x29, x31
    divu x15, x31, x23
    or x12, x18, x16
    divuw x18, x5, x12
    sllw x22, x18, x14
    sb x22, -200(x2)
    sb x10, -117(x2)
    lw x30, -344(x2)
    sb x22, -173(x2)
    addw x4, x30, x25
    sltiu x4, x8, 850
    srlw x21, x11, x8
    sw x17, 364(x2)
    addiw x25, x21, -22
    add x9, x25, x4
    srlw x8, x31, x26
    srli x18, x8, 37
    ori x18, x7, -1143
    c.or x11, x10
    slliw x22, x20, 7
    sb x22, -314(x2)
    mulw x30, x8, x24
    sltu x30, x21, x20
    subw x26, x27, x18
    bltu x20, x26, fwd_br_h2_6
    addi x26, x26, 1
fwd_br_h2_6:
    addw x31, x31, x27
    subw x25, x8, x31
    mulhsu x23, x17, x30
    srli x19, x23, 41
    ori x15, x19, -677
    xori x10, x17, -585
    lwu x16, -124(x2)
    bge x13, x19, fwd_br_h2_7
    addi x25, x25, 1
fwd_br_h2_7:
    addi x10, x27, 233
    slliw x11, x10, 15
    c.xor x12, x10
    divu x11, x12, x27
    addiw x21, x11, 1187
    slt x14, x13, x14
    blt x20, x5, fwd_br_h2_8
    addi x17, x17, 1
fwd_br_h2_8:
    add x18, x21, x25
    div x11, x14, x18
    bne x16, x19, fwd_br_h2_9
    addi x31, x31, 1
fwd_br_h2_9:
    xori x29, x6, -508
    remu x29, x6, x23
    mul x8, x29, x29
    sraiw x28, x19, 17
    srlw x11, x17, x28
    sw x8, -176(x2)
    mulhu x30, x11, x16
    mulhsu x22, x29, x30
    slti x23, x17, 293
    c.xor x14, x15
    c.add x11, x15
    lw x16, -460(x2)
    srli x24, x16, 21
    ori x4, x16, 925
    mul x22, x24, x19
    srliw x30, x21, 24
    c.or x14, x10
    sh x24, -4(x2)
    lwu x31, -20(x2)
    c.addw x13, x10
    rem x28, x31, x16
    rem x5, x13, x31
    sraw x13, x5, x30
    ori x13, x4, 1935
    mul x22, x19, x13
    c.or x8, x13
    bltu x27, x21, fwd_br_h2_10
    addi x6, x6, 1
fwd_br_h2_10:
    blt x28, x21, fwd_br_h2_11
    addi x6, x6, 1
fwd_br_h2_11:
    srai x19, x5, 43
    slliw x15, x19, 28
    remuw x19, x15, x28
    lhu x6, 342(x2)
    c.xor x14, x12
    add x21, x10, x28
    sltiu x20, x21, 1607
    sllw x30, x21, x20
    ori x14, x30, 1776
    sd x14, -8(x2)
    srai x7, x10, 15
    divw x14, x16, x28
    or x15, x7, x4
    remw x24, x27, x17
    c.addw x14, x14
    srliw x20, x27, 19
    sub x30, x14, x21
    lhu x16, 178(x2)
    mulhu x8, x30, x16
    mulw x8, x20, x8
    slliw x15, x8, 7
    c.and x15, x14
    c.sub x11, x15
    slt x4, x15, x24
    addiw x11, x4, 470
    sltiu x22, x11, -2027
    slt x29, x11, x18
    c.addi x10, 25
    remu x5, x10, x20
    div x7, x5, x5
    sw x5, 208(x2)
    mulw x18, x25, x23
    div x6, x6, x18
    sh x6, 374(x2)
    sltiu x13, x23, -602
    slti x28, x17, -201
    srliw x26, x8, 31
    addw x30, x28, x25
    rem x28, x30, x5
    slt x13, x6, x22
    ori x23, x28, 719
    sll x4, x23, x25
    slti x6, x4, -190
    addi x10, x20, 272
    remuw x8, x10, x12
    sh x21, -6(x2)
    slliw x5, x18, 30
    bne x19, x5, fwd_br_h2_12
    addi x6, x6, 1
fwd_br_h2_12:
    and x26, x24, x22
    lb x30, 278(x2)
    sh x30, 258(x2)
    sh x14, 84(x2)
    add x27, x30, x8
    sw x30, 48(x2)
    blt x28, x27, fwd_br_h2_13
    addi x6, x6, 1
fwd_br_h2_13:
    srli x28, x6, 20
    sltiu x15, x28, -937
    slt x26, x5, x14
    remu x9, x9, x8
    and x21, x9, x22
    sraiw x27, x21, 7
    bgeu x21, x15, fwd_br_h2_14
    addi x7, x7, 1
fwd_br_h2_14:
    srl x5, x18, x9
    sltu x21, x5, x11
    ori x12, x15, 1064
    c.xor x12, x8
    slti x22, x22, -1003
    mulhsu x21, x19, x22
    srai x9, x22, 54
    xori x22, x9, -265
    c.add x9, x11
    srliw x12, x22, 24
    remuw x24, x8, x15
    xor x9, x24, x8
    mul x25, x9, x14
    remu x21, x25, x30
    sw x21, 404(x2)
    srliw x27, x12, 11
    srliw x28, x27, 14
    remu x29, x30, x7
    slli x20, x28, 53
    srai x28, x20, 4
    srai x20, x28, 35
    ori x19, x20, 1461
    subw x29, x19, x28
    sraw x17, x8, x23
    slti x10, x11, -1059
    rem x18, x10, x12
    remw x18, x18, x25
    sltiu x21, x18, -1581
    srliw x7, x12, 26
    ori x8, x21, -1760
    c.or x12, x15
    lb x13, 237(x2)
    beq x17, x4, fwd_br_h2_15
    addi x27, x27, 1
fwd_br_h2_15:
    sltiu x12, x4, 518
    c.addi x8, 23
    sb x12, 464(x2)
    remuw x4, x26, x17
    c.addw x8, x13
    srlw x31, x17, x8
    sll x5, x31, x21
    addi x20, x31, -968
    c.addw x14, x12
    addw x21, x4, x14
    lb x22, 133(x2)
    lw x21, 268(x2)
    lwu x9, -240(x2)
    sllw x25, x21, x24
    blt x9, x27, fwd_br_h2_16
    addi x17, x17, 1
fwd_br_h2_16:
    srliw x25, x18, 27
    remuw x6, x20, x25
    remuw x23, x25, x9
    remuw x30, x23, x27
    addiw x30, x30, 1168
    div x29, x11, x30
    sltiu x19, x30, 646
    slliw x14, x4, 28
    mul x9, x7, x4
    mulw x31, x25, x9
    slti x24, x21, -1078
    and x17, x29, x24
    c.addw x9, x11
    remu x31, x9, x31
    srli x8, x9, 37
    lw x4, 328(x2)
    sh x8, -472(x2)
    sraiw x24, x14, 27
    lhu x14, 342(x2)
    sraiw x11, x24, 30
    remu x29, x11, x25
    blt x11, x10, fwd_br_h2_17
    addi x5, x5, 1
fwd_br_h2_17:
    remw x12, x6, x10
    lh x20, -178(x2)
    c.and x11, x8
    divw x19, x11, x28
    xor x10, x19, x29
    sub x12, x19, x22
    ori x31, x19, -778
    remu x19, x31, x20
    addw x9, x28, x12
    addi x28, x29, -7
    ori x29, x30, -1896
    mulw x29, x29, x8
    add x10, x29, x27
    c.mv x11, x10
    srliw x24, x10, 31
    lbu x16, 33(x2)
    remuw x20, x16, x15
    bgeu x20, x25, fwd_br_h2_18
    addi x11, x11, 1
fwd_br_h2_18:
    sltiu x23, x22, 125
    sra x9, x28, x23
    sllw x5, x9, x4
    sraiw x28, x26, 4
    slti x18, x5, 1748
    bgeu x24, x18, fwd_br_h2_19
    addi x25, x25, 1
fwd_br_h2_19:
    lb x24, 347(x2)
    slliw x5, x13, 12
    remuw x10, x25, x5
    bge x23, x19, fwd_br_h2_20
    addi x15, x15, 1
fwd_br_h2_20:
    c.mv x27, x15
    slli x13, x18, 1
    remw x26, x14, x21
    sltu x16, x26, x7
    divuw x8, x16, x25
    mulhu x28, x8, x13
    and x18, x17, x28
    slti x22, x25, 575
    addw x12, x22, x20
    sll x7, x10, x24
    remu x12, x25, x7
    c.addi x15, -30
    srai x4, x12, 47
    sltiu x24, x6, -1875
    xori x8, x29, 48
    sltu x6, x8, x29
    sub x29, x6, x10
    addiw x15, x20, 1393
    divu x30, x5, x25
    c.and x8, x8
    srliw x14, x8, 12
    slli x9, x19, 38
    blt x9, x17, fwd_br_h2_21
    addi x12, x12, 1
fwd_br_h2_21:
    bltu x23, x6, fwd_br_h2_22
    addi x11, x11, 1
fwd_br_h2_22:
    slt x26, x20, x20
    mul x15, x6, x15
    sra x27, x10, x22
    srliw x19, x24, 8
    sraiw x29, x19, 30
    c.addw x11, x9
    xori x6, x8, -1648
    sd x6, 0(x2)
    remuw x31, x15, x26
    slliw x26, x5, 11
    mulw x18, x26, x22
    xori x7, x18, 1242
    slliw x30, x18, 24
    sw x12, -512(x2)
    srliw x4, x15, 29
    c.and x9, x12
    c.xor x11, x11
    subw x26, x11, x25
    addi x5, x26, -748
    divu x13, x8, x5
    lwu x26, 72(x2)
    lbu x6, 376(x2)
    div x9, x26, x30
    lw x25, -128(x2)
    c.add x12, x9
    sraiw x6, x15, 27
    sll x7, x12, x6
    slliw x13, x7, 23
    slt x26, x26, x19
    sraw x26, x26, x4
    srlw x8, x26, x20
    srl x11, x12, x19
    sb x11, -237(x2)
    addi x25, x25, -789
    divu x25, x16, x25
    lbu x30, -501(x2)
    sra x17, x30, x5
    remuw x18, x21, x17
    remw x31, x4, x18
    sh x31, 234(x2)
    mulhsu x24, x4, x20
    sub x14, x18, x24
    sh x14, -294(x2)
    addw x30, x24, x18
    sll x18, x18, x11
    sllw x16, x18, x20
    sh x18, 384(x2)
    mulhsu x30, x29, x21
    sb x30, 266(x2)
    sltu x21, x25, x26
    sh x21, 172(x2)
    srai x14, x5, 53
    srliw x10, x16, 16
    divw x22, x10, x21
    srlw x11, x11, x22
    sw x22, 36(x2)
    srai x8, x16, 44
    mulh x29, x22, x14
    addi x23, x29, -176
    rem x28, x12, x23
    sub x27, x30, x28
    sb x15, 163(x2)
    addiw x21, x10, 409
    remw x16, x15, x21
    sub x6, x16, x7
    srliw x4, x15, 2
    or x19, x4, x5
    srli x23, x19, 11
    mulhu x17, x23, x22
    divw x16, x14, x17
    srli x18, x17, 32
    srlw x16, x18, x5
    remu x5, x20, x16
    c.mv x11, x5
    slliw x14, x11, 24
    andi x8, x11, -6
    andi x13, x13, 1021
    sraw x22, x12, x13
    slt x13, x14, x22
    c.addi x12, 1
    srliw x27, x7, 13
    sraw x16, x27, x13
    lwu x26, 268(x2)
    div x14, x6, x26
    slti x20, x14, 1510
    mulhu x12, x20, x8
    sltu x9, x12, x31
    c.addi x12, -18
    divuw x18, x30, x11
    sltu x18, x18, x28
    srlw x17, x18, x23
    beq x26, x24, fwd_br_h2_23
    addi x11, x11, 1
fwd_br_h2_23:
    slti x19, x10, 1575
    andi x20, x19, 1960
    lh x13, 260(x2)
    add x28, x13, x29
    c.addi x15, 16
    bltu x26, x21, fwd_br_h2_24
    addi x26, x26, 1
fwd_br_h2_24:
    slli x30, x15, 48
    divu x4, x7, x23
    blt x18, x14, fwd_br_h2_25
    addi x28, x28, 1
fwd_br_h2_25:
    and x8, x8, x7
    sltu x28, x8, x9
    c.xor x12, x13
    rem x27, x12, x25
    c.addw x11, x15
    c.add x9, x9
    c.add x15, x9
    mulhsu x21, x15, x27
    lw x28, -20(x2)
    bge x5, x21, fwd_br_h2_26
    addi x17, x17, 1
fwd_br_h2_26:
    and x27, x28, x19
    addi x15, x22, 1406
    sltiu x31, x27, -1978
    sltiu x11, x31, 1502
    remu x30, x30, x16
    mulhu x10, x30, x6
    slli x19, x30, 7
    mulhsu x14, x30, x26
    sltu x4, x14, x18
    lbu x17, -186(x2)
    slliw x9, x4, 13
    mulh x4, x25, x9
    sltu x31, x9, x7
    sltiu x7, x10, -707
    lhu x8, -356(x2)
    sraw x29, x8, x28
    srai x14, x12, 10
    xori x15, x16, -1842
    xori x12, x15, 1619
    sltiu x25, x12, -265
    sltiu x29, x12, 471
    sw x25, 264(x2)
    c.addw x12, x10
    slliw x12, x11, 24
    mulhsu x18, x20, x29
    xor x25, x18, x18
    mulhu x26, x20, x25
    srl x12, x29, x5
    sra x23, x11, x6
    addw x12, x23, x5
    addi x21, x14, -1249
    sraw x18, x21, x21
    rem x10, x18, x22
    andi x29, x10, -942
    andi x5, x10, -2041
    xor x9, x16, x14
    divuw x20, x30, x27
    remu x20, x7, x15
    c.mv x19, x19
    c.sub x8, x14
    srli x7, x8, 21
    mulw x25, x8, x5
    lh x8, 494(x2)
    addw x11, x8, x29
    sraw x17, x26, x24
    slt x18, x18, x15
    bgeu x11, x18, fwd_br_h2_27
    addi x14, x14, 1
fwd_br_h2_27:
    addiw x17, x18, 1452
    addiw x9, x17, -876
    remw x25, x19, x21
    c.add x12, x13
    and x30, x12, x17
    slli x22, x30, 59
    blt x22, x6, fwd_br_h2_28
    addi x17, x17, 1
fwd_br_h2_28:
    lw x21, -412(x2)
    divu x16, x27, x21
    sraw x7, x16, x16
    sra x13, x16, x7
    addiw x11, x31, 1567
    sll x6, x19, x11
    bge x6, x12, fwd_br_h2_29
    addi x9, x9, 1
fwd_br_h2_29:
    srai x5, x8, 26
    sw x19, -232(x2)
    srlw x24, x19, x11
    sraw x20, x24, x30
    sll x29, x24, x29
    srliw x23, x20, 25
    bne x23, x30, fwd_br_h2_30
    addi x8, x8, 1
fwd_br_h2_30:
    sb x4, -366(x2)
    sltu x24, x30, x31
    add x24, x24, x17
    sub x29, x24, x13
    bge x8, x27, fwd_br_h2_31
    addi x11, x11, 1
fwd_br_h2_31:
    divw x19, x26, x24
    remuw x12, x10, x19
    lhu x15, 138(x2)
    or x15, x15, x27
    and x28, x16, x30
    blt x21, x5, fwd_br_h2_32
    addi x30, x30, 1
fwd_br_h2_32:
    srliw x11, x28, 13
    mulhsu x27, x8, x29
    sltu x12, x27, x9
    mul x14, x30, x12
    c.and x15, x13
    remuw x18, x15, x10
    mul x21, x18, x8
    div x12, x21, x20
    mulhu x7, x12, x15
    divuw x27, x26, x7
    lwu x13, 8(x2)
    or x27, x20, x7
    lb x6, -141(x2)
    mulhsu x8, x6, x23
    addw x16, x25, x22
    c.xor x14, x15
    divu x20, x4, x26
    sraiw x16, x14, 12
    slliw x6, x16, 30
    sw x10, -208(x2)
    remw x27, x26, x26
    remu x22, x9, x27
    sltu x29, x23, x27
    addiw x5, x15, 1848
    c.sub x14, x8
    slli x13, x14, 37
    subw x26, x8, x13
    mulh x24, x13, x21
    sw x18, 384(x2)
    sb x8, 247(x2)
    c.or x13, x14
    add x18, x12, x13
    srliw x31, x11, 16
    and x27, x31, x28
    bgeu x27, x4, fwd_br_h2_33
    addi x11, x11, 1
fwd_br_h2_33:
    lbu x8, 202(x2)
    addiw x24, x7, 1299
    bgeu x8, x4, fwd_br_h2_34
    addi x8, x8, 1
fwd_br_h2_34:
    subw x15, x17, x23
    srlw x16, x17, x17
    and x25, x19, x14
    sub x11, x25, x10
    slti x31, x12, 1702
    sra x16, x31, x12
    c.or x13, x14
    addw x19, x4, x13
    srli x19, x19, 12
    c.sub x15, x10
    mulhsu x25, x15, x26
    sraiw x11, x15, 24
    addw x13, x11, x25
    ori x17, x13, -689
    addw x17, x4, x17
    sraw x15, x17, x6
    slli x21, x30, 6
    bne x5, x12, fwd_br_h2_35
    addi x10, x10, 1
fwd_br_h2_35:
    c.or x10, x11
    subw x19, x4, x5
    mul x9, x19, x4
    mulw x5, x19, x13
    srl x21, x10, x8
    sltiu x22, x21, 138
    addw x16, x22, x20
    mulh x24, x9, x12
    blt x31, x24, fwd_br_h2_36
    addi x6, x6, 1
fwd_br_h2_36:
    srliw x17, x18, 26
    addw x20, x18, x7
    sraiw x17, x20, 30
    lhu x20, 108(x2)
    c.and x8, x15
    remu x26, x19, x16
    addiw x13, x4, -1417
    addw x28, x22, x13
    c.or x8, x15
    mulhsu x11, x14, x24
    bne x8, x7, fwd_br_h2_37
    addi x31, x31, 1
fwd_br_h2_37:
    divuw x12, x30, x12
    sraw x29, x31, x16
    c.addi x14, 9
    lbu x9, -87(x2)
    c.addi x8, -17
    remw x28, x9, x13
    sub x31, x18, x23
    addiw x16, x28, 1289
    xor x19, x14, x16
    srl x23, x9, x17
    c.add x11, x14
    addi x31, x23, 760
    bne x31, x26, fwd_br_h2_38
    addi x15, x15, 1
fwd_br_h2_38:
    sb x6, 340(x2)
    lbu x30, 134(x2)
    c.sub x11, x15
    srlw x6, x11, x15
    lhu x13, -502(x2)
    addiw x6, x13, 1492
    ori x11, x17, -955
    andi x10, x11, 1467
    srliw x14, x16, 16
    addi x17, x25, -1397
    lwu x12, 504(x2)
    xori x24, x12, 1625
    sll x29, x24, x13
    sw x25, -192(x2)
    andi x6, x17, 1640
    slli x28, x17, 5
    sub x28, x6, x14
    c.add x15, x15
    blt x15, x6, fwd_br_h2_39
    addi x30, x30, 1
fwd_br_h2_39:
    addw x26, x12, x26
    bne x26, x9, fwd_br_h2_40
    addi x21, x21, 1
fwd_br_h2_40:
    addw x16, x21, x8
    div x10, x7, x6
    mulhsu x6, x16, x17
    srlw x11, x6, x10
    sltiu x9, x11, -396
    srai x31, x9, 54
    sh x9, 220(x2)
    add x11, x18, x28
    c.and x13, x13
    lhu x21, -156(x2)
    c.or x8, x14
    srai x15, x21, 25
    srlw x8, x16, x15
    subw x12, x8, x22
    blt x5, x26, fwd_br_h2_41
    addi x6, x6, 1
fwd_br_h2_41:
    divu x13, x12, x15
    srlw x20, x13, x17
    add x21, x13, x10
    lw x22, 360(x2)
    sw x21, 84(x2)
    lhu x17, -474(x2)
    blt x17, x18, fwd_br_h2_42
    addi x9, x9, 1
fwd_br_h2_42:
    c.add x8, x13
    sraiw x10, x14, 24
    ori x28, x18, 1604
    lbu x14, -404(x2)
    and x7, x26, x4
    mulw x29, x7, x26
    c.and x11, x10
    bltu x11, x14, fwd_br_h2_43
    addi x18, x18, 1
fwd_br_h2_43:
    srli x18, x26, 61
    sll x8, x11, x18
    mulh x6, x27, x8
    rem x5, x31, x6
    lhu x22, 136(x2)
    blt x28, x22, fwd_br_h2_44
    addi x8, x8, 1
fwd_br_h2_44:
    mulhsu x15, x15, x10
    addi x14, x20, -874
    addiw x28, x15, -268
    lwu x24, -448(x2)
    bgeu x16, x5, fwd_br_h2_45
    addi x7, x7, 1
fwd_br_h2_45:
    lw x20, -72(x2)
    addi x6, x9, -805
    sw x16, -404(x2)
    slliw x28, x6, 10
    srlw x29, x28, x18
    and x17, x29, x9
    or x7, x12, x27
    srliw x6, x7, 15
    ori x30, x6, -1042
    bne x30, x29, fwd_br_h2_46
    addi x23, x23, 1
fwd_br_h2_46:
    slt x24, x25, x27
    addw x19, x6, x24
    slti x9, x29, 479
    divu x27, x9, x13
    div x9, x27, x5
    sltiu x29, x27, -46
    sltiu x23, x29, 155
    slt x4, x10, x13
    sd x4, 384(x2)
    remuw x15, x23, x22
    mulw x4, x15, x14
    mul x19, x4, x30
    sltu x4, x19, x6
    sw x13, -384(x2)
    srliw x15, x31, 10
    lw x24, -36(x2)
    rem x25, x15, x13
    slti x15, x26, 504
    xor x29, x29, x15
    divuw x12, x24, x29
    c.xor x10, x15
    and x24, x30, x16
    sh x24, 150(x2)
    divu x6, x24, x30
    slti x19, x6, -314
    ori x29, x19, -672
    andi x16, x19, -304
    add x7, x5, x16
    lb x23, -135(x2)
    mul x9, x4, x28
    and x8, x7, x9
    divw x4, x4, x31
    slt x23, x16, x28
    bne x29, x23, fwd_br_h2_47
    addi x19, x19, 1
fwd_br_h2_47:
    ori x13, x23, -773
    xori x22, x13, 22
    c.or x8, x12
    bne x18, x21, fwd_br_h2_48
    addi x25, x25, 1
fwd_br_h2_48:
    slliw x31, x5, 9
    or x26, x31, x22
    remu x17, x26, x20
    sraw x22, x17, x28
    slli x8, x4, 62
    remuw x17, x8, x22
    bge x18, x17, fwd_br_h2_49
    addi x19, x19, 1
fwd_br_h2_49:
    mul x21, x24, x13
    srliw x16, x21, 11
    sltiu x15, x25, 340
    slliw x4, x19, 7
    addiw x13, x7, 913
    addw x5, x11, x9
    c.addi x14, 1
    slti x16, x14, 1881
    addiw x4, x17, -1327
    c.xor x9, x12
    slt x6, x9, x21
    subw x16, x9, x13
    sraw x24, x17, x4
    sraiw x31, x24, 16
    ori x20, x31, 491
    sw x20, 40(x2)
    sllw x11, x27, x31
    sw x11, 76(x2)
    srliw x24, x11, 5
    lb x27, -291(x2)
    sh x27, -348(x2)
    andi x18, x17, 1194
    srli x18, x18, 54
    xori x26, x18, 593
    remw x21, x19, x17
    lh x26, -186(x2)
    subw x26, x29, x26
    c.addi x13, -6
    xori x20, x26, 1772
    or x15, x20, x11
    sraiw x7, x25, 31
    sra x15, x27, x23
    sub x15, x15, x12
    sltu x20, x28, x17
    c.addi x10, 1
    srlw x7, x20, x30
    slli x8, x24, 0
    sra x18, x7, x17
    add x12, x18, x25
    sra x16, x18, x7
    srli x20, x31, 23
    sraiw x28, x16, 20
    c.sub x11, x13
    mulhu x21, x19, x11
    mulhu x15, x28, x21
    addiw x13, x21, -1879
    c.add x8, x11
    sra x28, x9, x5
    blt x28, x23, fwd_br_h2_50
    addi x25, x25, 1
fwd_br_h2_50:
    lwu x21, -368(x2)
    bltu x11, x25, fwd_br_h2_51
    addi x10, x10, 1
fwd_br_h2_51:
    addi x7, x30, 185
    add x29, x7, x22
    bne x29, x27, fwd_br_h2_52
    addi x13, x13, 1
fwd_br_h2_52:
    sll x5, x15, x18
    sllw x24, x5, x5
    slliw x26, x20, 6
    sub x8, x7, x16
    slli x30, x26, 31
    sllw x21, x8, x5
    sltiu x31, x24, 1359
    beq x21, x14, fwd_br_h2_53
    addi x15, x15, 1
fwd_br_h2_53:
    remu x5, x23, x5
    bgeu x18, x20, fwd_br_h2_54
    addi x15, x15, 1
fwd_br_h2_54:
    lw x28, -468(x2)
    andi x29, x28, -1054
    c.or x14, x13
    addiw x29, x14, -1756
    mulh x18, x23, x29
    c.and x8, x11
    mulh x24, x23, x8
    sraiw x28, x6, 16
    mulh x29, x24, x21
    mulhsu x23, x28, x31
    srliw x14, x29, 13
    rem x26, x14, x19
    c.xor x13, x10
    addi x27, x26, 1692
    mulhu x15, x25, x27
    sltu x24, x17, x15
    sra x21, x24, x24
    srli x25, x21, 4
    slliw x6, x15, 2
    slliw x8, x9, 11
    sltiu x19, x27, -532
    divuw x14, x19, x14
    sb x19, -367(x2)
    subw x8, x10, x16
    sraw x12, x8, x27
    addiw x26, x16, -1227
    divuw x26, x11, x26
    sh x24, -184(x2)
    c.or x14, x9
    sh x14, 118(x2)
    ld x10, -8(x2)
    or x31, x10, x23
    beq x8, x31, fwd_br_h2_55
    addi x29, x29, 1
fwd_br_h2_55:
    addiw x10, x30, -970
    mulhu x5, x26, x10
    srlw x10, x5, x4
    sd x26, -264(x2)
    mulhsu x12, x18, x21
    sra x27, x22, x12
    lhu x31, 432(x2)
    beq x27, x27, fwd_br_h2_56
    addi x5, x5, 1
fwd_br_h2_56:
    andi x12, x6, 784
    xori x30, x10, -974
    divu x18, x12, x11
    and x4, x23, x16
    sw x4, 96(x2)
    addiw x8, x9, 1949
    srli x22, x14, 13
    subw x14, x8, x8
    remuw x24, x14, x6
    rem x4, x24, x14
    bge x4, x16, fwd_br_h2_57
    addi x30, x30, 1
fwd_br_h2_57:
    sh x18, 284(x2)
    addi x8, x28, -1286
    remuw x23, x18, x31
    srai x13, x10, 55
    rem x16, x13, x21
    remu x23, x28, x11
    sub x19, x15, x23
    bne x13, x25, fwd_br_h2_58
    addi x11, x11, 1
fwd_br_h2_58:
    c.or x13, x13
    addw x12, x13, x7
    divuw x15, x12, x5
    xor x24, x15, x22
    sllw x18, x8, x24
    sraw x20, x18, x19
    sb x20, 407(x2)
    bgeu x20, x8, fwd_br_h2_59
    addi x18, x18, 1
fwd_br_h2_59:
    beq x14, x28, fwd_br_h2_60
    addi x4, x4, 1
fwd_br_h2_60:
    addi x7, x31, -905
    sll x21, x18, x7
    remw x31, x15, x8
    lw x14, -216(x2)
    sh x31, -180(x2)
    mulhsu x19, x14, x18
    srlw x24, x30, x12
    divw x21, x24, x18
    ld x24, -216(x2)
    srlw x18, x18, x24
    srliw x18, x18, 31
    sraw x22, x29, x8
    mulw x13, x24, x22
    divuw x31, x22, x20
    c.and x15, x9
    divu x9, x5, x15
    addw x19, x29, x16
    bge x27, x31, fwd_br_h2_61
    addi x14, x14, 1
fwd_br_h2_61:
    sraw x19, x19, x26
    andi x12, x12, -297
    sltu x9, x12, x23
    c.xor x10, x13
    srl x29, x31, x4
    and x31, x29, x13
    c.sub x8, x14
    mulhu x22, x10, x9
    xor x8, x22, x18
    sb x8, -19(x2)
    or x10, x9, x18
    slliw x24, x28, 15
    xori x21, x11, 690
    andi x17, x23, -1924
    srliw x7, x21, 5
    divuw x12, x9, x17
    subw x29, x7, x25
    bge x29, x7, fwd_br_h2_62
    addi x28, x28, 1
fwd_br_h2_62:
    lwu x23, 240(x2)
    sub x14, x20, x5
    lh x27, 206(x2)
    sw x27, -460(x2)
    slti x10, x26, -1451
    sllw x13, x10, x28
    mul x15, x13, x7
    remuw x26, x15, x6
    sra x6, x20, x26
    c.add x8, x12
    srai x26, x27, 63
    lh x16, 412(x2)
    mulhu x5, x16, x22
    lwu x18, -364(x2)
    divuw x7, x7, x12
    or x28, x11, x7
    c.or x10, x13
    sllw x29, x21, x10
    srli x18, x29, 25
    sll x25, x14, x6
    xor x29, x25, x19
    srlw x19, x10, x4
    xor x31, x19, x20
    or x26, x31, x27
    addw x28, x6, x10
    slli x13, x26, 12
    mul x28, x16, x26
    c.and x14, x13
    srai x20, x26, 61
    beq x14, x17, fwd_br_h2_63
    addi x13, x13, 1
fwd_br_h2_63:
    addw x27, x24, x27
    rem x13, x7, x30
    lwu x29, 84(x2)
    lwu x21, 356(x2)
    divw x6, x21, x22
    srlw x7, x6, x21
    srlw x19, x6, x4
    sraw x23, x28, x19
    slliw x29, x24, 26
    ori x24, x27, -717
    ori x21, x25, -1422
    slli x28, x21, 36
    subw x29, x8, x30
    remu x28, x28, x5
    sb x29, -76(x2)
    remu x14, x12, x10
    mulhsu x20, x9, x6
    c.addi x13, -27
    sraiw x20, x26, 27
    divu x23, x20, x17
    divuw x26, x26, x15
    sllw x10, x9, x26
    sltiu x19, x26, -1733
    srliw x22, x10, 11
    slliw x18, x22, 2
    sllw x16, x18, x30
    sltu x23, x23, x16
    lw x27, -76(x2)
    c.and x9, x14
    andi x6, x17, 303
    sb x29, -58(x2)
    c.addi x13, 28
    c.xor x10, x8
    sll x18, x10, x4
    xor x4, x18, x24
    c.add x9, x8
    bgeu x13, x7, fwd_br_h2_64
    addi x10, x10, 1
fwd_br_h2_64:
    /* --- END RANDOM INSTRUCTION BLOCK FOR HART 2 --- */
    addi x1, x1, -1
    bnez x1, .Lloop_hart2

    /* Hart 2 finished: store completion token */
    la   t1, h2_done
    li   t2, 0xCAFEBABE
    sd   t2, 0(t1)

    /* Secondary hart enters low-power sleep */
.Ldone_sleep_h2:
    wfi
    j    .Ldone_sleep_h2

/* ========================================================================= */
/* HART 3 EXECUTION STREAM                                                */
/* ========================================================================= */
.Lentry_hart3:
    /* Set up private scratchpad memory base pointer in x2 */
    la   x2, scratch_h3
    addi x2, x2, 2047
    addi x2, x2, 1

    /* Preload diverse corner values into registers x4..x31 */
    li   x4, 0x1
    li   x5, 0x2
    li   x6, 0xfffffffffffffffe
    li   x7, 0x3f
    li   x8, 0x1f
    li   x9, 0x123456789abcdef0
    li   x10, 0xdeadbeefcafebabe
    li   x11, 0x0
    li   x12, 0xffffffffffffffff
    li   x13, 0x7fffffffffffffff
    li   x14, 0x8000000000000000
    li   x15, 0x7fffffff
    li   x16, 0xffffffff80000000
    li   x17, 0xffffffff
    li   x18, 0x5555555555555555
    li   x19, 0xaaaaaaaaaaaaaaaa
    li   x20, 0x1
    li   x21, 0x2
    li   x22, 0xfffffffffffffffe
    li   x23, 0x3f
    li   x24, 0x1f
    li   x25, 0x123456789abcdef0
    li   x26, 0xdeadbeefcafebabe
    li   x27, 0x0
    li   x28, 0xffffffffffffffff
    li   x29, 0x7fffffffffffffff
    li   x30, 0x8000000000000000
    li   x31, 0x7fffffff

    /* Preload private scratchpad with initial deterministic data */
    li   x1, 0x3456789abcdf0122
    sd   x1, -512(x2)
    addi x1, x1, 0x111
    sd   x1, -384(x2)
    addi x1, x1, 0x111
    sd   x1, -256(x2)
    addi x1, x1, 0x111
    sd   x1, -128(x2)
    addi x1, x1, 0x111
    sd   x1, 0(x2)
    addi x1, x1, 0x111
    sd   x1, 128(x2)
    addi x1, x1, 0x111
    sd   x1, 256(x2)
    addi x1, x1, 0x111
    sd   x1, 384(x2)
    addi x1, x1, 0x111

    /* Initialize loop counter in x1 */
    li   x1, 25
.Lloop_hart3:
    /* --- BEGIN RANDOM INSTRUCTION BLOCK FOR HART 3 --- */
    div x18, x4, x23
    bge x24, x18, fwd_br_h3_0
    addi x18, x18, 1
fwd_br_h3_0:
    c.add x13, x10
    divuw x25, x13, x25
    div x20, x25, x13
    mul x29, x20, x13
    addiw x15, x20, 1271
    mul x10, x29, x12
    subw x15, x15, x14
    srli x18, x31, 4
    addi x31, x18, -103
    sraw x26, x4, x12
    sraiw x17, x26, 28
    sltiu x12, x17, 944
    c.add x14, x11
    blt x22, x14, fwd_br_h3_1
    addi x20, x20, 1
fwd_br_h3_1:
    srliw x9, x31, 22
    addw x10, x9, x19
    addi x17, x9, 736
    divu x16, x17, x29
    srlw x12, x16, x18
    bltu x12, x13, fwd_br_h3_2
    addi x9, x9, 1
fwd_br_h3_2:
    addiw x28, x14, 70
    divuw x14, x4, x21
    sh x14, 340(x2)
    subw x13, x17, x31
    or x5, x6, x8
    bltu x7, x31, fwd_br_h3_3
    addi x8, x8, 1
fwd_br_h3_3:
    sllw x28, x8, x22
    srliw x14, x22, 30
    slti x20, x14, -1666
    srliw x31, x23, 13
    srlw x6, x31, x7
    mulh x15, x6, x26
    sh x15, 448(x2)
    remuw x25, x28, x24
    slli x18, x25, 12
    addiw x31, x30, 1856
    bgeu x31, x14, fwd_br_h3_4
    addi x27, x27, 1
fwd_br_h3_4:
    lhu x22, -394(x2)
    divu x5, x15, x7
    xori x5, x22, 79
    lbu x5, 190(x2)
    mulh x25, x8, x5
    mulw x24, x5, x14
    divuw x7, x26, x24
    addi x17, x7, 512
    and x12, x17, x30
    c.addi x12, 14
    addw x25, x12, x9
    mul x26, x25, x14
    sub x9, x31, x16
    sb x26, 112(x2)
    mulh x29, x19, x29
    sb x28, -415(x2)
    c.mv x10, x28
    subw x11, x28, x4
    lh x26, -368(x2)
    c.add x9, x12
    addiw x20, x9, 173
    srliw x15, x20, 12
    c.and x11, x12
    slti x8, x30, -97
    srai x12, x8, 53
    and x7, x6, x19
    addi x25, x4, 1838
    srli x24, x7, 47
    xor x18, x24, x12
    add x18, x18, x14
    c.addi x11, 22
    sh x11, 274(x2)
    sd x10, 336(x2)
    addw x11, x10, x14
    lw x4, 480(x2)
    c.sub x10, x15
    slli x22, x10, 36
    remuw x14, x22, x30
    xor x7, x14, x9
    srliw x31, x14, 27
    srai x8, x31, 5
    srli x26, x8, 31
    addw x22, x26, x5
    mul x26, x22, x9
    c.sub x14, x11
    sltu x21, x14, x13
    srliw x31, x21, 11
    srliw x13, x22, 19
    srliw x11, x31, 20
    bne x13, x7, fwd_br_h3_5
    addi x11, x11, 1
fwd_br_h3_5:
    mulw x24, x11, x19
    divw x14, x5, x24
    xor x12, x20, x28
    slti x15, x14, 532
    andi x22, x28, -1982
    remuw x11, x22, x17
    ori x17, x15, 1751
    sb x10, 459(x2)
    sllw x30, x20, x12
    divuw x4, x20, x15
    addw x20, x27, x23
    sw x20, 160(x2)
    slli x10, x24, 27
    slliw x7, x9, 9
    sb x26, 431(x2)
    sraiw x8, x21, 3
    sh x31, -284(x2)
    lh x26, 174(x2)
    rem x10, x20, x26
    mulhsu x14, x19, x16
    mulhu x26, x14, x9
    srliw x30, x10, 12
    sltiu x31, x15, 1150
    bne x31, x27, fwd_br_h3_6
    addi x28, x28, 1
fwd_br_h3_6:
    lbu x19, -228(x2)
    srliw x21, x25, 2
    c.addi x8, 1
    sh x24, -394(x2)
    addi x5, x29, 228
    addiw x6, x17, -1143
    remw x28, x6, x16
    bltu x6, x30, fwd_br_h3_7
    addi x6, x6, 1
fwd_br_h3_7:
    sw x23, -420(x2)
    or x29, x21, x10
    addiw x24, x21, -143
    addi x18, x24, -1891
    lb x7, 287(x2)
    sb x26, -87(x2)
    mulhsu x12, x29, x19
    c.and x13, x10
    sub x13, x24, x13
    sllw x23, x13, x7
    lbu x10, 174(x2)
    sllw x20, x23, x10
    sh x19, -246(x2)
    srai x28, x14, 15
    bge x28, x25, fwd_br_h3_8
    addi x31, x31, 1
fwd_br_h3_8:
    srliw x26, x17, 1
    slli x12, x26, 38
    remu x15, x30, x17
    sltiu x12, x19, -36
    or x23, x12, x28
    beq x26, x31, fwd_br_h3_9
    addi x25, x25, 1
fwd_br_h3_9:
    c.add x10, x14
    or x22, x7, x10
    remuw x10, x28, x5
    addw x29, x10, x10
    sltu x23, x15, x22
    srli x15, x23, 45
    c.addw x9, x11
    sh x15, 280(x2)
    c.addw x12, x13
    addw x5, x12, x17
    sd x28, -48(x2)
    and x8, x22, x18
    addiw x17, x16, -1012
    sw x28, -420(x2)
    addi x9, x7, 1194
    sltiu x9, x9, 922
    subw x30, x13, x9
    sub x19, x19, x30
    blt x19, x21, fwd_br_h3_10
    addi x7, x7, 1
fwd_br_h3_10:
    c.mv x21, x19
    lbu x18, 33(x2)
    sb x18, 353(x2)
    mulhsu x24, x14, x10
    xori x13, x24, 1066
    remu x9, x13, x20
    slli x20, x19, 1
    srl x11, x9, x26
    slti x19, x27, 1971
    addi x29, x19, 917
    c.addw x9, x14
    srlw x17, x26, x8
    lh x24, 80(x2)
    subw x28, x24, x14
    divw x6, x28, x27
    sraw x27, x23, x6
    bltu x6, x30, fwd_br_h3_11
    addi x9, x9, 1
fwd_br_h3_11:
    sw x20, -348(x2)
    c.add x14, x15
    divw x20, x14, x23
    c.sub x8, x12
    c.sub x9, x13
    add x10, x11, x9
    mulw x7, x31, x10
    blt x20, x31, fwd_br_h3_12
    addi x6, x6, 1
fwd_br_h3_12:
    or x14, x4, x19
    sltiu x5, x21, -1626
    c.addi x12, 4
    lbu x29, -328(x2)
    remw x10, x28, x29
    rem x5, x7, x10
    mulhsu x29, x25, x13
    sltiu x28, x26, -354
    bge x20, x9, fwd_br_h3_13
    addi x18, x18, 1
fwd_br_h3_13:
    sd x8, 40(x2)
    lwu x20, 480(x2)
    divw x7, x11, x20
    subw x12, x15, x24
    ld x10, -328(x2)
    sltiu x14, x10, -1423
    slli x4, x8, 16
    slt x12, x24, x23
    andi x5, x28, 416
    sw x29, -96(x2)
    mulhu x8, x27, x27
    divuw x27, x8, x7
    sllw x23, x27, x25
    mulhsu x28, x27, x21
    and x23, x23, x5
    div x10, x13, x8
    sb x27, 382(x2)
    lhu x21, 412(x2)
    remw x8, x22, x7
    sraiw x20, x31, 23
    sltu x29, x8, x12
    andi x9, x16, 445
    xori x9, x13, 1140
    div x8, x9, x17
    divu x31, x8, x8
    sllw x5, x31, x19
    lb x20, 193(x2)
    addw x26, x24, x4
    sll x9, x26, x7
    add x27, x9, x5
    xor x5, x27, x4
    add x5, x5, x26
    add x14, x5, x21
    lhu x17, 4(x2)
    ori x31, x14, 1335
    sltu x23, x31, x20
    bltu x30, x20, fwd_br_h3_14
    addi x5, x5, 1
fwd_br_h3_14:
    c.addw x15, x13
    sb x15, -443(x2)
    ld x26, -56(x2)
    sd x30, 48(x2)
    bltu x26, x22, fwd_br_h3_15
    addi x16, x16, 1
fwd_br_h3_15:
    div x28, x9, x17
    srl x12, x28, x31
    and x20, x18, x13
    lwu x28, -352(x2)
    lbu x8, -93(x2)
    divu x14, x8, x28
    and x22, x12, x21
    xor x20, x31, x22
    add x30, x19, x22
    lbu x12, -55(x2)
    addi x16, x28, 1652
    mulw x14, x20, x15
    add x18, x14, x13
    or x29, x18, x17
    addi x21, x25, -458
    addiw x4, x21, 1238
    ori x6, x4, -1496
    or x4, x19, x21
    slli x13, x6, 29
    sltiu x6, x23, 1600
    rem x10, x6, x25
    divw x28, x10, x26
    sltu x8, x6, x28
    or x28, x8, x18
    c.addw x12, x14
    lbu x27, 408(x2)
    sltu x21, x27, x24
    sltu x22, x21, x29
    rem x23, x22, x9
    ori x23, x23, 1317
    srliw x5, x16, 30
    slliw x10, x5, 29
    xor x5, x15, x29
    and x6, x10, x6
    or x27, x6, x26
    c.mv x27, x7
    bne x27, x24, fwd_br_h3_16
    addi x31, x31, 1
fwd_br_h3_16:
    c.addi x12, -12
    addiw x17, x19, 738
    sraiw x17, x20, 27
    mul x28, x17, x10
    srlw x25, x17, x5
    beq x25, x5, fwd_br_h3_17
    addi x14, x14, 1
fwd_br_h3_17:
    remw x22, x13, x28
    sb x28, 447(x2)
    mulh x23, x22, x19
    slt x16, x23, x22
    addw x12, x16, x25
    sw x8, -112(x2)
    c.add x8, x15
    subw x28, x8, x30
    remuw x4, x16, x6
    slli x29, x4, 41
    srliw x27, x5, 14
    lbu x27, -172(x2)
    sh x25, -22(x2)
    mulh x15, x13, x18
    sb x15, -278(x2)
    xor x6, x15, x21
    mulh x30, x21, x15
    mulhu x5, x27, x30
    blt x30, x24, fwd_br_h3_18
    addi x14, x14, 1
fwd_br_h3_18:
    mulhu x24, x5, x4
    sw x24, -104(x2)
    xori x30, x23, 1251
    mulw x4, x15, x19
    or x26, x19, x28
    rem x26, x21, x26
    slt x4, x26, x15
    lh x27, 82(x2)
    sraiw x10, x30, 28
    xor x9, x10, x30
    subw x17, x24, x9
    divuw x5, x8, x17
    slt x19, x10, x5
    addiw x15, x19, -1765
    sb x19, -76(x2)
    lwu x5, -152(x2)
    sraw x24, x17, x5
    remu x17, x15, x24
    mulhsu x12, x24, x23
    lbu x30, 366(x2)
    and x20, x30, x18
    div x6, x8, x27
    divuw x26, x6, x10
    and x13, x6, x13
    c.addw x9, x8
    mulhsu x17, x9, x7
    sraiw x24, x9, 31
    slliw x31, x17, 17
    and x17, x31, x11
    lbu x29, 403(x2)
    rem x18, x29, x7
    ori x18, x18, -1776
    mulw x28, x13, x18
    srli x4, x10, 59
    mulh x28, x28, x16
    addw x17, x28, x22
    sltiu x8, x28, 1487
    sll x29, x26, x8
    divw x19, x26, x27
    sh x19, -328(x2)
    c.or x11, x8
    sra x21, x11, x14
    addiw x8, x31, -1222
    srai x16, x9, 36
    xor x26, x29, x12
    lhu x18, 380(x2)
    lh x4, 108(x2)
    srlw x12, x4, x28
    xori x18, x12, 2000
    and x23, x12, x21
    sll x5, x29, x25
    sh x5, 102(x2)
    srliw x21, x11, 16
    sh x21, 100(x2)
    srli x6, x23, 25
    mulw x23, x31, x30
    sh x23, 328(x2)
    slti x30, x23, -1321
    srlw x24, x30, x11
    mulh x7, x4, x24
    xor x15, x22, x7
    bgeu x15, x20, fwd_br_h3_19
    addi x28, x28, 1
fwd_br_h3_19:
    lw x23, 252(x2)
    sraw x4, x23, x4
    sra x9, x23, x9
    andi x11, x4, 254
    c.mv x15, x11
    sllw x31, x8, x15
    andi x17, x31, -1212
    c.sub x8, x12
    slliw x24, x17, 25
    slti x27, x8, 1419
    srliw x20, x27, 15
    xor x14, x19, x20
    beq x25, x14, fwd_br_h3_20
    addi x27, x27, 1
fwd_br_h3_20:
    lb x22, 282(x2)
    ori x5, x18, -390
    addw x27, x11, x8
    remuw x8, x27, x26
    slt x10, x4, x20
    add x18, x10, x12
    divu x25, x4, x17
    srl x14, x25, x14
    addiw x15, x12, 376
    addi x6, x15, -1418
    addw x6, x31, x16
    sraiw x4, x6, 16
    addw x30, x24, x8
    sub x28, x4, x28
    bgeu x28, x20, fwd_br_h3_21
    addi x12, x12, 1
fwd_br_h3_21:
    lw x13, -396(x2)
    xor x25, x26, x6
    subw x10, x13, x27
    sllw x24, x25, x20
    mulhu x5, x10, x30
    sraw x5, x11, x5
    xori x16, x19, 397
    or x25, x30, x16
    mulhsu x22, x22, x25
    add x5, x9, x19
    addi x14, x15, 928
    addw x17, x5, x29
    mulhu x17, x17, x4
    ld x17, 456(x2)
    srliw x17, x17, 22
    c.or x13, x12
    add x27, x9, x9
    slliw x25, x27, 3
    remu x24, x25, x9
    mulhsu x25, x24, x12
    sraw x16, x7, x26
    lbu x10, 74(x2)
    srai x5, x25, 13
    slliw x26, x10, 26
    c.add x13, x10
    sb x11, -103(x2)
    c.addw x12, x8
    or x9, x11, x4
    sllw x26, x9, x7
    rem x12, x9, x30
    andi x5, x23, -446
    lh x20, 490(x2)
    subw x22, x20, x17
    addw x5, x7, x22
    srlw x17, x5, x29
    slt x6, x5, x5
    lw x30, 152(x2)
    remu x8, x30, x16
    mulh x4, x8, x31
    sw x4, -316(x2)
    sllw x9, x6, x11
    sw x6, 184(x2)
    c.mv x25, x18
    blt x11, x16, fwd_br_h3_22
    addi x31, x31, 1
fwd_br_h3_22:
    remw x5, x25, x15
    srliw x21, x6, 18
    c.mv x20, x5
    sra x11, x21, x9
    sh x25, 6(x2)
    addi x15, x11, -1947
    sllw x9, x15, x30
    mulh x14, x9, x16
    sra x18, x14, x18
    lw x20, 12(x2)
    mulh x30, x8, x23
    srlw x7, x12, x26
    addw x21, x7, x5
    sraw x19, x23, x21
    sb x21, -191(x2)
    slt x19, x15, x18
    srl x28, x19, x20
    bne x28, x5, fwd_br_h3_23
    addi x16, x16, 1
fwd_br_h3_23:
    bne x28, x24, fwd_br_h3_24
    addi x28, x28, 1
fwd_br_h3_24:
    div x25, x12, x17
    mulhsu x31, x7, x23
    andi x30, x25, -573
    ld x8, 480(x2)
    sltu x18, x20, x8
    addw x19, x20, x18
    sw x19, 256(x2)
    slti x25, x19, 170
    sllw x21, x25, x27
    xor x6, x21, x26
    bgeu x20, x29, fwd_br_h3_25
    addi x30, x30, 1
fwd_br_h3_25:
    or x22, x15, x25
    addw x22, x27, x8
    subw x8, x28, x14
    c.mv x25, x12
    add x26, x8, x30
    bne x26, x4, fwd_br_h3_26
    addi x8, x8, 1
fwd_br_h3_26:
    sraw x13, x26, x10
    c.sub x9, x13
    sllw x6, x29, x9
    sltu x30, x21, x6
    sb x30, -421(x2)
    srl x21, x25, x18
    remuw x28, x24, x27
    sraw x10, x28, x23
    remu x22, x23, x10
    divuw x14, x4, x30
    c.xor x8, x15
    bne x8, x30, fwd_br_h3_27
    addi x24, x24, 1
fwd_br_h3_27:
    xor x27, x27, x13
    remu x14, x5, x19
    sll x4, x27, x10
    lwu x18, 232(x2)
    sllw x16, x18, x29
    remu x25, x12, x10
    srlw x12, x25, x6
    sraw x4, x12, x19
    srai x17, x24, 22
    srli x27, x17, 39
    remu x24, x27, x21
    add x19, x27, x28
    mulhsu x28, x23, x19
    sraw x5, x28, x4
    mulhsu x26, x7, x24
    andi x29, x26, 479
    or x13, x21, x8
    c.xor x13, x14
    sllw x14, x28, x13
    srliw x25, x16, 29
    sllw x4, x25, x17
    sltu x17, x4, x15
    lbu x8, 285(x2)
    sraw x31, x17, x18
    srlw x31, x17, x31
    remuw x28, x23, x31
    divu x8, x13, x18
    rem x30, x28, x21
    andi x4, x10, 1161
    c.add x13, x11
    sra x17, x8, x13
    lwu x7, -72(x2)
    bgeu x7, x6, fwd_br_h3_28
    addi x27, x27, 1
fwd_br_h3_28:
    c.add x8, x13
    slliw x29, x21, 11
    mulh x31, x26, x29
    remw x28, x31, x16
    sw x28, 340(x2)
    divw x4, x13, x4
    sltiu x16, x23, 1662
    addiw x28, x31, 711
    divu x10, x28, x21
    lbu x23, -472(x2)
    c.xor x12, x12
    sltiu x5, x28, -787
    blt x5, x21, fwd_br_h3_29
    addi x20, x20, 1
fwd_br_h3_29:
    mulw x5, x18, x28
    lw x17, -196(x2)
    divu x12, x17, x9
    remuw x19, x23, x12
    srl x21, x19, x13
    sraw x6, x8, x29
    sh x6, -324(x2)
    subw x4, x31, x11
    subw x11, x4, x26
    mulh x5, x5, x11
    c.xor x9, x11
    bgeu x5, x20, fwd_br_h3_30
    addi x26, x26, 1
fwd_br_h3_30:
    andi x6, x24, 194
    bne x6, x23, fwd_br_h3_31
    addi x11, x11, 1
fwd_br_h3_31:
    sub x15, x6, x14
    srlw x30, x25, x11
    ori x9, x30, 1094
    mulw x28, x9, x10
    or x8, x29, x23
    c.add x12, x9
    mulhsu x27, x12, x29
    srliw x6, x7, 4
    ld x30, 472(x2)
    andi x22, x7, 1585
    sllw x31, x22, x4
    or x30, x7, x25
    sb x30, -455(x2)
    srai x29, x24, 56
    subw x5, x22, x21
    or x10, x16, x5
    sltu x24, x27, x10
    c.add x12, x12
    c.and x10, x11
    c.xor x8, x14
    sh x16, -54(x2)
    srlw x15, x8, x4
    srlw x11, x14, x22
    srlw x28, x4, x11
    lwu x10, -32(x2)
    xor x6, x16, x10
    blt x5, x26, fwd_br_h3_32
    addi x28, x28, 1
fwd_br_h3_32:
    ori x11, x4, -1393
    sltu x6, x18, x22
    and x15, x6, x17
    srliw x7, x15, 5
    divuw x16, x7, x17
    slt x23, x7, x23
    subw x8, x23, x26
    divuw x25, x11, x30
    remw x29, x23, x28
    mul x11, x29, x19
    slt x14, x23, x7
    srliw x26, x10, 21
    subw x8, x28, x26
    sll x22, x8, x25
    andi x26, x27, 1117
    sllw x19, x4, x26
    c.mv x28, x19
    and x10, x28, x4
    sll x23, x24, x14
    andi x17, x23, 1974
    beq x17, x14, fwd_br_h3_33
    addi x18, x18, 1
fwd_br_h3_33:
    slti x24, x9, -1570
    addiw x19, x5, -1255
    c.xor x15, x14
    subw x6, x15, x28
    or x14, x27, x19
    srai x24, x14, 29
    sltu x21, x21, x15
    divuw x17, x21, x31
    c.sub x12, x14
    or x19, x24, x12
    lb x21, 421(x2)
    sltiu x8, x21, 1239
    remuw x9, x21, x30
    sra x22, x9, x10
    sraiw x11, x9, 24
    sraw x5, x6, x11
    ori x26, x11, 416
    srl x28, x16, x26
    srai x22, x28, 41
    sraiw x27, x28, 3
    srliw x20, x27, 3
    xori x13, x15, 76
    c.sub x9, x14
    lhu x24, -150(x2)
    ld x26, 320(x2)
    srli x19, x26, 30
    sltu x31, x8, x19
    mulhsu x21, x23, x25
    sd x21, 80(x2)
    xor x23, x21, x4
    ori x11, x22, 749
    andi x16, x11, -45
    divu x25, x11, x23
    mulhsu x17, x25, x24
    add x5, x25, x4
    divuw x28, x29, x23
    bge x28, x8, fwd_br_h3_34
    addi x6, x6, 1
fwd_br_h3_34:
    c.mv x25, x18
    sb x8, 236(x2)
    mulh x8, x9, x15
    srlw x17, x8, x19
    sltiu x6, x17, 1673
    remu x20, x6, x15
    sh x27, 394(x2)
    sraiw x5, x22, 23
    addi x4, x6, 1457
    and x11, x17, x10
    sw x11, -316(x2)
    c.addw x13, x15
    mulhu x13, x5, x28
    c.mv x25, x18
    addi x24, x17, 681
    beq x24, x15, fwd_br_h3_35
    addi x17, x17, 1
fwd_br_h3_35:
    sraw x6, x26, x13
    slli x11, x4, 36
    mulhsu x24, x11, x22
    c.xor x10, x12
    c.and x13, x12
    srl x13, x6, x19
    mulw x14, x13, x16
    blt x12, x14, fwd_br_h3_36
    addi x18, x18, 1
fwd_br_h3_36:
    srliw x18, x12, 6
    addw x8, x30, x8
    remw x15, x18, x8
    addw x24, x26, x27
    or x14, x20, x24
    remw x19, x24, x27
    remu x24, x7, x19
    bgeu x24, x21, fwd_br_h3_37
    addi x19, x19, 1
fwd_br_h3_37:
    c.and x9, x11
    addiw x24, x17, -831
    srl x23, x9, x28
    srlw x4, x26, x14
    srai x21, x8, 33
    c.add x10, x8
    lw x16, 8(x2)
    ori x29, x16, -618
    add x9, x31, x29
    sraiw x25, x21, 6
    c.or x14, x12
    sltiu x20, x14, -181
    mul x5, x24, x20
    sltiu x18, x29, 1372
    srliw x19, x21, 19
    remuw x28, x18, x19
    divuw x15, x19, x9
    c.or x11, x12
    srlw x10, x11, x13
    slt x9, x10, x23
    srli x6, x13, 59
    div x31, x13, x6
    xori x21, x6, 177
    mul x26, x21, x8
    mulhsu x24, x8, x12
    c.sub x9, x15
    slli x28, x12, 1
    or x15, x28, x8
    mul x6, x20, x15
    sraiw x4, x6, 15
    add x30, x4, x29
    sllw x10, x15, x30
    rem x14, x19, x10
    lh x28, -302(x2)
    addw x19, x28, x9
    subw x30, x19, x11
    addw x20, x30, x7
    mulh x8, x12, x15
    andi x18, x20, -610
    c.sub x13, x10
    srliw x20, x12, 25
    sll x30, x20, x31
    c.xor x14, x8
    srliw x7, x27, 4
    sh x22, 282(x2)
    sub x5, x30, x18
    srliw x7, x7, 19
    mulhu x26, x7, x23
    subw x4, x19, x26
    addi x7, x23, 914
    add x20, x7, x30
    srl x4, x7, x12
    xori x6, x20, -1308
    and x8, x6, x14
    srliw x28, x6, 2
    sw x28, 416(x2)
    c.mv x16, x15
    div x5, x16, x18
    mulh x11, x6, x5
    srai x10, x11, 23
    sraiw x13, x10, 15
    ori x9, x13, -1753
    slti x13, x4, 290
    sw x13, 292(x2)
    sltiu x8, x16, -384
    mulh x7, x6, x20
    mulhsu x18, x8, x7
    srliw x27, x18, 3
    mulh x5, x30, x12
    addiw x26, x9, -1854
    c.addw x12, x15
    sltiu x27, x26, -398
    or x28, x12, x9
    add x15, x29, x17
    lb x10, -50(x2)
    xor x23, x15, x27
    lbu x30, 384(x2)
    sraw x27, x31, x5
    mulw x9, x27, x25
    sltiu x13, x27, -748
    sw x15, 208(x2)
    sllw x20, x7, x18
    remw x18, x19, x20
    sltiu x24, x18, 257
    slli x18, x11, 60
    beq x24, x28, fwd_br_h3_38
    addi x5, x5, 1
fwd_br_h3_38:
    mulhsu x27, x7, x27
    sraw x7, x26, x22
    sb x7, 393(x2)
    sb x29, -220(x2)
    slt x19, x29, x13
    srli x14, x19, 54
    andi x17, x23, -289
    xori x24, x20, 183
    srli x23, x14, 13
    beq x24, x24, fwd_br_h3_39
    addi x25, x25, 1
fwd_br_h3_39:
    sraw x30, x6, x17
    sraw x31, x6, x14
    sllw x9, x15, x31
    remu x20, x16, x24
    sw x4, -156(x2)
    sh x20, -368(x2)
    sraw x19, x7, x25
    xor x22, x19, x19
    slli x16, x21, 14
    srlw x5, x13, x16
    sw x29, -92(x2)
    ori x6, x19, -215
    sllw x11, x6, x28
    addiw x20, x29, 1655
    sb x26, 457(x2)
    lwu x18, 44(x2)
    sltiu x14, x17, -1483
    beq x14, x6, fwd_br_h3_40
    addi x22, x22, 1
fwd_br_h3_40:
    lh x24, -96(x2)
    xori x29, x27, -1840
    mulh x13, x24, x7
    slli x18, x30, 59
    rem x16, x31, x31
    srai x24, x18, 29
    xor x9, x18, x23
    sltiu x5, x13, -745
    sltu x19, x9, x9
    c.addi x15, -23
    lh x22, -436(x2)
    sltiu x13, x30, 1189
    mulw x14, x27, x13
    bge x22, x14, fwd_br_h3_41
    addi x28, x28, 1
fwd_br_h3_41:
    srai x21, x15, 49
    sllw x4, x21, x7
    andi x5, x13, 1807
    sub x4, x5, x11
    c.xor x8, x11
    sltu x22, x8, x31
    srliw x21, x22, 3
    addw x8, x22, x26
    sltiu x22, x8, -373
    lb x22, 231(x2)
    addiw x26, x6, 80
    remu x24, x26, x30
    lhu x18, -370(x2)
    ori x21, x19, 1868
    divuw x5, x13, x26
    addw x17, x5, x21
    xori x30, x16, 1994
    sd x7, 368(x2)
    slti x25, x6, -845
    subw x17, x25, x20
    subw x21, x12, x12
    srlw x17, x17, x27
    mulhu x26, x16, x23
    srai x23, x17, 12
    sw x18, -260(x2)
    div x27, x20, x6
    xori x7, x27, -1462
    c.addw x14, x14
    slliw x24, x14, 30
    srl x22, x29, x22
    remw x17, x23, x22
    add x18, x9, x19
    rem x4, x17, x25
    slti x29, x23, 1560
    mulhu x19, x20, x29
    srli x26, x6, 19
    sb x6, -151(x2)
    add x25, x26, x9
    mulhsu x18, x31, x25
    srliw x7, x18, 19
    c.addw x11, x15
    sltu x19, x11, x11
    div x28, x24, x19
    sb x15, 421(x2)
    sd x19, 88(x2)
    and x30, x18, x15
    slli x12, x24, 29
    c.mv x12, x30
    sll x16, x12, x14
    sw x16, -488(x2)
    sraiw x6, x21, 16
    xori x25, x8, 1316
    mulhsu x27, x6, x15
    slli x27, x27, 3
    sltiu x8, x17, 408
    blt x8, x10, fwd_br_h3_42
    addi x30, x30, 1
fwd_br_h3_42:
    divw x19, x19, x16
    mulh x24, x17, x28
    divw x23, x7, x23
    addiw x23, x24, 1535
    div x22, x28, x6
    subw x12, x19, x22
    andi x30, x12, -957
    mulw x13, x8, x30
    slti x27, x13, -1979
    sd x27, -416(x2)
    divuw x6, x27, x24
    sllw x25, x13, x6
    mulh x21, x31, x14
    bne x13, x21, fwd_br_h3_43
    addi x20, x20, 1
fwd_br_h3_43:
    lw x29, 144(x2)
    beq x6, x5, fwd_br_h3_44
    addi x18, x18, 1
fwd_br_h3_44:
    slliw x26, x4, 9
    slliw x19, x26, 12
    bge x14, x17, fwd_br_h3_45
    addi x10, x10, 1
fwd_br_h3_45:
    add x31, x31, x11
    c.addi x8, -28
    srai x26, x9, 62
    srl x10, x8, x28
    slliw x4, x29, 8
    srliw x7, x22, 13
    slti x8, x5, -1338
    andi x21, x19, -959
    remuw x4, x8, x26
    slti x16, x21, -1439
    lw x15, -324(x2)
    mulhu x28, x8, x17
    c.mv x23, x28
    slti x17, x10, 622
    slliw x15, x9, 29
    addi x24, x15, 1619
    ori x11, x24, 966
    and x26, x11, x15
    sll x14, x15, x26
    c.addw x11, x9
    and x5, x11, x27
    or x4, x14, x5
    srliw x12, x4, 12
    addiw x4, x31, 1579
    remuw x22, x12, x7
    xor x31, x25, x22
    bne x25, x31, fwd_br_h3_46
    addi x17, x17, 1
fwd_br_h3_46:
    add x4, x11, x12
    rem x27, x4, x4
    ori x24, x27, -809
    sraiw x20, x24, 31
    andi x30, x8, 1164
    slt x7, x19, x30
    ld x21, -480(x2)
    ori x26, x14, 61
    sb x26, -23(x2)
    srliw x9, x19, 5
    slliw x27, x9, 31
    remuw x5, x27, x4
    subw x31, x24, x5
    c.sub x15, x14
    remu x4, x7, x15
    add x11, x24, x4
    bge x11, x10, fwd_br_h3_47
    addi x20, x20, 1
fwd_br_h3_47:
    sraw x13, x27, x8
    bne x27, x31, fwd_br_h3_48
    addi x19, x19, 1
fwd_br_h3_48:
    sraiw x25, x13, 24
    mulhsu x5, x16, x28
    sraw x31, x4, x5
    rem x11, x26, x8
    bltu x11, x23, fwd_br_h3_49
    addi x8, x8, 1
fwd_br_h3_49:
    sb x10, 197(x2)
    sh x5, -432(x2)
    c.add x14, x14
    sraw x21, x14, x23
    sllw x25, x17, x21
    lb x24, 130(x2)
    divu x22, x17, x26
    divuw x22, x31, x8
    divu x5, x22, x19
    srli x28, x16, 21
    sllw x19, x5, x17
    srli x19, x27, 39
    divuw x24, x19, x25
    bne x24, x4, fwd_br_h3_50
    addi x5, x5, 1
fwd_br_h3_50:
    bge x9, x20, fwd_br_h3_51
    addi x24, x24, 1
fwd_br_h3_51:
    rem x6, x19, x31
    div x7, x9, x6
    subw x31, x8, x20
    srai x9, x31, 61
    srli x22, x27, 30
    srliw x17, x22, 5
    srai x11, x14, 17
    sraw x25, x11, x20
    srl x24, x25, x16
    c.and x12, x15
    div x23, x24, x19
    div x12, x18, x23
    sb x12, 405(x2)
    sb x21, -325(x2)
    srliw x28, x13, 26
    sh x12, -314(x2)
    slliw x30, x7, 9
    mulhsu x7, x16, x30
    ori x11, x31, -936
    lh x15, 118(x2)
    sb x11, 356(x2)
    srl x23, x14, x30
    addw x28, x23, x6
    addiw x6, x28, 1467
    srl x9, x21, x10
    slli x24, x6, 34
    c.addw x9, x14
    remu x13, x7, x26
    remw x30, x14, x13
    divu x29, x15, x30
    slt x9, x22, x29
    addw x5, x30, x9
    addiw x19, x9, 1266
    remu x15, x19, x28
    sb x15, 404(x2)
    mulhsu x6, x15, x14
    remw x10, x6, x29
    divu x21, x6, x15
    addiw x10, x21, -450
    sllw x19, x7, x6
    sub x10, x11, x18
    lb x12, -336(x2)
    remuw x11, x31, x12
    bltu x9, x11, fwd_br_h3_52
    addi x17, x17, 1
fwd_br_h3_52:
    srai x10, x6, 60
    slt x13, x30, x13
    sll x10, x18, x28
    c.or x13, x9
    sh x13, -30(x2)
    beq x9, x25, fwd_br_h3_53
    addi x27, x27, 1
fwd_br_h3_53:
    sllw x28, x31, x9
    bne x25, x19, fwd_br_h3_54
    addi x24, x24, 1
fwd_br_h3_54:
    slti x15, x12, 611
    srai x9, x12, 9
    remuw x28, x9, x4
    sraiw x22, x9, 28
    slliw x5, x22, 13
    sraiw x8, x22, 12
    mulh x13, x17, x8
    addw x20, x13, x29
    mul x18, x20, x22
    divw x10, x19, x18
    subw x15, x17, x7
    slliw x9, x20, 4
    slliw x31, x28, 3
    addw x20, x5, x24
    andi x29, x17, 1790
    subw x26, x22, x29
    remu x21, x26, x21
    divw x14, x21, x30
    bne x28, x10, fwd_br_h3_55
    addi x30, x30, 1
fwd_br_h3_55:
    remw x28, x23, x20
    addiw x17, x4, -584
    /* --- END RANDOM INSTRUCTION BLOCK FOR HART 3 --- */
    addi x1, x1, -1
    bnez x1, .Lloop_hart3

    /* Hart 3 finished: store completion token */
    la   t1, h3_done
    li   t2, 0xCAFEBABE
    sd   t2, 0(t1)

    /* Secondary hart enters low-power sleep */
.Ldone_sleep_h3:
    wfi
    j    .Ldone_sleep_h3

.globl end_sync_start
end_sync_start:
.Lhart0_completion:
/* ========================================================================= */
/* HART 0: COMPLETION VERIFICATION & PASS SIGNATURE                          */
/* ========================================================================= */
    /* Wait for Harts 1..3 completion */
    la   t1, h1_done
.Lwait_done_h1:
    ld   t2, 0(t1)
    li   t3, 0xCAFEBABE
    bne  t2, t3, .Lwait_done_h1
    la   t1, h2_done
.Lwait_done_h2:
    ld   t2, 0(t1)
    li   t3, 0xCAFEBABE
    bne  t2, t3, .Lwait_done_h2
    la   t1, h3_done
.Lwait_done_h3:
    ld   t2, 0(t1)
    li   t3, 0xCAFEBABE
    bne  t2, t3, .Lwait_done_h3

    /* Signal completion to Spike via tohost */
    la   t0, tohost
    li   t1, 1
    sd   t1, 0(t0)

    TEST_PASS
    TEST_FAIL

.section .data
.align 6
start_signal: .dword 0
h1_ready:     .dword 0
h2_ready:     .dword 0
h3_ready:     .dword 0
h0_done:      .dword 0
h1_done:      .dword 0
h2_done:      .dword 0
h3_done:      .dword 0

.align 12
scratch_h0:
    .space 4096, 0xAA

.align 12
scratch_h1:
    .space 4096, 0xAA

.align 12
scratch_h2:
    .space 4096, 0xAA

.align 12
scratch_h3:
    .space 4096, 0xAA

.section .tohost, "aw", @progbits
.align 6
.globl tohost
tohost:   .dword 0
.globl fromhost
fromhost: .dword 0
