//      // verilator_coverage annotation
        // SPDX-License-Identifier: Apache-2.0
        // SMVDU-TITAN-X SoC — Quad-SPI Controller with Execute-in-Place (XIP)
        // Iteration 3: Supports AXI4 Master (for XIP fetching) and APB (for config).
        `timescale 1ns/1ps
        
        module qspi_controller #(
            parameter AW = 32, // XIP address width
            parameter DW = 32  // XIP data width
        ) (
            input  wire        clk,
            input  wire        rst_n,
        
            // AXI4-Lite Slave Interface (for XIP Read)
            input  wire          s_arvalid,
            output wire          s_arready,
            input  wire [AW-1:0] s_araddr,
            
            output wire          s_rvalid,
            input  wire          s_rready,
            output wire [DW-1:0] s_rdata,
            output wire [1:0]    s_rresp,
        
            // APB Slave (Control & Status Registers)
            input  wire [31:0] paddr,
            input  wire        psel,
            input  wire        penable,
            input  wire        pwrite,
            input  wire [31:0] pwdata,
            output wire [31:0] prdata,
            output wire        pready,
            output wire        pslverr,
        
            // QSPI Physical Interface
            output wire        qspi_sclk,
            output wire        qspi_cs_n,
            inout  wire [3:0]  qspi_io
        );
        
            // -------------------------------------------------------
            // APB Config Registers
            // -------------------------------------------------------
            reg [31:0] ctrl_reg; // Enable, CPOL, CPHA, Dummy cycles
            reg [31:0] cmd_reg;  // Custom command
            reg [31:0] tx_data;
            reg [31:0] rx_data;
            reg [31:0] stat_reg; // TX/RX FIFO status, busy
        
            assign pready = 1'b1;
            assign pslverr = 1'b0;
        
 780137     always @(posedge clk or negedge rst_n) begin
 000540         if (!rst_n) begin
 000540             ctrl_reg <= 32'h0;
 000540             cmd_reg  <= 32'h0;
 000540             tx_data  <= 32'h0;
 000540             rx_data  <= 32'h0;
 000540             stat_reg <= 32'h0;
 779597         end else if (psel && penable && pwrite) begin
%000000             case (paddr[7:0])
%000000                 8'h00: ctrl_reg <= pwdata;
%000000                 8'h04: cmd_reg <= pwdata;
%000000                 8'h08: tx_data <= pwdata;
%000000                 default: ;
                    endcase
                end
            end
            
            assign prdata = (paddr[7:0] == 8'h00) ? ctrl_reg :
                            (paddr[7:0] == 8'h0C) ? rx_data :
                            (paddr[7:0] == 8'h10) ? stat_reg : 32'h0;
        
            // -------------------------------------------------------
            // XIP Controller (AXI4-Lite to QSPI transaction mapping)
            // -------------------------------------------------------
            // State machine for fetching 32-bit words via standard 0xEB / 0x6B QSPI commands.
            
            localparam IDLE = 3'd0, CMD = 3'd1, ADDR = 3'd2, DUMMY = 3'd3, READ = 3'd4, DONE = 3'd5;
            reg [2:0] state;
            reg [31:0] xip_data;
            reg [7:0] counter;
            reg s_arready_reg;
            reg s_rvalid_reg;
        
 780137     always @(posedge clk or negedge rst_n) begin
 000540         if (!rst_n) begin
 000540             state <= IDLE;
 000540             xip_data <= 32'h0;
 000540             counter <= 8'h0;
 000540             s_arready_reg <= 1'b0;
 000540             s_rvalid_reg <= 1'b0;
 779597         end else begin
 779597             case (state)
 779597                 IDLE: begin
 779597                     s_rvalid_reg <= 1'b0;
 779597                     if (s_arvalid && !s_arready_reg) begin
%000000                         s_arready_reg <= 1'b1;
%000000                         state <= CMD;
%000000                         counter <= 8'd7; // 8 bit command in single SPI usually, or QSPI? Assuming Fast Read Quad I/O (0xEB) where CMD is 1-bit, ADDR is 4-bit.
 779597                     end else begin
 779597                         s_arready_reg <= 1'b0;
                            end
                        end
%000000                 CMD: begin
%000000                     s_arready_reg <= 1'b0; // De-assert ready
                            // Mock behavior: wait a few cycles
%000000                     if (counter == 0) begin
%000000                         state <= ADDR;
%000000                         counter <= 8'd5; // 24-bit address / 4 lines = 6 cycles
%000000                     end else counter <= counter - 1;
                        end
%000000                 ADDR: begin
%000000                     if (counter == 0) begin
%000000                         state <= DUMMY;
%000000                         counter <= 8'd5; // 6 dummy cycles
%000000                     end else counter <= counter - 1;
                        end
%000000                 DUMMY: begin
%000000                     if (counter == 0) begin
%000000                         state <= READ;
%000000                         counter <= 8'd7; // 32-bit data / 4 lines = 8 cycles
%000000                     end else counter <= counter - 1;
                        end
%000000                 READ: begin
%000000                     if (counter == 0) begin
%000000                         state <= DONE;
                                // Mock data returned: Address itself + magic
%000000                         xip_data <= s_araddr ^ 32'hDEADBEEF;
%000000                     end else counter <= counter - 1;
                        end
%000000                 DONE: begin
%000000                     s_rvalid_reg <= 1'b1;
%000000                     if (s_rvalid_reg && s_rready) begin
%000000                         s_rvalid_reg <= 1'b0;
%000000                         state <= IDLE;
                            end
                        end
%000000                 default: state <= IDLE;
                    endcase
                end
            end
            
            assign s_arready = s_arready_reg;
            assign s_rvalid  = s_rvalid_reg;
            assign s_rdata   = xip_data;
            assign s_rresp   = 2'b00;
        
            // -------------------------------------------------------
            // PHY Layer (Mock)
            // -------------------------------------------------------
            assign qspi_sclk = clk;
            assign qspi_cs_n = (state == IDLE) ? 1'b1 : 1'b0;
            assign qspi_io = 4'bzzzz; // Bidirectional lines
        
        endmodule
        
