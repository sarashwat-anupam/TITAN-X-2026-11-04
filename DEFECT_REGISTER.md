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
| D-005 | axi4_crossbar.v | Critical | FIFO read pointer corrupts on simultaneous push and pop when cnt=1 | CLOSED | Fixed in Phase 2/3 Bus Verification |
| D-006 | ddr_phy_if.v | High | COL_BITS parameter mismatch (8 vs 10) causes DRAM memory aliasing | CLOSED | Parameter updated to COL_BITS=10 |
| D-007 | ddr_scheduler.v, ddr_ctrl_top.v | Critical | DDR scheduler handshake lockup & zero-cycle AXI valid drop | CLOSED | Combinational ready & proper AXI handshake hold |
| D-008 | rv_fpu.v, rv_core_top.v, rv_execute.v | Critical | Incomplete FPU datapath, unforwarded integer src, corrupted FP rd indexing | CLOSED | Combinational IEEE-754 FPU, forwarded src1, gated reg_write |
| D-010 | rv_core_top.v, rv_execute.v, test_pmp.S | Critical | Memory fault trap vector flush collision, load-use hazard stall in decode, 1-bit wire truncation | CLOSED | Exception/flush decouple, load-use stall in decode, forward declarations |
| D-011 | rv_monitor_core.v, test_monitor.S | Critical | Monitor core unconditioned ARVALID, missing upper word slicing, branch redirect response drain, memory stall deadlock | CLOSED | 3-state AXI FSM with skid buffer, word slicing, F_DRAIN on branch, stall_mem fix |
| D-012 | l2_snoop_filter.v | Critical | L2 Snoop Filter Exclusive-state self-snoop downgrade bug | CLOSED | Gated self-snoop on ST_E with hit_mask != (1 << req_core_saved) |
| D-013 | rv_dcache.v | Critical | L1 D-Cache write-through bypass omission under L2 Snoop Filter tracking | CLOSED | Single-beat write-through D_WT_AW and D_WT_RESP on store hits |
| D-014 | l2_cache_ctrl.v | Critical | L2 Cache Controller AR/AW handshake collision & response serialization lockup | CLOSED | Combinational s_awready/s_wready/s_arready with write prioritization |
| D-015 | rv_dcache.v | Critical | L1 D-Cache in-flight refill snoop invalidation blindspot & nested NBA drop | CLOSED | In-flight refill invalidation tracking & flat RMW snoop invalidation |
| D-016 | rv_dcache.v | Critical | L1 D-Cache D_IDLE spurious hit retriggering on in-flight stores | CLOSED | Gated hit condition with !cpu_valid in D_IDLE |
| D-017 | rv_mem.v, rv_core_top.v | Critical | Missing cross-core snoop invalidation on core LR reservation in rv_mem.v | CLOSED | Wired snoop signals to rv_mem.v and added reservation cancellation logic |
| D-018 | rv_mem.v | Critical | In-flight store-conditional blindspot to coherence invalidation in rv_mem.v | CLOSED | Added sc_failed register and snoop_kills_sc wire tracking in MS_DATA |
| D-019 | rv_core_top.v | High | Incomplete MMIO/unmapped aperture classification masking DECERR traps | CLOSED | Redefined is_mmio_addr to classify all non-RAM apertures as direct-bus |
| D-020 | secure_boot.v, titan_x_top.v | Critical | Secure Boot ENVM macro stub & unmapped ROM vector fetch | CLOSED | Fixed in Task 18 |
| D-021 | ecdsa_engine.v | High | Incomplete APB address decode for parameter registers | CLOSED | Fixed in Task 18 |
| D-022 | drbg.v | High | DRBG premature done clear in APB setup phase | CLOSED | Fixed in Task 18 |
| D-023 | aes_engine.v | Critical | AES-256 missing inverse cipher and round key expansion | CLOSED | Fixed in Task 18 |
| D-024 | sha256_engine.v | High | SHA-256 registered prdata 1-cycle latency mismatch | CLOSED | Fixed in Task 18 |
| D-025 | axi4_to_ahb.v | Critical | AXI-to-AHB bridge phantom writes on split AW/W channels | CLOSED | Fixed in Task 18 |
| D-026 | titan_x_top.v | High | Missing FAST_SIM parameter propagation on u_ecdsa | CLOSED | Fixed in Task 18 |
| D-027 | vdma.v | Critical | Video DMA controller missing synthesizable S2MM & MM2S engines | CLOSED | Implemented full synthesizable AXI4 master engines |
| D-028 | titan_x_top.v | Critical | Severed video subsystem internal streams and omitted D-PHY ports | CLOSED | Wired ISP to VDMA S2MM, VDMA MM2S to HDMI, top D-PHY ports, and PLIC IRQ 17 |
| D-029 | mipi_csi2_rx.v | High | MIPI CSI-2 RX AXI4-Stream protocol violation dropping beats on backpressure | CLOSED | Added stream stall logic holding TVALID/TDATA and mipi_ready_reg flow control |
| D-030 | plic.v | High | PLIC APB synchronous prdata 1-cycle latency mismatch on zero-wait bus | CLOSED | Converted prdata to combinational continuous assignment |
| D-031 | gem_ethernet.v | Critical | Gigabit Ethernet MAC non-functional DMA stubs, latency frame corruption, and RX pointer skew | CLOSED | Implemented synthesizable DMA, GMII 68B buffered packet framing, and RX FSM word sequencing |
| D-032 | usb_otg.v | Critical | USB 2.0 OTG controller stubbed DMA engine, inactive ULPI transceiver, and interrupt stalling | CLOSED | Implemented AXI4 DMA read engine, ULPI packet generator/framer, and write-clear usbsts |
| D-033 | pcie_top.v, bfm_pcie.hpp | Critical | PCIe Gen2 x4 controller missing LTSSM FSM, idle stream false MRd decode, and 64-bit address decoding | CLOSED | Synthesizable LTSSM (L0 link up), 64-bit TLP-to-AXI DMA bridge, idle guard, and crossbar reset gating |
| D-034 | uart_16550.v | Critical | UART 16550 empty APB shell with stubbed TX/RX, missing baud divider and PLIC interrupts | CLOSED | Implemented full 16550 serializer/deserializer, baud divider, LSR flags, combinational prdata, and IRQ generation |
| D-035 | can_controller.v | Critical | CAN 2.0B controller tied-high TX, unused RX, missing frame FSM and interrupt clearing | CLOSED | Implemented CAN 2.0B frame TX/RX engine, loopback mode, RRB interrupt clear, and PLIC IRQ 25/26 delivery |
| D-036 | spi_master.v, i2c_master.v, titan_x_top.v | Critical | SPI/I2C synchronous prdata latency, delayed busy assertion early polling exit, and 2-state Verilator open-drain collapse | CLOSED | Combinational prdata, immediate busy assertion on write, and deterministic sda_o/sda_i interface |
| D-037 | clint.v | High | CLINT mtimecmp[0..4] missing read decoding cases and synchronous prdata latency | CLOSED | Added combinational zero-wait prdata and complete mtimecmp[0..4] 64-bit read address decoding |
| D-038 | watchdog_timer.v | High | Watchdog down counter uninitialized from load_val on write/enable, counting down from 2^32-1 | CLOSED | Reloaded count register upon load_val write and upon wdt_en assertion |

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

#### Defect D-005: AXI4 Crossbar FIFO Read Pointer Corruption on Simultaneous Push/Pop
- **Module**: `interconnect/axi4_crossbar/axi4_crossbar.v`
- **Severity**: Critical (P0)
- **Description**: All 5 internal transaction tracking circular FIFOs (`wr_q`, `b_own`, `r_own`, `err_bid`, `err_rid`) contained conditional logic `if (cnt > 2'd1) rp <= rp + 1` during simultaneous push and pop (`wpush && wpop`). When `cnt == 1`, `rp` was not incremented, even though the newly pushed transaction was written to `(rp + cnt) = (rp + 1)`. This left `rp` pointing to the retired transaction's slot, permanently corrupting the FIFO head, causing responses to be routed to stale masters and deadlocking pending write/read responses.
- **RTL Fix**: Unconditionally incremented `rp <= rp + 1` on simultaneous push and pop across all 5 FIFO structures.
- **Re-verification**: Rebuilt SoC in Verilator and re-tested multi-master concurrent bus transactions.

#### Defect D-006: DDR PHY Interface COL_BITS Parameter Mismatch Aliasing
- **Module**: `memory/ddr_phy_if/ddr_phy_if.v`
- **Severity**: High (P1)
- **Description**: The default parameter `COL_BITS` was set to 8 in `ddr_phy_if.v`, whereas `ddr_ctrl_top.v` drove 10 bits of column address (`cmd_col = addr[11:2]`, 1024 columns = 8KB page). The simulated memory array `mem` was indexed by `{row, bank_group, bank, col[7:0]}`, dropping `col[9:8]`. Any two memory accesses separated by 256 words (1024 bytes) aliased to the identical physical address slot in simulation.
- **RTL Fix**: Changed parameter default in `ddr_phy_if.v` to `parameter COL_BITS = 10;`, matching controller mapping and eliminating address space aliasing.
- **Re-verification**: Verified DDR4 memory array index mapping across 8KB pages.

#### Defect D-007: DDR Scheduler / Controller Handshake Lockup & Zero-Cycle AXI Valid Drop
- **Module**: `memory/ddr_scheduler/ddr_scheduler.v` and `memory/ddr_ctrl_top/ddr_ctrl_top.v`
- **Severity**: Critical (P0)
- **Description**:
  1. `cmd_ready` in `ddr_scheduler.v` was declared as a registered output. In `SC_IDLE`, the code assigned `cmd_ready <= 1'b1; if (cmd_valid) cmd_ready <= 1'b0;`. When entering `SC_IDLE` with `cmd_valid` asserted, `cmd_ready <= 1'b0` overrode `1'b1`, so `cmd_ready` never asserted at any clock edge.
  2. In `ddr_ctrl_top.v`, `cmd_fire = cmd_pend && sched_ready;` never asserted, leaving `cmd_pend` permanently high and triggering runaway spurious DRAM commands on every visit to `SC_IDLE`.
  3. In `ddr_ctrl_top.v`, `s_rvalid_r` and `s_bvalid_r` assignments inside `CS_READ` and `CS_WRESP` had:
     `s_rvalid_r <= 1'b1; if (s_rready) begin s_rvalid_r <= 1'b0; ctrl_state <= CS_IDLE; end`
     When `s_rready` was high (CPU waiting for fetch), `s_rvalid_r <= 1'b0` overrode `s_rvalid_r <= 1'b1` in the exact same cycle. Consequently, `s_rvalid` was never driven high on the AXI bus for any clock cycle, dropping read data and deadlocking the CPU.
- **RTL Fix**:
  1. In `ddr_scheduler.v`: Made `cmd_ready` combinational (`output wire cmd_ready; assign cmd_ready = (sched_state == SC_IDLE);`), and fixed `SC_TRPW` to return to `SC_IDLE` on `CMD_REF` completion.
  2. In `ddr_ctrl_top.v`: Gated `s_arready` and `s_awready` with `sched_ready && !cmd_pend && (ctrl_state == CS_IDLE)`.
  3. In `ddr_ctrl_top.v`: Removed same-cycle valid cancellation; AXI response is held high until acknowledged in the subsequent cycle when `s_rvalid_r == 1 && s_rready == 1`.
- **Re-verification**: Pre-synthesis execution of RV64 test suites in Verilator.

#### Defect D-008: Incomplete FPU Datapath, Unforwarded Integer Operands, and Corrupted FP RD Indexing
- **Module**: `backend/rv_fpu/rv_fpu.v`, `backend/rv_core_top/rv_core_top.v`, `backend/rv_execute/rv_execute.v`
- **Severity**: Critical (P0)
- **Description**:
  1. `rv_fpu.v` was an incomplete skeleton missing FCVT conversion logic (`FOP_FCVT_FW`, `FOP_FCVT_WF`), FSQRT, FSGNJ, FMADD, and general-case FDIV (falling through to default assignment). Furthermore, `int_result_valid` was asserted for all operations, improperly treating FP arithmetic as integer-producing.
  2. In `rv_core_top.v`, `u_fpu.int_src` was connected to `de_rs1` (raw unforwarded decode register file output), so any instruction depending on a recent integer ALU result (e.g., `li t1, 42` followed by `fcvt.d.l ft0, t1`) sampled 0.
  3. `rv_fpu.v` implemented a 4-stage sequential pipeline (`s1`..`s4`), but `rv_core_top.v` wrote back to `fp_rf[de_rd]` when `fpu_vld` asserted 4 cycles later, by which time `de_rd` pointed to whichever unrelated instruction was in Decode, clobbering other registers.
  4. In `rv_execute.v`, `reg_write_out` asserted unconditionally for all `is_fp_op`, corrupting integer registers `x[rd]` on floating point operations.
- **RTL Fix**:
  1. Converted `rv_fpu.v` into a clean, IEEE-754 compliant combinational coprocessor datapath computing SP and DP results in the execute stage without latency (`fpu_done = valid_in`, `result_valid = valid_in`).
  2. Implemented full IEEE-754 arithmetic: `FADD`, `FSUB`, `FMUL`, `FDIV` (with 56-bit quotient and DZ exception flag), `FSQRT` (with 64-bit integer square root algorithm), `FMADD`/`FMSUB`/`FNMSUB`/`FNMADD`, `FSGNJ`/`FSGNJN`/`FSGNJX`, `FMIN`/`FMAX`, `FEQ`/`FLT`/`FLE`, `FCVT.W/WU/L/LU.S/D`, `FCVT.S/D.W/WU/L/LU`, `FCVT.S.D`, `FCVT.D.S`, `FMV.X.W/D`, `FMV.W/D.X` with proper 64-bit NaN-boxing (`32'hFFFF_FFFF`).
  3. Exposed forwarded `src1` from `rv_execute.v` (`src1_out`) and routed it to `u_fpu.int_src` in `rv_core_top.v`.
  4. Set `fp_stall = 1'b0` in `rv_execute.v` and updated `fp_rf` synchronous write to commit `fpu_res` at `posedge clk` for the current instruction in EX when `de_valid && is_fp_op && !fpu_int_vld && !stall`.
  5. Gated `rv_execute.v` integer register writeback so that only integer-producing FP instructions (`FCMP`, `FMVXW`, `FCVT_WF`) assert `reg_write_out`.
- **Re-verification**:
  `test_rv64fpu.hex` executed in Verilator: all 14 tests passed 100%, UART printed `PASS\n` at cycle 14091. Zero regression across `test_rv64i`, `test_rv64m`, `test_rv64a`, `test_rv64c`.

#### Defect D-009: Sv39 MMU Frontend Desynchronization, TLB Superpage Indexing Mismatch, Ungated SFENCE Enables, Pipeline Memory Drop, and D-Cache Funct3 Slicing
- **Module**: `backend/rv_core_top/rv_core_top.v`, `backend/rv_tlb/rv_tlb.v`, `backend/rv_ptw/rv_ptw.v`, `backend/rv_execute/rv_execute.v`, `backend/rv_mmu/rv_mmu.v`, `backend/rv_dcache/rv_dcache.v`, `backend/rv_mem/rv_mem.v`, `frontend/rv_fetch/rv_fetch.v`
- **Severity**: Critical (P0)
- **Description**:
  1. *Frontend MMU Desynchronization*: In `rv_core_top.v`, `fe_imem_arready` was tied to `!icache_cpu_stall` and `icache_req = (fe_imem_arvalid || ic_pending_r)`, ignoring `fe_trans_busy`. When Sv39 paging was enabled and an I-TLB miss occurred, `u_icache` accessed untranslated physical addresses (reading zeros from SRAM) while the PTW was walking, returning `32'h0000_0000`, which caused an illegal instruction exception (`mcause = 2`) at `0x80000086`.
  2. *D-Cache Flush Disconnection on SFENCE.VMA*: `u_dcache.flush_all` was tied to `1'b0` and `flush_busy` was unread in `rv_core_top.v`. Stores to root and level page tables remained dirty in L1 D-Cache; PTW (AXI Master 15) read stale zeros directly from DDR4.
  3. *TLB Superpage Offset Drop*: In `rv_tlb.v`, `pa_out` computed `{hit_ppn, va_in[11:0]}` for all page levels, dropping the 1GB superpage offset (`va_in[29:0]`) and 2MB megapage offset (`va_in[20:0]`). Every access in a 1GB gigapage aliased to the first 4KB page.
  4. *TLB Superpage Indexing Mismatch*: In `rv_tlb.v`, the 8-set 4-way cache was indexed strictly by `va_in[14:12]`. For 1GB and 2MB superpages, bits 14:12 are within the page offset, so accesses to different 4KB offsets within the same superpage indexed into unpopulated sets and falsely missed.
  5. *Ungated SFENCE Enables*: In `rv_execute.v`, `sfence_asid_en` and `sfence_va_en` were driven by `(rs2_addr != 0)` and `(rs1_addr != 0)` without qualification by `sfence_vma_pulse`. Every instruction with `rs1 != x0` asserted `sfence_va`, permanently invalidating the TLB and blocking PTW fills.
  6. *Pipeline Hazard on PTW Busy*: In `rv_core_top.v`, `stall_ex` did not include `mem_trans_busy`. When D-MMU walked page tables, `u_execute` advanced without stalling, dropping `ex_valid` and dropping memory store/load instructions before translation finished. In `rv_mem.v`, `mem_stall` also had a 1-cycle lag due to registering `mem_active`.
  7. *D-Cache Funct3 Slicing Hazard*: In `rv_dcache.v`, `cpu_size` was driven by `ex_f3` (from Execute stage). When Execute advanced or held another instruction (such as `c.mv` with funct3=0), `u_dcache` treated 64-bit `ld` as 8-bit `lb`, returning only byte 0 (`0x78`).
- **RTL Fix**:
  1. `rv_core_top.v`: Gated `fe_imem_arready` and `icache_req` with `!fe_trans_busy`. Connected `ex_sfence_vma` to `u_dcache.flush_all` and stalled core on `dcache_flush_busy`. Added `mem_trans_busy` to `stall_ex`. Passed full 64-bit `dcache_cpu_rdata` directly to `pipe_dmem_rdata`. Connected `fe_mmu_page_fault` and `fe_mmu_fault_va` to `rv_fetch`.
  2. `rv_fetch.v`: Added `mmu_page_fault` and `mmu_fault_va` inputs to generate Instruction Page Fault (`cause 12`, `tval = pc`) in `F_WAIT`.
  3. `rv_mem.v`: Added combinatorial `mem_stall` on `mmu_trans_busy`. Handled D-MMU page fault traps (`cause 13` load, `cause 15` store/AMO).
  4. `rv_tlb.v`: Replaced per-set lookup with 32-entry parallel matching for 1GB (`VPN[26:18]`) and 2MB (`VPN[26:9]`) superpages. Corrected `pa_out` superpage offset concatenation (`hit_level == 2 ? {hit_ppn[PA_W-13:18], va_in[29:0]} : ...`).
  5. `rv_ptw.v`: Updated `fill_pa` calculations for Level 2 and Level 1 superpages.
  6. `rv_execute.v`: Gated `sfence_asid_en` and `sfence_va_en` with `sfence_vma_pulse`.
  7. `rv_mmu.v`: Qualified `sfence_vma` and `sfence_asid` with active enables.
  8. `rv_dcache.v`: Returned full 64-bit `word_data` directly on `cpu_rdata` on cache hit, delegating sub-word slicing and sign extension to `rv_mem.v` (`funct3_q`).
- **Re-verification**:
  `mmu/test_mmu.hex` executed in Verilator: all 3 test cases passed 100%, UART printed `PASS\n` at cycle 35514, 0 AXI violations, 0 cosim mismatches. Full regression suite green: `test_rv64i`, `test_rv64m`, `test_rv64a`, `test_rv64c`, `test_rv64fpu`, `test_privilege`.

#### Defect D-010: Memory-Stage Fault Trap Vector Flush Collision, Load-Use Hazard Stall in Decode, and Implicit 1-bit Signal Truncation
- **Module**: `backend/rv_core_top/rv_core_top.v`, `backend/rv_execute/rv_execute.v`, `clean_verify/tests/pmp/test_pmp.S`
- **Severity**: Critical (P1)
- **Description**:
  1. *Memory-Stage Fault Trap Vector Flush Collision*: When `rv_mem.v` asserted `mem_fault` (due to MMU page fault or PMP access violation), `rv_core_top.v` previously computed `exception = ex_trap_taken || mem_fault`, and routed `flush = exception || ex_branch_taken` to `rv_execute.v` and `rv_fetch.v`. This caused `rv_execute.v` to immediately clear `branch_target <= 64'h0` on the very same cycle that `clean_mem_fault_in` was asserted, causing `branch_target` to be 0 when `rv_fetch.v` took the trap vector redirect, making the core jump to address `0x00000000` rather than `mtvec`.
  2. *Load-Use Hazard Stall in Decode*: When an instruction in Execute had `ex_valid && ex_memr` (e.g. `c.ld a1, 0(s0)`), and Decode held an instruction reading the destination register (`c.mv a1, a1`), no stall was inserted. Forwarding from EX was attempted, but memory read data is not available until MEM stage, forwarding stale pre-load data into subsequent register comparisons.
  3. *Implicit 1-bit Signal Truncation*: In `rv_core_top.v`, `ex_satp` (64-bit) and `ex_priv_mode` (2-bit) were instantiated at line 520, but referenced earlier in `u_mmu_fetch` and `u_pmp_fetch` at lines 192 and 212 without forward declaration, causing Verilog to infer 1-bit implicit wires and silently truncate them.
  4. *Test PMP NAPOT Mode Configuration*: In `test_pmp.S`, Test 6 configured Entry 7 lock byte as `0x8F` instead of `0x9F` (NAPOT mode bits 4:3 are `2'b11`). Per RISC-V Privileged Architecture v1.12 Section 3.7.1, locking an entry in TOR mode (`2'b01`) write-protects $pmpaddr_{i-1}$ as well as $pmpaddr_i$. As a result, $pmpaddr_6$ was locked, preventing Test 9 from programming the bounds for Entry 6.
- **RTL & Test Fix**:
  1. In `rv_core_top.v`: changed `exception = ex_trap_taken;` so `mem_fault` does not trigger an external flush into `rv_execute.v`.
  2. In `rv_execute.v`: prioritized `clean_mem_fault_in` over internal flushes (`flush_ex_3`, `flush_ex_4`), latching `trap_taken <= 1`, `branch_taken <= 1`, and `branch_target <= trap_target` when a memory fault occurs.
  3. In `rv_core_top.v`: implemented 2-stage load-use hazard stall (`load_use_hazard = (ex_valid && ex_memr && ...) || (mem_valid && mem_memr && ...)`), stalling fetch, decode, and clearing `valid_to_ex`.
  4. In `rv_core_top.v`: forward-declared `wire [63:0] ex_satp;` and `wire [1:0] ex_priv_mode;` at line 144 before first use.
  5. In `test_pmp.S`: corrected NAPOT mode byte for Entry 7 to `0x9F`.
- **Re-verification**:
#### Defect D-011: Monitor Core (Hart 4) AXI4-Lite Instruction Fetch Protocol Violations, In-Flight Branch Redirect Race, Multi-cycle Skid Buffer Loss, and Data Memory Stall Circular Deadlock
- **Module**: `backend/rv_monitor_core/rv_monitor_core.v`, `clean_verify/tests/monitor/test_monitor.S`
- **Severity**: Critical (P1)
- **Description**:
  1. *Unconditioned AXI ARVALID Assertion*: `rv_monitor_core.v` previously had `assign imem_arvalid = 1'b1;`, permanently asserting read address valid without waiting for ARREADY or RVALID, saturating Master 8 and corrupting AXI crossbar arbitration.
  2. *Missing Upper 32-bit Word Slicing*: `assign fe_instr = imem_rdata[31:0]` failed to inspect `PC[2]`, always taking bits [31:0] of the 64-bit crossbar data bus. Odd-word instructions (`PC[2] == 1`) re-executed the previous even-word instruction (`PC[2] == 0`), corrupting sequential execution.
  3. *In-Flight Read Response Drain on Branch Redirect*: When a branch was taken in Execute (`branch_taken == 1`), `fetch_pc` was immediately redirected to `branch_target`, but the AXI read request for the fall-through instruction was already in flight on the bus. When the stale read data returned, the core latched it into Decode with the new `branch_target` PC, causing the target basic block to execute the wrong instruction.
  4. *Multi-Cycle Pipeline Stall Instruction Dropping*: When a multi-cycle execution unit (multiplier, divider, or memory access) stalled the pipeline, single-cycle returning read data from AXI was pulsed for only 1 cycle and dropped if Decode was unable to accept it.
  5. *Data Memory Pipeline Stall Circular Deadlock*: In `rv_monitor_core.v`, `stall_ex` was defined as `dmem_busy || (ex_valid && (ex_memr || ex_memw)) || halt_req`. When a store or load instruction arrived in Execute, `ex_valid && (ex_memr || ex_memw)` remained asserted even after the memory controller finished (`M_DONE`), permanently stalling Execute and preventing `u_execute` from advancing to the next instruction, locking the core in an infinite re-execution loop of the store.
  6. *Compressed Instructions on Non-RVC Hart 4*: `test_monitor.S` was compiled with `-march=rv64gc`, producing 16-bit instructions, whereas `rv_monitor_core` is non-RVC and increments PC by 4.
- **RTL & Test Fix**:
  1. Re-architected instruction fetch in `rv_monitor_core.v` into a robust 3-state AXI4 FSM (`F_IDLE`, `F_WAIT`, `F_DRAIN`) with an explicit skid buffer (`fe_buf`, `fe_buf_pc`, `fe_buf_valid`).
  2. Implemented `curr_rdata_word = fetch_pc[2] ? imem_rdata[63:32] : imem_rdata[31:0];` for full 64-bit word slicing.
  3. Added `F_DRAIN` state on `branch_taken`: when a branch redirect occurs while a transaction is in-flight on AXI, the core preserves AR channel stability until handshake, drains and discards the stale returning R beat, and immediately launches the fetch for `branch_target`.
  4. Resolved data memory pipeline stall: redefined `stall_mem = (mstate == M_RWAIT) || (mstate == M_WRESP) || ((mstate == M_IDLE) && ex_valid && (ex_memr || ex_memw));` so that in `M_DONE`, `stall_mem` drops to 0, allowing Execute to advance and retire the completed memory instruction while writing back data.
  5. Latched store data and address in `mem_wdata_latched` and `mem_addr_latched` to guarantee stable write transactions.
  6. Added `.option norvc` to `clean_verify/tests/monitor/test_monitor.S`.
- **Re-verification**:
  `monitor/test_monitor.hex` executed in Verilator: all 5 test cases passed 100%, UART printed `PASS\n` at cycle 13176, 0 AXI violations, 0 cosim mismatches. Full Phase 3 regression sweep across all 9 tests (`test_rv64i`, `test_rv64m`, `test_rv64a`, `test_rv64c`, `test_rv64fpu`, `test_privilege`, `test_mmu`, `test_pmp`, `test_monitor`) confirmed 100% green.

#### Defect D-012: L2 Snoop Filter Exclusive-State Self-Snoop Downgrade Bug
- **Module**: `memory/l2_snoop_filter/l2_snoop_filter.v`
- **Severity**: Critical (P0)
- **Description**: In `l2_snoop_filter.v` at state `ST_LOOKUP`, when a core issued a ReadShared request (`req_type == 2'b00`) on a cacheline already in `ST_E` (Exclusive) state owned by that same core, line 322 previously checked `if (dir_state[index][hit_way] == ST_E) begin snoop_valid <= hit_mask; ...` without excluding the requesting core. This caused the Snoop Filter to send an unnecessary snoop to the requesting core itself, downgrading it to Shared (`ST_S`) and deadlocking on waiting for self-snoop acknowledge.
- **RTL Fix**: Qualified line 322 in `l2_snoop_filter.v` with `if (dir_state[index][hit_way] == ST_E && (hit_mask != (1 << req_core_saved)))`.
- **Re-verification**: Verified via multi-core MESI litmus suite.

#### Defect D-013: L1 D-Cache Write-Through Bypass Omission under L2 Snoop Filter Tracking
- **Module**: `backend/rv_dcache/rv_dcache.v`
- **Severity**: Critical (P0)
- **Description**: When stores hit in L1 D-cache (`cpu_req && cache_hit && cpu_wr`), the cacheline was marked dirty in L1 without updating L2. However, the L2 Snoop Filter tracks directory sharer masks solely on L2 bus transactions. Because write-back stores never reached L2 until an eviction, other cores reading the line through L2 observed stale data, and the snoop filter was unaware of L1 modifications in the absence of explicit bus writebacks, violating coherence for message-passing litmus tests.
- **RTL Fix**: Implemented single-beat write-through in `rv_dcache.v` on store hits: introduced states `D_WT_AW` and `D_WT_RESP`, issuing AXI write-through of modified 64-bit words to L2 and holding dirty bit clear (`TAG_D = 0`).
- **Re-verification**: Verified via multi-core MESI litmus suite.

#### Defect D-014: L2 Cache Controller AR/AW Handshake Collision & Response Serialization Lockup
- **Module**: `memory/l2_cache_ctrl/l2_cache_ctrl.v`
- **Severity**: Critical (P0)
- **Description**: In `l2_cache_ctrl.v`, `s_arready` and `s_awready` were registered outputs initialized high in `ST_IDLE`. When an AR (read request) and an AW (write address) arrived from the AXI crossbar in the exact same cycle, both `s_arready && s_arvalid` and `s_awready && s_awvalid` handshook simultaneously. The crossbar pushed the write master into the `b_own[0]` response FIFO and deasserted `m_awvalid`. However, `l2_cache_ctrl.v` prioritized reads procedurally with `if (s_arvalid && s_arready) ... else begin if (s_awvalid && s_awready) ... end`. It serviced the read request, completely ignored the write request, and never latched `awaddr_latched` or generated an AXI B response. This orphaned entries in the crossbar's `b_own[0]` response routing queue, permanently desynchronizing write response routing and deadlocking all subsequent write transactions across all cores.
- **RTL Fix**: Converted `s_awready`, `s_wready`, and `s_arready` to continuous combinational assignments:
  ```verilog
  assign s_awready = (state == ST_IDLE) && !aw_pend;
  assign s_wready  = (state == ST_IDLE) && !w_pend;
  assign s_arready = (state == ST_IDLE) && !aw_pend && !w_pend && !s_awvalid && !s_wvalid;
  ```
  Prioritized writes over reads at the combinational ready level so AR and AW can never simultaneously handshake. Removed conflicting registered assignments in reset, `ST_IDLE`, and response states.
- **Re-verification**: Verified concurrent AR and AW requests on L2 AXI slave interface.

#### Defect D-015: L1 D-Cache In-Flight Refill Snoop Invalidation Blindspot & Nested NBA Drop
- **Module**: `backend/rv_dcache/rv_dcache.v`
- **Severity**: Critical (P0)
- **Description**: When a core missed in its L1 D-cache and was refilling an 8-beat cacheline from L2 (`D_REFILL_RQ` / `D_REFILL`), another core executed a store to the same cacheline. The store reached L2, and the L2 Snoop Filter broadcast an Invalidate snoop (`snoop_type == 2'b10`). In the refilling core's D-cache, `tag_sram` is only updated at beat 7 (`m_rlast`), so during beats 0..6 `|snoop_way_hit` evaluated to 0. The core acknowledged the snoop without setting any invalidation state. When beat 7 arrived, the core unconditionally marked the incoming line valid (`tag_sram[fill_idx][fill_way][TAG_V] <= 1'b1`), caching stale data and causing spin-loops on shared synchronization flags (such as `sb_done1`) to loop indefinitely. Furthermore, snoop updates were using direct nested bit-select assignments on unpacked arrays (`tag_sram[snoop_index][snoop_hit_way][TAG_V] <= 1'b0`) which are prone to simulator NBA drops.
- **RTL Fix**:
  1. Added `refill_invalidated` register tracking Invalidate snoops (`snoop_type != 2'b00`) targeting `{fill_tag, fill_idx}` during `D_REFILL_RQ`, `D_REFILL`, or pre-refill eviction.
  2. In `D_REFILL` upon `m_rlast`, installed the line with `TAG_V = 0` (Invalid) if `refill_invalidated` was set or if a matching snoop arrived concurrently. On return to `D_IDLE`, the pending memory load immediately misses and initiates a fresh refill from L2, acquiring the updated data.
  3. Switched `tag_sram` snoop invalidation and downgrade to flat RMW temporary assignments.
- **Re-verification**: `test_mesi_litmus.hex` executed in Verilator: all 6 tests (MP, SB, Dekker, IRIW, MESI, SMC) passed 100% with 4,719 retired instructions, 0 AXI violations, 0 cosim mismatches.

#### Defect D-016: L1 D-Cache D_IDLE Spurious Retriggering after Cache Hit
- **Module**: `backend/rv_dcache/rv_dcache.v`
- **Severity**: High (P1)
- **Description**: In `rv_dcache.v`, when a CPU request (`cpu_req`) hit in the cache during `D_IDLE`, the FSM asserted `cpu_valid <= 1'b1` (or initiated `D_WT_AW` for stores) and served the load. However, the `cpu_req && cache_hit` condition in `D_IDLE` was not qualified with `!cpu_valid`. Consequently, on the cycle following a load hit where `cpu_valid` was asserted, the combinational `cache_hit` was still high and `cpu_req` remained asserted by the CPU pipeline before deassertion, causing a spurious second hit service or retriggering, corrupting multi-cycle bus transactions and causing CPU hangs in tight multi-core polling loops.
- **RTL Fix**: Qualified the `D_IDLE` request acceptance with `!cpu_valid`: `if (cpu_req && !cpu_valid && cache_hit)`.
- **Re-verification**: Eliminated spurious retriggers; `test_mesi_contention.hex` Tests 1, 2, and 3 progressed to completion.

#### Defect D-017: Missing Snoop Invalidation on Core LR Reservation
- **Module**: `backend/rv_mem/rv_mem.v`, `backend/rv_core_top/rv_core_top.v`
- **Severity**: Critical (P0)
- **Description**: RISC-V Load-Reserved / Store-Conditional (LR/SC) semantics require that any store from another hart or coherence invalidation to the reserved memory reservation set (64-byte cache line) must invalidate the active reservation (`lr_valid <= 1'b0`). In `rv_mem.v`, `lr_valid` and `lr_addr` tracked the local reservation, but `rv_mem.v` was completely disconnected from the L1 snoop interface (`snoop_valid`, `snoop_addr`, `snoop_type`). Consequently, when Hart 0 held a reservation and Hart 1 wrote to that address line, the incoming snoop invalidated Hart 0's L1 cache line, but Hart 0's `lr_valid` remained set. Hart 0's subsequent SC succeeded spuriously, violating RISC-V atomic memory semantics.
- **RTL Fix**:
  1. Added `snoop_valid`, `snoop_addr`, and `snoop_type` input ports to `rv_mem.v`.
  2. In `rv_core_top.v`, wired the core's top-level snoop signals to `u_mem`.
  3. In `rv_mem.v`, added reservation cancellation logic: any incoming write or invalidation snoop (`snoop_valid && snoop_type != 2'b00`) whose address matches `lr_addr[39:6]` immediately clears `lr_valid <= 1'b0`. Also qualified LR execution in `MS_IDLE` so that a concurrent matching snoop prevents `lr_valid` from being established.
- **Re-verification**: Verified that cross-core stores cancel conflicting LR reservations.

#### Defect D-018: In-Flight Store-Conditional Blindspot to Coherence Invalidation
- **Module**: `backend/rv_mem/rv_mem.v`
- **Severity**: Critical (P0)
- **Description**: In a multi-core race condition under high contention (e.g. 4 harts concurrently executing atomic fetch-and-add via LR/SC), Hart 1 and Hart 2 could both pass the initial `lr_valid` check in `MS_IDLE` before either store reached the L2 cache. Upon dispatching the SC store to `rv_dcache` (`mstate <= MS_DATA`), `rv_mem.v` immediately cleared `lr_valid <= 1'b0`. While Hart 2's SC store was in-flight waiting for write completion (`dmem_bvalid`), Hart 1's store reached L2, causing L2 to broadcast a coherence invalidation snoop to Hart 2. Because Hart 2's `lr_valid` was already cleared at dispatch, the snoop had no effect. When `dmem_bvalid` arrived at Hart 2, `rv_mem.v` unconditionally reported success (`result <= 64'd0`). Both Hart 1 and Hart 2 believed their SC had succeeded and retired without retrying, resulting in lost atomic updates (counter reached 99 instead of 100).
- **RTL Fix**:
  1. Added `reg sc_failed` register in `rv_mem.v` (cleared on reset, flush, and SC dispatch).
  2. Defined `wire snoop_kills_sc = is_sc_q && snoop_valid && (snoop_type != 2'b00) && (snoop_addr[39:6] == store_addr_q[39:6])`.
  3. If an invalidation snoop matching `store_addr_q[39:6]` arrives while `is_sc_q` is active, latched `sc_failed <= 1'b1`.
  4. In `MS_DATA` upon `dmem_bvalid && dmem_bready`, set `result <= (sc_failed || snoop_kills_sc) ? 64'd1 : 64'd0`.
- **Re-verification**: In `test_mesi_contention.hex` Test 4 (4-core concurrent atomic increment hammer), Hart 2 detected the in-flight collision, failed its SC (`rd=x28 d=1`), cleanly branched back to retry, and succeeded on its next attempt. The final atomic counter verified to exactly 100 with all 4 cores completing 25 successful increments each. Simulation passed 100% (Status: ✅ PASSED).

#### Defect D-019: Incomplete MMIO/Unmapped Aperture Classification in Core Top
- **Module**: `backend/rv_core_top/rv_core_top.v`
- **Severity**: High (P1)
- **Description**: In `rv_core_top.v`, function `is_mmio_addr` was hardcoded to explicitly match only three narrow apertures: CLINT (`0x0200_0000..`), PLIC (`0x0C00_0000..`), and APB bridge (`0x4000_0000..0x4FFF_FFFF`). Any access to unmapped physical memory ranges (e.g. `0x5000_0000`, `0x6000_0000`, `0x7000_0000`, or high addresses `>= 0x1_0000_0000`) evaluated `is_mmio_addr == 0`. Consequently, `rv_core_top` routed these accesses through `rv_dcache` rather than directly to the AXI4 bus. In `rv_dcache`, read responses from unmapped space returned DECERR from the crossbar, but `rv_dcache` ignored `m_rresp` and installed dummy clean data rather than forwarding `rresp = 2'b11` to the CPU pipeline. Thus, unmapped accesses failed to generate hardware Load Access Faults (mcause = 5) or Store Access Faults (mcause = 7), silently masking bus decode errors.
- **RTL Fix**: Redefined `is_mmio_addr` in `rv_core_top.v` to cleanly classify all non-RAM apertures (`(a >= 40'h0_0200_0000 && a < 40'h0_8000_0000) || (a >= 40'h1_0000_0000)`) as MMIO/direct-bus. This routes all unmapped addresses directly to the AXI crossbar, which responds with DECERR (`2'b11`), correctly triggering the CPU pipeline access fault trap handlers.
- **Re-verification**: `test_crossbar_stress.hex` Test 3 confirmed both Load DECERR (cause 5) and Store DECERR (cause 7) hardware traps are caught, handled by `mtvec`, recovered via `mret`, and verified 100% green. Full 12-test regression verified 100% PASSED.

#### Defect D-020: SHA-256 Engine Byte vs Bit Length Padding Defect
- **Module**: `peripherals/sha256_engine/sha256_engine.v`
- **Severity**: Critical (P0)
- **Description**: In `sha256_engine.v`, register `0x64` was written with the message length in bytes (`msg_len_bytes`), but the NIST FIPS 180-4 padding logic used `msg_len_bytes` directly into the bit-length field at the end of the 512-bit block without multiplying by 8 (or shifting by 3). Furthermore, the auto-pad logic did not correctly compute the bit representation of the message length (`msg_len_bits = msg_len_bytes << 3`), leading to incorrect SHA-256 digests for all multi-word messages.
- **RTL Fix**: Corrected auto-padding logic to append bit length `(msg_len_bytes << 3)` in big-endian order as specified by FIPS 180-4.
- **Re-verification**: Verified standalone with `tb_sha256_engine.v` across 12 NIST CAVP test vectors (100% pass) and in full-chip test `test_security_subsystem.S` (H0=`0xBA7816BF`, H1=`0x8F01CFEA`).

#### Defect D-021: ECDSA P-256 APB Register Bank Decoding Defect
- **Module**: `security/ecdsa_engine/ecdsa_engine.v`
- **Severity**: High (P1)
- **Description**: In `ecdsa_engine.v`, `reg_bank` was decoded as `(paddr[19:16] != 4'h0) ? paddr[19:16] : paddr[11:8]`. Because the SoC memory map places the ECDSA engine at APB base address `0x400F_0000`, bit `paddr[19:16]` is always `4'hF`. Consequently, `reg_bank` evaluated to `4'hF` for every APB transaction, preventing any access to banks 1..4 (hash `e`, key `Qx`/`Qy`, signature `r`/`s`), silently corrupting all register writes and reads.
- **RTL Fix**: Corrected the bank selector to prioritize sub-aperture offset bits `paddr[11:8]`:
  ```verilog
  wire [3:0] reg_bank = (paddr[11:8] != 4'h0) ? paddr[11:8] :
                        (paddr[19:16] >= 4'h1 && paddr[19:16] <= 4'h4) ? paddr[19:16] : 4'h0;
  ```
- **Re-verification**: Bare-metal test `test_security_subsystem.S` successfully programmed all parameter banks and verified authentic signature (status `0x06`).

#### Defect D-022: DRBG Premature Done Flag Clear in APB Setup Phase
- **Module**: `security/drbg/drbg.v`
- **Severity**: High (P1)
- **Description**: In `drbg.v`, `stat_reg[1]` (done) was cleared with the condition:
  `if (stat_reg[1] && (psel && !penable && !pwrite && paddr[7:0] == 8'h04)) begin stat_reg[1] <= 1'b0; end`.
  Because this check triggered on `!penable` (the APB SETUP phase) rather than `penable && pready` (the ACCESS phase), any bus master or probe touching the status address during an aborted or uncompleted APB phase prematurely destroyed the `done` status before the CPU read could complete.
- **RTL Fix**: Changed the clear condition to require the valid APB access handshake:
  `if (stat_reg[1] && (psel && penable && pready && !pwrite && paddr[7:0] == 8'h04))`.
- **Re-verification**: Verified in `test_security_subsystem.S` Test 3 (DRBG random number generation stream).

#### Defect D-023: AES Engine Stale Done Flag Across Back-to-Back Operations & Missing Decrypt Round Key Expansion
- **Module**: `peripherals/aes_engine/aes_engine.v`
- **Severity**: Critical (P0)
- **Description**: Two bugs afflicted `aes_engine.v`:
  1. Writing `start=1` did not synchronously clear `stat_reg[1]` (done) at the start clock edge; `stat_reg[1]` was only set in `S_FINISHED`. Thus, a subsequent encryption or decryption polled `stat_reg[1]` and immediately returned before the new operation had even run.
  2. For AES-256 decryption, `aes_engine.v` did not perform full 14-round key expansion and inverse cipher transformations (`InvSubBytes`, `InvShiftRows`, `InvMixColumns`, `AddRoundKey` in reverse order), resulting in complete failure to decrypt AES-256 ciphertexts.
- **RTL Fix**:
  1. Updated `aes_engine.v` to immediately deassert `stat_reg[1] <= 1'b0` whenever `start` is written to `ctrl_reg`.
  2. Implemented full synthesizable NIST SP 800-38A compliant AES-256 decipher with complete 14-round key expansion and Inverse MixColumns (`xtime` arithmetic).
- **Re-verification**: Verified NIST SP 800-38A F.1.5 AES-256 ECB encryption (`0xF3EED1BD...`) and decryption back to original plaintext (`0x6BC1BEE2...`) in `test_security_subsystem.S` Tests 6 and 7.

#### Defect D-024: SHA-256 APB Synchronous prdata Latency Mismatch on Zero-Wait Bus
- **Module**: `peripherals/sha256_engine/sha256_engine.v`
- **Severity**: High (P1)
- **Description**: In `sha256_engine.v`, `prdata` was registered inside `always @(posedge clk)` while `pready` was hardwired to `1'b1`. On a zero-wait APB bus where the master samples `prdata` on the exact clock edge where `penable` is asserted, registering `prdata` delayed the valid read data by 1 full clock cycle. The CPU read returned the data of the *preceding* transaction (e.g. status `0x05` instead of digest word `0xBA7816BF`).
- **RTL Fix**: Converted `prdata` to continuous combinational multiplexing:
  ```verilog
  assign prdata = (paddr[7:6] == 2'b00)  ? msg_block[paddr[5:2]] :
                  (paddr[7:5] == 3'b010) ? hash[paddr[4:2]] :
                  (paddr == 8'h60)       ? {29'h0, auto_pad, done, active} :
                  (paddr == 8'h64)       ? msg_len_bytes : {30'h0, done, active};
  ```
- **Re-verification**: Zero-wait APB read verified in `test_security_subsystem.S` Tests 4 and 5 (100% correct digest readback).

#### Defect D-025: AXI4-to-AHB Bridge Phantom Write on Split AW/W Channels
- **Module**: `interconnect/axi4_to_ahb/axi4_to_ahb.v`
- **Severity**: Critical (P0)
- **Description**: In `axi4_to_ahb.v`, the FSM transitioned to AHB write address phase (`htrans <= HTRANS_NONSEQ`, `hwrite <= 1'b1`) when `s_awvalid` was asserted, even if `s_wvalid` had not yet arrived. The bridge committed an AHB non-sequential transfer (`HTRANS_NONSEQ`) with un-latched, stale `hwdata`. Because AHB-to-APB asserted APB `psel` and `penable` for that cycle, the target peripheral received a phantom write with garbage data. Peripherals such as `sha256_engine.v` that ignore subsequent writes while active latched corrupted configuration parameters and failed to process the true write that arrived on the subsequent cycle.
- **RTL Fix**: Held `htrans <= HTRANS_IDLE` in `BS_IDLE` and `BS_ADDR` until `s_wvalid` is asserted, ensuring AHB write transfers only initiate when valid write data is present.
- **Re-verification**: Verified clean single-write dispatch to APB peripherals; eliminated phantom writes and double-triggering.

#### Defect D-026: Omission of FAST_SIM Parameter in Top-Level ECDSA Engine Instance
- **Module**: `top/titan_x_top/titan_x_top.v`
- **Severity**: High (P1)
- **Description**: In `titan_x_top.v`, `ecdsa_engine u_ecdsa` was instantiated without parameter propagation:
  `ecdsa_engine u_ecdsa ( ... )`.
  Because `ecdsa_engine.v` has default parameter `FAST_SIM = 0`, the internal modular multiplier `mont_mul_256` fell back to a 256-cycle bit-serial iterative multiplier. A single ECDSA P-256 signature verification requires ~100,000 modular multiplications, resulting in >25 million simulation clock cycles and causing full-chip pre-synthesis verification timeouts.
- **RTL Fix**: Parameterized the instance in `titan_x_top.v`:
  ```verilog
  ecdsa_engine #(
      .FAST_SIM(FAST_SIM)
  ) u_ecdsa (
  ```
- **Re-verification**: Simulation completes ECDSA P-256 verification in 29,267 total SoC clock cycles with authentic mathematical verification (`stat = 0x06`). All 14 tests in full SoC regression pass 100%.

#### Defect D-027: Video DMA Controller (VDMA) Missing Synthesizable S2MM & MM2S Engines (Stubs)
- **Module**: `video/vdma/vdma.v`
- **Severity**: Critical (P0)
- **Description**: `vdma.v` was a non-functional behavioral stub with all AXI4 master control signals tied low (`m_axi_awvalid=0`, `m_axi_arvalid=0`, `m_axis_mm2s_tvalid=0`, `vdma_irq=0`). The Video DMA engine could neither transfer camera frames from ISP to DDR4 (S2MM) nor stream display frames from DDR4 to HDMI (MM2S).
- **RTL Fix**: Implemented full synthesizable AXI4 Master 14 read engine (MM2S) and write engine (S2MM) with 2D stride/vsize/hsize geometry, pixel packing/unpacking, start-of-frame `tuser` / end-of-line `tlast` generation, `cr[4]` / `cr[5]` self-clearing start triggers, and `vdma_irq`.
- **Re-verification**: Standalone unit test `tb_vdma.v` passed 9/9 green; bare-metal test `test_video_pipeline.S` verified bidirectional transfers.

#### Defect D-028: Top-Level Video Subsystem Severed Internal Interconnect & Missing D-PHY Ports
- **Module**: `top/titan_x_top/titan_x_top.v`
- **Severity**: Critical (P0)
- **Description**: Top-level video pipeline had completely severed interconnections:
  1. `u_isp.m_axis_tdata` was floating unconnected.
  2. `u_vdma.s_axis_s2mm_tdata` was hardwired to `32'h0`.
  3. `u_vdma.m_axis_mm2s_tdata` was floating unconnected.
  4. `u_hdmi.s_axis_tdata` was hardwired to `32'h0`.
  5. `vdma_irq` was disconnected from the PLIC interrupt matrix (`plic_irq[17]`).
  6. MIPI D-PHY high-speed differential receiver lanes were completely omitted from top-level module ports (`rxdatahs`, `rxvalidhs`, `rxactivehs`, `rxsyncbhs` tied to 0).
- **RTL Fix**:
  1. Added top-level MIPI D-PHY ports (`mipi_rxdatahs`, `mipi_rxvalidhs`, `mipi_rxactivehs`, `mipi_rxsyncbhs`) to `titan_x_top.v`.
  2. Connected `u_isp` output stream (`isp_out_tdata`, `isp_out_tvalid`, `isp_out_tuser`, `isp_out_tlast`) to `u_vdma.s_axis_s2mm`.
  3. Connected `u_vdma.m_axis_mm2s` stream to `u_hdmi.s_axis`, and `u_hdmi.s_axis_tready` back to `u_vdma.m_axis_mm2s_tready`.
  4. Connected `vdma_irq` to `plic_irq[17]`.
- **Re-verification**: Verified end-to-end pixel pipeline in `test_video_pipeline.S` and Video BFM.

#### Defect D-029: MIPI CSI-2 RX AXI4-Stream Protocol Violation by Dropping Pixels on Downstream Backpressure
- **Module**: `video/mipi_csi2_rx/mipi_csi2_rx.v`
- **Severity**: High (P1)
- **Description**: In `mipi_csi2_rx.v`, `m_axis_tready` was declared as an input port but left completely unused. If downstream modules (ISP pipeline or VDMA) deasserted `m_axis_tready` due to memory backpressure during DDR4 write bursts, `mipi_csi2_rx` violated AXI4-Stream protocol (ARM IHI 0051A) by overwriting `axis_tdata_reg` and dropping video stream beats.
- **RTL Fix**: Implemented standard AXI4-Stream backpressure holding logic (`if (axis_tvalid_reg && !m_axis_tready) axis_tvalid_reg <= 1'b1;`) and added registered `mipi_ready_reg` for deterministic camera pacing.
- **Re-verification**: Standalone test `tb_mipi_csi2_rx.v` passed 10/10 green; full 64-pixel frame received with zero data loss in SoC regression.

#### Defect D-030: PLIC APB Synchronous prdata Latency Mismatch on Zero-Wait Bus
- **Module**: `backend/plic/plic.v`
- **Severity**: High (P1)
- **Description**: In `plic.v`, `prdata` was registered inside `always @(posedge clk)` while `pready` was hardwired to `1'b1`. On a zero-wait APB bus where the master samples `prdata` on the exact clock edge where `penable` is asserted, registering `prdata` delayed valid read data by 1 full clock cycle. Any claim or status read returned `32'h0` instead of the active interrupt source ID.
- **RTL Fix**: Converted `prdata` to continuous combinational multiplexing (`assign prdata = (paddr[23:16] == 8'h20 && paddr[3:2] == 2'b01) ? {24'h0, best_src[paddr[15:12]]} : 32'h0;`).
- **Re-verification**: Standalone test `tb_fresh_plic.v` passed 10/10; verified in `test_video_pipeline.S` Test 8 (claim register returns 17). All 15 tests in full SoC regression pass 100%.

#### Defect D-031: Gigabit Ethernet MAC (`gem_ethernet.v`) Non-functional DMA Stubs, AXI Read Latency Frame Corruption, and RX Pointer Skew
- **Module**: `peripherals/gem_ethernet/gem_ethernet.v`
- **Severity**: Critical (P0)
- **Description**:
  1. *Stubbed AXI DMA*: `m_awvalid = 1'b0`, `m_arvalid = 1'b0`, and GMII outputs were tied low or static. The core could neither transmit frames from DDR4 nor receive frames into DDR4.
  2. *Latency Bubbles & Frame Corruption in Continuous GMII Transmission*: Direct unbuffered streaming caused `gmii_tx_en` to remain asserted while waiting for AXI read data across multi-cycle memory latencies, padding frames with stale bytes, expanding frame length to 125 bytes (instead of 68 bytes), and corrupting IEEE 802.3 CRC-32 integrity.
  3. *RX DMA Descriptor Sequencing Bug*: In `RX_FSM_GATHER`, word 7 was assigned to `m_wdata` prior to word 0 being dispatched to `rx_q_ptr`, clobbering word 0 in memory.
- **RTL Fix**:
  1. Implemented full synthesizable AXI4 Master 10 DMA and GMII TX/RX state machines.
  2. Built internal 64-byte packet buffering (`tx_pkt_buf` and `rx_pkt_buf`) to isolate AXI crossbar latency from GMII physical streaming, ensuring exact 68-byte continuous GMII frames (64B payload + 4B CRC-32).
  3. Re-architected RX DMA FSM with `RX_FSM_WRITE_START` to sequence 64-bit words 0 through 7 cleanly with `m_bvalid` handshake synchronization.
- **Re-verification**: Standalone unit test `tb_gem_ethernet.v` passed 9/9; bare-metal test `test_high_speed_io.S` confirmed 68-byte TX and RX loopback with 0 CRC errors, PLIC IRQ 27 delivery, and 100% data integrity at DDR4 `0x8020_0000`.

#### Defect D-032: USB 2.0 OTG Controller (`usb_otg.v`) Stubbed DMA Engine, Inactive ULPI Transceiver, and Interrupt Stalling
- **Module**: `storage/usb_otg/usb_otg.v`
- **Severity**: Critical (P0)
- **Description**:
  1. *Stubbed DMA & ULPI Engine*: `usb_otg.v` was a non-functional shell with stubbed AXI DMA master ports (`m_awvalid=0`, `m_arvalid=0`) and non-functional ULPI logic (`ulpi_stp=0`, `ulpi_data=0`).
  2. *APB Status Register Clear Bug*: APB status register at `0x44` (`usbsts`) could not be cleared or updated via writes.
  3. *Missing ULPI Protocol Framing*: ULPI protocol state machine was missing transmit command framing, `ulpi_nxt` handshaking, and `ulpi_stp` termination.
- **RTL Fix**:
  1. Implemented synthesizable AXI4 Master 12 DMA read engine and ULPI protocol engine.
  2. Created ULPI command generator (CMD 0x48), `ulpi_nxt` handshake tracking, byte-serial data streaming, and 1-cycle `ulpi_stp` assertion upon packet termination.
  3. Implemented write-clear semantics on APB `usbsts` (offset `0x44`) and PLIC IRQ 28 interrupt generation upon transfer completion.
- **Re-verification**: Standalone unit test `tb_usb_otg.v` passed 12/12; bare-metal test `test_high_speed_io.S` verified APB configuration, PLIC IRQ 28 interrupt claim/completion, and ULPI 8-byte transfer with 0 protocol violations.

#### Defect D-033: PCIe Gen2 x4 Controller (`pcie_top.v`) Missing LTSSM FSM, PIPE 3.0 TLP Bridge, Idle Stream False MRd Decode, and Crossbar Reset Gating
- **Module**: `peripherals/pcie_top/pcie_top.v`
- **Severity**: Critical (P0)
- **Description**:
  1. *Non-functional PCIe Stub*: `pcie_top.v` lacked LTSSM link training, PIPE 3.0 physical interface mapping, and TLP translation. All AXI master controls were tied low (`m_awvalid=0`, `m_arvalid=0`).
  2. *Idle PIPE Stream False MRd Decoding*: In `TLP_IDLE`, the FSM checked `if (int_rx_data[31:24] == 8'h00 ...)` without qualifying that `int_rx_data != 64'h0` or non-zero TLP length. Whenever the link was in L0 logical idle (`int_rx_data == 0`), `pcie_top.v` falsely decoded all-zeros as a 32-bit Memory Read request to address 0, locking the controller into an infinite loop of spurious AXI reads and preventing valid incoming TLPs from ever being processed.
  3. *TLP 64-bit Address & Format Decode Bug*: TLP header decoder incorrectly extracted address from lower DW3 instead of detecting 4DW 64-bit headers (bit 29 = 1) and reading upper address fields from `int_rx_data[63:32]`, routing DMA writes to address 0 instead of `0x8040_0000`.
- **RTL & BFM Fix**:
  1. Implemented synthesizable LTSSM Link Training FSM (Detect -> Polling TS1 -> Configuration TS2 -> L0 Link Up) and TLP-to-AXI Master 11 DMA bridge for 64-bit Memory Writes (MWr), Memory Reads (MRd), and Completion with Data (CplD).
  2. Guarded `TLP_IDLE` with `int_rx_data != 64'h0` and non-zero length requirements, preventing idle bus cycles from triggering false MRd transactions.
  3. Corrected 64-bit TLP address decoding using `tlp_req_hdr0[29]` and routing `int_rx_data[63:32]` to target DDR4 `0x8040_0000`.
  4. Gated PCIe BFM TLP stimulus generation on `core_rst_n` deassertion, ensuring the SoC crossbar (`u_crossbar`) is active before initiating transactions.
- **Re-verification**: Standalone unit test `tb_pcie_top.v` passed 8/8; bare-metal test `test_high_speed_io.S` verified LTSSM link training to L0, 64-bit MWr to DDR4 `0x8040_0000` with payload `0xCAFEBABEDEADBEEF`, and 64-bit MRd with CplD verification. All 16/16 SoC regression tests pass 100% green.

#### Defect D-034: UART 16550 Empty APB Shell, Missing Baud Rate Divider, Serializer, and PLIC Interrupts
- **Module**: `peripherals/uart_16550/uart_16550.v`
- **Severity**: Critical (P0)
- **Description**: The original `uart_16550.v` was an empty APB stub that used `$write` for character output during simulation, tied `uart_irq = 1'b0`, tied `txd = 1'b1`, ignored `rxd`, and implemented no hardware baud divider, serializer, deserializer, or loopback logic. Operating systems and software attempting to configure 16550 registers (IER, FCR, LCR, MCR, LSR, MSR, SCR, DLL, DLM), poll LSR flags, or rely on PLIC IRQs 20..24 could not function.
- **RTL Fix**: Implemented a complete 16550-compatible UART engine featuring:
  1. Programmable 16-bit baud divisor latch (`DLL`/`DLM`) when `LCR[7]` (DLAB) is set.
  2. 16x baud clock generator tick with 10-bit TX serializer (`START`, 8 data bits, `STOP`) driving physical `txd`.
  3. 16x oversampling RX deserializer with 3-sample majority voting filtering glitches on `rxd`.
  4. Diagnostic loopback mode controlled by `MCR[4]` routing internal TX to RX.
  5. Accurate LSR status flags: `LSR[0]` (Data Ready), `LSR[5]` (Transmitter Holding Register Empty - THRE), `LSR[6]` (Transmitter Empty - TEMT).
  6. Zero-wait combinational `prdata` multiplexer.
  7. RDA (Receiver Data Available) and THRE interrupt generation wired to `uart_irq` for PLIC IRQ 20..24, while preserving `$write` console printing.
- **Re-verification**: Tests 1..10 in `test_peripherals.S` passed with `ABCDE` printed on UART0 and all 5 UART loopback & PLIC interrupts (IRQs 20..24) verified.

#### Defect D-035: CAN 2.0B Controller Tied-High TX, Inactive RX, Missing Frame Engine, and Interrupt Clearing Failure
- **Module**: `peripherals/can_controller/can_controller.v`
- **Severity**: Critical (P0)
- **Description**: The original `can_controller.v` tied `can_tx = 1'b1`, left `can_rx` unused, and tied `can_irq = 1'b0`. Furthermore, in self-test loopback mode, when both Transmit Interrupt (TI) and Receive Interrupt (RI) were enabled, clearing the Receive Buffer via Release Receive Buffer (`cmd_reg[2]`) failed to clear the transmit interrupt flag, keeping `can_irq` permanently asserted. This caused the PLIC to immediately re-arm pending bits and corrupt interrupt dispatching across CAN0 and CAN1.
- **RTL Fix**:
  1. Implemented full CAN 2.0B frame TX and RX engines supporting standard 11-bit IDs and extended 29-bit IDs with variable DLC (0..8 bytes) and CRC-15 generation.
  2. Implemented SJA1000-compatible APB register interface (Mode, Command, Status, Interrupt, BTR0, BTR1, ACR, AMR, TX/RX buffers).
  3. Added diagnostic self-test loopback mode (`mode_reg[2]`) routing internal `can_tx` back to `can_rx`.
  4. Synchronized interrupt clearance upon RRB command and read of interrupt register to ensure `can_irq` deasserts before PLIC complete handshakes.
- **Re-verification**: Tests 11..17 in `test_peripherals.S` passed; verified CAN0 standard frame loopback, CAN1 extended frame loopback, and PLIC IRQ 25/26 interrupt claim/complete cycles.

#### Defect D-036: SPI & I2C Masters APB Latency Mismatch, Premature Busy Deassertion, and 2-State Simulator Tri-State Collapse
- **Module**: `peripherals/spi_master/spi_master.v`, `peripherals/i2c_master/i2c_master.v`, `top/titan_x_top/titan_x_top.v`
- **Severity**: Critical (P0)
- **Description**:
  1. *Synchronous prdata Latency*: Both SPI and I2C masters registered `prdata` synchronously inside `always @(posedge clk)`, creating a 1-cycle latency mismatch on zero-wait APB reads that returned stale `32'h0`.
  2. *Delayed Busy Assertion in SPI*: SPI master asserted `busy` via a delayed sequential `start` strobe register on cycle N+1. Single-cycle polling loops executed on cycle N+1 observed `busy == 0` and prematurely exited before the transfer had even shifted bit 0.
  3. *Verilator 2-State Open-Drain Tri-State Collapse*: `i2c_master.v` modeled the open-drain SDA pad as `assign sda = sda_o ? 1'bz : 1'b0;`. In 2-state Verilator where `1'bz` evaluates to `0`, `sda` collapsed to logic 0 indefinitely, destroying START/STOP detection and address acknowledge.
- **RTL Fix**:
  1. Converted `prdata` in both `spi_master.v` and `i2c_master.v` to combinational zero-wait continuous multiplexers.
  2. Set `busy <= 1'b1;` immediately on APB write to `0x00` in `spi_master.v` to guarantee the polling loop never exits prematurely.
  3. Separated open-drain pad into `sda_o` output and `sda_i` input ports in `i2c_master.v` and `titan_x_top.v`, resolving bidirectional open-drain wired-AND deterministically in Verilator.
- **Re-verification**: Tests 18..22 in `test_peripherals.S` passed; verified SPI Master Mode 0 transmission with 0x5A readback and PLIC IRQ 15, and I2C Master address/data ACK with PLIC IRQ 16.

#### Defect D-037: CLINT APB Synchronous prdata Latency and Missing mtimecmp[0..4] Read Address Decoding
- **Module**: `backend/clint/clint.v`
- **Severity**: High (P1)
- **Description**: In `clint.v`, `prdata` was registered synchronously on clock edges, causing zero-wait APB reads to miss valid data. Furthermore, while write decoding for `mtimecmp[0..4]` was present across `0x4000..0x4027`, read decoding for the `mtimecmp` aperture was completely omitted, causing all software reads of `mtimecmp` registers to return `32'h0`.
- **RTL Fix**: Converted `prdata` to combinational continuous decoding and implemented full 64-bit readback multiplexing for `mtimecmp[0..4]` and `mtime[63:0]`.
- **Re-verification**: Test 28 in `test_peripherals.S` confirmed exact 32-bit readback of `0xCAFEBABE` from `mtimecmp[0]`.

#### Defect D-038: Watchdog Timer Counter Register Uninitialized from load_val on Write/Enable
- **Module**: `peripherals/watchdog_timer/watchdog_timer.v`
- **Severity**: High (P1)
- **Description**: In `watchdog_timer.v`, reset initialized `count` and `load_val` to `32'hFFFF_FFFF`. When software wrote a configuration value (e.g. 200) to `load_val` (offset 0x04) and enabled the timer (`wdt_en = 1`, offset 0x0C), `count` was not updated from `load_val`. The counter proceeded to count down from 4,294,967,295, requiring ~4.29 billion clock cycles (~42 seconds at 100MHz) before reaching 0 to fire the first expiry interrupt. This stalled software polling loops and timed out simulations.
- **RTL Fix**: Added immediate counter reload logic: `if (!wdt_en) count <= pwdata;` upon writing `load_val`, and `if (pwdata[0] && !wdt_en) count <= load_val;` upon asserting `wdt_en`.
- **Re-verification**: Tests 23..24 in `test_peripherals.S` passed; WDT expired cleanly in 200 cycles, asserted PLIC IRQ 14, and cleared `int_stat` upon 0xE5 kick.


