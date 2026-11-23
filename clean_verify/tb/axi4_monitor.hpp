#ifndef TITAN_X_AXI4_MONITOR_HPP
#define TITAN_X_AXI4_MONITOR_HPP

#include <cstdint>
#include <string>
#include <vector>
#include <deque>
#include <iostream>
#include <iomanip>
#include <sstream>

class Axi4PortMonitor {
public:
    struct WriteTx {
        uint8_t  id;
        uint64_t addr;
        uint8_t  len;
        uint8_t  size;
        uint8_t  burst;
        uint32_t beats_received;
        uint64_t start_cycle;
    };

    struct ReadTx {
        uint8_t  id;
        uint64_t addr;
        uint8_t  len;
        uint8_t  size;
        uint8_t  burst;
        uint32_t beats_received;
        uint64_t start_cycle;
    };

    Axi4PortMonitor(const std::string& name, bool is_master)
        : name_(name), is_master_(is_master), violations_(0) {}

    void sample(
        uint64_t cycle,
        bool awvalid, bool awready, uint64_t awaddr, uint8_t awid, uint8_t awlen, uint8_t awsize, uint8_t awburst,
        bool wvalid,  bool wready,  uint64_t wdata,  uint8_t wstrb, bool wlast,
        bool bvalid,  bool bready,  uint8_t bresp,   uint8_t bid,
        bool arvalid, bool arready, uint64_t araddr, uint8_t arid, uint8_t arlen, uint8_t arsize, uint8_t arburst,
        bool rvalid,  bool rready,  uint64_t rdata,  uint8_t rresp, bool rlast, uint8_t rid
    ) {
        // -------------------------------------------------------------
        // 1. Handshake Stability Check: AW Channel
        // Once AWVALID is asserted, it must remain high until AWREADY is asserted.
        // Payload (awaddr, awid, awlen, awsize, awburst) must not change.
        // -------------------------------------------------------------
        if (prev_awvalid_ && !prev_awready_) {
            if (!awvalid) {
                record_violation(cycle, "AWVALID dropped before AWREADY handshake");
            } else {
                if (awaddr != prev_awaddr_) record_violation(cycle, "AWADDR changed while AWVALID asserted waiting for AWREADY");
                if (awid != prev_awid_)     record_violation(cycle, "AWID changed while AWVALID asserted waiting for AWREADY");
                if (awlen != prev_awlen_)   record_violation(cycle, "AWLEN changed while AWVALID asserted waiting for AWREADY");
                if (awsize != prev_awsize_) record_violation(cycle, "AWSIZE changed while AWVALID asserted waiting for AWREADY");
                if (awburst != prev_awburst_) record_violation(cycle, "AWBURST changed while AWVALID asserted waiting for AWREADY");
            }
        }

        // -------------------------------------------------------------
        // 2. Handshake Stability Check: W Channel
        // Once WVALID is asserted, it must remain high until WREADY is asserted.
        // -------------------------------------------------------------
        if (prev_wvalid_ && !prev_wready_) {
            if (!wvalid) {
                record_violation(cycle, "WVALID dropped before WREADY handshake");
            } else {
                if (wdata != prev_wdata_) record_violation(cycle, "WDATA changed while WVALID asserted waiting for WREADY");
                if (wstrb != prev_wstrb_) record_violation(cycle, "WSTRB changed while WVALID asserted waiting for WREADY");
                if (wlast != prev_wlast_) record_violation(cycle, "WLAST changed while WVALID asserted waiting for WREADY");
            }
        }

        // -------------------------------------------------------------
        // 3. Handshake Stability Check: B Channel
        // -------------------------------------------------------------
        if (prev_bvalid_ && !prev_bready_) {
            if (!bvalid) {
                record_violation(cycle, "BVALID dropped before BREADY handshake");
            } else {
                if (bresp != prev_bresp_) record_violation(cycle, "BRESP changed while BVALID asserted waiting for BREADY");
                if (bid != prev_bid_)     record_violation(cycle, "BID changed while BVALID asserted waiting for BREADY");
            }
        }

        // -------------------------------------------------------------
        // 4. Handshake Stability Check: AR Channel
        // -------------------------------------------------------------
        if (prev_arvalid_ && !prev_arready_) {
            if (!arvalid) {
                record_violation(cycle, "ARVALID dropped before ARREADY handshake");
            } else {
                if (araddr != prev_araddr_) record_violation(cycle, "ARADDR changed while ARVALID asserted waiting for ARREADY");
                if (arid != prev_arid_)     record_violation(cycle, "ARID changed while ARVALID asserted waiting for ARREADY");
                if (arlen != prev_arlen_)   record_violation(cycle, "ARLEN changed while ARVALID asserted waiting for ARREADY");
                if (arsize != prev_arsize_) record_violation(cycle, "ARSIZE changed while ARVALID asserted waiting for ARREADY");
                if (arburst != prev_arburst_) record_violation(cycle, "ARBURST changed while ARVALID asserted waiting for ARREADY");
            }
        }

        // -------------------------------------------------------------
        // 5. Handshake Stability Check: R Channel
        // -------------------------------------------------------------
        if (prev_rvalid_ && !prev_rready_) {
            if (!rvalid) {
                record_violation(cycle, "RVALID dropped before RREADY handshake");
            } else {
                if (rdata != prev_rdata_) record_violation(cycle, "RDATA changed while RVALID asserted waiting for RREADY");
                if (rresp != prev_rresp_) record_violation(cycle, "RRESP changed while RVALID asserted waiting for RREADY");
                if (rlast != prev_rlast_) record_violation(cycle, "RLAST changed while RVALID asserted waiting for RREADY");
                if (rid != prev_rid_)     record_violation(cycle, "RID changed while RVALID asserted waiting for RREADY");
            }
        }

        // -------------------------------------------------------------
        // 6. 4KB Boundary Crossing Checks
        // AXI4 Rule A3.4.1: An INCR burst must not cross a 4KB boundary
        // -------------------------------------------------------------
        if (awvalid && awready && awburst == 1) { // INCR
            uint64_t burst_bytes = (static_cast<uint64_t>(awlen) + 1) * (1ULL << awsize);
            uint64_t start_page = awaddr & ~0xFFFULL;
            uint64_t end_page   = (awaddr + burst_bytes - 1) & ~0xFFFULL;
            if (start_page != end_page) {
                std::ostringstream ss;
                ss << "Write INCR burst crosses 4KB boundary: addr=0x" << std::hex << awaddr 
                   << " len=" << std::dec << (int)awlen << " size=" << (int)awsize;
                record_violation(cycle, ss.str());
            }
        }

        if (arvalid && arready && arburst == 1) { // INCR
            uint64_t burst_bytes = (static_cast<uint64_t>(arlen) + 1) * (1ULL << arsize);
            uint64_t start_page = araddr & ~0xFFFULL;
            uint64_t end_page   = (araddr + burst_bytes - 1) & ~0xFFFULL;
            if (start_page != end_page) {
                std::ostringstream ss;
                ss << "Read INCR burst crosses 4KB boundary: addr=0x" << std::hex << araddr 
                   << " len=" << std::dec << (int)arlen << " size=" << (int)arsize;
                record_violation(cycle, ss.str());
            }
        }

        // -------------------------------------------------------------
        // 7. Track Transactions and Verify Burst Lengths
        // -------------------------------------------------------------
        if (awvalid && awready) {
            WriteTx tx;
            tx.id = awid;
            tx.addr = awaddr;
            tx.len = awlen;
            tx.size = awsize;
            tx.burst = awburst;
            tx.beats_received = 0;
            tx.start_cycle = cycle;
            pending_writes_.push_back(tx);
        }

        if (wvalid && wready) {
            if (pending_writes_.empty()) {
                // Out-of-order write data or unexpected write
            } else {
                auto& cur_wr = pending_writes_.front();
                cur_wr.beats_received++;
                if (wlast) {
                    if (cur_wr.beats_received != static_cast<uint32_t>(cur_wr.len + 1)) {
                        std::ostringstream ss;
                        ss << "WLAST asserted prematurely or late: beat " << cur_wr.beats_received 
                           << " expected " << (cur_wr.len + 1);
                        record_violation(cycle, ss.str());
                    }
                } else {
                    if (cur_wr.beats_received >= static_cast<uint32_t>(cur_wr.len + 1)) {
                        record_violation(cycle, "WLAST not asserted on final write beat");
                    }
                }
            }
        }

        if (bvalid && bready) {
            if (!pending_writes_.empty()) {
                pending_writes_.pop_front();
            }
        }

        if (arvalid && arready) {
            ReadTx tx;
            tx.id = arid;
            tx.addr = araddr;
            tx.len = arlen;
            tx.size = arsize;
            tx.burst = arburst;
            tx.beats_received = 0;
            tx.start_cycle = cycle;
            pending_reads_.push_back(tx);
        }

        if (rvalid && rready) {
            if (!pending_reads_.empty()) {
                auto& cur_rd = pending_reads_.front();
                cur_rd.beats_received++;
                if (rlast) {
                    if (cur_rd.beats_received != static_cast<uint32_t>(cur_rd.len + 1)) {
                        std::ostringstream ss;
                        ss << "RLAST asserted at unexpected beat: beat " << cur_rd.beats_received 
                           << " expected " << (cur_rd.len + 1);
                        record_violation(cycle, ss.str());
                    }
                    pending_reads_.pop_front();
                }
            }
        }

        // Save current states for next cycle stability checks
        prev_awvalid_ = awvalid; prev_awready_ = awready; prev_awaddr_ = awaddr;
        prev_awid_    = awid;    prev_awlen_   = awlen;   prev_awsize_ = awsize; prev_awburst_ = awburst;

        prev_wvalid_  = wvalid;  prev_wready_  = wready;  prev_wdata_  = wdata;
        prev_wstrb_   = wstrb;   prev_wlast_   = wlast;

        prev_bvalid_  = bvalid;  prev_bready_  = bready;  prev_bresp_  = bresp;  prev_bid_    = bid;

        prev_arvalid_ = arvalid; prev_arready_ = arready; prev_araddr_ = araddr;
        prev_arid_    = arid;    prev_arlen_   = arlen;   prev_arsize_ = arsize; prev_arburst_ = arburst;

        prev_rvalid_  = rvalid;  prev_rready_  = rready;  prev_rdata_  = rdata;
        prev_rresp_   = rresp;   prev_rlast_   = rlast;   prev_rid_    = rid;
    }

    uint64_t get_violations() const { return violations_; }
    const std::string& get_name() const { return name_; }

private:
    void record_violation(uint64_t cycle, const std::string& desc) {
        violations_++;
        std::cerr << "[AXI4_PROTOCOL_ASSERTION_FAIL] Cycle " << cycle 
                  << " Port: " << name_ << " : " << desc << std::endl;
    }

    std::string name_;
    bool is_master_;
    uint64_t violations_;

    std::deque<WriteTx> pending_writes_;
    std::deque<ReadTx>  pending_reads_;

    bool     prev_awvalid_ = false, prev_awready_ = false;
    uint64_t prev_awaddr_  = 0;
    uint8_t  prev_awid_ = 0, prev_awlen_ = 0, prev_awsize_ = 0, prev_awburst_ = 0;

    bool     prev_wvalid_ = false, prev_wready_ = false, prev_wlast_ = false;
    uint64_t prev_wdata_  = 0;
    uint8_t  prev_wstrb_  = 0;

    bool     prev_bvalid_ = false, prev_bready_ = false;
    uint8_t  prev_bresp_ = 0, prev_bid_ = 0;

    bool     prev_arvalid_ = false, prev_arready_ = false;
    uint64_t prev_araddr_  = 0;
    uint8_t  prev_arid_ = 0, prev_arlen_ = 0, prev_arsize_ = 0, prev_arburst_ = 0;

    bool     prev_rvalid_ = false, prev_rready_ = false, prev_rlast_ = false;
    uint64_t prev_rdata_  = 0;
    uint8_t  prev_rresp_ = 0, prev_rid_ = 0;
};

#endif // TITAN_X_AXI4_MONITOR_HPP
