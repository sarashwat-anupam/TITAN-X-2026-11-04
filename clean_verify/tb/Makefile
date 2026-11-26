# SPDX-License-Identifier: Apache-2.0
# SMVDU TITAN-X: Clean-Room Testbench Makefile
SHELL := /bin/bash
REPO_ROOT := $(abspath ../..)

VERILATOR := verilator
JOBS ?= 2
COVERAGE ?= 0
VERILATOR_FLAGS := -Wno-fatal -Wno-PINMISSING -Wno-DECLFILENAME -Wno-TIMESCALEMOD \
                   -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-PINCONNECTEMPTY -Wno-SYNCASYNCNET \
                   -Wno-BLKSEQ -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC -Wno-COMBDLY -Wno-MULTIDRIVEN \
                   -Wno-CASEINCOMPLETE -Wno-LATCH -Wno-UNDRIVEN -Wno-UNOPTFLAT -Wno-UNSIGNED \
                   -O3 --trace-fst -DFAST_SIM=1 -DFAST_INIT=1 -GFAST_SIM=1 \
                   --top-module titan_x_top \
                   --cc --exe --build -j $(JOBS) \
                   --CFLAGS "-std=c++17 -I$(abspath .) -I$(abspath ../bfm)" \
                    --LDFLAGS "-lz"

ifeq ($(COVERAGE),1)
    VERILATOR_FLAGS += --coverage-line --coverage-user
endif

INCDIRS := -I$(REPO_ROOT)/includes \
           -I$(REPO_ROOT)/backend/rv_core_top \
           -I$(REPO_ROOT)/backend/rv_execute \
           -I$(REPO_ROOT)/backend/rv_mem \
           -I$(REPO_ROOT)/backend/rv_writeback \
           -I$(REPO_ROOT)/backend/rv_regfile \
           -I$(REPO_ROOT)/backend/rv_csr \
           -I$(REPO_ROOT)/backend/rv_mmu \
           -I$(REPO_ROOT)/backend/rv_tlb \
           -I$(REPO_ROOT)/backend/rv_ptw \
           -I$(REPO_ROOT)/backend/rv_pmp \
           -I$(REPO_ROOT)/backend/rv_fpu \
           -I$(REPO_ROOT)/backend/rv_dcache \
           -I$(REPO_ROOT)/backend/rv_debug \
           -I$(REPO_ROOT)/backend/rv_monitor_core \
           -I$(REPO_ROOT)/backend/clint \
           -I$(REPO_ROOT)/backend/plic \
           -I$(REPO_ROOT)/frontend/rv_fetch \
           -I$(REPO_ROOT)/frontend/rv_decode \
           -I$(REPO_ROOT)/frontend/rv_icache \
           -I$(REPO_ROOT)/frontend/rv_bpu \
           -I$(REPO_ROOT)/interconnect \
           -I$(REPO_ROOT)/interconnect/axi4_crossbar \
           -I$(REPO_ROOT)/interconnect/axi4_to_ahb \
           -I$(REPO_ROOT)/interconnect/ahb_to_apb \
           -I$(REPO_ROOT)/interconnect/interconnect_mpu \
           -I$(REPO_ROOT)/interconnect/qos_controller \
           -I$(REPO_ROOT)/interconnect/mmu_arbiter \
           -I$(REPO_ROOT)/memory/l2_cache_top \
           -I$(REPO_ROOT)/memory/l2_cache_ctrl \
           -I$(REPO_ROOT)/memory/l2_tag_array \
           -I$(REPO_ROOT)/memory/l2_data_array \
           -I$(REPO_ROOT)/memory/l2_snoop_filter \
           -I$(REPO_ROOT)/memory/ddr_ctrl_top \
           -I$(REPO_ROOT)/memory/ddr_scheduler \
           -I$(REPO_ROOT)/memory/ddr_phy_if \
           -I$(REPO_ROOT)/memory/sram_32x64_180nm \
           -I$(REPO_ROOT)/memory/sram_512kx8_180nm \
           -I$(REPO_ROOT)/memory/mbist \
           -I$(REPO_ROOT)/peripherals/uart_16550 \
           -I$(REPO_ROOT)/peripherals/can_controller \
           -I$(REPO_ROOT)/peripherals/gpio_ctrl \
           -I$(REPO_ROOT)/peripherals/watchdog_timer \
           -I$(REPO_ROOT)/peripherals/spi_master \
           -I$(REPO_ROOT)/peripherals/i2c_master \
           -I$(REPO_ROOT)/peripherals/rtc \
           -I$(REPO_ROOT)/peripherals/gem_ethernet \
           -I$(REPO_ROOT)/peripherals/gem_sgmii_pcs \
           -I$(REPO_ROOT)/peripherals/pcie_top \
           -I$(REPO_ROOT)/peripherals/pcie_pipe_if \
           -I$(REPO_ROOT)/peripherals/trng \
           -I$(REPO_ROOT)/peripherals/sha256_engine \
           -I$(REPO_ROOT)/peripherals/aes_engine \
           -I$(REPO_ROOT)/security/secure_boot \
           -I$(REPO_ROOT)/security/drbg \
           -I$(REPO_ROOT)/security/ecdsa_engine \
           -I$(REPO_ROOT)/security/efuse_ctrl \
           -I$(REPO_ROOT)/security/envm_ctrl \
           -I$(REPO_ROOT)/storage/usb_otg \
           -I$(REPO_ROOT)/storage/mmc_controller \
           -I$(REPO_ROOT)/storage/qspi_controller \
           -I$(REPO_ROOT)/video/vdma \
           -I$(REPO_ROOT)/video/mipi_csi2_rx \
           -I$(REPO_ROOT)/video/isp_pipeline \
           -I$(REPO_ROOT)/video/hdmi_ctrl \
           -I$(REPO_ROOT)/top/axi_sram \
           -I$(REPO_ROOT)/top/axi_rom \
           -I$(REPO_ROOT)/top/titan_x_top \
           -I$(REPO_ROOT)/common/sync_cell \
           -I$(REPO_ROOT)/common/reset_sync \
           -I$(REPO_ROOT)/common/cdc_sync \
           -I$(REPO_ROOT)/common/fifo_sync \
           -I$(REPO_ROOT)/common/fifo_async \
           -I$(REPO_ROOT)/common

RTL_FILES := $(shell grep -E '\.v$$' $(REPO_ROOT)/verilator_files.f | sed -e 's|^|$(REPO_ROOT)/|' | tr '\n' ' ')

TB_SRCS := tb_titan_x_top.cpp

TARGET := obj_dir/Vtitan_x_top

.PHONY: all build clean run

all: build

build: $(TARGET)

$(TARGET): $(TB_SRCS) $(RTL_FILES)
	@echo "=== Compiling Full TITAN-X SoC with Verilator ==="
	$(VERILATOR) $(VERILATOR_FLAGS) $(INCDIRS) $(RTL_FILES) $(TB_SRCS)
	@echo "=== Verilator compilation successful: $(TARGET) ==="

run: build
	./$(TARGET) --cycles 50000

clean:
	rm -rf obj_dir *.fst *.vcd *.log
