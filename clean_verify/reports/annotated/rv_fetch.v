//      // verilator_coverage annotation
        // SPDX-License-Identifier: Apache-2.0
        // SMVDU-Titan-X SoC — RISC-V Instruction Fetch Stage (RV64I)
        //
        // Single-outstanding AXI-Lite fetch FSM with redirect-safe teardown:
        // on a redirect the unit first drains any orphaned transaction belonging
        // to the abandoned stream (an unaccepted AR, or an R beat already owed)
        // before issuing the redirected fetch. Without that drain the stale
        // instruction would be paired with the NEW pc_out — silent execution of
        // the wrong instruction at the wrong architectural address.
        `timescale 1ns/1ps
        `include "params.vh"
        
        module rv_fetch #(
            parameter RESET_PC     = `RESET_PC,
            parameter ENABLE_DRAIN = 1,
            parameter ENABLE_RVC   = 0
        ) (
            input  wire        clk,
            input  wire        rst_n,
            // Hazard/control
            input  wire        stall,
            input  wire        flush,
            input  wire        branch_taken,
            input  wire [63:0] branch_target,
            // Instruction memory (AXI-Lite AR/R)
            output reg  [63:0] imem_addr,
            output reg         imem_arvalid,
            input  wire        imem_arready,
            input  wire [31:0] imem_rdata,
            input  wire        imem_rvalid,
            output wire        imem_rready,
            input  wire [1:0]  imem_rresp,
            // MMU Translation fault
            input  wire        mmu_page_fault,
            input  wire [63:0] mmu_fault_va,
            // PMP Access fault
            input  wire        pmp_fault,
            // To decode stage
            output reg  [63:0] pc_out,
            output reg  [31:0] instr_out,
            output reg         valid_out,
            output reg         fault_out,
            output reg  [63:0] fault_cause_out,
            output reg  [63:0] fault_tval_out
        );
            reg [63:0] pc;
            reg [15:0] half_buf;
            reg        half_buf_valid;
        
            // Fetch FSM
            localparam F_REQ   = 2'd1;
            localparam F_WAIT  = 2'd2;
            localparam F_FLUSH = 2'd3;   // draining an orphaned transaction
            reg [1:0] fstate;
            reg       pending_r;         // AR accepted; matching R beat still owed
        
            // Ready for the R beat while waiting for data OR while swallowing an
            // orphan after a redirect — and never during a global stall (a
            // compliant slave holds rvalid/rdata stable until we accept).
            assign imem_rready = (fstate == F_WAIT || fstate == F_FLUSH) && !stall;
        
            wire redirect = flush || branch_taken;
        
            // Transaction-completion pulses. r_fire doubles as "the R beat is being
            // consumed THIS edge" (rready is high by construction in both wait
            // states), which is what makes the redirect classification below exact.
            wire ar_fire = imem_arvalid && imem_arready;
            wire r_fire  = !stall && imem_rvalid;
        
 3120548     always @(posedge clk or negedge rst_n) begin
 866520         if (!rst_n) begin
 866520             pc              <= RESET_PC;
 866520             imem_addr       <= RESET_PC;
 866520             imem_arvalid    <= 1'b0;
 866520             pc_out          <= 64'h0;
 866520             instr_out       <= 32'h0000_0013; // NOP
 866520             valid_out       <= 1'b0;
 866520             fault_out       <= 1'b0;
 866520             fault_cause_out <= 64'h0;
 866520             fault_tval_out  <= 64'h0;
 866520             fstate          <= F_REQ;
 866520             pending_r       <= 1'b0;
 866520             half_buf        <= 16'h0;
 866520             half_buf_valid  <= 1'b0;
 2254028         end else begin
 2254028             case (fstate)
 746027                 F_REQ: begin
%000008                     if (redirect) begin
%000008                         valid_out       <= 1'b0;
%000008                         fault_out       <= 1'b0;
%000008                         fault_cause_out <= 64'h0;
%000008                         fault_tval_out  <= 64'h0;
%000008                         half_buf_valid  <= 1'b0;
%000008                         pc              <= branch_target;
%000008                         imem_addr       <= ENABLE_RVC ? {branch_target[63:2], 2'b00} : branch_target;
%000008                         imem_arvalid    <= 1'b1;
%000008                         fstate          <= F_WAIT;
 335178                     end else if (!stall) begin
 335178                         valid_out       <= 1'b0;
 335178                         fault_out       <= 1'b0;
 335178                         fault_cause_out <= 64'h0;
 335178                         fault_tval_out  <= 64'h0;
 023430                         if (ENABLE_RVC && half_buf_valid && (half_buf[1:0] != 2'b11)) begin
                                    // Fast path: consume the buffered 16-bit compressed instruction directly
 023430                             pc_out          <= pc;
 023430                             instr_out       <= {16'h0000, half_buf};
 023430                             valid_out       <= 1'b1;
 023430                             pc              <= pc + 64'd2;
 023430                             half_buf_valid  <= 1'b0;
 023430                             fstate          <= F_REQ;
 311748                         end else begin
 311748                             imem_addr       <= ENABLE_RVC ? ({pc[63:2], 2'b00} + (half_buf_valid ? 64'd4 : 64'd0)) : pc;
 311748                             imem_arvalid    <= 1'b1;
 311748                             fstate          <= F_WAIT;
                                end
                            end
                        end
 1508001                 F_WAIT: begin
%000000                     if (mmu_page_fault) begin
%000000                         valid_out       <= 1'b1;
%000000                         fault_out       <= 1'b1;
%000000                         fault_cause_out <= 64'd12; // Instruction page fault
%000000                         fault_tval_out  <= mmu_fault_va;
%000000                         instr_out       <= 32'h0000_0013;
%000000                         imem_arvalid    <= 1'b0;
%000000                         pending_r       <= 1'b0;
%000000                         half_buf_valid  <= 1'b0;
%000000                         fstate          <= F_REQ;
 1508001                     end else if (pmp_fault) begin
%000000                         valid_out       <= 1'b1;
%000000                         fault_out       <= 1'b1;
%000000                         fault_cause_out <= 64'd1;  // Instruction access fault
%000000                         fault_tval_out  <= pc;
%000000                         instr_out       <= 32'h0000_0013;
%000000                         imem_arvalid    <= 1'b0;
%000000                         pending_r       <= 1'b0;
%000000                         half_buf_valid  <= 1'b0;
%000000                         fstate          <= F_REQ;
 1508001                     end else begin
                                // Track AR completion for the outstanding request
 417281                         if (ar_fire) begin
 417281                             imem_arvalid <= 1'b0;
 417281                             pending_r    <= 1'b1;
                                end
 093666                         if (redirect) begin
 093666                             valid_out       <= 1'b0;
 093666                             fault_out       <= 1'b0;
 093666                             fault_cause_out <= 64'h0;
 093666                             fault_tval_out  <= 64'h0;
 093666                             half_buf_valid  <= 1'b0;
 093666                             pc              <= branch_target;
 093666                         if (ENABLE_DRAIN && ((imem_arvalid && !ar_fire) ||
                                    ((pending_r || ar_fire) && !r_fire)))
%000000                             fstate <= F_FLUSH;
 093666                         else begin
 093666                             pending_r    <= 1'b0;
 093666                             imem_addr    <= ENABLE_RVC ? {branch_target[63:2], 2'b00} : branch_target;
 093666                             imem_arvalid <= 1'b1;
 093666                             fstate       <= F_WAIT;
                                end
 323597                     end else if (!stall && pending_r && imem_rvalid) begin
 323597                         pc_out <= pc;
%000000                         if (imem_rresp != 2'b00) begin
%000000                             instr_out       <= 32'h0000_0013; // NOP
%000000                             valid_out       <= 1'b1;
%000000                             fault_out       <= 1'b1;
%000000                             fault_cause_out <= 64'd1;         // Instruction access fault
%000000                             fault_tval_out  <= pc;
%000000                             pc              <= pc + 64'd4;
%000000                             half_buf_valid  <= 1'b0;
%000000                             pending_r       <= 1'b0;
%000000                             fstate          <= F_REQ;
 080873                         end else if (ENABLE_RVC && half_buf_valid) begin
                                    // Spanning 32-bit instruction: lower half from buffer, upper half from imem_rdata[15:0]
 080873                             instr_out       <= {imem_rdata[15:0], half_buf};
 080873                             valid_out       <= 1'b1;
 080873                             fault_out       <= 1'b0;
 080873                             fault_cause_out <= 64'h0;
 080873                             fault_tval_out  <= 64'h0;
 080873                             pc              <= pc + 64'd4;
 080873                             half_buf        <= imem_rdata[31:16];
 080873                             half_buf_valid  <= 1'b1;
 080873                             pending_r       <= 1'b0;
 080873                             fstate          <= F_REQ;
 230345                         end else if (ENABLE_RVC && (pc[1] == 1'b0)) begin
 086176                             if (imem_rdata[1:0] != 2'b11) begin
                                        // 16-bit compressed instruction at word lower half
 086176                                 instr_out       <= {16'h0000, imem_rdata[15:0]};
 086176                                 valid_out       <= 1'b1;
 086176                                 fault_out       <= 1'b0;
 086176                                 fault_cause_out <= 64'h0;
 086176                                 fault_tval_out  <= 64'h0;
 086176                                 pc              <= pc + 64'd2;
 086176                                 half_buf        <= imem_rdata[31:16];
 086176                                 half_buf_valid  <= 1'b1;
 144169                             end else begin
                                        // 32-bit regular instruction
 144169                                 instr_out       <= imem_rdata;
 144169                                 valid_out       <= 1'b1;
 144169                                 fault_out       <= 1'b0;
 144169                                 fault_cause_out <= 64'h0;
 144169                                 fault_tval_out  <= 64'h0;
 144169                                 pc              <= pc + 64'd4;
 144169                                 half_buf_valid  <= 1'b0;
                                    end
 230345                             pending_r <= 1'b0;
 230345                             fstate    <= F_REQ;
%000000                         end else if (ENABLE_RVC && (pc[1] == 1'b1)) begin
                                    // pc[1] == 1'b1: instruction begins at imem_rdata[31:16]
 000485                             if (imem_rdata[17:16] != 2'b11) begin
                                        // 16-bit compressed instruction at upper half
 000485                                 instr_out       <= {16'h0000, imem_rdata[31:16]};
 000485                                 valid_out       <= 1'b1;
 000485                                 fault_out       <= 1'b0;
 000485                                 fault_cause_out <= 64'h0;
 000485                                 fault_tval_out  <= 64'h0;
 000485                                 pc              <= pc + 64'd2;
 000485                                 half_buf_valid  <= 1'b0;
 000485                                 pending_r       <= 1'b0;
 000485                                 fstate          <= F_REQ;
 011894                             end else begin
                                        // 32-bit uncompressed instruction starting at upper half: buffer and fetch next word
 011894                                 half_buf        <= imem_rdata[31:16];
 011894                                 half_buf_valid  <= 1'b1;
 011894                                 imem_addr       <= {pc[63:2], 2'b00} + 64'd4;
 011894                                 imem_arvalid    <= 1'b1;
 011894                                 pending_r       <= 1'b0;
                                        // Remain in F_WAIT for next word
                                    end
%000000                         end else begin
                                    // Standard uncompressed fetch (ENABLE_RVC == 0)
%000000                             instr_out       <= imem_rdata;
%000000                             valid_out       <= 1'b1;
%000000                             fault_out       <= 1'b0;
%000000                             fault_cause_out <= 64'h0;
%000000                             fault_tval_out  <= 64'h0;
%000000                             pc              <= pc + 64'd4;
%000000                             half_buf_valid  <= 1'b0;
%000000                             pending_r       <= 1'b0;
%000000                             fstate          <= F_REQ;
                                end
                            end
                            end
                        end
%000000                 F_FLUSH: begin
%000000                     valid_out       <= 1'b0;
%000000                     fault_out       <= 1'b0;
%000000                     fault_cause_out <= 64'h0;
%000000                     fault_tval_out  <= 64'h0;
%000000                     half_buf_valid  <= 1'b0;
                            // Latest target wins if another redirect arrives mid-drain.
%000000                     if (redirect) begin
%000000                         pc <= branch_target;
%000000                         if (!ENABLE_DRAIN) begin
%000000                             imem_addr    <= ENABLE_RVC ? {branch_target[63:2], 2'b00} : branch_target;
%000000                             imem_arvalid <= 1'b1;
%000000                             pending_r    <= 1'b0;
%000000                             fstate       <= F_WAIT;
                                end
                            end
%000000                     if (imem_arvalid) begin
                                // Old request still waiting for its AR handshake:
                                // hold address/arvalid stable until accepted.
%000000                         if (ar_fire) begin
%000000                             imem_arvalid <= 1'b0;
%000000                             pending_r    <= 1'b1;
                                end
%000000                     end else if (pending_r) begin
%000000                         if (r_fire)
%000000                             pending_r <= 1'b0;    // orphan swallowed
%000000                     end else begin
%000000                         imem_addr    <= ENABLE_RVC ? {pc[63:2], 2'b00} : pc;
%000000                         imem_arvalid <= 1'b1;
%000000                         fstate       <= F_WAIT;
                            end
                        end
%000000                 default: fstate <= F_REQ;
                    endcase
        `ifndef SYNTHESIS
 2254028             if ($time > 0) begin
                        // Check if in window
                    end
        `endif
                end
            end
        endmodule
        
