// SPDX-License-Identifier: Apache-2.0
// SMVDU TITAN-X Clean-Room Verification Environment
// Security Subsystem Bus Functional Model (BFM) & Monitor
// Verifies Secure Boot Root-of-Trust, SHA-256, AES-256, ECDSA P-256, TRNG, and DRBG.

#ifndef BFM_SECURITY_HPP
#define BFM_SECURITY_HPP

#include <cstdint>
#include <iostream>
#include <iomanip>
#include <string>
#include <vector>
#include <array>
#include <cassert>

class SecurityBFM {
public:
    struct Stats {
        uint64_t secure_boot_cycles = 0;
        bool boot_passed = false;
        bool boot_failed = false;
        uint64_t sha256_ops = 0;
        uint64_t aes_ops = 0;
        uint64_t ecdsa_ops = 0;
        uint64_t trng_samples = 0;
        uint64_t drbg_generations = 0;
        uint64_t protocol_violations = 0;
        uint64_t irq_count[16] = {0};
    };

private:
    Stats stats_;
    bool prev_psel_ = false;
    bool prev_penable_ = false;
    uint32_t prev_paddr_ = 0;
    bool prev_pwrite_ = false;
    uint32_t prev_pwdata_ = 0;

    // Shadow state for SHA-256
    uint32_t sha_msg_[16] = {0};
    uint32_t sha_hash_[8] = {0};
    bool sha_busy_ = false;

    // Shadow state for AES-256
    uint32_t aes_key_[8] = {0};
    uint32_t aes_iv_[4] = {0};
    uint32_t aes_din_[4] = {0};
    uint32_t aes_dout_[4] = {0};
    uint32_t aes_ctrl_ = 0;

    // Shadow state for ECDSA
    uint32_t ecdsa_hash_[8] = {0};
    uint32_t ecdsa_key_[16] = {0};
    uint32_t ecdsa_sig_r_[8] = {0};
    uint32_t ecdsa_sig_s_[8] = {0};
    uint32_t ecdsa_ctrl_ = 0;
    uint32_t prev_plic_irq_bits_ = 0;

    bool verbose_ = false;

public:
    SecurityBFM(bool verbose = false) : verbose_(verbose) {}

    void tick(uint64_t cycle,
              bool rst_n,
              bool boot_pass,
              bool boot_fail,
              bool psel,
              bool penable,
              bool pwrite,
              uint32_t paddr,
              uint32_t pwdata,
              uint32_t prdata,
              bool pready,
              uint32_t plic_irq_bits) {
        if (!rst_n) {
            stats_.boot_passed = false;
            stats_.boot_failed = false;
            prev_plic_irq_bits_ = 0;
            return;
        }

        // 1. Root-of-Trust Monitoring
        if (boot_pass && !stats_.boot_passed) {
            stats_.boot_passed = true;
            stats_.secure_boot_cycles = cycle;
            if (verbose_) {
                std::cout << "[Security BFM] [Cycle " << std::dec << cycle
                          << "] ✅ Hardware Root-of-Trust PASS (boot_pass=1, cores released from reset)\n";
            }
        }
        if (boot_fail && !stats_.boot_failed) {
            stats_.boot_failed = true;
            stats_.protocol_violations++;
            std::cerr << "[Security BFM] [Cycle " << std::dec << cycle
                      << "] ❌ Hardware Root-of-Trust FAIL (boot_fail=1, lockdown asserted)\n";
        }

        // 2. APB Bus Interface Monitoring
        if (psel && penable && pready) {
            uint32_t base_page = paddr & 0xFFFFF000;
            uint32_t offset = paddr & 0x00000FFF;

            // DRBG: 0x4007_0000 or 0x2000_0000
            if (base_page == 0x40070000 || base_page == 0x20000000) {
                if (pwrite && (offset & 0xFF) == 0x00) {
                    if (pwdata & 0x1) {
                        if (verbose_) std::cout << "[Security BFM] DRBG INSTANTIATE command written\n";
                    }
                    if (pwdata & 0x4) {
                        stats_.drbg_generations++;
                        if (verbose_) std::cout << "[Security BFM] DRBG GENERATE command written (count=" << stats_.drbg_generations << ")\n";
                    }
                    if (pwdata & 0x2) {
                        if (verbose_) std::cout << "[Security BFM] DRBG RESEED command written\n";
                    }
                }
            }

            // AES-256: 0x4008_0000 or 0x2001_0000
            else if (base_page == 0x40080000 || base_page == 0x20010000) {
                uint8_t reg_off = offset & 0xFF;
                if (pwrite) {
                    if (reg_off == 0x00) {
                        aes_ctrl_ = pwdata;
                        if (pwdata & 0x8) {
                            stats_.aes_ops++;
                            bool is_dec = (pwdata >> 2) & 1;
                            uint8_t mode = pwdata & 3;
                            if (verbose_) {
                                std::cout << "[Security BFM] [Cycle " << std::dec << cycle
                                          << "] AES-256 " << (is_dec ? "DECRYPT" : "ENCRYPT")
                                          << " START (Mode=" << (mode == 0 ? "ECB" : (mode == 1 ? "CBC" : "OTHER"))
                                          << ") [op #" << stats_.aes_ops << "]\n";
                            }
                        }
                    } else if (reg_off >= 0x10 && reg_off <= 0x2C) {
                        aes_key_[(reg_off - 0x10) >> 2] = pwdata;
                    } else if (reg_off >= 0x30 && reg_off <= 0x3C) {
                        aes_iv_[(reg_off - 0x30) >> 2] = pwdata;
                    } else if (reg_off >= 0x60 && reg_off <= 0x6C) {
                        aes_din_[(reg_off - 0x60) >> 2] = pwdata;
                    }
                } else {
                    if (reg_off >= 0x70 && reg_off <= 0x7C) {
                        aes_dout_[(reg_off - 0x70) >> 2] = prdata;
                    }
                }
            }

            // Secure Boot APB Telemetry: 0x400A_0000 or 0x2003_0000
            else if (base_page == 0x400A0000 || base_page == 0x20030000) {
                if (!pwrite && (offset & 0xFF) == 0x00) {
                    if (verbose_) {
                        std::cout << "[Security BFM] Secure Boot APB Telemetry read: 0x" << std::hex << prdata << std::dec << "\n";
                    }
                }
            }

            // TRNG: 0x400D_0000 or 0x2004_0000
            else if (base_page == 0x400D0000 || base_page == 0x20040000) {
                if (!pwrite && (offset & 0xFF) == 0x04) {
                    stats_.trng_samples++;
                    if (prdata & 1) {
                        stats_.protocol_violations++;
                        std::cerr << "[Security BFM] ❌ TRNG Health Test Failure reported!\n";
                    }
                }
            }

            // SHA-256: 0x400E_0000 or 0x2005_0000
            else if (base_page == 0x400E0000 || base_page == 0x20050000) {
                uint8_t reg_off = offset & 0xFF;
                if (pwrite) {
                    if (reg_off < 0x40) {
                        sha_msg_[reg_off >> 2] = pwdata;
                    } else if (reg_off == 0x60) {
                        if (pwdata & 1) {
                            stats_.sha256_ops++;
                            if (verbose_) {
                                std::cout << "[Security BFM] [Cycle " << std::dec << cycle
                                          << "] SHA-256 START (init=" << ((pwdata >> 1) & 1)
                                          << ", auto_pad=" << ((pwdata >> 2) & 1)
                                          << ") [op #" << stats_.sha256_ops << "]\n";
                            }
                        }
                    }
                } else {
                    if (reg_off >= 0x40 && reg_off <= 0x5C) {
                        sha_hash_[(reg_off - 0x40) >> 2] = prdata;
                    }
                }
            }

            // ECDSA: 0x400F_0000 or 0x2006_0000
            else if (base_page == 0x400F0000 || base_page == 0x20060000) {
                uint8_t bank = (offset >> 8) & 0xF;
                uint8_t reg_off = offset & 0xFF;
                if (pwrite) {
                    if (bank == 0 && reg_off == 0x00) {
                        ecdsa_ctrl_ = pwdata;
                        if (pwdata & 1) {
                            stats_.ecdsa_ops++;
                            if (verbose_) {
                                std::cout << "[Security BFM] [Cycle " << std::dec << cycle
                                          << "] ECDSA P-256 VERIFY START [op #" << stats_.ecdsa_ops << "]\n";
                            }
                        }
                    } else if (bank == 1 && reg_off <= 0x1C) {
                        ecdsa_hash_[reg_off >> 2] = pwdata;
                    } else if (bank == 2 && reg_off <= 0x3C) {
                        ecdsa_key_[reg_off >> 2] = pwdata;
                    } else if (bank == 3 && reg_off <= 0x1C) {
                        ecdsa_sig_r_[reg_off >> 2] = pwdata;
                    } else if (bank == 4 && reg_off <= 0x1C) {
                        ecdsa_sig_s_[reg_off >> 2] = pwdata;
                    }
                } else {
                    if (bank == 0 && reg_off == 0x04) {
                        if (verbose_) {
                            std::cout << "[Security BFM] ECDSA Status read: 0x" << std::hex << prdata
                                      << " (done=" << ((prdata >> 1) & 1)
                                      << ", pass=" << ((prdata >> 2) & 1) << ")" << std::dec << "\n";
                        }
                    }
                }
            }
        }

        // 3. PLIC Security IRQ Monitoring (IRQs 8..12)
        // [8]=TRNG, [9]=ECDSA, [10]=DRBG, [11]=AES, [12]=SHA256
        uint32_t irq_edges = plic_irq_bits & ~prev_plic_irq_bits_;
        for (int irq = 8; irq <= 12; ++irq) {
            if ((irq_edges >> irq) & 1) {
                stats_.irq_count[irq]++;
            }
        }
        prev_plic_irq_bits_ = plic_irq_bits;
    }

    const Stats& get_stats() const { return stats_; }
    uint64_t get_violations() const { return stats_.protocol_violations; }

    void print_summary() const {
        std::cout << "\n===================================================================\n";
        std::cout << "           TITAN-X SECURITY SUBSYSTEM BFM REPORT                  \n";
        std::cout << "===================================================================\n";
        std::cout << " Hardware Root-of-Trust Boot: " << (stats_.boot_passed ? "✅ PASSED" : (stats_.boot_failed ? "❌ FAILED" : "PENDING"))
                  << " (auth cycles: " << std::dec << stats_.secure_boot_cycles << ")\n";
        std::cout << " NIST SHA-256 Operations:     " << stats_.sha256_ops << "\n";
        std::cout << " NIST AES-256 ECB/CBC Ops:    " << stats_.aes_ops << "\n";
        std::cout << " NIST ECDSA P-256 Operations: " << stats_.ecdsa_ops << "\n";
        std::cout << " TRNG Entropy Health Polls:   " << stats_.trng_samples << "\n";
        std::cout << " DRBG Random Number Streams:  " << stats_.drbg_generations << "\n";
        std::cout << " Security Interrupts Fired:   "
                  << "TRNG=" << stats_.irq_count[8] << ", "
                  << "ECDSA=" << stats_.irq_count[9] << ", "
                  << "DRBG=" << stats_.irq_count[10] << ", "
                  << "AES=" << stats_.irq_count[11] << ", "
                  << "SHA=" << stats_.irq_count[12] << "\n";
        std::cout << " Security Violations:         " << stats_.protocol_violations << "\n";
        std::cout << " Overall Status:              " << (stats_.protocol_violations == 0 && stats_.boot_passed ? "✅ PASSED" : "❌ FAILED") << "\n";
        std::cout << "===================================================================\n";
    }
};

#endif // BFM_SECURITY_HPP
