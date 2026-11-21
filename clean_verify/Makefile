# SMVDU TITAN-X: Clean-Room Verification Master Makefile
SHELL := /bin/bash
REPO_ROOT := $(abspath ..)

.PHONY: all lint latch cdc unit coherence bfm linux coverage clean help

help:
	@echo "SMVDU TITAN-X Clean-Room Verification Master Makefile"
	@echo "Targets:"
	@echo "  make lint       - Phase 1: Run Verilator lint-only on entire SoC"
	@echo "  make latch      - Phase 1: Run Yosys latch detection on all modules"
	@echo "  make cdc        - Phase 1: Run CDC and reset domain verification"
	@echo "  make tb_build   - Phase 2: Compile Verilator C++ testbench harness"
	@echo "  make unit       - Phase 3: Run RV64GC core/privilege/MMU/PMP unit tests"
	@echo "  make coherence  - Phase 4: Run multi-core MESI cache coherence litmus tests"
	@echo "  make bfm        - Phase 5: Run subsystem & peripheral BFMs"
	@echo "  make linux      - Phase 6: Run full multi-core Linux boot regression"
	@echo "  make coverage   - Phase 6: Generate code and functional coverage report"
	@echo "  make all        - Run all phases sequentially from scratch"
	@echo "  make clean      - Clean all simulation and build artifacts"

lint:
	@echo "=== [Phase 1] Static Linting ==="
	@bash scripts/run_lint.sh

latch:
	@echo "=== [Phase 1] Zero-Latch Audit ==="
	@yosys -s scripts/check_latches.tcl

cdc:
	@echo "=== [Phase 1] CDC & Reset Domain Audit ==="
	@python3 scripts/audit_cdc.py

tb_build:
	@echo "=== [Phase 2] Build Verilator Top Harness ==="
	@make -C tb build

unit:
	@echo "=== [Phase 3] RV64GC Core & Privilege Unit Tests ==="
	@python3 tests/run_unit_tests.py

coherence:
	@echo "=== [Phase 4] Multi-Core MESI Coherence & Crossbar Stress ==="
	@python3 tests/run_coherence_suite.py

bfm:
	@echo "=== [Phase 5] Subsystem & Peripheral BFMs ==="
	@python3 tests/run_bfm_suite.py

linux:
	@echo "=== [Phase 6] Full Multi-Core Linux Boot Bringup ==="
	@bash linux/run_linux_boot.sh

coverage:
	@echo "=== [Phase 6] Coverage Report Generation ==="
	@python3 scripts/generate_coverage_report.py

all: lint latch cdc tb_build unit coherence bfm linux coverage
	@echo "=== ALL VERIFICATION PHASES COMPLETED AND VERIFIED ==="

clean:
	@rm -rf obj_dir tb/obj_dir *.vcd *.fst *.log
	@echo "Clean completed."
