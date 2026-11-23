#ifndef TITAN_X_SPIKE_COSIM_BRIDGE_HPP
#define TITAN_X_SPIKE_COSIM_BRIDGE_HPP

#include <cstdint>
#include <string>
#include <vector>
#include <deque>
#include <fstream>
#include <iostream>
#include <sstream>
#include <iomanip>
#include <unordered_map>

class SpikeCosimBridge {
public:
    struct CommitEvent {
        uint32_t hartid;
        uint64_t pc;
        uint32_t instr;
        uint8_t  rd;
        uint64_t data;
        bool     has_wb;
    };

    SpikeCosimBridge() : mismatches_(0), total_commits_(0), end_sync_pc_(0) {
        for (int i = 0; i < 8; ++i) {
            user_active_[i] = false;
            end_sync_reached_[i] = false;
        }
    }

    void set_end_sync_pc(uint64_t pc) { end_sync_pc_ = pc; }

    bool load_spike_commit_log(const std::string& logfile) {
        std::ifstream file(logfile);
        if (!file.is_open()) {
            std::cerr << "[SpikeCosim] Warning: Cannot open Spike commit log: " << logfile << std::endl;
            return false;
        }

        std::string line;
        while (std::getline(file, line)) {
            // Trim leading/trailing whitespace
            size_t s = line.find_first_not_of(" \t\r\n");
            if (s == std::string::npos) continue;
            line = line.substr(s);
            if (line.empty()) continue;

            // Spike commit format:
            // "core   0: 0x0000000080000000 (0x00000297) x5  0x0000000080000000"
            // or "core   0: 3 0x0000000080000004 (0x00028293)"
            CommitEvent ev;
            ev.hartid = 0;
            ev.has_wb = false;
            ev.rd = 0;
            ev.data = 0;

            if (line.find("core") == 0) {
                std::istringstream iss(line);
                std::string token;
                iss >> token; // "core"
                std::string core_token;
                iss >> core_token; // e.g. "0:"
                if (!core_token.empty() && core_token.back() == ':') core_token.pop_back();
                try {
                    ev.hartid = std::stoul(core_token);
                } catch (...) {
                    continue;
                }

                std::string pc_token;
                iss >> pc_token;
                // Check if privilege mode number is present e.g. "3"
                if (pc_token.length() == 1 && isdigit(pc_token[0])) {
                    iss >> pc_token; // Next is PC
                }

                if (pc_token.find("0x") == 0) {
                    try {
                        ev.pc = std::stoull(pc_token, nullptr, 16);
                    } catch (...) {
                        continue;
                    }
                }

                std::string instr_token;
                iss >> instr_token; // (0x...)
                if (instr_token.find("(0x") == 0) {
                    std::string hex_str = instr_token.substr(3);
                    if (!hex_str.empty() && hex_str.back() == ')') hex_str.pop_back();
                    try {
                        ev.instr = std::stoul(hex_str, nullptr, 16);
                    } catch (...) {}
                }

                std::string reg_token;
                if (iss >> reg_token) {
                    // e.g. "x5" or "ra"
                    if (reg_token.length() >= 2 && reg_token[0] == 'x' && isdigit(reg_token[1])) {
                        try {
                            ev.rd = std::stoul(reg_token.substr(1));
                            std::string data_token;
                            if (iss >> data_token) {
                                if (data_token.find("0x") == 0) {
                                    ev.data = std::stoull(data_token, nullptr, 16);
                                    ev.has_wb = true;
                                }
                            }
                        } catch (...) {}
                    }
                }

                // Only track user code commits with register writeback (skip internal spike reset loader and non-WB instructions)
                if (ev.has_wb && ev.pc >= 0x80000000ULL && (end_sync_pc_ == 0 || ev.pc < end_sync_pc_)) {
                    golden_queue_[ev.hartid].push_back(ev);
                }
            }
        }
        std::cout << "[SpikeCosim] Loaded golden commits from " << logfile << ":\n";
        for (int h = 0; h < 4; ++h) {
            std::cout << "  Hart " << h << ": " << golden_queue_[h].size() << " commits\n";
        }
        return true;
    }

    void on_rtl_commit(uint64_t cycle, uint32_t hartid, uint64_t pc, uint8_t rd, uint64_t data, bool we) {
        total_commits_++;
        if (hartid < 8) {
            if (!user_active_[hartid]) {
                if (pc >= 0x80000000ULL) {
                    user_active_[hartid] = true;
                } else {
                    return;
                }
            }
            if (end_sync_pc_ != 0 && pc >= end_sync_pc_) {
                end_sync_reached_[hartid] = true;
            }
            if (end_sync_reached_[hartid]) {
                return;
            }
        }
        
        // Track GPR state in reference shadow table
        if (we && rd != 0 && rd < 32) {
            shadow_gpr_[hartid][rd] = data;
        }

        // If golden queue is active, perform lockstep comparison
        auto it = golden_queue_.find(hartid);
        if (it != golden_queue_.end() && !it->second.empty()) {
            CommitEvent expected = it->second.front();
            it->second.pop_front();

            bool mismatch = false;
            std::ostringstream err;

            if (we && (rd != 0)) {
                if (!expected.has_wb || expected.rd != rd || expected.data != data) {
                    mismatch = true;
                    err << "GPR Writeback Mismatch on Hart " << hartid << " at Cycle " << cycle << "!\n"
                        << "  RTL retired:   PC=0x" << std::hex << pc 
                        << " rd=x" << std::dec << (int)rd << " data=0x" << std::hex << data << "\n"
                        << "  Spike expects: PC=0x" << expected.pc 
                        << " rd=x" << std::dec << (int)expected.rd << " data=0x" << std::hex << expected.data;
                }
            }

            if (mismatch) {
                mismatches_++;
                std::cerr << "\n======================================================\n";
                std::cerr << "[COSIM_MISMATCH_ERROR] " << err.str() << "\n";
                std::cerr << "======================================================\n" << std::endl;
            }
        }
    }

    uint64_t get_gpr(uint32_t hartid, uint8_t reg_idx) const {
        auto h_it = shadow_gpr_.find(hartid);
        if (h_it != shadow_gpr_.end()) {
            auto r_it = h_it->second.find(reg_idx);
            if (r_it != h_it->second.end()) return r_it->second;
        }
        return 0;
    }

    uint64_t get_mismatches() const { return mismatches_; }
    uint64_t get_total_commits() const { return total_commits_; }

private:
    uint64_t mismatches_;
    uint64_t total_commits_;
    uint64_t end_sync_pc_;
    bool     user_active_[8];
    bool     end_sync_reached_[8];
    std::unordered_map<uint32_t, std::deque<CommitEvent>> golden_queue_;
    std::unordered_map<uint32_t, std::unordered_map<uint8_t, uint64_t>> shadow_gpr_;
};

#endif // TITAN_X_SPIKE_COSIM_BRIDGE_HPP
