`timescale 1ns/1ps
// =====================================================================
//  3-stage pipelined RV32I processor with Harvard AXI Handshakes
// =====================================================================
module processor (
    input             clk,
    input             rst,
    input             timer_interrupt,

    // Instruction Memory Interface
    output     [31:0] imem_addr,
    output            imem_valid,
    input             imem_ready,
    input      [31:0] imem_rdata,

    // Data Memory Interface
    output     [31:0] dmem_addr,
    output            dmem_valid,
    output            dmem_write,
    output     [ 3:0] dmem_wstrb,
    output     [31:0] dmem_wdata,
    input             dmem_ready,
    input      [31:0] dmem_rdata
);

    // ---------------- PC & IF Stage ----------------
    wire [31:0] pc_out_IF;
    reg  [31:0] pc_out_DE;
    reg  [31:0] pc_out_MW;
    wire [31:0] new_pc;

    wire [31:0] inst_IF;
    reg  [31:0] inst_DE;
    reg  [31:0] inst_MW;
    reg  [ 4:0] waddr;

    // ---------------- Decoded fields & Datapath ----------------
    wire [ 4:0] rs1_DE, rs2_DE, rd_DE;
    wire [ 4:0] rd_MW;
    wire [ 6:0] opcode, funct7;
    wire [ 2:0] funct3;

    wire [31:0] rdata1_DE, rdata2_DE;
    reg  [31:0] rdata1_MW, rdata2_MW;
    
    wire [31:0] opr_a, opr_b, opr_res_DE;
    reg  [31:0] opr_res_IF, opr_res_MW;
    
    wire [31:0] imm_val_DE;
    reg  [31:0] wdata_DE;
    wire [31:0] wdata_MW;
    wire [31:0] rdata;
    
    wire        br_taken;
    wire [ 3:0] aluop;

    // ---------------- Control signals ----------------
    wire        rf_en_DE;
    reg         rf_en_MW;
    wire        sel_a, sel_b;
    wire        rd_en_DE;  
    reg         rd_en_MW;
    wire        wr_en_DE;
    reg         wr_en_MW;
    wire [ 1:0] wb_sel_DE; 
    reg  [1:0]  wb_sel_MW;
    wire [ 2:0] mem_acc_mode_DE; 
    reg  [2:0]  mem_acc_mode_MW;
    wire [ 2:0] br_type;
    wire        br_take_DE;
    reg         br_take_IF;
    wire        csr_rd_DE;
    reg         csr_rd_MW;
    wire        csr_wr_DE;
    wire        csr_wr_MW; 
    wire        is_mret_DE;
    reg         is_mret_MW;
    wire [31:0] csr_rdata;

    // ---------------- Trap / EPC ----------------
    reg  [31:0] epc_IF;
    wire [31:0] epc_MW;
    reg         epc_taken_IF;
    wire        epc_taken_MW;
    wire [31:0] epc_pc;

    // ---------------- Hazard ----------------
    reg  [31:0] forward_opr_a, forward_opr_b;
    wire        forward_a, forward_b;
    wire        stall_IF, flush_DE;

    // =================== Memory Interface Logic ===================
    assign imem_addr  = pc_out_IF;
    assign imem_valid = 1'b1;
    assign inst_IF    = imem_rdata;

    assign dmem_valid = wr_en_MW | rd_en_MW;
    assign dmem_write = wr_en_MW;
    assign dmem_addr  = opr_res_MW;

    // Byte lane alignment for writes
    reg [31:0] wdata_shifted;
    reg [3:0]  wstrb_val;
    always @(*) begin
        if (wr_en_MW) begin
            case (mem_acc_mode_MW)
                3'b000: begin // SB
                    wdata_shifted = {4{rdata2_MW[7:0]}};
                    wstrb_val     = 4'b0001 << opr_res_MW[1:0];
                end
                3'b001: begin // SH
                    wdata_shifted = {2{rdata2_MW[15:0]}};
                    wstrb_val     = 4'b0011 << opr_res_MW[1:0];
                end
                default: begin // SW
                    wdata_shifted = rdata2_MW;
                    wstrb_val     = 4'b1111;
                end
            endcase
        end else begin
            wdata_shifted = 32'b0;
            wstrb_val     = 4'b0000;
        end
    end
    assign dmem_wdata = wdata_shifted;
    assign dmem_wstrb = wstrb_val;

    // Data extraction and sign-extension for reads
    reg [31:0] rdata_formatted;
    always @(*) begin
        case (mem_acc_mode_MW)
            3'b000: begin // LB
                case (opr_res_MW[1:0])
                    2'b00: rdata_formatted = {{24{dmem_rdata[7]}}, dmem_rdata[7:0]};
                    2'b01: rdata_formatted = {{24{dmem_rdata[15]}}, dmem_rdata[15:8]};
                    2'b10: rdata_formatted = {{24{dmem_rdata[23]}}, dmem_rdata[23:16]};
                    2'b11: rdata_formatted = {{24{dmem_rdata[31]}}, dmem_rdata[31:24]};
                endcase
            end
            3'b100: begin // LBU
                case (opr_res_MW[1:0])
                    2'b00: rdata_formatted = {24'b0, dmem_rdata[7:0]};
                    2'b01: rdata_formatted = {24'b0, dmem_rdata[15:8]};
                    2'b10: rdata_formatted = {24'b0, dmem_rdata[23:16]};
                    2'b11: rdata_formatted = {24'b0, dmem_rdata[31:24]};
                endcase
            end
            3'b001: begin // LH
                if (opr_res_MW[1]) rdata_formatted = {{16{dmem_rdata[31]}}, dmem_rdata[31:16]};
                else               rdata_formatted = {{16{dmem_rdata[15]}}, dmem_rdata[15:0]};
            end
            3'b101: begin // LHU
                if (opr_res_MW[1]) rdata_formatted = {16'b0, dmem_rdata[31:16]};
                else               rdata_formatted = {16'b0, dmem_rdata[15:0]};
            end
            default: rdata_formatted = dmem_rdata; // LW
        endcase
    end
    assign rdata = rdata_formatted;

    // =================== Pipeline Stall Generator ===================
    wire stall_ext = (imem_valid && !imem_ready) || (dmem_valid && !dmem_ready);

    // =================== Instruction Fetch ===================
    mux_2x1 mux_2x1_pc (.in_0(pc_out_IF + 32'd4), .in_1(opr_res_IF), .select_line(br_take_IF), .out(new_pc));
    mux_2x1 mux_2x1_epc (.in_0(new_pc), .in_1(epc_IF), .select_line(epc_taken_IF), .out(epc_pc));
    
    pc pc_i (
        .clk    (clk),
        .rst    (rst),
        .en     (~stall_IF && ~stall_ext),
        .pc_in  (epc_pc),
        .pc_out (pc_out_IF)
    );

    // IF <-> DE pipeline buffer
    always @(posedge clk) begin
        if (rst) begin
            pc_out_DE <= 32'b0;
            inst_DE   <= 32'h00000013; // NOP
        end
        else if (stall_ext) begin
            // Wait for AXI: Hold pipeline state entirely
            pc_out_DE <= pc_out_DE;
            inst_DE   <= inst_DE;
        end
        else if (flush_DE) begin
            inst_DE   <= 32'h00000013;
            pc_out_DE <= 32'b0;
        end
        else if (stall_IF) begin
            // Normal internal hazard wait
            pc_out_DE <= pc_out_DE;
            inst_DE   <= inst_DE;
        end
        else begin
            pc_out_DE <= pc_out_IF;
            inst_DE   <= inst_IF;
        end
    end

    // =================== Decode-Execute ===================
    inst_dec inst_dec_i (.inst(inst_DE), .rs1(rs1_DE), .rs2(rs2_DE), .rd(rd_DE), .opcode(opcode), .funct3(funct3), .funct7(funct7));
    reg_file reg_file_i (.clk(clk), .rf_en(rf_en_MW), .rs1(rs1_DE), .rs2(rs2_DE), .rd(waddr), .wdata(wdata_DE), .rdata1(rdata1_DE), .rdata2(rdata2_DE));
    controller controller_i (.opcode(opcode), .funct3(funct3), .funct7(funct7), .br_taken(br_taken), .aluop(aluop), .rf_en(rf_en_DE), .sel_a(sel_a), .sel_b(sel_b), .rd_en(rd_en_DE), .wr_en(wr_en_DE), .wb_sel(wb_sel_DE), .mem_acc_mode(mem_acc_mode_DE), .br_type(br_type), .br_take(br_take_DE), .csr_rd(csr_rd_DE), .csr_wr(csr_wr_DE), .is_mret(is_mret_DE));
    imm_gen imm_gen_i (.inst(inst_DE), .imm_val(imm_val_DE));

    always @(*) begin
        if (forward_a) forward_opr_a = wdata_MW;
        else forward_opr_a = rdata1_DE;
        
        if (forward_b) forward_opr_b = wdata_MW; 
        else forward_opr_b = rdata2_DE;
    end

    mux_2x1 mux_2x1_alu_opr_a (.in_0(pc_out_DE), .in_1(forward_opr_a), .select_line(sel_a), .out(opr_a));
    mux_2x1 mux_2x1_alu_opr_b (.in_0(forward_opr_b), .in_1(imm_val_DE), .select_line(sel_b), .out(opr_b));
    alu alu_i (.aluop(aluop), .opr_a(opr_a), .opr_b(opr_b), .opr_res(opr_res_DE));
    
    br_cond br_cond_i (.rdata1(forward_opr_a), .rdata2(forward_opr_b), .br_type(br_type), .br_taken(br_taken));
    always @(*) begin
        br_take_IF = br_take_DE;
        opr_res_IF = opr_res_DE;
    end

    // DE <-> MW pipeline buffer
    always @(posedge clk) begin
        if (rst) begin
            pc_out_MW       <= 32'b0;
            inst_MW         <= 32'b0;
            opr_res_MW      <= 32'b0;
            rdata1_MW       <= 32'b0;
            rdata2_MW       <= 32'b0;
            rf_en_MW        <= 1'b0;
            rd_en_MW        <= 1'b0;
            wr_en_MW        <= 1'b0;
            mem_acc_mode_MW <= 3'b0;
            csr_rd_MW       <= 1'b0;
            is_mret_MW      <= 1'b0;
            wb_sel_MW       <= 2'b0;
        end
        else if (stall_ext) begin
            // Hold completely during AXI Wait
        end
        else begin
            pc_out_MW       <= pc_out_DE;
            inst_MW         <= inst_DE;
            opr_res_MW      <= opr_res_DE;
            
            // FIX: Latch the hazard-resolved values, NOT the raw register file outputs!
            rdata1_MW       <= forward_opr_a; 
            rdata2_MW       <= forward_opr_b; 
            
            rf_en_MW        <= rf_en_DE;
            rd_en_MW        <= rd_en_DE;
            wr_en_MW        <= wr_en_DE;
            mem_acc_mode_MW <= mem_acc_mode_DE;
            csr_rd_MW       <= csr_rd_DE;
            is_mret_MW      <= is_mret_DE;
            wb_sel_MW       <= wb_sel_DE;
        end
    end

    // =================== Memory-Writeback ===================
    csr_reg csr_reg_i (.clk(clk), .rst(rst), .wdata(rdata1_MW), .pc(pc_out_MW), .trap(timer_interrupt), .csr_rd(csr_rd_MW), .csr_wr(csr_wr_MW), .is_mret(is_mret_MW), .inst(inst_MW), .rdata(csr_rdata), .epc(epc_MW), .epc_taken(epc_taken_MW));
    mux_4x1 wb_mux (.in_0(pc_out_MW + 32'd4), .in_1(opr_res_MW), .in_2(rdata), .in_3(csr_rdata), .select_line(wb_sel_MW), .out(wdata_MW));
    
    always @(*) begin
        epc_IF       = epc_MW;
        epc_taken_IF = epc_taken_MW;
        waddr        = inst_MW[11:7];
        wdata_DE     = wdata_MW;
    end

    // =================== Hazard Unit ===================
    hazard_unit hazard_unit_i (.rs1_DE(rs1_DE), .rs2_DE(rs2_DE), .rd_MW(rd_MW), .rf_en_MW(rf_en_MW), .forward_a(forward_a), .forward_b(forward_b), .inst_IF(inst_IF), .rd_DE(rd_DE), .wb_sel_DE(wb_sel_DE), .br_taken(br_take_DE), .stall_IF(stall_IF), .flush_DE(flush_DE));

    // =================== Internal Wire Assignments ===================
    assign rd_MW         = inst_MW[11:7];
    assign csr_wr_MW     = (inst_MW[6:0] == 7'b1110011) && (inst_MW[14:12] != 3'b000);

endmodule