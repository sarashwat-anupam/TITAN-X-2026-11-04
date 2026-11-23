// SPDX-License-Identifier: Apache-2.0
// SMVDU-TITAN-X Clean-Room Verification Environment
// Gigabit Ethernet GMII BFM (IEEE 802.3 MAC / PHY Monitor & Stimulus Generator)
#ifndef BFM_ETHERNET_HPP
#define BFM_ETHERNET_HPP

#include <cstdint>
#include <iostream>
#include <iomanip>
#include <sstream>
#include <vector>
#include <string>

class EthernetBFM {
public:
    explicit EthernetBFM(bool verbose = false)
        : verbose_(verbose),
          tx_frames_(0),
          rx_frames_(0),
          tx_bytes_(0),
          rx_bytes_(0),
          crc_errors_(0),
          violations_(0),
          prev_tx_en_(false),
          tx_crc_(0xFFFFFFFFU),
          rx_inject_idx_(0),
          rx_inject_active_(false) {}

    // IEEE 802.3 Ethernet CRC-32 (polynomial 0xEDB88320)
    static uint32_t calculate_crc32(const std::vector<uint8_t>& data) {
        uint32_t crc = 0xFFFFFFFFU;
        for (uint8_t b : data) {
            for (int i = 0; i < 8; ++i) {
                if ((crc ^ (b >> i)) & 1) {
                    crc = (crc >> 1) ^ 0xEDB88320U;
                } else {
                    crc = crc >> 1;
                }
            }
        }
        return ~crc;
    }

    void tick(uint64_t cycle,
              bool rst_n,
              uint8_t gmii_txd,
              bool gmii_tx_en,
              bool gmii_tx_er,
              uint8_t& gmii_rxd_out,
              bool& gmii_rx_dv_out) {
        if (!rst_n) {
            prev_tx_en_ = false;
            tx_frame_buffer_.clear();
            tx_crc_ = 0xFFFFFFFFU;
            gmii_rxd_out = 0;
            gmii_rx_dv_out = false;
            return;
        }

        // 1. GMII TX Monitor
        if (gmii_tx_en) {
            if (gmii_tx_er) {
                record_violation(cycle, "GMII TX error asserted (gmii_tx_er=1)");
            }
            tx_frame_buffer_.push_back(gmii_txd);
            tx_bytes_++;
        } else if (prev_tx_en_ && !gmii_tx_en) {
            // Frame completed
            tx_frames_++;
            if (tx_frame_buffer_.size() < 68) { // 64 bytes payload + 4 bytes CRC
                record_violation(cycle, "GMII TX frame length below minimum (expected >= 68 bytes, got " +
                                 std::to_string(tx_frame_buffer_.size()) + ")");
            } else {
                // Verify CRC-32
                std::vector<uint8_t> payload(tx_frame_buffer_.begin(), tx_frame_buffer_.begin() + 64);
                uint32_t expected_crc = calculate_crc32(payload);
                uint32_t received_crc = static_cast<uint32_t>(tx_frame_buffer_[64]) |
                                       (static_cast<uint32_t>(tx_frame_buffer_[65]) << 8) |
                                       (static_cast<uint32_t>(tx_frame_buffer_[66]) << 16) |
                                       (static_cast<uint32_t>(tx_frame_buffer_[67]) << 24);
                if (expected_crc != received_crc) {
                    record_violation(cycle, "GMII TX CRC-32 mismatch (expected 0x" +
                                     to_hex32(expected_crc) + ", got 0x" + to_hex32(received_crc) + ")");
                    crc_errors_++;
                } else if (verbose_) {
                    std::cout << "[EthernetBFM] [Cycle " << cycle << "] Valid GMII TX frame captured ("
                              << tx_frame_buffer_.size() << " bytes), CRC-32 0x"
                              << std::hex << expected_crc << std::dec << " OK\n";
                }

                // Automatically prime loopback buffer
                rx_loopback_buffer_ = tx_frame_buffer_;
                rx_inject_active_   = true;
                rx_inject_idx_      = 0;
            }
            tx_frame_buffer_.clear();
        }
        prev_tx_en_ = gmii_tx_en;

        // 2. GMII RX Loopback Injection
        if (rx_inject_active_ && rx_inject_idx_ < rx_loopback_buffer_.size()) {
            gmii_rx_dv_out = true;
            gmii_rxd_out   = rx_loopback_buffer_[rx_inject_idx_];
            rx_inject_idx_++;
            rx_bytes_++;
            if (rx_inject_idx_ == rx_loopback_buffer_.size()) {
                rx_frames_++;
            }
        } else {
            gmii_rx_dv_out = false;
            gmii_rxd_out   = 0;
            if (rx_inject_active_) {
                rx_inject_active_ = false;
                if (verbose_) {
                    std::cout << "[EthernetBFM] [Cycle " << cycle << "] GMII RX loopback frame injection complete\n";
                }
            }
        }
    }

    void queue_rx_frame(const std::vector<uint8_t>& frame) {
        rx_loopback_buffer_ = frame;
        rx_inject_active_   = true;
        rx_inject_idx_      = 0;
    }

    uint64_t get_violations() const { return violations_; }
    uint64_t get_tx_frames() const { return tx_frames_; }
    uint64_t get_rx_frames() const { return rx_frames_; }
    uint64_t get_tx_bytes() const { return tx_bytes_; }
    uint64_t get_rx_bytes() const { return rx_bytes_; }
    uint64_t get_crc_errors() const { return crc_errors_; }

    void print_summary() const {
        std::cout << "\n--- Ethernet GMII BFM Verification Report ---\n";
        std::cout << "  TX Frames Captured:  " << tx_frames_ << "\n";
        std::cout << "  TX Bytes Transferred: " << tx_bytes_ << "\n";
        std::cout << "  RX Frames Injected:  " << rx_frames_ << "\n";
        std::cout << "  RX Bytes Injected:   " << rx_bytes_ << "\n";
        std::cout << "  CRC-32 Check Errors: " << crc_errors_ << "\n";
        std::cout << "  Protocol Violations: " << violations_ << "\n";
        std::cout << "  Overall Status:      " << (violations_ == 0 ? "PASSED" : "FAILED") << "\n";
        std::cout << "---------------------------------------------\n";
    }

private:
    void record_violation(uint64_t cycle, const std::string& msg) {
        violations_++;
        std::cerr << "[EthernetBFM VIOLATION] [Cycle " << cycle << "] " << msg << std::endl;
    }

    static std::string to_hex32(uint32_t val) {
        std::stringstream ss;
        ss << std::hex << std::setfill('0') << std::setw(8) << val;
        return ss.str();
    }

    bool verbose_;
    uint64_t tx_frames_;
    uint64_t rx_frames_;
    uint64_t tx_bytes_;
    uint64_t rx_bytes_;
    uint64_t crc_errors_;
    uint64_t violations_;

    bool prev_tx_en_;
    std::vector<uint8_t> tx_frame_buffer_;
    uint32_t tx_crc_;

    std::vector<uint8_t> rx_loopback_buffer_;
    size_t rx_inject_idx_;
    bool rx_inject_active_;
};

#endif // BFM_ETHERNET_HPP
