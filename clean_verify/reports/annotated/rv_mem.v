//      // verilator_coverage annotation
        // SPDX-License-Identifier: Apache-2.0
        // SMVDU-TITAN-X SoC — RV64I Memory Access Stage with A-Extension (Atomics)
        `timescale 1ns/1ps
        `include "params.vh"
        `include "isa_pkg.vh"
        
        module rv_mem (
            input  wire        clk,
            input  wire        rst_n,
            input  wire        flush,
            // From execute
            input  wire [63:0] alu_result,
            input  wire [63:0] rs2_data,
            input  wire [4:0]  rd_in,
            input  wire [2:0]  funct3,
            input  wire [6:0]  opcode,
            input  wire        mem_read,
            input  wire        mem_write,
            input  wire        reg_write,
            input  wire        is_amo,
            input  wire [4:0]  amo_funct5,
            input  wire        valid_in,
            // Physical address from MMU and Page Fault inputs
            input  wire [39:0] phys_addr,
            input  wire        mmu_page_fault,
            input  wire [63:0] mmu_fault_va,
            input  wire        mmu_trans_busy,
            input  wire        pmp_fault,
            // Snoop invalidation interface from L2 coherence subsystem
            input  wire        snoop_valid,
            input  wire [39:0] snoop_addr,
            input  wire [1:0]  snoop_type,
            // Data memory AXI4-Lite master
            output reg         dmem_awvalid,
            input  wire        dmem_awready,
            output reg  [39:0] dmem_awaddr,
            output reg         dmem_wvalid,
            input  wire        dmem_wready,
            output reg  [63:0] dmem_wdata,
            output reg  [7:0]  dmem_wstrb,
            input  wire        dmem_bvalid,
            output reg         dmem_bready,
            output reg         dmem_arvalid,
            input  wire        dmem_arready,
            output reg  [39:0] dmem_araddr,
            input  wire        dmem_rvalid,
            output reg         dmem_rready,
            input  wire [63:0] dmem_rdata,
            input  wire [1:0]  dmem_rresp,
            input  wire [63:0] pc_in,
            input  wire [1:0]  dmem_bresp,
            // To writeback
            output reg  [63:0] result,
            output reg  [4:0]  rd_out,
            output reg         reg_write_out,
            output reg         valid_out,
            // Forwarding output
            output wire [63:0] fwd_mem_data,
            output wire [4:0]  fwd_mem_rd,
            output wire        fwd_mem_valid,
            // Fault reporting to core exception unit
            output reg         mem_fault,
            output reg  [63:0] mem_fault_pc,
            output reg  [63:0] mem_fault_cause,
            output reg  [63:0] mem_fault_tval,
            // Stall request
            output wire        mem_stall
        );
            localparam MS_IDLE      = 3'd0;
            localparam MS_DATA      = 3'd1;
            localparam MS_DONE      = 3'd2;
            localparam MS_AMO_READ  = 3'd3;
            localparam MS_AMO_WRITE = 3'd4;
            reg [2:0]  mstate;
            reg [63:0] load_data;
            reg        mem_active;
            reg [63:0] pc_q;
            reg [39:0] store_addr_q;
            reg        lr_valid;
            reg [39:0] lr_addr;
            reg        is_sc_q;
            reg        sc_failed;
            reg [2:0]  funct3_q;
            reg [4:0]  amo_funct5_q;
            reg [63:0] rs2_data_q;
            wire [39:0] eff_mem_addr = (phys_addr[0] !== 1'bx) ? phys_addr : alu_result[39:0];
        
            wire [1:0]  clean_bresp = dmem_bresp;
            wire [1:0]  clean_rresp = dmem_rresp;
            wire [63:0] clean_pc_in = pc_in;
        
            wire snoop_kills_lr = snoop_valid && (snoop_type != 2'b00) && (snoop_addr[39:6] == lr_addr[39:6]);
            wire snoop_kills_sc = is_sc_q && snoop_valid && (snoop_type != 2'b00) && (snoop_addr[39:6] == store_addr_q[39:6]);
            wire sc_fail = is_amo && (amo_funct5 == `AMO_SC) && !(lr_valid && !snoop_kills_lr && (lr_addr[39:3] == eff_mem_addr[39:3]));
            wire mem_req_active = valid_in && (mem_read || mem_write || is_amo) &&
                                  !(mmu_page_fault || pmp_fault) && !sc_fail;
        
            assign mem_stall  = (mem_active && (mstate != MS_DONE)) ||
                                (valid_in && (mem_read || mem_write || is_amo) && mmu_trans_busy);
            assign fwd_mem_data  = result;
            assign fwd_mem_rd    = rd_out;
            // Suppress forwarding while a memory transaction is in flight: 'result'
            // still holds the PREVIOUS instruction's value until the transfer
            // completes, and advertising it here would feed a dependent in execute
            // with stale data for the whole bus latency.
            assign fwd_mem_valid = valid_out && reg_write_out && !mem_active;
        
            // Load data sign-extension
 023837     function [63:0] extend_load;
                input [63:0] raw;
                input [2:0]  f3;
 023837         case (f3)
 000753             3'b000: extend_load = {{56{raw[7]}},  raw[7:0]};   // LB
 001126             3'b001: extend_load = {{48{raw[15]}}, raw[15:0]};  // LH
 006425             3'b010: extend_load = {{32{raw[31]}}, raw[31:0]};  // LW
 011235             3'b011: extend_load = raw;                          // LD
 001226             3'b100: extend_load = {56'h0, raw[7:0]};           // LBU
 001277             3'b101: extend_load = {48'h0, raw[15:0]};          // LHU
 001795             3'b110: extend_load = {32'h0, raw[31:0]};          // LWU
%000000             default:extend_load = raw;
                endcase
            endfunction
        
            // Write strobe from funct3
 009564     function [7:0] wstrb_from_f3;
                input [2:0] f3;
 009564         case (f3)
 002362             3'b000: wstrb_from_f3 = 8'b0000_0001; // SB
 002176             3'b001: wstrb_from_f3 = 8'b0000_0011; // SH
 002159             3'b010: wstrb_from_f3 = 8'b0000_1111; // SW
 002867             3'b011: wstrb_from_f3 = 8'b1111_1111; // SD
%000000             default:wstrb_from_f3 = 8'b1111_1111;
                endcase
            endfunction
        
            // 32-bit AMO compute function
 000072     function [31:0] calc_amo_32;
                input [4:0]  af5;
                input [31:0] old_v;
                input [31:0] op_v;
 000072         case (af5)
 000027             `AMO_SWAP: calc_amo_32 = op_v;
 3097681             `AMO_ADD:  calc_amo_32 = old_v + op_v;
 000025             `AMO_XOR:  calc_amo_32 = old_v ^ op_v;
 000025             `AMO_AND:  calc_amo_32 = old_v & op_v;
 000027             `AMO_OR:   calc_amo_32 = old_v | op_v;
 000024             `AMO_MIN:  calc_amo_32 = ($signed(old_v) < $signed(op_v)) ? old_v : op_v;
 000024             `AMO_MAX:  calc_amo_32 = ($signed(old_v) > $signed(op_v)) ? old_v : op_v;
 000162             `AMO_MINU: calc_amo_32 = (old_v < op_v) ? old_v : op_v;
 000024             `AMO_MAXU: calc_amo_32 = (old_v > op_v) ? old_v : op_v;
 022601             default:   calc_amo_32 = old_v + op_v;
                endcase
            endfunction
        
            // 64-bit AMO compute function
 000072     function [63:0] calc_amo_64;
                input [4:0]  af5;
                input [63:0] old_v;
                input [63:0] op_v;
 000072         case (af5)
 000027             `AMO_SWAP: calc_amo_64 = op_v;
 3097681             `AMO_ADD:  calc_amo_64 = old_v + op_v;
 000025             `AMO_XOR:  calc_amo_64 = old_v ^ op_v;
 000025             `AMO_AND:  calc_amo_64 = old_v & op_v;
 000027             `AMO_OR:   calc_amo_64 = old_v | op_v;
 000024             `AMO_MIN:  calc_amo_64 = ($signed(old_v) < $signed(op_v)) ? old_v : op_v;
 000024             `AMO_MAX:  calc_amo_64 = ($signed(old_v) > $signed(op_v)) ? old_v : op_v;
 000162             `AMO_MINU: calc_amo_64 = (old_v < op_v) ? old_v : op_v;
 000024             `AMO_MAXU: calc_amo_64 = (old_v > op_v) ? old_v : op_v;
 022601             default:   calc_amo_64 = old_v + op_v;
                endcase
            endfunction
        
            wire [31:0] amo_old_32 = (dmem_rdata >> {store_addr_q[2:0], 3'b000}) & 32'hFFFF_FFFF;
            wire [31:0] amo_new_32 = calc_amo_32(amo_funct5_q, amo_old_32, rs2_data_q[31:0]);
            wire [63:0] amo_old_64 = dmem_rdata;
            wire [63:0] amo_new_64 = calc_amo_64(amo_funct5_q, amo_old_64, rs2_data_q);
        
 3120548     always @(posedge clk or negedge rst_n) begin
 866520         if (!rst_n) begin
 866520             dmem_awvalid    <= 1'b0;  dmem_awaddr  <= 40'h0;
 866520             dmem_wvalid     <= 1'b0;  dmem_wdata   <= 64'h0;  dmem_wstrb <= 8'h0;
 866520             dmem_bready     <= 1'b0;
 866520             dmem_arvalid    <= 1'b0;  dmem_araddr  <= 40'h0;
 866520             dmem_rready     <= 1'b0;
 866520             result          <= 64'h0;
 866520             rd_out          <= 5'h0;
 866520             reg_write_out   <= 1'b0;
 866520             valid_out       <= 1'b0;
 866520             load_data       <= 64'h0;
 866520             mem_active      <= 1'b0;
 866520             mstate          <= MS_IDLE;
 866520             pc_q            <= 64'h0;
 866520             store_addr_q    <= 40'h0;
 866520             lr_valid        <= 1'b0;
 866520             lr_addr         <= 40'h0;
 866520             is_sc_q         <= 1'b0;
 866520             sc_failed       <= 1'b0;
 866520             funct3_q        <= 3'h0;
 866520             amo_funct5_q    <= 5'h0;
 866520             rs2_data_q      <= 64'h0;
 866520             mem_fault       <= 1'b0;
 866520             mem_fault_pc    <= 64'h0;
 866520             mem_fault_cause <= 64'h0;
 866520             mem_fault_tval  <= 64'h0;
 2254028         end else if (flush) begin
%000000             dmem_awvalid    <= 1'b0;  dmem_awaddr  <= 40'h0;
%000000             dmem_wvalid     <= 1'b0;  dmem_wdata   <= 64'h0;  dmem_wstrb <= 8'h0;
%000000             dmem_bready     <= 1'b0;
%000000             dmem_arvalid    <= 1'b0;  dmem_araddr  <= 40'h0;
%000000             dmem_rready     <= 1'b0;
%000000             result          <= 64'h0;
%000000             rd_out          <= 5'h0;
%000000             reg_write_out   <= 1'b0;
%000000             valid_out       <= 1'b0;
%000000             load_data       <= 64'h0;
%000000             mem_active      <= 1'b0;
%000000             mstate          <= MS_IDLE;
%000000             pc_q            <= 64'h0;
%000000             store_addr_q    <= 40'h0;
%000000             is_sc_q         <= 1'b0;
%000000             sc_failed       <= 1'b0;
%000000             funct3_q        <= 3'h0;
%000000             amo_funct5_q    <= 5'h0;
%000000             rs2_data_q      <= 64'h0;
%000000             mem_fault       <= 1'b0;
%000000             mem_fault_pc    <= 64'h0;
%000000             mem_fault_cause <= 64'h0;
%000000             mem_fault_tval  <= 64'h0;
 2254028         end else begin
                    // Defect D-017 & D-018: Snoop invalidation of LR reservation and in-flight SC.
                    // Any write or invalidation snoop matching the 64-byte reservation line clears lr_valid.
                    // If an SC write is in-flight when snoop invalidation arrives, SC must fail.
 001642             if (snoop_valid && (snoop_type != 2'b00)) begin
 000306                 if (snoop_addr[39:6] == lr_addr[39:6])
 000306                     lr_valid <= 1'b0;
 000050                 if (is_sc_q && (snoop_addr[39:6] == store_addr_q[39:6]))
 000050                     sc_failed <= 1'b1;
                    end
        
 2254028             case (mstate)
 1839132                 MS_IDLE: begin
 1839132                     mem_fault <= 1'b0;
%000001                     if (valid_in && (mem_read || mem_write || is_amo) && (mmu_page_fault || pmp_fault)) begin
%000001                         mem_fault       <= 1'b1;
%000001                         mem_fault_pc    <= clean_pc_in;
%000001                         mem_fault_cause <= mmu_page_fault ? (mem_read ? 64'd13 : 64'd15) :
%000001                                            (mem_read ? 64'd5 : 64'd7); // 5=Load access fault, 7=Store/AMO access fault
%000001                         mem_fault_tval  <= mmu_page_fault ? mmu_fault_va : alu_result;
%000001                         valid_out       <= 1'b0;
%000001                         reg_write_out   <= 1'b0;
%000001                         mem_active      <= 1'b0;
%000001                         mstate          <= MS_IDLE;
 000020                     end else if (valid_in && (mem_read || mem_write || is_amo) && mmu_trans_busy) begin
 000020                         mem_active      <= 1'b1;
 000020                         mstate          <= MS_IDLE;
 000278                     end else if (valid_in && is_amo) begin
 000278                         funct3_q      <= funct3;
 000278                         amo_funct5_q  <= amo_funct5;
 000278                         rs2_data_q    <= rs2_data;
 000135                         if (amo_funct5 == `AMO_LR) begin
                                    // LR: Load Reserved
 000135                             dmem_arvalid  <= 1'b1;
 000135                             dmem_araddr   <= eff_mem_addr;
 000135                             pc_q          <= clean_pc_in;
 000135                             dmem_rready   <= 1'b1;
 000135                             mem_active    <= 1'b1;
 000135                             mstate        <= MS_DATA;
 000135                             rd_out        <= rd_in;
 000135                             reg_write_out <= reg_write;
 000135                             valid_out     <= 1'b0;
 000135                             if (snoop_valid && (snoop_type != 2'b00) && (snoop_addr[39:6] == eff_mem_addr[39:6])) begin
%000000                                 lr_valid  <= 1'b0;
 000135                             end else begin
 000135                                 lr_valid  <= 1'b1;
                                    end
 000135                             lr_addr       <= eff_mem_addr;
 000135                             is_sc_q       <= 1'b0;
 000010                         end else if (amo_funct5 == `AMO_SC) begin
                                    // SC: Store Conditional
%000006                             if (lr_valid && !snoop_kills_lr && (lr_addr[39:3] == eff_mem_addr[39:3])) begin
 000127                                 lr_valid      <= 1'b0;
 000127                                 sc_failed     <= 1'b0;
 000127                                 dmem_awvalid  <= 1'b1;
 000127                                 dmem_awaddr   <= eff_mem_addr;
 000127                                 store_addr_q  <= eff_mem_addr;
 000127                                 pc_q          <= clean_pc_in;
 000127                                 dmem_wvalid   <= 1'b1;
 000127                                 dmem_wdata    <= rs2_data << {alu_result[2:0], 3'b000};
 000127                                 dmem_wstrb    <= wstrb_from_f3(funct3) << alu_result[2:0];
 000127                                 dmem_bready   <= 1'b1;
 000127                                 mem_active    <= 1'b1;
 000127                                 mstate        <= MS_DATA;
 000127                                 rd_out        <= rd_in;
 000127                                 reg_write_out <= 1'b1;
 000127                                 result        <= 64'd0; // 0 = SC success (tentative)
 000127                                 valid_out     <= 1'b0;
 000127                                 is_sc_q       <= 1'b1;
%000006                             end else begin
%000006                                 lr_valid      <= 1'b0;
%000006                                 result        <= 64'd1; // 1 = SC failure
%000006                                 rd_out        <= rd_in;
%000006                                 reg_write_out <= 1'b1;
%000006                                 valid_out     <= 1'b1;
%000006                                 mem_active    <= 1'b0;
%000006                                 mstate        <= MS_IDLE;
%000006                                 is_sc_q       <= 1'b0;
                                    end
 000010                         end else begin
                                    // Read-Modify-Write AMO (AMOADD, AMOSWAP, etc.)
 000010                             dmem_arvalid  <= 1'b1;
 000010                             dmem_araddr   <= eff_mem_addr;
 000010                             store_addr_q  <= eff_mem_addr;
 000010                             pc_q          <= clean_pc_in;
 000010                             dmem_rready   <= 1'b1;
 000010                             mem_active    <= 1'b1;
 000010                             mstate        <= MS_AMO_READ;
 000010                             rd_out        <= rd_in;
 000010                             reg_write_out <= reg_write;
 000010                             valid_out     <= 1'b0;
 000010                             is_sc_q       <= 1'b0;
                                end
 009437                     end else if (valid_in && mem_write) begin
 009437                         funct3_q      <= funct3;
 009437                         amo_funct5_q  <= amo_funct5;
 009437                         rs2_data_q    <= rs2_data;
 009437                         dmem_awvalid  <= 1'b1;
 009437                         dmem_awaddr   <= eff_mem_addr;
 009437                         store_addr_q  <= eff_mem_addr;
 009437                         pc_q          <= clean_pc_in;
 009437                         dmem_wvalid   <= 1'b1;
 009437                         dmem_wdata    <= rs2_data
 009437                                          << {alu_result[2:0], 3'b000};
 009437                         dmem_wstrb    <= wstrb_from_f3(funct3)
 009437                                          << alu_result[2:0];
 009437                         dmem_bready   <= 1'b1;
 009437                         mem_active    <= 1'b1;
 009437                         mstate        <= MS_DATA;
 009437                         rd_out        <= rd_in;
 009437                         reg_write_out <= reg_write;
 009437                         result        <= alu_result;
 009437                         valid_out     <= 1'b0;
 009437                         is_sc_q       <= 1'b0;
 023711                     end else if (valid_in && mem_read) begin
 023711                         funct3_q      <= funct3;
 023711                         amo_funct5_q  <= amo_funct5;
 023711                         rs2_data_q    <= rs2_data;
 023711                         dmem_arvalid  <= 1'b1;
 023711                         dmem_araddr   <= eff_mem_addr;
 023711                         pc_q          <= clean_pc_in;
 023711                         dmem_rready   <= 1'b1;
 023711                         mem_active    <= 1'b1;
 023711                         mstate        <= MS_DATA;
 023711                         rd_out        <= rd_in;
 023711                         reg_write_out <= reg_write;
 023711                         valid_out     <= 1'b0;
 023711                         is_sc_q       <= 1'b0;
 1805685                     end else begin
 1805685                         result        <= alu_result;
 1805685                         rd_out        <= rd_in;
 1805685                         reg_write_out <= reg_write;
 1805685                         valid_out     <= valid_in;
 1805685                         mem_active    <= 1'b0;
 1805685                         is_sc_q       <= 1'b0;
                            end
                        end
 414766                 MS_DATA: begin
 029200                     if (dmem_awready) dmem_awvalid <= 1'b0;
 029191                     if (dmem_wready)  dmem_wvalid  <= 1'b0;
 033124                     if (dmem_arready) dmem_arvalid <= 1'b0;
 009564                     if (dmem_bvalid && dmem_bready) begin
 009564                         dmem_bready <= 1'b0;
 009564                         mem_active  <= 1'b0;
 009564                         mstate      <= MS_IDLE;
%000003                         if (clean_bresp[1] == 1'b1 || clean_bresp[0] == 1'b1) begin
%000003                             mem_fault       <= 1'b1;
%000003                             mem_fault_pc    <= pc_q;
%000003                             mem_fault_cause <= 64'd7;
%000003                             mem_fault_tval  <= {24'h0, store_addr_q};
%000003                             valid_out       <= 1'b0;
%000003                             reg_write_out   <= 1'b0;
 009561                         end else begin
 009561                             valid_out       <= 1'b1;
 009561                             mem_fault       <= 1'b0;
 000127                             if (is_sc_q)
 000127                                 result      <= (sc_failed || snoop_kills_sc) ? 64'd1 : 64'd0;
                                end
 023845                     end else if (dmem_rvalid && dmem_rready) begin
 023845                         dmem_rready <= 1'b0;
 023845                         mem_active  <= 1'b0;
 023845                         mstate      <= MS_IDLE;
%000008                         if (clean_rresp[1] == 1'b1 || clean_rresp[0] == 1'b1) begin
%000008                             mem_fault       <= 1'b1;
%000008                             mem_fault_pc    <= pc_q;
%000008                             mem_fault_cause <= 64'd5;
%000008                             mem_fault_tval  <= {24'h0, dmem_araddr};
%000008                             valid_out       <= 1'b0;
%000008                             reg_write_out   <= 1'b0;
 023837                         end else begin
 023837                             load_data    <= dmem_rdata;
 023837                             result       <= extend_load(
 023837                                 dmem_rdata >> {dmem_araddr[2:0], 3'b000},
 023837                                 funct3_q);
 023837                             valid_out    <= 1'b1;
 023837                             mem_fault    <= 1'b0;
                                end
                            end
                        end
 000020                 MS_AMO_READ: begin
 000010                     if (dmem_arready) dmem_arvalid <= 1'b0;
 000010                     if (dmem_rvalid) begin
 000010                         dmem_rready <= 1'b0;
 000010                         if (clean_rresp[1] == 1'b1 || clean_rresp[0] == 1'b1) begin
%000000                             mem_fault       <= 1'b1;
%000000                             mem_fault_pc    <= pc_q;
%000000                             mem_fault_cause <= 64'd5;
%000000                             mem_fault_tval  <= {24'h0, store_addr_q};
%000000                             valid_out       <= 1'b0;
%000000                             reg_write_out   <= 1'b0;
%000000                             mem_active      <= 1'b0;
%000000                             mstate          <= MS_IDLE;
 000010                         end else begin
 000010                             dmem_awvalid <= 1'b1;
 000010                             dmem_awaddr  <= store_addr_q;
 000010                             dmem_wvalid  <= 1'b1;
 000010                             dmem_bready  <= 1'b1;
 000010                             mstate       <= MS_AMO_WRITE;
        
%000003                             if (funct3_q == `AMO_W) begin
%000007                                 result     <= {{32{amo_old_32[31]}}, amo_old_32};
%000007                                 dmem_wdata <= {32'h0, amo_new_32} << {store_addr_q[2:0], 3'b000};
%000007                                 dmem_wstrb <= 8'h0F << store_addr_q[2:0];
%000003                             end else begin
%000003                                 result     <= amo_old_64;
%000003                                 dmem_wdata <= amo_new_64;
%000003                                 dmem_wstrb <= 8'hFF;
                                    end
                                end
                            end
                        end
 000110                 MS_AMO_WRITE: begin
 000010                     if (dmem_awready) dmem_awvalid <= 1'b0;
 000010                     if (dmem_wready)  dmem_wvalid  <= 1'b0;
 000010                     if (dmem_bvalid) begin
 000010                         dmem_bready <= 1'b0;
 000010                         mem_active  <= 1'b0;
 000010                         mstate      <= MS_IDLE;
 000010                         if (clean_bresp[1] == 1'b1 || clean_bresp[0] == 1'b1) begin
%000000                             mem_fault       <= 1'b1;
%000000                             mem_fault_pc    <= pc_q;
%000000                             mem_fault_cause <= 64'd7;
%000000                             mem_fault_tval  <= {24'h0, store_addr_q};
%000000                             valid_out       <= 1'b0;
%000000                             reg_write_out   <= 1'b0;
 000010                         end else begin
 000010                             valid_out       <= 1'b1;
 000010                             mem_fault       <= 1'b0;
                                end
                            end
                        end
%000000                 default: mstate <= MS_IDLE;
                    endcase
                end
            end
        endmodule
        
