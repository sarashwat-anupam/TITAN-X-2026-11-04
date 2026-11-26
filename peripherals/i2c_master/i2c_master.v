// SPDX-License-Identifier: Apache-2.0
// SMVDU-TITAN-X SoC — I2C Master Controller
// Pre-Synthesis Clean-Room Fix (Defect D-036): Zero wait-state combinational prdata,
// clear command strobes on execution start, transaction completion interrupt generation,
// and deterministic open-drain sda_o / sda_i bus interface.
`timescale 1ns/1ps

module i2c_master (
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
    // I2C signals
    output wire        scl_pad,
    output wire        sda_o,
    input  wire        sda_i,
    output wire        irq
);
    assign pready = 1'b1;

    reg [15:0] prescale;   // SCL = clk / (5 * prescale)
    reg [7:0]  tx_data;
    reg [7:0]  rx_data;
    reg        cmd_start;
    reg        cmd_stop;
    reg        cmd_read;
    reg        cmd_write;
    reg        cmd_ack;
    reg        busy;
    reg        ack_out;
    reg        done_irq;

    reg        scl_reg;
    reg        sda_reg;

    assign scl_pad = scl_reg;
    assign sda_o   = sda_reg;
    assign irq     = done_irq;

    // Prescaler / clock
    reg [15:0] presc_cnt;
    reg [1:0]  phase;   // 0=scl_lo, 1=scl_rise, 2=scl_hi, 3=scl_fall
    wire       phase_tick = (presc_cnt == 16'h0);

    // I2C state machine
    localparam IS_IDLE  = 3'd0;
    localparam IS_START = 3'd1;
    localparam IS_WRITE = 3'd2;
    localparam IS_READ  = 3'd3;
    localparam IS_ACK   = 3'd4;
    localparam IS_STOP  = 3'd5;

    reg [2:0] istate;
    reg [2:0] bit_idx;
    reg [7:0] shift;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            presc_cnt <= 16'h0;
            phase     <= 2'h0;
            scl_reg   <= 1'b1;
            sda_reg   <= 1'b1;
            istate    <= IS_IDLE;
            bit_idx   <= 3'h0;
            shift     <= 8'h0;
            busy      <= 1'b0;
            rx_data   <= 8'h0;
            ack_out   <= 1'b0;
            done_irq  <= 1'b0;
            cmd_start <= 1'b0;
            cmd_stop  <= 1'b0;
            cmd_read  <= 1'b0;
            cmd_write <= 1'b0;
            cmd_ack   <= 1'b0;
        end else begin
            // Prescaler
            if (presc_cnt == 16'h0) presc_cnt <= prescale;
            else                    presc_cnt <= presc_cnt - 16'h1;

            // APB Commands
            if (psel && penable) begin
                if (pwrite && (paddr[3:2] == 2'd2)) begin
                    {cmd_ack, cmd_stop, cmd_start, cmd_read, cmd_write} <= pwdata[4:0];
                    if (pwdata[0] || pwdata[1]) busy <= 1'b1;
                    done_irq <= 1'b0;
                end else if (!pwrite && (paddr[3:2] == 2'd2)) begin
                    done_irq <= 1'b0;
                end
            end

            case (istate)
                IS_IDLE: begin
                    scl_reg <= 1'b1;
                    sda_reg <= 1'b1;
                    if (cmd_write || cmd_read) begin
                        busy      <= 1'b1;
                        shift     <= tx_data;
                        bit_idx   <= 3'h7;
                        istate    <= cmd_start ? IS_START : (cmd_write ? IS_WRITE : IS_READ);
                        cmd_start <= 1'b0;
                        cmd_write <= 1'b0;
                        cmd_read  <= 1'b0;
                        phase     <= 2'h0;
                    end
                end

                IS_START: begin
                    if (phase_tick) begin
                        case (phase)
                            2'd0: sda_reg <= 1'b0;  // SDA low while SCL high (START)
                            2'd1: scl_reg <= 1'b0;  // SCL low
                            2'd2: ;
                            2'd3: istate <= IS_WRITE;
                        endcase
                        phase <= phase + 2'h1;
                    end
                end

                IS_WRITE: begin
                    if (phase_tick) begin
                        case (phase)
                            2'd0: sda_reg <= shift[7];
                            2'd1: scl_reg <= 1'b1;
                            2'd2: ;
                            2'd3: begin
                                scl_reg <= 1'b0;
                                shift   <= {shift[6:0], 1'b0};
                                if (bit_idx == 3'h0) begin
                                    istate  <= IS_ACK;
                                    bit_idx <= 3'h0;
                                end else begin
                                    bit_idx <= bit_idx - 3'h1;
                                end
                            end
                        endcase
                        phase <= phase + 2'h1;
                    end
                end

                IS_READ: begin
                    if (phase_tick) begin
                        case (phase)
                            2'd0: sda_reg <= 1'b1; // Release SDA
                            2'd1: begin
                                scl_reg <= 1'b1;
                                rx_data <= {rx_data[6:0], sda_i};
                            end
                            2'd2: ;
                            2'd3: begin
                                scl_reg <= 1'b0;
                                if (bit_idx == 3'h0) begin
                                    istate <= IS_ACK;
                                end else begin
                                    bit_idx <= bit_idx - 3'h1;
                                end
                            end
                        endcase
                        phase <= phase + 2'h1;
                    end
                end

                IS_ACK: begin
                    if (phase_tick) begin
                        case (phase)
                            2'd0: sda_reg <= 1'b1;  // Release SDA for ACK
                            2'd1: scl_reg <= 1'b1;
                            2'd2: ack_out <= (sda_i == 1'b0); // Sample ACK (active low)
                            2'd3: begin
                                scl_reg <= 1'b0;
                                if (cmd_stop) begin
                                    istate <= IS_STOP;
                                end else begin
                                    busy     <= 1'b0;
                                    done_irq <= 1'b1;
                                    istate   <= IS_IDLE;
                                end
                            end
                        endcase
                        phase <= phase + 2'h1;
                    end
                end

                IS_STOP: begin
                    if (phase_tick) begin
                        case (phase)
                            2'd0: sda_reg <= 1'b0;
                            2'd1: scl_reg <= 1'b1;
                            2'd2: sda_reg <= 1'b1; // Stop condition (SDA rising while SCL high)
                            2'd3: begin
                                istate   <= IS_IDLE;
                                cmd_stop <= 1'b0;
                                busy     <= 1'b0;
                                done_irq <= 1'b1;
                            end
                        endcase
                        phase <= phase + 2'h1;
                    end
                end

                default: istate <= IS_IDLE;
            endcase
        end
    end

    // APB Write Register Configuration
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            prescale <= 16'd99;  // 100MHz / (5*100) = 200kHz
            tx_data  <= 8'h0;
        end else if (psel && penable && pwrite) begin
            case (paddr[3:2])
                2'd0: prescale <= pwdata[15:0];
                2'd1: tx_data  <= pwdata[7:0];
                default: ;
            endcase
        end
    end

    // Combinational Zero Wait-State Read Data
    reg [31:0] prdata_comb;
    always @(*) begin
        case (paddr[3:2])
            2'd0: prdata_comb = {busy, 15'h0, prescale};
            2'd1: prdata_comb = {24'h0, rx_data};
            2'd2: prdata_comb = {31'h0, ack_out};
            default: prdata_comb = 32'h0;
        endcase
    end
    assign prdata = prdata_comb;

endmodule
