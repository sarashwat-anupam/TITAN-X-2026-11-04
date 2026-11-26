//      // verilator_coverage annotation
        module sync_cell (
            input  wire clk,
            input  wire rst_n,
            input  wire d,
            output reg  q
        );
            reg q1;
 780137     always @(posedge clk or negedge rst_n) begin
%000000         if (!rst_n) begin
%000000             q1 <= 1'b0;
%000000             q  <= 1'b0;
 780137         end else begin
 780137             q1 <= d;
 780137             q  <= q1;
                end
            end
        endmodule
        
