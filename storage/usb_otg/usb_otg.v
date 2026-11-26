// SPDX-License-Identifier: Apache-2.0
// SMVDU-TITAN-X SoC — USB 2.0 OTG Controller (with ULPI Interface)
// Iteration 3: Supports Device/Host mode with AXI4 DMA.
`timescale 1ns/1ps

module usb_otg #(
    parameter AW = 40,
    parameter DW = 64,
    parameter IDW = 4
) (
    input  wire        clk,      // System clock
    input  wire        rst_n,

    // ULPI Interface (to external PHY)
    input  wire        ulpi_clk, // 60 MHz from PHY
    inout  wire [7:0]  ulpi_data,
    input  wire        ulpi_dir,
    input  wire        ulpi_nxt,
    output reg         ulpi_stp,
    output wire        ulpi_reset,

    // AXI4 Master (Scatter-Gather DMA)
    output reg         m_awvalid,  input  wire        m_awready,
    output reg  [AW-1:0] m_awaddr, output wire [IDW-1:0] m_awid,
    output wire [7:0]  m_awlen,    output wire [2:0]  m_awsize,
    output reg         m_wvalid,   input  wire        m_wready,
    output reg  [DW-1:0] m_wdata,  output wire [DW/8-1:0] m_wstrb,
    output reg         m_wlast,
    input  wire        m_bvalid,   output wire        m_bready,
    input  wire [1:0]  m_bresp,    input  wire [IDW-1:0] m_bid,
    
    output reg         m_arvalid,  input  wire        m_arready,
    output reg  [AW-1:0] m_araddr, output wire [IDW-1:0] m_arid,
    output wire [7:0]  m_arlen,    output wire [2:0]  m_arsize,
    input  wire        m_rvalid,   output wire        m_rready,
    input  wire [DW-1:0] m_rdata,  input  wire [1:0]  m_rresp,
    input  wire        m_rlast,    input  wire [IDW-1:0] m_rid,

    // APB Slave (Control & Status Registers)
    input  wire [31:0] paddr,
    input  wire        psel,
    input  wire        penable,
    input  wire        pwrite,
    input  wire [31:0] pwdata,
    output wire [31:0] prdata,
    output wire        pready,
    output wire        pslverr,

    // Interrupt
    output wire        usb_irq
);

    // Static AXI4 master attributes
    assign m_awid   = {IDW{1'b0}};
    assign m_awlen  = 8'h0;
    assign m_awsize = 3'h3; // 64-bit
    assign m_wstrb  = {DW/8{1'b1}};
    assign m_bready = 1'b1;

    assign m_arid   = {IDW{1'b0}};
    assign m_arlen  = 8'h0;
    assign m_arsize = 3'h3; // 64-bit
    assign m_rready = 1'b1;

    // -------------------------------------------------------
    // APB Registers (EHCI/OTG compatible)
    // -------------------------------------------------------
    reg [31:0] usbcmd;
    reg [31:0] usbsts;
    reg [31:0] usbintr;
    reg [31:0] asynclistaddr;
    reg [31:0] portsc1;
    reg [31:0] otgsc;

    assign pready  = 1'b1;
    assign pslverr = 1'b0;

    reg tx_trigger_pulse;
    reg usb_done_pulse;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            usbcmd           <= 32'h0;
            usbsts           <= 32'h0;
            usbintr          <= 32'h0;
            asynclistaddr    <= 32'h0;
            portsc1          <= 32'h0;
            otgsc            <= 32'h0;
            tx_trigger_pulse <= 1'b0;
        end else begin
            tx_trigger_pulse <= 1'b0;
            if (usb_done_pulse) begin
                usbsts[0] <= 1'b1; // USBINT assert
            end

            if (psel && penable && pwrite) begin
                case (paddr[7:0])
                    8'h40: begin
                        usbcmd <= pwdata;
                        if (pwdata[0] || pwdata[4]) begin
                            tx_trigger_pulse <= 1'b1;
                        end
                    end
                    8'h44: usbsts        <= pwdata;
                    8'h48: usbintr       <= pwdata;
                    8'h58: asynclistaddr <= pwdata;
                    8'h84: portsc1       <= pwdata;
                    8'hA4: otgsc         <= pwdata;
                    default: ;
                endcase
            end
        end
    end

    reg [31:0] prdata_reg;
    always @(*) begin
        case (paddr[7:0])
            8'h40: prdata_reg = usbcmd;
            8'h44: prdata_reg = usbsts;
            8'h48: prdata_reg = usbintr;
            8'h58: prdata_reg = asynclistaddr;
            8'h84: prdata_reg = portsc1;
            8'hA4: prdata_reg = otgsc;
            default: prdata_reg = 32'h0;
        endcase
    end
    assign prdata = prdata_reg;

    assign usb_irq = |(usbsts & usbintr);

    // -------------------------------------------------------
    // ULPI Interface & DMA State Machine
    // -------------------------------------------------------
    reg [7:0]  ulpi_data_out;
    assign ulpi_data  = (ulpi_dir) ? 8'hzz : ulpi_data_out;
    assign ulpi_reset = ~rst_n;

    localparam USB_FSM_IDLE    = 3'd0;
    localparam USB_FSM_AR      = 3'd1;
    localparam USB_FSM_R       = 3'd2;
    localparam USB_FSM_TX_CMD  = 3'd3;
    localparam USB_FSM_TX_DATA = 3'd4;
    localparam USB_FSM_TX_STP  = 3'd5;
    localparam USB_FSM_DONE    = 3'd6;

    reg [2:0]  usb_fsm;
    reg [63:0] usb_tx_buf;
    reg [2:0]  usb_byte_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            usb_fsm          <= USB_FSM_IDLE;
            m_arvalid        <= 1'b0;
            m_araddr         <= {AW{1'b0}};
            m_awvalid        <= 1'b0;
            m_awaddr         <= {AW{1'b0}};
            m_wvalid         <= 1'b0;
            m_wdata          <= {DW{1'b0}};
            m_wlast          <= 1'b0;
            ulpi_stp         <= 1'b0;
            ulpi_data_out    <= 8'h00;
            usb_tx_buf       <= 64'h0;
            usb_byte_cnt     <= 3'd0;
            usb_done_pulse   <= 1'b0;
        end else begin
            usb_done_pulse <= 1'b0;

            case (usb_fsm)
                USB_FSM_IDLE: begin
                    ulpi_stp      <= 1'b0;
                    ulpi_data_out <= 8'h00;
                    if (tx_trigger_pulse && usbcmd[0]) begin // Run
                        m_arvalid <= 1'b1;
                        m_araddr  <= {{(AW-32){1'b0}}, asynclistaddr};
                        usb_fsm   <= USB_FSM_AR;
                    end
                end

                USB_FSM_AR: begin
                    if (m_arready) begin
                        m_arvalid <= 1'b0;
                        usb_fsm   <= USB_FSM_R;
                    end
                end

                USB_FSM_R: begin
                    if (m_rvalid) begin
                        usb_tx_buf    <= m_rdata;
                        ulpi_data_out <= 8'h4B; // USB DATA0 PID token
                        usb_byte_cnt  <= 3'd0;
                        usb_fsm       <= USB_FSM_TX_CMD;
                    end
                end

                USB_FSM_TX_CMD: begin
                    // Transmit USB command byte on ULPI
                    if (ulpi_nxt) begin
                        ulpi_data_out <= usb_tx_buf[7:0];
                        usb_tx_buf    <= {8'h00, usb_tx_buf[63:8]};
                        usb_byte_cnt  <= 3'd1;
                        usb_fsm       <= USB_FSM_TX_DATA;
                    end
                end

                USB_FSM_TX_DATA: begin
                    if (ulpi_nxt) begin
                        ulpi_data_out <= usb_tx_buf[7:0];
                        usb_tx_buf    <= {8'h00, usb_tx_buf[63:8]};
                        if (usb_byte_cnt == 3'd7) begin
                            ulpi_stp <= 1'b1; // Stop transfer on final byte
                            usb_fsm  <= USB_FSM_TX_STP;
                        end else begin
                            usb_byte_cnt <= usb_byte_cnt + 1'b1;
                        end
                    end
                end

                USB_FSM_TX_STP: begin
                    ulpi_stp      <= 1'b0;
                    ulpi_data_out <= 8'h00;
                    usb_fsm       <= USB_FSM_DONE;
                end

                USB_FSM_DONE: begin
                    usb_done_pulse <= 1'b1;
                    usb_fsm        <= USB_FSM_IDLE;
                end

                default: usb_fsm <= USB_FSM_IDLE;
            endcase
        end
    end

    // To prevent unused warnings
    wire _unused_ulpi = &{ulpi_clk};

endmodule
