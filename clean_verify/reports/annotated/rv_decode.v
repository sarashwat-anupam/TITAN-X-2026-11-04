//      // verilator_coverage annotation
        // SPDX-License-Identifier: Apache-2.0
        // SMVDU-TITAN-X SoC — RV64I Decode + Register File Stage
        `timescale 1ns/1ps
        // Shared ISA constants — single source of truth shared with execute/top.
        // (isa_constants.vh was a drifted 4-bit localparam duplicate; retired.)
        // Included at file scope, matching every other consumer of this header.
        `include "isa_pkg.vh"
        
        module rv_decode #(
            parameter [63:0] HART_ID  = 64'd0,
            parameter [63:0] FDT_ADDR = 64'h0000_0000_8002_0000
        ) (
            input  wire        clk,
            input  wire        rst_n,
            input  wire        stall,
            input  wire        flush,
            // From fetch
            input  wire [63:0] pc_in,
            input  wire [31:0] instr_in,
            input  wire        valid_in,
            input  wire        fault_in,
            input  wire [63:0] fault_cause_in,
            input  wire [63:0] fault_tval_in,
            // Writeback feedback
            input  wire [4:0]  wb_rd,
            input  wire [63:0] wb_data,
            input  wire        wb_we,
            // To execute
            output reg  [63:0] pc_out,
            output reg  [31:0] instr_out,
            output reg  [63:0] rs1_data,
            output reg  [63:0] rs2_data,
            output reg  [63:0] imm,
            output reg  [4:0]  rd,
            output reg  [4:0]  rs1_addr,
            output reg  [4:0]  rs2_addr,
            output reg  [2:0]  funct3,
            output reg  [6:0]  funct7,
            output reg  [6:0]  opcode,
            output reg  [4:0]  alu_op,
            output reg         mem_read,
            output reg         mem_write,
            output reg         reg_write,
            output reg         branch,
            output reg         jal,
            output reg         jalr,
            // SYSTEM (Zicsr + privileged simples, Phase 5 Step 5.4)
            output reg         is_csr,
            output reg  [1:0]  csr_op,      // f3[1:0]: 01 W, 10 S, 11 C
            output reg         is_ecall,
            output reg         is_ebreak,
            output reg         is_mret,
            output reg         is_sret,
            output reg         is_amo,
            output reg  [4:0]  amo_funct5,
            output reg         illegal_instr,
            output reg         fault_out,
            output reg  [63:0] fault_cause_out,
            output reg  [63:0] fault_tval_out,
            output reg         valid_out
        );
            // -------------------------------------------------------
            // RVC Compressed Instruction Decompressor
            // -------------------------------------------------------
            wire [31:0] decomp_instr;
            wire        c_illegal;
            rv_c_decoder u_rv_c_decoder (
                .c_instr      (instr_in[15:0]),
                .instr32      (decomp_instr),
                .illegal      (c_illegal)
            );
        
            wire is_compressed = (instr_in[1:0] != 2'b11);
            wire [31:0] eff_instr = is_compressed ? decomp_instr : instr_in;
        
            wire [6:0] op   = eff_instr[6:0];
            wire [4:0] r_rs1 = eff_instr[19:15];
            wire [4:0] r_rs2 = eff_instr[24:20];
            wire [4:0] r_rd  = eff_instr[11:7];
            wire [2:0] f3   = eff_instr[14:12];
            wire [6:0] f7   = eff_instr[31:25];
        
            // Immediate decode (combinational)
            reg [63:0] imm_comb;
            reg [4:0]  alu_op_comb;
            reg        mem_r_comb, mem_w_comb, reg_w_comb, br_comb, jal_comb, jalr_comb;
            reg        csr_comb, ec_comb, eb_comb, mret_comb, sret_comb, illegal_comb;
            reg        is_amo_comb;
            reg [4:0]  amo_funct5_comb;
            reg [1:0]  csrop_comb;
        
 000018     always @(*) begin
 000018         imm_comb        = 64'h0;
 000018         alu_op_comb     = `ALU_ADD;
 000018         mem_r_comb      = 1'b0;
 000018         mem_w_comb      = 1'b0;
 000018         reg_w_comb      = 1'b0;
 000018         br_comb         = 1'b0;
 000018         jal_comb        = 1'b0;
 000018         jalr_comb       = 1'b0;
 000018         csr_comb        = 1'b0;
 000018         ec_comb         = 1'b0;
 000018         eb_comb         = 1'b0;
 000018         mret_comb       = 1'b0;
 000018         sret_comb       = 1'b0;
 000018         is_amo_comb     = 1'b0;
 000018         amo_funct5_comb = 5'h0;
 000018         illegal_comb    = is_compressed ? c_illegal : 1'b0;
 000018         csrop_comb      = 2'b00;
        
 000018         case (op)
 000947             `OP_LUI: begin
 000947                 imm_comb    = {{32{eff_instr[31]}}, eff_instr[31:12], 12'h0};
 000947                 alu_op_comb = `ALU_LUI;
 000947                 reg_w_comb  = 1'b1;
                    end
 002235             `OP_AUIPC: begin
 002235                 imm_comb    = {{32{eff_instr[31]}}, eff_instr[31:12], 12'h0};
 002235                 alu_op_comb = `ALU_AUIPC;
 002235                 reg_w_comb  = 1'b1;
                    end
 001163             `OP_JAL: begin
                        // Width check: 44 sign bits + 8 + 1 + 10 + 1 = 64.
 001163                 imm_comb    = {{44{eff_instr[31]}}, eff_instr[19:12],
 001163                                eff_instr[20], eff_instr[30:21], 1'b0};
 001163                 alu_op_comb = `ALU_ADD;
 001163                 reg_w_comb  = 1'b1;
 001163                 jal_comb    = 1'b1;
                    end
 006312             `OP_JALR: begin
 006312                 imm_comb    = {{52{eff_instr[31]}}, eff_instr[31:20]};
 006312                 alu_op_comb = `ALU_ADD;
 006312                 reg_w_comb  = 1'b1;
 006312                 jalr_comb   = 1'b1;
                    end
 031523             `OP_BRANCH: begin
 031523                 imm_comb    = {{51{eff_instr[31]}}, eff_instr[31], eff_instr[7],
 031523                                eff_instr[30:25], eff_instr[11:8], 1'b0};
 031523                 br_comb     = 1'b1;
 031523                 case (f3)
 008534                     3'b000: alu_op_comb = `ALU_SUB;  // BEQ
 011675                     3'b001: alu_op_comb = `ALU_SUB;  // BNE
 001564                     3'b100: alu_op_comb = `ALU_SLT;  // BLT
 000650                     3'b101: alu_op_comb = `ALU_SLT;  // BGE
 000325                     3'b110: alu_op_comb = `ALU_SLTU; // BLTU
 000496                     3'b111: alu_op_comb = `ALU_SLTU; // BGEU
%000000                     default: alu_op_comb = `ALU_SUB;
                        endcase
                    end
 013572             `OP_LOAD: begin
 013572                 imm_comb   = {{52{eff_instr[31]}}, eff_instr[31:20]};
 013572                 mem_r_comb = 1'b1;
 013572                 reg_w_comb = 1'b1;
                    end
 006951             `OP_STORE: begin
 006951                 imm_comb   = {{52{eff_instr[31]}}, eff_instr[31:25], eff_instr[11:7]};
 006951                 mem_w_comb = 1'b1;
                    end
 300524             `OP_IMM, `OP_IMM64: begin
 300524                 imm_comb   = {{52{eff_instr[31]}}, eff_instr[31:20]};
 300524                 reg_w_comb = 1'b1;
 300524                 case (f3)
 268026                     3'b000: alu_op_comb = `ALU_ADD;
 001420                     3'b010: alu_op_comb = `ALU_SLT;
 002260                     3'b011: alu_op_comb = `ALU_SLTU;
 001171                     3'b100: alu_op_comb = `ALU_XOR;
 001976                     3'b110: alu_op_comb = `ALU_OR;
 001699                     3'b111: alu_op_comb = `ALU_AND;
 006212                     3'b001: alu_op_comb = `ALU_SLL;
 010156                     3'b101: alu_op_comb = (f7[5]) ? `ALU_SRA : `ALU_SRL;
%000000                     default: alu_op_comb = `ALU_ADD;
                        endcase
                    end
 180381             `OP_REG, `OP_REG64: begin
 180381                 reg_w_comb = 1'b1;
 045272                 if (f7 == 7'b0000001) begin
                            // M-extension. Dispatched on the FULL funct7: the old
                            // {f7[5],f3} table ignored f7[0], so every MUL/DIV
                            // decoded as its base-op twin (MUL executed as ADD,
                            // DIV as XOR).
 127525                     case (f3)
 002613                         3'b000: alu_op_comb = `ALU_MUL;
 001535                         3'b001: alu_op_comb = `ALU_MULH;
 002891                         3'b010: alu_op_comb = `ALU_MULHSU;
 001734                         3'b011: alu_op_comb = `ALU_MULHU;
 020192                         3'b100: alu_op_comb = `ALU_DIV;
 030913                         3'b101: alu_op_comb = `ALU_DIVU;
 025131                         3'b110: alu_op_comb = `ALU_REM;
 027332                         3'b111: alu_op_comb = `ALU_REMU;
%000000                         default: alu_op_comb = `ALU_ADD;
                            endcase
                        end else
 045272                 case ({f7[5], f3})
 008160                     4'b0000: alu_op_comb = `ALU_ADD;
 004474                     4'b1000: alu_op_comb = `ALU_SUB;
 000925                     4'b0010: alu_op_comb = `ALU_SLT;
 001275                     4'b0011: alu_op_comb = `ALU_SLTU;
 003486                     4'b0100: alu_op_comb = `ALU_XOR;
 003400                     4'b0110: alu_op_comb = `ALU_OR;
 002664                     4'b0111: alu_op_comb = `ALU_AND;
 004069                     4'b0001: alu_op_comb = `ALU_SLL;
 003416                     4'b0101: alu_op_comb = `ALU_SRL;
 003089                     4'b1101: alu_op_comb = `ALU_SRA;
%000000                     default: alu_op_comb = `ALU_ADD;
                        endcase
                    end
 003225             `OP_SYSTEM: begin
                        // Zicsr + privileged simples. The CSR address rides the
                        // imm field (no extra datapath). funct3[2] marks the
                        // immediate forms: rs1 field is a zimm VALUE, not an
                        // index — Block 3 substitutes {59'b0, r_rs1}.
 000604                 if (f3 == 3'b000) begin
 000604                     case (eff_instr[31:20])
%000000                         12'h000: ec_comb   = 1'b1;    // ECALL
%000000                         12'h001: eb_comb   = 1'b1;    // EBREAK
%000000                         12'h302: mret_comb = 1'b1;    // MRET
%000000                         12'h102: sret_comb = 1'b1;    // SRET
 000317                         12'h105: ;                    // WFI (handled as NOP)
%000000                         default: begin
%000000                             if (eff_instr[31:25] == 7'b0001001) begin
                                        // SFENCE.VMA (handled as valid fence)
%000000                             end else begin
%000000                                 illegal_comb = 1'b1;
                                    end
                                end
                            endcase
 000067                 end else if (f3 == 3'b100) begin
%000000                     illegal_comb = 1'b1; // reserved CSR opcode
 000067                 end else begin
 000067                     csr_comb   = 1'b1;
 000067                     csrop_comb = f3[1:0];
 000067                     imm_comb   = {52'h0, eff_instr[31:20]};
 000067                     reg_w_comb = 1'b1;            // rd <- old value (x0 discards)
                        end
                    end
 009133             `OP_FENCE: begin
 009133                 alu_op_comb = `ALU_ADD;
 009133                 reg_w_comb  = 1'b0;
                    end
 000162             `OP_AMO: begin
 000162                 is_amo_comb     = 1'b1;
 000162                 amo_funct5_comb = eff_instr[31:27];
 000162                 reg_w_comb      = 1'b1; // rd receives old value (or SC status)
 000162                 alu_op_comb     = `ALU_ADD;
 000079                 if (eff_instr[31:27] == `AMO_SC) begin
 000079                     mem_w_comb = 1'b1;
 000079                     mem_r_comb = 1'b0;
%000000                 end else if (eff_instr[31:27] == `AMO_LR) begin
 000081                     mem_r_comb = 1'b1;
 000081                     mem_w_comb = 1'b0;
%000000                 end else begin
                            // Read-modify-write atomic
%000000                     mem_r_comb = 1'b1;
%000000                     mem_w_comb = 1'b1;
                        end
                    end
%000000             `OP_LOAD_FP: begin
%000000                 imm_comb   = {{52{eff_instr[31]}}, eff_instr[31:20]};
%000000                 mem_r_comb = 1'b1;
%000000                 reg_w_comb = 1'b1;
                    end
%000000             `OP_STORE_FP: begin
%000000                 imm_comb   = {{52{eff_instr[31]}}, eff_instr[31:25], eff_instr[11:7]};
%000000                 mem_w_comb = 1'b1;
                    end
%000000             `OP_FP, `OP_FMADD, `OP_FMSUB, `OP_FNMSUB, `OP_FNMADD: begin
%000000                 reg_w_comb  = 1'b1;
%000000                 alu_op_comb = `ALU_ADD;
                    end
 000018             default: begin
 000018                 illegal_comb = 1'b1;
                    end
                endcase
            end
        
            wire zimm_form = (op == `OP_SYSTEM) && f3[2];
        
            // Register file: dedicated module (unit-tested under backend/rv_regfile),
            // written from the writeback stage through the wb_* feedback port.
            wire [63:0] rf_rs1_data, rf_rs2_data;
            rv_regfile #(
                .HART_ID  (HART_ID),
                .FDT_ADDR (FDT_ADDR)
            ) u_rf (
                .clk      (clk),
                .rst_n    (rst_n),
                .rd_addr1 (r_rs1),   .rd_data1 (rf_rs1_data),
                .rd_addr2 (r_rs2),   .rd_data2 (rf_rs2_data),
                .wr_en    (wb_we),
                .wr_addr  (wb_rd),
                .wr_data  (wb_data)
            );
        
            wire flush_buf1, flush_buf2, flush_buf3, flush_buf4, flush_buf5;
            BUFX4 u_buf1 (.A(flush), .Y(flush_buf1)); // for pc_out
            BUFX4 u_buf2 (.A(flush), .Y(flush_buf2)); // for imm
            BUFX4 u_buf3 (.A(flush), .Y(flush_buf3)); // for rs1_data
            BUFX4 u_buf4 (.A(flush), .Y(flush_buf4)); // for rs2_data
            BUFX4 u_buf5 (.A(flush), .Y(flush_buf5)); // for control bits
        
            // Pipeline register - Block 1: pc_out and instr_out
 780137     always @(posedge clk or negedge rst_n) begin
 216630         if (!rst_n) begin
 216630             pc_out    <= 64'h0;
 216630             instr_out <= 32'h0;
 013744         end else if (flush_buf1) begin
 013744             pc_out    <= 64'h0;
 013744             instr_out <= 32'h0;
 189947         end else if (!stall) begin
 269902             pc_out    <= pc_in;
 269902             instr_out <= eff_instr;
                end
            end
        
            // Pipeline register - Block 2: imm
 780137     always @(posedge clk or negedge rst_n) begin
 216630         if (!rst_n) begin
 216630             imm       <= 64'h0;
 013744         end else if (flush_buf2) begin
 013744             imm       <= 64'h0;
 189947         end else if (!stall) begin
 269902             imm       <= imm_comb;
                end
            end
        
            // Pipeline register - Block 3: rs1_data
 780137     always @(posedge clk or negedge rst_n) begin
 216630         if (!rst_n) begin
 216630             rs1_data  <= 64'h0;
 013744         end else if (flush_buf3) begin
 013744             rs1_data  <= 64'h0;
 189947         end else if (!stall) begin
 269902             rs1_data  <= (wb_we && wb_rd == r_rs1 && r_rs1 != 5'h0) ?
 269902                          wb_data :
 269902                          zimm_form ? {59'b0, r_rs1} :   // CSRR*I: field is a value
 269902                          rf_rs1_data;
                end
            end
        
            // Pipeline register - Block 4: rs2_data
 780137     always @(posedge clk or negedge rst_n) begin
 216630         if (!rst_n) begin
 216630             rs2_data  <= 64'h0;
 013744         end else if (flush_buf4) begin
 013744             rs2_data  <= 64'h0;
 189947         end else if (!stall) begin
 269902             rs2_data  <= (wb_we && wb_rd == r_rs2 && r_rs2 != 5'h0) ?
 269902                          wb_data : rf_rs2_data;
                end
            end
        
            // Pipeline register - Block 5: control signals
 780137     always @(posedge clk or negedge rst_n) begin
 216630         if (!rst_n) begin
 216630             rd        <= 5'h0;
 216630             rs1_addr  <= 5'h0;
 216630             rs2_addr  <= 5'h0;
 216630             funct3    <= 3'h0;
 216630             funct7    <= 7'h0;
 216630             opcode    <= 7'h0;
 216630             alu_op    <= 5'h0;
 216630             mem_read  <= 1'b0;
 216630             mem_write <= 1'b0;
 216630             reg_write <= 1'b0;
 216630             branch    <= 1'b0;
 216630             jal       <= 1'b0;
 216630             jalr      <= 1'b0;
 216630             is_csr        <= 1'b0;
 216630             csr_op        <= 2'b00;
 216630             is_ecall      <= 1'b0;
 216630             is_ebreak     <= 1'b0;
 216630             is_mret       <= 1'b0;
 216630             is_sret       <= 1'b0;
 216630             is_amo        <= 1'b0;
 216630             amo_funct5    <= 5'h0;
 216630             illegal_instr <= 1'b0;
 216630             fault_out       <= 1'b0;
 216630             fault_cause_out <= 64'h0;
 216630             fault_tval_out  <= 64'h0;
 216630             valid_out       <= 1'b0;
 013744         end else if (flush_buf5) begin
 013744             rd            <= 5'h0;
 013744             rs1_addr      <= 5'h0;
 013744             rs2_addr      <= 5'h0;
 013744             funct3        <= 3'h0;
 013744             funct7        <= 7'h0;
 013744             opcode        <= 7'h0;
 013744             alu_op        <= 5'h0;
 013744             mem_read      <= 1'b0;
 013744             mem_write     <= 1'b0;
 013744             reg_write     <= 1'b0;
 013744             branch        <= 1'b0;
 013744             jal           <= 1'b0;
 013744             jalr          <= 1'b0;
 013744             is_csr        <= 1'b0;
 013744             csr_op        <= 2'b00;
 013744             is_ecall      <= 1'b0;
 013744             is_ebreak     <= 1'b0;
 013744             is_mret       <= 1'b0;
 013744             is_sret       <= 1'b0;
 013744             is_amo        <= 1'b0;
 013744             amo_funct5    <= 5'h0;
 013744             illegal_instr <= 1'b0;
 013744             fault_out       <= 1'b0;
 013744             fault_cause_out <= 64'h0;
 013744             fault_tval_out  <= 64'h0;
 013744             valid_out       <= 1'b0;
 189947         end else if (!stall) begin
 269902             rd            <= r_rd;
 269902             rs1_addr      <= r_rs1;
 269902             rs2_addr      <= r_rs2;
 269902             funct3        <= f3;
 269902             funct7        <= f7;
 269902             opcode        <= op;
 269902             alu_op        <= alu_op_comb;
 269902             mem_read      <= mem_r_comb;
 269902             mem_write     <= mem_w_comb;
 269902             reg_write     <= reg_w_comb;
 269902             branch        <= br_comb;
 269902             jal           <= jal_comb;
 269902             jalr          <= jalr_comb;
 269902             is_csr        <= csr_comb;
 269902             csr_op        <= csrop_comb;
 269902             is_ecall      <= ec_comb;
 269902             is_ebreak     <= eb_comb;
 269902             is_mret       <= mret_comb;
 269902             is_sret       <= sret_comb;
 269902             is_amo        <= is_amo_comb;
 269902             amo_funct5    <= amo_funct5_comb;
 269902             illegal_instr <= valid_in && illegal_comb;
 269902             fault_out       <= valid_in && (fault_in === 1'b1);
 269902             fault_cause_out <= (valid_in && (fault_in === 1'b1)) ? fault_cause_in : 64'h0;
 269902             fault_tval_out  <= (valid_in && (fault_in === 1'b1)) ? fault_tval_in : 64'h0;
 269902             valid_out       <= valid_in;
                end
            end
        endmodule
        
