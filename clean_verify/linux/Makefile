# SPDX-License-Identifier: Apache-2.0
# SMVDU TITAN-X Clean-Room Multi-Core Linux OS / OpenSBI Boot Makefile
SHELL := /bin/bash
REPO_ROOT := $(abspath ../..)

JOBS ?= 2
VERILATOR := verilator
VERILATOR_FLAGS := -Wno-fatal -Wno-PINMISSING -Wno-DECLFILENAME -Wno-TIMESCALEMOD \
                   -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-PINCONNECTEMPTY -Wno-SYNCASYNCNET \
                   -Wno-BLKSEQ -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC -Wno-COMBDLY -Wno-MULTIDRIVEN \
                   -Wno-CASEINCOMPLETE -Wno-LATCH -Wno-UNDRIVEN -Wno-UNOPTFLAT -Wno-UNSIGNED \
                   -O3 -DFAST_SIM=1 -DSIM_AXI_RAM=1 \
                   -GBOOT_ADDR=64\'h0000000080000000 -GFAST_SIM=1 \
                   --top-module titan_x_top \
                   --cc --exe --build -j $(JOBS) \
                   --CFLAGS "-std=c++17 -I$(abspath .)"

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
           -I$(REPO_ROOT)/common \
           -I$(abspath .)

RTL_FILES := $(shell grep -E '\.v$$' $(REPO_ROOT)/verilator_files.f | grep -v 'ddr_' | sed -e 's|^|$(REPO_ROOT)/|' | tr '\n' ' ')
RTL_FILES += $(abspath ./axi_ram.v)

TB_SRCS := $(abspath ./tb_linux_boot.cpp)

TARGET := obj_dir/Vtitan_x_top

.PHONY: all build clean run firmware

all: build

firmware: firmware.hex

firmware.hex: titan_x.dts build_linux_firmware.sh
	./build_linux_firmware.sh

build: firmware $(TARGET)

$(TARGET): $(TB_SRCS) $(RTL_FILES)
	$(VERILATOR) $(VERILATOR_FLAGS) $(INCDIRS) $(RTL_FILES) $(TB_SRCS)

run: build
	./obj_dir/Vtitan_x_top --cycles 40000000 2>&1 | tee ../reports/linux_boot.log

clean:
	rm -rf obj_dir titan_x.dtb firmware.hex titan_x_fw.bin titan_x_fw.elf fw.dis
