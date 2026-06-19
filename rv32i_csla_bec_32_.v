//============================================================
// 32-bit Carry Select Adder using BEC (low area / low power)
//============================================================
`timescale 1ns/1ps
module rv32i_csla_bec_32_ (
    input  [31:0] a,
    input  [31:0] b,
    input         cin,
    output [31:0] sum,
    output        cout
);
    // First 4-bit RCA
    wire [3:0] s0;
    wire       c1;
    wire       c0_1, c0_2, c0_3;
    assign s0[0] = a[0] ^ b[0] ^ cin;
    assign c0_1  = (a[0]&b[0]) | (a[0]&cin) | (b[0]&cin);
    assign s0[1] = a[1] ^ b[1] ^ c0_1;
    assign c0_2  = (a[1]&b[1]) | (a[1]&c0_1) | (b[1]&c0_1);
    assign s0[2] = a[2] ^ b[2] ^ c0_2;
    assign c0_3  = (a[2]&b[2]) | (a[2]&c0_2) | (b[2]&c0_2);
    assign s0[3] = a[3] ^ b[3] ^ c0_3;
    assign c1    = (a[3]&b[3]) | (a[3]&c0_3) | (b[3]&c0_3);
    assign sum[3:0] = s0;

    // Seven 4-bit CSLA-BEC blocks
    wire [3:0] s1,s2,s3,s4,s5,s6,s7;
    wire       c2,c3,c4,c5,c6,c7,c8;
    csla_bec_block blk1(a[7:4]  , b[7:4]  , c1, s1, c2);
    csla_bec_block blk2(a[11:8] , b[11:8] , c2, s2, c3);
    csla_bec_block blk3(a[15:12], b[15:12], c3, s3, c4);
    csla_bec_block blk4(a[19:16], b[19:16], c4, s4, c5);
    csla_bec_block blk5(a[23:20], b[23:20], c5, s5, c6);
    csla_bec_block blk6(a[27:24], b[27:24], c6, s6, c7);
    csla_bec_block blk7(a[31:28], b[31:28], c7, s7, c8);

    assign sum[7:4]   = s1;
    assign sum[11:8]  = s2;
    assign sum[15:12] = s3;
    assign sum[19:16] = s4;
    assign sum[23:20] = s5;
    assign sum[27:24] = s6;
    assign sum[31:28] = s7;
    assign cout = c8;
endmodule
