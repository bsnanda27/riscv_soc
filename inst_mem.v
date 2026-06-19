// Instruction memory : 32-bit word x 100, word-addressed (addr[31:2])
module inst_mem (
    input      [31:0] addr,
    output reg [31:0] data
);
    reg [31:0] mem [0:99];
    always @(*) begin
        data = mem[addr[31:2]];
    end
endmodule
