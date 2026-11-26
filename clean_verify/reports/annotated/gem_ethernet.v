//      // verilator_coverage annotation
        // SPDX-License-Identifier: Apache-2.0
        // SMVDU-TITAN-X SoC — Gigabit Ethernet MAC (GEM) with Scatter-Gather DMA
        // Iteration 3: Connects to AXI4 for DMA, APB for Control, and GMII for PHY.
        `timescale 1ns/1ps
        
        module gem_ethernet #(
            parameter AW = 40,
            parameter DW = 64,
            parameter IDW = 4
        ) (
            input  wire        clk,          // System clock for AXI/APB
            input  wire        rst_n,
            
            // AXI4 Master (Scatter-Gather DMA)
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
        
            // APB Slave (Control & Status Registers)
            input  wire [31:0] paddr,
            input  wire        psel,
            input  wire        penable,
            input  wire        pwrite,
            input  wire [31:0] pwdata,
            output wire [31:0] prdata,
            output wire        pready,
            output wire        pslverr,
        
            // Interrupts
            output wire        mac_irq,
        
            // GMII Interface (to SGMII PCS or external PHY)
            input  wire        tx_clk,
            output reg  [7:0]  gmii_txd,
            output reg         gmii_tx_en,
            output wire        gmii_tx_er,
            
            input  wire        rx_clk,
            input  wire [7:0]  gmii_rxd,
            input  wire        gmii_rx_dv,
            input  wire        gmii_rx_er,
            input  wire        gmii_crs,
            input  wire        gmii_col
        );
        
            // Static AXI4 master attributes
            assign m_awid   = {IDW{1'b0}};
            assign m_awlen  = 8'h0; // single beat
            assign m_awsize = 3'h3; // 8 bytes (64-bit)
            assign m_wstrb  = {DW/8{1'b1}};
            assign m_bready = 1'b1;
        
            assign m_arid   = {IDW{1'b0}};
            assign m_arlen  = 8'h0; // single beat
            assign m_arsize = 3'h3; // 8 bytes (64-bit)
            assign m_rready = 1'b1;
        
            assign gmii_tx_er = 1'b0;
        
            // -------------------------------------------------------
            // APB CSRs
            // -------------------------------------------------------
            reg [31:0] network_control;
            reg [31:0] network_config;
            reg [31:0] tx_status;
            reg [31:0] rx_status;
            reg [31:0] irq_status;
            reg [31:0] irq_mask;
            reg [31:0] tx_q_ptr;
            reg [31:0] rx_q_ptr;
        
            assign pready  = 1'b1;
            assign pslverr = 1'b0;
            
            wire apb_write = psel && penable && pwrite;
        
            reg tx_trigger_pulse;
            reg rx_done_pulse;
            reg tx_done_pulse;
        
 780137     always @(posedge clk or negedge rst_n) begin
 000540         if (!rst_n) begin
 000540             network_control   <= 32'h0;
 000540             network_config    <= 32'h0;
 000540             irq_mask          <= 32'hFFFF_FFFF;
 000540             irq_status        <= 32'h0;
 000540             tx_q_ptr          <= 32'h0;
 000540             rx_q_ptr          <= 32'h0;
 000540             tx_status         <= 32'h0;
 000540             rx_status         <= 32'h0;
 000540             tx_trigger_pulse  <= 1'b0;
 779597         end else begin
 779597             tx_trigger_pulse <= 1'b0;
%000001             if (tx_done_pulse) begin
%000001                 irq_status[7] <= 1'b1; // bit 7: TX complete
%000001                 tx_status[0]  <= 1'b1;
                    end
%000001             if (rx_done_pulse) begin
%000001                 irq_status[1] <= 1'b1; // bit 1: RX complete
%000001                 rx_status[0]  <= 1'b1;
                    end
        
%000009             if (apb_write) begin
%000009                 case (paddr[11:0])
%000001                     12'h000: begin
%000001                         network_control <= pwdata;
%000000                         if (pwdata[9] || pwdata[3]) begin
%000001                             tx_trigger_pulse <= 1'b1;
                                end
                            end
%000001                     12'h004: network_config  <= pwdata;
%000001                     12'h008: tx_status       <= tx_status & ~pwdata; // W1C
%000001                     12'h00C: rx_status       <= rx_status & ~pwdata; // W1C
%000001                     12'h014: tx_q_ptr        <= pwdata;
%000001                     12'h018: rx_q_ptr        <= pwdata;
%000002                     12'h020: irq_status      <= irq_status & ~pwdata; // W1C
%000001                     12'h024: irq_mask        <= pwdata;
%000000                     default: ;
                        endcase
                    end
                end
            end
        
            reg [31:0] prdata_reg;
 000018     always @(*) begin
 000018         case (paddr[11:0])
 674749             12'h000: prdata_reg = network_control;
 083697             12'h004: prdata_reg = network_config;
 001180             12'h008: prdata_reg = tx_status;
 001665             12'h00C: prdata_reg = rx_status;
 007951             12'h014: prdata_reg = tx_q_ptr;
 000058             12'h018: prdata_reg = rx_q_ptr;
 000064             12'h020: prdata_reg = irq_status;
 000052             12'h024: prdata_reg = irq_mask;
 010739             default: prdata_reg = 32'h0;
                endcase
            end
            assign prdata = prdata_reg;
        
            assign mac_irq = |(irq_status & ~irq_mask);
        
            // -------------------------------------------------------
            // CRC-32 Calculation Function (IEEE 802.3 Ethernet standard)
            // Polynomial: 0x04C11DB7, bit-reversed: 0xEDB88320
            // -------------------------------------------------------
 000128     function [31:0] next_crc;
                input [7:0]  data_in;
                input [31:0] crc_in;
                reg [31:0]   c;
                integer      b;
 000128         begin
 000128             c = crc_in;
 000128             for (b = 0; b < 8; b = b + 1) begin
 000502                 if ((c[0] ^ data_in[b]) == 1'b1)
 000522                     c = {1'b0, c[31:1]} ^ 32'hEDB88320;
                        else
 000502                     c = {1'b0, c[31:1]};
                    end
 000128             next_crc = c;
                end
            endfunction
        
            // -------------------------------------------------------
            // Internal TX/RX Packet Buffers (8 x 64-bit = 64 bytes)
            // -------------------------------------------------------
            reg [63:0] tx_pkt_buffer [0:7];
            reg [63:0] rx_pkt_buffer [0:7];
        
            // -------------------------------------------------------
            // TX DMA & GMII Serializer Engine
            // 1. Fetches 8 words from tx_q_ptr into tx_pkt_buffer
            // 2. Transmits 64 bytes contiguously over GMII + 4 bytes CRC
            // -------------------------------------------------------
            localparam TX_FSM_IDLE     = 3'd0;
            localparam TX_FSM_FETCH_AR = 3'd1;
            localparam TX_FSM_FETCH_R  = 3'd2;
            localparam TX_FSM_STREAM   = 3'd3;
            localparam TX_FSM_CRC      = 3'd4;
            localparam TX_FSM_DONE     = 3'd5;
        
            reg [2:0]  tx_fsm;
            reg [2:0]  tx_word_cnt;
            reg [2:0]  tx_byte_cnt;
            reg [31:0] tx_crc;
            reg [1:0]  tx_crc_byte;
        
            wire [7:0] tx_stream_byte = tx_pkt_buffer[tx_word_cnt][tx_byte_cnt*8 +: 8];
        
 780137     always @(posedge clk or negedge rst_n) begin
 000540         if (!rst_n) begin
 000540             tx_fsm           <= TX_FSM_IDLE;
 000540             m_arvalid        <= 1'b0;
 000540             m_araddr         <= {AW{1'b0}};
 000540             gmii_txd         <= 8'h00;
 000540             gmii_tx_en       <= 1'b0;
 000540             tx_word_cnt      <= 3'd0;
 000540             tx_byte_cnt      <= 3'd0;
 000540             tx_crc           <= 32'hFFFF_FFFF;
 000540             tx_crc_byte      <= 2'd0;
 000540             tx_done_pulse    <= 1'b0;
 779597         end else begin
 779597             tx_done_pulse <= 1'b0;
        
 779597             case (tx_fsm)
 779355                 TX_FSM_IDLE: begin
 779355                     gmii_tx_en <= 1'b0;
 779355                     gmii_txd   <= 8'h00;
%000001                     if (tx_trigger_pulse && network_control[3]) begin // TX enabled
%000001                         tx_word_cnt <= 3'd0;
%000001                         m_arvalid   <= 1'b1;
%000001                         m_araddr    <= {{(AW-32){1'b0}}, tx_q_ptr};
%000001                         tx_fsm      <= TX_FSM_FETCH_AR;
                            end
                        end
        
 000133                 TX_FSM_FETCH_AR: begin
%000008                     if (m_arready) begin
%000008                         m_arvalid <= 1'b0;
%000008                         tx_fsm    <= TX_FSM_FETCH_R;
                            end
                        end
        
 000040                 TX_FSM_FETCH_R: begin
%000008                     if (m_rvalid) begin
%000008                         tx_pkt_buffer[tx_word_cnt] <= m_rdata;
%000001                         if (tx_word_cnt == 3'd7) begin
                                    // All 8 words fetched! Start streaming
%000001                             tx_word_cnt <= 3'd0;
%000001                             tx_byte_cnt <= 3'd0;
%000001                             tx_crc      <= 32'hFFFF_FFFF;
%000001                             tx_fsm      <= TX_FSM_STREAM;
%000007                         end else begin
%000007                             tx_word_cnt <= tx_word_cnt + 1'b1;
%000007                             m_arvalid   <= 1'b1;
%000007                             m_araddr    <= {{(AW-32){1'b0}}, tx_q_ptr} + {{(AW-6){1'b0}}, (tx_word_cnt + 1'b1), 3'b000};
%000007                             tx_fsm      <= TX_FSM_FETCH_AR;
                                end
                            end
                        end
        
 000064                 TX_FSM_STREAM: begin
 000064                     gmii_tx_en <= 1'b1;
 000064                     gmii_txd   <= tx_stream_byte;
 000064                     tx_crc     <= next_crc(tx_stream_byte, tx_crc);
        
%000008                     if (tx_byte_cnt == 3'd7) begin
%000008                         tx_byte_cnt <= 3'd0;
%000001                         if (tx_word_cnt == 3'd7) begin
%000001                             tx_fsm      <= TX_FSM_CRC;
%000001                             tx_crc_byte <= 2'd0;
%000007                         end else begin
%000007                             tx_word_cnt <= tx_word_cnt + 1'b1;
                                end
 000056                     end else begin
 000056                         tx_byte_cnt <= tx_byte_cnt + 1'b1;
                            end
                        end
        
%000004                 TX_FSM_CRC: begin
%000004                     gmii_tx_en <= 1'b1;
%000004                     gmii_txd   <= ~tx_crc[tx_crc_byte*8 +: 8];
        
%000001                     if (tx_crc_byte == 2'd3) begin
%000001                         tx_fsm <= TX_FSM_DONE;
%000003                     end else begin
%000003                         tx_crc_byte <= tx_crc_byte + 1'b1;
                            end
                        end
        
%000001                 TX_FSM_DONE: begin
%000001                     gmii_tx_en    <= 1'b0;
%000001                     gmii_txd      <= 8'h00;
%000001                     tx_done_pulse <= 1'b1;
%000001                     tx_fsm        <= TX_FSM_IDLE;
                        end
        
%000000                 default: tx_fsm <= TX_FSM_IDLE;
                    endcase
                end
            end
        
            // -------------------------------------------------------
            // RX Deserializer & RX DMA Engine
            // 1. Receives 64 bytes from GMII into rx_pkt_buffer
            // 2. Writes 8 words into rx_q_ptr in DDR4
            // -------------------------------------------------------
            localparam RX_FSM_IDLE        = 3'd0;
            localparam RX_FSM_GATHER      = 3'd1;
            localparam RX_FSM_WRITE_START = 3'd2;
            localparam RX_FSM_WRITE_AW_W  = 3'd3;
            localparam RX_FSM_WRITE_B     = 3'd4;
            localparam RX_FSM_DONE        = 3'd5;
        
            reg [2:0]  rx_fsm;
            reg [2:0]  rx_word_cnt;
            reg [2:0]  rx_byte_cnt;
            reg [63:0] rx_word_buf;
            reg [31:0] rx_crc;
        
 780137     always @(posedge clk or negedge rst_n) begin
 000540         if (!rst_n) begin
 000540             rx_fsm        <= RX_FSM_IDLE;
 000540             m_awvalid     <= 1'b0;
 000540             m_awaddr      <= {AW{1'b0}};
 000540             m_wvalid      <= 1'b0;
 000540             m_wdata       <= {DW{1'b0}};
 000540             m_wlast       <= 1'b0;
 000540             rx_word_cnt   <= 3'd0;
 000540             rx_byte_cnt   <= 3'd0;
 000540             rx_word_buf   <= 64'd0;
 000540             rx_crc        <= 32'hFFFF_FFFF;
 000540             rx_done_pulse <= 1'b0;
 779597         end else begin
 779597             rx_done_pulse <= 1'b0;
        
 779597             case (rx_fsm)
 779253                 RX_FSM_IDLE: begin
%000001                     if (network_control[2] && gmii_rx_dv) begin // RX enabled and frame start
%000001                         rx_word_cnt <= 3'd0;
%000001                         rx_byte_cnt <= 3'd1;
%000001                         rx_word_buf <= {56'h0, gmii_rxd};
%000001                         rx_crc      <= next_crc(gmii_rxd, 32'hFFFF_FFFF);
%000001                         rx_fsm      <= RX_FSM_GATHER;
                            end
                        end
        
 000063                 RX_FSM_GATHER: begin
%000000                     if (gmii_rx_dv) begin
 000063                         rx_word_buf[rx_byte_cnt*8 +: 8] <= gmii_rxd;
 000063                         rx_crc <= next_crc(gmii_rxd, rx_crc);
        
%000008                         if (rx_byte_cnt == 3'd7) begin
%000008                             rx_pkt_buffer[rx_word_cnt] <= {gmii_rxd, rx_word_buf[55:0]};
%000008                             rx_byte_cnt <= 3'd0;
%000001                             if (rx_word_cnt == 3'd7) begin
                                        // All 64 bytes captured! Begin DMA writes
%000001                                 rx_word_cnt <= 3'd0;
%000001                                 rx_fsm      <= RX_FSM_WRITE_START;
%000007                             end else begin
%000007                                 rx_word_cnt <= rx_word_cnt + 1'b1;
                                    end
 000055                         end else begin
 000055                             rx_byte_cnt <= rx_byte_cnt + 1'b1;
                                end
                            end
                        end
        
%000008                 RX_FSM_WRITE_START: begin
%000008                     m_awvalid <= 1'b1;
%000008                     m_awaddr  <= {{(AW-32){1'b0}}, rx_q_ptr} + {{(AW-6){1'b0}}, rx_word_cnt, 3'b000};
%000008                     m_wvalid  <= 1'b1;
%000008                     m_wdata   <= rx_pkt_buffer[rx_word_cnt];
%000008                     m_wlast   <= 1'b1;
%000008                     rx_fsm    <= RX_FSM_WRITE_AW_W;
                        end
        
 000142                 RX_FSM_WRITE_AW_W: begin
%000008                     if (m_awready) m_awvalid <= 1'b0;
%000008                     if (m_wready) begin
%000008                         m_wvalid <= 1'b0;
%000008                         m_wlast  <= 1'b0;
                            end
%000008                     if ((m_awready || !m_awvalid) && (m_wready || !m_wvalid)) begin
%000008                         rx_fsm <= RX_FSM_WRITE_B;
                            end
                        end
        
 000130                 RX_FSM_WRITE_B: begin
%000008                     if (m_bvalid) begin
%000001                         if (rx_word_cnt == 3'd7) begin
%000001                             rx_fsm <= RX_FSM_DONE;
%000007                         end else begin
%000007                             rx_word_cnt <= rx_word_cnt + 1'b1;
%000007                             rx_fsm      <= RX_FSM_WRITE_START;
                                end
                            end
                        end
        
%000001                 RX_FSM_DONE: begin
%000001                     rx_done_pulse <= 1'b1;
%000001                     rx_fsm        <= RX_FSM_IDLE;
                        end
        
%000000                 default: rx_fsm <= RX_FSM_IDLE;
                    endcase
                end
            end
        
            // To prevent unused warnings
            wire _unused = &{gmii_rx_er, gmii_crs, gmii_col, tx_clk, rx_clk};
        
        endmodule
        
