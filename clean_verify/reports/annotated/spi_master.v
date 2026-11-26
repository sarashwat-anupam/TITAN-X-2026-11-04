//      // verilator_coverage annotation
        // SPDX-License-Identifier: Apache-2.0
        // SMVDU-TITAN-X SoC — SPI Master Controller
        // Pre-Synthesis Clean-Room Fix (Defect D-036): Zero wait-state combinational prdata,
        // immediate busy assertion on APB write, and robust completion interrupt generation.
        `timescale 1ns/1ps
        
        module spi_master (
            input  wire        clk,
            input  wire        rst_n,
            // APB slave
            input  wire        psel,
            input  wire        penable,
            input  wire        pwrite,
            input  wire [3:0]  paddr,
            input  wire [31:0] pwdata,
            output wire [31:0] prdata,
            output wire        pready,
            // SPI pads
            output wire        spi_clk,
            output wire        spi_mosi,
            input  wire        spi_miso,
            output reg  [3:0]  spi_csn,   // 4 chip selects (active-low)
            output wire        irq
        );
            assign pready = 1'b1;
        
            reg [15:0] clk_div;    // SCLK = clk / (2*(clk_div+1))
            reg [7:0]  tx_data;
            reg [7:0]  rx_data;
            reg        busy;
            reg [3:0]  cs_select;  // which CS to assert
            reg        cpol, cpha;
            reg        done_irq;
        
            // Clock generator
            reg [15:0] clk_cnt;
            reg        sclk_r;
            wire       sclk_edge = (clk_cnt == 16'h0);
        
 780137     always @(posedge clk or negedge rst_n) begin
 000540         if (!rst_n) begin
 000540             clk_cnt <= 16'h0;
 000540             sclk_r  <= 1'b0;
 000031         end else if (busy) begin
 000015             if (clk_cnt >= clk_div) begin
 000015                 clk_cnt <= 16'h0;
 000015                 sclk_r  <= ~sclk_r;
 000016             end else begin
 000016                 clk_cnt <= clk_cnt + 16'h1;
                    end
 779566         end else begin
 779566             sclk_r  <= cpol;
 779566             clk_cnt <= 16'h0;
                end
            end
        
            assign spi_clk = sclk_r;
        
            // Shift register
            reg [7:0] shift_out;
            reg [7:0] shift_in;
            reg [2:0] bit_cnt;
            reg       mosi_r;
            assign spi_mosi = mosi_r;
            assign irq      = done_irq;
        
 780137     always @(posedge clk or negedge rst_n) begin
 000540         if (!rst_n) begin
 000540             shift_out <= 8'h0;
 000540             shift_in  <= 8'h0;
 000540             rx_data   <= 8'h0;
 000540             bit_cnt   <= 3'h0;
 000540             mosi_r    <= 1'b1;
 000540             busy      <= 1'b0;
 000540             spi_csn   <= 4'hF;
 000540             done_irq  <= 1'b0;
 779597         end else begin
                    // APB Write: offset 0x00 starts transfer immediately
%000001             if (psel && penable && pwrite && (paddr[3:2] == 2'd0)) begin
%000001                 done_irq  <= 1'b0;
%000001                 shift_out <= {pwdata[6:0], 1'b0};
%000001                 mosi_r    <= pwdata[7];
%000001                 bit_cnt   <= 3'h7;
%000001                 busy      <= 1'b1;
%000001                 spi_csn   <= ~(4'b0001 << cs_select[1:0]);
 000014             end else if (psel && penable && !pwrite && (paddr[3:2] == 2'd0)) begin
 000014                 done_irq  <= 1'b0; // Reading RX data clears interrupt
                    end
        
                    // Shift on SCLK edges
 000016             if (busy && sclk_edge) begin
%000008                 if (sclk_r) begin
                            // Rising edge (sampling MISO in Mode 0)
%000008                     shift_in <= {shift_in[6:0], spi_miso};
%000001                     if (bit_cnt == 3'h0) begin
%000001                         rx_data  <= {shift_in[6:0], spi_miso};
%000001                         busy     <= 1'b0;
%000001                         spi_csn  <= 4'hF;
%000001                         done_irq <= 1'b1;
%000007                     end else begin
%000007                         bit_cnt <= bit_cnt - 3'h1;
                            end
%000008                 end else begin
                            // Falling edge (shifting out next MOSI bit)
%000008                     mosi_r    <= shift_out[7];
%000008                     shift_out <= {shift_out[6:0], 1'b0};
                        end
                    end
                end
            end
        
            // APB registers
 780137     always @(posedge clk or negedge rst_n) begin
 000540         if (!rst_n) begin
 000540             clk_div   <= 16'd49;   // 100MHz / (2*50) = 1 MHz
 000540             tx_data   <= 8'h0;
 000540             cs_select <= 4'h0;
 000540             cpol      <= 1'b0;
 000540             cpha      <= 1'b0;
%000003         end else if (psel && penable && pwrite) begin
%000003             case (paddr[3:2])
%000001                 2'd0: tx_data <= pwdata[7:0];
%000001                 2'd1: clk_div <= pwdata[15:0];
%000001                 2'd2: {cpha, cpol, cs_select} <= {pwdata[5], pwdata[4], pwdata[3:0]};
%000000                 default: ;
                    endcase
                end
            end
        
            // Combinational Zero Wait-State Read Data
            reg [31:0] prdata_comb;
 000018     always @(*) begin
 000018         case (paddr[3:2])
 676903             2'd0: prdata_comb = {24'h0, rx_data};
 092543             2'd1: prdata_comb = {busy, 15'h0, clk_div};
 010709             default: prdata_comb = 32'h0;
                endcase
            end
            assign prdata = prdata_comb;
        
        endmodule
        
