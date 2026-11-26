//      // verilator_coverage annotation
        // SPDX-License-Identifier: Apache-2.0
        // SMVDU-TITAN-X SoC — AXI4 Crossbar (15 Masters × 9 Slaves)
        // Iteration 4: queue-based routing replacing the self-clearing grant scheme.
        //
        // Iteration 3 defect (root cause of every write hanging at the W handshake):
        // W/B/R routing was keyed on s_*_gnt registers that cleared to "no grant" the
        // moment awvalid dropped — i.e. one cycle after every AW handshake. Transaction
        // state now lives in FIFOs pushed on address-handshake and popped on completion
        // handshake, so a transaction stays routable for its whole lifetime:
        //
        //   per-master wr_wq[m] : target slave of each outstanding write; W beats are
        //                         routed to the head; popped on the WLAST handshake.
        //   per-master rd_tgt/cnt : outstanding-read target (single-target contract);
        //                         popped when its owned RLAST beat is accepted.
        //   per-slave  b_own[s] : which master owns the next B response; pushed on AW
        //                         handshake, popped on B acceptance.
        //   per-slave  r_own[s] : which master owns the next R beat; pushed on AR
        //                         handshake, popped on the RLAST beat.
        //
        // Ordering contract: a master may pipeline transactions, but only to the same
        // target slave until they drain (every master in this SoC is in-order). This
        // keeps each master's response source unique at any instant, so B/R demux by
        // owner-FIFO head is exact. Bursts pass through beat-by-beat. Addresses that
        // decode to no slave get an internal DECERR responder instead of silently
        // landing on real slave 8 (the Iteration 3 collision).
        `timescale 1ns/1ps
        
        module axi4_crossbar #(
            parameter NM   = 15,  // Number of masters
            parameter NS   = 9,   // Number of slaves
            parameter AW   = 40,  // Address width
            parameter DW   = 64,  // Data width
            parameter IDW  = 4,   // Master ID width
            parameter OUTS = 4    // Outstanding transactions tracked per master/slave
        ) (
            input  wire                 clk,
            input  wire                 rst_n,
        
            // ── Master Ports (Flattened) ─────────────────────────────────
            input  wire [NM-1:0]        m_awvalid,
            output wire [NM-1:0]        m_awready,
            input  wire [(NM*AW)-1:0]   m_awaddr,
            input  wire [(NM*IDW)-1:0]  m_awid,
            input  wire [(NM*8)-1:0]    m_awlen,
            input  wire [(NM*3)-1:0]    m_awsize,
            input  wire [(NM*2)-1:0]    m_awburst,
        
            input  wire [NM-1:0]        m_wvalid,
            output wire [NM-1:0]        m_wready,
            input  wire [(NM*DW)-1:0]   m_wdata,
            input  wire [(NM*(DW/8))-1:0] m_wstrb,
            input  wire [NM-1:0]        m_wlast,
        
            output wire [NM-1:0]        m_bvalid,
            input  wire [NM-1:0]        m_bready,
            output wire [(NM*2)-1:0]    m_bresp,
            output wire [(NM*IDW)-1:0]  m_bid,
        
            input  wire [NM-1:0]        m_arvalid,
            output wire [NM-1:0]        m_arready,
            input  wire [(NM*AW)-1:0]   m_araddr,
            input  wire [(NM*IDW)-1:0]  m_arid,
            input  wire [(NM*8)-1:0]    m_arlen,
            input  wire [(NM*3)-1:0]    m_arsize,
            input  wire [(NM*2)-1:0]    m_arburst,
        
            output wire [NM-1:0]        m_rvalid,
            input  wire [NM-1:0]        m_rready,
            output wire [(NM*DW)-1:0]   m_rdata,
            output wire [(NM*2)-1:0]    m_rresp,
            output wire [NM-1:0]        m_rlast,
            output wire [(NM*IDW)-1:0]  m_rid,
            input  wire [(NM*4)-1:0]    m_awqos,
            input  wire [(NM*4)-1:0]    m_arqos,
        
            // ── Slave Ports (Flattened) ──────────────────────────────────
            output wire [NS-1:0]        s_awvalid,
            input  wire [NS-1:0]        s_awready,
            output wire [(NS*AW)-1:0]   s_awaddr,
            output wire [(NS*IDW)-1:0]  s_awid,
            output wire [(NS*8)-1:0]    s_awlen,
            output wire [(NS*3)-1:0]    s_awsize,
            output wire [(NS*2)-1:0]    s_awburst,
        
            output wire [NS-1:0]        s_wvalid,
            input  wire [NS-1:0]        s_wready,
            output wire [(NS*DW)-1:0]   s_wdata,
            output wire [(NS*(DW/8))-1:0] s_wstrb,
            output wire [NS-1:0]        s_wlast,
        
            input  wire [NS-1:0]        s_bvalid,
            output wire [NS-1:0]        s_bready,
            input  wire [(NS*2)-1:0]    s_bresp,
            input  wire [(NS*IDW)-1:0]  s_bid,
        
            output wire [NS-1:0]        s_arvalid,
            input  wire [NS-1:0]        s_arready,
            output wire [(NS*AW)-1:0]   s_araddr,
            output wire [(NS*IDW)-1:0]  s_arid,
            output wire [(NS*8)-1:0]    s_arlen,
            output wire [(NS*3)-1:0]    s_arsize,
            output wire [(NS*2)-1:0]    s_arburst,
        
            input  wire [NS-1:0]        s_rvalid,
            output wire [NS-1:0]        s_rready,
            input  wire [(NS*DW)-1:0]   s_rdata,
            input  wire [(NS*2)-1:0]    s_rresp,
            input  wire [NS-1:0]        s_rlast,
            input  wire [(NS*IDW)-1:0]  s_rid
        );
        
            localparam T_UNMAPPED = 4'd9;   // virtual target: answered internally
        
            // -------------------------------------------------------
            // Address Decoding (matches titan_x_top slave wiring)
            // -------------------------------------------------------
            // -------------------------------------------------------
            // Address Decoding (matches titan_x_top slave wiring)
            // -------------------------------------------------------
            // S0: DDR4            (0x8000_0000 - 0xFFFF_FFFF)
            // S1: AHB/APB bridge  (0x4000_0000 primary + 0x2000/0x3000/0x0C00/0x0200 aliases)
            // S2: BootROM         (0x1000_0000 - 0x1FFF_FFFF)
            // S3: Low Mem / SRAM  (0x0000_0000 - 0x01FF_FFFF)
            // S4-S8: Unused peripheral banks (assigned in top)
 000576     function [3:0] decode_slave;
                input [AW-1:0] addr;
 000576         begin
 6879196             if      (addr[39:31] == 9'h001)   decode_slave = 4'd0; // DDR
 202918             else if (addr[39:28] == 12'h004 || // APB bridge primary
                             addr[39:28] == 12'h002 || // Security peripherals (0x2000_0000)
                             addr[39:28] == 12'h003 || // CAN peripherals (0x3000_0000)
                             addr[39:24] == 16'h000C|| // Standard RISC-V PLIC (0x0C00_0000)
                             addr[39:24] == 16'h0002)  // Standard RISC-V CLINT (0x0200_0000)
 202918                                               decode_slave = 4'd1; // APB bridge
 223567             else if (addr[39:28] == 12'h001)  decode_slave = 4'd2; // BootROM
 005856             else if (addr[39:28] == 12'h000)  decode_slave = 4'd3; // Low Memory / SRAM
 005856             else                              decode_slave = T_UNMAPPED;
                end
            endfunction
        
            // -------------------------------------------------------
            // State
            // -------------------------------------------------------
            reg [3:0]  wr_q   [0:NM-1][0:OUTS-1];  // outstanding-write targets
            reg [1:0]  wr_rp  [0:NM-1];
            reg [1:0]  wr_cnt [0:NM-1];
        
            reg [3:0]  rd_tgt  [0:NM-1];           // outstanding-read target (or F)
            reg [1:0]  rd_cnt  [0:NM-1];
        
            reg [1:0]  err_b_cnt [0:NM-1];         // unmapped writes awaiting B
            reg        err_b_act [0:NM-1];
            reg [IDW-1:0] err_bid [0:NM-1][0:OUTS-1];
            reg [1:0]  err_b_rp  [0:NM-1];
        
            reg [1:0]  err_r_cnt [0:NM-1];         // unmapped reads awaiting R
            reg        err_r_act [0:NM-1];
            reg [IDW-1:0] err_rid [0:NM-1][0:OUTS-1];
            reg [1:0]  err_r_rp  [0:NM-1];
        
            reg [3:0]  b_own  [0:NS-1][0:OUTS-1];  // next B response owner
            reg [1:0]  b_rp   [0:NS-1];
            reg [1:0]  b_cnt  [0:NS-1];
            reg [3:0]  r_own  [0:NS-1][0:OUTS-1];  // next R beat owner
            reg [1:0]  r_rp   [0:NS-1];
            reg [1:0]  r_cnt  [0:NS-1];
        
            reg [3:0]  rr_aw [0:NS-1];
            reg [3:0]  rr_w  [0:NS-1];
            reg [3:0]  rr_ar [0:NS-1];
        
            integer i, j;
        
            // -------------------------------------------------------
            // Targets & combinational arbitration
            // -------------------------------------------------------
            wire [3:0] aw_tgt [0:NM-1];
            wire [3:0] ar_tgt [0:NM-1];
            wire [3:0] m_awqos_eff [0:NM-1];
            wire [3:0] m_arqos_eff [0:NM-1];
            genvar gm;
            generate for (gm = 0; gm < NM; gm = gm + 1) begin : g_tgt
                assign aw_tgt[gm] = decode_slave(m_awaddr[gm*AW +: AW]);
                assign ar_tgt[gm] = decode_slave(m_araddr[gm*AW +: AW]);
                assign m_awqos_eff[gm] = m_awqos[gm*4 +: 4];
                assign m_arqos_eff[gm] = m_arqos[gm*4 +: 4];
            end endgenerate
        
            reg [4:0] aw_sel [0:NS-1];
            reg [4:0] w_sel  [0:NS-1];
            reg [4:0] ar_sel [0:NS-1];
            reg [3:0] best_aw_qos [0:NS-1];
            reg [3:0] best_ar_qos [0:NS-1];
            integer s_aw, k_aw, mm_aw;
            integer s_ar, k_ar, mm_ar;
            integer s_w,  k_w,  mm_w;
            integer s;
        
            // AW channel arbitration (QoS-prioritized with round-robin tie-break)
 000018     always @* begin
 000018         for (s_aw = 0; s_aw < NS; s_aw = s_aw + 1) begin
 000162             aw_sel[s_aw] = 5'd31;
 000162             best_aw_qos[s_aw] = 4'h0;
 000162             for (k_aw = 0; k_aw < NM; k_aw = k_aw + 1) begin
 112342320                 mm_aw = rr_aw[s_aw] + k_aw; if (mm_aw >= NM) mm_aw = mm_aw - NM;
 112342320                 if (m_awvalid[mm_aw] &&
                            (aw_tgt[mm_aw] == s_aw[3:0]) && (wr_cnt[mm_aw] != 2'd3) &&
                            ((wr_cnt[mm_aw] == 2'd0) ||
%000000                      (wr_q[mm_aw][wr_rp[mm_aw]] == aw_tgt[mm_aw]))) begin
%000000                     if ((aw_sel[s_aw] == 5'd31) || (m_awqos_eff[mm_aw] > best_aw_qos[s_aw])) begin
%000000                         aw_sel[s_aw] = mm_aw[4:0];
%000000                         best_aw_qos[s_aw] = m_awqos_eff[mm_aw];
                            end
                        end
                    end
                end
            end
        
            // AR channel arbitration (QoS-prioritized with round-robin tie-break)
 000018     always @* begin
 000018         for (s_ar = 0; s_ar < NS; s_ar = s_ar + 1) begin
 000162             ar_sel[s_ar] = 5'd31;
 000162             best_ar_qos[s_ar] = 4'h0;
 000162             for (k_ar = 0; k_ar < NM; k_ar = k_ar + 1) begin
 112342320                 mm_ar = rr_ar[s_ar] + k_ar; if (mm_ar >= NM) mm_ar = mm_ar - NM;
 000080                 if (m_arvalid[mm_ar] &&
                            (ar_tgt[mm_ar] == s_ar[3:0]) &&
 000080                     ((rd_cnt[mm_ar] == 2'd0) || (rd_tgt[mm_ar] == ar_tgt[mm_ar]))) begin
 000080                     if ((ar_sel[s_ar] == 5'd31) || (m_arqos_eff[mm_ar] > best_ar_qos[s_ar])) begin
%000000                         ar_sel[s_ar] = mm_ar[4:0];
%000000                         best_ar_qos[s_ar] = m_arqos_eff[mm_ar];
                            end
                        end
                    end
                end
            end
        
            // W channel arbitration
 000018     always @* begin
 000018         for (s_w = 0; s_w < NS; s_w = s_w + 1) begin
 000162             w_sel[s_w] = 5'd31;
 000162             for (k_w = 0; k_w < NM; k_w = k_w + 1) begin
 112342320                 mm_w = rr_w[s_w] + k_w; if (mm_w >= NM) mm_w = mm_w - NM;
 112342320                 if ((w_sel[s_w] == 5'd31) && (wr_cnt[mm_w] != 0) &&
                            (wr_q[mm_w][wr_rp[mm_w]] == s_w[3:0]))
%000000                     w_sel[s_w] = mm_w[4:0];
                    end
                end
            end
        
            // Handshakes through the selections
            wire aw_hs [0:NS-1];
            wire ar_hs [0:NS-1];
            wire wl_hs [0:NS-1];   // WLAST beat accepted by a slave
            genvar gs;
            generate for (gs = 0; gs < NS; gs = gs + 1) begin : g_hs
                assign aw_hs[gs] = (aw_sel[gs] != 5'd31) && s_awready[gs];
                assign ar_hs[gs] = (ar_sel[gs] != 5'd31) && s_arready[gs];
                assign wl_hs[gs] = (w_sel[gs] != 5'd31) && m_wvalid[w_sel[gs]] &&
                                   m_wlast[w_sel[gs]]   && s_wready[gs];
            end endgenerate
        
            // -------------------------------------------------------
            // Sequential: FIFO maintenance & pointers
            // -------------------------------------------------------
 780137     always @(posedge clk or negedge rst_n) begin
 216630         if (!rst_n) begin
 216630             for (i = 0; i < NM; i = i + 1) begin
 3466080                 for (j = 0; j < OUTS; j = j + 1) begin
 13864320                     wr_q[i][j]    <= 4'hF;
 13864320                     err_bid[i][j] <= {IDW{1'b0}};
 13864320                     err_rid[i][j] <= {IDW{1'b0}};
                        end
 3466080                 wr_rp[i] <= 2'd0;  wr_cnt[i] <= 2'd0;
 3466080                 rd_tgt[i] <= 4'hF; rd_cnt[i] <= 2'd0;
 3466080                 err_b_cnt[i] <= 2'd0; err_b_act[i] <= 1'b0; err_b_rp[i] <= 2'd0;
 3466080                 err_r_cnt[i] <= 2'd0; err_r_act[i] <= 1'b0; err_r_rp[i] <= 2'd0;
                    end
 216630             for (i = 0; i < NS; i = i + 1) begin
 1949670                 for (j = 0; j < OUTS; j = j + 1) begin
 7798680                     b_own[i][j] <= 4'hF;
 7798680                     r_own[i][j] <= 4'hF;
                        end
 1949670                 b_rp[i] <= 2'd0; b_cnt[i] <= 2'd0;
 1949670                 r_rp[i] <= 2'd0; r_cnt[i] <= 2'd0;
 1949670                 rr_aw[i] <= 4'd0; rr_w[i] <= 4'd0; rr_ar[i] <= 4'd0;
                    end
 563507         end else begin
                    // ---- per-master queues ----
                    // Push/pop on the SAME edge must not fight: independent
                    // if-blocks let the later NBA silently cancel the earlier one
                    // (a push erased by a same-cycle pop lost a whole transaction).
 563507             for (i = 0; i < NM; i = i + 1) begin : m_loop
                        reg wpush, wpop, rpush, rpop;
 9016112                 begin
 9016112                     wpush = (aw_tgt[i] < T_UNMAPPED) && m_awready[i] && m_awvalid[i];
 9016112                     wpop  = (wr_cnt[i] != 0) &&
 9016112                             (wr_q[i][wr_rp[i]] < T_UNMAPPED) &&
 9016112                             wl_hs[wr_q[i][wr_rp[i]]];
 9016112                     if (wpush)
%000000                         wr_q[i][(wr_rp[i] + wr_cnt[i]) & 2'h3] <= aw_tgt[i];
%000000                     if (wpush && !wpop)      wr_cnt[i] <= wr_cnt[i] + 2'd1;
%000000                     else if (!wpush && wpop) begin
%000000                         wr_rp[i]  <= wr_rp[i] + 2'd1;
%000000                         wr_cnt[i] <= wr_cnt[i] - 2'd1;
 9016112                     end else if (wpush && wpop) begin
%000000                         wr_rp[i]  <= wr_rp[i] + 2'd1;
                            end
        
 9016112                     rpush = (ar_tgt[i] < T_UNMAPPED) && m_arready[i] && m_arvalid[i];
 9016112                     rpop  = (rd_cnt[i] != 0) && (rd_tgt[i] < T_UNMAPPED) &&
 9016112                             s_rvalid[rd_tgt[i]] && s_rready[rd_tgt[i]] &&
 9016112                             s_rlast[rd_tgt[i]] &&
 9016112                             (r_own[rd_tgt[i]][r_rp[rd_tgt[i]]] == i[3:0]);
 000048                     if (rpush) rd_tgt[i] <= ar_tgt[i];
 000048                     if (rpush && !rpop)      rd_cnt[i] <= rd_cnt[i] + 2'd1;
 000048                     else if (!rpush && rpop) rd_cnt[i] <= rd_cnt[i] - 2'd1;
                        end
                    end
        
                    // ---- per-slave owner FIFOs (same push/pop discipline) ----
 563507             for (s = 0; s < NS; s = s + 1) begin : s_loop
                        reg bpush, bpop, rpush2, rpop2;
 5071563                 begin
 5071563                     bpush = aw_hs[s];
 5071563                     bpop  = (b_cnt[s] != 0) && s_bvalid[s] && s_bready[s];
 5071563                     if (bpush)
%000000                         b_own[s][(b_rp[s] + b_cnt[s]) & 2'h3] <= aw_sel[s][3:0];
%000000                     if (bpush && !bpop)      b_cnt[s] <= b_cnt[s] + 2'd1;
%000000                     else if (!bpush && bpop) begin
%000000                         b_rp[s]  <= b_rp[s] + 2'd1;
%000000                         b_cnt[s] <= b_cnt[s] - 2'd1;
 5071563                     end else if (bpush && bpop) begin
%000000                         b_rp[s]  <= b_rp[s] + 2'd1;
                            end
        
 5071563                     rpush2 = ar_hs[s];
 5071563                     rpop2  = (r_cnt[s] != 0) && s_rvalid[s] && s_rready[s]
 5071563                              && s_rlast[s];
 5071563                     if (rpush2)
%000000                         r_own[s][(r_rp[s] + r_cnt[s]) & 2'h3] <= ar_sel[s][3:0];
%000000                     if (rpush2 && !rpop2)      r_cnt[s] <= r_cnt[s] + 2'd1;
%000000                     else if (!rpush2 && rpop2) begin
%000000                         r_rp[s]  <= r_rp[s] + 2'd1;
%000000                         r_cnt[s] <= r_cnt[s] - 2'd1;
 5071563                     end else if (rpush2 && rpop2) begin
%000000                         r_rp[s]  <= r_rp[s] + 2'd1;
                            end
                        end
                    end
        
                    // ---- unmapped-access responders ----
                    // Same push/pop discipline: a same-cycle push while the error B/R
                    // drains must not let the pop's count-decrement erase the push.
 563507             for (i = 0; i < NM; i = i + 1) begin : e_loop
                        reg bpush3, bpop3, rpush3, rpop3;
 9016112                 begin
 9016112                     bpush3 = m_awvalid[i] && m_awready[i]
 9016112                              && (aw_tgt[i] == T_UNMAPPED);
 9016112                     bpop3  = err_b_act[i] && m_bready[i];
 9016112                     if (bpush3)
%000000                         err_bid[i][(err_b_rp[i] + err_b_cnt[i]) & 2'h3]
%000000                             <= m_awid[i*IDW +: IDW];
%000001                     if (!err_b_act[i] && (err_b_cnt[i] != 0))
%000001                         err_b_act[i] <= 1'b1;
%000000                     else if (bpush3 && !bpop3)      err_b_cnt[i] <= err_b_cnt[i] + 2'd1;
%000000                     else if (!bpush3 && bpop3) begin
%000000                         err_b_act[i] <= 1'b0;
%000000                         err_b_rp[i]  <= err_b_rp[i] + 2'd1;
%000000                         err_b_cnt[i] <= err_b_cnt[i] - 2'd1;
 9016111                     end else if (bpush3 && bpop3) begin
%000000                         err_b_rp[i]  <= err_b_rp[i] + 2'd1;
%000000                         err_b_act[i] <= 1'b1;
                            end
        
 9016112                     rpush3 = m_arvalid[i] && m_arready[i]
 9016112                              && (ar_tgt[i] == T_UNMAPPED);
 9016112                     rpop3  = err_r_act[i] && m_rready[i];
 9016112                     if (rpush3)
%000000                         err_rid[i][(err_r_rp[i] + err_r_cnt[i]) & 2'h3]
%000000                             <= m_arid[i*IDW +: IDW];
 001144                     if (!err_r_act[i] && (err_r_cnt[i] != 0))
 001144                         err_r_act[i] <= 1'b1;
%000000                     else if (rpush3 && !rpop3)      err_r_cnt[i] <= err_r_cnt[i] + 2'd1;
%000000                     else if (!rpush3 && rpop3) begin
%000000                         err_r_act[i] <= 1'b0;
%000000                         err_r_rp[i]  <= err_r_rp[i] + 2'd1;
%000000                         err_r_cnt[i] <= err_r_cnt[i] - 2'd1;
 9014968                     end else if (rpush3 && rpop3) begin
%000000                         err_r_rp[i]  <= err_r_rp[i] + 2'd1;
%000000                         err_r_act[i] <= 1'b1;
                            end
                        end
                    end
        
                    // ---- round-robin pointer updates on service ----
 563507             for (s = 0; s < NS; s = s + 1) begin : rr_loop
 009619                 if (aw_hs[s]) rr_aw[s] <= aw_sel[s][3:0] + 4'd1;
 181946                 if (ar_hs[s]) rr_ar[s] <= ar_sel[s][3:0] + 4'd1;
 009619                 if ((w_sel[s] != 5'd31) && m_wvalid[w_sel[s]] && s_wready[s])
 009619                     rr_w[s] <= w_sel[s][3:0] + 4'd1;
                    end
                end
            end
        
            // Owner lookups: with the single-target contract, at most one slave can
            // hold this master in its owner-FIFO head at any time. Computed in an
            // always @* (NOT a function of the master index alone — a function in a
            // continuous assign re-evaluates only when its arguments change, and the
            // master index never changes).
            reg [3:0] b_src [0:NM-1];
            reg [3:0] r_src [0:NM-1];
            integer si, sj, own_m;
 000018     always @* begin
 000018         own_m = 0;
 000018         for (si = 0; si < NM; si = si + 1) begin
 000288             b_src[si] = 4'hF;
 000288             r_src[si] = 4'hF;
                end
 000018         for (sj = 0; sj < NS; sj = sj + 1) begin
 049712             if (b_cnt[sj] != 0) begin
 049712                 own_m = b_own[sj][b_rp[sj]];
 014702                 if (b_src[own_m] == 4'hF) b_src[own_m] = sj[3:0];
                    end
 320096             if (r_cnt[sj] != 0) begin
 320096                 own_m = r_own[sj][r_rp[sj]];
 000288                 if (r_src[own_m] == 4'hF) r_src[own_m] = sj[3:0];
                    end
                end
            end
        
            // -------------------------------------------------------
            // Output assembly
            // -------------------------------------------------------
            genvar gs2;
            generate for (gs2 = 0; gs2 < NS; gs2 = gs2 + 1) begin : g_fwd
                assign s_awvalid[gs2] = (aw_sel[gs2] != 5'd31);
                assign s_awaddr[gs2*AW +: AW]  = (aw_sel[gs2] != 5'd31)
                    ? m_awaddr[aw_sel[gs2]*AW +: AW] : {AW{1'b0}};
                assign s_awid[gs2*IDW +: IDW]  = (aw_sel[gs2] != 5'd31)
                    ? m_awid[aw_sel[gs2]*IDW +: IDW] : {IDW{1'b0}};
                assign s_awlen[gs2*8 +: 8]     = (aw_sel[gs2] != 5'd31)
                    ? m_awlen[aw_sel[gs2]*8 +: 8] : 8'd0;
                assign s_awsize[gs2*3 +: 3]    = (aw_sel[gs2] != 5'd31)
                    ? m_awsize[aw_sel[gs2]*3 +: 3] : 3'd0;
                assign s_awburst[gs2*2 +: 2]   = (aw_sel[gs2] != 5'd31)
                    ? m_awburst[aw_sel[gs2]*2 +: 2] : 2'd0;
        
                assign s_arvalid[gs2] = (ar_sel[gs2] != 5'd31);
                assign s_araddr[gs2*AW +: AW]  = (ar_sel[gs2] != 5'd31)
                    ? m_araddr[ar_sel[gs2]*AW +: AW] : {AW{1'b0}};
                assign s_arid[gs2*IDW +: IDW]  = (ar_sel[gs2] != 5'd31)
                    ? m_arid[ar_sel[gs2]*IDW +: IDW] : {IDW{1'b0}};
                assign s_arlen[gs2*8 +: 8]     = (ar_sel[gs2] != 5'd31)
                    ? m_arlen[ar_sel[gs2]*8 +: 8] : 8'd0;
                assign s_arsize[gs2*3 +: 3]    = (ar_sel[gs2] != 5'd31)
                    ? m_arsize[ar_sel[gs2]*3 +: 3] : 3'd0;
                assign s_arburst[gs2*2 +: 2]   = (ar_sel[gs2] != 5'd31)
                    ? m_arburst[ar_sel[gs2]*2 +: 2] : 2'd0;
        
                assign s_wvalid[gs2] = (w_sel[gs2] != 5'd31) ? m_wvalid[w_sel[gs2]] : 1'b0;
                assign s_wdata[gs2*DW +: DW] = (w_sel[gs2] != 5'd31)
                    ? m_wdata[w_sel[gs2]*DW +: DW] : {DW{1'b0}};
                assign s_wstrb[gs2*(DW/8) +: (DW/8)] = (w_sel[gs2] != 5'd31)
                    ? m_wstrb[w_sel[gs2]*(DW/8) +: (DW/8)] : {(DW/8){1'b0}};
                assign s_wlast[gs2]  = (w_sel[gs2] != 5'd31) ? m_wlast[w_sel[gs2]] : 1'b0;
        
                // Response readiness flows back to the owning master only
                assign s_bready[gs2] = (b_cnt[gs2] != 0)
                    ? m_bready[b_own[gs2][b_rp[gs2]]] : 1'b1;
                assign s_rready[gs2] = (r_cnt[gs2] != 0)
                    ? m_rready[r_own[gs2][r_rp[gs2]]] : 1'b1;
            end endgenerate
        
            genvar gm2;
            generate for (gm2 = 0; gm2 < NM; gm2 = gm2 + 1) begin : g_mst
                wire [3:0] at = aw_tgt[gm2];
                wire [3:0] rt = ar_tgt[gm2];
                wire aw_grant = (at < T_UNMAPPED) && (aw_sel[at[3:0]] == gm2[4:0])
                                && s_awready[at[3:0]];
                wire ar_grant = (rt < T_UNMAPPED) && (ar_sel[rt[3:0]] == gm2[4:0])
                                && s_arready[rt[3:0]];
                assign m_awready[gm2] = aw_grant || (at == T_UNMAPPED);
                assign m_arready[gm2] = ar_grant || (rt == T_UNMAPPED);
        
                // W beats: gated by head slave readiness; absorbed when unmapped
                wire       w_have = (wr_cnt[gm2] != 0);
                wire [3:0] wt     = wr_q[gm2][wr_rp[gm2]];
                assign m_wready[gm2] = w_have &&
                    ((wt < T_UNMAPPED) ? s_wready[wt[3:0]] : 1'b1);
        
                // B response: error engine takes priority; else the owned slave's
                wire [3:0] bt  = b_src[gm2];
                assign m_bvalid[gm2] = err_b_act[gm2] ||
                    ((bt < T_UNMAPPED) ? (b_own[bt[3:0]][b_rp[bt[3:0]]] == gm2[3:0]) &&
                                         s_bvalid[bt[3:0]] : 1'b0);
                assign m_bresp[gm2*2 +: 2] = err_b_act[gm2] ? 2'b11 :
                    ((bt < T_UNMAPPED) ? s_bresp[bt[3:0]*2 +: 2] : 2'b00);
                assign m_bid[gm2*IDW +: IDW] = err_b_act[gm2]
                    ? err_bid[gm2][err_b_rp[gm2]]
                    : ((bt < T_UNMAPPED) ? s_bid[bt[3:0]*IDW +: IDW] : {IDW{1'b0}});
        
                // R beats: error engine first; else the owned slave's stream
                wire [3:0] rtq = r_src[gm2];
                assign m_rvalid[gm2] = err_r_act[gm2] ||
                    ((rtq < T_UNMAPPED) ? (r_own[rtq[3:0]][r_rp[rtq[3:0]]] == gm2[3:0]) &&
                                          s_rvalid[rtq[3:0]] : 1'b0);
                assign m_rdata[gm2*DW +: DW] = err_r_act[gm2] ? {DW{1'b0}} :
                    ((rtq < T_UNMAPPED) ? s_rdata[rtq[3:0]*DW +: DW] : {DW{1'b0}});
                assign m_rresp[gm2*2 +: 2] = err_r_act[gm2] ? 2'b11 :
                    ((rtq < T_UNMAPPED) ? s_rresp[rtq[3:0]*2 +: 2] : 2'b00);
                assign m_rlast[gm2] = err_r_act[gm2] ? 1'b1 :
                    ((rtq < T_UNMAPPED) ? s_rlast[rtq[3:0]] : 1'b0);
                assign m_rid[gm2*IDW +: IDW] = err_r_act[gm2]
                    ? err_rid[gm2][err_r_rp[gm2]]
                    : ((rtq < T_UNMAPPED) ? s_rid[rtq[3:0]*IDW +: IDW] : {IDW{1'b0}});
            end endgenerate
        
        endmodule
        
