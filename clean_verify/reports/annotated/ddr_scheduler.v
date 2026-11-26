//      // verilator_coverage annotation
        // SPDX-License-Identifier: Apache-2.0
        // SMVDU-TITAN-X SoC — DDR Scheduler (Open-Row Policy)
        // Accepts commands from ddr_ctrl_top and sequences ACT/CAS/PRE
        `timescale 1ns/1ps
        module ddr_scheduler #(
            parameter BANKS    = 8,
            parameter ROWS     = 65536,
            parameter COLS     = 1024,
            parameter tRCD     = 4,   // cycles
            parameter tRP      = 4,
            parameter tCAS     = 4
        ) (
            input  wire        clk,
            input  wire        rst_n,
            // Command from controller
            input  wire        cmd_valid,
            input  wire [1:0]  cmd_type,    // 00=RD, 01=WR, 10=REF, 11=PRE
            input  wire [1:0]  cmd_bg,      // bank group (DDR4)
            input  wire [2:0]  cmd_bank,
            input  wire [15:0] cmd_row,
            input  wire [9:0]  cmd_col,
            output wire        cmd_ready,
            output reg         cmd_done,    // pulsed when a WR (or REF) fully retires
            output reg  [63:0] rd_data,
            output reg         rd_valid,
            input  wire [63:0] wr_data,
            // DFI command outputs to PHY
            output reg         dfi_cs_n,
            output reg         dfi_ras_n,
            output reg         dfi_cas_n,
            output reg         dfi_we_n,
            output reg         dfi_act_n,
            output reg  [2:0]  dfi_bank,
            output reg  [1:0]  dfi_bg,
            output reg  [15:0] dfi_addr,
            output reg         dfi_wrdata_valid,
            output reg  [63:0] dfi_wrdata,
            input  wire [63:0] dfi_rddata,
            input  wire        dfi_rddata_valid
        );
            localparam CMD_RD  = 2'd0;
            localparam CMD_WR  = 2'd1;
            localparam CMD_REF = 2'd2;  // BUG-DDR-002 fix: was CMD_ACT, now properly CMD_REF
            localparam CMD_PRE = 2'd3;
        
            // Open-row tracking. Indexed by {bg,bank}: DDR4 bank groups are
            // independent rows — tracking per-bank alone made the scheduler skip
            // ACT for a {bg!=0} access whose bank happened to hold the same row,
            // and the PHY (which DOES track {bg,bank}) silently dropped the
            // access on a closed row (BUG-DDR-005).
            localparam BA_SLOTS = 32;                  // 4 BG x 8 banks
            reg [15:0] open_row   [0:BA_SLOTS-1];
            reg        row_open   [0:BA_SLOTS-1];
            wire [4:0] ba_cmd     = {cmd_bg, cmd_bank};
            wire [4:0] ba_saved   = {saved_bg, saved_bank};
            integer    i;
        
            // Timing counters
            reg [3:0] tRCD_cnt, tRP_cnt, tCAS_cnt;
        
            localparam SC_IDLE  = 3'd0;
            localparam SC_PRE   = 3'd1;
            localparam SC_TRPW  = 3'd2;
            localparam SC_ACT   = 3'd3;
            localparam SC_TRCDW = 3'd4;
            localparam SC_CAS   = 3'd5;
            localparam SC_CASW  = 3'd6;
            localparam SC_RDWT  = 3'd7;  // BUG-DDR-001 fix: wait for dfi_rddata_valid
        
            reg [2:0]  sched_state;
            reg [1:0]  saved_cmd_type;
            reg [1:0]  saved_bg;
            reg [2:0]  saved_bank;
            reg [15:0] saved_row;
            reg [9:0]  saved_col;
            reg        rd_arm;      // BUG-DDR-003: armed once valid observed LOW
        
            assign cmd_ready = (sched_state == SC_IDLE);
        
 780137     always @(posedge clk or negedge rst_n) begin
 000540         if (!rst_n) begin
 000540             for (i = 0; i < BA_SLOTS; i = i+1) begin
 017280                 open_row[i] <= 16'h0;
 017280                 row_open[i] <= 1'b0;
                    end
 000540             cmd_done       <= 1'b0;
 000540             rd_arm         <= 1'b0;
 000540             dfi_cs_n       <= 1'b1;
 000540             dfi_ras_n      <= 1'b1;
 000540             dfi_cas_n      <= 1'b1;
 000540             dfi_we_n       <= 1'b1;
 000540             dfi_act_n      <= 1'b1;
 000540             dfi_bank       <= 3'h0;
 000540             dfi_bg         <= 2'h0;
 000540             dfi_addr       <= 16'h0;
 000540             dfi_wrdata_valid <= 1'b0;
 000540             dfi_wrdata     <= 64'h0;
 000540             rd_valid       <= 1'b0;
 000540             tRCD_cnt       <= 4'h0;
 000540             tRP_cnt        <= 4'h0;
 000540             tCAS_cnt       <= 4'h0;
 000540             sched_state    <= SC_IDLE;
 779597         end else begin
 779597             dfi_cs_n       <= 1'b1;  // Default: NOP
 779597             dfi_ras_n      <= 1'b1;
 779597             dfi_cas_n      <= 1'b1;
 779597             dfi_we_n       <= 1'b1;
 779597             dfi_act_n      <= 1'b1;
 779597             dfi_wrdata_valid <= 1'b0;
 779597             cmd_done       <= 1'b0;
 779597             rd_valid       <= 1'b0;
        
 779597             case (sched_state)
 741589                 SC_IDLE: begin
 007492                     if (cmd_valid) begin
 007492                         rd_arm         <= 1'b0;
 007492                         saved_cmd_type <= cmd_type;
 007492                         saved_bg       <= cmd_bg;
 007492                         saved_bank     <= cmd_bank;
 007492                         saved_row      <= cmd_row;
 007492                         saved_col      <= cmd_col;
 000492                         if (cmd_type == CMD_REF) begin
                                    // BUG-DDR-002 fix: refresh = NOP pulse, no bank state change
 000492                             tRP_cnt     <= tRP[3:0];
 000492                             sched_state <= SC_TRPW;  // reuse tRP wait as tRFC mini-delay
 006932                         end else if (row_open[ba_cmd] && open_row[ba_cmd] == cmd_row) begin
                                    // Row already open: go direct to CAS
 006932                             sched_state <= SC_CAS;
 000028                         end else if (row_open[ba_cmd]) begin
                                    // Different row open: precharge first
 000028                             dfi_cs_n  <= 1'b0;
 000028                             dfi_ras_n <= 1'b0;
 000028                             dfi_we_n  <= 1'b0;
 000028                             dfi_bank  <= cmd_bank;
 000028                             dfi_bg    <= cmd_bg;
 000028                             dfi_addr  <= 16'h0400; // AP bit
 000028                             tRP_cnt   <= tRP[3:0];
 000028                             row_open[ba_cmd] <= 1'b0;
 000028                             sched_state <= SC_TRPW;
 000040                         end else begin
                                    // Row closed: ACT
 000040                             sched_state <= SC_ACT;
                                end
                            end
                        end
        
 002600                 SC_TRPW: begin
 000520                     if (tRP_cnt == 4'h0) begin
 000028                         if (saved_cmd_type == CMD_REF) begin
 000492                             cmd_done    <= 1'b1;
 000492                             sched_state <= SC_IDLE;
 000028                         end else begin
 000028                             sched_state <= SC_ACT;
                                end
 002080                     end else tRP_cnt <= tRP_cnt - 4'h1;
                        end
        
 000068                 SC_ACT: begin
 000068                     dfi_cs_n  <= 1'b0;
 000068                     dfi_ras_n <= 1'b0;
 000068                     dfi_act_n <= 1'b0;
 000068                     dfi_bank  <= saved_bank;
 000068                     dfi_bg    <= saved_bg;
 000068                     dfi_addr  <= saved_row;
 000068                     open_row[ba_saved] <= saved_row;
 000068                     row_open[ba_saved] <= 1'b1;
 000068                     tRCD_cnt  <= tRCD[3:0];
 000068                     sched_state <= SC_TRCDW;
                        end
        
 000340                 SC_TRCDW: begin
 000068                     if (tRCD_cnt == 4'h0) sched_state <= SC_CAS;
 000272                     else tRCD_cnt <= tRCD_cnt - 4'h1;
                        end
        
 007000                 SC_CAS: begin
 007000                     dfi_cs_n  <= 1'b0;
 007000                     dfi_cas_n <= 1'b0;
 007000                     dfi_bank  <= saved_bank;
 007000                     dfi_bg    <= saved_bg;
 007000                     dfi_addr  <= {{6{1'b0}}, saved_col};
 007000                     if (saved_cmd_type == CMD_WR) begin
%000000                         dfi_we_n         <= 1'b0;
%000000                         dfi_wrdata_valid <= 1'b1;
%000000                         dfi_wrdata       <= wr_data;
%000000                         tCAS_cnt    <= tCAS[3:0];   // write turnaround
%000000                         sched_state <= SC_CASW;
 007000                     end else begin
                                // Read: CAS latency already covers the data flight time
                                // (PHY returns data CL cycles after this pulse). Waiting
                                // tCAS more cycles first misses the rddata_valid window.
 007000                         sched_state <= SC_RDWT;
                            end
                        end
        
%000000                 SC_CASW: begin
%000000                     if (tCAS_cnt == 4'h0) begin
%000000                         sched_state <= SC_IDLE;     // write done
%000000                         cmd_done    <= 1'b1;        // BUG-DDR-004: real completion flag
                            end else
%000000                         tCAS_cnt <= tCAS_cnt - 4'h1;
                        end
        
 028000                 SC_RDWT: begin
                            // Wait for PHY to assert dfi_rddata_valid (CL cycles after
                            // CAS). Valid is level-held by the PHY until the next
                            // command — and the command-active cycle coincides with
                            // our FIRST SC_RDWT cycle, where the stale valid from the
                            // previous read is still high. Arm only after observing
                            // valid LOW once; then the next rising valid carries this
                            // command's fresh data (BUG-DDR-003).
 014068                     if (!dfi_rddata_valid)
 014068                         rd_arm <= 1'b1;
 006932                     else if (rd_arm) begin
 007000                         rd_data  <= dfi_rddata;
 007000                         rd_valid <= 1'b1;
 007000                         sched_state <= SC_IDLE;
        `ifdef TB_SCHED_TRACE
                                $display("[SCHED] %0t RDWT latch d=%h col_saved=%0d",
                                         $time, dfi_rddata, saved_col);
        `endif
                            end
                        end
        
%000000                 default: sched_state <= SC_IDLE;
                    endcase
                end
            end
        endmodule
        
