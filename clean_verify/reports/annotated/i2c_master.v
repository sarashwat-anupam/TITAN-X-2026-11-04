//      // verilator_coverage annotation
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
        
 780137     always @(posedge clk or negedge rst_n) begin
 000540         if (!rst_n) begin
 000540             presc_cnt <= 16'h0;
 000540             phase     <= 2'h0;
 000540             scl_reg   <= 1'b1;
 000540             sda_reg   <= 1'b1;
 000540             istate    <= IS_IDLE;
 000540             bit_idx   <= 3'h0;
 000540             shift     <= 8'h0;
 000540             busy      <= 1'b0;
 000540             rx_data   <= 8'h0;
 000540             ack_out   <= 1'b0;
 000540             done_irq  <= 1'b0;
 000540             cmd_start <= 1'b0;
 000540             cmd_stop  <= 1'b0;
 000540             cmd_read  <= 1'b0;
 000540             cmd_write <= 1'b0;
 000540             cmd_ack   <= 1'b0;
 779597         end else begin
                    // Prescaler
 009652             if (presc_cnt == 16'h0) presc_cnt <= prescale;
 769945             else                    presc_cnt <= presc_cnt - 16'h1;
        
                    // APB Commands
 000026             if (psel && penable) begin
%000002                 if (pwrite && (paddr[3:2] == 2'd2)) begin
%000002                     {cmd_ack, cmd_stop, cmd_start, cmd_read, cmd_write} <= pwdata[4:0];
%000000                     if (pwdata[0] || pwdata[1]) busy <= 1'b1;
%000002                     done_irq <= 1'b0;
%000002                 end else if (!pwrite && (paddr[3:2] == 2'd2)) begin
%000002                     done_irq <= 1'b0;
                        end
                    end
        
 779597             case (istate)
 779359                 IS_IDLE: begin
 779359                     scl_reg <= 1'b1;
 779359                     sda_reg <= 1'b1;
%000002                     if (cmd_write || cmd_read) begin
%000002                         busy      <= 1'b1;
%000002                         shift     <= tx_data;
%000002                         bit_idx   <= 3'h7;
%000002                         istate    <= cmd_start ? IS_START : (cmd_write ? IS_WRITE : IS_READ);
%000002                         cmd_start <= 1'b0;
%000002                         cmd_write <= 1'b0;
%000002                         cmd_read  <= 1'b0;
%000002                         phase     <= 2'h0;
                            end
                        end
        
 000012                 IS_START: begin
%000004                     if (phase_tick) begin
%000004                         case (phase)
%000001                             2'd0: sda_reg <= 1'b0;  // SDA low while SCL high (START)
%000001                             2'd1: scl_reg <= 1'b0;  // SCL low
%000001                             2'd2: ;
%000001                             2'd3: istate <= IS_WRITE;
                                endcase
%000004                         phase <= phase + 2'h1;
                            end
                        end
        
 000190                 IS_WRITE: begin
 000064                     if (phase_tick) begin
 000064                         case (phase)
 000016                             2'd0: sda_reg <= shift[7];
 000016                             2'd1: scl_reg <= 1'b1;
 000016                             2'd2: ;
 000016                             2'd3: begin
 000016                                 scl_reg <= 1'b0;
 000016                                 shift   <= {shift[6:0], 1'b0};
%000002                                 if (bit_idx == 3'h0) begin
%000002                                     istate  <= IS_ACK;
%000002                                     bit_idx <= 3'h0;
 000014                                 end else begin
 000014                                     bit_idx <= bit_idx - 3'h1;
                                        end
                                    end
                                endcase
 000064                         phase <= phase + 2'h1;
                            end
                        end
        
%000000                 IS_READ: begin
%000000                     if (phase_tick) begin
%000000                         case (phase)
%000000                             2'd0: sda_reg <= 1'b1; // Release SDA
%000000                             2'd1: begin
%000000                                 scl_reg <= 1'b1;
%000000                                 rx_data <= {rx_data[6:0], sda_i};
                                    end
%000000                             2'd2: ;
%000000                             2'd3: begin
%000000                                 scl_reg <= 1'b0;
%000000                                 if (bit_idx == 3'h0) begin
%000000                                     istate <= IS_ACK;
%000000                                 end else begin
%000000                                     bit_idx <= bit_idx - 3'h1;
                                        end
                                    end
                                endcase
%000000                         phase <= phase + 2'h1;
                            end
                        end
        
 000024                 IS_ACK: begin
%000008                     if (phase_tick) begin
%000008                         case (phase)
%000002                             2'd0: sda_reg <= 1'b1;  // Release SDA for ACK
%000002                             2'd1: scl_reg <= 1'b1;
%000002                             2'd2: ack_out <= (sda_i == 1'b0); // Sample ACK (active low)
%000002                             2'd3: begin
%000002                                 scl_reg <= 1'b0;
%000001                                 if (cmd_stop) begin
%000001                                     istate <= IS_STOP;
%000001                                 end else begin
%000001                                     busy     <= 1'b0;
%000001                                     done_irq <= 1'b1;
%000001                                     istate   <= IS_IDLE;
                                        end
                                    end
                                endcase
%000008                         phase <= phase + 2'h1;
                            end
                        end
        
 000012                 IS_STOP: begin
%000004                     if (phase_tick) begin
%000004                         case (phase)
%000001                             2'd0: sda_reg <= 1'b0;
%000001                             2'd1: scl_reg <= 1'b1;
%000001                             2'd2: sda_reg <= 1'b1; // Stop condition (SDA rising while SCL high)
%000001                             2'd3: begin
%000001                                 istate   <= IS_IDLE;
%000001                                 cmd_stop <= 1'b0;
%000001                                 busy     <= 1'b0;
%000001                                 done_irq <= 1'b1;
                                    end
                                endcase
%000004                         phase <= phase + 2'h1;
                            end
                        end
        
%000000                 default: istate <= IS_IDLE;
                    endcase
                end
            end
        
            // APB Write Register Configuration
 780137     always @(posedge clk or negedge rst_n) begin
 000540         if (!rst_n) begin
 000540             prescale <= 16'd99;  // 100MHz / (5*100) = 200kHz
 000540             tx_data  <= 8'h0;
%000005         end else if (psel && penable && pwrite) begin
%000005             case (paddr[3:2])
%000001                 2'd0: prescale <= pwdata[15:0];
%000002                 2'd1: tx_data  <= pwdata[7:0];
%000002                 default: ;
                    endcase
                end
            end
        
            // Combinational Zero Wait-State Read Data
            reg [31:0] prdata_comb;
 000018     always @(*) begin
 000018         case (paddr[3:2])
 676903             2'd0: prdata_comb = {busy, 15'h0, prescale};
 092543             2'd1: prdata_comb = {24'h0, rx_data};
 006887             2'd2: prdata_comb = {31'h0, ack_out};
 003822             default: prdata_comb = 32'h0;
                endcase
            end
            assign prdata = prdata_comb;
        
        endmodule
        
