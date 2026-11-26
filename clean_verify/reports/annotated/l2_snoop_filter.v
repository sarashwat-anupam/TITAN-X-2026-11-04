//      // verilator_coverage annotation
        // SPDX-License-Identifier: Apache-2.0
        // SMVDU-TITAN-X SoC — L2 Snoop Filter (MESI Directory)
        // Iteration 4: Tracks L1 D-Cache coherence state for 4 application cores.
        // Coherence Protocol: MESI with Set Saturation Victim Eviction & Back-Invalidation.
        `timescale 1ns/1ps
        `include "params.vh"
        
        module l2_snoop_filter #(
            parameter NUM_CORES = 4,
            parameter ADDR_W    = 40,
            parameter TAG_W     = 28,  // Depends on L1 cache geometry (e.g., 64 sets, 64B line)
            parameter INDEX_W   = 6,
            parameter WAYS      = 8
        )(
            input  wire        clk,
            input  wire        rst_n,
        
            // Crossbar / L2 Controller snooping request
            input  wire        req_valid,
            input  wire [39:0] req_addr,
            input  wire [1:0]  req_type,   // 00=ReadShared, 01=ReadUnique, 10=CleanInvalidate, 11=MakeInvalid
            input  wire [1:0]  req_core,   // Requesting core ID (0-3)
        
            // Snoop output to L1 D-Caches
            output reg  [NUM_CORES-1:0] snoop_valid,
            output reg  [39:0]          snoop_addr,
            output reg  [1:0]           snoop_type, // 00=GetS (downgrade to S), 01=GetM (inv), 10=Inv
            input  wire [NUM_CORES-1:0] snoop_ack,
            input  wire [NUM_CORES-1:0] snoop_data_valid,
        
            // Snoop filter response to L2 Controller
            output reg         resp_valid,
            output reg         resp_hit,
            output reg         resp_dirty,
            output reg [1:0]   resp_owner // Core ID holding Modified state
        );
        
            // -------------------------------------------------------
            // Directory Array
            // Tracks MESI state and owner/sharer mask for each L1 line.
            // Unified array: 64 sets × 32 ways (8 ways * 4 cores)
            // -------------------------------------------------------
            reg [ADDR_W-1:0] req_addr_saved;
        `ifdef FORMAL
            localparam DIR_SETS = 2;
            localparam DIR_WAYS = 2;
            wire [0:0] index = req_addr_saved[6];
        `else
        `ifdef SYNTHESIS
            localparam DIR_SETS = 2;
            localparam DIR_WAYS = 2;
            wire [0:0] index = req_addr_saved[6];
        `else
            localparam DIR_SETS = 64;
            localparam DIR_WAYS = 32;
            wire [INDEX_W-1:0] index = req_addr_saved[11:6];
        `endif
        `endif
            wire [TAG_W-1:0]   tag   = req_addr_saved[39:12];
        
            // State encoding (MESI)
            localparam ST_I = 2'b00; // Invalid
            localparam ST_S = 2'b01; // Shared
            localparam ST_E = 2'b10; // Exclusive
            localparam ST_M = 2'b11; // Modified
        
            // Directory entry: {State[1:0], SharerMask[3:0], Tag[27:0]}
            reg [1:0]  dir_state [0:DIR_SETS-1][0:DIR_WAYS-1];
            reg [3:0]  dir_mask  [0:DIR_SETS-1][0:DIR_WAYS-1];
            reg [27:0] dir_tag   [0:DIR_SETS-1][0:DIR_WAYS-1];
        
            // Round-robin replacement pointer per directory set
            reg [4:0]  replace_ptr [0:DIR_SETS-1];
        
            // -------------------------------------------------------
            // FSM
            // -------------------------------------------------------
            localparam IDLE       = 3'd0;
            localparam LOOKUP     = 3'd1;
            localparam SNOOP_REQ  = 3'd2;
            localparam SNOOP_ACK  = 3'd3;
            localparam UPDATE     = 3'd4;
            localparam EVICT_WAIT = 3'd5;
        
            reg [2:0] state;
            reg [3:0] hit_mask;
            reg [4:0] hit_way;
            reg       line_hit;
            reg [1:0] line_state;
            reg [1:0] req_core_saved;
            reg [1:0] req_type_saved;
            reg [3:0] target_snoop_mask;
            reg [4:0] chosen_way;
            reg [3:0] ack_accum;
            reg       dirty_accum;
        
            // Combinational lookup logic
            reg       combo_line_hit;
            reg [4:0] combo_hit_way;
            reg [1:0] combo_line_state;
            reg [3:0] combo_hit_mask;
            integer ki;
        
 000018     always @* begin
 000018         combo_line_hit = 1'b0;
 000018         combo_hit_way = 5'd0;
 000018         combo_line_state = ST_I;
 000018         combo_hit_mask = 4'h0;
 000018         for (ki = 0; ki < DIR_WAYS; ki = ki + 1) begin
 561289             if ((dir_state[index][ki] != ST_I) && (dir_tag[index][ki] == tag)) begin
 561289                 combo_line_hit = 1'b1;
 561289                 combo_hit_way = ki[4:0];
 561289                 combo_line_state = dir_state[index][ki];
 561289                 combo_hit_mask = dir_mask[index][ki];
                    end
                end
            end
        
            // Combinational free way detection
            reg       has_free_way;
            reg [4:0] free_way;
            integer ai;
 000018     always @* begin
 000018         has_free_way = 1'b0;
 000018         free_way     = 5'd0;
 000018         for (ai = DIR_WAYS - 1; ai >= 0; ai = ai - 1) begin
 2809389             if (dir_state[index][ai] == ST_I) begin
 22155571                 has_free_way = 1'b1;
 22155571                 free_way     = ai[4:0];
                    end
                end
            end
        
            // Combinational victim selection
            wire [4:0]  victim_way_comb  = replace_ptr[index];
            wire [3:0]  victim_mask_comb = dir_mask[index][victim_way_comb];
            wire [27:0] victim_tag_comb  = dir_tag[index][victim_way_comb];
        
            integer s_i, w_i;
        
 780137     always @(posedge clk or negedge rst_n) begin
 000540         if (!rst_n) begin
 000540             state <= IDLE;
 000540             snoop_valid <= 4'h0;
 000540             snoop_addr  <= 40'h0;
 000540             snoop_type  <= 2'b00;
 000540             resp_valid <= 1'b0;
 000540             resp_hit <= 1'b0;
 000540             resp_dirty <= 1'b0;
 000540             resp_owner <= 2'b00;
 000540             line_hit <= 1'b0;
 000540             hit_mask <= 4'h0;
 000540             hit_way <= 5'h0;
 000540             chosen_way <= 5'h0;
 000540             line_state <= ST_I;
 000540             req_core_saved <= 2'h0;
 000540             req_type_saved <= 2'h0;
 000540             req_addr_saved <= {ADDR_W{1'b0}};
 000540             target_snoop_mask <= 4'h0;
 000540             ack_accum <= 4'h0;
 000540             dirty_accum <= 1'b0;
 000540             for (s_i = 0; s_i < DIR_SETS; s_i = s_i + 1) begin
 034560                 replace_ptr[s_i] = 5'd0;
 034560                 for (w_i = 0; w_i < DIR_WAYS; w_i = w_i + 1) begin
 1105920                     dir_state[s_i][w_i] = ST_I;
 1105920                     dir_mask[s_i][w_i]  = 4'h0;
 1105920                     dir_tag[s_i][w_i]   = 28'h0;
                        end
                    end
 779597         end else begin
 779597             resp_valid <= 1'b0;
 779597             snoop_valid <= 4'h0;
        
 779597             case (state)
 727447                 IDLE: begin
 025064                     if (req_valid) begin
 025064                         req_core_saved <= req_core;
 025064                         req_type_saved <= req_type;
 025064                         req_addr_saved <= req_addr;
 025064                         state <= LOOKUP;
                            end
                        end
        
 025063                 LOOKUP: begin
 025063                     line_hit   <= combo_line_hit;
 025063                     hit_way    <= combo_hit_way;
 025063                     line_state <= combo_line_state;
 025063                     hit_mask   <= combo_hit_mask;
        
 000875                     if (!combo_line_hit || (combo_line_state == ST_I)) begin
                                // Directory Miss: Check if an empty way exists in this set
%000000                         if (has_free_way) begin
 000875                             chosen_way <= free_way;
 000875                             resp_valid <= 1'b1;
 000875                             resp_hit   <= 1'b0;
 000875                             resp_dirty <= 1'b0;
 000875                             state      <= UPDATE;
%000000                         end else begin
                                    // Set Saturation: Evict victim via back-invalidation
%000000                             chosen_way <= victim_way_comb;
%000000                             if (victim_way_comb >= 5'd31)
%000000                                 replace_ptr[index] <= 5'd0;
                                    else
%000000                                 replace_ptr[index] <= victim_way_comb + 5'd1;
        
%000000                             if (victim_mask_comb != 4'h0) begin
%000000                                 snoop_valid       <= victim_mask_comb;
%000000                                 snoop_addr        <= {victim_tag_comb, index, 6'h0};
%000000                                 snoop_type        <= 2'b10; // Invalidate
%000000                                 target_snoop_mask <= victim_mask_comb;
%000000                                 ack_accum         <= 4'h0;
%000000                                 dirty_accum       <= 1'b0;
%000000                                 state             <= EVICT_WAIT;
%000000                             end else begin
                                        // Entry valid but no sharers
%000000                                 dir_state[index][victim_way_comb] <= ST_I;
%000000                                 resp_valid <= 1'b1;
%000000                                 resp_hit   <= 1'b0;
%000000                                 resp_dirty <= 1'b0;
%000000                                 state      <= UPDATE;
                                    end
                                end
 024188                     end else begin
                                // Hit: determine if snoop is needed
 017877                         if (combo_line_state == ST_M || combo_line_state == ST_E) begin
                                    // Someone else has it exclusively, must snoop
 000584                             if (combo_hit_mask != (1 << req_core_saved)) begin
 000584                                 snoop_valid       <= combo_hit_mask;
 000584                                 snoop_addr        <= {tag, index, 6'h0};
 000584                                 snoop_type        <= (req_type_saved == 2'b00) ? 2'b00 : 2'b01; // GetS vs GetM
 000584                                 target_snoop_mask <= combo_hit_mask;
 000584                                 ack_accum         <= 4'h0;
 000584                                 dirty_accum       <= 1'b0;
 000584                                 state <= SNOOP_REQ;
 017293                             end else begin
                                        // It is us, no snoop needed
 017293                                 resp_valid <= 1'b1;
 017293                                 resp_hit <= 1'b1;
 017293                                 resp_dirty <= 1'b0;
 017293                                 resp_owner <= req_core_saved;
 017293                                 state <= UPDATE;
                                    end
%000000                         end else if (combo_line_state == ST_S) begin
 000428                             if (req_type_saved == 2'b01 || req_type_saved == 2'b10) begin
                                        // Write request to shared line: invalidate others
%000000                                 if ((combo_hit_mask & ~(1 << req_core_saved)) != 4'h0) begin
 000428                                     snoop_valid       <= combo_hit_mask & ~(1 << req_core_saved);
 000428                                     snoop_addr        <= {tag, index, 6'h0};
 000428                                     snoop_type        <= 2'b10; // Inv
 000428                                     target_snoop_mask <= combo_hit_mask & ~(1 << req_core_saved);
 000428                                     ack_accum         <= 4'h0;
 000428                                     dirty_accum       <= 1'b0;
 000428                                     state <= SNOOP_REQ;
%000000                                 end else begin
%000000                                     resp_valid <= 1'b1;
%000000                                     resp_hit <= 1'b1;
%000000                                     resp_dirty <= 1'b0;
%000000                                     state <= UPDATE;
                                        end
 005883                             end else begin
                                        // Read shared: just add to sharers
 005883                                 resp_valid <= 1'b1;
 005883                                 resp_hit <= 1'b1;
 005883                                 resp_dirty <= 1'b0;
 005883                                 state <= UPDATE;
                                    end
                                end
                            end
                        end
        
 002024                 SNOOP_REQ: begin
                            // Wait for all snooped cores to ack (support independent / staggered acks)
 001012                     if ((ack_accum | (snoop_ack & target_snoop_mask)) == target_snoop_mask) begin
 001012                         resp_valid  <= 1'b1;
 001012                         resp_hit    <= 1'b1;
 001012                         resp_dirty  <= dirty_accum | (|(snoop_data_valid & target_snoop_mask));
 001012                         resp_owner  <= req_core_saved;
 001012                         snoop_valid <= 4'h0;
 001012                         ack_accum   <= 4'h0;
 001012                         dirty_accum <= 1'b0;
 001012                         state       <= UPDATE;
 001012                     end else begin
 001012                         ack_accum   <= ack_accum | (snoop_ack & target_snoop_mask);
 001012                         dirty_accum <= dirty_accum | (|(snoop_data_valid & target_snoop_mask));
 001012                         snoop_valid <= target_snoop_mask & ~(ack_accum | (snoop_ack & target_snoop_mask)); // Keep requesting un-acked
                            end
                        end
        
%000000                 EVICT_WAIT: begin
                            // Wait for all snooped L1 cores to ack the victim back-invalidation (support independent / staggered acks)
%000000                     if ((ack_accum | (snoop_ack & target_snoop_mask)) == target_snoop_mask) begin
%000000                         snoop_valid                  <= 4'h0;
%000000                         dir_state[index][chosen_way] <= ST_I;
%000000                         dir_mask[index][chosen_way]  <= 4'h0;
%000000                         resp_valid                   <= 1'b1;
%000000                         resp_hit                     <= 1'b0;
%000000                         resp_dirty                   <= dirty_accum | (|(snoop_data_valid & target_snoop_mask));
%000000                         ack_accum                    <= 4'h0;
%000000                         dirty_accum                  <= 1'b0;
%000000                         state                        <= UPDATE;
%000000                     end else begin
%000000                         ack_accum   <= ack_accum | (snoop_ack & target_snoop_mask);
%000000                         dirty_accum <= dirty_accum | (|(snoop_data_valid & target_snoop_mask));
%000000                         snoop_valid <= target_snoop_mask & ~(ack_accum | (snoop_ack & target_snoop_mask)); // Keep requesting un-acked
                            end
                        end
        
 025063                 UPDATE: begin
                            // Update directory state based on req_type and previous state
 000875                     if (!line_hit) begin
                                // Allocate new line into chosen_way
 000875                         dir_tag[index][chosen_way]   <= tag;
 000875                         dir_mask[index][chosen_way]  <= (1 << req_core_saved);
 000875                         dir_state[index][chosen_way] <= (req_type_saved == 2'b00) ? ST_E :
 000875                                                         (req_type_saved == 2'b01) ? ST_M : ST_I;
 024188                     end else begin
                                // Update existing line at hit_way
 009084                         if (req_type_saved == 2'b01) begin // ReadUnique/Write
 009084                             dir_state[index][hit_way] <= ST_M;
 009084                             dir_mask[index][hit_way] <= (1 << req_core_saved);
 015104                         end else if (req_type_saved == 2'b00) begin // ReadShared
 000506                             if ((line_state == ST_M || line_state == ST_E) && (hit_mask != (1 << req_core_saved))) begin
 000506                                 dir_state[index][hit_way] <= ST_S;
 000506                                 dir_mask[index][hit_way] <= hit_mask | (1 << req_core_saved);
 005883                             end else if (line_state == ST_S) begin
 005883                                 dir_mask[index][hit_way] <= hit_mask | (1 << req_core_saved);
                                    end
%000000                         end else if (req_type_saved == 2'b10) begin // Evict/Invalidate
%000000                             dir_mask[index][hit_way] <= hit_mask & ~(1 << req_core_saved);
%000000                             if ((hit_mask & ~(1 << req_core_saved)) == 4'h0) begin
%000000                                 dir_state[index][hit_way] <= ST_I;
                                    end
                                end
                            end
 025063                     state <= IDLE;
                        end
        
%000000                 default: state <= IDLE;
                    endcase
                end
            end
        
        endmodule
        
