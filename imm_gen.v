// Immediate generator (default added to keep it latch-free; behaviour preserved)
`timescale 1ns/1ps
module imm_gen (
    input      [31:0] inst,
    output reg [31:0] imm_val
);
    always @(*) begin
        imm_val = 32'b0;                          // default -> no latch
        case (inst[6:0])
            7'b0010011: begin                     // I-type ALU
                case (inst[14:12])
                    3'b011:  imm_val = $signed(inst[31:20]);     // SLTIU: sign-extend (unsigned compare done in ALU)
                    3'b001:  imm_val = {27'b0, inst[24:20]};     // SLLI shamt
                    3'b101:  imm_val = {27'b0, inst[24:20]};     // SRLI/SRAI shamt
                    default: imm_val = $signed(inst[31:20]);     // ADDI/SLTI/XORI/ORI/ANDI
                endcase
            end
            7'b0100011: imm_val = $signed({inst[31:25], inst[11:7]});                        // S-type
            7'b1100011: imm_val = $signed({inst[31], inst[7], inst[30:25], inst[11:8], 1'b0}); // B-type
            7'b0110111: imm_val = {inst[31:12], 12'b0};                                      // U-type (LUI)
            7'b0010111: imm_val = {inst[31:12], 12'b0};                                      // U-type (AUIPC)
            7'b1101111: imm_val = $signed({inst[31], inst[19:12], inst[20], inst[30:21], 1'b0}); // J-type (JAL)
            7'b1100111: imm_val = $signed(inst[31:20]);                                      // I-type (JALR)
            7'b0000011: imm_val = $signed(inst[31:20]);                                      // Load: sign-extend
            default:    imm_val = 32'b0;
        endcase
    end
endmodule
