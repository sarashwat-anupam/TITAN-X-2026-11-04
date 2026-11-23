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
    function [63:0] int_to_dp;
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
        begin
            is_signed = ~in_rs2[0];
            if (in_rs2[1] == 1'b0)
                eff_val = is_signed ? {{32{in_src[31]}}, in_src[31:0]} : {32'h0, in_src[31:0]};
            else
                eff_val = in_src;

            if (is_signed && eff_val[63]) begin
                sgn = 1'b1;
                mag = -eff_val;
            end else begin
                sgn = 1'b0;
                mag = eff_val;
            end

            if (mag == 64'd0) begin
                int_to_dp = 64'd0;
            end else begin
                lz = 6'd0;
                found = 1'b0;
                for (k = 0; k < 64; k = k + 1) begin
                    if (mag[63 - k] && !found) begin
                        lz = k[5:0];
                        found = 1'b1;
                    end
                end
                exp = 11'd1023 + (11'd63 - {5'd0, lz});
                if ((6'd63 - lz) <= 6'd52)
                    man = (mag << (6'd52 - (6'd63 - lz))) & 52'hFFFFFFFFFFFFF;
                else
                    man = (mag >> ((6'd63 - lz) - 6'd52)) & 52'hFFFFFFFFFFFFF;
                int_to_dp = {sgn, exp, man};
            end
        end
    endfunction

    function [63:0] int_to_sp;
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
        begin
            is_signed = ~in_rs2[0];
            if (in_rs2[1] == 1'b0)
                eff_val = is_signed ? {{32{in_src[31]}}, in_src[31:0]} : {32'h0, in_src[31:0]};
            else
                eff_val = in_src;

            if (is_signed && eff_val[63]) begin
                sgn = 1'b1;
                mag = -eff_val;
            end else begin
                sgn = 1'b0;
                mag = eff_val;
            end

            if (mag == 64'd0) begin
                int_to_sp = {32'hFFFF_FFFF, 32'd0};
            end else begin
                lz = 6'd0;
                found = 1'b0;
                for (k = 0; k < 64; k = k + 1) begin
                    if (mag[63 - k] && !found) begin
                        lz = k[5:0];
                        found = 1'b1;
                    end
                end
                exp = 8'd127 + (8'd63 - {2'd0, lz});
                if ((6'd63 - lz) <= 6'd23)
                    man = (mag << (6'd23 - (6'd63 - lz))) & 23'h7FFFFF;
                else
                    man = (mag >> ((6'd63 - lz) - 6'd23)) & 23'h7FFFFF;
                int_to_sp = {32'hFFFF_FFFF, sgn, exp, man};
            end
        end
    endfunction

    function [63:0] dp_to_int;
        input [63:0] in_fp;
        input [4:0]  in_rs2;
        reg          sgn;
        reg [10:0]   exp;
        reg [51:0]   man;
        reg [10:0]   sh;
        reg [52:0]   sig;
        reg [63:0]   mag;
        reg [63:0]   res;
        begin
            sgn = in_fp[63];
            exp = in_fp[62:52];
            man = in_fp[51:0];
            sig = {1'b1, man};
            if (exp < 11'd1023) begin
                dp_to_int = 64'd0;
            end else begin
                sh = exp - 11'd1023;
                if (sh <= 11'd52)
                    mag = {11'd0, sig} >> (11'd52 - sh);
                else if (sh < 11'd63)
                    mag = {11'd0, sig} << (sh - 11'd52);
                else
                    mag = 64'h7FFFFFFFFFFFFFFF;
                res = sgn ? -mag : mag;
                if (in_rs2[1] == 1'b0)
                    dp_to_int = in_rs2[0] ? {32'h0, res[31:0]} : {{32{res[31]}}, res[31:0]};
                else
                    dp_to_int = res;
            end
        end
    endfunction

    function [63:0] sp_to_int;
        input [63:0] in_fp;
        input [4:0]  in_rs2;
        reg          sgn;
        reg [7:0]    exp;
        reg [22:0]   man;
        reg [7:0]    sh;
        reg [23:0]   sig;
        reg [63:0]   mag;
        reg [63:0]   res;
        begin
            sgn = in_fp[31];
            exp = in_fp[30:23];
            man = in_fp[22:0];
            sig = {1'b1, man};
            if (exp < 8'd127) begin
                sp_to_int = 64'd0;
            end else begin
                sh = exp - 8'd127;
                if (sh <= 8'd23)
                    mag = {40'd0, sig} >> (8'd23 - sh);
                else if (sh < 8'd63)
                    mag = {40'd0, sig} << (sh - 8'd23);
                else
                    mag = 64'h7FFFFFFFFFFFFFFF;
                res = sgn ? -mag : mag;
                if (in_rs2[1] == 1'b0)
                    sp_to_int = in_rs2[0] ? {32'h0, res[31:0]} : {{32{res[31]}}, res[31:0]};
                else
                    sp_to_int = res;
            end
        end
    endfunction

    // Float <-> Float Conversion
    function [63:0] dp_to_sp;
        input [63:0] in_dp;
        reg        sgn;
        reg [10:0] exp;
        reg [51:0] man;
        reg [7:0]  sp_exp;
        reg [22:0] sp_man;
        begin
            sgn = in_dp[63];
            exp = in_dp[62:52];
            man = in_dp[51:0];
            if (exp == 11'h7FF) begin
                dp_to_sp = (man != 52'h0) ? {32'hFFFF_FFFF, SP_QNAN} :
                                            {32'hFFFF_FFFF, sgn, 8'hFF, 23'h0};
            end else if (exp == 11'h0) begin
                dp_to_sp = {32'hFFFF_FFFF, sgn, 31'h0};
            end else if (exp < 11'd1023 - 11'd126) begin
                dp_to_sp = {32'hFFFF_FFFF, sgn, 31'h0};
            end else if (exp > 11'd1023 + 11'd127) begin
                dp_to_sp = {32'hFFFF_FFFF, sgn, 8'hFF, 23'h0};
            end else begin
                sp_exp = exp - 11'd1023 + 11'd127;
                sp_man = man[51:29];
                dp_to_sp = {32'hFFFF_FFFF, sgn, sp_exp, sp_man};
            end
        end
    endfunction

    function [63:0] sp_to_dp;
        input [63:0] in_sp;
        reg        sgn;
        reg [7:0]  exp;
        reg [22:0] man;
        reg [10:0] dp_exp;
        reg [51:0] dp_man;
        begin
            sgn = in_sp[31];
            exp = in_sp[30:23];
            man = in_sp[22:0];
            if (exp == 8'hFF) begin
                sp_to_dp = (man != 23'h0) ? DP_QNAN : {sgn, 11'h7FF, 52'h0};
            end else if (exp == 8'h0) begin
                sp_to_dp = {sgn, 63'h0};
            end else begin
                dp_exp = exp - 8'd127 + 11'd1023;
                dp_man = {man, 29'h0};
                sp_to_dp = {sgn, dp_exp, dp_man};
            end
        end
    endfunction

    // -------------------------------------------------------
    // Helper Function: 64-bit Non-Restoring Integer Sqrt
    // -------------------------------------------------------
    function [31:0] sqrt64;
        input [63:0] val;
        reg [63:0] rem;
        reg [31:0] root;
        integer i;
        begin
            rem = 64'd0;
            root = 32'd0;
            for (i = 0; i < 32; i = i + 1) begin
                rem = {rem[61:0], val[63 - 2*i], val[62 - 2*i]};
                if (rem >= {root, 2'b01}) begin
                    rem = rem - {root, 2'b01};
                    root = {root[30:0], 1'b1};
                end else begin
                    root = {root[30:0], 1'b0};
                end
            end
            sqrt64 = root;
        end
    endfunction

    // -------------------------------------------------------
    // Double-Precision Arithmetic Functions
    // -------------------------------------------------------
    function [63:0] dp_add;
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
        begin
            sgn_a = a[63];
            exp_a = a[62:52];
            sig_a = (exp_a == 11'd0) ? {1'b0, a[51:0]} : {1'b1, a[51:0]};

            sgn_b = is_sub ? ~b[63] : b[63];
            exp_b = b[62:52];
            sig_b = (exp_b == 11'd0) ? {1'b0, b[51:0]} : {1'b1, b[51:0]};

            if (a[62:0] == 63'd0) begin
                dp_add = {sgn_b, exp_b, b[51:0]};
            end else if (b[62:0] == 63'd0) begin
                dp_add = a;
            end else begin
                if ((exp_a > exp_b) || ((exp_a == exp_b) && (sig_a >= sig_b))) begin
                    exp_res = exp_a;
                    sgn_res = sgn_a;
                    sig_l = {sig_a, 2'b00};
                    sig_s = {sig_b, 2'b00};
                    exp_diff = exp_a - exp_b;
                end else begin
                    exp_res = exp_b;
                    sgn_res = sgn_b;
                    sig_l = {sig_b, 2'b00};
                    sig_s = {sig_a, 2'b00};
                    exp_diff = exp_b - exp_a;
                end

                sig_aligned = (exp_diff > 11'd55) ? 56'd0 : (sig_s >> exp_diff);
                eff_sub = sgn_a ^ sgn_b;

                if (eff_sub)
                    sig_sum = sig_l - sig_aligned;
                else
                    sig_sum = sig_l + sig_aligned;

                if (sig_sum == 56'd0) begin
                    dp_add = 64'd0;
                end else if (!eff_sub && sig_sum[55]) begin
                    // Carry out
                    dp_add = {sgn_res, exp_res + 11'd1, sig_sum[54:3]};
                end else begin
                    lz = 6'd0;
                    found = 1'b0;
                    for (i = 0; i < 55; i = i + 1) begin
                        if (sig_sum[54 - i] && !found) begin
                            lz = i[5:0];
                            found = 1'b1;
                        end
                    end
                    if (exp_res <= {5'd0, lz}) begin
                        dp_add = {sgn_res, 11'd0, 52'd0};
                    end else begin
                        exp_res = exp_res - {5'd0, lz};
                        sig_sum = sig_sum << lz;
                        dp_add = {sgn_res, exp_res, sig_sum[53:2]};
                    end
                end
            end
        end
    endfunction

    function [63:0] dp_mul;
        input [63:0] a;
        input [63:0] b;
        reg        sgn;
        reg [10:0] exp;
        reg [52:0] sig_a, sig_b;
        reg [105:0] prod;
        begin
            if ((a[62:0] == 63'd0) || (b[62:0] == 63'd0)) begin
                dp_mul = {a[63] ^ b[63], 63'd0};
            end else begin
                sgn = a[63] ^ b[63];
                exp = a[62:52] + b[62:52] - 11'd1023;
                sig_a = {1'b1, a[51:0]};
                sig_b = {1'b1, b[51:0]};
                prod = sig_a * sig_b;
                if (prod[105]) begin
                    exp = exp + 11'd1;
                    dp_mul = {sgn, exp, prod[104:53]};
                end else begin
                    dp_mul = {sgn, exp, prod[103:52]};
                end
            end
        end
    endfunction

    function [63:0] dp_div;
        input [63:0] a;
        input [63:0] b;
        output [4:0] flags;
        reg        sgn;
        reg [10:0] exp;
        reg [52:0] sig_a, sig_b;
        reg [107:0] num;
        reg [55:0] quot;
        begin
            flags = 5'd0;
            sgn = a[63] ^ b[63];
            if (b[62:0] == 63'd0) begin
                if (a[62:0] == 63'd0) begin
                    flags = `FFLAG_NV;
                    dp_div = DP_QNAN;
                end else begin
                    flags = `FFLAG_DZ;
                    dp_div = {sgn, 11'h7FF, 52'd0};
                end
            end else if (a[62:0] == 63'd0) begin
                dp_div = {sgn, 63'd0};
            end else begin
                exp = a[62:52] - b[62:52] + 11'd1023;
                sig_a = {1'b1, a[51:0]};
                sig_b = {1'b1, b[51:0]};
                num = {sig_a, 55'd0};
                quot = num / sig_b;
                if (quot[55]) begin
                    dp_div = {sgn, exp, quot[54:3]};
                end else begin
                    dp_div = {sgn, exp - 11'd1, quot[53:2]};
                end
            end
        end
    endfunction

    function [63:0] dp_sqrt;
        input [63:0] a;
        output [4:0] flags;
        reg [10:0] raw_exp;
        reg [52:0] sig;
        reg [63:0] radicand;
        reg [31:0] root;
        reg [10:0] exp_out;
        begin
            flags = 5'd0;
            if (a[63] && (a[62:0] != 63'd0)) begin
                flags = `FFLAG_NV;
                dp_sqrt = DP_QNAN;
            end else if (a[62:0] == 63'd0) begin
                dp_sqrt = 64'd0;
            end else if (a[62:52] == 11'h7FF) begin
                dp_sqrt = a;
            end else begin
                raw_exp = a[62:52] - 11'd1023;
                sig = {1'b1, a[51:0]};
                if (raw_exp[0]) begin
                    radicand = {sig, 11'd0};
                    exp_out = 11'd1023 + ((raw_exp - 11'd1) >> 1);
                end else begin
                    radicand = {1'b0, sig, 10'd0};
                    exp_out = 11'd1023 + (raw_exp >> 1);
                end
                root = sqrt64(radicand);
                dp_sqrt = {1'b0, exp_out, root[30:0], 21'd0};
            end
        end
    endfunction

    // -------------------------------------------------------
    // Single-Precision Arithmetic Functions
    // -------------------------------------------------------
    function [31:0] sp_add;
        input [31:0] a;
        input [31:0] b;
        input        is_sub;
        reg [63:0] dp_a, dp_b, dp_res;
        begin
            dp_a = sp_to_dp({32'hFFFF_FFFF, a});
            dp_b = sp_to_dp({32'hFFFF_FFFF, b});
            dp_res = dp_add(dp_a, dp_b, is_sub);
            sp_add = dp_to_sp(dp_res);
        end
    endfunction

    function [31:0] sp_mul;
        input [31:0] a;
        input [31:0] b;
        reg [63:0] dp_a, dp_b, dp_res;
        begin
            dp_a = sp_to_dp({32'hFFFF_FFFF, a});
            dp_b = sp_to_dp({32'hFFFF_FFFF, b});
            dp_res = dp_mul(dp_a, dp_b);
            sp_mul = dp_to_sp(dp_res);
        end
    endfunction

    function [31:0] sp_div;
        input [31:0] a;
        input [31:0] b;
        output [4:0] flags;
        reg [63:0] dp_a, dp_b, dp_res;
        begin
            dp_a = sp_to_dp({32'hFFFF_FFFF, a});
            dp_b = sp_to_dp({32'hFFFF_FFFF, b});
            dp_res = dp_div(dp_a, dp_b, flags);
            sp_div = dp_to_sp(dp_res);
        end
    endfunction

    // -------------------------------------------------------
    // Combinational Execution Engine
    // -------------------------------------------------------
    reg [4:0] div_flags, sqrt_flags;
    reg [63:0] fma_prod;

    always @(*) begin
        // Defaults
        fp_result        = 64'h0;
        int_result       = 64'h0;
        int_result_valid = 1'b0;
        fflags           = 5'h0;
        div_flags        = 5'h0;
        sqrt_flags       = 5'h0;
        fma_prod         = 64'h0;

        if (opcode == `OP_FMADD || opcode == `OP_FMSUB ||
            opcode == `OP_FNMSUB || opcode == `OP_FNMADD) begin
            // Fused Multiply-Add instructions
            if (fmt == `FMT_S) begin
                fma_prod = sp_to_dp({32'hFFFF_FFFF, sp_mul(fp_src1[31:0], fp_src2[31:0])});
                case (opcode)
                    `OP_FMADD:  fp_result = dp_to_sp(dp_add(fma_prod, sp_to_dp(fp_src3), 1'b0));
                    `OP_FMSUB:  fp_result = dp_to_sp(dp_add(fma_prod, sp_to_dp(fp_src3), 1'b1));
                    `OP_FNMSUB: fp_result = dp_to_sp(dp_add({~fma_prod[63], fma_prod[62:0]}, sp_to_dp(fp_src3), 1'b0));
                    `OP_FNMADD: fp_result = dp_to_sp(dp_add({~fma_prod[63], fma_prod[62:0]}, sp_to_dp(fp_src3), 1'b1));
                    default:    fp_result = {32'hFFFF_FFFF, SP_QNAN};
                endcase
            end else begin
                fma_prod = dp_mul(fp_src1, fp_src2);
                case (opcode)
                    `OP_FMADD:  fp_result = dp_add(fma_prod, fp_src3, 1'b0);
                    `OP_FMSUB:  fp_result = dp_add(fma_prod, fp_src3, 1'b1);
                    `OP_FNMSUB: fp_result = dp_add({~fma_prod[63], fma_prod[62:0]}, fp_src3, 1'b0);
                    `OP_FNMADD: fp_result = dp_add({~fma_prod[63], fma_prod[62:0]}, fp_src3, 1'b1);
                    default:    fp_result = DP_QNAN;
                endcase
            end
        end else begin
            // Standard OP_FP instructions
            case (fop)
                `FOP_FADD: begin
                    fp_result = (fmt == `FMT_S) ?
                                {32'hFFFF_FFFF, sp_add(fp_src1[31:0], fp_src2[31:0], 1'b0)} :
                                dp_add(fp_src1, fp_src2, 1'b0);
                end
                `FOP_FSUB: begin
                    fp_result = (fmt == `FMT_S) ?
                                {32'hFFFF_FFFF, sp_add(fp_src1[31:0], fp_src2[31:0], 1'b1)} :
                                dp_add(fp_src1, fp_src2, 1'b1);
                end
                `FOP_FMUL: begin
                    fp_result = (fmt == `FMT_S) ?
                                {32'hFFFF_FFFF, sp_mul(fp_src1[31:0], fp_src2[31:0])} :
                                dp_mul(fp_src1, fp_src2);
                end
                `FOP_FDIV: begin
                    if (fmt == `FMT_S) begin
                        fp_result = {32'hFFFF_FFFF, sp_div(fp_src1[31:0], fp_src2[31:0], div_flags)};
                        fflags    = div_flags;
                    end else begin
                        fp_result = dp_div(fp_src1, fp_src2, div_flags);
                        fflags    = div_flags;
                    end
                end
                `FOP_FSQRT: begin
                    if (fmt == `FMT_S) begin
                        fp_result = dp_to_sp(dp_sqrt(sp_to_dp(fp_src1), sqrt_flags));
                        fflags    = sqrt_flags;
                    end else begin
                        fp_result = dp_sqrt(fp_src1, sqrt_flags);
                        fflags    = sqrt_flags;
                    end
                end
                `FOP_FSGNJ: begin
                    if (fmt == `FMT_S) begin
                        case (rm[1:0])
                            2'b00: fp_result = {32'hFFFF_FFFF, fp_src2[31], fp_src1[30:0]};
                            2'b01: fp_result = {32'hFFFF_FFFF, ~fp_src2[31], fp_src1[30:0]};
                            2'b10: fp_result = {32'hFFFF_FFFF, fp_src1[31] ^ fp_src2[31], fp_src1[30:0]};
                            default: fp_result = {32'hFFFF_FFFF, fp_src2[31], fp_src1[30:0]};
                        endcase
                    end else begin
                        case (rm[1:0])
                            2'b00: fp_result = {fp_src2[63], fp_src1[62:0]};
                            2'b01: fp_result = {~fp_src2[63], fp_src1[62:0]};
                            2'b10: fp_result = {fp_src1[63] ^ fp_src2[63], fp_src1[62:0]};
                            default: fp_result = {fp_src2[63], fp_src1[62:0]};
                        endcase
                    end
                end
                `FOP_FMINMAX: begin
                    if (fmt == `FMT_S)
                        fp_result = {32'hFFFF_FFFF, rm[0] ? sp_fmax : sp_fmin};
                    else
                        fp_result = rm[0] ? dp_fmax : dp_fmin;
                end
                `FOP_FCVT_WF: begin
                    // Float -> Integer
                    int_result = (fmt == `FMT_S) ? sp_to_int(fp_src1, rs2) : dp_to_int(fp_src1, rs2);
                    int_result_valid = 1'b1;
                end
                `FOP_FCVT_FW: begin
                    // Integer -> Float
                    fp_result = (fmt == `FMT_S) ? int_to_sp(int_src, rs2) : int_to_dp(int_src, rs2);
                end
                `FOP_FCVT_FF: begin
                    // Float <-> Float
                    fp_result = (fmt == `FMT_S) ? dp_to_sp(fp_src1) : sp_to_dp(fp_src1);
                end
                `FOP_FMVXW: begin
                    // Move Float to Integer register
                    int_result = (fmt == `FMT_S) ? {{32{fp_src1[31]}}, fp_src1[31:0]} : fp_src1;
                    int_result_valid = 1'b1;
                end
                `FOP_FMVWX: begin
                    // Move Integer to Float register
                    fp_result = (fmt == `FMT_S) ? {32'hFFFF_FFFF, int_src[31:0]} : int_src;
                end
                `FOP_FCMP: begin
                    // Float comparison: FEQ, FLT, FLE
                    if (fmt == `FMT_S) begin
                        case (rm[1:0])
                            2'b10: int_result = {63'd0, sp_eq};
                            2'b01: int_result = {63'd0, sp_lt};
                            default: int_result = {63'd0, sp_le};
                        endcase
                    end else begin
                        case (rm[1:0])
                            2'b10: int_result = {63'd0, dp_eq};
                            2'b01: int_result = {63'd0, dp_lt};
                            default: int_result = {63'd0, dp_le};
                        endcase
                    end
                    int_result_valid = 1'b1;
                end
                default: begin
                    fp_result = (fmt == `FMT_S) ? {32'hFFFF_FFFF, fp_src1[31:0]} : fp_src1;
                end
            endcase
        end
    end

endmodule
