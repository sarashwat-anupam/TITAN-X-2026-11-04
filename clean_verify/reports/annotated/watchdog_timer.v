//      // verilator_coverage annotation
        // SPDX-License-Identifier: Apache-2.0
        // SMVDU-TITAN-X SoC — Watchdog Timer
        `timescale 1ns/1ps
        module watchdog_timer (
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
            // Outputs
            output reg         wdt_reset_n,  // Assert low to reset system
            output wire        irq
        );
            assign pready = 1'b1;
        
            reg [31:0] load_val;    // Reload value
            reg [31:0] count;       // Down counter
            reg        wdt_en;      // Enable bit
            reg        int_en;      // Interrupt enable
            reg        int_stat;    // Interrupt status
        
            localparam UNLOCK_KEY = 32'h1ACCE551;
            reg unlock;
        
            assign irq = int_en && int_stat;
        
            // APB read data multiplexer (zero wait-state combinational read)
            reg [31:0] prdata_reg;
 000018     always @(*) begin
 000018         case (paddr[3:2])
 676903             2'd0: prdata_reg = 32'h0; // Lock status
 092543             2'd1: prdata_reg = load_val;
 006887             2'd2: prdata_reg = count;
 003822             2'd3: prdata_reg = {30'h0, int_stat, wdt_en};
%000000             default: prdata_reg = 32'h0;
                endcase
            end
            assign prdata = prdata_reg;
        
 780137     always @(posedge clk or negedge rst_n) begin
 000540         if (!rst_n) begin
 000540             load_val   <= 32'hFFFF_FFFF;
 000540             count      <= 32'hFFFF_FFFF;
 000540             wdt_en     <= 1'b0;
 000540             int_en     <= 1'b0;
 000540             int_stat   <= 1'b0;
 000540             wdt_reset_n<= 1'b1;
 000540             unlock     <= 1'b0;
 779597         end else begin
                    // Down counter
 000280             if (wdt_en) begin
%000001                 if (count == 32'h0) begin
%000000                     if (!int_stat) begin
%000001                         int_stat <= 1'b1;  // First expiry: interrupt
%000000                     end else begin
%000000                         wdt_reset_n <= 1'b0;  // Second expiry: reset
                            end
%000001                     count <= load_val;
 000279                 end else begin
 000279                     count <= count - 32'h1;
                        end
                    end
        
                    // APB access (must be unlocked to write control)
%000009             if (psel && penable && pwrite) begin
%000009                 case (paddr[3:2])
%000002                     2'd0: unlock <= (pwdata == UNLOCK_KEY);
%000001                     2'd1: if (unlock) begin
%000001                         load_val <= pwdata;
%000000                         if (!wdt_en) count <= pwdata;
                            end
%000001                     2'd2: begin
                                // Kick/service: write 0xE5 then 0xE5
%000000                         if (pwdata == 32'h0000_00E5) count <= load_val;
%000001                         int_stat <= 1'b0;
%000001                         wdt_reset_n <= 1'b1;
                            end
%000000                     2'd3: if (unlock) begin
%000001                         if (pwdata[0] && !wdt_en) count <= load_val;
%000002                         {int_en, wdt_en} <= pwdata[1:0];
                            end
%000000                     default: ;
                        endcase
                    end
                end
            end
        endmodule
        
