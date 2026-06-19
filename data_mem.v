// 100-byte data memory, big-endian, async read / sync write
`timescale 1ns/1ps
module data_mem (
    input             clk,
    input             rd_en,
    input             wr_en,
    input      [31:0] addr,
    input      [ 2:0] mem_acc_mode,
    input      [31:0] wdata,
    output reg [31:0] rdata
);
    parameter BYTE              = 3'b000;
    parameter HALFWORD          = 3'b001;
    parameter WORD              = 3'b010;
    parameter BYTE_UNSIGNED     = 3'b011;
    parameter HALFWORD_UNSIGNED = 3'b100;

    reg [7:0] data_mem [0:99];

    // asynchronous read (default added -> no latch)
    always @(*) begin
        rdata = 32'b0;
        if (rd_en) begin
            case (mem_acc_mode)
                BYTE:              rdata = $signed(data_mem[addr]);
                HALFWORD:          rdata = $signed({data_mem[addr], data_mem[addr+1]});
                WORD:              rdata = $signed({data_mem[addr], data_mem[addr+1], data_mem[addr+2], data_mem[addr+3]});
                BYTE_UNSIGNED:     rdata = {24'b0, data_mem[addr]};
                HALFWORD_UNSIGNED: rdata = {16'b0, data_mem[addr], data_mem[addr+1]};
                default:           rdata = 32'b0;
            endcase
        end
    end

    // synchronous write
    always @(posedge clk) begin
        if (wr_en) begin
            case (mem_acc_mode)
                BYTE:     data_mem[addr] <= wdata[7:0];
                HALFWORD: begin
                    data_mem[addr  ] <= wdata[15:8];
                    data_mem[addr+1] <= wdata[ 7:0];
                end
                WORD: begin
                    data_mem[addr  ] <= wdata[31:24];
                    data_mem[addr+1] <= wdata[23:16];
                    data_mem[addr+2] <= wdata[15: 8];
                    data_mem[addr+3] <= wdata[ 7: 0];
                end
                default: ;
            endcase
        end
    end
endmodule
