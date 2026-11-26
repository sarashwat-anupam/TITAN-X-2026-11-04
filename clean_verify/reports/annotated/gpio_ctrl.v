//      // verilator_coverage annotation
        // SPDX-License-Identifier: Apache-2.0
        // SMVDU-TITAN-X SoC — GPIO Controller (32-bit bidirectional)
        `timescale 1ns/1ps
        module gpio_ctrl (
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
            // GPIO pads (using tri-state for inout)
            inout  wire [31:0] gpio_pad,
            output wire        irq
        );
            assign pready = 1'b1;
        
            reg [31:0] dir_reg;    // 1=output, 0=input
            reg [31:0] out_reg;    // output data
            reg [31:0] int_en;     // interrupt enable
            reg [31:0] int_pol;    // interrupt polarity (1=high, 0=low)
            reg [31:0] int_stat;   // interrupt status (W1C)
            reg [31:0] in_sync;    // synchronized input value
        
            // 2-stage synchronizer for each GPIO input
            reg [31:0] gpio_sync1, gpio_sync2;
 780137     always @(posedge clk or negedge rst_n) begin
 000540         if (!rst_n) begin
 000540             gpio_sync1 <= 32'h0;
 000540             gpio_sync2 <= 32'h0;
 000540             in_sync    <= 32'h0;
 779597         end else begin
 779597             gpio_sync1 <= gpio_pad;
 779597             gpio_sync2 <= gpio_sync1;
 779597             in_sync    <= gpio_sync2;
                end
            end
        
            // Tri-state drivers
            genvar i;
            generate
                for (i = 0; i < 32; i = i+1) begin : GPIO_TRIS
                    assign gpio_pad[i] = dir_reg[i] ? out_reg[i] : 1'bz;
                end
            endgenerate
        
            // Interrupt: any enabled GPIO triggered
            reg [31:0] int_raw;
 000018     always @(*) begin
 000018         int_raw = (int_pol) ? in_sync : ~in_sync; // polarity select
            end
            assign irq = |(int_en & int_raw & ~int_stat);
        
            // APB read data multiplexer (zero wait-state combinational read)
            reg [31:0] prdata_reg;
 000018     always @(*) begin
 000018         case (paddr[3:2])
 676903             2'd0: prdata_reg = in_sync;
 092543             2'd1: prdata_reg = dir_reg;
 006887             2'd2: prdata_reg = int_en;
 003822             2'd3: prdata_reg = int_stat;
%000000             default: prdata_reg = 32'h0;
                endcase
            end
            assign prdata = prdata_reg;
        
            // APB write access
 780137     always @(posedge clk or negedge rst_n) begin
 000540         if (!rst_n) begin
 000540             dir_reg  <= 32'h0;
 000540             out_reg  <= 32'h0;
 000540             int_en   <= 32'h0;
 000540             int_pol  <= 32'h0;
 000540             int_stat <= 32'h0;
 779597         end else if (psel && penable && pwrite) begin
%000000             case (paddr[3:2])
%000000                 2'd0: out_reg  <= pwdata;
%000000                 2'd1: dir_reg  <= pwdata;
%000000                 2'd2: int_en   <= pwdata;
%000000                 2'd3: begin
%000000                     int_pol  <= pwdata;
%000000                     int_stat <= int_stat & ~pwdata; // W1C on bit3
                        end
                    endcase
                end
            end
        endmodule
        
