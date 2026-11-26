//      // verilator_coverage annotation
        // SPDX-License-Identifier: Apache-2.0
        // SMVDU-TITAN-X SoC — L2 Cache Controller
        // 16-Way Set-Associative, 64-byte line, Burst Refill & Writeback, MESI Dirty Intervention
        // Refactored to integrate banked foundry SRAM macros (DEF-ARCH-04) and scale geometry (DEF-ARCH-03).
        `timescale 1ns/1ps
        
        module l2_cache_ctrl #(
            parameter ADDR_W = 40,
            parameter DATA_W = 64,
            parameter OFF_W  = 6,   // 64B lines (8 beats of 64 bits)
            parameter WAYS   = 16,  // 16-way set-associative
            parameter SETS   = 64,
            parameter IDX_W  = $clog2(SETS),
            parameter TAG_W  = ADDR_W - OFF_W - IDX_W
        ) (
            input  wire              clk,
            input  wire              rst_n,
        
            // CPU-side AXI4-Lite slave (from crossbar/cores)
            input  wire              s_arvalid,
            output wire              s_arready,
            input  wire [ADDR_W-1:0] s_araddr,
            input  wire [3:0]        s_arid,
            output reg               s_rvalid,
            input  wire              s_rready,
            output wire [DATA_W-1:0] s_rdata,
            output reg  [1:0]        s_rresp,
        
            input  wire              s_awvalid,
            output wire              s_awready,
            input  wire [ADDR_W-1:0] s_awaddr,
            input  wire [3:0]        s_awid,
            input  wire              s_wvalid,
            output wire              s_wready,
            input  wire [DATA_W-1:0] s_wdata,
            input  wire [7:0]        s_wstrb,
            output reg               s_bvalid,
            input  wire              s_bready,
            output reg  [1:0]        s_bresp,
        
            // Memory-side AXI4 burst master (to burst-to-lite shim / DDR)
            output reg               m_arvalid,
            input  wire              m_arready,
            output reg  [ADDR_W-1:0] m_araddr,
            output reg  [7:0]        m_arlen,
            output reg  [2:0]        m_arsize,
            output reg  [1:0]        m_arburst,
            input  wire              m_rvalid,
            output reg               m_rready,
            input  wire [DATA_W-1:0] m_rdata,
            input  wire [1:0]        m_rresp,
            input  wire              m_rlast,
        
            output reg               m_awvalid,
            input  wire              m_awready,
            output reg  [ADDR_W-1:0] m_awaddr,
            output reg  [7:0]        m_awlen,
            output reg  [2:0]        m_awsize,
            output reg  [1:0]        m_awburst,
            output reg               m_wvalid,
            input  wire              m_wready,
            output reg  [DATA_W-1:0] m_wdata,
            output reg  [7:0]        m_wstrb,
            output reg               m_wlast,
            input  wire              m_bvalid,
            output reg               m_bready,
            input  wire [1:0]        m_bresp,
        
            // Snoop filter request/response interface
            output reg               sf_req_valid,
            output reg  [ADDR_W-1:0] sf_req_addr,
            output reg  [1:0]        sf_req_type,   // 00=ReadShared, 01=ReadUnique/Write
            output reg  [1:0]        sf_req_core,
            input  wire              sf_resp_valid,
            input  wire              sf_resp_hit,
            input  wire              sf_resp_dirty,
            input  wire [1:0]        sf_resp_owner,
            input  wire [511:0]      snoop_data
        );
        
            // ------------------------------------------------------------
            // States
            // ------------------------------------------------------------
            localparam ST_IDLE       = 4'd0;
            localparam ST_LOOKUP     = 4'd1;
            localparam ST_INTERVENE  = 4'd2;
            localparam ST_EVICT_AW   = 4'd3;
            localparam ST_EVICT_W    = 4'd4;
            localparam ST_EVICT_B    = 4'd5;
            localparam ST_REFILL_AR  = 4'd6;
            localparam ST_REFILL_R   = 4'd7;
            localparam ST_RESP_R     = 4'd8;
            localparam ST_RESP_W     = 4'd9;
            localparam ST_READ_HIT   = 4'd10;
            localparam ST_EVICT_BUF  = 4'd11;
        
            reg [3:0] state;
        
            // Latched transaction registers
            reg [ADDR_W-1:0] req_addr;
            reg [3:0]        req_id;
            reg [DATA_W-1:0] req_wdata;
            reg [7:0]        req_wstrb;
            reg              req_wr;
        
            reg [ADDR_W-1:0] awaddr_latched;
            reg [3:0]        awid_latched;
            reg [DATA_W-1:0] wdata_latched;
            reg [7:0]        wstrb_latched;
            reg              aw_pend, w_pend;
        
            // ------------------------------------------------------------
            // 16-Way Cache Arrays
            // ------------------------------------------------------------
            reg [TAG_W-1:0]  tag_mem     [0:SETS-1][0:WAYS-1];
            reg              valid_mem   [0:SETS-1][0:WAYS-1];
            reg              dirty_mem   [0:SETS-1][0:WAYS-1];
            reg [3:0]        replace_ptr [0:SETS-1];
        
            // Data array: Banked SRAM macro storage (DEF-ARCH-04)
            localparam ARRAY_ADDR_W = IDX_W + $clog2(WAYS) + 3;
        
            reg                     sram_cs;
            reg                     sram_we;
            reg  [7:0]              sram_wmask;
            reg  [ARRAY_ADDR_W-1:0] sram_addr;
            reg  [DATA_W-1:0]       sram_din;
            wire [DATA_W-1:0]       sram_dout;
            wire                    sram_dout_valid;
        
            l2_data_array #(
                .DATA_W(DATA_W),
                .DEPTH(SETS * WAYS * 8),
                .ADDR_W(ARRAY_ADDR_W)
            ) u_data_array (
                .clk(clk),
                .rst_n(rst_n),
                .cs(sram_cs),
                .we(sram_we),
                .wmask(sram_wmask),
                .addr(sram_addr),
                .din(sram_din),
                .dout(sram_dout),
                .dout_valid(sram_dout_valid)
            );
        
            reg [DATA_W-1:0] s_rdata_reg;
            reg              read_hit_flag;
            assign s_rdata = read_hit_flag ? sram_dout : s_rdata_reg;
        
            reg [DATA_W-1:0] evict_buffer [0:7];
            reg [3:0]        evict_cnt;
            reg [2:0]        intervene_cnt;
            reg [511:0]      snoop_line_latched;
        
            wire [TAG_W-1:0] req_tag     = req_addr[ADDR_W-1 : OFF_W+IDX_W];
            wire [IDX_W-1:0] req_index   = req_addr[OFF_W+IDX_W-1 : OFF_W];
            wire [2:0]       word_offset = req_addr[5:3];
        
            // 16-way combinational tag matching & hit detection
            reg [WAYS-1:0] way_hit_comb;
            reg [3:0]      hit_way_comb;
            reg            line_hit_comb;
            reg [3:0]      alloc_way_comb;
            integer w_idx;
        
 000018     always @* begin
 000018         way_hit_comb   = {WAYS{1'b0}};
 000018         hit_way_comb   = 4'd0;
 000018         line_hit_comb  = 1'b0;
 000018         alloc_way_comb = replace_ptr[req_index];
        
 000018         for (w_idx = 0; w_idx < WAYS; w_idx = w_idx + 1) begin
 488648             if (valid_mem[req_index][w_idx] && (tag_mem[req_index][w_idx] == req_tag)) begin
 488648                 way_hit_comb[w_idx] = 1'b1;
 488648                 hit_way_comb        = w_idx[3:0];
 488648                 line_hit_comb       = 1'b1;
                    end
                end
        
                // Prefer invalid way if available
 000018         for (w_idx = WAYS - 1; w_idx >= 0; w_idx = w_idx - 1) begin
 794065             if (!valid_mem[req_index][w_idx]) begin
 11688415                 alloc_way_comb = w_idx[3:0];
                    end
                end
            end
        
            // AXI4-Lite slave handshake readiness
            assign s_awready = (state == ST_IDLE) && !aw_pend;
            assign s_wready  = (state == ST_IDLE) && !w_pend;
            assign s_arready = (state == ST_IDLE) && !aw_pend && !w_pend && !s_awvalid && !s_wvalid;
        
            // Refill & Eviction counters and registers
            reg [2:0]        refill_cnt;
            reg [3:0]        target_way;
            reg [3:0]        evict_way;
            reg [DATA_W-1:0] read_word_latched;
        
            integer s_i, w_i, b_i;
        
 780137     always @(posedge clk or negedge rst_n) begin
 000540         if (!rst_n) begin
 000540             state             <= ST_IDLE;
 000540             s_rvalid          <= 1'b0;
 000540             s_rdata_reg       <= {DATA_W{1'b0}};
 000540             read_hit_flag     <= 1'b0;
 000540             s_rresp           <= 2'b00;
 000540             s_bvalid          <= 1'b0;
 000540             s_bresp           <= 2'b00;
        
 000540             m_arvalid         <= 1'b0;
 000540             m_araddr          <= {ADDR_W{1'b0}};
 000540             m_arlen           <= 8'd0;
 000540             m_arsize          <= 3'b011;
 000540             m_arburst         <= 2'b01;
 000540             m_rready          <= 1'b0;
        
 000540             m_awvalid         <= 1'b0;
 000540             m_awaddr          <= {ADDR_W{1'b0}};
 000540             m_awlen           <= 8'd0;
 000540             m_awsize          <= 3'b011;
 000540             m_awburst         <= 2'b01;
 000540             m_wvalid          <= 1'b0;
 000540             m_wdata           <= {DATA_W{1'b0}};
 000540             m_wstrb           <= 8'h00;
 000540             m_wlast           <= 1'b0;
 000540             m_bready          <= 1'b0;
        
 000540             sf_req_valid      <= 1'b0;
 000540             sf_req_addr       <= {ADDR_W{1'b0}};
 000540             sf_req_type       <= 2'b00;
 000540             sf_req_core       <= 2'b00;
        
 000540             sram_cs           <= 1'b0;
 000540             sram_we           <= 1'b0;
 000540             sram_wmask        <= 8'h00;
 000540             sram_addr         <= {ARRAY_ADDR_W{1'b0}};
 000540             sram_din          <= {DATA_W{1'b0}};
 000540             intervene_cnt     <= 3'd0;
 000540             snoop_line_latched<= 512'h0;
        
 000540             req_addr          <= {ADDR_W{1'b0}};
 000540             req_id            <= 4'h0;
 000540             req_wdata         <= {DATA_W{1'b0}};
 000540             req_wstrb         <= 8'h0;
 000540             req_wr            <= 1'b0;
 000540             awaddr_latched    <= {ADDR_W{1'b0}};
 000540             awid_latched      <= 4'h0;
 000540             wdata_latched     <= {DATA_W{1'b0}};
 000540             wstrb_latched     <= 8'h0;
 000540             aw_pend           <= 1'b0;
 000540             w_pend            <= 1'b0;
 000540             refill_cnt        <= 3'd0;
 000540             evict_cnt         <= 4'd0;
 000540             target_way        <= 4'd0;
 000540             evict_way         <= 4'd0;
 000540             read_word_latched <= {DATA_W{1'b0}};
        
 000540             for (b_i = 0; b_i < 8; b_i = b_i + 1) begin
 004320                 evict_buffer[b_i] <= {DATA_W{1'b0}};
                    end
        
 000540             for (s_i = 0; s_i < SETS; s_i = s_i + 1) begin
 1105920                 replace_ptr[s_i] = 4'd0;
 1105920                 for (w_i = 0; w_i < WAYS; w_i = w_i + 1) begin
 17694720                     valid_mem[s_i][w_i] = 1'b0;
 17694720                     dirty_mem[s_i][w_i] = 1'b0;
 17694720                     tag_mem[s_i][w_i]   = {TAG_W{1'b0}};
                        end
                    end
 779597         end else begin
 779597             sf_req_valid <= 1'b0; // Default pulse
        
 779597             case (state)
                        // ----------------------------------------------------
                        // IDLE: Accept incoming Read or Write requests
                        // ----------------------------------------------------
 590432                 ST_IDLE: begin
 590432                     sram_cs <= 1'b0;
 590432                     sram_we <= 1'b0;
 015959                     if (!aw_pend && !w_pend && s_arvalid && s_arready) begin
 015959                         req_addr     <= s_araddr;
 015959                         req_id       <= s_arid;
 015959                         req_wr       <= 1'b0;
        
                                // Issue Snoop Filter request
 015959                         sf_req_valid <= 1'b1;
 015959                         sf_req_addr  <= s_araddr;
 015959                         sf_req_type  <= 2'b00; // ReadShared
 015959                         sf_req_core  <= s_arid[1:0];
        
 015959                         state        <= ST_LOOKUP;
 574473                     end else begin
                                // If both AW and W captured or capturing now, start write transaction
 009105                         if (((s_awvalid && s_awready) || aw_pend) &&
 009105                             ((s_wvalid  && s_wready)  || w_pend)) begin
 009105                             req_addr     <= aw_pend ? awaddr_latched : s_awaddr;
 009105                             req_id       <= aw_pend ? awid_latched   : s_awid;
 009105                             req_wdata    <= w_pend  ? wdata_latched  : s_wdata;
 009105                             req_wstrb    <= w_pend  ? wstrb_latched  : s_wstrb;
 009105                             req_wr       <= 1'b1;
 009105                             aw_pend      <= 1'b0;
 009105                             w_pend       <= 1'b0;
        
                                    // Issue Snoop Filter request
 009105                             sf_req_valid <= 1'b1;
 009105                             sf_req_addr  <= aw_pend ? awaddr_latched : s_awaddr;
 009105                             sf_req_type  <= 2'b01; // ReadUnique/Write
 009105                             sf_req_core  <= aw_pend ? awid_latched[1:0] : s_awid[1:0];
        
 009105                             state        <= ST_LOOKUP;
 565368                         end else begin
                                    // Latch whichever arrived first
 009105                             if (s_awvalid && s_awready) begin
 009105                                 awaddr_latched <= s_awaddr;
 009105                                 awid_latched   <= s_awid;
 009105                                 aw_pend        <= 1'b1;
                                    end
 565368                             if (s_wvalid && s_wready) begin
%000000                                 wdata_latched  <= s_wdata;
%000000                                 wstrb_latched  <= s_wstrb;
%000000                                 w_pend         <= 1'b1;
                                    end
                                end
                            end
                        end
        
                        // ----------------------------------------------------
                        // LOOKUP: 16-way tag check & snoop filter response
                        // ----------------------------------------------------
 077214                 ST_LOOKUP: begin
 025063                     if (sf_resp_valid) begin
%000000                         if (sf_resp_dirty) begin
                                    // ----------------------------------------
                                    // DIRTY-OWNER INTERVENTION:
                                    // Another core holds line Modified; capture
                                    // its dirty line directly via snoop channel.
                                    // Bypasses stale DDR completely!
                                    // ----------------------------------------
%000000                             target_way         <= line_hit_comb ? hit_way_comb : alloc_way_comb;
%000000                             tag_mem[req_index][line_hit_comb ? hit_way_comb : alloc_way_comb]   <= req_tag;
%000000                             valid_mem[req_index][line_hit_comb ? hit_way_comb : alloc_way_comb] <= 1'b1;
%000000                             snoop_line_latched <= snoop_data;
%000000                             intervene_cnt      <= 3'd0;
%000000                             state              <= ST_INTERVENE;
 000875                         end else if (line_hit_comb) begin
                                    // ----------------------------------------
                                    // L2 CACHE HIT (Clean or existing dirty)
                                    // ----------------------------------------
 009084                             if (!req_wr) begin
 015104                                 sram_cs   <= 1'b1;
 015104                                 sram_we   <= 1'b0;
 015104                                 sram_addr <= {req_index, hit_way_comb, word_offset};
 015104                                 state     <= ST_READ_HIT;
 009084                             end else begin
 009084                                 sram_cs    <= 1'b1;
 009084                                 sram_we    <= 1'b1;
 009084                                 sram_wmask <= req_wstrb;
 009084                                 sram_addr  <= {req_index, hit_way_comb, word_offset};
 009084                                 sram_din   <= req_wdata;
 009084                                 dirty_mem[req_index][hit_way_comb] <= 1'b1;
 009084                                 s_bvalid   <= 1'b1;
 009084                                 s_bresp    <= 2'b00;
 009084                                 state      <= ST_RESP_W;
                                    end
 000875                         end else begin
                                    // ----------------------------------------
                                    // L2 CACHE MISS: Refill from DDR
                                    // Check if victim way needs dirty writeback
                                    // ----------------------------------------
 000875                             target_way <= alloc_way_comb;
 000875                             if (valid_mem[req_index][alloc_way_comb] && dirty_mem[req_index][alloc_way_comb]) begin
                                        // Victim is dirty: read 8 beats from SRAM into evict_buffer
%000000                                 evict_way  <= alloc_way_comb;
%000000                                 evict_cnt  <= 4'd0;
%000000                                 sram_cs    <= 1'b1;
%000000                                 sram_we    <= 1'b0;
%000000                                 sram_addr  <= {req_index, alloc_way_comb, 3'd0};
%000000                                 state      <= ST_EVICT_BUF;
 000875                             end else begin
                                        // Victim clean/invalid: direct 8-beat read refill burst
 000875                                 m_arvalid  <= 1'b1;
 000875                                 m_araddr   <= {req_addr[ADDR_W-1:OFF_W], 6'b000000};
 000875                                 m_arlen    <= 8'd7;   // 8 beats
 000875                                 m_arsize   <= 3'b011; // 8 bytes
 000875                                 m_arburst  <= 2'b01;  // INCR
 000875                                 refill_cnt <= 3'd0;
 000875                                 state      <= ST_REFILL_AR;
                                    end
                                end
                            end
                        end
        
                        // ----------------------------------------------------
                        // READ HIT: Synchronous SRAM read latency cycle
                        // ----------------------------------------------------
 015104                 ST_READ_HIT: begin
 015104                     sram_cs       <= 1'b0;
 015104                     read_hit_flag <= 1'b1;
 015104                     s_rvalid      <= 1'b1;
 015104                     s_rresp       <= 2'b00;
 015104                     state         <= ST_RESP_R;
                        end
        
                        // ----------------------------------------------------
                        // INTERVENE: Write intervened dirty snoop line to SRAM
                        // ----------------------------------------------------
%000000                 ST_INTERVENE: begin
%000000                     sram_cs    <= 1'b1;
%000000                     sram_we    <= 1'b1;
%000000                     sram_addr  <= {req_index, target_way, intervene_cnt};
%000000                     sram_wmask <= 8'hFF;
        
%000000                     if (req_wr && (intervene_cnt == word_offset)) begin
%000000                         for (b_i = 0; b_i < 8; b_i = b_i + 1) begin
%000000                             sram_din[b_i*8 +: 8] <= req_wstrb[b_i] ? req_wdata[b_i*8 +: 8] : snoop_line_latched[intervene_cnt*64 + b_i*8 +: 8];
                                end
%000000                     end else begin
%000000                         sram_din <= snoop_line_latched[intervene_cnt*64 +: 64];
                            end
        
%000000                     if (intervene_cnt == 3'd7) begin
%000000                         sram_cs <= 1'b0;
%000000                         sram_we <= 1'b0;
%000000                         if (!req_wr) begin
%000000                             dirty_mem[req_index][target_way] <= 1'b0;
%000000                             s_rdata_reg   <= snoop_line_latched[word_offset*64 +: 64];
%000000                             read_hit_flag <= 1'b0;
%000000                             s_rvalid      <= 1'b1;
%000000                             s_rresp       <= 2'b00;
%000000                             state         <= ST_RESP_R;
%000000                         end else begin
%000000                             dirty_mem[req_index][target_way] <= 1'b1;
%000000                             s_bvalid <= 1'b1;
%000000                             s_bresp  <= 2'b00;
%000000                             state    <= ST_RESP_W;
                                end
%000000                     end else begin
%000000                         intervene_cnt <= intervene_cnt + 3'd1;
                            end
                        end
        
                        // ----------------------------------------------------
                        // EVICT BUF: Sequentially read 8 words from SRAM into buffer
                        // ----------------------------------------------------
%000000                 ST_EVICT_BUF: begin
%000000                     evict_cnt <= evict_cnt + 4'd1;
%000000                     if (evict_cnt > 4'd0) begin
%000000                         evict_buffer[evict_cnt[2:0] - 3'd1] <= sram_dout;
                            end
%000000                     if (evict_cnt < 4'd7) begin
%000000                         sram_cs   <= 1'b1;
%000000                         sram_we   <= 1'b0;
%000000                         sram_addr <= {req_index, evict_way, evict_cnt[2:0] + 3'd1};
%000000                     end else begin
%000000                         sram_cs   <= 1'b0;
                            end
%000000                     if (evict_cnt == 4'd8) begin
%000000                         evict_buffer[7] <= sram_dout;
%000000                         m_awvalid       <= 1'b1;
%000000                         m_awaddr        <= {tag_mem[req_index][evict_way], req_index, 6'b000000};
%000000                         m_awlen         <= 8'd7;   // 8 beats
%000000                         m_awsize        <= 3'b011; // 8 bytes
%000000                         m_awburst       <= 2'b01;  // INCR
%000000                         state           <= ST_EVICT_AW;
                            end
                        end
        
                        // ----------------------------------------------------
                        // EVICT AW: Emit writeback address to DDR
                        // ----------------------------------------------------
%000000                 ST_EVICT_AW: begin
%000000                     if (m_awvalid && m_awready) begin
%000000                         m_awvalid <= 1'b0;
%000000                         evict_cnt <= 4'd0;
%000000                         m_wvalid  <= 1'b1;
%000000                         m_wdata   <= evict_buffer[0];
%000000                         m_wstrb   <= 8'hFF;
%000000                         m_wlast   <= 1'b0;
%000000                         state     <= ST_EVICT_W;
                            end
                        end
        
                        // ----------------------------------------------------
                        // EVICT W: Stream 8-beat writeback burst
                        // ----------------------------------------------------
%000000                 ST_EVICT_W: begin
%000000                     if (m_wvalid && m_wready) begin
%000000                         if (evict_cnt == 4'd7) begin
%000000                             m_wvalid <= 1'b0;
%000000                             m_wlast  <= 1'b0;
%000000                             m_bready <= 1'b1;
%000000                             state    <= ST_EVICT_B;
%000000                         end else begin
%000000                             evict_cnt <= evict_cnt + 4'd1;
%000000                             m_wvalid  <= 1'b1;
%000000                             m_wdata   <= evict_buffer[evict_cnt[2:0] + 3'd1];
%000000                             m_wstrb   <= 8'hFF;
%000000                             m_wlast   <= (evict_cnt + 4'd1 == 4'd7);
                                end
                            end
                        end
        
                        // ----------------------------------------------------
                        // EVICT B: Wait for DDR write response, then refill
                        // ----------------------------------------------------
%000000                 ST_EVICT_B: begin
%000000                     if (m_bvalid && m_bready) begin
%000000                         m_bready   <= 1'b0;
                                // Now issue 8-beat refill burst
%000000                         m_arvalid  <= 1'b1;
%000000                         m_araddr   <= {req_addr[ADDR_W-1:OFF_W], 6'b000000};
%000000                         m_arlen    <= 8'd7;   // 8 beats
%000000                         m_arsize   <= 3'b011; // 8 bytes
%000000                         m_arburst  <= 2'b01;  // INCR
%000000                         refill_cnt <= 3'd0;
%000000                         state      <= ST_REFILL_AR;
                            end
                        end
        
                        // ----------------------------------------------------
                        // REFILL AR: Issue read refill address to DDR
                        // ----------------------------------------------------
 000875                 ST_REFILL_AR: begin
%000000                     if (m_arvalid && m_arready) begin
 000875                         m_arvalid <= 1'b0;
 000875                         m_rready  <= 1'b1;
 000875                         state     <= ST_REFILL_R;
                            end
                        end
        
                        // ----------------------------------------------------
                        // REFILL R: Collect 8 beats and assemble line
                        // ----------------------------------------------------
 070909                 ST_REFILL_R: begin
 070909                     sram_cs <= 1'b0;
 070909                     sram_we <= 1'b0;
 007000                     if (m_rvalid && m_rready) begin
 007000                         sram_cs    <= 1'b1;
 007000                         sram_we    <= 1'b1;
 007000                         sram_addr  <= {req_index, target_way, refill_cnt};
 007000                         sram_wmask <= 8'hFF;
 000021                         if (req_wr && (refill_cnt == word_offset)) begin
 000021                             for (b_i = 0; b_i < 8; b_i = b_i + 1) begin
 000168                                 sram_din[b_i*8 +: 8] <= req_wstrb[b_i] ? req_wdata[b_i*8 +: 8] : m_rdata[b_i*8 +: 8];
                                    end
 006979                         end else begin
 006979                             sram_din <= m_rdata;
                                end
        
 000854                         if (!req_wr && (refill_cnt == word_offset)) begin
 000854                             read_word_latched <= m_rdata;
                                end
        
 000875                         if (m_rlast || (refill_cnt == 3'd7)) begin
 000875                             m_rready <= 1'b0;
        
                                    // Update tag and valid
 000875                             tag_mem[req_index][target_way]   <= req_tag;
 000875                             valid_mem[req_index][target_way] <= 1'b1;
 000875                             replace_ptr[req_index]           <= replace_ptr[req_index] + 4'd1;
        
 000021                             if (!req_wr) begin
 000854                                 dirty_mem[req_index][target_way] <= 1'b0;
 000854                                 s_rdata_reg   <= (refill_cnt == word_offset) ? m_rdata : read_word_latched;
 000854                                 read_hit_flag <= 1'b0;
 000854                                 s_rvalid      <= 1'b1;
 000854                                 s_rresp       <= 2'b00;
 000854                                 state         <= ST_RESP_R;
 000021                             end else begin
 000021                                 dirty_mem[req_index][target_way] <= 1'b1;
 000021                                 s_bvalid <= 1'b1;
 000021                                 s_bresp  <= 2'b00;
 000021                                 state    <= ST_RESP_W;
                                    end
 006125                         end else begin
 006125                             refill_cnt <= refill_cnt + 3'd1;
                                end
                            end
                        end
        
                        // ----------------------------------------------------
                        // RESP R: Deliver read data to requesting core
                        // ----------------------------------------------------
 015958                 ST_RESP_R: begin
 015958                     sram_cs <= 1'b0;
 015958                     sram_we <= 1'b0;
%000000                     if (s_rvalid && s_rready) begin
 015958                         s_rvalid      <= 1'b0;
 015958                         read_hit_flag <= 1'b0;
 015958                         state         <= ST_IDLE;
                            end
                        end
        
                        // ----------------------------------------------------
                        // RESP W: Deliver write response to requesting core
                        // ----------------------------------------------------
 009105                 ST_RESP_W: begin
 009105                     sram_cs <= 1'b0;
 009105                     sram_we <= 1'b0;
%000000                     if (s_bvalid && s_bready) begin
 009105                         s_bvalid  <= 1'b0;
 009105                         state     <= ST_IDLE;
                            end
                        end
        
%000000                 default: state <= ST_IDLE;
                    endcase
                end
            end
        
        endmodule
        
