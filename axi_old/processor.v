`timescale 1ns/1ps
// =====================================================================
//  3-stage pipelined RV32I processor  (Verilog-2001, Genus-synthesizable)
//  Stages : IF  |  DE (decode+execute)  |  MW (mem+writeback)
//  ALU add/sub use the CSLA-BEC adder_unit.
//

// =====================================================================
module processor (
    input             clk,
    input             rst,

    // ---------------- instruction-memory interface (external ROM) ----------------
    output     [31:0] imem_addr,     // fetch address  (= pc_out_IF)
    input      [31:0] imem_rdata,    // fetched instruction word -> inst_IF
    input             mem_ready,

    // ---------------- retire-stage monitor / debug outputs ----------------
    output     [31:0] pc_debug,      // pc_out_MW : PC of instruction in MW stage
    output     [31:0] inst_debug,    // inst_MW   : instruction word in MW stage
    output            rf_we,         // rf_en_MW  : register-file write enable (retire indicator)
    output     [ 4:0] rf_waddr,      // waddr     : register-file write address
    output     [31:0] rf_wdata,      // wdata_DE  : register-file write data
    output            mem_we,        // wr_en_MW  : data-memory write enable
    output            mem_re,        // rd_en_MW  : data-memory read enable
    output     [31:0] mem_addr,      // opr_res_MW: data-memory address
    output     [31:0] mem_wdata,     // rdata2_MW : data-memory write data
    output     [31:0] mem_rdata,     // rdata     : data-memory read data
    output            br_taken_dbg,  // br_take_DE: branch/jump taken in DE
    output            trap_taken,    // epc_taken_MW: interrupt/mret redirect taken
    output     [31:0] epc_debug,     // epc_MW    : trap/return target address
    output            timer_irq_dbg  // internal timer_interrupt (was a primary input; now observable here)
);
    // internal interrupt wire (was a top-level input before the timer was folded in)
    wire timer_interrupt;
    // ---------------- PC ----------------
    wire [31:0] pc_out_IF;
    reg  [31:0] pc_out_DE;
    reg  [31:0] pc_out_MW;
    wire [31:0] new_pc;

    // ---------------- instruction ----------------
    wire [31:0] inst_IF;
    reg  [31:0] inst_DE;
    reg  [31:0] inst_MW;

    reg  [ 4:0] waddr;

    // ---------------- decoded fields ----------------
    wire [ 4:0] rs1_DE;
    wire [ 4:0] rs2_DE;
    reg [ 4:0] rs1_MW;
    reg [ 4:0] rs2_MW;
    wire [ 4:0] rd_DE;   reg [4:0] rd_MW;   // rd_MW derived from inst_MW (not pipelined)
    wire [ 6:0] opcode;
    wire [ 2:0] funct3;
    wire [ 6:0] funct7;

    // ---------------- datapath values ----------------
    wire [31:0] rdata1_DE;  reg [31:0] rdata1_MW;
    wire [31:0] rdata2_DE;  reg [31:0] rdata2_MW;
    wire [31:0] opr_a;
    wire [31:0] opr_b;
    reg  [31:0] opr_res_IF;
    wire [31:0] opr_res_DE;
    reg  [31:0] opr_res_MW;
    reg [31:0] imm_val_MW;
    wire [31:0] imm_val_DE;
    reg  [31:0] wdata_DE;
    wire [31:0] wdata_MW;
    wire [31:0] rdata;
    wire        br_taken;
    wire [ 3:0] aluop;

    // ---------------- control signals ----------------
    wire        rf_en_DE;  reg rf_en_MW;
    wire        sel_a;
    wire        sel_b;
    wire        rd_en_DE;  reg rd_en_MW;
    wire        wr_en_DE;  reg wr_en_MW;
    wire [ 1:0] wb_sel_DE; reg [1:0] wb_sel_MW;
    wire [ 2:0] mem_acc_mode_DE; reg [2:0] mem_acc_mode_MW;
    wire [ 2:0] br_type;
    wire        br_take_DE;
    reg         br_take_IF;
    wire        csr_rd_DE; reg csr_rd_MW;
    wire        csr_wr_DE; reg csr_wr_MW;  // csr_wr_MW derived from inst_MW (not pipelined)
    wire        is_mret_DE; reg is_mret_MW;

    wire [31:0] csr_rdata;

    // ---------------- trap / epc ----------------
    reg  [31:0] epc_IF;
    wire [31:0] epc_MW;
    reg         epc_taken_IF;
    wire        epc_taken_MW;
    wire [31:0] epc_pc;

    // ---------------- hazard ----------------
    reg  [31:0] forward_opr_a;
    reg  [31:0] forward_opr_b;
    wire        forward_a;
    wire        forward_b;
    wire        stall_IF;
    wire        flush_DE;

    // FOR AXI integration
    reg  fetch_pending;   // AXI read in flight for inst fetch
    reg  data_pending;    // AXI transaction in flight for load/store
    

    // =================== Timer (embedded interrupt source) ===================
    // Was external-only (TB-level) in the original repo and unused by
    // 'processor' itself, leaving it orphaned in the read_hdl set.
    // Now a real internal block driving timer_interrupt.
    timer timer_i (
        .clk             (clk),
        .rst             (rst),
        .timer_interrupt (timer_interrupt)
    );

    // =================== Instruction Fetch ===================
    mux_2x1 mux_2x1_pc (
        .in_0        (pc_out_IF + 32'd4),
        .in_1        (opr_res_IF),
        .select_line (br_take_IF),
        .out         (new_pc)
    );

    mux_2x1 mux_2x1_epc (
        .in_0        (new_pc),
        .in_1        (epc_IF),
        .select_line (epc_taken_IF),
        .out         (epc_pc)
    );

    /*
pc pc_i (
        .clk    (clk),
        .rst    (rst),
        .en     (~stall_IF),
        .pc_in  (epc_pc),
        .pc_out (pc_out_IF)
    );

    // Instruction memory is EXTERNAL: drive the fetch address out, take the
    // instruction word in. (No inst_mem instance inside the core.)
    assign imem_addr = pc_out_IF;
    assign inst_IF   = imem_rdata;

    // IF <-> DE pipeline buffer
    always @(posedge clk) begin
        if (rst) begin
            pc_out_DE <= 32'b0;
            inst_DE   <= 32'b0;
        end
        else if (flush_DE) begin
            inst_DE   <= 32'h00000013; // NOP (addi x0,x0,0)
            pc_out_DE <= 32'b0;
        end
        else begin
            pc_out_DE <= pc_out_IF;
            inst_DE   <= inst_IF;
        end
    end
*/
    //====================================================
    // AXI / SHARED MEMORY ACCESS
    //
    //====================================================

   /* assign data_access = rd_en_MW | wr_en_MW;

    // mem_valid: always asserted; AXI master handles sequencing
    assign mem_valid = 1'b1;

    assign mem_write = data_access & wr_en_MW;
    assign mem_addr  = data_access ? opr_res_MW : pc_out_IF;
    assign mem_wdata = wr_en_MW    ? rdata2_MW  : 32'b0;
    assign mem_wstrb = wr_en_MW    ? 4'b1111    : 4'b0000;

    // Instruction and read-data are only valid on the cycle mem_ready pulses
    // for the right transaction type
    assign inst_IF = (!data_access && mem_ready) ? mem_rdata : 32'h00000013;
    assign rdata   = ( data_access && mem_ready) ? mem_rdata : 32'b0;

    //====================================================
    // PROGRAM COUNTER
    //====================================================

    wire fetch_done = (!data_access) && mem_ready && mem_valid;
    wire data_done  = ( data_access) && mem_ready && mem_valid;
    wire trans_done = fetch_done | data_done;

    pc pc_i
    (
        .clk    (clk),
        .rst    (rst),
        .en     (~stall_IF && fetch_done), 
        .pc_in  (epc_pc),
        .pc_out (pc_out_IF)
    );
*/
//====================================================
    // AXI / SHARED MEMORY ACCESS
    //====================================================

    wire data_access = rd_en_MW | wr_en_MW;

    // FIX: Expose the raw PC address out to the SoC wrapper so it can handle the multiplexing
    assign imem_addr = pc_out_IF;

    // FIX: Read from the wrapper's multiplexed 'imem_rdata' instead of the output port 'mem_rdata'
    assign inst_IF = (!data_access && mem_ready) ? imem_rdata : 32'h00000013;
    assign rdata   = ( data_access && mem_ready) ? imem_rdata : 32'b0;

    //====================================================
    // PROGRAM COUNTER
    //====================================================

    // FIX: Removed undeclared 'mem_valid' dependency
    wire fetch_done = (!data_access) && mem_ready;
    wire data_done  = ( data_access) && mem_ready;
    wire trans_done = fetch_done | data_done;

    pc pc_i
    (
        .clk    (clk),
        .rst    (rst),
        .en     (~stall_IF && fetch_done), 
        .pc_in  (epc_pc),
        .pc_out (pc_out_IF)
    );
    //====================================================
    // IF/DE PIPELINE
    //====================================================

    always @(posedge clk)
    begin
        if (rst)
        begin
            pc_out_DE <= 32'b0;
            inst_DE   <= 32'h00000013;  // NOP (ADDI x0,x0,0)
        end

        else if (stall_IF || (!fetch_done && !data_done))
        begin
            // Hold — do not update decode stage while stalled or transaction not ready
            pc_out_DE <= pc_out_DE;
            inst_DE   <= inst_DE;
        end

        else if (flush_DE || data_done)
        begin
            pc_out_DE <= 32'b0;
            inst_DE   <= 32'h00000013;
        end
        else
        begin
            pc_out_DE <= pc_out_IF;
            inst_DE   <= inst_IF;
        end
    end




    // =================== Decode-Execute ===================
    inst_dec inst_dec_i (
        .inst   (inst_DE),
        .rs1    (rs1_DE),
        .rs2    (rs2_DE),
        .rd     (rd_DE),
        .opcode (opcode),
        .funct3 (funct3),
        .funct7 (funct7)
    );

    reg_file reg_file_i (
        .clk    (clk),
        .rf_en  (rf_en_MW),
        .rs1    (rs1_DE),
        .rs2    (rs2_DE),
        .rd     (waddr),
        .wdata  (wdata_DE),
        .rdata1 (rdata1_DE),
        .rdata2 (rdata2_DE)
    );

    controller controller_i (
        .opcode       (opcode),
        .funct3       (funct3),
        .funct7       (funct7),
        .br_taken     (br_taken),
        .aluop        (aluop),
        .rf_en        (rf_en_DE),
        .sel_a        (sel_a),
        .sel_b        (sel_b),
        .rd_en        (rd_en_DE),
        .wr_en        (wr_en_DE),
        .wb_sel       (wb_sel_DE),
        .mem_acc_mode (mem_acc_mode_DE),
        .br_type      (br_type),
        .br_take      (br_take_DE),
        .csr_rd       (csr_rd_DE),
        .csr_wr       (csr_wr_DE),
        .is_mret      (is_mret_DE)
    );

    imm_gen imm_gen_i (
        .inst    (inst_DE),
        .imm_val (imm_val_DE)
    );

    // forwarding muxes : forward the REAL writeback value (wdata_MW), so a
    // dependent instruction right after a load / JAL / JALR / CSR gets the
    // correct value (loaded data / pc+4 / csr data), not just the ALU result.
    // forward_a/forward_b are already gated on rf_en_MW inside hazard_unit.
    always @(*) begin
        if (forward_a) forward_opr_a = wdata_MW;
        else           forward_opr_a = rdata1_DE;
    end

    always @(*) begin
        if (forward_b) forward_opr_b = wdata_MW;
        else           forward_opr_b = rdata2_DE;
    end

    mux_2x1 mux_2x1_alu_opr_a (
        .in_0        (pc_out_DE),
        .in_1        (forward_opr_a),
        .select_line (sel_a),
        .out         (opr_a)
    );

    mux_2x1 mux_2x1_alu_opr_b (
        .in_0        (forward_opr_b),
        .in_1        (imm_val_DE),
        .select_line (sel_b),
        .out         (opr_b)
    );

    alu alu_i (
        .aluop   (aluop),
        .opr_a   (opr_a),
        .opr_b   (opr_b),
        .opr_res (opr_res_DE)
    );

    // Branch comparator must use the FORWARDED operands (not the raw register
    // reads): with a posedge-write register file, a branch that depends on the
    // immediately-preceding instruction would otherwise compare stale data.
    br_cond br_cond_i (
        .rdata1   (forward_opr_a),
        .rdata2   (forward_opr_b),
        .br_type  (br_type),
        .br_taken (br_taken)
    );

    // feedback to IF
    always @(*) begin
        br_take_IF = br_take_DE;
        opr_res_IF = opr_res_DE;
    end

    // DE <-> MW pipeline buffer
/*
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
        else begin
            pc_out_MW       <= pc_out_DE;
            inst_MW         <= inst_DE;
            opr_res_MW      <= opr_res_DE;
            rdata1_MW       <= rdata1_DE;
            rdata2_MW       <= rdata2_DE;
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
    data_mem data_mem_i (
        .clk          (clk),
        .rd_en        (rd_en_MW),
        .wr_en        (wr_en_MW),
        .addr         (opr_res_MW),
        .mem_acc_mode (mem_acc_mode_MW),
        .wdata        (rdata2_MW),
        .rdata        (rdata)
    );
*/
    always @(posedge clk)
    begin
        if (rst)
        begin
            pc_out_MW       <= 32'b0;
            inst_MW         <= 32'h00000013;
            opr_res_MW      <= 32'b0;

            rdata1_MW       <= 32'b0;
            rdata2_MW       <= 32'b0;

            imm_val_MW      <= 32'b0;

            rs1_MW          <= 5'b0;
            rs2_MW          <= 5'b0;
            rd_MW           <= 5'b0;

            rf_en_MW        <= 1'b0;
            rd_en_MW        <= 1'b0;
            wr_en_MW        <= 1'b0;

            wb_sel_MW       <= 2'b0;
            mem_acc_mode_MW <= 3'b0;

            csr_rd_MW       <= 1'b0;
            csr_wr_MW       <= 1'b0;
            is_mret_MW      <= 1'b0;
        end
        else if (data_access && !mem_ready)
        begin
            // Data transaction pending — hold all MW registers
            pc_out_MW       <= pc_out_MW;
            inst_MW         <= inst_MW;
            opr_res_MW      <= opr_res_MW;
            rdata1_MW       <= rdata1_MW;
            rdata2_MW       <= rdata2_MW;
            imm_val_MW      <= imm_val_MW;
            rs1_MW          <= rs1_MW;
            rs2_MW          <= rs2_MW;
            rd_MW           <= rd_MW;
            rf_en_MW        <= rf_en_MW;
            rd_en_MW        <= rd_en_MW;
            wr_en_MW        <= wr_en_MW;
            wb_sel_MW       <= wb_sel_MW;
            mem_acc_mode_MW <= mem_acc_mode_MW;
            csr_rd_MW       <= csr_rd_MW;
            csr_wr_MW       <= csr_wr_MW;
            is_mret_MW      <= is_mret_MW;
        end
        else
        begin
            pc_out_MW       <= pc_out_DE;
            inst_MW         <= inst_DE;
            opr_res_MW      <= opr_res_DE;

            rdata1_MW       <= rdata1_DE;
            rdata2_MW       <= rdata2_DE;

            imm_val_MW      <= imm_val_DE;

            rs1_MW          <= rs1_DE;
            rs2_MW          <= rs2_DE;
            rd_MW           <= rd_DE;

            rf_en_MW        <= rf_en_DE;
            rd_en_MW        <= rd_en_DE;
            wr_en_MW        <= wr_en_DE;

            wb_sel_MW       <= wb_sel_DE;
            mem_acc_mode_MW <= mem_acc_mode_DE;

            csr_rd_MW       <= csr_rd_DE;
            csr_wr_MW       <= csr_wr_DE;
            is_mret_MW      <= is_mret_DE;
        end
    end
    csr_reg csr_reg_i (
        .clk       (clk),
        .rst       (rst),
        .wdata     (rdata1_MW),
        .pc        (pc_out_MW),
        .trap      (timer_interrupt),
        .csr_rd    (csr_rd_MW),
        .csr_wr    (csr_wr_MW),
        .is_mret   (is_mret_MW),
        .inst      (inst_MW),
        .rdata     (csr_rdata),
        .epc       (epc_MW),
        .epc_taken (epc_taken_MW)
    );

    mux_4x1 wb_mux (
        .in_0        (pc_out_MW + 32'd4),
        .in_1        (opr_res_MW),
        .in_2        (rdata),
        .in_3        (csr_rdata),
        .select_line (wb_sel_MW),
        .out         (wdata_MW)
    );

    // feedback to IF (epc)
    always @(*) begin
        epc_IF       = epc_MW;
        epc_taken_IF = epc_taken_MW;
    end

    // feedback to DE (writeback)
    always @(*) begin
        waddr    = inst_MW[11:7];
        wdata_DE = wdata_MW;
    end

    // =================== Hazard Unit ===================
    hazard_unit hazard_unit_i (
        .rs1_DE    (rs1_DE),
        .rs2_DE    (rs2_DE),
        .rd_MW     (rd_MW),
        .rf_en_MW  (rf_en_MW),
        .forward_a (forward_a),
        .forward_b (forward_b),
        .inst_IF   (inst_IF),
        .rd_DE     (rd_DE),
        .wb_sel_DE (wb_sel_DE),
        .br_taken  (br_take_DE),
        .stall_IF  (stall_IF),
        .flush_DE  (flush_DE)
    );
    // =================== Retire-stage monitor / debug bus ===================
    assign pc_debug     = pc_out_MW;
    assign inst_debug   = inst_MW;

    //assign rd_MW     = inst_MW[11:7];
    //assign csr_wr_MW = (inst_MW[6:0] == 7'b1110011) && (inst_MW[14:12] != 3'b000);
    assign rf_we        = rf_en_MW;
    assign rf_waddr     = waddr;
    assign rf_wdata     = wdata_DE;
    assign mem_we       = wr_en_MW;
    assign mem_re       = rd_en_MW;
    assign mem_addr     = opr_res_MW;
    assign mem_wdata    = rdata2_MW;
    assign mem_rdata    = rdata;
    assign br_taken_dbg = br_take_DE;
    assign trap_taken   = epc_taken_MW;
    assign epc_debug    = epc_MW;
    assign timer_irq_dbg = timer_interrupt;

endmodule
