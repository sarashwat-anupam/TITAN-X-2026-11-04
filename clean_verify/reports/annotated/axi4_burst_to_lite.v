//      // verilator_coverage annotation
        // SPDX-License-Identifier: Apache-2.0
        // SMVDU-TITAN-X SoC — AXI4 burst-master → single-beat-master shim
        //
        // The L1 caches refill/evict with 8-beat INCR bursts, but this SoC's
        // memory-side controllers are single-beat (ddr_ctrl_top answers SLVERR
        // for len>0). This shim decomposes every burst into N single-beat
        // transactions and reassembles the responses, so a burst-native master
        // can sit transparently behind the core's existing external ports.
        //
        // Read side : N AR/R round-trips, R beats forwarded with RLAST only on
        //             the final beat; per-beat RRESP passed through.
        // Write side: AW accepted up front, W beats collected into a line buffer,
        //             then N single-beat AW+W pairs; ONE B is returned upstream
        //             after the last downstream B. BRESP = worst response seen.
        //
        // No reordering, one outstanding burst either direction — matches the
        // cache FSMs' strictly serial use.
        `timescale 1ns/1ps
        
        module axi4_burst_to_lite #(
            parameter ADDR_W = 40,
            parameter DATA_W = 64,
            parameter MAX_BEATS = 8              // caches use arlen=7 / awlen=7
        )(
            input  wire clk,
            input  wire rst_n,
        
            // ---- upstream slave face (toward the cache) ----
            // read address
            input  wire               s_arvalid,
            output wire               s_arready,
            input  wire [ADDR_W-1:0]  s_araddr,
            input  wire [7:0]         s_arlen,
            input  wire [2:0]         s_arsize,
            input  wire [1:0]         s_arburst,
            // read data
            output reg                s_rvalid,
            input  wire               s_rready,
            output reg  [DATA_W-1:0]  s_rdata,
            output reg                s_rlast,
            output reg  [1:0]         s_rresp,
            // write address
            input  wire               s_awvalid,
            output wire               s_awready,
            input  wire [ADDR_W-1:0]  s_awaddr,
            input  wire [7:0]         s_awlen,
            input  wire [2:0]         s_awsize,
            input  wire [1:0]         s_awburst,
            // write data
            input  wire               s_wvalid,
            output reg                s_wready,
            input  wire [DATA_W-1:0]  s_wdata,
            input  wire [DATA_W/8-1:0] s_wstrb,
            input  wire               s_wlast,
            // write response
            output reg                s_bvalid,
            input  wire               s_bready,
            output reg  [1:0]         s_bresp,
        
            // ---- downstream master face (single-beat only) ----
            output reg                m_arvalid,
            input  wire               m_arready,
            output reg  [ADDR_W-1:0]  m_araddr,
            output wire [7:0]         m_arlen,     // tied 0
            output wire [2:0]         m_arsize,    // tied 3 (8B)
            output wire [1:0]         m_arburst,   // tied INCR
            input  wire               m_rvalid,
            output reg                m_rready,
            input  wire [DATA_W-1:0]  m_rdata,
            input  wire               m_rlast,
            input  wire [1:0]         m_rresp,
            output reg                m_awvalid,
            input  wire               m_awready,
            output reg  [ADDR_W-1:0]  m_awaddr,
            output wire [7:0]         m_awlen,     // tied 0
            output wire [2:0]         m_awsize,    // tied 3
            output wire [1:0]         m_awburst,   // tied INCR
            output reg                m_wvalid,
            input  wire               m_wready,
            output reg  [DATA_W-1:0]  m_wdata,
            output reg  [DATA_W/8-1:0] m_wstrb,
            output reg                m_wlast,     // always 1 downstream
            input  wire               m_bvalid,
            output reg                m_bready,
            input  wire [1:0]         m_bresp
        );
        
            assign m_arlen   = 8'h0;
            assign m_arsize  = 3'd3;
            assign m_arburst = 2'b01;
            assign m_awlen   = 8'h0;
            assign m_awsize  = 3'd3;
            assign m_awburst = 2'b01;
            assign m_wlast   = 1'b1;
        
            localparam BEAT_BYTES = DATA_W/8;
        
            // ------------------------------------------------------------
            // Read decomposition
            // ------------------------------------------------------------
            localparam R_IDLE = 2'd0, R_ADDR = 2'd1, R_DATA = 2'd2, R_FWD = 2'd3;
            reg [1:0]          rstate;
            reg [ADDR_W-1:0]   r_base;
            reg [7:0]          r_len, r_cnt;
        
            assign s_arready = (rstate == R_IDLE);
        
 7021233     always @(posedge clk or negedge rst_n) begin
 1733580         if (!rst_n) begin
 1733580             rstate      <= R_IDLE;
 1733580             m_arvalid   <= 1'b0;
 1733580             m_rready    <= 1'b0;
 1733580             s_rvalid    <= 1'b0;
 1733580             s_rdata     <= {DATA_W{1'b0}};
 1733580             s_rlast     <= 1'b0;
 1733580             s_rresp     <= 2'b00;
 1733580             r_base      <= {ADDR_W{1'b0}};
 1733580             r_len       <= 8'h0;
 1733580             r_cnt       <= 8'h0;
 1733580             m_araddr    <= {ADDR_W{1'b0}};
 5287653         end else begin
 5287653             case (rstate)
 4835974                 R_IDLE: begin
 002382                     if (s_arvalid) begin
 002382                         r_base    <= s_araddr;
 002382                         r_len     <= s_arlen;
 002382                         r_cnt     <= 8'h0;
 002382                         m_araddr  <= s_araddr;
 002382                         m_arvalid <= 1'b1;
 002382                         rstate    <= R_ADDR;
                            end
                        end
        
 257351                 R_ADDR: begin
 019056                     if (m_arready && m_arvalid) begin
 019056                         m_arvalid <= 1'b0;
 019056                         m_rready  <= 1'b1;
 019056                         rstate    <= R_DATA;
                            end
                        end
        
 175272                 R_DATA: begin
 019056                     if (m_rvalid && m_rready) begin
 019056                         m_rready  <= 1'b0;
 019056                         s_rdata   <= m_rdata;
 019056                         s_rresp   <= m_rresp;
 019056                         s_rlast   <= (r_cnt == r_len);
 019056                         s_rvalid  <= 1'b1;
 019056                         rstate    <= R_FWD;
                            end
                        end
        
 019056                 R_FWD: begin
%000000                     if (s_rvalid && s_rready) begin
 019056                         s_rvalid <= 1'b0;
 002382                         if (r_cnt == r_len) begin
 002382                             rstate <= R_IDLE;
 016674                         end else begin
 016674                             r_cnt    <= r_cnt + 8'h1;
 016674                             m_araddr <= r_base + (r_cnt + 8'h1) * BEAT_BYTES;
 016674                             m_arvalid<= 1'b1;
 016674                             rstate   <= R_ADDR;
                                end
                            end
                        end
        
%000000                 default: rstate <= R_IDLE;
                    endcase
                end
            end
        
            // ------------------------------------------------------------
            // Write decomposition
            // ------------------------------------------------------------
            // W_DONE (4) is deliberately outside the busy-encoding used by
            // s_awready/s_wready below: in it the shim owns an unaccepted B and
            // must not take a new AW.
            localparam W_IDLE = 3'd0, W_COLL = 3'd1, W_ISSUE = 3'd2,
                       W_RESP = 3'd3, W_DONE = 3'd4;
            reg [2:0]          wstate;
            reg [ADDR_W-1:0]   w_base;
            reg [7:0]          w_len, w_cnt, w_coll;
            reg [DATA_W-1:0]   w_buf [0:MAX_BEATS-1];
            reg [DATA_W/8-1:0] w_strb_buf [0:MAX_BEATS-1];
            reg                aw_issued, w_issued;
            reg [1:0]          w_resp_acc;
            reg [63:0]         cyc;
 7021233     always @(posedge clk or negedge rst_n) begin
 1733580         if (!rst_n) cyc <= 0;
 5287653         else cyc <= cyc + 1;
            end
        
            assign s_awready = (wstate == W_IDLE);
            assign s_wready  = (wstate == W_COLL);
        
 7021233     always @(posedge clk or negedge rst_n) begin
 1733580         if (!rst_n) begin
 1733580             wstate     <= W_IDLE;
 1733580             s_bvalid   <= 1'b0;
 1733580             s_bresp    <= 2'b00;
 1733580             m_awvalid  <= 1'b0;
 1733580             m_wvalid   <= 1'b0;
 1733580             m_bready   <= 1'b0;
 1733580             aw_issued  <= 1'b0;
 1733580             w_issued   <= 1'b0;
 1733580             w_base     <= {ADDR_W{1'b0}};
 1733580             w_len      <= 8'h0;
 1733580             w_cnt      <= 8'h0;
 1733580             w_coll     <= 8'h0;
 1733580             w_resp_acc <= 2'b00;
 1733580             m_awaddr   <= {ADDR_W{1'b0}};
 1733580             m_wdata    <= {DATA_W{1'b0}};
 1733580             m_wstrb    <= {(DATA_W/8){1'b0}};
 5287653         end else begin
 5287653             case (wstate)
 5196233                 W_IDLE: begin
 009261                     if (s_awvalid) begin
 009261                         w_base     <= s_awaddr;
 009261                         w_len      <= s_awlen;
 009261                         w_coll     <= 8'h0;
 009261                         w_cnt      <= 8'h0;
 009261                         w_resp_acc <= 2'b00;
 009261                         wstate     <= W_COLL;
                            end
                        end
        
 009261                 W_COLL: begin
%000000                     if (s_wvalid) begin
 009261                         w_buf[w_coll[2:0]]      <= s_wdata;
 009261                         w_strb_buf[w_coll[2:0]] <= s_wstrb;
 009261                         if ((w_base >> 4) == (40'h0082200820 >> 4)) begin
%000000                             $display("[B2L_WCOLL] cyc=%0d base=0x%010x beat=%0d data=0x%016x strb=0x%02x last=%b",
%000000                                      cyc, w_base, w_coll, s_wdata, s_wstrb, s_wlast);
                                end
%000000                         if (s_wlast || (w_coll == w_len)) begin
 009261                             w_coll    <= 8'h0;
 009261                             m_awaddr  <= w_base;
                                    // len==0 passthrough: beat0 is being captured
                                    // THIS edge — its NBA hasn't landed, so take it
                                    // straight from s_wdata/s_wstrb.
 009261                             m_wdata   <= (w_len == 8'h0) ? s_wdata : w_buf[0];
 009261                             m_wstrb   <= (w_len == 8'h0) ? s_wstrb : w_strb_buf[0];
 009261                             m_awvalid <= 1'b1;
 009261                             m_wvalid  <= 1'b1;
 009261                             aw_issued <= 1'b0;
 009261                             w_issued  <= 1'b0;
 009261                             wstate    <= W_ISSUE;
%000000                         end else begin
%000000                             w_coll <= w_coll + 8'h1;
                                end
                            end
                        end
        
 035420                 W_ISSUE: begin
 009261                     if (m_awvalid && m_awready) begin
 009261                         m_awvalid <= 1'b0;
 009261                         aw_issued <= 1'b1;
                            end
 009261                     if (m_wvalid && m_wready) begin
 009261                         m_wvalid <= 1'b0;
 009261                         w_issued <= 1'b1;
                            end
 035420                     if ((w_base >> 4) == (40'h0082200820 >> 4) && (m_awvalid || m_wvalid)) begin
%000000                         $display("[B2L_WISSUE] cyc=%0d cnt=%0d awaddr=0x%010x wdata=0x%016x awrdy=%b wrdy=%b",
%000000                                  cyc, w_cnt, m_awaddr, m_wdata, m_awready, m_wready);
                            end
 009261                     if ((aw_issued || (m_awvalid && m_awready)) &&
 009261                         (w_issued  || (m_wvalid && m_wready))) begin
 009261                         m_bready <= 1'b1;
 009261                         wstate   <= W_RESP;
                            end
                        end
        
 037478                 W_RESP: begin
 009261                     if (m_bvalid && m_bready) begin
 009261                         m_bready <= 1'b0;
 009261                         if (m_bresp != 2'b00)
%000000                             w_resp_acc <= 2'b10;      // degrade to SLVERR
%000000                         if (w_cnt == w_len) begin
 009261                             s_bresp  <= (w_resp_acc != 2'b00 ||
 009261                                          m_bresp != 2'b00) ? 2'b10 : 2'b00;
 009261                             s_bvalid <= 1'b1;
 009261                             wstate   <= W_DONE;
%000000                         end else begin
%000000                             w_cnt     <= w_cnt + 8'h1;
%000000                             m_awaddr  <= w_base + (w_cnt + 8'h1) * BEAT_BYTES;
%000000                             m_wdata   <= w_buf[(w_cnt + 8'h1) & (MAX_BEATS-1)];
%000000                             m_wstrb   <= w_strb_buf[(w_cnt + 8'h1) & (MAX_BEATS-1)];
%000000                             m_awvalid <= 1'b1;
%000000                             m_wvalid  <= 1'b1;
%000000                             aw_issued <= 1'b0;
%000000                             w_issued  <= 1'b0;
%000000                             wstate    <= W_ISSUE;
                                end
                            end
                        end
        
 009261                 W_DONE: begin
                            // Hold B upstream until accepted; only then rearm.
%000000                     if (s_bvalid && s_bready) begin
 009261                         s_bvalid <= 1'b0;
 009261                         wstate   <= W_IDLE;
                            end
                        end
        
%000000                 default: wstate <= W_IDLE;
                    endcase
                end
            end
        
        endmodule
        
