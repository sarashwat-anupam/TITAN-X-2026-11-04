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

