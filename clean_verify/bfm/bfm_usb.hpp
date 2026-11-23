// SPDX-License-Identifier: Apache-2.0
// SMVDU-TITAN-X Clean-Room Verification Environment
// USB 2.0 OTG ULPI BFM (External PHY Model & Protocol Monitor)
#ifndef BFM_USB_HPP
#define BFM_USB_HPP

#include <cstdint>
#include <iostream>
#include <iomanip>
#include <sstream>
#include <vector>
#include <string>

class UsbBFM {
public:
    explicit UsbBFM(bool verbose = false)
        : verbose_(verbose),
          tx_transfers_(0),
          rx_transfers_(0),
          bytes_transferred_(0),
          violations_(0),
          phy_dir_(false),
          phy_nxt_(false),
          rx_inject_active_(false),
          rx_inject_idx_(0),
          tx_state_(0) {}

    void tick(uint64_t cycle,
              bool rst_n,
              uint8_t ulpi_data,
              bool ulpi_stp,
              bool ulpi_reset,
              bool& ulpi_dir_out,
              bool& ulpi_nxt_out,
              uint8_t& ulpi_data_drive) {
        if (!rst_n || ulpi_reset) {
            phy_dir_ = false;
            phy_nxt_ = false;
            ulpi_dir_out = false;
            ulpi_nxt_out = false;
            ulpi_data_drive = 0;
            tx_buffer_.clear();
            tx_state_ = 0;
            return;
        }

        int state_before = tx_state_;

        // 1. Monitor ULPI TX (MAC -> PHY)
        if (!phy_dir_) {
            // When MAC presents a command byte (bit 6 set, e.g. 0x4B for DATA0 or 0x48 for OUT)
            if (tx_state_ == 0) {
                if ((ulpi_data & 0xC0) == 0x40) { // Transmit command
                    tx_state_ = 1;
                    phy_nxt_  = true; // Handshake: PHY ready for data
                    tx_buffer_.push_back(ulpi_data);
                    if (verbose_) {
                        std::cout << "[UsbBFM] [Cycle " << cycle << "] ULPI TX Start: CMD 0x"
                                  << std::hex << static_cast<int>(ulpi_data) << std::dec << "\n";
                    }
                } else {
                    phy_nxt_ = false;
                }
            } else if (tx_state_ == 1) {
                // Capturing payload bytes
                tx_buffer_.push_back(ulpi_data);
                bytes_transferred_++;
                if (ulpi_stp) {
                    // Transfer concluded by MAC
                    tx_transfers_++;
                    phy_nxt_ = false;
                    tx_state_ = 0;
                    if (verbose_) {
                        std::cout << "[UsbBFM] [Cycle " << cycle << "] ULPI TX Stop captured ("
                                  << tx_buffer_.size() << " bytes transferred)\n";
                    }
                    tx_buffer_.clear();
                }
            }
        }

        // 2. ULPI Protocol Sanity Checks
        if (ulpi_stp && state_before == 0 && !prev_ulpi_stp_) {
            record_violation(cycle, "Spurious ULPI STP asserted outside of active transfer");
        }
        prev_ulpi_stp_ = ulpi_stp;

        ulpi_dir_out = phy_dir_;
        ulpi_nxt_out = phy_nxt_;
    }

    uint64_t get_violations() const { return violations_; }
    uint64_t get_tx_transfers() const { return tx_transfers_; }
    uint64_t get_rx_transfers() const { return rx_transfers_; }
    uint64_t get_bytes_transferred() const { return bytes_transferred_; }

    void print_summary() const {
        std::cout << "\n--- USB 2.0 ULPI BFM Verification Report ---\n";
        std::cout << "  TX Transfers Captured: " << tx_transfers_ << "\n";
        std::cout << "  Bytes Transferred:     " << bytes_transferred_ << "\n";
        std::cout << "  Protocol Violations:   " << violations_ << "\n";
        std::cout << "  Overall Status:        " << (violations_ == 0 ? "PASSED" : "FAILED") << "\n";
        std::cout << "--------------------------------------------\n";
    }

private:
    void record_violation(uint64_t cycle, const std::string& msg) {
        violations_++;
        std::cerr << "[UsbBFM VIOLATION] [Cycle " << cycle << "] " << msg << std::endl;
    }

    bool verbose_;
    uint64_t tx_transfers_;
    uint64_t rx_transfers_;
    uint64_t bytes_transferred_;
    uint64_t violations_;

    bool phy_dir_;
    bool phy_nxt_;
    bool prev_ulpi_stp_{false};

    bool rx_inject_active_;
    size_t rx_inject_idx_;
    std::vector<uint8_t> rx_buffer_;

    int tx_state_;
    std::vector<uint8_t> tx_buffer_;
};

#endif // BFM_USB_HPP
