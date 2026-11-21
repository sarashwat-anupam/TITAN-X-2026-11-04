#!/usr/bin/env python3
import subprocess
import os
import sys

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
os.chdir(REPO_ROOT)

modules_to_check = [
    ("rv_decode", ["frontend/rv_decode/rv_decode.v"]),
    ("rv_c_decoder", ["frontend/rv_decode/rv_c_decoder.v"]),
    ("rv_fetch", ["frontend/rv_fetch/rv_fetch.v"]),
    ("rv_execute", ["backend/rv_execute/rv_execute.v", "backend/rv_csr/rv_csr.v"]),
    ("rv_mem", ["backend/rv_mem/rv_mem.v"]),
    ("rv_writeback", ["backend/rv_writeback/rv_writeback.v"]),
    ("rv_csr", ["backend/rv_csr/rv_csr.v"]),
    ("rv_ptw", ["backend/rv_ptw/rv_ptw.v"]),
    ("rv_tlb", ["backend/rv_tlb/rv_tlb.v"]),
    ("rv_pmp", ["backend/rv_pmp/rv_pmp.v"]),
    ("rv_bpu", ["frontend/rv_bpu/rv_bpu.v"]),
    ("axi4_crossbar", ["interconnect/axi4_crossbar/axi4_crossbar.v"]),
    ("axi4_to_ahb", ["interconnect/axi4_to_ahb/axi4_to_ahb.v"]),
    ("ahb_to_apb", ["interconnect/ahb_to_apb/ahb_to_apb.v"]),
    ("interconnect_mpu", ["interconnect/interconnect_mpu/mpu.v"]),
    ("qos_controller", ["interconnect/qos_controller/qos_controller.v"]),
    ("mmu_arbiter", ["interconnect/mmu_arbiter/mmu_arbiter.v"]),
    ("l2_snoop_filter", ["memory/l2_snoop_filter/l2_snoop_filter.v"]),
    ("l2_cache_ctrl", ["memory/l2_cache_ctrl/l2_cache_ctrl.v"]),
    ("clint", ["backend/clint/clint.v"]),
    ("plic", ["backend/plic/plic.v"]),
    ("uart_16550", ["peripherals/uart_16550/uart_16550.v"]),
    ("gpio_ctrl", ["peripherals/gpio_ctrl/gpio_ctrl.v"]),
    ("watchdog_timer", ["peripherals/watchdog_timer/watchdog_timer.v"]),
    ("spi_master", ["peripherals/spi_master/spi_master.v"]),
    ("i2c_master", ["peripherals/i2c_master/i2c_master.v"]),
    ("sha256_engine", ["peripherals/sha256_engine/sha256_engine.v"]),
    ("aes_engine", ["peripherals/aes_engine/aes_engine.v"]),
    ("ecdsa_engine", ["security/ecdsa_engine/ecdsa_engine.v"]),
    ("trng", ["peripherals/trng/trng.v"]),
    ("drbg", ["security/drbg/drbg.v"]),
    ("secure_boot", ["security/secure_boot/secure_boot.v"])
]

total_latches = 0
results = []

incdirs = [
    "-Iincludes", "-Ibackend/rv_core_top", "-Ibackend/rv_execute", "-Ibackend/rv_mem",
    "-Ibackend/rv_writeback", "-Ibackend/rv_regfile", "-Ibackend/rv_csr", "-Ibackend/rv_mmu",
    "-Ibackend/rv_tlb", "-Ibackend/rv_ptw", "-Ibackend/rv_pmp", "-Ibackend/rv_fpu",
    "-Ibackend/rv_dcache", "-Ibackend/rv_debug", "-Ibackend/rv_monitor_core",
    "-Ibackend/clint", "-Ibackend/plic", "-Ifrontend/rv_fetch", "-Ifrontend/rv_decode",
    "-Ifrontend/rv_icache", "-Ifrontend/rv_bpu", "-Iinterconnect", "-Iinterconnect/axi4_crossbar",
    "-Iinterconnect/axi4_to_ahb", "-Iinterconnect/ahb_to_apb", "-Iinterconnect/interconnect_mpu",
    "-Iinterconnect/qos_controller", "-Iinterconnect/mmu_arbiter", "-Imemory/l2_cache_top",
    "-Imemory/l2_cache_ctrl", "-Imemory/l2_tag_array", "-Imemory/l2_data_array",
    "-Imemory/l2_snoop_filter", "-Imemory/ddr_ctrl_top", "-Imemory/ddr_scheduler",
    "-Imemory/ddr_phy_if", "-Imemory/sram_32x64_180nm", "-Imemory/sram_512kx8_180nm",
    "-Imemory/mbist", "-Iperipherals/uart_16550", "-Iperipherals/can_controller",
    "-Iperipherals/gpio_ctrl", "-Iperipherals/watchdog_timer", "-Iperipherals/spi_master",
    "-Iperipherals/i2c_master", "-Iperipherals/rtc", "-Iperipherals/gem_ethernet",
    "-Iperipherals/gem_sgmii_pcs", "-Iperipherals/pcie_top", "-Iperipherals/pcie_pipe_if",
    "-Iperipherals/trng", "-Iperipherals/sha256_engine", "-Iperipherals/aes_engine",
    "-Isecurity/secure_boot", "-Isecurity/drbg", "-Isecurity/ecdsa_engine",
    "-Isecurity/efuse_ctrl", "-Isecurity/envm_ctrl", "-Istorage/usb_otg",
    "-Istorage/mmc_controller", "-Istorage/qspi_controller", "-Ivideo/vdma",
    "-Ivideo/mipi_csi2_rx", "-Ivideo/isp_pipeline", "-Ivideo/hdmi_ctrl",
    "-Itop/axi_sram", "-Itop/axi_rom", "-Itop/titan_x_top", "-Icommon/sync_cell",
    "-Icommon/reset_sync", "-Icommon/cdc_sync", "-Icommon/fifo_sync", "-Icommon/fifo_async",
    "-Icommon"
]
inc_str = " ".join(incdirs)

for mod_name, files in modules_to_check:
    file_str = " ".join(files)
    tcl_script = f"""
    verilog_defaults -add {inc_str}
    read_verilog {file_str}
    hierarchy -check -top {mod_name}
    proc
    select -list t:$dlatch t:$adlatch
    """
    
    cmd = ["yosys", "-q", "-p", tcl_script]
    p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    
    # Check lines in output
    latch_count = 0
    latch_details = []
    for line in p.stdout.splitlines():
        line = line.strip()
        if line.startswith(f"\\{mod_name}/$") or "$dlatch" in line or "$adlatch" in line:
            latch_count += 1
            latch_details.append(line)
            
    total_latches += latch_count
    status = "PASS (0 latches)" if latch_count == 0 else f"FAIL ({latch_count} latches)"
    results.append((mod_name, status, latch_details))
    print(f"[{status}] Module: {mod_name}")

print("\n" + "="*60)
print(f" ZERO-LATCH AUDIT COMPLETE: Total Inferred Latches = {total_latches}")
print("="*60)

with open("clean_verify/reports/zero_latch_audit.md", "w") as f:
    f.write("# Zero-Latch Combinational Audit Report\n\n")
    f.write(f"**Total Inferred Latches**: {total_latches}\n\n")
    f.write("| Module | Latch Count | Status |\n")
    f.write("|---|---|---|\n")
    for mod_name, status, details in results:
        cnt = "0" if "PASS" in status else status
        f.write(f"| `{mod_name}` | {cnt} | {'✅ PASS' if 'PASS' in status else '❌ FAIL'} |\n")
    if total_latches > 0:
        f.write("\n### Latch Details\n")
        for mod_name, status, details in results:
            if details:
                f.write(f"\n#### `{mod_name}`\n")
                for d in details:
                    f.write(f"- `{d}`\n")

if total_latches > 0:
    sys.exit(1)
