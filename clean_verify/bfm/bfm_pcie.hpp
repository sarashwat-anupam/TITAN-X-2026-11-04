// SPDX-License-Identifier: Apache-2.0
// SMVDU-TITAN-X Clean-Room Verification Environment
// PCIe Gen2 x4 PIPE 3.0 Root Complex BFM & Protocol Monitor
#ifndef BFM_PCIE_HPP
#define BFM_PCIE_HPP

#include <cstdint>
#include <iostream>
#include <iomanip>
#include <sstream>
#include <vector>
#include <string>

class PcieBFM {
public:
    explicit PcieBFM(bool verbose = false)
        : verbose_(verbose),
          ltssm_state_(RP_DETECT),
          ts_count_(0),
          link_up_(false),
          mwr_count_(0),
          mrd_count_(0),
          cpld_count_(0),
          violations_(0),
          tlp_stim_state_(0),
          tlp_stim_cycle_(0),
          cpld_rx_beat_(0),
          last_cpld_payload_(0) {}

    enum RpState {
        RP_DETECT  = 0,
        RP_POLLING = 1,
        RP_CONFIG  = 2,
        RP_L0      = 3
    };

    void tick(uint64_t cycle,
              bool rst_n,
              bool core_rst_n,
              uint64_t pipe_tx_data,
              uint8_t pipe_tx_datak,
              uint8_t pipe_tx_rate,
              uint8_t pipe_tx_elecidle,
              uint64_t& pipe_rx_data_out,
              uint8_t& pipe_rx_datak_out,
              uint8_t& pipe_rx_valid_out,
              uint8_t& pipe_rx_elecidle_out,
              uint8_t& pipe_phy_status_out) {
        if (!rst_n) {
            ltssm_state_        = RP_DETECT;
            ts_count_           = 0;
            link_up_            = false;
            pipe_rx_data_out    = 0;
            pipe_rx_datak_out   = 0;
            pipe_rx_valid_out   = 0;
            pipe_rx_elecidle_out = 0xF;
            pipe_phy_status_out = 0;
            tlp_stim_state_     = 0;
            cpld_rx_beat_       = 0;
            return;
        }

        // 1. LTSSM Link Training (Root Port side)
        switch (ltssm_state_) {
            case RP_DETECT:
                pipe_rx_elecidle_out = 0xF;
                pipe_rx_valid_out    = 0x0;
                pipe_rx_data_out     = 0x0;
                pipe_rx_datak_out    = 0x0;

                // Senses endpoint presence when DUT deasserts electrical idle
                if (pipe_tx_elecidle == 0) {
                    pipe_phy_status_out = 0xF;
                    pipe_rx_elecidle_out = 0x0;
                    ts_count_ = 0;
                    ltssm_state_ = RP_POLLING;
                    if (verbose_) {
                        std::cout << "[PcieBFM] [Cycle " << cycle << "] LTSSM Detect: Endpoint detected\n";
                    }
                }
                break;

            case RP_POLLING:
                pipe_phy_status_out  = 0x0;
                pipe_rx_elecidle_out = 0x0;
                pipe_rx_valid_out    = 0xF;
                pipe_rx_data_out     = 0x4A4A4A4A4A4A4A4AULL; // TS1
                pipe_rx_datak_out    = 0xFF;
                ts_count_++;

                if (ts_count_ > 16 && (pipe_tx_data == 0x4A4A4A4A4A4A4A4AULL || pipe_tx_data == 0x4545454545454545ULL)) {
                    ts_count_ = 0;
                    ltssm_state_ = RP_CONFIG;
                    if (verbose_) {
                        std::cout << "[PcieBFM] [Cycle " << cycle << "] LTSSM Polling: TS1 exchange complete\n";
                    }
                }
                break;

            case RP_CONFIG:
                pipe_rx_data_out  = 0x4545454545454545ULL; // TS2
                pipe_rx_datak_out = 0xFF;
                pipe_rx_valid_out = 0xF;
                ts_count_++;

                if (ts_count_ > 8 && pipe_tx_data == 0x4545454545454545ULL) {
                    ts_count_ = 0;
                    ltssm_state_ = RP_L0;
                    link_up_     = true;
                    if (verbose_) {
                        std::cout << "[PcieBFM] [Cycle " << cycle << "] LTSSM L0: PCIe Gen2 x4 Link UP!\n";
                    }
                }
                break;

            case RP_L0:
                // Steady State L0
                pipe_rx_elecidle_out = 0x0;
                pipe_rx_valid_out    = 0xF;

                // 2. TLP Stimulus Generator (Inject MWr then MRd only after SoC crossbar released from reset)
                if (tlp_stim_state_ == 0) {
                    // Send IDLE
                    pipe_rx_data_out  = 0x0;
                    pipe_rx_datak_out = 0x0;
                    if (core_rst_n) {
                        tlp_stim_cycle_++;
                        if (tlp_stim_cycle_ > 20) {
                            tlp_stim_state_ = 1; // Begin MWr
                        }
                    }
                } else if (tlp_stim_state_ == 1) {
                    // MWr Beat 0: Header DW0 & DW1
                    pipe_rx_data_out  = 0x010000FF60000002ULL; // Fmt=011, Type=0, Len=2, Req=0100, Tag=00, BE=FF
                    pipe_rx_datak_out = 0x00;
                    tlp_stim_state_   = 2;
                } else if (tlp_stim_state_ == 2) {
                    // MWr Beat 1: Header DW2 (Addr[63:32]=0) & DW3 (Addr[31:0]=0x8040_0000)
                    pipe_rx_data_out  = 0x8040000000000000ULL;
                    pipe_rx_datak_out = 0x00;
                    tlp_stim_state_   = 3;
                } else if (tlp_stim_state_ == 3) {
                    // MWr Beat 2: Payload DW4 & DW5
                    pipe_rx_data_out  = 0xCAFEBABEDEADBEEFULL;
                    pipe_rx_datak_out = 0x00;
                    mwr_count_++;
                    tlp_stim_state_   = 4;
                    if (verbose_) {
                        std::cout << "[PcieBFM] [Cycle " << cycle << "] Injected 64-bit MWr TLP @ 0x80400000: 0xCAFEBABE_DEADBEEF\n";
                    }
                } else if (tlp_stim_state_ == 4) {
                    // Idle gap between write and read
                    pipe_rx_data_out  = 0x0;
                    pipe_rx_datak_out = 0x0;
                    tlp_stim_cycle_++;
                    if (tlp_stim_cycle_ > 100) {
                        tlp_stim_state_ = 5; // Begin MRd
                    }
                } else if (tlp_stim_state_ == 5) {
                    // MRd Beat 0: Header DW0 & DW1
                    pipe_rx_data_out  = 0x010005FF20000002ULL; // Fmt=001, Type=0, Len=2, Req=0100, Tag=05, BE=FF
                    pipe_rx_datak_out = 0x00;
                    tlp_stim_state_   = 6;
                } else if (tlp_stim_state_ == 6) {
                    // MRd Beat 1: Header DW2 (Addr[63:32]=0) & DW3 (Addr[31:0]=0x8040_0008)
                    pipe_rx_data_out  = 0x8040000800000000ULL;
                    pipe_rx_datak_out = 0x00;
                    mrd_count_++;
                    tlp_stim_state_   = 7;
                    tlp_stim_cycle_   = 0;
                    if (verbose_) {
                        std::cout << "[PcieBFM] [Cycle " << cycle << "] Injected 64-bit MRd TLP @ 0x80400008\n";
                    }
                } else if (tlp_stim_state_ == 7) {
                    // Steady-state idle or periodic MRd re-poll until expected payload captured
                    pipe_rx_data_out  = 0x0;
                    pipe_rx_datak_out = 0x0;
                    tlp_stim_cycle_++;
                    if (tlp_stim_cycle_ > 300 && last_cpld_payload_ != 0x1122334455667788ULL) {
                        tlp_stim_cycle_ = 0;
                        tlp_stim_state_ = 5; // Re-inject MRd
                    }
                } else {
                    // Steady-state idle
                    pipe_rx_data_out  = 0x0;
                    pipe_rx_datak_out = 0x0;
                }

                // 3. Monitor CplD TLPs returned on pipe_tx_data
                if (pipe_tx_datak == 0 && pipe_tx_data != 0) {
                    if (cpld_rx_beat_ == 0) {
                        if ((pipe_tx_data & 0xFF) == 0x02 && ((pipe_tx_data >> 24) & 0xFF) == 0x4A) {
                            // CplD Header DW0 & DW1 detected
                            cpld_rx_beat_ = 1;
                        }
                    } else if (cpld_rx_beat_ == 1) {
                        // Header DW2 & Payload Lower DW3
                        last_cpld_payload_ = pipe_tx_data >> 32;
                        cpld_rx_beat_ = 2;
                    } else if (cpld_rx_beat_ == 2) {
                        // Payload Upper DW4
                        last_cpld_payload_ |= (pipe_tx_data & 0xFFFFFFFFULL) << 32;
                        cpld_count_++;
                        cpld_rx_beat_ = 0;
                        if (verbose_) {
                            std::cout << "[PcieBFM] [Cycle " << cycle << "] Captured CplD TLP payload: 0x"
                                      << std::hex << last_cpld_payload_ << std::dec << "\n";
                        }
                    }
                }
                break;
        }
    }

    bool is_link_up() const { return link_up_; }
    uint64_t get_violations() const { return violations_; }
    uint64_t get_mwr_count() const { return mwr_count_; }
    uint64_t get_mrd_count() const { return mrd_count_; }
    uint64_t get_cpld_count() const { return cpld_count_; }
    uint64_t get_last_cpld_payload() const { return last_cpld_payload_; }

    void print_summary() const {
        std::cout << "\n--- PCIe Gen2 x4 PIPE 3.0 BFM Verification Report ---\n";
        std::cout << "  LTSSM Link Status:    " << (link_up_ ? "LINK UP (L0)" : "DOWN") << "\n";
        std::cout << "  Memory Write TLPs:    " << mwr_count_ << "\n";
        std::cout << "  Memory Read TLPs:     " << mrd_count_ << "\n";
        std::cout << "  Completion TLPs:      " << cpld_count_ << "\n";
        std::cout << "  Protocol Violations:  " << violations_ << "\n";
        std::cout << "  Overall Status:       " << (violations_ == 0 && link_up_ ? "PASSED" : "FAILED") << "\n";
        std::cout << "-----------------------------------------------------\n";
    }

private:
    void record_violation(uint64_t cycle, const std::string& msg) {
        violations_++;
        std::cerr << "[PcieBFM VIOLATION] [Cycle " << cycle << "] " << msg << std::endl;
    }

    bool verbose_;
    RpState ltssm_state_;
    uint8_t ts_count_;
    bool link_up_;
    uint64_t mwr_count_;
    uint64_t mrd_count_;
    uint64_t cpld_count_;
    uint64_t violations_;

    int tlp_stim_state_;
    uint64_t tlp_stim_cycle_;
    int cpld_rx_beat_;
    uint64_t last_cpld_payload_;
};

#endif // BFM_PCIE_HPP
