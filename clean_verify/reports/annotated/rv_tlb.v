//      // verilator_coverage annotation
        // SPDX-License-Identifier: Apache-2.0
        // SMVDU-TITAN-X SoC — Sv39 Translation Lookaside Buffer
        // Iteration 3: 32-entry, 4-way set-associative, ASID-tagged
        // Shared between I-MMU and D-MMU (or split 16+16)
        // Sv39: VPN[2](9) → VPN[1](9) → VPN[0](9) → PPN(44) + offset(12)
        `timescale 1ns/1ps
        `include "params.vh"
        `include "isa_pkg.vh"
        
        module rv_tlb #(
            parameter WAYS    = `TLB_WAYS,   // 4-way set-associative
            parameter SETS    = `TLB_SETS,   // 8 sets → 32 entries
            parameter ASID_W  = `ASID_WIDTH, // 16-bit ASID
            parameter VA_W    = `VADDR_WIDTH, // 39-bit virtual address
            parameter PA_W    = `PADDR_WIDTH  // 38-bit physical address
        )(
            input  wire            clk,
            input  wire            rst_n,
        
            // Lookup port
            input  wire [VA_W-1:0] va_in,       // Virtual address to translate
            input  wire [ASID_W-1:0] asid_in,   // Current ASID from satp
            input  wire            req_valid,   // Translation request
        
            // Lookup result (combinational)
            output wire [PA_W-1:0] pa_out,      // Physical address (PPN + offset)
            output wire            hit,         // TLB hit
            output wire            perm_r,      // Read permission
            output wire            perm_w,      // Write permission
            output wire            perm_x,      // Execute permission
            output wire            perm_u,      // User-mode accessible
            output wire            page_fault,  // Permission violation
        
            // Fill port (from Page Table Walker)
            input  wire            fill_valid,  // PTW has a new translation to install
            input  wire [VA_W-1:0] fill_va,
            input  wire [PA_W-1:0] fill_pa,    // Physical page number (38-bit)
            input  wire [ASID_W-1:0] fill_asid,
            input  wire [7:0]      fill_perm,  // PTE permission bits [7:0]: D,A,G,U,X,W,R,V
            input  wire [1:0]      fill_level, // Page level: 0=4KB, 1=2MB mega, 2=1GB giga
        
            // SFENCE.VMA invalidation
            input  wire            sfence_vma,  // Flush entire TLB
            input  wire            sfence_asid, // Flush TLB by ASID only
            input  wire [ASID_W-1:0] sfence_asid_val,
            input  wire            sfence_va,   // Flush by VA+ASID
            input  wire [VA_W-1:0] sfence_va_val,
        
            // Access type (for permission checking)
            input  wire            access_r,
            input  wire            access_w,
            input  wire            access_x,
            input  wire            priv_s       // Supervisor mode (0=User)
        );
        
            // -------------------------------------------------------
            // TLB Entry Format
            // -------------------------------------------------------
            // valid(1) + global(1) + asid(16) + vpn(27) + ppn(44) + perm(8) + level(2)
            // Total: 1+1+16+27+44+8+2 = 99 bits per entry
            localparam VPN_W   = 27;  // Three 9-bit VPN levels
            localparam PPN_W   = PA_W - 12;  // Physical page number (38-bit PA / 4KB page = 26 bits)
        
            reg              tlb_valid [0:SETS-1][0:WAYS-1];
            reg              tlb_global[0:SETS-1][0:WAYS-1];
            reg [ASID_W-1:0] tlb_asid  [0:SETS-1][0:WAYS-1];
            reg [VPN_W-1:0]  tlb_vpn   [0:SETS-1][0:WAYS-1];
            reg [PPN_W-1:0]  tlb_ppn   [0:SETS-1][0:WAYS-1];
            reg [7:0]        tlb_perm  [0:SETS-1][0:WAYS-1]; // D,A,G,U,X,W,R,V
            reg [1:0]        tlb_level [0:SETS-1][0:WAYS-1]; // 0=4KB, 1=2MB, 2=1GB
            // PLRU state: 3 bits for 4-way PLRU
            reg [2:0]        tlb_plru  [0:SETS-1];
        
            // Index into TLB: bits [5:3] of VPN[0] (using lower VA bits after page offset)
            localparam SET_BITS = 3;  // log2(SETS)
            wire [SET_BITS-1:0] set_idx = va_in[SET_BITS+11:12]; // VA[14:12]
            wire [VPN_W-1:0]    va_vpn  = va_in[VA_W-1:12];      // VPN[2:0] concatenated
        
            wire [SET_BITS-1:0] fill_set_idx = fill_va[SET_BITS+11:12];
            wire [VPN_W-1:0]    fill_vpn     = fill_va[VA_W-1:12];
        
            // -------------------------------------------------------
            // Lookup: combinational across sets and ways for superpages
            // -------------------------------------------------------
            wire [SETS-1:0] way_hit [0:WAYS-1];
            wire [PPN_W-1:0] way_ppn [0:SETS-1][0:WAYS-1];
            wire [7:0]       way_perm [0:SETS-1][0:WAYS-1];
            wire [1:0]       way_lvl  [0:SETS-1][0:WAYS-1];
        
            genvar s, w;
            generate
                for (s = 0; s < SETS; s = s + 1) begin : gen_tlb_s
                    for (w = 0; w < WAYS; w = w + 1) begin : gen_tlb_w
                        wire vpn_match = (tlb_level[s][w] == 2'd2) ? (tlb_vpn[s][w][26:18] == va_vpn[26:18]) :
                                         (tlb_level[s][w] == 2'd1) ? (tlb_vpn[s][w][26:9]  == va_vpn[26:9]) :
                                         ((s == set_idx) && (tlb_vpn[s][w] == va_vpn));
                        assign way_hit[w][s] = tlb_valid[s][w] && vpn_match &&
                                               (tlb_global[s][w] || (tlb_asid[s][w] == asid_in));
                        assign way_ppn[s][w]  = tlb_ppn[s][w];
                        assign way_perm[s][w] = tlb_perm[s][w];
                        assign way_lvl[s][w]  = tlb_level[s][w];
                    end
                end
            endgenerate
        
            reg                hit_r;
            reg [PPN_W-1:0]    hit_ppn_r;
            reg [7:0]          hit_perm_r;
            reg [1:0]          hit_level_r;
            reg [1:0]          hit_way_r;
            reg [SET_BITS-1:0] hit_set_r;
        
            integer lk_s, lk_w;
 000144     always @(*) begin
 000144         hit_r       = 1'b0;
 000144         hit_ppn_r   = {PPN_W{1'b0}};
 000144         hit_perm_r  = 8'h0;
 000144         hit_level_r = 2'd0;
 000144         hit_way_r   = 2'd0;
 000144         hit_set_r   = {SET_BITS{1'b0}};
 000144         for (lk_s = 0; lk_s < SETS; lk_s = lk_s + 1) begin
 001152             for (lk_w = 0; lk_w < WAYS; lk_w = lk_w + 1) begin
 001413                 if (way_hit[lk_w][lk_s]) begin
 001413                     hit_r       = 1'b1;
 001413                     hit_ppn_r   = way_ppn[lk_s][lk_w];
 001413                     hit_perm_r  = way_perm[lk_s][lk_w];
 001413                     hit_level_r = way_lvl[lk_s][lk_w];
 001413                     hit_way_r   = lk_w[1:0];
 001413                     hit_set_r   = lk_s[SET_BITS-1:0];
                        end
                    end
                end
            end
        
            assign hit = hit_r;
            wire [PPN_W-1:0]    hit_ppn     = hit_ppn_r;
            wire [7:0]          hit_perm    = hit_perm_r;
            wire [1:0]          hit_level   = hit_level_r;
            wire [1:0]          hit_way_enc = hit_way_r;
            wire [SET_BITS-1:0] hit_set_idx = hit_set_r;
        
            // Physical address = PPN concatenated with page offset according to page level:
            // Level 2 (1GB): PPN[25:18] (8 bits) + VA[29:0] (30 bits) = 38-bit PA
            // Level 1 (2MB): PPN[25:9] (17 bits) + VA[20:0] (21 bits) = 38-bit PA
            // Level 0 (4KB): PPN[25:0] (26 bits) + VA[11:0] (12 bits) = 38-bit PA
            assign pa_out   = (hit_level == 2'd2) ? {hit_ppn[PA_W-13:18], va_in[29:0]} :
                              (hit_level == 2'd1) ? {hit_ppn[PA_W-13:9],  va_in[20:0]} :
                                                    {hit_ppn[PA_W-13:0],  va_in[11:0]};
            assign perm_r   = hit_perm[1];  // R bit
            assign perm_w   = hit_perm[2];  // W bit
            assign perm_x   = hit_perm[3];  // X bit
            assign perm_u   = hit_perm[4];  // U bit
        
            // Permission fault detection
            wire access_fault = hit && req_valid && (
                (access_r && !perm_r) ||
                (access_w && !perm_w) ||
                (access_x && !perm_x) ||
                // Supervisor accessing user page without sstatus.SUM
                (priv_s && perm_u)
            );
            assign page_fault = access_fault;
        
            // -------------------------------------------------------
            // PLRU Replacement: 4-way
            // State encoding: {mru_bit, left_half_mru, right_half_mru}
            // plru[2]=0 means left (ways 0,1) recently used
            // plru[2]=1 means right (ways 2,3) recently used
            // plru[1] = which of way 0/1 was MRU (0=way0, 1=way1)
            // plru[0] = which of way 2/3 was MRU (0=way2, 1=way3)
            // -------------------------------------------------------
            wire [1:0] plru_victim;
            assign plru_victim = !tlb_plru[fill_set_idx][2] ? 
                                  // Left half (ways 0,1): pick non-MRU
                                  (!tlb_plru[fill_set_idx][1] ? 2'd0 : 2'd1) :
                                  // Right half (ways 2,3): pick non-MRU
                                  (!tlb_plru[fill_set_idx][0] ? 2'd2 : 2'd3);
        
        
        
            // -------------------------------------------------------
            // Fill and Invalidation Logic
            // -------------------------------------------------------
            integer si, wi;
 6241096     always @(posedge clk or negedge rst_n) begin
 1733040         if (!rst_n) begin
 1733040             for (si = 0; si < SETS; si = si + 1) begin
 13864320                 tlb_plru[si] <= 3'h0;
 13864320                 for (wi = 0; wi < WAYS; wi = wi + 1) begin
 55457280                     tlb_valid[si][wi] <= 1'b0;
 55457280                     tlb_global[si][wi]<= 1'b0;
                        end
                    end
 4508056         end else begin
                    // SFENCE.VMA: global flush
%000006             if (sfence_vma) begin
%000006                 for (si = 0; si < SETS; si = si + 1)
 000048                     for (wi = 0; wi < WAYS; wi = wi + 1)
%000002                         if (!tlb_global[si][wi])  // Keep global entries
 000190                             tlb_valid[si][wi] <= 1'b0;
                    end
                    // SFENCE by ASID
%000004             else if (sfence_asid) begin
%000004                 for (si = 0; si < SETS; si = si + 1)
 000032                     for (wi = 0; wi < WAYS; wi = wi + 1)
 000128                         if (tlb_asid[si][wi] == sfence_asid_val && !tlb_global[si][wi])
%000000                             tlb_valid[si][wi] <= 1'b0;
                    end
                    // SFENCE by VA+ASID
 000272             else if (sfence_va) begin
 000272                 for (si = 0; si < SETS; si = si + 1)
 002176                     for (wi = 0; wi < WAYS; wi = wi + 1)
 000064                         if ((tlb_asid[si][wi] == sfence_asid_val || tlb_global[si][wi]) &&
                                    (tlb_vpn[si][wi] == sfence_va_val[VA_W-1:12]))
 000064                             tlb_valid[si][wi] <= 1'b0;
                    end
                    // Fill from PTW
%000003             else if (fill_valid) begin
                        // Install at victim way
%000003                 tlb_valid [fill_set_idx][plru_victim] <= 1'b1;
%000003                 tlb_global[fill_set_idx][plru_victim] <= fill_perm[5]; // G bit
%000003                 tlb_asid  [fill_set_idx][plru_victim] <= fill_asid;
%000003                 tlb_vpn   [fill_set_idx][plru_victim] <= fill_vpn;
%000003                 tlb_ppn   [fill_set_idx][plru_victim] <= fill_pa[PA_W-1:12];
%000003                 tlb_perm  [fill_set_idx][plru_victim] <= fill_perm;
%000003                 tlb_level [fill_set_idx][plru_victim] <= fill_level;
                        // Update PLRU to mark this way as MRU
%000003                 case (plru_victim)
%000003                     2'd0: tlb_plru[fill_set_idx] <= {1'b0, 1'b0, tlb_plru[fill_set_idx][0]};
%000000                     2'd1: tlb_plru[fill_set_idx] <= {1'b0, 1'b1, tlb_plru[fill_set_idx][0]};
%000000                     2'd2: tlb_plru[fill_set_idx] <= {1'b1, tlb_plru[fill_set_idx][1], 1'b0};
%000000                     2'd3: tlb_plru[fill_set_idx] <= {1'b1, tlb_plru[fill_set_idx][1], 1'b1};
                        endcase
 000220             end else if (hit && req_valid) begin
                        // Update PLRU on hit
 000220                 case (hit_way_enc)
 000220                     2'd0: tlb_plru[hit_set_idx] <= {1'b0, 1'b0, tlb_plru[hit_set_idx][0]};
%000000                     2'd1: tlb_plru[hit_set_idx] <= {1'b0, 1'b1, tlb_plru[hit_set_idx][0]};
%000000                     2'd2: tlb_plru[hit_set_idx] <= {1'b1, tlb_plru[hit_set_idx][1], 1'b0};
%000000                     2'd3: tlb_plru[hit_set_idx] <= {1'b1, tlb_plru[hit_set_idx][1], 1'b1};
                        endcase
                    end
                end
            end
        
        endmodule
        
