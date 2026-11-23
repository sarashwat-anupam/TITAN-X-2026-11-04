#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# SMVDU TITAN-X — Multi-Core Constrained-Random Instruction Stream Generator
# Generates high-stress baremetal RISC-V RV64IMAC multi-core assembly
# targeting 100,000+ dynamic instructions across Harts 0..3 with
# hazard injection (RAW/WAR/WAW) and per-hart memory arena isolation.

import argparse
import random
import os
import sys

# Registers:
# x0: zero
# x1: ra (temporary in init)
# x2: sp / scratchpad pointer
# x3: loop counter (preserved across loop body)
# x4..x31: general test registers for hazard chains
TEST_REGS = [f"x{i}" for i in range(4, 32)]
RVC_REGS  = [f"x{i}" for i in range(8, 16)] # x8..x15

CORNER_VALUES = [
    0x0000000000000000,
    0xFFFFFFFFFFFFFFFF,
    0x7FFFFFFFFFFFFFFF,
    0x8000000000000000,
    0x000000007FFFFFFF,
    0xFFFFFFFF80000000,
    0x00000000FFFFFFFF,
    0x5555555555555555,
    0xAAAAAAAAAAAAAAAA,
    0x0000000000000001,
    0x0000000000000002,
    0xFFFFFFFFFFFFFFFE,
    0x000000000000003F,
    0x000000000000001F,
    0x123456789ABCDEF0,
    0xDEADBEEFCAFEBABE,
]

ALU_OPS_REG   = ["add", "sub", "slt", "sltu", "xor", "or", "and", "sll", "srl", "sra"]
ALU_OPS_IMM   = ["addi", "slti", "sltiu", "xori", "ori", "andi", "slli", "srli", "srai"]
ALU_W_OPS_REG = ["addw", "subw", "sllw", "srlw", "sraw"]
ALU_W_OPS_IMM = ["addiw", "slliw", "srliw", "sraiw"]
MEXT_OPS      = ["mul", "mulh", "mulhsu", "mulhu", "div", "divu", "rem", "remu", "mulw", "divw", "divuw", "remw", "remuw"]

LOAD_STORE_OPS = [
    ("sd", "ld", 8),
    ("sw", "lw", 4),
    ("sh", "lh", 2),
    ("sb", "lb", 1),
    ("sw", "lwu", 4),
    ("sh", "lhu", 2),
    ("sb", "lbu", 1),
]

BRANCH_OPS = ["beq", "bne", "blt", "bge", "bltu", "bgeu"]

def generate_random_block(hart_id, block_size, seed_offset, enable_rvc=True, enable_mext=True):
    random.seed(0x1000 * (hart_id + 1) + seed_offset)
    lines = []
    prev_rd = "x4"
    prev_prev_rd = "x5"
    br_id = 0

    for i in range(block_size):
        r = random.random()
        # RAW Hazard Injection
        if r < 0.35:
            rs1 = prev_rd
            rs2 = random.choice(TEST_REGS)
        elif r < 0.55:
            rs1 = random.choice(TEST_REGS)
            rs2 = prev_rd
        elif r < 0.70:
            rs1 = prev_prev_rd
            rs2 = random.choice(TEST_REGS)
        else:
            rs1 = random.choice(TEST_REGS)
            rs2 = random.choice(TEST_REGS)

        rd = random.choice(TEST_REGS)

        cat = random.random()
        if cat < 0.30:
            # 64-bit ALU
            if random.random() < 0.5:
                op = random.choice(ALU_OPS_REG)
                lines.append(f"    {op} {rd}, {rs1}, {rs2}")
            else:
                op = random.choice(ALU_OPS_IMM)
                if op in ("slli", "srli", "srai"):
                    shamt = random.randint(0, 63)
                    lines.append(f"    {op} {rd}, {rs1}, {shamt}")
                else:
                    imm = random.randint(-2048, 2047)
                    lines.append(f"    {op} {rd}, {rs1}, {imm}")

        elif cat < 0.50:
            # 32-bit Word Ops
            if random.random() < 0.5:
                op = random.choice(ALU_W_OPS_REG)
                lines.append(f"    {op} {rd}, {rs1}, {rs2}")
            else:
                op = random.choice(ALU_W_OPS_IMM)
                if op in ("slliw", "srliw", "sraiw"):
                    shamt = random.randint(0, 31)
                    lines.append(f"    {op} {rd}, {rs1}, {shamt}")
                else:
                    imm = random.randint(-2048, 2047)
                    lines.append(f"    {op} {rd}, {rs1}, {imm}")

        elif cat < 0.70 and enable_mext:
            # Multiplier & Divider
            op = random.choice(MEXT_OPS)
            lines.append(f"    {op} {rd}, {rs1}, {rs2}")

        elif cat < 0.85:
            # Bounded memory loads/stores in private scratchpad arena [-512, 512]
            st_op, ld_op, align = random.choice(LOAD_STORE_OPS)
            offset = random.randrange(-512, 512, align)
            if random.random() < 0.5:
                lines.append(f"    {st_op} {rs1}, {offset}(x2)")
            else:
                lines.append(f"    {ld_op} {rd}, {offset}(x2)")

        elif cat < 0.93 and enable_rvc:
            # Compressed Instructions
            c_op = random.choice(["c.add", "c.sub", "c.and", "c.or", "c.xor", "c.mv", "c.addi", "c.addw"])
            rc1 = random.choice(RVC_REGS)
            rc2 = random.choice(RVC_REGS)
            if c_op in ("c.add", "c.sub", "c.and", "c.or", "c.xor", "c.addw"):
                lines.append(f"    {c_op} {rc1}, {rc2}")
                rd = rc1
            elif c_op == "c.mv":
                lines.append(f"    {c_op} {rd}, {rs1}")
            elif c_op == "c.addi":
                c_imm = random.randint(-32, 31)
                if c_imm == 0: c_imm = 1
                lines.append(f"    {c_op} {rc1}, {c_imm}")
                rd = rc1
        else:
            # Forward conditional branch skipping 1 dummy instruction
            b_op = random.choice(BRANCH_OPS)
            lbl = f"fwd_br_h{hart_id}_{br_id}"
            br_id += 1
            lines.append(f"    {b_op} {rs1}, {rs2}, {lbl}")
            dummy_rd = random.choice(TEST_REGS)
            lines.append(f"    addi {dummy_rd}, {dummy_rd}, 1")
            lines.append(f"{lbl}:")

        prev_prev_rd = prev_rd
        prev_rd = rd

    return lines

def generate_multicore_asm(num_insns_per_core=1000, loop_iterations=25, enable_rvc=True, enable_mext=True):
    # Total dynamic instructions = 4 cores * num_insns_per_core * loop_iterations
    total_dynamic = 4 * num_insns_per_core * loop_iterations
    
    code = []
    code.append("/* SPDX-License-Identifier: Apache-2.0 */")
    code.append("/* SMVDU TITAN-X Multi-Core Constrained-Random Instruction Regression Suite */")
    code.append(f"/* Target: 4 Cores x {num_insns_per_core} insns x {loop_iterations} iters = {total_dynamic} dynamic instructions */")
    code.append("")
    code.append("#include \"../test_macros.h\"")
    code.append("")
    code.append(".section .text.init")
    code.append(".globl _start")
    code.append("")
    code.append("_start:")
    code.append("    csrr a0, mhartid")
    code.append("    li   t0, 4")
    code.append("    beq  a0, t0, .Lpark_hart4")
    code.append("")
    code.append("    /* Stack setup: private 4KB stack per core */")
    code.append("    la   sp, __stack_top")
    code.append("    slli t0, a0, 12")
    code.append("    sub  sp, sp, t0")
    code.append("")
    code.append("    /* Core entry dispatch */")
    code.append("    beqz a0, .Lentry_hart0")
    code.append("    li   t0, 1; beq a0, t0, .Lentry_hart1")
    code.append("    li   t0, 2; beq a0, t0, .Lentry_hart2")
    code.append("    li   t0, 3; beq a0, t0, .Lentry_hart3")
    code.append("")
    code.append(".Lpark_hart4:")
    code.append("    wfi")
    code.append("    j    .Lpark_hart4")
    code.append("")

    # Generate each core's entry and execution loop
    for hid in range(4):
        code.append(f"/* ========================================================================= */")
        code.append(f"/* HART {hid} EXECUTION STREAM                                                */")
        code.append(f"/* ========================================================================= */")
        code.append(f".Lentry_hart{hid}:")
        code.append(f"    /* Set up private scratchpad memory base pointer in x2 */")
        code.append(f"    la   x2, scratch_h{hid}")
        code.append(f"    addi x2, x2, 2047")
        code.append(f"    addi x2, x2, 1")
        code.append("")
        code.append(f"    /* Preload diverse corner values into registers x4..x31 */")
        for i, reg in enumerate(TEST_REGS):
            cval = CORNER_VALUES[(i + hid * 3) % len(CORNER_VALUES)]
            code.append(f"    li   {reg}, {hex(cval)}")
        code.append("")
        code.append(f"    /* Preload private scratchpad with initial deterministic data */")
        code.append(f"    li   x1, {hex(0x0123456789ABCDEF + hid * 0x1111111111111111)}")
        for off in range(-512, 512, 128):
            code.append(f"    sd   x1, {off}(x2)")
            code.append(f"    addi x1, x1, 0x111")
        code.append("")

        code.append(f"    /* Initialize loop counter in x1 */")
        code.append(f"    li   x1, {loop_iterations}")
        code.append(f".Lloop_hart{hid}:")
        code.append(f"    /* --- BEGIN RANDOM INSTRUCTION BLOCK FOR HART {hid} --- */")

        # Generate block instructions
        block_insns = generate_random_block(hid, num_insns_per_core, seed_offset=0x100 * hid,
                                           enable_rvc=enable_rvc, enable_mext=enable_mext)
        code.extend(block_insns)

        code.append(f"    /* --- END RANDOM INSTRUCTION BLOCK FOR HART {hid} --- */")
        code.append(f"    addi x1, x1, -1")
        code.append(f"    bnez x1, .Lloop_hart{hid}")
        code.append("")
        code.append(f"    /* Hart {hid} finished: store completion token */")
        code.append(f"    la   t1, h{hid}_done")
        code.append(f"    li   t2, 0xCAFEBABE")
        code.append(f"    sd   t2, 0(t1)")
        code.append("")

        if hid > 0:
            code.append(f"    /* Secondary hart enters low-power sleep */")
            code.append(f".Ldone_sleep_h{hid}:")
            code.append(f"    wfi")
            code.append(f"    j    .Ldone_sleep_h{hid}")
            code.append("")
        else:
            code.append(f"    /* Hart 0 proceeds to wait for Harts 1..3 */")
            code.append(f"    j    .Lhart0_completion")
            code.append("")

    # Hart 0 completion coordination
    code.append(".globl end_sync_start")
    code.append("end_sync_start:")
    code.append(".Lhart0_completion:")
    code.append("/* ========================================================================= */")
    code.append("/* HART 0: COMPLETION VERIFICATION & PASS SIGNATURE                          */")
    code.append("/* ========================================================================= */")
    code.append("    /* Wait for Harts 1..3 completion */")
    for h in range(1, 4):
        code.append(f"    la   t1, h{h}_done")
        code.append(f".Lwait_done_h{h}:")
        code.append(f"    ld   t2, 0(t1)")
        code.append(f"    li   t3, 0xCAFEBABE")
        code.append(f"    bne  t2, t3, .Lwait_done_h{h}")

    code.append("")
    code.append("    /* Signal completion to Spike via tohost */")
    code.append("    la   t0, tohost")
    code.append("    li   t1, 1")
    code.append("    sd   t1, 0(t0)")
    code.append("")
    code.append("    TEST_PASS")
    code.append("    TEST_FAIL")
    code.append("")

    # Data sections and scratchpads
    code.append(".section .data")
    code.append(".align 6")
    code.append("start_signal: .dword 0")
    code.append("h1_ready:     .dword 0")
    code.append("h2_ready:     .dword 0")
    code.append("h3_ready:     .dword 0")
    code.append("h0_done:      .dword 0")
    code.append("h1_done:      .dword 0")
    code.append("h2_done:      .dword 0")
    code.append("h3_done:      .dword 0")
    code.append("")
    for hid in range(4):
        code.append(".align 12")
        code.append(f"scratch_h{hid}:")
        code.append("    .space 4096, 0xAA")
        code.append("")

    code.append(".section .tohost, \"aw\", @progbits")
    code.append(".align 6")
    code.append(".globl tohost")
    code.append("tohost:   .dword 0")
    code.append(".globl fromhost")
    code.append("fromhost: .dword 0")
    code.append("")

    return "\n".join(code)

def main():
    parser = argparse.ArgumentParser(description="Multi-Core Constrained-Random ATPG Generator for TITAN-X")
    parser.add_argument("--insns-per-core", type=int, default=1000, help="Instructions per block per core")
    parser.add_argument("--iterations", type=int, default=25, help="Loop iterations per core")
    parser.add_argument("--output", type=str, default="clean_verify/tests/random/test_random_multicore.S", help="Output path")
    parser.add_argument("--no-rvc", action="store_true", help="Disable RVC instructions")
    parser.add_argument("--no-mext", action="store_true", help="Disable M-extension instructions")

    args = parser.parse_args()

    os.makedirs(os.path.dirname(args.output), exist_ok=True)
    asm_text = generate_multicore_asm(num_insns_per_core=args.insns_per_core,
                                     loop_iterations=args.iterations,
                                     enable_rvc=not args.no_rvc,
                                     enable_mext=not args.no_mext)

    with open(args.output, "w") as f:
        f.write(asm_text)

    total_insns = 4 * args.insns_per_core * args.iterations
    print(f"[GEN] Generated multi-core random assembly with {total_insns} dynamic instructions -> {args.output}")

if __name__ == "__main__":
    main()
