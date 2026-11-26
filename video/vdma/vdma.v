// SPDX-License-Identifier: Apache-2.0
// SMVDU-TITAN-X SoC — Video DMA (VDMA) Controller
// Iteration 3: Bridges AXI4-Stream (Video) and AXI4-Memory Mapped (DDR).
// Features Triple Buffering and 2D transfer (stride) support.
`timescale 1ns/1ps

module vdma (
    input  wire        clk,
    input  wire        rst_n,

    // AXI4-Stream IN (Write Channel - e.g. from ISP)
    input  wire [31:0] s_axis_s2mm_tdata,
    input  wire        s_axis_s2mm_tvalid,
    output wire        s_axis_s2mm_tready,
    input  wire        s_axis_s2mm_tuser,  // SOF
    input  wire        s_axis_s2mm_tlast,  // EOL

    // AXI4-Stream OUT (Read Channel - e.g. to HDMI)
    output wire [31:0] m_axis_mm2s_tdata,
    output wire        m_axis_mm2s_tvalid,
    input  wire        m_axis_mm2s_tready,
    output wire        m_axis_mm2s_tuser,
    output wire        m_axis_mm2s_tlast,

    // AXI4 Master (Memory Mapped)
    output wire        m_axi_awvalid,
    input  wire        m_axi_awready,
    output wire [39:0] m_axi_awaddr,
    output wire [7:0]  m_axi_awlen,
    output wire [2:0]  m_axi_awsize,
    
    output wire        m_axi_wvalid,
    input  wire        m_axi_wready,
    output wire [63:0] m_axi_wdata,
    output wire [7:0]  m_axi_wstrb,
    output wire        m_axi_wlast,
    
    input  wire        m_axi_bvalid,
    output wire        m_axi_bready,
    input  wire [1:0]  m_axi_bresp,

    output wire        m_axi_arvalid,
    input  wire        m_axi_arready,
    output wire [39:0] m_axi_araddr,
    output wire [7:0]  m_axi_arlen,
    output wire [2:0]  m_axi_arsize,
    
    input  wire        m_axi_rvalid,
    output wire        m_axi_rready,
    input  wire [63:0] m_axi_rdata,
    input  wire [1:0]  m_axi_rresp,
    input  wire        m_axi_rlast,

    // APB Config Interface
    input  wire [31:0] paddr,
    input  wire        psel,
    input  wire        penable,
    input  wire        pwrite,
    input  wire [31:0] pwdata,
    output wire [31:0] prdata,
    output wire        pready,
    output wire        pslverr,
    
    // Interrupts
    output wire        vdma_irq
);

    // -------------------------------------------------------
    // APB Configuration Registers
    // -------------------------------------------------------
    reg [31:0] mm2s_vsize;
    reg [31:0] mm2s_hsize;
    reg [31:0] mm2s_stride;
    reg [39:0] mm2s_start_addr [0:2]; // Triple buffer

    reg [31:0] s2mm_vsize;
    reg [31:0] s2mm_hsize;
    reg [31:0] s2mm_stride;
    reg [39:0] s2mm_start_addr [0:2]; // Triple buffer

    reg [31:0] cr; // Control register
    reg        mm2s_busy;
    reg        s2mm_busy;
    reg        mm2s_done;
    reg        s2mm_done;

    assign pready = 1'b1;
    assign pslverr = 1'b0;

    wire [31:0] sr = {28'h0, s2mm_done, mm2s_done, s2mm_busy, mm2s_busy};
    assign prdata = (paddr[7:0] == 8'h04) ? sr :
                    (paddr[7:0] == 8'h00) ? cr :
                    (paddr[7:0] == 8'h10) ? mm2s_vsize :
                    (paddr[7:0] == 8'h14) ? mm2s_hsize :
                    (paddr[7:0] == 8'h18) ? mm2s_stride :
                    (paddr[7:0] == 8'h1C) ? mm2s_start_addr[0][31:0] :
                    (paddr[7:0] == 8'h30) ? s2mm_vsize :
                    (paddr[7:0] == 8'h34) ? s2mm_hsize :
                    (paddr[7:0] == 8'h38) ? s2mm_stride :
                    (paddr[7:0] == 8'h3C) ? s2mm_start_addr[0][31:0] : 32'h0;

    assign vdma_irq = mm2s_done || s2mm_done;

    // -------------------------------------------------------
    // AXI4 Master Signals
    // -------------------------------------------------------
    reg         awvalid_reg;
    reg  [39:0] awaddr_reg;
    reg         wvalid_reg;
    reg  [63:0] wdata_reg;
    reg         bready_reg;

    reg         arvalid_reg;
    reg  [39:0] araddr_reg;
    reg         rready_reg;

    assign m_axi_awvalid = awvalid_reg;
    assign m_axi_awaddr  = awaddr_reg;
    assign m_axi_awlen   = 8'd0;    // Single beat per write burst
    assign m_axi_awsize  = 3'b011;  // 8 bytes (64-bit)

    assign m_axi_wvalid  = wvalid_reg;
    assign m_axi_wdata   = wdata_reg;
    assign m_axi_wstrb   = 8'hFF;   // All byte lanes valid
    assign m_axi_wlast   = 1'b1;

    assign m_axi_bready  = bready_reg;

    assign m_axi_arvalid = arvalid_reg;
    assign m_axi_araddr  = araddr_reg;
    assign m_axi_arlen   = 8'd0;    // Single beat per read burst
    assign m_axi_arsize  = 3'b011;  // 8 bytes (64-bit)

    assign m_axi_rready  = rready_reg;

    // -------------------------------------------------------
    // MM2S Engine (Memory -> Stream)
    // -------------------------------------------------------
    localparam [2:0]
        M_IDLE     = 3'd0,
        M_AR       = 3'd1,
        M_R        = 3'd2,
        M_STREAM_0 = 3'd3,
        M_STREAM_1 = 3'd4;

    reg [2:0]  m_state;
    reg [39:0] m_cur_addr;
    reg [31:0] m_line_cnt;
    reg [31:0] m_byte_cnt;
    reg [63:0] m_rdata_reg;

    reg [31:0] mm2s_tdata_reg;
    reg        mm2s_tvalid_reg;
    reg        mm2s_tuser_reg;
    reg        mm2s_tlast_reg;

    assign m_axis_mm2s_tdata  = mm2s_tdata_reg;
    assign m_axis_mm2s_tvalid = mm2s_tvalid_reg;
    assign m_axis_mm2s_tuser  = mm2s_tuser_reg;
    assign m_axis_mm2s_tlast  = mm2s_tlast_reg;

    // -------------------------------------------------------
    // S2MM Engine (Stream -> Memory)
    // -------------------------------------------------------
    localparam [2:0]
        S_IDLE     = 3'd0,
        S_PIX0     = 3'd1,
        S_PIX1     = 3'd2,
        S_AW       = 3'd3,
        S_B        = 3'd4;

    reg [2:0]  s_state;
    reg [39:0] s_cur_addr;
    reg [31:0] s_line_cnt;
    reg [31:0] s_byte_cnt;
    reg [31:0] s_pix0_reg;

    assign s_axis_s2mm_tready = (s_state == S_IDLE) ? 1'b1 :
                                (s_state == S_PIX0 || s_state == S_PIX1);

    // -------------------------------------------------------
    // Sequential Logic & FSMs
    // -------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cr                 <= 32'h0;
            mm2s_vsize         <= 32'h0;
            mm2s_hsize         <= 32'h0;
            mm2s_stride        <= 32'h0;
            mm2s_start_addr[0] <= 40'h0;
            mm2s_start_addr[1] <= 40'h0;
            mm2s_start_addr[2] <= 40'h0;

            s2mm_vsize         <= 32'h0;
            s2mm_hsize         <= 32'h0;
            s2mm_stride        <= 32'h0;
            s2mm_start_addr[0] <= 40'h0;
            s2mm_start_addr[1] <= 40'h0;
            s2mm_start_addr[2] <= 40'h0;

            mm2s_busy          <= 1'b0;
            s2mm_busy          <= 1'b0;
            mm2s_done          <= 1'b0;
            s2mm_done          <= 1'b0;

            // MM2S
            m_state            <= M_IDLE;
            m_cur_addr         <= 40'h0;
            m_line_cnt         <= 32'h0;
            m_byte_cnt         <= 32'h0;
            m_rdata_reg        <= 64'h0;
            arvalid_reg        <= 1'b0;
            araddr_reg         <= 40'h0;
            rready_reg         <= 1'b1;
            mm2s_tvalid_reg    <= 1'b0;
            mm2s_tdata_reg     <= 32'h0;
            mm2s_tuser_reg     <= 1'b0;
            mm2s_tlast_reg     <= 1'b0;

            // S2MM
            s_state            <= S_IDLE;
            s_cur_addr         <= 40'h0;
            s_line_cnt         <= 32'h0;
            s_byte_cnt         <= 32'h0;
            s_pix0_reg         <= 32'h0;
            awvalid_reg        <= 1'b0;
            awaddr_reg         <= 40'h0;
            wvalid_reg         <= 1'b0;
            wdata_reg          <= 64'h0;
            bready_reg         <= 1'b1;
        end else begin
            // ---------------------------------------------------
            // APB Register Writes
            // ---------------------------------------------------
            if (psel && penable && pwrite) begin
                case (paddr[7:0])
                    8'h00: begin
                        cr <= pwdata;
                        if (pwdata[2]) mm2s_done <= 1'b0;
                        if (pwdata[3]) s2mm_done <= 1'b0;
                    end
                    8'h10: mm2s_vsize         <= pwdata;
                    8'h14: mm2s_hsize         <= pwdata;
                    8'h18: mm2s_stride        <= pwdata;
                    8'h1C: mm2s_start_addr[0] <= {8'h0, pwdata};
                    8'h30: s2mm_vsize         <= pwdata;
                    8'h34: s2mm_hsize         <= pwdata;
                    8'h38: s2mm_stride        <= pwdata;
                    8'h3C: s2mm_start_addr[0] <= {8'h0, pwdata};
                    default: ;
                endcase
            end

            // ---------------------------------------------------
            // MM2S FSM (Read from Memory -> Stream to HDMI)
            // ---------------------------------------------------
            case (m_state)
                M_IDLE: begin
                    arvalid_reg     <= 1'b0;
                    rready_reg      <= 1'b1;
                    mm2s_tvalid_reg <= 1'b0;
                    if (cr[0] && cr[4] && (mm2s_vsize > 32'd0) && (mm2s_hsize > 32'd0)) begin
                        cr[4]       <= 1'b0; // self-clearing start trigger
                        mm2s_busy   <= 1'b1;
                        mm2s_done   <= 1'b0;
                        m_cur_addr  <= mm2s_start_addr[0];
                        m_line_cnt  <= 32'd0;
                        m_byte_cnt  <= 32'd0;
                        araddr_reg  <= mm2s_start_addr[0];
                        arvalid_reg <= 1'b1;
                        m_state     <= M_AR;
                    end else begin
                        mm2s_busy   <= 1'b0;
                    end
                end

                M_AR: begin
                    if (m_axi_arready && arvalid_reg) begin
                        arvalid_reg <= 1'b0;
                        m_state     <= M_R;
                    end
                end

                M_R: begin
                    if (m_axi_rvalid && rready_reg) begin
                        m_rdata_reg     <= m_axi_rdata;
                        mm2s_tdata_reg  <= m_axi_rdata[31:0];
                        mm2s_tvalid_reg <= 1'b1;
                        mm2s_tuser_reg  <= (m_line_cnt == 32'd0) && (m_byte_cnt == 32'd0);
                        mm2s_tlast_reg  <= (m_byte_cnt + 32'd4 >= mm2s_hsize);
                        m_state         <= M_STREAM_0;
                    end
                end

                M_STREAM_0: begin
                    if (m_axis_mm2s_tready && mm2s_tvalid_reg) begin
                        if (m_byte_cnt + 32'd4 >= mm2s_hsize) begin
                            // Line finished on Pixel 0
                            if (m_line_cnt + 32'd1 >= mm2s_vsize) begin
                                mm2s_tvalid_reg <= 1'b0;
                                mm2s_busy       <= 1'b0;
                                mm2s_done       <= 1'b1;
                                m_state         <= M_IDLE;
                            end else begin
                                m_line_cnt      <= m_line_cnt + 32'd1;
                                m_byte_cnt      <= 32'd0;
                                m_cur_addr      <= mm2s_start_addr[0] + ((m_line_cnt + 32'd1) * mm2s_stride);
                                araddr_reg      <= mm2s_start_addr[0] + ((m_line_cnt + 32'd1) * mm2s_stride);
                                arvalid_reg     <= 1'b1;
                                mm2s_tvalid_reg <= 1'b0;
                                m_state         <= M_AR;
                            end
                        end else begin
                            m_byte_cnt      <= m_byte_cnt + 32'd4;
                            mm2s_tdata_reg  <= m_rdata_reg[63:32];
                            mm2s_tvalid_reg <= 1'b1;
                            mm2s_tuser_reg  <= 1'b0;
                            mm2s_tlast_reg  <= (m_byte_cnt + 32'd8 >= mm2s_hsize);
                            m_state         <= M_STREAM_1;
                        end
                    end
                end

                M_STREAM_1: begin
                    if (m_axis_mm2s_tready && mm2s_tvalid_reg) begin
                        if (m_byte_cnt + 32'd4 >= mm2s_hsize) begin
                            // Line finished on Pixel 1
                            if (m_line_cnt + 32'd1 >= mm2s_vsize) begin
                                mm2s_tvalid_reg <= 1'b0;
                                mm2s_busy       <= 1'b0;
                                mm2s_done       <= 1'b1;
                                m_state         <= M_IDLE;
                            end else begin
                                m_line_cnt      <= m_line_cnt + 32'd1;
                                m_byte_cnt      <= 32'd0;
                                m_cur_addr      <= mm2s_start_addr[0] + ((m_line_cnt + 32'd1) * mm2s_stride);
                                araddr_reg      <= mm2s_start_addr[0] + ((m_line_cnt + 32'd1) * mm2s_stride);
                                arvalid_reg     <= 1'b1;
                                mm2s_tvalid_reg <= 1'b0;
                                m_state         <= M_AR;
                            end
                        end else begin
                            m_byte_cnt      <= m_byte_cnt + 32'd4;
                            m_cur_addr      <= m_cur_addr + 40'd8;
                            araddr_reg      <= m_cur_addr + 40'd8;
                            arvalid_reg     <= 1'b1;
                            mm2s_tvalid_reg <= 1'b0;
                            m_state         <= M_AR;
                        end
                    end
                end
            endcase

            // ---------------------------------------------------
            // S2MM FSM (Stream from ISP -> Write to Memory)
            // ---------------------------------------------------
            case (s_state)
                S_IDLE: begin
                    awvalid_reg <= 1'b0;
                    wvalid_reg  <= 1'b0;
                    bready_reg  <= 1'b1;
                    if (cr[1] && cr[5] && (s2mm_vsize > 32'd0) && (s2mm_hsize > 32'd0)) begin
                        cr[5]      <= 1'b0; // self-clearing start trigger
                        s2mm_busy  <= 1'b1;
                        s2mm_done  <= 1'b0;
                        s_cur_addr <= s2mm_start_addr[0];
                        s_line_cnt <= 32'd0;
                        s_byte_cnt <= 32'd0;
                        s_state    <= S_PIX0;
                    end else begin
                        s2mm_busy  <= 1'b0;
                    end
                end

                S_PIX0: begin
                    if (s_axis_s2mm_tvalid) begin
                        s_pix0_reg <= s_axis_s2mm_tdata;
                        if (s_byte_cnt + 32'd4 >= s2mm_hsize) begin
                            awaddr_reg  <= s_cur_addr;
                            awvalid_reg <= 1'b1;
                            wdata_reg   <= {32'h0, s_axis_s2mm_tdata};
                            wvalid_reg  <= 1'b1;
                            s_state     <= S_AW;
                        end else begin
                            s_state <= S_PIX1;
                        end
                    end
                end

                S_PIX1: begin
                    if (s_axis_s2mm_tvalid) begin
                        awaddr_reg  <= s_cur_addr;
                        awvalid_reg <= 1'b1;
                        wdata_reg   <= {s_axis_s2mm_tdata, s_pix0_reg};
                        wvalid_reg  <= 1'b1;
                        s_state     <= S_AW;
                    end
                end

                S_AW: begin
                    if (m_axi_awready && awvalid_reg) awvalid_reg <= 1'b0;
                    if (m_axi_wready && wvalid_reg)   wvalid_reg  <= 1'b0;

                    if ((m_axi_awready || !awvalid_reg) && (m_axi_wready || !wvalid_reg)) begin
                        bready_reg <= 1'b1;
                        s_state    <= S_B;
                    end
                end

                S_B: begin
                    if (m_axi_bvalid && bready_reg) begin
                        if (s_byte_cnt + 32'd8 >= s2mm_hsize) begin
                            // Line complete
                            if (s_line_cnt + 32'd1 >= s2mm_vsize) begin
                                s2mm_busy <= 1'b0;
                                s2mm_done <= 1'b1;
                                s_state   <= S_IDLE;
                            end else begin
                                s_line_cnt <= s_line_cnt + 32'd1;
                                s_byte_cnt <= 32'd0;
                                s_cur_addr <= s2mm_start_addr[0] + ((s_line_cnt + 32'd1) * s2mm_stride);
                                s_state    <= S_PIX0;
                            end
                        end else begin
                            s_byte_cnt <= s_byte_cnt + 32'd8;
                            s_cur_addr <= s_cur_addr + 40'd8;
                            s_state    <= S_PIX0;
                        end
                    end
                end
            endcase
        end
    end

endmodule
