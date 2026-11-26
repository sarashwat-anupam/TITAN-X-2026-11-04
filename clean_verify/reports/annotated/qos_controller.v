//      // verilator_coverage annotation
        // SPDX-License-Identifier: Apache-2.0
        // SMVDU-TITAN-X SoC — QoS Controller
        // Dynamically adjusts AXI QoS signals based on bandwidth usage.
        // Targets high-bandwidth masters (Video DMA, PCIe, Ethernet).
        // Fully synthesizable Verilog-2001 with APB register programming.
        `timescale 1ns/1ps
        
        module qos_controller #(
            parameter NM = 15, // Total masters
            parameter IDW = 4
        ) (
            input  wire clk,
            input  wire rst_n,
        
            // APB Config Interface (Memory Mapped Registers)
            input  wire [31:0]          paddr,
            input  wire                 psel,
            input  wire                 penable,
            input  wire                 pwrite,
            input  wire [31:0]          pwdata,
            output reg  [31:0]          prdata,
            output wire                 pready,
            output wire                 pslverr,
        
            // QoS configuration from direct ports (flattened 1D for Verilog-2001)
            input  wire [(NM*4)-1:0]    cfg_base_qos,
            input  wire [(NM*4)-1:0]    cfg_boost_qos,
            input  wire [(NM*16)-1:0]   cfg_bw_limit,
            input  wire [15:0]          cfg_time_win,
        
            // AXI read/write valid/ready signals to monitor bandwidth usage
            input  wire [NM-1:0]        m_arvalid,
            input  wire [NM-1:0]        m_arready,
            input  wire [NM-1:0]        m_awvalid,
            input  wire [NM-1:0]        m_awready,
        
            // Output QoS signals (Flattened 1D vectors)
            output wire [(NM*4)-1:0]    m_arqos,
            output wire [(NM*4)-1:0]    m_awqos
        );
        
            // -------------------------------------------------------
            // Internal Configuration Registers (Programmable via APB)
            // -------------------------------------------------------
            reg [15:0] reg_time_win;
            reg [3:0]  reg_base_qos  [0:NM-1];
            reg [3:0]  reg_boost_qos [0:NM-1];
            reg [15:0] reg_bw_limit  [0:NM-1];
        
            wire [3:0] m_idx = paddr[5:2] - 4'd1;
            integer r_init;
        
 780137     always @(posedge clk or negedge rst_n) begin
 000540         if (!rst_n) begin
 000540             reg_time_win <= 16'd1000;
 000540             for (r_init = 0; r_init < NM; r_init = r_init + 1) begin
 008640                 reg_base_qos[r_init]  <= 4'h1;
 008640                 reg_boost_qos[r_init] <= 4'hF;
 008640                 reg_bw_limit[r_init]  <= 16'd64;
                    end
%000004         end else if (psel && penable && pwrite) begin
%000002             if (paddr[5:2] == 4'd0) begin
%000002                 reg_time_win <= pwdata[15:0];
%000000             end else if (m_idx < NM) begin
%000002                 reg_base_qos[m_idx]  <= pwdata[3:0];
%000002                 reg_boost_qos[m_idx] <= pwdata[7:4];
%000002                 reg_bw_limit[m_idx]  <= pwdata[31:16];
                    end
                end
            end
        
            // -------------------------------------------------------
            // Effective Configuration Selection
            // -------------------------------------------------------
            wire [15:0] eff_time_win;
            wire [3:0]  eff_base_qos  [0:NM-1];
            wire [3:0]  eff_boost_qos [0:NM-1];
            wire [15:0] eff_bw_limit  [0:NM-1];
        
            assign eff_time_win = (cfg_time_win != 16'h0) ? cfg_time_win : reg_time_win;
        
            genvar ge;
            generate
                for (ge = 0; ge < NM; ge = ge + 1) begin : gen_eff
                    wire [3:0]  port_base  = cfg_base_qos[ge*4 +: 4];
                    wire [3:0]  port_boost = cfg_boost_qos[ge*4 +: 4];
                    wire [15:0] port_limit = cfg_bw_limit[ge*16 +: 16];
        
                    assign eff_base_qos[ge]  = (port_base != 4'h0)  ? port_base  : reg_base_qos[ge];
                    assign eff_boost_qos[ge] = (port_boost != 4'h0) ? port_boost : reg_boost_qos[ge];
                    assign eff_bw_limit[ge]  = (port_limit != 16'h0) ? port_limit : reg_bw_limit[ge];
                end
            endgenerate
        
            // APB Read
 000018     always @(*) begin
 674990         if (paddr[5:2] == 4'd0) begin
 674990             prdata = {16'h0, eff_time_win};
%000000         end else if (m_idx < NM) begin
 105165             prdata = {eff_bw_limit[m_idx], 8'h0, eff_boost_qos[m_idx], eff_base_qos[m_idx]};
%000000         end else begin
%000000             prdata = 32'h0;
                end
            end
        
            assign pready  = 1'b1;
            assign pslverr = 1'b0;
        
            // -------------------------------------------------------
            // Bandwidth Accounting & Dynamic QoS State Machine
            // -------------------------------------------------------
            reg [15:0] time_cnt;
            reg [15:0] bw_cnt [0:NM-1];
            reg [3:0]  cur_arqos [0:NM-1];
            reg [3:0]  cur_awqos [0:NM-1];
        
            integer i;
 780137     always @(posedge clk or negedge rst_n) begin
 000540         if (!rst_n) begin
 000540             time_cnt <= 16'h0;
 000540             for (i = 0; i < NM; i = i + 1) begin
 008640                 bw_cnt[i]    <= 16'h0;
 008640                 cur_arqos[i] <= 4'h0;
 008640                 cur_awqos[i] <= 4'h0;
                    end
 779597         end else begin
                    // Time window counter
 000895             if (time_cnt >= eff_time_win) begin
 000895                 time_cnt <= 16'h0;
                        // Evaluate QoS at the end of window
 000895                 for (i = 0; i < NM; i = i + 1) begin
 000485                     if (bw_cnt[i] > eff_bw_limit[i]) begin
                                // Exceeded bandwidth: lower QoS to base
 000485                         cur_arqos[i] <= eff_base_qos[i];
 000485                         cur_awqos[i] <= eff_base_qos[i];
 013835                     end else begin
                                // Within limits: boost QoS
 013835                         cur_arqos[i] <= eff_boost_qos[i];
 013835                         cur_awqos[i] <= eff_boost_qos[i];
                            end
                            // Reset BW counter for next window
 014320                     bw_cnt[i] <= 16'h0;
                        end
 778702             end else begin
 778702                 time_cnt <= time_cnt + 16'h1;
                        // Accumulate bandwidth (count accepted transactions)
 778702                 for (i = 0; i < NM; i = i + 1) begin
 182809                     if (m_arvalid[i] && m_arready[i]) bw_cnt[i] <= bw_cnt[i] + 16'h1;
 009614                     if (m_awvalid[i] && m_awready[i]) bw_cnt[i] <= bw_cnt[i] + 16'h1;
                        end
                    end
                end
            end
        
            // -------------------------------------------------------
            // Output Flattening
            // -------------------------------------------------------
            genvar g;
            generate
                for (g = 0; g < NM; g = g + 1) begin : gen_qos_out
                    assign m_arqos[g*4 +: 4] = cur_arqos[g];
                    assign m_awqos[g*4 +: 4] = cur_awqos[g];
                end
            endgenerate
        
        endmodule
        
