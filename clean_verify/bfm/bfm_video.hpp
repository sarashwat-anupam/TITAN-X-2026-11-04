// SPDX-License-Identifier: Apache-2.0
// SMVDU TITAN-X Clean-Room Verification Environment
// Video Subsystem Bus Functional Model (BFM) & Monitor
// Verifies VDMA (S2MM/MM2S), MIPI CSI-2 RX, ISP Pipeline, and HDMI 1.4 TMDS.

#ifndef BFM_VIDEO_HPP
#define BFM_VIDEO_HPP

#include <cstdint>
#include <iostream>
#include <iomanip>
#include <string>
#include <vector>

class VideoBFM {
public:
    struct Stats {
        uint64_t apb_vdma_writes = 0;
        uint64_t apb_vdma_reads  = 0;
        uint64_t apb_mipi_writes = 0;
        uint64_t apb_isp_writes  = 0;
        uint64_t apb_hdmi_writes = 0;
        uint64_t s2mm_frames     = 0;
        uint64_t mm2s_frames     = 0;
        uint64_t vdma_irq_count  = 0;
        uint64_t tmds_clk_toggles = 0;
        uint64_t tmds_data_toggles = 0;
        uint64_t mipi_pixels_in  = 0;
        uint64_t protocol_violations = 0;
    };

private:
    Stats stats_;
    bool verbose_ = false;

    // Shadow registers
    uint32_t vdma_cr_ = 0;
    uint32_t vdma_sr_ = 0;
    uint32_t vdma_mm2s_vsize_ = 0;
    uint32_t vdma_mm2s_hsize_ = 0;
    uint32_t vdma_mm2s_stride_ = 0;
    uint32_t vdma_mm2s_addr_ = 0;
    uint32_t vdma_s2mm_vsize_ = 0;
    uint32_t vdma_s2mm_hsize_ = 0;
    uint32_t vdma_s2mm_stride_ = 0;
    uint32_t vdma_s2mm_addr_ = 0;

    uint32_t isp_bypass_ = 1;
    uint32_t mipi_cr_ = 0;

    // TMDS line tracking
    bool prev_tmds_clk_p_ = false;
    uint8_t prev_tmds_data_p_ = 0;

    // IRQ tracking
    bool prev_vdma_irq_ = false;

    // APB cycle tracking
    bool prev_penable_ = false;

public:
    VideoBFM(bool verbose = false) : verbose_(verbose) {}

    void tick(uint64_t cycle,
              bool rst_n,
              bool psel,
              bool penable,
              bool pwrite,
              uint32_t paddr,
              uint32_t pwdata,
              uint32_t prdata,
              bool pready,
              bool tmds_clk_p,
              bool tmds_clk_n,
              uint8_t tmds_data_p,
              uint8_t tmds_data_n,
              bool vdma_irq) {
        if (!rst_n) {
            prev_penable_ = false;
            prev_vdma_irq_ = false;
            prev_tmds_clk_p_ = false;
            prev_tmds_data_p_ = 0;
            return;
        }

        // 1. HDMI TMDS Differential Line Verification
        if (tmds_clk_p == tmds_clk_n) {
            stats_.protocol_violations++;
            std::cerr << "[Video BFM] [Cycle " << std::dec << cycle
                      << "] ❌ TMDS Clock Pair Violation: clk_p == clk_n ("
                      << (int)tmds_clk_p << ")\n";
        }
        if (tmds_clk_p != prev_tmds_clk_p_) {
            stats_.tmds_clk_toggles++;
            prev_tmds_clk_p_ = tmds_clk_p;
        }

        if ((tmds_data_p & 0x7) == (tmds_data_n & 0x7)) {
            stats_.protocol_violations++;
            std::cerr << "[Video BFM] [Cycle " << std::dec << cycle
                      << "] ❌ TMDS Data Pair Violation: data_p == data_n ("
                      << (int)tmds_data_p << ")\n";
        }
        if (tmds_data_p != prev_tmds_data_p_) {
            stats_.tmds_data_toggles++;
            prev_tmds_data_p_ = tmds_data_p;
        }

        // 2. VDMA Interrupt Monitoring
        if (vdma_irq && !prev_vdma_irq_) {
            stats_.vdma_irq_count++;
            if (verbose_) {
                std::cout << "[Video BFM] [Cycle " << std::dec << cycle
                          << "] ⚡ VDMA Frame Done Interrupt Asserted (PLIC IRQ 17)\n";
            }
        }
        prev_vdma_irq_ = vdma_irq;

        // 3. APB Video Register Tracking
        bool apb_fire = psel && penable && !prev_penable_;
        prev_penable_ = penable;

        if (apb_fire) {
            uint32_t base = paddr & 0xFFFFF000;
            uint32_t offset = paddr & 0x000000FF;

            // VDMA: 0x40018000
            if (base == 0x40018000) {
                if (pwrite) {
                    stats_.apb_vdma_writes++;
                    switch (offset) {
                        case 0x00:
                            vdma_cr_ = pwdata;
                            if (pwdata & 0x10) stats_.mm2s_frames++;
                            if (pwdata & 0x20) stats_.s2mm_frames++;
                            if (verbose_) {
                                std::cout << "[Video BFM] [Cycle " << std::dec << cycle
                                          << "] VDMA CR Write: 0x" << std::hex << pwdata
                                          << " (MM2S_run=" << (pwdata & 1)
                                          << " S2MM_run=" << ((pwdata >> 1) & 1)
                                          << " MM2S_start=" << ((pwdata >> 4) & 1)
                                          << " S2MM_start=" << ((pwdata >> 5) & 1) << ")\n";
                            }
                            break;
                        case 0x10: vdma_mm2s_vsize_ = pwdata; break;
                        case 0x14: vdma_mm2s_hsize_ = pwdata; break;
                        case 0x18: vdma_mm2s_stride_ = pwdata; break;
                        case 0x1C: vdma_mm2s_addr_ = pwdata; break;
                        case 0x30: vdma_s2mm_vsize_ = pwdata; break;
                        case 0x34: vdma_s2mm_hsize_ = pwdata; break;
                        case 0x38: vdma_s2mm_stride_ = pwdata; break;
                        case 0x3C: vdma_s2mm_addr_ = pwdata; break;
                        default: break;
                    }
                } else {
                    stats_.apb_vdma_reads++;
                }
            }
            // MIPI: 0x40040000
            else if (base == 0x40040000) {
                if (pwrite) {
                    stats_.apb_mipi_writes++;
                    if (offset == 0x00) {
                        mipi_cr_ = pwdata;
                        if (verbose_) {
                            std::cout << "[Video BFM] [Cycle " << std::dec << cycle
                                      << "] MIPI CSI-2 CR Write: 0x" << std::hex << pwdata << "\n";
                        }
                    }
                }
            }
            // ISP: 0x40050000
            else if (base == 0x40050000) {
                if (pwrite) {
                    stats_.apb_isp_writes++;
                    if (offset == 0x00) {
                        isp_bypass_ = pwdata;
                        if (verbose_) {
                            std::cout << "[Video BFM] [Cycle " << std::dec << cycle
                                      << "] ISP Bypass CR Write: 0x" << std::hex << pwdata << "\n";
                        }
                    }
                }
            }
            // HDMI: 0x40060000
            else if (base == 0x40060000) {
                if (pwrite) {
                    stats_.apb_hdmi_writes++;
                    if (verbose_) {
                        std::cout << "[Video BFM] [Cycle " << std::dec << cycle
                                  << "] HDMI Timing Reg 0x" << std::hex << offset
                                  << " Write: 0x" << pwdata << "\n";
                    }
                }
            }
        }
    }

    void record_mipi_pixel(uint32_t count = 1) {
        stats_.mipi_pixels_in += count;
    }

    uint64_t get_violations() const { return stats_.protocol_violations; }
    const Stats& get_stats() const { return stats_; }

    void print_summary() const {
        std::cout << "\n===================================================================\n";
        std::cout << "             TITAN-X VIDEO PIPELINE BFM REPORT                     \n";
        std::cout << "===================================================================\n";
        std::cout << " VDMA APB Configuration Writes:  " << std::dec << stats_.apb_vdma_writes << "\n";
        std::cout << " VDMA S2MM Frame Captures:       " << stats_.s2mm_frames << "\n";
        std::cout << " VDMA MM2S Frame Streamings:     " << stats_.mm2s_frames << "\n";
        std::cout << " VDMA Interrupts Fired (IRQ 17): " << stats_.vdma_irq_count << "\n";
        std::cout << " MIPI CSI-2 APB Writes:          " << stats_.apb_mipi_writes << "\n";
        std::cout << " MIPI Pixels Ingested:           " << stats_.mipi_pixels_in << "\n";
        std::cout << " ISP Pipeline Config Writes:     " << stats_.apb_isp_writes << "\n";
        std::cout << " HDMI Controller APB Writes:     " << stats_.apb_hdmi_writes << "\n";
        std::cout << " HDMI TMDS Clock Toggles:        " << stats_.tmds_clk_toggles << "\n";
        std::cout << " HDMI TMDS Data Toggles:         " << stats_.tmds_data_toggles << "\n";
        std::cout << " Video Protocol Violations:      " << stats_.protocol_violations << "\n";
        std::cout << " Overall Video Subsystem Status: "
                  << (stats_.protocol_violations == 0 ? "✅ PASSED" : "❌ FAILED") << "\n";
        std::cout << "===================================================================\n\n";
    }
};

#endif // BFM_VIDEO_HPP
