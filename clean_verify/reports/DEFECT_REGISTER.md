# SMVDU TITAN-X Pre-Synthesis Signoff: Defect Register

## Policy
1. Every failure encountered during verification is documented here immediately.
2. No testbench assertion may be modified or weakened to bypass a failure.
3. Every defect must have:
   - Defect ID
   - Subsystem / Module
   - Symptom & Failing Test
   - Root Cause Analysis (with waveform timestamp and PC if applicable)
   - RTL Fix applied (file, lines, diff)
   - Re-verification Evidence

| Defect ID | Module | Severity | Summary | Status | Commit / Fix |
|---|---|---|---|---|---|
| D-001 | rv_execute.v | High | DIVUW/REMUW operand sign-extension bug | CLOSED | Fixed in previous ATPG pass |
| D-002 | rv_mem.v | Critical | funct3_q unlatched bus de-sync bug | CLOSED | Fixed in previous ATPG pass |
| D-003 | rv_decode.v | Critical | FP opcodes nested in OP_SYSTEM 12-bit case & JAL 71-bit sign extension | CLOSED | Fixed in Phase 1 Linting |
| D-004 | rv_icache.v, rv_dcache.v | High | 8-way PLRU replacement bit-truncation & directional inversion | CLOSED | Fixed in Phase 1 Linting |

### Detailed Defect Records

#### Defect D-003: RV64 Decoder FP Opcode Nesting & JAL Immediate Overflow
- **Module**: `frontend/rv_decode/rv_decode.v`
- **Severity**: Critical (P0)
- **Description**: FP opcode decode branches (`OP_LOAD_FP`, `OP_STORE_FP`, `OP_FP`, `OP_FMADD`, etc.) were nested inside `case (eff_instr[31:20])` of `OP_SYSTEM`, making all floating point operations trigger illegal instruction traps. Also, JAL immediate replication was 51 bits producing a 71-bit expression for a 64-bit target.
- **RTL Fix**: Moved FP cases to outer `case (op)` level, removed duplicate definitions, corrected JAL replication count to 44.
- **Re-verification**: Verilator static lint pass green with 0 errors.

#### Defect D-004: L1 Caches 8-Way PLRU Replacement Tree Bit Truncation
- **Module**: `frontend/rv_icache/rv_icache.v` and `backend/rv_dcache/rv_dcache.v`
- **Severity**: High (P1)
- **Description**: Accesses to ways 2 and 3 omitted node `p[2]` from the 7-bit PLRU concatenation (`{p[6:5], 1'b0, p[3], 1'b1, 1'b1}` = 6 bits), and accesses to ways 4-7 set root bit to 1 instead of 0, corrupting tree state and freezing cache replacement.
- **RTL Fix**: Replaced with exact 7-bit `next_plru` function correctly setting root and subtree directional bits for all 8 ways.
- **Re-verification**: Verilator static lint pass green with 0 errors.
