// ALU : ADD (0000) and SUB (0001) now go through the CSLA-BEC adder_unit.
// All other ops behaviourally identical to the original RTL.
module alu (
    input      [ 3:0] aluop,
    input      [31:0] opr_a,
    input      [31:0] opr_b,
    output reg [31:0] opr_res
);
    // CSLA-BEC add/sub front-end
    wire        alu_sub;
    wire [31:0] add_sub_res;
    assign alu_sub = (aluop == 4'b0001);          // 1 => subtract
    adder_unit u_adder (
        .a      (opr_a),
        .b      (opr_b),
        .sub    (alu_sub),
        .result (add_sub_res)
    );

    always @(*) begin
        opr_res = 32'b0;                          // default -> no latch
        case (aluop)
            4'b0000: opr_res = add_sub_res;                                   // ADD  (CSLA)
            4'b0001: opr_res = add_sub_res;                                   // SUB  (CSLA)
            4'b0010: opr_res = opr_a              << opr_b[4:0];               // SLL  (shamt = [4:0])
            4'b0011: opr_res = ($signed(opr_a)   <  $signed(opr_b))   ? 32'd1 : 32'd0; // SLT  (signed)
            4'b0100: opr_res = ($unsigned(opr_a) <  $unsigned(opr_b)) ? 32'd1 : 32'd0; // SLTU (unsigned)
            4'b0101: opr_res = opr_a              ^  opr_b;                     // XOR
            4'b0110: opr_res = opr_a              >> opr_b[4:0];               // SRL  (logical,    shamt = [4:0])
            4'b0111: opr_res = $signed(opr_a)     >>> opr_b[4:0];             // SRA  (arithmetic, shamt = [4:0])
            4'b1000: opr_res = opr_a              |  opr_b;                     // OR
            4'b1001: opr_res = opr_a              &  opr_b;                     // AND
            4'b1010: opr_res = opr_b;                                         // pass opr_b (LUI)
            default: opr_res = 32'b0;
        endcase
    end
endmodule
