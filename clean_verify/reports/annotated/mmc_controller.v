//      // verilator_coverage annotation
        // SPDX-License-Identifier: Apache-2.0
        // SMVDU-TITAN-X SoC — eMMC 5.1 / SD 3.0 Host Controller
        // Iteration 3: Supports AXI4 Master DMA and APB config.
        `timescale 1ns/1ps
        
        module mmc_controller #(
            parameter AW = 40,
            parameter DW = 64,
            parameter IDW = 4
        ) (
            input  wire        clk,
            input  wire        rst_n,
        
            // AXI4 Master (DMA for block transfers)
            output wire        m_awvalid,  input  wire        m_awready,
            output wire [AW-1:0] m_awaddr, output wire [IDW-1:0] m_awid,
            output wire [7:0]  m_awlen,    output wire [2:0]  m_awsize,
            output wire        m_wvalid,   input  wire        m_wready,
            output wire [DW-1:0] m_wdata,  output wire [DW/8-1:0] m_wstrb,
            output wire        m_wlast,
            input  wire        m_bvalid,   output wire        m_bready,
            input  wire [1:0]  m_bresp,    input  wire [IDW-1:0] m_bid,
            
            output wire        m_arvalid,  input  wire        m_arready,
            output wire [AW-1:0] m_araddr, output wire [IDW-1:0] m_arid,
            output wire [7:0]  m_arlen,    output wire [2:0]  m_arsize,
            input  wire        m_rvalid,   output wire        m_rready,
            input  wire [DW-1:0] m_rdata,  input  wire [1:0]  m_rresp,
            input  wire        m_rlast,    input  wire [IDW-1:0] m_rid,
        
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
            output wire        mmc_irq,
        
            // SD/eMMC Physical Interface
            output wire        sd_clk,
            inout  wire        sd_cmd,
            inout  wire [7:0]  sd_dat, // 4-bit for SD, 8-bit for eMMC
            output wire        sd_reset_n
        );
        
            // -------------------------------------------------------
            // SD Host Controller Standard (SDHC) Registers Stub
            // -------------------------------------------------------
            reg [31:0] sdmasysad; // System Address
            reg [31:0] blkattr;   // Block Size & Count
            reg [31:0] arg1;      // Argument
            reg [31:0] trnmod_cmd;// Transfer Mode & Command
            reg [31:0] resp_0_1;  // Response 0-1
            reg [31:0] pres_state;// Present State
        
            assign pready = 1'b1;
            assign pslverr = 1'b0;
        
 780137     always @(posedge clk or negedge rst_n) begin
 000540         if (!rst_n) begin
 000540             sdmasysad <= 32'h0;
 000540             blkattr   <= 32'h0;
 000540             arg1      <= 32'h0;
 000540             trnmod_cmd<= 32'h0;
 000540             resp_0_1  <= 32'h0;
 000540             pres_state<= 32'h0000_0000;
 779597         end else if (psel && penable && pwrite) begin
%000000             case (paddr[7:0])
%000000                 8'h00: sdmasysad <= pwdata;
%000000                 8'h04: blkattr <= pwdata;
%000000                 8'h08: arg1 <= pwdata;
%000000                 8'h0C: trnmod_cmd <= pwdata;
%000000                 default: ;
                    endcase
                end
            end
            
            reg [31:0] prdata_reg;
 000018     always @(*) begin
 000018         case (paddr[7:0])
 674807             8'h00: prdata_reg = sdmasysad;
 084043             8'h04: prdata_reg = blkattr;
 001236             8'h08: prdata_reg = arg1;
 002383             8'h0C: prdata_reg = trnmod_cmd;
 000749             8'h10: prdata_reg = resp_0_1;
 000214             8'h24: prdata_reg = pres_state;
 016723             default: prdata_reg = 32'h0;
                endcase
            end
            assign prdata = prdata_reg;
        
            // -------------------------------------------------------
            // DMA Engine Stub
            // -------------------------------------------------------
            assign m_awvalid = 1'b0;
            assign m_awaddr  = {AW{1'b0}};
            assign m_awid    = {IDW{1'b0}};
            assign m_awlen   = 8'h0;
            assign m_awsize  = 3'h3;
            assign m_wvalid  = 1'b0;
            assign m_wdata   = {DW{1'b0}};
            assign m_wstrb   = {DW/8{1'b0}};
            assign m_wlast   = 1'b0;
            assign m_bready  = 1'b1;
            
            assign m_arvalid = 1'b0;
            assign m_araddr  = {AW{1'b0}};
            assign m_arid    = {IDW{1'b0}};
            assign m_arlen   = 8'h0;
            assign m_arsize  = 3'h3;
            assign m_rready  = 1'b1;
        
            // -------------------------------------------------------
            // PHY Interface Stub
            // -------------------------------------------------------
            assign sd_clk = clk;
            assign sd_cmd = 1'bz;
            assign sd_dat = 8'hzz;
            assign sd_reset_n = rst_n;
            
            assign mmc_irq = 1'b0;
        
        endmodule
        
