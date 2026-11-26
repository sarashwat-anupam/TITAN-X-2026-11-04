//      // verilator_coverage annotation
        // SPDX-License-Identifier: Apache-2.0
        // SMVDU-TITAN-X SoC — PCIe Gen2 x4 Endpoint/Root Port Top
        // Iteration 3: Connects AXI4 interfaces to LTSSM, Data Link Layer, and PIPE PHY.
        `timescale 1ns/1ps
        
        module pcie_top #(
            parameter LANES = 4,
            parameter AW = 40,
            parameter DW = 64,
            parameter IDW = 4
        ) (
            input  wire pcie_clk,       // Core clock
            input  wire pcie_rst_n,
            input  wire pipe_clk,       // 250MHz PIPE Clock
        
            // AXI4 Master (DMA/Bus Master traffic to system)
            output reg         m_awvalid,  input  wire        m_awready,
            output reg  [AW-1:0] m_awaddr, output wire [IDW-1:0] m_awid,
            output wire [7:0]  m_awlen,    output wire [2:0]  m_awsize,
            output reg         m_wvalid,   input  wire        m_wready,
            output reg  [DW-1:0] m_wdata,  output wire [DW/8-1:0] m_wstrb,
            output reg         m_wlast,
            input  wire        m_bvalid,   output wire        m_bready,
            input  wire [1:0]  m_bresp,    input  wire [IDW-1:0] m_bid,
            
            output reg         m_arvalid,  input  wire        m_arready,
            output reg  [AW-1:0] m_araddr, output wire [IDW-1:0] m_arid,
            output wire [7:0]  m_arlen,    output wire [2:0]  m_arsize,
            input  wire        m_rvalid,   output wire        m_rready,
            input  wire [DW-1:0] m_rdata,  input  wire [1:0]  m_rresp,
            input  wire        m_rlast,    input  wire [IDW-1:0] m_rid,
        
            // AXI4 Slave (Target traffic from system to PCIe)
            input  wire        s_awvalid,  output wire        s_awready,
            input  wire [AW-1:0] s_awaddr, input  wire [IDW-1:0] s_awid,
            input  wire [7:0]  s_awlen,    input  wire [2:0]  s_awsize,
            input  wire        s_wvalid,   output wire        s_wready,
            input  wire [DW-1:0] s_wdata,  input  wire [DW/8-1:0] s_wstrb,
            input  wire        s_wlast,
            output wire        s_bvalid,   input  wire        s_bready,
            output wire [1:0]  s_bresp,    output wire [IDW-1:0] s_bid,
            
            input  wire        s_arvalid,  output wire        s_arready,
            input  wire [AW-1:0] s_araddr, input  wire [IDW-1:0] s_arid,
            input  wire [7:0]  s_arlen,    input  wire [2:0]  s_arsize,
            output wire        s_rvalid,   input  wire        s_rready,
            output wire [DW-1:0] s_rdata,  output wire [1:0]  s_rresp,
            output wire        s_rlast,    output wire [IDW-1:0] s_rid,
        
            // PIPE 3.0 Interface (to PHY)
            output wire [(LANES*16)-1:0] pipe_tx_data,
            output wire [(LANES*2)-1:0]  pipe_tx_datak,
            input  wire [(LANES*16)-1:0] pipe_rx_data,
            input  wire [(LANES*2)-1:0]  pipe_rx_datak,
            
            output wire [1:0]            pipe_tx_rate,
            output wire [LANES-1:0]      pipe_tx_elecidle,
            output wire [LANES-1:0]      pipe_tx_compliance,
            output wire [LANES-1:0]      pipe_rx_polarity,
            output wire [(LANES*2)-1:0]  pipe_power_down,
        
            input  wire [LANES-1:0]      pipe_rx_valid,
            input  wire [LANES-1:0]      pipe_rx_elecidle,
            input  wire [(LANES*3)-1:0]  pipe_rx_status,
            input  wire [LANES-1:0]      pipe_phy_status
        );
        
            // Static AXI Master Attributes
            assign m_awid   = {IDW{1'b0}};
            assign m_awlen  = 8'h0;
            assign m_awsize = 3'h3; // 64-bit
            assign m_wstrb  = {DW/8{1'b1}};
            assign m_bready = 1'b1;
        
            assign m_arid   = {IDW{1'b0}};
            assign m_arlen  = 8'h0;
            assign m_arsize = 3'h3; // 64-bit
            assign m_rready = 1'b1;
        
            // Tie off slave responses (PCIe target slave)
            assign s_awready = 1'b0;
            assign s_wready  = 1'b0;
            assign s_bvalid  = 1'b0;
            assign s_bresp   = 2'b00;
            assign s_bid     = {IDW{1'b0}};
            
            assign s_arready = 1'b0;
            assign s_rvalid  = 1'b0;
            assign s_rdata   = {DW{1'b0}};
            assign s_rresp   = 2'b00;
            assign s_rlast   = 1'b0;
            assign s_rid     = {IDW{1'b0}};
        
            // -------------------------------------------------------
            // LTSSM & Link Training
            // -------------------------------------------------------
            wire [1:0]  tx_rate = 2'b01; // Force Gen2 (5.0 GT/s)
            wire [(LANES*2)-1:0] power_down = {(LANES*2){1'b0}}; // P0 state
            wire [LANES-1:0] tx_elecidle;
            wire [LANES-1:0] tx_compliance;
            wire [LANES-1:0] rx_polarity;
        
            genvar i;
            generate
                for (i = 0; i < LANES; i = i + 1) begin : gen_ltssm_ties
                    assign tx_elecidle[i]   = 1'b0; // transmitting
                    assign tx_compliance[i] = 1'b0;
                    assign rx_polarity[i]   = 1'b0;
                end
            endgenerate
        
            // LTSSM states
            localparam LTSSM_DETECT  = 2'd0;
            localparam LTSSM_POLLING = 2'd1;
            localparam LTSSM_CONFIG  = 2'd2;
            localparam LTSSM_L0      = 2'd3;
        
            reg [1:0]  ltssm_state;
            reg [7:0]  ts_match_cnt;
        
            // Internal PIPE stream
            reg [(LANES*16)-1:0] int_tx_data;
            reg [(LANES*2)-1:0]  int_tx_datak;
            wire [(LANES*16)-1:0] int_rx_data;
            wire [(LANES*2)-1:0]  int_rx_datak;
            wire [LANES-1:0]      int_rx_valid;
        
            // Ordered Set definitions
            localparam OS_TS1  = 64'h4A4A_4A4A_4A4A_4A4A;
            localparam OS_TS2  = 64'h4545_4545_4545_4545;
            localparam OS_IDLE = 64'h0000_0000_0000_0000;
        
            // -------------------------------------------------------
            // TLP Processing Engine & DMA Bridge
            // -------------------------------------------------------
            localparam TLP_IDLE      = 3'd0;
            localparam TLP_MWR_ADDR  = 3'd1;
            localparam TLP_MWR_DATA  = 3'd2;
            localparam TLP_MWR_AXI   = 3'd3;
            localparam TLP_MRD_ADDR  = 3'd4;
            localparam TLP_MRD_AXI   = 3'd5;
            localparam TLP_CPLD_TX   = 3'd6;
        
            reg [2:0]  tlp_state;
            reg [63:0] tlp_req_hdr0;
            reg [31:0] tlp_target_addr;
            reg [63:0] tlp_write_data;
            reg [63:0] tlp_read_data;
            reg [1:0]  cpld_beat;
        
 780137     always @(posedge pcie_clk or negedge pcie_rst_n) begin
 000540         if (!pcie_rst_n) begin
 000540             ltssm_state     <= LTSSM_DETECT;
 000540             ts_match_cnt    <= 8'd0;
 000540             int_tx_data     <= 64'h0;
 000540             int_tx_datak    <= 8'h0;
 000540             tlp_state       <= TLP_IDLE;
 000540             m_awvalid       <= 1'b0;
 000540             m_awaddr        <= {AW{1'b0}};
 000540             m_wvalid        <= 1'b0;
 000540             m_wdata         <= {DW{1'b0}};
 000540             m_wlast         <= 1'b0;
 000540             m_arvalid       <= 1'b0;
 000540             m_araddr        <= {AW{1'b0}};
 000540             tlp_req_hdr0    <= 64'h0;
 000540             tlp_target_addr <= 32'h0;
 000540             tlp_write_data  <= 64'h0;
 000540             tlp_read_data   <= 64'h0;
 000540             cpld_beat       <= 2'd0;
 779597         end else begin
                    // -------------------------------------------------------
                    // 1. LTSSM Link Training FSM
                    // -------------------------------------------------------
 779597             case (ltssm_state)
 000054                 LTSSM_DETECT: begin
 000054                     int_tx_data  <= OS_IDLE;
 000054                     int_tx_datak <= 8'h00;
 000018                     if (int_rx_valid != 4'h0 || int_rx_data[31:0] == 32'h4A4A_4A4A) begin
 000018                         ltssm_state  <= LTSSM_POLLING;
 000018                         ts_match_cnt <= 8'd0;
                            end
                        end
        
 000306                 LTSSM_POLLING: begin
                            // Transmit TS1 ordered sets
 000306                     int_tx_data  <= OS_TS1;
 000306                     int_tx_datak <= 8'hFF;
 000018                     if (int_rx_data[31:0] == 32'h4A4A_4A4A) begin
 000288                         ts_match_cnt <= ts_match_cnt + 1'b1;
                            end
 000018                     if (ts_match_cnt > 8'd4 && int_rx_data[31:0] == 32'h4545_4545) begin
 000018                         ltssm_state  <= LTSSM_CONFIG;
 000018                         ts_match_cnt <= 8'd0;
                            end
                        end
        
 000162                 LTSSM_CONFIG: begin
                            // Transmit TS2 ordered sets
 000162                     int_tx_data  <= OS_TS2;
 000162                     int_tx_datak <= 8'hFF;
 000018                     if (int_rx_data[31:0] == 32'h4545_4545) begin
 000144                         ts_match_cnt <= ts_match_cnt + 1'b1;
                            end
 000018                     if (ts_match_cnt > 8'd4 && (int_rx_data[31:0] == 32'h0 || int_rx_datak == 8'h0)) begin
 000018                         ltssm_state <= LTSSM_L0;
                            end
                        end
        
 779075                 LTSSM_L0: begin
                            // Link Up in steady state
 007324                     if (tlp_state == TLP_CPLD_TX) begin
                                // Driving CplD
 771751                     end else begin
 771751                         int_tx_data  <= OS_IDLE;
 771751                         int_tx_datak <= 8'h00;
                            end
                        end
        
%000000                 default: ltssm_state <= LTSSM_DETECT;
                    endcase
        
                    // -------------------------------------------------------
                    // 2. TLP Packet Decoder & AXI DMA Master 11 FSM
                    // -------------------------------------------------------
 000522             if (ltssm_state == LTSSM_L0) begin
 779075                 case (tlp_state)
 736973                     TLP_IDLE: begin
                                // Check if a TLP header arrived (Fmt/Type in DW0 [31:24] or [7:0])
 001849                         if (int_rx_valid != 4'h0 && int_rx_datak == 8'h0 && int_rx_data != 64'h0) begin
 000018                             if (int_rx_data[31:24] == 8'h40 || int_rx_data[31:24] == 8'h60 ||
 000018                                 int_rx_data[7:0]   == 8'h40 || int_rx_data[7:0]   == 8'h60) begin
                                        // Memory Write 32/64-bit (MWr)
 000018                                 tlp_req_hdr0 <= int_rx_data;
 000018                                 tlp_state    <= TLP_MWR_ADDR;
%000000                             end else if (int_rx_data[31:24] == 8'h20 || int_rx_data[7:0] == 8'h20 ||
 001831                                          ((int_rx_data[31:24] == 8'h00 || int_rx_data[7:0] == 8'h00) && int_rx_data[9:0] != 10'h0)) begin
                                        // Memory Read 32/64-bit (MRd)
 001831                                 tlp_req_hdr0 <= int_rx_data;
 001831                                 tlp_state    <= TLP_MRD_ADDR;
                                    end
                                end
                            end
        
 000018                     TLP_MWR_ADDR: begin
%000000                         if (int_rx_valid != 4'h0) begin
 000018                             tlp_target_addr <= (tlp_req_hdr0[29] || tlp_req_hdr0[5]) ? int_rx_data[63:32] : int_rx_data[31:0];
 000018                             tlp_state       <= TLP_MWR_DATA;
                                end
                            end
        
 000018                     TLP_MWR_DATA: begin
%000000                         if (int_rx_valid != 4'h0) begin
 000018                             tlp_write_data <= int_rx_data;
                                    // Launch AXI write into DDR4
 000018                             m_awvalid      <= 1'b1;
 000018                             m_awaddr       <= {{(AW-32){1'b0}}, tlp_target_addr};
 000018                             m_wvalid       <= 1'b1;
 000018                             m_wdata        <= int_rx_data;
 000018                             m_wlast        <= 1'b1;
 000018                             tlp_state      <= TLP_MWR_AXI;
                                end
                            end
        
 001674                     TLP_MWR_AXI: begin
 000018                         if (m_awready) m_awvalid <= 1'b0;
 000018                         if (m_wready) begin
 000018                             m_wvalid <= 1'b0;
 000018                             m_wlast  <= 1'b0;
                                end
 000018                         if (m_bvalid) begin
 000018                             tlp_state <= TLP_IDLE;
                                end
                            end
        
 001831                     TLP_MRD_ADDR: begin
%000000                         if (int_rx_valid != 4'h0) begin
 001831                             tlp_target_addr <= (tlp_req_hdr0[29] || tlp_req_hdr0[5]) ? int_rx_data[63:32] : int_rx_data[31:0];
                                    // Launch AXI read from DDR4
 001831                             m_arvalid       <= 1'b1;
 001831                             m_araddr        <= {{(AW-32){1'b0}}, ((tlp_req_hdr0[29] || tlp_req_hdr0[5]) ? int_rx_data[63:32] : int_rx_data[31:0])};
 001831                             tlp_state       <= TLP_MRD_AXI;
                                end
                            end
        
 031237                     TLP_MRD_AXI: begin
 001831                         if (m_arready) m_arvalid <= 1'b0;
 001831                         if (m_rvalid) begin
 001831                             tlp_read_data <= m_rdata;
 001831                             cpld_beat     <= 2'd0;
 001831                             tlp_state     <= TLP_CPLD_TX;
                                end
                            end
        
 007324                     TLP_CPLD_TX: begin
                                // Transmit Completion with Data (CplD)
 007324                         case (cpld_beat)
 001831                             2'd0: begin
                                        // Header: DW0 (0x4A00_0002 CplD 2DW payload) & DW1 (Completer ID, status, byte count 8)
 001831                                 int_tx_data  <= {32'h0000_0008, 32'h4A00_0002};
 001831                                 int_tx_datak <= 8'h00;
 001831                                 cpld_beat    <= 2'd1;
                                    end
 001831                             2'd1: begin
                                        // Header: DW2 (Requester ID from tlp_req_hdr0[63:32], lower addr 0) & Payload Lower DW3
 001831                                 int_tx_data  <= {tlp_read_data[31:0], tlp_req_hdr0[63:48], 16'h0000};
 001831                                 int_tx_datak <= 8'h00;
 001831                                 cpld_beat    <= 2'd2;
                                    end
 001831                             2'd2: begin
                                        // Payload Upper DW4
 001831                                 int_tx_data  <= {32'h0000_0000, tlp_read_data[63:32]};
 001831                                 int_tx_datak <= 8'h00;
 001831                                 cpld_beat    <= 2'd3;
                                    end
 001831                             2'd3: begin
 001831                                 int_tx_data  <= OS_IDLE;
 001831                                 int_tx_datak <= 8'h00;
 001831                                 tlp_state    <= TLP_IDLE;
                                    end
                                endcase
                            end
        
%000000                     default: tlp_state <= TLP_IDLE;
                        endcase
                    end
                end
            end
        
            // -------------------------------------------------------
            // PIPE Interface Instance
            // -------------------------------------------------------
            pcie_pipe_if #(
                .LANES(LANES)
            ) u_pipe_if (
                .pclk(pipe_clk),
                .reset_n(pcie_rst_n),
                .tx_data(int_tx_data),
                .tx_datak(int_tx_datak),
                .rx_data(int_rx_data),
                .rx_datak(int_rx_datak),
                .rx_valid(int_rx_valid),
                .rx_elecidle(),
                .rx_status(),
                .tx_rate(tx_rate),
                .power_down(power_down),
                .tx_elecidle(tx_elecidle),
                .tx_compliance(tx_compliance),
                .rx_polarity(rx_polarity),
                .pipe_tx_data(pipe_tx_data),
                .pipe_tx_datak(pipe_tx_datak),
                .pipe_rx_data(pipe_rx_data),
                .pipe_rx_datak(pipe_rx_datak),
                .pipe_tx_rate(pipe_tx_rate),
                .pipe_tx_elecidle(pipe_tx_elecidle),
                .pipe_tx_compliance(pipe_tx_compliance),
                .pipe_rx_polarity(pipe_rx_polarity),
                .pipe_power_down(pipe_power_down),
                .pipe_rx_valid(pipe_rx_valid),
                .pipe_rx_elecidle(pipe_rx_elecidle),
                .pipe_rx_status(pipe_rx_status),
                .pipe_phy_status(pipe_phy_status)
            );
        
        endmodule
        
