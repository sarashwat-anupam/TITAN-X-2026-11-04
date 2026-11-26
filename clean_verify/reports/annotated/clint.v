//      // verilator_coverage annotation
        // SPDX-License-Identifier: Apache-2.0
        // SMVDU-TITAN-X SoC — CLINT: Core-Local Interruptor
        // Implements: mtime (64-bit), mtimecmp[0:4] (64-bit), msip[0:4]
        // Memory map (APB-style, 32-bit access):
        //   0x0000 - 0x0013: msip[0..4]  (4 bytes each)
        //   0x4000 - 0x4027: mtimecmp[0..4] (8 bytes each, lo then hi)
        //   0xBFF8 - 0xBFFF: mtime (8 bytes, lo then hi)
        // Pre-Synthesis Clean-Room Fix (Defect D-037): Zero wait-state combinational prdata,
        // and full mtimecmp[0:4] readback decoding.
        `timescale 1ns/1ps
        
        module clint #(
            parameter NUM_HARTS = 5
        ) (
            input  wire        clk,
            input  wire        rst_n,
            // APB slave
            input  wire        psel,
            input  wire        penable,
            input  wire        pwrite,
            input  wire [15:0] paddr,
            input  wire [31:0] pwdata,
            output wire [31:0] prdata,
            output wire        pready,
            // Interrupt outputs
            output wire [NUM_HARTS-1:0] msip,
            output wire [NUM_HARTS-1:0] mtip
        );
            reg [63:0] mtime;
            reg [63:0] mtimecmp [0:NUM_HARTS-1];
            reg [NUM_HARTS-1:0] msip_reg;
        
            assign pready = 1'b1;  // Zero-wait APB
        
            // mtime increments every cycle
 780137     always @(posedge clk or negedge rst_n) begin
 000540         if (!rst_n) begin
 000540             mtime <= 64'h0;
 779597         end else begin
 779597             mtime <= mtime + 64'h1;
                end
            end
        
            // mtip: timer interrupt when mtime >= mtimecmp
            genvar g;
            generate
                for (g = 0; g < NUM_HARTS; g = g+1) begin : GEN_MTIP
                    assign mtip[g] = (mtime >= mtimecmp[g]);
                end
            endgenerate
            assign msip = msip_reg;
        
            // APB Write Register Configuration
            integer i;
 780137     always @(posedge clk or negedge rst_n) begin
 000540         if (!rst_n) begin
 000540             msip_reg <= {NUM_HARTS{1'b0}};
 000540             for (i = 0; i < NUM_HARTS; i = i+1)
 002700                 mtimecmp[i] <= 64'hFFFF_FFFF_FFFF_FFFF;
%000005         end else if (psel && penable && pwrite) begin
%000002             if (paddr < 16'h0020) begin
                        // msip region: 0x0000 + hart*4
%000000                 if (paddr[5:2] < NUM_HARTS)
%000002                     msip_reg[paddr[5:2]] <= pwdata[0];
%000000             end else if (paddr >= 16'h4000 && paddr < 16'h4028) begin
                        // mtimecmp region
%000003                 case (paddr[5:2])
%000002                     4'd0: mtimecmp[0][31:0]  <= pwdata;
%000001                     4'd1: mtimecmp[0][63:32] <= pwdata;
%000000                     4'd2: mtimecmp[1][31:0]  <= pwdata;
%000000                     4'd3: mtimecmp[1][63:32] <= pwdata;
%000000                     4'd4: mtimecmp[2][31:0]  <= pwdata;
%000000                     4'd5: mtimecmp[2][63:32] <= pwdata;
%000000                     4'd6: mtimecmp[3][31:0]  <= pwdata;
%000000                     4'd7: mtimecmp[3][63:32] <= pwdata;
%000000                     4'd8: mtimecmp[4][31:0]  <= pwdata;
%000000                     4'd9: mtimecmp[4][63:32] <= pwdata;
%000000                     default: ;
                        endcase
                    end
                end
            end
        
            // Combinational Zero Wait-State Read Data
            reg [31:0] prdata_comb;
 000018     always @(*) begin
 695270         if (paddr < 16'h0020) begin
 007797             if (paddr[5:2] < NUM_HARTS)
 687473                 prdata_comb = {31'h0, msip_reg[paddr[5:2]]};
                    else
 007797                 prdata_comb = 32'h0;
 001069         end else if (paddr >= 16'h4000 && paddr < 16'h4028) begin
 001069             case (paddr[5:2])
 000503                 4'd0: prdata_comb = mtimecmp[0][31:0];
 000189                 4'd1: prdata_comb = mtimecmp[0][63:32];
 000184                 4'd2: prdata_comb = mtimecmp[1][31:0];
 000159                 4'd3: prdata_comb = mtimecmp[1][63:32];
%000008                 4'd4: prdata_comb = mtimecmp[2][31:0];
 000026                 4'd5: prdata_comb = mtimecmp[2][63:32];
%000000                 4'd6: prdata_comb = mtimecmp[3][31:0];
%000000                 4'd7: prdata_comb = mtimecmp[3][63:32];
%000000                 4'd8: prdata_comb = mtimecmp[4][31:0];
%000000                 4'd9: prdata_comb = mtimecmp[4][63:32];
%000000                 default: prdata_comb = 32'h0;
                    endcase
%000000         end else if (paddr == 16'hBFF8) begin
%000000             prdata_comb = mtime[31:0];
 083816         end else if (paddr == 16'hBFFC) begin
%000000             prdata_comb = mtime[63:32];
 083816         end else begin
 083816             prdata_comb = 32'h0;
                end
            end
            assign prdata = prdata_comb;
        
        endmodule
        
