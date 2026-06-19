`timescale 1ns/1ps
module mux_2x1 (
    input      [31:0] in_0,
    input      [31:0] in_1,
    input             select_line,
    output reg [31:0] out
);
    always @(*) begin
        case (select_line)
            1'b1:    out = in_1;
            1'b0:    out = in_0;
            default: out = in_0;
        endcase
    end
endmodule
