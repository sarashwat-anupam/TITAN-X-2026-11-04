// SPDX-License-Identifier: Apache-2.0
// SMVDU TITAN-X SoC — Clean-Room Multi-Core Linux OS / OpenSBI Boot Bringup Testbench
#include <verilated.h>
#include "Vtitan_x_top.h"
#include "Vtitan_x_top___024root.h"
#include "Vtitan_x_top_titan_x_top.h"
#include <iostream>
#include <memory>
#include <string>
#include <sys/time.h>
#include <sys/resource.h>
#include <cstdlib>

enum UartState { UART_IDLE, UART_START, UART_DATA, UART_STOP };

int main(int argc, char** argv) {
    // Elevate stack size limit to 256MB to avoid segfaults on large simulation models
    struct rlimit rl;
    if (getrlimit(RLIMIT_STACK, &rl) == 0) {
        rl.rlim_cur = 256 * 1024 * 1024;
        setrlimit(RLIMIT_STACK, &rl);
    }

    Verilated::commandArgs(argc, argv);
    
    uint64_t max_cycles = 40000000ULL; // 40M cycles default
    for (int i = 1; i < argc; i++) {
        if (std::string(argv[i]) == "--cycles" && i + 1 < argc) {
            max_cycles = std::stoull(argv[i + 1]);
        }
    }

    auto top = std::make_unique<Vtitan_x_top>();
    
    top->clk = 0;
    top->rst_n = 0;
    
    uint64_t ticks = 0;
    UartState uart_state = UART_IDLE;
    uint32_t uart_cnt = 0;
    uint8_t uart_byte = 0;
    int uart_bit_idx = 0;
    const uint32_t BIT_CYCLES = 868; // 100MHz / 115200 baud

    std::string console_log = "";
    bool opensbi_banner_seen = false;
    bool four_harts_seen = false;
    bool aclint_ipi_seen = false;
    bool aclint_timer_seen = false;
    bool payload_running_seen = false;

    std::cout << "===================================================================\n";
    std::cout << " SMVDU TITAN-X SoC — Multi-Core Linux OS Boot Bringup Testbench   \n";
    std::cout << " Platform: 4-Core RV64GC (Sv39 MMU + March C+ MBIST + ACLINT)     \n";
    std::cout << " Max Cycles: " << max_cycles << "\n";
    std::cout << "===================================================================\n" << std::endl;
    
    while (!Verilated::gotFinish()) {
        if (ticks < 40) {
            top->rst_n = 0;
        } else {
            top->rst_n = 1;
        }
        
        top->clk = !top->clk;
        top->eval();
        
        if (top->clk) {
            int tx_bit = (top->uart_tx & 1);
            switch (uart_state) {
                case UART_IDLE:
                    if (tx_bit == 0) {
                        uart_state = UART_START;
                        uart_cnt = BIT_CYCLES + (BIT_CYCLES / 2);
                        uart_byte = 0;
                        uart_bit_idx = 0;
                    }
                    break;
                case UART_START:
                case UART_DATA:
                    if (--uart_cnt == 0) {
                        uart_byte |= (tx_bit << uart_bit_idx);
                        uart_bit_idx++;
                        if (uart_bit_idx == 8) {
                            char c = static_cast<char>(uart_byte);
                            std::cout << c << std::flush;
                            console_log += c;

                            if (!opensbi_banner_seen && console_log.find("OpenSBI v1.2") != std::string::npos) {
                                opensbi_banner_seen = true;
                                std::cerr << "\n[BOOT_EVENT] OpenSBI v1.2 banner detected!\n" << std::flush;
                            }
                            if (!four_harts_seen && console_log.find("Platform HART Count       : 4") != std::string::npos) {
                                four_harts_seen = true;
                                std::cerr << "[BOOT_EVENT] 4 Symmetric Application Harts Enumerated!\n" << std::flush;
                            }
                            if (!aclint_ipi_seen && console_log.find("Platform IPI Device       : aclint-mswi") != std::string::npos) {
                                aclint_ipi_seen = true;
                                std::cerr << "[BOOT_EVENT] ACLINT-MSWI Inter-Processor Interrupt (IPI) initialized!\n" << std::flush;
                            }
                            if (!aclint_timer_seen && console_log.find("Platform Timer Device     : aclint-mtimer") != std::string::npos) {
                                aclint_timer_seen = true;
                                std::cerr << "[BOOT_EVENT] ACLINT-MTIMER Machine Timer initialized!\n" << std::flush;
                            }
                            if (!payload_running_seen && console_log.find("Test payload running") != std::string::npos) {
                                payload_running_seen = true;
                                std::cerr << "\n[BOOT_EVENT] S-Mode OS Payload reached and executing successfully!\n" << std::flush;
                            }

                            uart_state = UART_STOP;
                            uart_cnt = BIT_CYCLES;
                        } else {
                            uart_cnt = BIT_CYCLES;
                        }
                    }
                    break;
                case UART_STOP:
                    if (--uart_cnt == 0) {
                        uart_state = UART_IDLE;
                    }
                    break;
            }
        }

        ticks++;
        uint64_t main_cycles = ticks / 2;
        
        if (ticks % 2000000 == 0) {
            uint64_t h0_pc = top->titan_x_top->__PVT__gen_cores__BRA__0__KET____DOT__u_core__DOT__ex_pc;
            uint64_t h1_pc = top->titan_x_top->__PVT__gen_cores__BRA__1__KET____DOT__u_core__DOT__ex_pc;
            uint64_t h2_pc = top->titan_x_top->__PVT__gen_cores__BRA__2__KET____DOT__u_core__DOT__ex_pc;
            uint64_t h3_pc = top->titan_x_top->__PVT__gen_cores__BRA__3__KET____DOT__u_core__DOT__ex_pc;
            std::cerr << "[SIM INFO] " << main_cycles << " cycles elapsed | Console: " 
                      << console_log.length() << " chars | H0_PC=0x" << std::hex << h0_pc
                      << " H1_PC=0x" << h1_pc << " H2_PC=0x" << h2_pc << " H3_PC=0x" << h3_pc << std::dec << "\n" << std::flush;
        }

        // If payload has started running and completed execution, we can finish gracefully
        if (payload_running_seen && (ticks % 2000000 == 0)) {
            std::cout << "\n[SIM INFO] Boot sequence verified successfully. Terminating bringup test.\n";
            break;
        }

        if (main_cycles >= max_cycles) {
            std::cout << "\n[SIM INFO] Reached max cycle limit (" << max_cycles << "). Stopping simulation.\n";
            break;
        }
    }
    
    std::cout << "\n===================================================================\n";
    std::cout << " TITAN-X Multi-Core Linux / OpenSBI Boot Verification Report       \n";
    std::cout << "===================================================================\n";
    std::cout << " Simulation Cycles:        " << (ticks / 2) << "\n";
    std::cout << " OpenSBI Banner:           " << (opensbi_banner_seen ? "✅ DETECTED" : "❌ NOT DETECTED") << "\n";
    std::cout << " 4-HART Enumeration:       " << (four_harts_seen ? "✅ DETECTED" : "❌ NOT DETECTED") << "\n";
    std::cout << " ACLINT-MSWI (IPI):        " << (aclint_ipi_seen ? "✅ DETECTED" : "❌ NOT DETECTED") << "\n";
    std::cout << " ACLINT-MTIMER (Timer):    " << (aclint_timer_seen ? "✅ DETECTED" : "❌ NOT DETECTED") << "\n";
    std::cout << " S-Mode Payload Execution: " << (payload_running_seen ? "✅ PASSED" : "❌ NOT REACHED") << "\n";
    
    bool boot_passed = opensbi_banner_seen && four_harts_seen && aclint_ipi_seen && aclint_timer_seen && payload_running_seen;
    std::cout << " Overall Bringup Status:   " << (boot_passed ? "✅ 100% PASSED" : "❌ FAILED") << "\n";
    std::cout << "===================================================================\n" << std::endl;

    top->final();
    return boot_passed ? 0 : 1;
}
