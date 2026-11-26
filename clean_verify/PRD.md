# SMVDU TITAN-X SoC: Pre-Synthesis Signoff Verification PRD

## Overview
This PRD serves as the immutable task contract for the pre-synthesis verification signoff of the SMVDU TITAN-X 5-Core Heterogeneous SoC. All testing is conducted strictly in `clean_verify/` with zero legacy testbench reuse, no assertion masking, RTL-first defect remediation, and reproducible execution via the master `Makefile`.

---

## Task 1: Environment & Workspace Initialization
- Create master `Makefile` in `clean_verify/` supporting discrete phase execution targets (`make lint`, `make unit`, `make coherence`, `make bfm`, `make linux`, `make coverage`, `make all`).
- Set up include paths, compiler flags, and tool wrappers.
- Initialize `clean_verify/reports/DEFECT_REGISTER.md`.

## Task 2: Phase 1 - Full SoC Verilator Static Linting
- Execute `verilator -Wall --lint-only` over the top-level `titan_x_top` and all instantiations with complete include paths (`includes/`, `backend/`, `frontend/`, `interconnect/`, etc.).
- Audit all warnings: width mismatches, undeclared nets, circular combinational paths, missing ports, or unhandled bit slices.
- Fix all RTL issues directly in the `.v` source files. Produce `clean_verify/reports/phase1_lint_report.md`.

## Task 3: Phase 1 - Zero-Latch Combinational Logic Audit
- Author and run Yosys netlist analysis script (`clean_verify/scripts/check_latches.tcl`).
- Inspect all `always @(*)` and combinational blocks across the entire hierarchy to guarantee 0 accidental latches are inferred.
- Remediate any incomplete case/if statements in RTL if discovered.

## Task 4: Phase 1 - CDC & Multi-Clock Domain Reset Synchronization Verification
- Inspect and audit clock domain crossing boundaries across all 7 clock domains (`clk`, `pipe_clk`, `eth_tx_clk`, `eth_rx_clk`, `ulpi_clk`, `mipi_rxbyteclkhs`, `hdmi_clk_pixel`, `hdmi_clk_tmds`, `rtc_clk`).
- Verify proper usage of `sync_cell`, `cdc_sync`, `fifo_async`, and `reset_sync`.
- Verify that reset deassertion is synchronized to prevent metastability or glitching.

## Task 5: Phase 2 - Clean-Room Verilator C++ Top-Level Testbench Harness
- Implement `clean_verify/tb/tb_titan_x_top.cpp` from scratch.
- Integrate multi-clock generation, synchronous reset sequencing, FST waveform dumping, execution cycle limiting, and error trapping.
- Implement sparse 64-bit physical memory model (`clean_verify/tb/memory_model.hpp`) supporting DDR4 (2GB), Boot ROM (64KB), and on-chip SRAM (512KB).

## Task 6: Phase 2 - Formal AXI4 Protocol Assertion Checker
- Author `clean_verify/tb/axi4_monitor.hpp` implementing SVA / C++ assertion checks for all 16 AXI Masters and 9 Slaves.
- Check AXI4 protocol rules: handshake stability (VALID must remain asserted until READY), burst length boundaries, 4KB address boundary crossing rules, response ordering, and write strobe validity.

## Task 7: Phase 2 - Spike Golden Co-Simulation Differential Execution Bridge
- Implement `clean_verify/tb/spike_cosim_bridge.hpp` interfacing with Spike RISC-V ISA simulator.
- Compare instruction commit stream, program counter (PC), destination register, writeback data, and CSR state transitions between RTL cores and Spike.

## Task 8: Phase 3 - RV64GC Core Datapath & Arithmetic Stress Verification
- Create baremetal assembly and C tests verifying RV64I (ALU, shifts, sign extensions), RV64M (multiplication, division, remainders with extreme corner cases: 0/0, overflow -2^63/-1), RV64A (LR/SC, AMO operations), and RV64C (compressed instructions and unaligned boundaries).
- Execute on `rv_core_top` and verify bit-exact register retirement against golden reference.

## Task 9: Phase 3 - IEEE-754 FPU Execution Verification
- Author test suites for single and double precision floating-point arithmetic (RV64F, RV64D).
- Verify rounding modes, NaN generation/propagation, subnormal numbers, and floating-point CSR (`fcsr`) flag updates.

## Task 10: Phase 3 - M/S/U Privilege Mode Transitions, Traps, and CSR Access
- Test privilege transitions between Machine (M), Supervisor (S), and User (U) modes using `ecall`, `mret`, `sret`.
- Verify trap delegation (`medeleg`, `mideleg`), vectored and direct trap handling (`mtvec`, `stvec`), and trap value registers (`mtval`, `stval`).

## Task 11: Phase 3 - Sv39 Virtual Memory, Page Table Walker, and TLB Shootdown
- Implement test suite configuring 3-level page tables (VPN2 -> VPN1 -> VPN0) in DRAM.
- Verify hardware Page Table Walker (PTW) memory requests via Master 15 through `mmu_arbiter`.
- Verify TLB hit/miss handling, permission checks (R/W/X/U), and TLB invalidation via `sfence.vma`.

## Task 12: Phase 3 - 8-Region Physical Memory Protection (PMP) Enforcement
- Configure PMP registers (`pmpcfg0..1`, `pmpaddr0..7`) across all addressing modes (TOR, NA4, NAPOT).
- Verify access permission enforcement (R/W/X) across M, S, and U modes, and confirm exception generation on unauthorized access.

## Task 13: Phase 3 - Hart 4 Monitor Core Isolation & Security Access
- Verify RV64IMAC execution on `rv_monitor_core` (Hart 4).
- Confirm non-coherent access to security registers and MPU while verifying hardware isolation from application cores 0..3.

## Task 14: Phase 4 - Multi-Core MESI Cache Coherence Litmus Suite
- Author multi-hart concurrent litmus tests running across Harts 0..3: Store Buffering (SB), Message Passing (MP), Independent Reads of Independent Writes (IRIW), and Dekker's algorithm.
- Verify memory consistency, memory fences (`fence`, `fence.i`), and hardware MESI state transitions.

## Task 15: Phase 4 - True & False Cache-Line Sharing and Contention Hammer
- Author stress tests with multiple harts hammering the exact same 64-byte cache line (MESI Modified -> Invalid -> Modified bouncing).
- Author false-sharing stress tests where different harts write to adjacent 64-bit words in the same 64-byte cache line.

## Task 16: Phase 4 - AXI4 Crossbar Randomized Backpressure, Out-of-Order ID, and Burst Stress
- Implement crossbar stress injector in `tb_titan_x_top.cpp` applying randomized backpressure (delays on AWREADY, WREADY, ARREADY).
- Stress concurrent transactions across all 16 masters to all 9 slaves, verifying arbitration fairness, starvation freedom, and DECERR responses on unmapped addresses.

## Task 17: Phase 4 - Interconnect MPU & QoS Controller Bus Protection Enforcement
- Program `interconnect_mpu` with locked and restricted memory apertures.
- Verify that illegal transactions are blocked with DECERR/SLVERR and generate security interrupts.
- Verify bandwidth regulation and priority boosting in `qos_controller`.

## Task 18: Phase 5 - Security Subsystem BFM
- Author `clean_verify/bfm/bfm_security.hpp`.
- Verify Secure Boot Root-of-Trust authentication of ROM image (`boot_pass`), NIST SHA-256 test vectors, AES-256 ECB/CBC encryption/decryption, ECDSA P-256 signing and verification, and TRNG/DRBG entropy generation.

## Task 19: Phase 5 - Video Pipeline BFM
- Author `clean_verify/bfm/bfm_video.hpp`.
- Verify VDMA frame streaming (MM2S frame read, S2MM frame capture), HDMI TMDS packet generation, and MIPI CSI-2 RX to ISP pipeline processing.

## Task 20: Phase 5 - High-Speed I/O BFMs
- Author `clean_verify/bfm/bfm_ethernet.hpp`, `bfm_usb.hpp`, `bfm_pcie.hpp`.
- Verify GMII Ethernet packet TX/RX loopback with CRC checking, USB 2.0 ULPI protocol handshake and packet transfers, and PCIe Gen2 x4 PIPE 3.0 configuration and memory TLP transactions.

## Task 21: Phase 5 - Low-Speed Peripherals BFM
- Author `clean_verify/bfm/bfm_peripherals.hpp`.
- Verify UART0..4 FIFO loopback, CAN0/1 frame transmit/receive, SPI master transfers, I2C transactions, Watchdog timer timeout hard reset, RTC clock ticking, and CLINT/PLIC interrupt delivery to all 5 harts.

## Task 22: Phase 6 - Multi-Core Constrained-Random Instruction Stream Regression [SIGNED OFF]
- Generate randomized multi-core instruction streams with pipeline hazard injection (RAW, WAR, WAW), branch thrashing, and memory arena contention across Harts 0..3.
- Verify bit-exact register matching against Spike reference model across 100,000+ dynamic instructions.
- Status: **100% COMPLETE & SIGNED OFF** (100,298 dynamic instructions retired with 0 mismatches, 0 violations at cycle 331,028).

## Task 23: Phase 6 - Full Multi-Core Linux OS / OpenSBI Boot Bringup on TITAN-X Hardware [SIGNED OFF]
- Create hardware-accurate Device Tree Source (`clean_verify/linux/titan_x.dts`) and compile to `titan_x.dtb`.
- Package OpenSBI firmware and S-mode OS payload image.
- Boot OpenSBI on TITAN-X in Verilator, verifying early console printout, 4-hart symmetric enumeration, ACLINT-MSWI IPI, ACLINT-MTIMER, and S-mode OS payload execution.
- Status: **100% COMPLETE & SIGNED OFF** (OpenSBI v1.2 banner, 4 symmetric application harts enumerated `0*, 1*, 2*, 3*`, ACLINT-MSWI IPI initialized, ACLINT-MTIMER @ 10MHz initialized, S-mode OS payload reached and executing `Test payload running` at cycle 65,582,996 with 9,549,311 instructions retired).

## Task 24: Phase 6 - Comprehensive Code & Functional Coverage Signoff Report
- Compile with Verilator `--coverage` and run full regression suite.
- Extract line, branch, toggle, and FSM coverage data.
- Author final `clean_verify/reports/SIGNOFF_REPORT.md` documenting verification metrics, defect log, and tapeout readiness declaration.
