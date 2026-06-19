// Machine-mode CSR file (6 regs) + timer-interrupt trap / mret handling.
// csr_mem: 0=mstatus 1=mie 2=mtvec 3=mepc 4=mcause 5=mip
`timescale 1ns/1ps
module csr_reg (
    input             clk,
    input             rst,
    input      [31:0] wdata,     // data from rs1
    input      [31:0] pc,
    input             trap,      // interrupt / exception
    input             csr_rd,
    input             csr_wr,
    input             is_mret,
    input      [31:0] inst,
    output reg [31:0] rdata,
    output reg [31:0] epc,
    output reg        epc_taken
);
    reg [31:0] csr_mem [0:5];
    wire       is_device_int_en = csr_mem[5][7] & csr_mem[1][7];
    wire       is_global_int_en = csr_mem[0][3] & is_device_int_en; // mstatus.MIE & device-enable

    // read (default added -> no latch)
    always @(*) begin
        rdata = 32'b0;
        if (csr_rd) begin
            case (inst[31:20])
                12'h300: rdata = csr_mem[0]; // mstatus
                12'h304: rdata = csr_mem[1]; // mie
                12'h305: rdata = csr_mem[2]; // mtvec
                12'h341: rdata = csr_mem[3]; // mepc
                12'h342: rdata = csr_mem[4]; // mcause
                12'h344: rdata = csr_mem[5]; // mip
                default: rdata = 32'b0;
            endcase
        end
    end

    // write / trap / mret
    // NOTE: reset now DOMINATES the whole block, so every state element here --
    // csr_mem[0..5], epc, epc_taken -- has a defined reset value. Previously epc
    // and epc_taken had no reset, which made them undefined at power-up and was
    // the root cause of the epc_reg[*]/epc_taken_reg LEC non-equivalences.
    always @(posedge clk) begin
        if (rst) begin
            csr_mem[0] <= 32'b0;
            csr_mem[1] <= 32'b0;
            csr_mem[2] <= 32'b0;
            csr_mem[3] <= 32'b0;
            csr_mem[4] <= 32'b0;
            csr_mem[5] <= 32'b0;
            epc        <= 32'b0;
            epc_taken  <= 1'b0;
        end
        else begin
            if (csr_wr) begin
                case (inst[31:20])
                    12'h300: csr_mem[0] <= wdata;
                    12'h304: csr_mem[1] <= wdata;
                    12'h305: csr_mem[2] <= wdata;
                    12'h341: csr_mem[3] <= wdata;
                    12'h342: csr_mem[4] <= wdata;
                    12'h344: csr_mem[5] <= wdata;
                    default: ;
                endcase
            end

            if (trap) begin
                csr_mem[4] <= 32'b0;                       // only timer interrupt modelled
                csr_mem[5] <= csr_mem[5] | 32'd128;        // set mip[7]
                if (is_global_int_en) begin
                    csr_mem[3] <= pc;                      // save PC -> mepc
                    epc        <= csr_mem[2] + (csr_mem[4] << 2); // mtvec + (mcause<<2)
                    epc_taken  <= 1'b1;
                end
            end
            else if (is_mret) begin
                epc_taken <= 1'b1;
                epc       <= csr_mem[3];                   // restore from mepc
            end
            else begin
                epc_taken <= 1'b0;
                epc       <= pc;
            end
        end
    end
endmodule
