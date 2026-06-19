// 31 x 32-bit register file (x1..x31; x0 hardwired to 0, no storage).
// Async read, posedge synchronous write, single clock domain.
`timescale 1ns/1ps
module reg_file (
    input             clk,
    input             rf_en,
    input      [ 4:0] rs1,
    input      [ 4:0] rs2,
    input      [ 4:0] rd,
    input      [31:0] wdata,
    output reg [31:0] rdata1,
    output reg [31:0] rdata2
);
    // No entry for x0 -> avoids dead, never-written storage for register 0.
    reg [31:0] reg_mem [1:31];

    // asynchronous read (x0 reads 0 and never indexes reg_mem[0])
    always @(*) begin
        rdata1 = (rs1 == 5'b00000) ? 32'b0 : reg_mem[rs1];
        rdata2 = (rs2 == 5'b00000) ? 32'b0 : reg_mem[rs2];
    end

    // synchronous write : posedge (single clock domain). Same-cycle MW->DE
    // bypass for every consumer (ALU, branch, store-data, CSR-data) is handled
    // by the forwarding logic in processor.v.
    always @(posedge clk) begin
        if (rf_en && (rd != 5'b00000))
            reg_mem[rd] <= wdata;
    end
endmodule
