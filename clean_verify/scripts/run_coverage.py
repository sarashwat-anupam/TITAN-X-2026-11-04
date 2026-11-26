#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# SMVDU TITAN-X: Comprehensive Code & Functional Coverage Runner
# Runs full 17-test regression suite + multi-core random instruction stream with coverage instrumentation,
# merges coverage databases, generates annotated sources, and computes subsystem coverage breakdown.

import os
import glob
import subprocess
import sys
import time

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
TB_DIR = os.path.join(REPO_ROOT, "clean_verify", "tb")
REPORTS_DIR = os.path.join(REPO_ROOT, "clean_verify", "reports")
HARNESS = os.path.join(TB_DIR, "obj_dir", "Vtitan_x_top")

tests = [
    ("test_rv64i", "clean_verify/tests/core/test_rv64i.hex", 200000, []),
    ("test_rv64m", "clean_verify/tests/core/test_rv64m.hex", 200000, []),
    ("test_rv64a", "clean_verify/tests/core/test_rv64a.hex", 200000, []),
    ("test_rv64c", "clean_verify/tests/core/test_rv64c.hex", 200000, []),
    ("test_rv64fpu", "clean_verify/tests/core/test_rv64fpu.hex", 200000, []),
    ("test_privilege", "clean_verify/tests/privilege/test_privilege.hex", 200000, []),
    ("test_mmu", "clean_verify/tests/mmu/test_mmu.hex", 200000, []),
    ("test_pmp", "clean_verify/tests/pmp/test_pmp.hex", 200000, []),
    ("test_monitor", "clean_verify/tests/monitor/test_monitor.hex", 200000, []),
    ("test_mesi_litmus", "clean_verify/tests/coherence/test_mesi_litmus.hex", 200000, []),
    ("test_mesi_contention", "clean_verify/tests/coherence/test_mesi_contention.hex", 200000, []),
    ("test_crossbar_stress", "clean_verify/tests/coherence/test_crossbar_stress.hex", 200000, []),
    ("test_interconnect_mpu_qos", "clean_verify/tests/coherence/test_interconnect_mpu_qos.hex", 200000, []),
    ("test_security_subsystem", "clean_verify/tests/security/test_security_subsystem.hex", 300000, []),
    ("test_video_pipeline", "clean_verify/tests/video/test_video_pipeline.hex", 300000, []),
    ("test_high_speed_io", "clean_verify/tests/io/test_high_speed_io.hex", 300000, []),
    ("test_peripherals", "clean_verify/tests/peripherals/test_peripherals.hex", 500000, []),
    ("test_random_multicore", "clean_verify/tests/random/test_random_multicore.hex", 600000, [
        "--spike-log", "clean_verify/reports/spike_multicore_random.log",
        "--cosim-end-pc", "0x800043c2"
    ]),
]

def run_tests():
    os.makedirs(REPORTS_DIR, exist_ok=True)
    # Clean previous coverage temp files
    for old_cov in glob.glob(os.path.join(REPORTS_DIR, "cov_*.dat")):
        try:
            os.remove(old_cov)
        except OSError:
            pass

    print("=" * 80)
    print(" SMVDU TITAN-X Pre-Synthesis Verification: Coverage Regression Suite")
    print("=" * 80)

    results = []
    passed = 0
    failed = 0

    for idx, (name, hex_path, max_cycles, extra_args) in enumerate(tests, 1):
        cov_file = os.path.join(REPORTS_DIR, f"cov_{name}.dat")
        cmd = [
            HARNESS,
            "--hex", hex_path,
            "--cycles", str(max_cycles),
            "--coverage-file", cov_file
        ] + extra_args

        t0 = time.time()
        res = subprocess.run(cmd, cwd=REPO_ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        t_elapsed = time.time() - t0

        status_pass = ("Status: ✅ PASSED" in res.stdout) or ("Status: PASSED" in res.stdout)
        exit_code_zero = (res.returncode == 0)

        cycles = "N/A"
        for line in res.stdout.splitlines():
            if "Simulation Finished at Cycle:" in line:
                cycles = line.split(":")[-1].strip()
                break

        if exit_code_zero and status_pass:
            passed += 1
            verdict = "✅ PASSED"
        else:
            failed += 1
            verdict = f"❌ FAILED (code {res.returncode})"

        cov_status = "COV_OK" if os.path.exists(cov_file) else "NO_COV"
        results.append((name, verdict, cycles, f"{t_elapsed:.2f}s", cov_status))
        print(f"[{idx:02d}/{len(tests)}] {name:<28} : {verdict} (cycles: {cycles}, elapsed: {t_elapsed:.2f}s, cov: {cov_status})")

    print("=" * 80)
    print(f" Regression Results: {passed}/{len(tests)} PASSED, {failed}/{len(tests)} FAILED")
    print("=" * 80)

    if failed > 0:
        print("REGRESSION FAILED! Aborting coverage aggregation.")
        sys.exit(1)

def merge_and_analyze_coverage():
    cov_files = sorted(glob.glob(os.path.join(REPORTS_DIR, "cov_*.dat")))
    if not cov_files:
        print("Error: No coverage data files found to merge.")
        sys.exit(1)

    merged_dat = os.path.join(REPORTS_DIR, "coverage.dat")
    info_file = os.path.join(REPORTS_DIR, "coverage.info")
    rank_file = os.path.join(REPORTS_DIR, "coverage_rank.txt")
    annotated_dir = os.path.join(REPORTS_DIR, "annotated")

    print(f"\nMerging {len(cov_files)} coverage database files into {merged_dat}...")
    cmd_merge = ["verilator_coverage", "-write", merged_dat] + cov_files
    subprocess.run(cmd_merge, cwd=REPO_ROOT, check=True)

    print(f"Writing LCOV info format to {info_file}...")
    cmd_info = ["verilator_coverage", "-write-info", info_file, merged_dat]
    subprocess.run(cmd_info, cwd=REPO_ROOT, check=True)

    print(f"Generating test ranking report into {rank_file}...")
    with open(rank_file, "w") as rf:
        subprocess.run(["verilator_coverage", "--rank", merged_dat], cwd=REPO_ROOT, stdout=rf, stderr=subprocess.STDOUT)

    print(f"Generating annotated source coverage in {annotated_dir}...")
    os.makedirs(annotated_dir, exist_ok=True)
    subprocess.run(["verilator_coverage", "--annotate", annotated_dir, merged_dat], cwd=REPO_ROOT, check=True)

    print("\nAnalyzing coverage data by subsystem...")
    subsystems = {
        "Core Top & Pipeline": ["rv_core_top", "rv_fetch", "rv_decode", "rv_execute", "rv_mem", "rv_writeback", "rv_regfile", "rv_csr", "rv_bpu"],
        "Memory Management & Protection": ["rv_mmu", "rv_ptw", "rv_tlb", "rv_pmp"],
        "Hardware Floating-Point (FPU)": ["rv_fpu"],
        "RV Security Monitor Core": ["rv_monitor_core"],
        "L1 & L2 Cache Coherence (MESI)": ["rv_icache", "rv_dcache", "l2_cache_top", "l2_cache_ctrl", "l2_tag_array", "l2_data_array", "l2_snoop_filter"],
        "AXI4 Interconnect & QoS": ["axi4_crossbar", "interconnect_mpu", "qos_controller", "axi4_to_ahb", "ahb_to_apb", "mmu_arbiter", "apb_bridge", "axi4_burst_to_lite"],
        "Memory Subsystem & Controllers": ["ddr_ctrl_top", "ddr_scheduler", "ddr_phy_if", "axi_sram", "axi_rom", "sram_32x64_180nm", "sram_512kx8_180nm", "mbist"],
        "Hardware Cryptographic Engines": ["sha256_engine", "aes_engine", "trng", "ecdsa_engine", "secure_boot", "drbg", "efuse_ctrl", "envm_ctrl"],
        "Video Subsystem": ["mipi_csi2_rx", "isp_pipeline", "vdma", "hdmi_ctrl"],
        "High-Speed I/O": ["gem_ethernet", "gem_sgmii_pcs", "usb_otg", "pcie_top", "pcie_pipe_if", "mmc_controller", "qspi_controller"],
        "Low-Speed Peripherals & System": ["uart_16550", "can_controller", "spi_master", "i2c_master", "gpio_ctrl", "watchdog_timer", "rtc", "clint", "plic"],
        "Top-Level SoC Integration": ["titan_x_top", "sync_cell", "reset_sync", "cdc_sync", "fifo_sync", "fifo_async", "BUFX4", "stdcell_stubs"],
    }

    file_stats = {}
    current_file = None
    if os.path.exists(info_file):
        with open(info_file, "r") as f:
            for line in f:
                line = line.strip()
                if line.startswith("SF:"):
                    current_file = line[3:]
                    if current_file not in file_stats:
                        file_stats[current_file] = {"lines_found": 0, "lines_hit": 0}
                elif line.startswith("DA:") and current_file:
                    parts = line[3:].split(",")
                    if len(parts) >= 2:
                        hits = int(parts[1])
                        file_stats[current_file]["lines_found"] += 1
                        if hits > 0:
                            file_stats[current_file]["lines_hit"] += 1
                elif line.startswith("end_of_record"):
                    current_file = None

    summary_path = os.path.join(REPORTS_DIR, "coverage_summary.txt")
    subsystem_totals = {sub: {"found": 0, "hit": 0} for sub in subsystems.keys()}

    total_found = 0
    total_hit = 0

    for fpath, stats in file_stats.items():
        total_found += stats["lines_found"]
        total_hit += stats["lines_hit"]
        matched_sub = "Top-Level SoC Integration"
        for sub_name, keywords in subsystems.items():
            if any(k in fpath for k in keywords):
                matched_sub = sub_name
                break
        subsystem_totals[matched_sub]["found"] += stats["lines_found"]
        subsystem_totals[matched_sub]["hit"] += stats["lines_hit"]

    subsystem_coverage = {}
    for sub_name, data in subsystem_totals.items():
        found = data["found"]
        hit = data["hit"]
        pct = (hit / found * 100.0) if found > 0 else 0.0
        subsystem_coverage[sub_name] = (found, hit, pct)

    total_pct = (total_hit / total_found * 100.0) if total_found > 0 else 0.0

    with open(summary_path, "w") as sf:
        sf.write("=" * 85 + "\n")
        sf.write(" SMVDU TITAN-X Clean-Room Verification: Comprehensive Code & Functional Coverage\n")
        sf.write("=" * 85 + "\n")
        sf.write(f"{'Subsystem / Module Area':<38} | {'Found Lines':>12} | {'Hit Lines':>10} | {'Coverage':>10}\n")
        sf.write("-" * 85 + "\n")
        for sub_name, (found, hit, pct) in subsystem_coverage.items():
            sf.write(f"{sub_name:<38} | {found:>12} | {hit:>10} | {pct:>9.2f}%\n")
        sf.write("=" * 85 + "\n")
        sf.write(f"{'OVERALL TITAN-X SOC AGGREGATE':<38} | {total_found:>12} | {total_hit:>10} | {total_pct:>9.2f}%\n")
        sf.write("=" * 85 + "\n")

    with open(summary_path, "r") as sf:
        print(sf.read())

if __name__ == "__main__":
    run_tests()
    merge_and_analyze_coverage()
