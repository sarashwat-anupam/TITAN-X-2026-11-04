#!/usr/bin/env python3
import subprocess
import sys
import time

tests = [
    ("test_rv64i", "clean_verify/tests/core/test_rv64i.hex", 200000),
    ("test_rv64m", "clean_verify/tests/core/test_rv64m.hex", 200000),
    ("test_rv64a", "clean_verify/tests/core/test_rv64a.hex", 200000),
    ("test_rv64c", "clean_verify/tests/core/test_rv64c.hex", 200000),
    ("test_rv64fpu", "clean_verify/tests/core/test_rv64fpu.hex", 200000),
    ("test_privilege", "clean_verify/tests/privilege/test_privilege.hex", 200000),
    ("test_mmu", "clean_verify/tests/mmu/test_mmu.hex", 200000),
    ("test_pmp", "clean_verify/tests/pmp/test_pmp.hex", 200000),
    ("test_monitor", "clean_verify/tests/monitor/test_monitor.hex", 200000),
    ("test_mesi_litmus", "clean_verify/tests/coherence/test_mesi_litmus.hex", 200000),
    ("test_mesi_contention", "clean_verify/tests/coherence/test_mesi_contention.hex", 200000),
    ("test_crossbar_stress", "clean_verify/tests/coherence/test_crossbar_stress.hex", 200000),
    ("test_interconnect_mpu_qos", "clean_verify/tests/coherence/test_interconnect_mpu_qos.hex", 200000),
    ("test_security_subsystem", "clean_verify/tests/security/test_security_subsystem.hex", 300000),
    ("test_video_pipeline", "clean_verify/tests/video/test_video_pipeline.hex", 300000),
    ("test_high_speed_io", "clean_verify/tests/io/test_high_speed_io.hex", 300000),
    ("test_peripherals", "clean_verify/tests/peripherals/test_peripherals.hex", 500000),
]

harness = "./clean_verify/tb/obj_dir/Vtitan_x_top"

passed = 0
failed = 0
results = []

print("=" * 80)
print(f" TITAN-X Clean-Room Pre-Synthesis Verification: Full 17-Test Regression Suite")
print("=" * 80)

for name, hex_path, max_cycles in tests:
    cmd = [harness, "--hex", hex_path, "--cycles", str(max_cycles)]
    t0 = time.time()
    res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    t_elapsed = time.time() - t0
    
    # Check output
    status_pass = ("Status: ✅ PASSED" in res.stdout) or ("Status: PASSED" in res.stdout)
    exit_code_zero = (res.returncode == 0)
    has_pass_str = ("PASS" in res.stdout)
    
    # Extract cycle count if possible
    cycles = "N/A"
    for line in res.stdout.splitlines():
        if "Simulation Finished at Cycle:" in line:
            cycles = line.split(":")[-1].strip()
            break
            
    is_ok = exit_code_zero and status_pass
    if is_ok:
        passed += 1
        verdict = "✅ PASSED"
    else:
        failed += 1
        verdict = f"❌ FAILED (code {res.returncode})"
        
    results.append((name, verdict, cycles, f"{t_elapsed:.2f}s"))
    print(f"[{len(results):02d}/17] {name:<28} : {verdict} (cycles: {cycles}, elapsed: {t_elapsed:.2f}s)")

print("=" * 80)
print(f" Regression Suite Results: {passed}/17 PASSED, {failed}/17 FAILED")
print("=" * 80)

if failed > 0:
    print("REGRESSION FAILED!")
    sys.exit(1)
else:
    print("ALL 17 TESTS PASSED (100% GREEN)!")
    sys.exit(0)
