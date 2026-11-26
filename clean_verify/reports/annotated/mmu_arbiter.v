//      // verilator_coverage annotation
        // SPDX-License-Identifier: Apache-2.0
        // SMVDU-TITAN-X SoC — MMU PTW Arbiter
        // Iteration 3: Routes 5 Page Table Walkers (PTW) to a single L2 cache port.
        // Read-only AXI4 arbiter.
        `timescale 1ns/1ps
        
        module mmu_arbiter #(
            parameter N  = 5, // 5 PTWs
            parameter AW = 40,
            parameter DW = 64
        ) (
            input  wire clk,
            input  wire rst_n,
        
            // 5 Master Ports from PTWs (Read-only AXI4-Lite style)
            input  wire [N-1:0]        s_arvalid,
            output wire [N-1:0]        s_arready,
            input  wire [(N*AW)-1:0]   s_araddr,
            
            output wire [N-1:0]        s_rvalid,
            input  wire [N-1:0]        s_rready,
            output wire [(N*DW)-1:0]   s_rdata,
            output wire [(N*2)-1:0]    s_rresp,
        
            // 1 Slave Port to L2 (or Crossbar)
            output wire                m_arvalid,
            input  wire                m_arready,
            output wire [AW-1:0]       m_araddr,
            
            input  wire                m_rvalid,
            output wire                m_rready,
            input  wire [DW-1:0]       m_rdata,
            input  wire [1:0]          m_rresp
        );
        
            // Simple Round-Robin Arbitration
            reg [2:0] grant_idx;
            reg       req_active;
            
            integer i;
 780137     always @(posedge clk or negedge rst_n) begin
 000540         if (!rst_n) begin
 000540             grant_idx <= 3'd0;
 000540             req_active <= 1'b0;
 779597         end else begin
 000022             if (req_active) begin
                        // Transaction in progress, wait for read data to complete
%000003                 if (m_rvalid && m_rready) begin
%000003                     req_active <= 1'b0;
                            // Move to next priority after completing a request
%000003                     grant_idx <= (grant_idx == N-1) ? 3'd0 : grant_idx + 1;
                        end
 779575             end else begin
                        // Look for a new request starting from grant_idx
%000001                 if (s_arvalid[grant_idx]) begin
%000001                     req_active <= 1'b1;
 779574                 end else begin
                            // Priority encoder for next request
 779574                     for (i = 1; i <= N; i = i + 1) begin
%000002                         if (s_arvalid[(grant_idx + i) % N] && !req_active) begin
%000002                             grant_idx <= (grant_idx + i) % N;
%000002                             req_active <= 1'b1;
                                end
                            end
                        end
                    end
                end
            end
        
            // Demux responses and Mux requests
            assign m_arvalid = req_active && s_arvalid[grant_idx];
            assign m_araddr  = s_araddr[grant_idx*AW +: AW];
            
            assign m_rready  = req_active ? s_rready[grant_idx] : 1'b1;
        
            genvar g;
            generate
                for (g = 0; g < N; g = g + 1) begin : gen_demux
                    assign s_arready[g] = (req_active && grant_idx == g) ? m_arready : 1'b0;
                    assign s_rvalid[g]  = (req_active && grant_idx == g) ? m_rvalid : 1'b0;
                    assign s_rdata[g*DW +: DW] = m_rdata;
                    assign s_rresp[g*2 +: 2]   = m_rresp;
                end
            endgenerate
        
        endmodule
        
