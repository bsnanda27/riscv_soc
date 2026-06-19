// Synthesis/LEC BLACK-BOX stub for the instruction ROM.
// Real $readmem ROM (inst_mem.v) lives with the testbench, not here.
`timescale 1ns/1ps
module inst_mem (
    input  [31:0] addr,
    output [31:0] data      // intentionally undriven: black-box boundary
);
endmodule
