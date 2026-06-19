`timescale 1ns/1ps
// Main controller / decoder. Global defaults at top keep every output latch-free;
// each opcode branch then drives the same values as the original RTL.
module controller (
    input      [6:0] opcode,
    input      [2:0] funct3,
    input      [6:0] funct7,
    input            br_taken,        // from br_cond block
    output reg [3:0] aluop,
    output reg       rf_en,
    output reg       sel_a,
    output reg       sel_b,
    output reg       rd_en,
    output reg       wr_en,
    output reg [1:0] wb_sel,
    output reg [2:0] mem_acc_mode,
    output reg [2:0] br_type,
    output reg       br_take,
    output reg       csr_rd,
    output reg       csr_wr,
    output reg       is_mret
);
    always @(*) begin
        // ---- global defaults (== original 'default' opcode branch) ----
        aluop        = 4'b0000;
        rf_en        = 1'b0;
        sel_a        = 1'b1;
        sel_b        = 1'b0;
        rd_en        = 1'b0;
        wr_en        = 1'b0;
        wb_sel       = 2'b01;
        br_take      = 1'b0;
        mem_acc_mode = 3'b111;
        br_type      = 3'b011;
        csr_rd       = 1'b0;
        csr_wr       = 1'b0;
        is_mret      = 1'b0;

        case (opcode)
            7'b0110011: begin // R-type
                rf_en = 1'b1; sel_a = 1'b1; sel_b = 1'b0; rd_en = 1'b0; wb_sel = 2'b01; wr_en = 1'b0;
                br_take = 1'b0; mem_acc_mode = 3'b111; br_type = 3'b011; csr_rd = 1'b0; csr_wr = 1'b0; is_mret = 1'b0;
                case (funct3)
                    3'b000: case (funct7)
                                7'b0000000: aluop = 4'b0000; // ADD
                                7'b0100000: aluop = 4'b0001; // SUB
                                default:    aluop = 4'b0000;
                            endcase
                    3'b001: aluop = 4'b0010; // SLL
                    3'b010: aluop = 4'b0011; // SLT
                    3'b011: aluop = 4'b0100; // SLTU
                    3'b100: aluop = 4'b0101; // XOR
                    3'b101: case (funct7)
                                7'b0000000: aluop = 4'b0110; // SRL
                                7'b0100000: aluop = 4'b0111; // SRA
                                default:    aluop = 4'b0110;
                            endcase
                    3'b110: aluop = 4'b1000; // OR
                    3'b111: aluop = 4'b1001; // AND
                    default: aluop = 4'b0000;
                endcase
            end

            7'b0010011: begin // I-type (data processing)
                rf_en = 1'b1; sel_a = 1'b1; sel_b = 1'b1; rd_en = 1'b0; wb_sel = 2'b01; wr_en = 1'b0;
                br_take = 1'b0; mem_acc_mode = 3'b111; br_type = 3'b011; csr_rd = 1'b0; csr_wr = 1'b0; is_mret = 1'b0;
                case (funct3)
                    3'b000: aluop = 4'b0000; // ADDI
                    3'b010: aluop = 4'b0011; // SLTI
                    3'b011: aluop = 4'b0100; // SLTIU
                    3'b100: aluop = 4'b0101; // XORI
                    3'b110: aluop = 4'b1000; // ORI
                    3'b111: aluop = 4'b1001; // ANDI
                    3'b001: aluop = 4'b0010; // SLLI
                    3'b101: case (funct7)
                                7'b0000000: aluop = 4'b0110; // SRLI
                                7'b0100000: aluop = 4'b0111; // SRAI
                                default:    aluop = 4'b0110;
                            endcase
                    default: aluop = 4'b0000;
                endcase
            end

            7'b0000011: begin // I-type (loads)
                rf_en = 1'b1; sel_a = 1'b1; sel_b = 1'b1; rd_en = 1'b1; wb_sel = 2'b10; wr_en = 1'b0;
                br_take = 1'b0; aluop = 4'b0000; br_type = 3'b011; csr_rd = 1'b0; csr_wr = 1'b0; is_mret = 1'b0;
                case (funct3)
                    3'b000:  mem_acc_mode = 3'b000; // LB
                    3'b001:  mem_acc_mode = 3'b001; // LH
                    3'b010:  mem_acc_mode = 3'b010; // LW
                    3'b100:  mem_acc_mode = 3'b011; // LBU
                    3'b101:  mem_acc_mode = 3'b100; // LHU
                    default: mem_acc_mode = 3'b111;
                endcase
            end

            7'b0100011: begin // S-type (stores)
                rf_en = 1'b0; sel_a = 1'b1; sel_b = 1'b1; rd_en = 1'b0; wb_sel = 2'b01; wr_en = 1'b1;
                br_take = 1'b0; aluop = 4'b0000; br_type = 3'b011; csr_rd = 1'b0; csr_wr = 1'b0; is_mret = 1'b0;
                case (funct3)
                    3'b000:  mem_acc_mode = 3'b000; // SB
                    3'b001:  mem_acc_mode = 3'b001; // SH
                    3'b010:  mem_acc_mode = 3'b010; // SW
                    default: mem_acc_mode = 3'b111;
                endcase
            end

            7'b1100011: begin // B-type
                rf_en = 1'b0; sel_a = 1'b0; sel_b = 1'b1; rd_en = 1'b0; wb_sel = 2'b01; wr_en = 1'b0;
                aluop = 4'b0000; br_type = funct3; br_take = br_taken;
                csr_rd = 1'b0; csr_wr = 1'b0; is_mret = 1'b0;
            end

            7'b0110111: begin // U-type (LUI)
                rf_en = 1'b1; sel_a = 1'b0; sel_b = 1'b1; rd_en = 1'b0; wb_sel = 2'b01; wr_en = 1'b0;
                aluop = 4'b1010; br_type = 3'b011; br_take = 1'b0;
                csr_rd = 1'b0; csr_wr = 1'b0; is_mret = 1'b0;
            end

            7'b0010111: begin // U-type (AUIPC)
                rf_en = 1'b1; sel_a = 1'b0; sel_b = 1'b1; rd_en = 1'b0; wb_sel = 2'b01; wr_en = 1'b0;
                aluop = 4'b0000; br_type = 3'b011; br_take = 1'b0;
                csr_rd = 1'b0; csr_wr = 1'b0; is_mret = 1'b0;
            end

            7'b1101111: begin // J-type (JAL)
                rf_en = 1'b1; sel_a = 1'b0; sel_b = 1'b1; rd_en = 1'b0; wb_sel = 2'b00; wr_en = 1'b0;
                aluop = 4'b0000; br_type = 3'b011; br_take = 1'b1;
                csr_rd = 1'b0; csr_wr = 1'b0; is_mret = 1'b0;
            end

            7'b1100111: begin // I-type (JALR)
                rf_en = 1'b1; sel_a = 1'b1; sel_b = 1'b1; rd_en = 1'b0; wb_sel = 2'b00; wr_en = 1'b0;
                aluop = 4'b0000; br_type = 3'b011; br_take = 1'b1;
                csr_rd = 1'b0; csr_wr = 1'b0; is_mret = 1'b0;
            end

            7'b1110011: begin // SYSTEM (CSRRW / MRET)
                case (funct3)
                    3'b000: begin // MRET
                        rf_en = 1'b0; sel_a = 1'b1; sel_b = 1'b0; rd_en = 1'b0; wb_sel = 2'b01; wr_en = 1'b0;
                        br_take = 1'b0; mem_acc_mode = 3'b111; br_type = 3'b011;
                        csr_rd = 1'b0; csr_wr = 1'b0; is_mret = 1'b1;
                    end
                    default: begin // CSRRW
                        rf_en = 1'b1; sel_a = 1'b1; sel_b = 1'b0; rd_en = 1'b0; wb_sel = 2'b11; wr_en = 1'b0;
                        br_take = 1'b0; mem_acc_mode = 3'b111; br_type = 3'b011;
                        csr_rd = 1'b1; csr_wr = 1'b1; is_mret = 1'b0;
                    end
                endcase
            end

            default: begin
                rf_en = 1'b0; sel_a = 1'b1; sel_b = 1'b0; rd_en = 1'b0; wb_sel = 2'b01; wr_en = 1'b0;
                br_take = 1'b0; mem_acc_mode = 3'b111; br_type = 3'b011;
                csr_rd = 1'b0; csr_wr = 1'b0; is_mret = 1'b0;
            end
        endcase
    end
endmodule
