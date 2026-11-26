//      // verilator_coverage annotation
        // SPDX-License-Identifier: Apache-2.0
        // SMVDU-TITAN-X SoC — IEEE 754-2008 Floating Point Unit (F + D extensions)
        // RV64 FPU Coprocessor — IEEE-754 Single & Double Precision Datapath
        // Target: SCL 180nm, 125-200 MHz
        // Supports: FADD, FSUB, FMUL, FDIV, FSQRT, FMADD/FMSUB/FNMSUB/FNMADD,
        //           FCVT, FMIN/FMAX, FCMP, FMV, FSGNJ
        // Rounding modes: RNE, RTZ, RDN, RUP, RMM, DYN
        `timescale 1ns/1ps
        `include "params.vh"
        `include "isa_pkg.vh"
        
        module rv_fpu (
            input  wire        clk,
            input  wire        rst_n,
            input  wire [6:0]  opcode,      // Opcode [6:0] for FMADD/FMSUB/FNMSUB/FNMADD
            input  wire [4:0]  fop,         // FP operation code [31:27]
            input  wire [1:0]  fmt,         // Precision: 00=SP, 01=DP
            input  wire [2:0]  rm,          // Rounding mode
            input  wire [4:0]  rs2,         // rs2 field [24:20] for FCVT signedness and int width
            input  wire        valid_in,
            input  wire [63:0] fp_src1,
            input  wire [63:0] fp_src2,
            input  wire [63:0] fp_src3,     // rs3 for FMA
            input  wire [63:0] int_src,     // Integer source for FCVT.S/D.W/WU/L/LU
            input  wire [2:0]  frm_csr,
            output reg  [63:0] fp_result,
            output wire        result_valid,
            output reg  [4:0]  fflags,      // Exception flags: NV,DZ,OF,UF,NX
            output wire        fpu_done,
            output reg  [63:0] int_result,
            output reg         int_result_valid
        );
        
            assign fpu_done     = valid_in;
            assign result_valid = valid_in;
        
            // Effective rounding mode
            wire [2:0] eff_rm = (rm == `RM_DYN) ? frm_csr : rm;
        
            // Canonical constants
            localparam [31:0] SP_QNAN = 32'h7FC0_0000;
            localparam [63:0] DP_QNAN = 64'h7FF8_0000_0000_0000;
        
            // -------------------------------------------------------
            // Classification & Unpacking
            // -------------------------------------------------------
            // Single Precision
            wire        sp_sgn1 = fp_src1[31];
            wire [7:0]  sp_exp1 = fp_src1[30:23];
            wire [22:0] sp_man1 = fp_src1[22:0];
            wire        sp_nan1 = (sp_exp1 == 8'hFF) && (sp_man1 != 23'h0);
            wire        sp_inf1 = (sp_exp1 == 8'hFF) && (sp_man1 == 23'h0);
            wire        sp_zero1= (sp_exp1 == 8'h0)  && (sp_man1 == 23'h0);
        
            wire        sp_sgn2 = fp_src2[31];
            wire [7:0]  sp_exp2 = fp_src2[30:23];
            wire [22:0] sp_man2 = fp_src2[22:0];
            wire        sp_nan2 = (sp_exp2 == 8'hFF) && (sp_man2 != 23'h0);
            wire        sp_inf2 = (sp_exp2 == 8'hFF) && (sp_man2 == 23'h0);
            wire        sp_zero2= (sp_exp2 == 8'h0)  && (sp_man2 == 23'h0);
        
            // Double Precision
            wire        dp_sgn1 = fp_src1[63];
            wire [10:0] dp_exp1 = fp_src1[62:52];
            wire [51:0] dp_man1 = fp_src1[51:0];
            wire        dp_nan1 = (dp_exp1 == 11'h7FF) && (dp_man1 != 52'h0);
            wire        dp_inf1 = (dp_exp1 == 11'h7FF) && (dp_man1 == 52'h0);
            wire        dp_zero1= (dp_exp1 == 11'h0)   && (dp_man1 == 52'h0);
        
            wire        dp_sgn2 = fp_src2[63];
            wire [10:0] dp_exp2 = fp_src2[62:52];
            wire [51:0] dp_man2 = fp_src2[51:0];
            wire        dp_nan2 = (dp_exp2 == 11'h7FF) && (dp_man2 != 52'h0);
            wire        dp_inf2 = (dp_exp2 == 11'h7FF) && (dp_man2 == 52'h0);
            wire        dp_zero2= (dp_exp2 == 11'h0)   && (dp_man2 == 52'h0);
        
            // -------------------------------------------------------
            // Comparisons
            // -------------------------------------------------------
            wire sp_eq = ((fp_src1[31:0] == fp_src2[31:0]) || (sp_zero1 && sp_zero2)) && !sp_nan1 && !sp_nan2;
            wire sp_lt = !sp_nan1 && !sp_nan2 && (
                            (sp_zero1 && sp_zero2) ? 1'b0 :
                            (sp_sgn1 != sp_sgn2) ? sp_sgn1 :
                            sp_sgn1 ? (fp_src1[30:0] > fp_src2[30:0]) :
                                      (fp_src1[30:0] < fp_src2[30:0])
                         );
            wire sp_le = sp_lt || sp_eq;
        
            wire dp_eq = ((fp_src1 == fp_src2) || (dp_zero1 && dp_zero2)) && !dp_nan1 && !dp_nan2;
            wire dp_lt = !dp_nan1 && !dp_nan2 && (
                            (dp_zero1 && dp_zero2) ? 1'b0 :
                            (dp_sgn1 != dp_sgn2) ? dp_sgn1 :
                            dp_sgn1 ? (fp_src1[62:0] > fp_src2[62:0]) :
                                      (fp_src1[62:0] < fp_src2[62:0])
                         );
            wire dp_le = dp_lt || dp_eq;
        
            // FMIN / FMAX
            wire [31:0] sp_fmin = (sp_nan1 && sp_nan2) ? SP_QNAN :
                                  sp_nan1 ? fp_src2[31:0] :
                                  sp_nan2 ? fp_src1[31:0] :
                                  sp_lt ? fp_src1[31:0] : fp_src2[31:0];
            wire [31:0] sp_fmax = (sp_nan1 && sp_nan2) ? SP_QNAN :
                                  sp_nan1 ? fp_src2[31:0] :
                                  sp_nan2 ? fp_src1[31:0] :
                                  sp_lt ? fp_src2[31:0] : fp_src1[31:0];
        
            wire [63:0] dp_fmin = (dp_nan1 && dp_nan2) ? DP_QNAN :
                                  dp_nan1 ? fp_src2 :
                                  dp_nan2 ? fp_src1 :
                                  dp_lt ? fp_src1 : fp_src2;
            wire [63:0] dp_fmax = (dp_nan1 && dp_nan2) ? DP_QNAN :
                                  dp_nan1 ? fp_src2 :
                                  dp_nan2 ? fp_src1 :
                                  dp_lt ? fp_src2 : fp_src1;
        
            // -------------------------------------------------------
            // Helper Functions: Integer <-> Float Conversions
            // -------------------------------------------------------
 000944     function [63:0] int_to_dp;
                input [63:0] in_src;
                input [4:0]  in_rs2;
                reg          is_signed;
                reg [63:0]   eff_val;
                reg          sgn;
                reg [63:0]   mag;
                reg [5:0]    lz;
                reg          found;
                reg [10:0]   exp;
                reg [51:0]   man;
                integer      k;
 000944         begin
 000944             is_signed = ~in_rs2[0];
 000329             if (in_rs2[1] == 1'b0)
 000615                 eff_val = is_signed ? {{32{in_src[31]}}, in_src[31:0]} : {32'h0, in_src[31:0]};
                    else
 000329                 eff_val = in_src;
        
 000087             if (is_signed && eff_val[63]) begin
 000087                 sgn = 1'b1;
 000087                 mag = -eff_val;
 000857             end else begin
 000857                 sgn = 1'b0;
 000857                 mag = eff_val;
                    end
        
 000372             if (mag == 64'd0) begin
 000372                 int_to_dp = 64'd0;
 000572             end else begin
 000572                 lz = 6'd0;
 000572                 found = 1'b0;
 000572                 for (k = 0; k < 64; k = k + 1) begin
 000572                     if (mag[63 - k] && !found) begin
 000572                         lz = k[5:0];
 000572                         found = 1'b1;
                            end
                        end
 000572                 exp = 11'd1023 + (11'd63 - {5'd0, lz});
%000004                 if ((6'd63 - lz) <= 6'd52)
 000568                     man = (mag << (6'd52 - (6'd63 - lz))) & 52'hFFFFFFFFFFFFF;
                        else
%000004                     man = (mag >> ((6'd63 - lz) - 6'd52)) & 52'hFFFFFFFFFFFFF;
 000572                 int_to_dp = {sgn, exp, man};
                    end
                end
            endfunction
        
 000325     function [63:0] int_to_sp;
                input [63:0] in_src;
                input [4:0]  in_rs2;
                reg          is_signed;
                reg [63:0]   eff_val;
                reg          sgn;
                reg [63:0]   mag;
                reg [5:0]    lz;
                reg          found;
                reg [7:0]    exp;
                reg [22:0]   man;
                integer      k;
 000325         begin
 000325             is_signed = ~in_rs2[0];
 000075             if (in_rs2[1] == 1'b0)
 000250                 eff_val = is_signed ? {{32{in_src[31]}}, in_src[31:0]} : {32'h0, in_src[31:0]};
                    else
 000075                 eff_val = in_src;
        
 000100             if (is_signed && eff_val[63]) begin
 000100                 sgn = 1'b1;
 000100                 mag = -eff_val;
 000225             end else begin
 000225                 sgn = 1'b0;
 000225                 mag = eff_val;
                    end
        
 000147             if (mag == 64'd0) begin
 000147                 int_to_sp = {32'hFFFF_FFFF, 32'd0};
 000178             end else begin
 000178                 lz = 6'd0;
 000178                 found = 1'b0;
 000178                 for (k = 0; k < 64; k = k + 1) begin
 000178                     if (mag[63 - k] && !found) begin
 000178                         lz = k[5:0];
 000178                         found = 1'b1;
                            end
                        end
 000178                 exp = 8'd127 + (8'd63 - {2'd0, lz});
%000003                 if ((6'd63 - lz) <= 6'd23)
 000175                     man = (mag << (6'd23 - (6'd63 - lz))) & 23'h7FFFFF;
                        else
%000003                     man = (mag >> ((6'd63 - lz) - 6'd23)) & 23'h7FFFFF;
 000178                 int_to_sp = {32'hFFFF_FFFF, sgn, exp, man};
                    end
                end
            endfunction
        
 002702     function [63:0] dp_to_int;
                input [63:0] in_fp;
                input [4:0]  in_rs2;
                reg          sgn;
                reg [10:0]   exp;
                reg [51:0]   man;
                reg [10:0]   sh;
                reg [52:0]   sig;
                reg [63:0]   mag;
                reg [63:0]   res;
 002702         begin
 002702             sgn = in_fp[63];
 002702             exp = in_fp[62:52];
 002702             man = in_fp[51:0];
 002702             sig = {1'b1, man};
%000003             if (exp < 11'd1023) begin
 002699                 dp_to_int = 64'd0;
%000003             end else begin
%000003                 sh = exp - 11'd1023;
%000003                 if (sh <= 11'd52)
%000003                     mag = {11'd0, sig} >> (11'd52 - sh);
%000000                 else if (sh < 11'd63)
%000000                     mag = {11'd0, sig} << (sh - 11'd52);
                        else
%000000                     mag = 64'h7FFFFFFFFFFFFFFF;
%000003                 res = sgn ? -mag : mag;
%000003                 if (in_rs2[1] == 1'b0)
%000000                     dp_to_int = in_rs2[0] ? {32'h0, res[31:0]} : {{32{res[31]}}, res[31:0]};
                        else
%000003                     dp_to_int = res;
                    end
                end
            endfunction
        
 000250     function [63:0] sp_to_int;
                input [63:0] in_fp;
                input [4:0]  in_rs2;
                reg          sgn;
                reg [7:0]    exp;
                reg [22:0]   man;
                reg [7:0]    sh;
                reg [23:0]   sig;
                reg [63:0]   mag;
                reg [63:0]   res;
 000250         begin
 000250             sgn = in_fp[31];
 000250             exp = in_fp[30:23];
 000250             man = in_fp[22:0];
 000250             sig = {1'b1, man};
%000000             if (exp < 8'd127) begin
 000250                 sp_to_int = 64'd0;
%000000             end else begin
%000000                 sh = exp - 8'd127;
%000000                 if (sh <= 8'd23)
%000000                     mag = {40'd0, sig} >> (8'd23 - sh);
%000000                 else if (sh < 8'd63)
%000000                     mag = {40'd0, sig} << (sh - 8'd23);
                        else
%000000                     mag = 64'h7FFFFFFFFFFFFFFF;
%000000                 res = sgn ? -mag : mag;
%000000                 if (in_rs2[1] == 1'b0)
%000000                     sp_to_int = in_rs2[0] ? {32'h0, res[31:0]} : {{32{res[31]}}, res[31:0]};
                        else
%000000                     sp_to_int = res;
                    end
                end
            endfunction
        
            // Float <-> Float Conversion
 1836890     function [63:0] dp_to_sp;
                input [63:0] in_dp;
                reg        sgn;
                reg [10:0] exp;
                reg [51:0] man;
                reg [7:0]  sp_exp;
                reg [22:0] sp_man;
 1836890         begin
 1836890             sgn = in_dp[63];
 1836890             exp = in_dp[62:52];
 1836890             man = in_dp[51:0];
 014350             if (exp == 11'h7FF) begin
 014350                 dp_to_sp = (man != 52'h0) ? {32'hFFFF_FFFF, SP_QNAN} :
 014350                                             {32'hFFFF_FFFF, sgn, 8'hFF, 23'h0};
 1822527             end else if (exp == 11'h0) begin
 1822527                 dp_to_sp = {32'hFFFF_FFFF, sgn, 31'h0};
%000000             end else if (exp < 11'd1023 - 11'd126) begin
%000000                 dp_to_sp = {32'hFFFF_FFFF, sgn, 31'h0};
 000013             end else if (exp > 11'd1023 + 11'd127) begin
%000000                 dp_to_sp = {32'hFFFF_FFFF, sgn, 8'hFF, 23'h0};
 000013             end else begin
 000013                 sp_exp = exp - 11'd1023 + 11'd127;
 000013                 sp_man = man[51:29];
 000013                 dp_to_sp = {32'hFFFF_FFFF, sgn, sp_exp, sp_man};
                    end
                end
            endfunction
        
 3590652     function [63:0] sp_to_dp;
                input [63:0] in_sp;
                reg        sgn;
                reg [7:0]  exp;
                reg [22:0] man;
                reg [10:0] dp_exp;
                reg [51:0] dp_man;
 3590652         begin
 3590652             sgn = in_sp[31];
 3590652             exp = in_sp[30:23];
 3590652             man = in_sp[22:0];
%000000             if (exp == 8'hFF) begin
%000000                 sp_to_dp = (man != 23'h0) ? DP_QNAN : {sgn, 11'h7FF, 52'h0};
%000000             end else if (exp == 8'h0) begin
 3590652                 sp_to_dp = {sgn, 63'h0};
%000000             end else begin
%000000                 dp_exp = exp - 8'd127 + 11'd1023;
%000000                 dp_man = {man, 29'h0};
%000000                 sp_to_dp = {sgn, dp_exp, dp_man};
                    end
                end
            endfunction
        
            // -------------------------------------------------------
            // Helper Function: 64-bit Non-Restoring Integer Sqrt
            // -------------------------------------------------------
%000003     function [31:0] sqrt64;
                input [63:0] val;
                reg [63:0] rem;
                reg [31:0] root;
                integer i;
%000003         begin
%000003             rem = 64'd0;
%000003             root = 32'd0;
%000003             for (i = 0; i < 32; i = i + 1) begin
 000096                 rem = {rem[61:0], val[63 - 2*i], val[62 - 2*i]};
 000096                 if (rem >= {root, 2'b01}) begin
%000000                     rem = rem - {root, 2'b01};
%000000                     root = {root[30:0], 1'b1};
 000096                 end else begin
 000096                     root = {root[30:0], 1'b0};
                        end
                    end
%000003             sqrt64 = root;
                end
            endfunction
        
            // -------------------------------------------------------
            // Double-Precision Arithmetic Functions
            // -------------------------------------------------------
 2149820     function [63:0] dp_add;
                input [63:0] a;
                input [63:0] b;
                input        is_sub;
                reg        sgn_a, sgn_b, sgn_res;
                reg [10:0] exp_a, exp_b, exp_res;
                reg [52:0] sig_a, sig_b;
                reg [10:0] exp_diff;
                reg [55:0] sig_l, sig_s, sig_aligned, sig_sum;
                reg        eff_sub;
                reg [5:0]  lz;
                reg        found;
                integer    i;
 2149820         begin
 2149820             sgn_a = a[63];
 2149820             exp_a = a[62:52];
 2149820             sig_a = (exp_a == 11'd0) ? {1'b0, a[51:0]} : {1'b1, a[51:0]};
        
 2149820             sgn_b = is_sub ? ~b[63] : b[63];
 2149820             exp_b = b[62:52];
 2149820             sig_b = (exp_b == 11'd0) ? {1'b0, b[51:0]} : {1'b1, b[51:0]};
        
 2149658             if (a[62:0] == 63'd0) begin
 2149658                 dp_add = {sgn_b, exp_b, b[51:0]};
 000012             end else if (b[62:0] == 63'd0) begin
 000150                 dp_add = a;
 000012             end else begin
%000003                 if ((exp_a > exp_b) || ((exp_a == exp_b) && (sig_a >= sig_b))) begin
%000009                     exp_res = exp_a;
%000009                     sgn_res = sgn_a;
%000009                     sig_l = {sig_a, 2'b00};
%000009                     sig_s = {sig_b, 2'b00};
%000009                     exp_diff = exp_a - exp_b;
%000003                 end else begin
%000003                     exp_res = exp_b;
%000003                     sgn_res = sgn_b;
%000003                     sig_l = {sig_b, 2'b00};
%000003                     sig_s = {sig_a, 2'b00};
%000003                     exp_diff = exp_b - exp_a;
                        end
        
 000012                 sig_aligned = (exp_diff > 11'd55) ? 56'd0 : (sig_s >> exp_diff);
 000012                 eff_sub = sgn_a ^ sgn_b;
        
%000003                 if (eff_sub)
%000003                     sig_sum = sig_l - sig_aligned;
                        else
%000009                     sig_sum = sig_l + sig_aligned;
        
%000000                 if (sig_sum == 56'd0) begin
%000000                     dp_add = 64'd0;
%000006                 end else if (!eff_sub && sig_sum[55]) begin
                            // Carry out
%000006                     dp_add = {sgn_res, exp_res + 11'd1, sig_sum[54:3]};
%000006                 end else begin
%000006                     lz = 6'd0;
%000006                     found = 1'b0;
%000006                     for (i = 0; i < 55; i = i + 1) begin
%000006                         if (sig_sum[54 - i] && !found) begin
%000006                             lz = i[5:0];
%000006                             found = 1'b1;
                                end
                            end
%000006                     if (exp_res <= {5'd0, lz}) begin
%000000                         dp_add = {sgn_res, 11'd0, 52'd0};
%000006                     end else begin
%000006                         exp_res = exp_res - {5'd0, lz};
%000006                         sig_sum = sig_sum << lz;
%000006                         dp_add = {sgn_res, exp_res, sig_sum[53:2]};
                            end
                        end
                    end
                end
            endfunction
        
 333691     function [63:0] dp_mul;
                input [63:0] a;
                input [63:0] b;
                reg        sgn;
                reg [10:0] exp;
                reg [52:0] sig_a, sig_b;
                reg [105:0] prod;
 333691         begin
%000006             if ((a[62:0] == 63'd0) || (b[62:0] == 63'd0)) begin
 333685                 dp_mul = {a[63] ^ b[63], 63'd0};
%000006             end else begin
%000006                 sgn = a[63] ^ b[63];
%000006                 exp = a[62:52] + b[62:52] - 11'd1023;
%000006                 sig_a = {1'b1, a[51:0]};
%000006                 sig_b = {1'b1, b[51:0]};
%000006                 prod = sig_a * sig_b;
%000006                 if (prod[105]) begin
%000000                     exp = exp + 11'd1;
%000000                     dp_mul = {sgn, exp, prod[104:53]};
%000006                 end else begin
%000006                     dp_mul = {sgn, exp, prod[103:52]};
                        end
                    end
                end
            endfunction
        
 028530     function [63:0] dp_div;
                input [63:0] a;
                input [63:0] b;
                output [4:0] flags;
                reg        sgn;
                reg [10:0] exp;
                reg [52:0] sig_a, sig_b;
                reg [107:0] num;
                reg [55:0] quot;
 028530         begin
 028530             flags = 5'd0;
 028530             sgn = a[63] ^ b[63];
 028527             if (b[62:0] == 63'd0) begin
%000003                 if (a[62:0] == 63'd0) begin
 028524                     flags = `FFLAG_NV;
 028524                     dp_div = DP_QNAN;
%000003                 end else begin
%000003                     flags = `FFLAG_DZ;
%000003                     dp_div = {sgn, 11'h7FF, 52'd0};
                        end
%000003             end else if (a[62:0] == 63'd0) begin
%000000                 dp_div = {sgn, 63'd0};
%000003             end else begin
%000003                 exp = a[62:52] - b[62:52] + 11'd1023;
%000003                 sig_a = {1'b1, a[51:0]};
%000003                 sig_b = {1'b1, b[51:0]};
%000003                 num = {sig_a, 55'd0};
%000003                 quot = num / sig_b;
%000000                 if (quot[55]) begin
%000003                     dp_div = {sgn, exp, quot[54:3]};
%000000                 end else begin
%000000                     dp_div = {sgn, exp - 11'd1, quot[53:2]};
                        end
                    end
                end
            endfunction
        
 004239     function [63:0] dp_sqrt;
                input [63:0] a;
                output [4:0] flags;
                reg [10:0] raw_exp;
                reg [52:0] sig;
                reg [63:0] radicand;
                reg [31:0] root;
                reg [10:0] exp_out;
 004239         begin
 004239             flags = 5'd0;
%000000             if (a[63] && (a[62:0] != 63'd0)) begin
%000000                 flags = `FFLAG_NV;
%000000                 dp_sqrt = DP_QNAN;
 004236             end else if (a[62:0] == 63'd0) begin
 004236                 dp_sqrt = 64'd0;
%000003             end else if (a[62:52] == 11'h7FF) begin
%000000                 dp_sqrt = a;
%000003             end else begin
%000003                 raw_exp = a[62:52] - 11'd1023;
%000003                 sig = {1'b1, a[51:0]};
%000003                 if (raw_exp[0]) begin
%000000                     radicand = {sig, 11'd0};
%000000                     exp_out = 11'd1023 + ((raw_exp - 11'd1) >> 1);
%000003                 end else begin
%000003                     radicand = {1'b0, sig, 10'd0};
%000003                     exp_out = 11'd1023 + (raw_exp >> 1);
                        end
%000003                 root = sqrt64(radicand);
%000003                 dp_sqrt = {1'b0, exp_out, root[30:0], 21'd0};
                    end
                end
            endfunction
        
            // -------------------------------------------------------
            // Single-Precision Arithmetic Functions
            // -------------------------------------------------------
 1534947     function [31:0] sp_add;
                input [31:0] a;
                input [31:0] b;
                input        is_sub;
                reg [63:0] dp_a, dp_b, dp_res;
 1534947         begin
 1534947             dp_a = sp_to_dp({32'hFFFF_FFFF, a});
 1534947             dp_b = sp_to_dp({32'hFFFF_FFFF, b});
 1534947             dp_res = dp_add(dp_a, dp_b, is_sub);
 1534947             sp_add = dp_to_sp(dp_res);
                end
            endfunction
        
 242374     function [31:0] sp_mul;
                input [31:0] a;
                input [31:0] b;
                reg [63:0] dp_a, dp_b, dp_res;
 242374         begin
 242374             dp_a = sp_to_dp({32'hFFFF_FFFF, a});
 242374             dp_b = sp_to_dp({32'hFFFF_FFFF, b});
 242374             dp_res = dp_mul(dp_a, dp_b);
 242374             sp_mul = dp_to_sp(dp_res);
                end
            endfunction
        
 014335     function [31:0] sp_div;
                input [31:0] a;
                input [31:0] b;
                output [4:0] flags;
                reg [63:0] dp_a, dp_b, dp_res;
 014335         begin
 014335             dp_a = sp_to_dp({32'hFFFF_FFFF, a});
 014335             dp_b = sp_to_dp({32'hFFFF_FFFF, b});
 014335             dp_res = dp_div(dp_a, dp_b, flags);
 014335             sp_div = dp_to_sp(dp_res);
                end
            endfunction
        
            // -------------------------------------------------------
            // Combinational Execution Engine
            // -------------------------------------------------------
            reg [4:0] div_flags, sqrt_flags;
            reg [63:0] fma_prod;
        
 000072     always @(*) begin
                // Defaults
 000072         fp_result        = 64'h0;
 000072         int_result       = 64'h0;
 000072         int_result_valid = 1'b0;
 000072         fflags           = 5'h0;
 000072         div_flags        = 5'h0;
 000072         sqrt_flags       = 5'h0;
 000072         fma_prod         = 64'h0;
        
%000003         if (opcode == `OP_FMADD || opcode == `OP_FMSUB ||
%000003             opcode == `OP_FNMSUB || opcode == `OP_FNMADD) begin
                    // Fused Multiply-Add instructions
%000003             if (fmt == `FMT_S) begin
%000000                 fma_prod = sp_to_dp({32'hFFFF_FFFF, sp_mul(fp_src1[31:0], fp_src2[31:0])});
%000000                 case (opcode)
%000000                     `OP_FMADD:  fp_result = dp_to_sp(dp_add(fma_prod, sp_to_dp(fp_src3), 1'b0));
%000000                     `OP_FMSUB:  fp_result = dp_to_sp(dp_add(fma_prod, sp_to_dp(fp_src3), 1'b1));
%000000                     `OP_FNMSUB: fp_result = dp_to_sp(dp_add({~fma_prod[63], fma_prod[62:0]}, sp_to_dp(fp_src3), 1'b0));
%000000                     `OP_FNMADD: fp_result = dp_to_sp(dp_add({~fma_prod[63], fma_prod[62:0]}, sp_to_dp(fp_src3), 1'b1));
%000000                     default:    fp_result = {32'hFFFF_FFFF, SP_QNAN};
                        endcase
%000003             end else begin
%000003                 fma_prod = dp_mul(fp_src1, fp_src2);
%000003                 case (opcode)
%000003                     `OP_FMADD:  fp_result = dp_add(fma_prod, fp_src3, 1'b0);
%000000                     `OP_FMSUB:  fp_result = dp_add(fma_prod, fp_src3, 1'b1);
%000000                     `OP_FNMSUB: fp_result = dp_add({~fma_prod[63], fma_prod[62:0]}, fp_src3, 1'b0);
%000000                     `OP_FNMADD: fp_result = dp_add({~fma_prod[63], fma_prod[62:0]}, fp_src3, 1'b1);
%000000                     default:    fp_result = DP_QNAN;
                        endcase
                    end
 3120617         end else begin
                    // Standard OP_FP instructions
 3120617             case (fop)
 2122263                 `FOP_FADD: begin
 2122263                     fp_result = (fmt == `FMT_S) ?
 2122263                                 {32'hFFFF_FFFF, sp_add(fp_src1[31:0], fp_src2[31:0], 1'b0)} :
 2122263                                 dp_add(fp_src1, fp_src2, 1'b0);
                        end
 027554                 `FOP_FSUB: begin
 027554                     fp_result = (fmt == `FMT_S) ?
 027554                                 {32'hFFFF_FFFF, sp_add(fp_src1[31:0], fp_src2[31:0], 1'b1)} :
 027554                                 dp_add(fp_src1, fp_src2, 1'b1);
                        end
 333688                 `FOP_FMUL: begin
 333688                     fp_result = (fmt == `FMT_S) ?
 333688                                 {32'hFFFF_FFFF, sp_mul(fp_src1[31:0], fp_src2[31:0])} :
 333688                                 dp_mul(fp_src1, fp_src2);
                        end
 028530                 `FOP_FDIV: begin
 014195                     if (fmt == `FMT_S) begin
 014335                         fp_result = {32'hFFFF_FFFF, sp_div(fp_src1[31:0], fp_src2[31:0], div_flags)};
 014335                         fflags    = div_flags;
 014195                     end else begin
 014195                         fp_result = dp_div(fp_src1, fp_src2, div_flags);
 014195                         fflags    = div_flags;
                            end
                        end
 004239                 `FOP_FSQRT: begin
 000752                     if (fmt == `FMT_S) begin
 000752                         fp_result = dp_to_sp(dp_sqrt(sp_to_dp(fp_src1), sqrt_flags));
 000752                         fflags    = sqrt_flags;
 003487                     end else begin
 003487                         fp_result = dp_sqrt(fp_src1, sqrt_flags);
 003487                         fflags    = sqrt_flags;
                            end
                        end
 001907                 `FOP_FSGNJ: begin
 000675                     if (fmt == `FMT_S) begin
 000675                         case (rm[1:0])
 000300                             2'b00: fp_result = {32'hFFFF_FFFF, fp_src2[31], fp_src1[30:0]};
%000004                             2'b01: fp_result = {32'hFFFF_FFFF, ~fp_src2[31], fp_src1[30:0]};
 000346                             2'b10: fp_result = {32'hFFFF_FFFF, fp_src1[31] ^ fp_src2[31], fp_src1[30:0]};
 000025                             default: fp_result = {32'hFFFF_FFFF, fp_src2[31], fp_src1[30:0]};
                                endcase
 001232                     end else begin
 001232                         case (rm[1:0])
 000531                             2'b00: fp_result = {fp_src2[63], fp_src1[62:0]};
 000133                             2'b01: fp_result = {~fp_src2[63], fp_src1[62:0]};
 000493                             2'b10: fp_result = {fp_src1[63] ^ fp_src2[63], fp_src1[62:0]};
 000075                             default: fp_result = {fp_src2[63], fp_src1[62:0]};
                                endcase
                            end
                        end
 002419                 `FOP_FMINMAX: begin
 000435                     if (fmt == `FMT_S)
 000435                         fp_result = {32'hFFFF_FFFF, rm[0] ? sp_fmax : sp_fmin};
                            else
 001984                         fp_result = rm[0] ? dp_fmax : dp_fmin;
                        end
 002952                 `FOP_FCVT_WF: begin
                            // Float -> Integer
 002952                     int_result = (fmt == `FMT_S) ? sp_to_int(fp_src1, rs2) : dp_to_int(fp_src1, rs2);
 002952                     int_result_valid = 1'b1;
                        end
 001269                 `FOP_FCVT_FW: begin
                            // Integer -> Float
 001269                     fp_result = (fmt == `FMT_S) ? int_to_sp(int_src, rs2) : int_to_dp(int_src, rs2);
                        end
 051070                 `FOP_FCVT_FF: begin
                            // Float <-> Float
 051070                     fp_result = (fmt == `FMT_S) ? dp_to_sp(fp_src1) : sp_to_dp(fp_src1);
                        end
 027253                 `FOP_FMVXW: begin
                            // Move Float to Integer register
 027253                     int_result = (fmt == `FMT_S) ? {{32{fp_src1[31]}}, fp_src1[31:0]} : fp_src1;
 027253                     int_result_valid = 1'b1;
                        end
 027066                 `FOP_FMVWX: begin
                            // Move Integer to Float register
 027066                     fp_result = (fmt == `FMT_S) ? {32'hFFFF_FFFF, int_src[31:0]} : int_src;
                        end
 001650                 `FOP_FCMP: begin
                            // Float comparison: FEQ, FLT, FLE
 000469                     if (fmt == `FMT_S) begin
 000469                         case (rm[1:0])
 000016                             2'b10: int_result = {63'd0, sp_eq};
%000000                             2'b01: int_result = {63'd0, sp_lt};
 000453                             default: int_result = {63'd0, sp_le};
                                endcase
 001181                     end else begin
 001181                         case (rm[1:0])
 000453                             2'b10: int_result = {63'd0, dp_eq};
%000001                             2'b01: int_result = {63'd0, dp_lt};
 000727                             default: int_result = {63'd0, dp_le};
                                endcase
                            end
 001650                     int_result_valid = 1'b1;
                        end
 488757                 default: begin
 488757                     fp_result = (fmt == `FMT_S) ? {32'hFFFF_FFFF, fp_src1[31:0]} : fp_src1;
                        end
                    endcase
                end
            end
        
        endmodule
        
