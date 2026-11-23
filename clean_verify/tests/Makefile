# SPDX-License-Identifier: Apache-2.0
# SMVDU TITAN-X: Architectural Test Suites Makefile

RISCV_PREFIX ?= /home/anupam-sarashwat/.local/riscv/bin/riscv64-unknown-elf-
CC      := $(RISCV_PREFIX)gcc
OBJCOPY := $(RISCV_PREFIX)objcopy
OBJDUMP := $(RISCV_PREFIX)objdump

CFLAGS  := -march=rv64gc -mabi=lp64d -nostdlib -nostartfiles -mcmodel=medany -I.
LDFLAGS := -T link.ld

TEST_SRCS := core/test_rv64i.S \
             core/test_rv64m.S \
             core/test_rv64a.S \
             core/test_rv64c.S \
             core/test_rv64fpu.S \
             privilege/test_privilege.S \
             mmu/test_mmu.S \
             pmp/test_pmp.S \
             monitor/test_monitor.S \
             coherence/test_mesi_litmus.S \
             coherence/test_mesi_contention.S \
             coherence/test_crossbar_stress.S \
             coherence/test_interconnect_mpu_qos.S \
             security/test_security_subsystem.S \
             video/test_video_pipeline.S \
             io/test_high_speed_io.S \
             peripherals/test_peripherals.S

ELFS := $(TEST_SRCS:.S=.elf)
HEXS := $(TEST_SRCS:.S=.hex)
DUMPS := $(TEST_SRCS:.S=.dump)

.PHONY: all clean

all: $(ELFS) $(HEXS) $(DUMPS)

%.elf: %.S test_macros.h link.ld
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $<

%.hex: %.elf
	$(OBJCOPY) -O verilog --verilog-data-width 1 $< $@

%.dump: %.elf
	$(OBJDUMP) -d -M numeric,no-aliases $< > $@

clean:
	rm -f $(ELFS) $(HEXS) $(DUMPS)
