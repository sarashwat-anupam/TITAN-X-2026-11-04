#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

echo "=== Building TITAN-X OpenSBI & Linux Payload Firmware ==="

export CROSS_COMPILE=riscv64-unknown-elf-
export ARCH=riscv

# 1. Compile Device Tree
echo "[1/4] Compiling Device Tree Source (titan_x.dts -> titan_x.dtb)..."
dtc -I dts -O dtb -o titan_x.dtb titan_x.dts

# 2. Locate or clone OpenSBI v1.2
OPEN_SBI_SRC="/home/anupam-sarashwat/titan_x_firmware/linux_bringup/opensbi"
if [ ! -d "${OPEN_SBI_SRC}" ]; then
    echo "Cloning OpenSBI v1.2..."
    git clone --depth 1 --branch v1.2 https://github.com/riscv-software-src/opensbi.git "${SCRIPT_DIR}/opensbi"
    OPEN_SBI_SRC="${SCRIPT_DIR}/opensbi"
fi

# 3. Build OpenSBI generic platform with embedded DTB
echo "[2/4] Building OpenSBI v1.2 with embedded DTB..."
make -C "${OPEN_SBI_SRC}" \
    CROSS_COMPILE=${CROSS_COMPILE} \
    PLATFORM=generic \
    PLATFORM_RISCV_ISA=rv64ima_zicsr_zifencei \
    PLATFORM_RISCV_ABI=lp64 \
    FW_FDT_PATH="${SCRIPT_DIR}/titan_x.dtb" \
    FW_PIC=n

cp "${OPEN_SBI_SRC}/build/platform/generic/firmware/fw_payload.elf" "${SCRIPT_DIR}/titan_x_fw.elf"
cp "${OPEN_SBI_SRC}/build/platform/generic/firmware/fw_payload.bin" "${SCRIPT_DIR}/titan_x_fw.bin"

# 4. Generate disassembly and hex memory image
echo "[3/4] Generating disassembly (fw.dis)..."
${CROSS_COMPILE}objdump -d "${SCRIPT_DIR}/titan_x_fw.elf" > "${SCRIPT_DIR}/fw.dis"

echo "[4/4] Converting binary to 64-bit hex image (firmware.hex)..."
python3 "${SCRIPT_DIR}/bin2hex.py" "${SCRIPT_DIR}/titan_x_fw.bin" "${SCRIPT_DIR}/firmware.hex"

echo "=== Firmware Build Complete: ${SCRIPT_DIR}/firmware.hex ready ==="
