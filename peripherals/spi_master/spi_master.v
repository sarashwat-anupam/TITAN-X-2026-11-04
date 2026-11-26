// SPDX-License-Identifier: Apache-2.0
// SMVDU-TITAN-X SoC — SPI Master Controller
// Pre-Synthesis Clean-Room Fix (Defect D-036): Zero wait-state combinational prdata,
// immediate busy assertion on APB write, and robust completion interrupt generation.
`timescale 1ns/1ps

module spi_master (
    input  wire        clk,
    input  wire        rst_n,
    // APB slave
    input  wire        psel,
    input  wire        penable,
    input  wire        pwrite,
    input  wire [3:0]  paddr,
    input  wire [31:0] pwdata,
    output wire [31:0] prdata,
    output wire        pready,
    // SPI pads
    output wire        spi_clk,
    output wire        spi_mosi,
    input  wire        spi_miso,
    output reg  [3:0]  spi_csn,   // 4 chip selects (active-low)
    output wire        irq
);
    assign pready = 1'b1;

    reg [15:0] clk_div;    // SCLK = clk / (2*(clk_div+1))
    reg [7:0]  tx_data;
    reg [7:0]  rx_data;
    reg        busy;
    reg [3:0]  cs_select;  // which CS to assert
    reg        cpol, cpha;
    reg        done_irq;

    // Clock generator
    reg [15:0] clk_cnt;
    reg        sclk_r;
    wire       sclk_edge = (clk_cnt == 16'h0);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_cnt <= 16'h0;
            sclk_r  <= 1'b0;
        end else if (busy) begin
            if (clk_cnt >= clk_div) begin
                clk_cnt <= 16'h0;
                sclk_r  <= ~sclk_r;
            end else begin
                clk_cnt <= clk_cnt + 16'h1;
            end
        end else begin
            sclk_r  <= cpol;
            clk_cnt <= 16'h0;
        end
    end

    assign spi_clk = sclk_r;

    // Shift register
    reg [7:0] shift_out;
    reg [7:0] shift_in;
    reg [2:0] bit_cnt;
    reg       mosi_r;
    assign spi_mosi = mosi_r;
    assign irq      = done_irq;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_out <= 8'h0;
            shift_in  <= 8'h0;
            rx_data   <= 8'h0;
            bit_cnt   <= 3'h0;
            mosi_r    <= 1'b1;
            busy      <= 1'b0;
            spi_csn   <= 4'hF;
            done_irq  <= 1'b0;
        end else begin
            // APB Write: offset 0x00 starts transfer immediately
            if (psel && penable && pwrite && (paddr[3:2] == 2'd0)) begin
                done_irq  <= 1'b0;
                shift_out <= {pwdata[6:0], 1'b0};
                mosi_r    <= pwdata[7];
                bit_cnt   <= 3'h7;
                busy      <= 1'b1;
                spi_csn   <= ~(4'b0001 << cs_select[1:0]);
            end else if (psel && penable && !pwrite && (paddr[3:2] == 2'd0)) begin
                done_irq  <= 1'b0; // Reading RX data clears interrupt
            end

            // Shift on SCLK edges
            if (busy && sclk_edge) begin
                if (sclk_r) begin
                    // Rising edge (sampling MISO in Mode 0)
                    shift_in <= {shift_in[6:0], spi_miso};
                    if (bit_cnt == 3'h0) begin
                        rx_data  <= {shift_in[6:0], spi_miso};
                        busy     <= 1'b0;
                        spi_csn  <= 4'hF;
                        done_irq <= 1'b1;
                    end else begin
                        bit_cnt <= bit_cnt - 3'h1;
                    end
                end else begin
                    // Falling edge (shifting out next MOSI bit)
                    mosi_r    <= shift_out[7];
                    shift_out <= {shift_out[6:0], 1'b0};
                end
            end
        end
    end

    // APB registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_div   <= 16'd49;   // 100MHz / (2*50) = 1 MHz
            tx_data   <= 8'h0;
            cs_select <= 4'h0;
            cpol      <= 1'b0;
            cpha      <= 1'b0;
        end else if (psel && penable && pwrite) begin
            case (paddr[3:2])
                2'd0: tx_data <= pwdata[7:0];
                2'd1: clk_div <= pwdata[15:0];
                2'd2: {cpha, cpol, cs_select} <= {pwdata[5], pwdata[4], pwdata[3:0]};
                default: ;
            endcase
        end
    end

    // Combinational Zero Wait-State Read Data
    reg [31:0] prdata_comb;
    always @(*) begin
        case (paddr[3:2])
            2'd0: prdata_comb = {24'h0, rx_data};
            2'd1: prdata_comb = {busy, 15'h0, clk_div};
            default: prdata_comb = 32'h0;
        endcase
    end
    assign prdata = prdata_comb;

endmodule
