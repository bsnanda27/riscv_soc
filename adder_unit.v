`timescale 1ns/1ps

// ALU add/sub front-end : result = sub ? (a-b) : (a+b)  using CSLA-BEC
module adder_unit (
    input  [31:0] a,
    input  [31:0] b,
    input         sub,
    output [31:0] result
);
    wire [31:0] b_mod;
    wire        cin;
    assign b_mod = sub ? ~b : b;       // two's-complement: a + ~b + 1
    assign cin   = sub;
    rv32i_csla_bec_32_ add_csla (
        .a   (a),
        .b   (b_mod),
        .cin (cin),
        .sum (result),
        .cout()
    );
endmodule
