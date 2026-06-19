`timescale 1ns/1ps
//============================================================
// 4-bit CSLA-BEC block
//============================================================
module csla_bec_block (
    input  [3:0] a,
    input  [3:0] b,
    input        cin,
    output [3:0] sum,
    output       cout
);
    // RCA assuming carry = 0
    wire [3:0] sum0;
    wire       c1,c2,c3,c4;
    assign sum0[0] = a[0] ^ b[0];
    assign c1      = a[0] & b[0];
    assign sum0[1] = a[1] ^ b[1] ^ c1;
    assign c2      = (a[1]&b[1]) | (a[1]&c1) | (b[1]&c1);
    assign sum0[2] = a[2] ^ b[2] ^ c2;
    assign c3      = (a[2]&b[2]) | (a[2]&c2) | (b[2]&c2);
    assign sum0[3] = a[3] ^ b[3] ^ c3;
    assign c4      = (a[3]&b[3]) | (a[3]&c3) | (b[3]&c3);

    // BEC (sum0 + 1)
    wire [4:0] bec;
    assign bec[0] = ~sum0[0];
    assign bec[1] = sum0[1] ^ sum0[0];
    assign bec[2] = sum0[2] ^ (sum0[1] & sum0[0]);
    assign bec[3] = sum0[3] ^ (sum0[2] & sum0[1] & sum0[0]);
    assign bec[4] = c4      ^ (sum0[3] & sum0[2] & sum0[1] & sum0[0]);

    // carry-select MUX
    assign sum[0] = cin ? bec[0] : sum0[0];
    assign sum[1] = cin ? bec[1] : sum0[1];
    assign sum[2] = cin ? bec[2] : sum0[2];
    assign sum[3] = cin ? bec[3] : sum0[3];
    assign cout   = cin ? bec[4] : c4;
endmodule
