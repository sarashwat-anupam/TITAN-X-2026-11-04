//      // verilator_coverage annotation
        // SPDX-License-Identifier: Apache-2.0
        // SMVDU-TITAN-X SoC — RV64IMAC Monitor Core
        // Iteration 3: SiFive E51 equivalent
        // Target: SCL 180nm, 125-200 MHz
        // Features: 64-bit, IMAC extensions (no FPU), Bare/M-mode (no MMU), simple PMP.
        // 5-stage pipeline with tightly-integrated memory / direct AXI interface.
        `timescale 1ns/1ps
        `include "params.vh"
        `include "isa_pkg.vh"
        
        module rv_monitor_core #(
            parameter HART_ID  = 4,
            parameter RESET_PC = 64'h0000_0000_1000_0000
        ) (
            input  wire        clk,
            input  wire        rst_n,
        
            // Interrupts
            input  wire        irq_m_ext,
            input  wire        irq_m_timer,
            input  wire        irq_m_soft,
        
            // AXI4-Lite Instruction Interface
            output wire [39:0] imem_araddr,
            output wire        imem_arvalid,
            input  wire        imem_arready,
            input  wire [63:0] imem_rdata,
            input  wire        imem_rvalid,
            input  wire [1:0]  imem_rresp,
        
            // AXI4 Data Interface
            output wire        dmem_awvalid,
            input  wire        dmem_awready,
            output wire [39:0] dmem_awaddr,
            output wire [7:0]  dmem_awlen,
            output wire [2:0]  dmem_awsize,
            output wire [1:0]  dmem_awburst,
            output wire        dmem_wvalid,
            input  wire        dmem_wready,
            output wire [63:0] dmem_wdata,
            output wire [7:0]  dmem_wstrb,
            output wire        dmem_wlast,
            input  wire        dmem_bvalid,
            output wire        dmem_bready,
            input  wire [1:0]  dmem_bresp,
        
            output wire        dmem_arvalid,
            input  wire        dmem_arready,
            output wire [39:0] dmem_araddr,
            output wire [7:0]  dmem_arlen,
            output wire [2:0]  dmem_arsize,
            output wire [1:0]  dmem_arburst,
            input  wire        dmem_rvalid,
            output wire        dmem_rready,
            input  wire [63:0] dmem_rdata,
            input  wire        dmem_rlast,
            input  wire [1:0]  dmem_rresp,
        
            // Debug control
            input  wire        halt_req,
            input  wire        resume_req,
            output wire        hart_halted,
            output wire        hart_running
        );
        
            // -------------------------------------------------------
            // Core state and CSR wires
            // -------------------------------------------------------
            wire [1:0] priv_mode = `PRIV_M; // Always M-mode (Machine only)
        
            // -------------------------------------------------------
            // Pipeline Wires
            // -------------------------------------------------------
            wire        stall, flush_fe, flush_de;
            wire [63:0] branch_target;
            wire        branch_taken;
        
            // Fetch → Decode
            wire [63:0] fe_pc;
            wire [31:0] fe_instr;
            wire        fe_valid;
        
            // -------------------------------------------------------
            // Instruction Fetch FSM with Skid Buffer
            // -------------------------------------------------------
            localparam F_IDLE  = 2'd0;
            localparam F_WAIT  = 2'd1;
            localparam F_DRAIN = 2'd2;
        
            reg [1:0]  fstate;
            reg [63:0] pc_reg;
            reg [63:0] fetch_pc;
            reg        imem_arvalid_r;
            reg [31:0] fe_buf;
            reg [63:0] fe_buf_pc;
            reg        fe_buf_valid;
        
            assign imem_araddr  = {fetch_pc[39:3], 3'b000};
            assign imem_arvalid = imem_arvalid_r;
        
            wire [31:0] curr_rdata_word = fetch_pc[2] ? imem_rdata[63:32] : imem_rdata[31:0];
        
            // Output to Decode: either from skid buffer (if stalled) or direct from AXI R bus
            assign fe_pc    = fe_buf_valid ? fe_buf_pc : fetch_pc;
            assign fe_instr = fe_buf_valid ? fe_buf : curr_rdata_word;
            assign fe_valid = (fe_buf_valid ? 1'b1 : (imem_rvalid && (fstate == F_WAIT) && !stall)) && !branch_taken;
        
 780137     always @(posedge clk or negedge rst_n) begin
 216630         if (!rst_n) begin
 216630             fstate         <= F_IDLE;
 216630             pc_reg         <= RESET_PC;
 216630             fetch_pc       <= RESET_PC;
 216630             imem_arvalid_r <= 1'b0;
 216630             fe_buf         <= 32'h00000013; // NOP
 216630             fe_buf_pc      <= RESET_PC;
 216630             fe_buf_valid   <= 1'b0;
 563507         end else begin
 001792             if (branch_taken) begin
 001792                 fe_buf_valid <= 1'b0;
 001792                 pc_reg       <= branch_target;
 001792                 case (fstate)
%000000                     F_IDLE: begin
%000000                         fetch_pc       <= branch_target;
%000000                         imem_arvalid_r <= 1'b1;
%000000                         fstate         <= F_WAIT;
                            end
 001792                     F_WAIT: begin
 001792                         if (fe_buf_valid || imem_rvalid) begin
                                    // In-flight read already completed or completed this cycle.
                                    // Immediately fetch the new branch target!
%000000                             fetch_pc       <= branch_target;
%000000                             imem_arvalid_r <= 1'b1;
%000000                             fstate         <= F_WAIT;
 001792                         end else begin
                                    // Read is still in flight (or address handshake pending).
                                    // Must wait for it to complete and discard before fetching target.
 000111                             if (imem_arvalid_r && imem_arready) begin
 001681                                 imem_arvalid_r <= 1'b0;
                                    end
 001792                             fstate <= F_DRAIN;
                                end
                            end
%000000                     F_DRAIN: begin
%000000                         if (imem_arvalid_r && imem_arready) begin
%000000                             imem_arvalid_r <= 1'b0;
                                end
%000000                         if (imem_rvalid) begin
%000000                             fetch_pc       <= branch_target;
%000000                             imem_arvalid_r <= 1'b1;
%000000                             fstate         <= F_WAIT;
                                end
                            end
                        endcase
 561715             end else begin
 561715                 case (fstate)
 163253                     F_IDLE: begin
 000068                         if (!stall) begin
 163185                             fetch_pc       <= pc_reg;
 163185                             imem_arvalid_r <= 1'b1;
 163185                             fe_buf_valid   <= 1'b0;
 163185                             fstate         <= F_WAIT;
                                end
                            end
        
 393533                     F_WAIT: begin
 163177                         if (imem_arvalid_r && imem_arready) begin
 163177                             imem_arvalid_r <= 1'b0;
                                end
        
 000142                         if (fe_buf_valid) begin
%000008                             if (!stall) begin
%000008                                 fe_buf_valid <= 1'b0;
%000008                                 pc_reg       <= fe_buf_pc + 4;
%000008                                 fstate       <= F_IDLE;
                                    end
 163171                         end else if (imem_rvalid) begin
%000008                             if (!stall) begin
 163163                                 pc_reg <= fetch_pc + 4;
 163163                                 fstate <= F_IDLE;
%000008                             end else begin
%000008                                 fe_buf       <= curr_rdata_word;
%000008                                 fe_buf_pc    <= fetch_pc;
%000008                                 fe_buf_valid <= 1'b1;
                                    end
                                end
                            end
        
 004929                     F_DRAIN: begin
 000111                         if (imem_arvalid_r && imem_arready) begin
 000111                             imem_arvalid_r <= 1'b0;
                                end
 001792                         if (imem_rvalid) begin
 001792                             fetch_pc       <= pc_reg;
 001792                             imem_arvalid_r <= 1'b1;
 001792                             fstate         <= F_WAIT;
                                end
                            end
                        endcase
                    end
                end
            end
        
            assign flush_fe = branch_taken;
            assign flush_de = branch_taken;
        
            // -------------------------------------------------------
            // Decode Stage
            // -------------------------------------------------------
            wire [63:0] de_pc, de_rs1, de_rs2, de_imm;
            wire [4:0]  de_rd, de_rs1a, de_rs2a;
            wire [2:0]  de_f3;
            wire [6:0]  de_f7, de_op;
            wire [4:0]  de_aluop;
            wire [4:0]  de_amo_f5;
            wire        de_memr, de_memw, de_regw, de_branch, de_jal, de_jalr, de_is_amo, de_valid;
            wire        de_is_csr;
            wire [1:0]  de_csr_op;
            wire        de_is_ecall, de_is_ebreak, de_is_mret;
        
            wire        mon_wb_we;
            wire [4:0]  mon_wb_rd;
            wire [63:0] mon_wb_data;
        
            rv_decode u_decode (
                .clk       (clk),         .rst_n    (rst_n),
                .stall     (stall),       .flush    (flush_de),
                .pc_in     (fe_pc),       .instr_in (fe_instr),    .valid_in (fe_valid),
                .wb_rd     (mon_wb_rd),   .wb_data  (mon_wb_data), .wb_we    (mon_wb_we),
                .pc_out    (de_pc),       .rs1_data (de_rs1),      .rs2_data (de_rs2),
                .imm       (de_imm),      .rd       (de_rd),
                .rs1_addr  (de_rs1a),     .rs2_addr (de_rs2a),
                .funct3    (de_f3),       .funct7   (de_f7),       .opcode   (de_op),
                .alu_op    (de_aluop),    .mem_read (de_memr),     .mem_write(de_memw),
                .reg_write (de_regw),     .branch   (de_branch),   .jal      (de_jal),
                .jalr      (de_jalr),     .valid_out(de_valid),
                .is_csr    (de_is_csr),   .csr_op   (de_csr_op),
                .is_ecall  (de_is_ecall), .is_ebreak(de_is_ebreak),.is_mret  (de_is_mret)
            );
            assign de_amo_f5 = 5'h0;
            assign de_is_amo = 1'b0;
        
            // -------------------------------------------------------
            // Execute Stage
            // -------------------------------------------------------
            wire [63:0] ex_alures, ex_rs2, ex_lr_addr;
            wire [4:0]  ex_rd, ex_amo_f5;
            wire [2:0]  ex_f3;
            wire [6:0]  ex_op;
            wire        ex_memr, ex_memw, ex_regw, ex_is_amo, ex_valid, ex_lr_valid;
            wire        mul_div_stall;
        
            localparam M_IDLE  = 3'd0;
            localparam M_RWAIT = 3'd1;
            localparam M_WRESP = 3'd2;
            localparam M_DONE  = 3'd3;
            reg [2:0]  mstate;
        
            wire stall_mem = (mstate == M_RWAIT) || (mstate == M_WRESP) || ((mstate == M_IDLE) && ex_valid && (ex_memr || ex_memw));
            /* verilator lint_off UNOPTFLAT */
            wire stall_ex = stall_mem || halt_req;
            /* verilator lint_on UNOPTFLAT */
            assign stall  = mul_div_stall || stall_ex;
        
            rv_execute #(
                .HART_ID(HART_ID)
            ) u_execute (
                .clk          (clk),        .rst_n        (rst_n),
                .stall        (stall_ex),   .flush        (flush_de),
                .pc_in        (de_pc),      .rs1_data     (de_rs1),    .rs2_data    (de_rs2),
                .imm          (de_imm),     .rd_in        (de_rd),
                .rs1_addr     (de_rs1a),    .rs2_addr     (de_rs2a),
                .funct3       (de_f3),      .funct7       (de_f7),     .opcode      (de_op),
                .alu_op       (de_aluop),   .mem_read     (de_memr),   .mem_write   (de_memw),
                .reg_write    (de_regw),    .branch       (de_branch), .jal         (de_jal),
                .jalr         (de_jalr),    .is_amo       (de_is_amo), .amo_funct5  (de_amo_f5),
                .is_csr       (de_is_csr),  .csr_op       (de_csr_op),
                .is_ecall     (de_is_ecall),.is_ebreak    (de_is_ebreak), .is_mret  (de_is_mret),
                .irq_m_ext    (irq_m_ext),  .irq_m_timer  (irq_m_timer), .irq_m_soft (irq_m_soft),
                .valid_in     (de_valid),
                .fwd_mem_data (64'h0),      .fwd_mem_valid(1'b0),      .fwd_mem_rd  (5'h0),
                .fwd_wb_data  (mon_wb_data),.fwd_wb_valid (mon_wb_we), .fwd_wb_rd   (mon_wb_rd),
                .fpu_result   (64'h0),      .fpu_valid    (1'b0),      .fpu_done    (1'b1), // No FPU
                .alu_result   (ex_alures),  .rs2_out      (ex_rs2),
                .rd_out       (ex_rd),      .funct3_out   (ex_f3),     .opcode_out  (ex_op),
                .mem_read_out (ex_memr),    .mem_write_out(ex_memw),   .reg_write_out(ex_regw),
                .is_amo_out   (ex_is_amo),  .amo_funct5_out(ex_amo_f5),
                .valid_out    (ex_valid),
                .mul_div_stall(mul_div_stall),
                .branch_taken (branch_taken), .branch_target(branch_target),
                .lr_addr      (ex_lr_addr), .lr_valid     (ex_lr_valid)
            );
        
            // -------------------------------------------------------
            // Data Memory Controller (AXI4 Load / Store)
            // -------------------------------------------------------
            reg        dmem_arvalid_r;
            reg        dmem_awvalid_r;
            reg        dmem_wvalid_r;
            reg [63:0] dmem_rdata_latched;
            reg [63:0] mem_addr_latched;
            reg [63:0] mem_wdata_latched;
            reg [2:0]  mem_f3_latched;
            reg        mem_regw_latched;
            reg [4:0]  mem_rd_latched;
            reg        mem_is_load;
        
            // Load formatting logic
            wire [2:0]  b_offset = mem_addr_latched[2:0];
            wire [7:0]  lb_data  = (dmem_rdata_latched >> (b_offset * 8)) & 8'hFF;
            wire [15:0] lh_data  = (dmem_rdata_latched >> (b_offset[2:1] * 16)) & 16'hFFFF;
            wire [31:0] lw_data  = (dmem_rdata_latched >> (b_offset[2] * 32)) & 32'hFFFF_FFFF;
        
            reg [63:0] formatted_load_data;
 000018     always @(*) begin
 000018         case (mem_f3_latched)
 449690             3'b000: formatted_load_data = {{56{lb_data[7]}}, lb_data};        // LB
%000000             3'b001: formatted_load_data = {{48{lh_data[15]}}, lh_data};      // LH
%000007             3'b010: formatted_load_data = {{32{lw_data[31]}}, lw_data};      // LW
 330458             3'b011: formatted_load_data = dmem_rdata_latched;                 // LD
%000000             3'b100: formatted_load_data = {56'h0, lb_data};                   // LBU
%000000             3'b101: formatted_load_data = {48'h0, lh_data};                   // LHU
%000000             3'b110: formatted_load_data = {32'h0, lw_data};                   // LWU
%000000             default: formatted_load_data = dmem_rdata_latched;
                endcase
            end
        
            // Store formatting logic
            wire [2:0]  st_offset = mem_addr_latched[2:0];
            reg [7:0]   st_strb;
            reg [63:0]  st_data;
 000018     always @(*) begin
 000018         case (mem_f3_latched)
 449690             3'b000: begin // SB
 449690                 st_strb = 8'h01 << st_offset;
 449690                 st_data = {8{mem_wdata_latched[7:0]}};
                    end
%000000             3'b001: begin // SH
%000000                 st_strb = 8'h03 << (st_offset[2:1] * 2);
%000000                 st_data = {4{mem_wdata_latched[15:0]}};
                    end
%000007             3'b010: begin // SW
%000007                 st_strb = 8'h0F << (st_offset[2] * 4);
%000007                 st_data = {2{mem_wdata_latched[31:0]}};
                    end
 330458             3'b011: begin // SD
 330458                 st_strb = 8'hFF;
 330458                 st_data = mem_wdata_latched;
                    end
%000000             default: begin
%000000                 st_strb = 8'hFF;
%000000                 st_data = mem_wdata_latched;
                    end
                endcase
            end
        
            assign dmem_arvalid = dmem_arvalid_r;
            assign dmem_araddr  = {mem_addr_latched[39:3], 3'b000};
            assign dmem_arlen   = 8'h0;
            assign dmem_arsize  = 3'h3;
            assign dmem_arburst = 2'b01;
            assign dmem_rready  = 1'b1;
        
            assign dmem_awvalid = dmem_awvalid_r;
            assign dmem_awaddr  = {mem_addr_latched[39:3], 3'b000};
            assign dmem_awlen   = 8'h0;
            assign dmem_awsize  = 3'h3;
            assign dmem_awburst = 2'b01;
        
            assign dmem_wvalid  = dmem_wvalid_r;
            assign dmem_wdata   = st_data;
            assign dmem_wstrb   = st_strb;
            assign dmem_wlast   = 1'b1;
            assign dmem_bready  = 1'b1;
        
 780137     always @(posedge clk or negedge rst_n) begin
 216630         if (!rst_n) begin
 216630             mstate             <= M_IDLE;
 216630             dmem_arvalid_r     <= 1'b0;
 216630             dmem_awvalid_r     <= 1'b0;
 216630             dmem_wvalid_r      <= 1'b0;
 216630             dmem_rdata_latched <= 64'h0;
 216630             mem_addr_latched   <= 64'h0;
 216630             mem_wdata_latched  <= 64'h0;
 216630             mem_f3_latched     <= 3'h0;
 216630             mem_regw_latched   <= 1'b0;
 216630             mem_rd_latched     <= 5'h0;
 216630             mem_is_load        <= 1'b0;
 563507         end else begin
 563507             case (mstate)
 562840                 M_IDLE: begin
 000010                     if (ex_valid && ex_memr) begin
 000010                         mem_addr_latched <= ex_alures;
 000010                         mem_f3_latched   <= ex_f3;
 000010                         mem_regw_latched <= ex_regw;
 000010                         mem_rd_latched   <= ex_rd;
 000010                         mem_is_load      <= 1'b1;
 000010                         dmem_arvalid_r   <= 1'b1;
 000010                         mstate           <= M_RWAIT;
 000018                     end else if (ex_valid && ex_memw) begin
 000018                         mem_addr_latched  <= ex_alures;
 000018                         mem_wdata_latched <= ex_rs2;
 000018                         mem_f3_latched    <= ex_f3;
 000018                         mem_regw_latched  <= 1'b0;
 000018                         mem_rd_latched    <= 5'h0;
 000018                         mem_is_load       <= 1'b0;
 000018                         dmem_awvalid_r    <= 1'b1;
 000018                         dmem_wvalid_r     <= 1'b1;
 000018                         mstate            <= M_WRESP;
 562812                     end else begin
 562812                         mem_is_load      <= 1'b0;
                            end
                        end
        
 000368                 M_RWAIT: begin
 000010                     if (dmem_arvalid_r && dmem_arready) begin
 000010                         dmem_arvalid_r <= 1'b0;
                            end
 000010                     if (dmem_rvalid) begin
 000010                         dmem_rdata_latched <= dmem_rdata;
 000010                         mstate             <= M_DONE;
                            end
                        end
        
 000271                 M_WRESP: begin
 000018                     if (dmem_awvalid_r && dmem_awready) dmem_awvalid_r <= 1'b0;
 000018                     if (dmem_wvalid_r && dmem_wready)   dmem_wvalid_r  <= 1'b0;
 000018                     if (dmem_bvalid) begin
 000018                         mstate <= M_DONE;
                            end
                        end
        
 000028                 M_DONE: begin
 000028                     mstate <= M_IDLE;
                        end
                    endcase
                end
            end
        
            // Writeback mux: load results arrive in M_DONE
            assign mon_wb_we   = (mstate == M_DONE && mem_is_load) ? (mem_regw_latched && (mem_rd_latched != 5'h0)) :
                                 (ex_valid && ex_regw && !ex_memr && (ex_rd != 5'h0));
            assign mon_wb_rd   = (mstate == M_DONE && mem_is_load) ? mem_rd_latched : ex_rd;
            assign mon_wb_data = (mstate == M_DONE && mem_is_load) ? formatted_load_data : ex_alures;
        
            assign hart_halted = halt_req;
            assign hart_running = !halt_req;
        
        endmodule
        
