`timescale 1ns/1fs

// ============================================================================
// Module : axi4lite_sram_slave
// Purpose:
//   AXI4-Lite slave connected to SPRAM_1024x36 foundry memory.
//
// Used for:
//   1. Instruction memory AXI slave
//   2. Data memory AXI slave
//
// AXI support:
//   - AXI read  : AR + R channel
//   - AXI write : AW + W + B channel
//   - WSTRB byte-lane write support
//
// Memory:
//   - 1024 words
//   - 32-bit data used
//   - upper 4 bits of 36-bit SRAM unused
// ============================================================================

module axi4lite_sram_slave (
    input             clk,
    input             rst,

    // ============================================================
    // AXI4-Lite write address channel
    // ============================================================
    input      [31:0] S_AXI_AWADDR,
    input             S_AXI_AWVALID,
    output reg        S_AXI_AWREADY,

    // ============================================================
    // AXI4-Lite write data channel
    // ============================================================
    input      [31:0] S_AXI_WDATA,
    input      [ 3:0] S_AXI_WSTRB,
    input             S_AXI_WVALID,
    output reg        S_AXI_WREADY,

    // ============================================================
    // AXI4-Lite write response channel
    // ============================================================
    output reg [ 1:0] S_AXI_BRESP,
    output reg        S_AXI_BVALID,
    input             S_AXI_BREADY,

    // ============================================================
    // AXI4-Lite read address channel
    // ============================================================
    input      [31:0] S_AXI_ARADDR,
    input             S_AXI_ARVALID,
    output reg        S_AXI_ARREADY,

    // ============================================================
    // AXI4-Lite read data channel
    // ============================================================
    output reg [31:0] S_AXI_RDATA,
    output reg [ 1:0] S_AXI_RRESP,
    output reg        S_AXI_RVALID,
    input             S_AXI_RREADY
);

    // ============================================================
    // FSM states
    // ============================================================
    localparam IDLE            = 3'd0;
    localparam READ_WAIT       = 3'd1;
    localparam READ_RESP       = 3'd2;
    localparam WRITE_READ_WAIT = 3'd3;
    localparam WRITE_DO        = 3'd4;
    localparam WRITE_RESP      = 3'd5;

    reg [2:0] state;

    // ============================================================
    // Latched AXI write information
    // ============================================================
    reg [31:0] awaddr_q;
    reg [31:0] wdata_q;
    reg [ 3:0] wstrb_q;

    // ============================================================
    // SRAM signals
    // ============================================================
    reg  [ 9:0] sram_addr;
    reg  [35:0] sram_i;
    wire [35:0] sram_o;

    reg         sram_csb;
    reg         sram_web;

    // ============================================================
    // Foundry SRAM macro
    //
    // CE  = ~clk is used so that AXI control signals are updated
    //       on posedge clk and SRAM samples them on the next negedge.
    //
    // WEB = 1 : read
    // WEB = 0 : write
    // CSB = 0 : selected
    // OEB = 0 : output enabled
    // ============================================================
    SPRAM_1024x36 sram_macro (
        .A   (sram_addr),
        .CE  (~clk),
        .WEB (sram_web),
        .OEB (1'b0),
        .CSB (sram_csb),
        .I   (sram_i),
        .O   (sram_o)
    );

    // ============================================================
    // Merge write data using AXI WSTRB
    //
    // WSTRB[0] -> byte [7:0]
    // WSTRB[1] -> byte [15:8]
    // WSTRB[2] -> byte [23:16]
    // WSTRB[3] -> byte [31:24]
    // ============================================================
    function [31:0] merge_wstrb;
        input [31:0] old_word;
        input [31:0] new_word;
        input [ 3:0] strb;
        begin
            merge_wstrb = old_word;

            if (strb[0])
                merge_wstrb[7:0] = new_word[7:0];

            if (strb[1])
                merge_wstrb[15:8] = new_word[15:8];

            if (strb[2])
                merge_wstrb[23:16] = new_word[23:16];

            if (strb[3])
                merge_wstrb[31:24] = new_word[31:24];
        end
    endfunction

    // ============================================================
    // AXI4-Lite slave FSM
    // ============================================================
    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;

            S_AXI_AWREADY <= 1'b0;
            S_AXI_WREADY  <= 1'b0;
            S_AXI_BRESP   <= 2'b00;
            S_AXI_BVALID  <= 1'b0;

            S_AXI_ARREADY <= 1'b0;
            S_AXI_RDATA   <= 32'b0;
            S_AXI_RRESP   <= 2'b00;
            S_AXI_RVALID  <= 1'b0;

            awaddr_q <= 32'b0;
            wdata_q  <= 32'b0;
            wstrb_q  <= 4'b0000;

            sram_addr <= 10'b0;
            sram_i    <= 36'b0;
            sram_csb  <= 1'b1;
            sram_web  <= 1'b1;
        end
        else begin

            case (state)

                // ====================================================
                // IDLE
                // Accept either AXI read or AXI write.
                //
                // For write, this simple slave accepts AW and W together.
                // This is okay because our AXI master wrapper drives
                // AWVALID and WVALID together and keeps them high until
                // accepted.
                // ====================================================
                IDLE: begin
                    S_AXI_BVALID <= 1'b0;
                    S_AXI_RVALID <= 1'b0;

                    sram_csb <= 1'b1;
                    sram_web <= 1'b1;

                    S_AXI_ARREADY <= 1'b1;
                    S_AXI_AWREADY <= 1'b1;
                    S_AXI_WREADY  <= 1'b1;

                    // Write has priority if both read and write arrive.
                    if (S_AXI_AWVALID && S_AXI_WVALID) begin
                        awaddr_q <= S_AXI_AWADDR;
                        wdata_q  <= S_AXI_WDATA;
                        wstrb_q  <= S_AXI_WSTRB;

                        S_AXI_AWREADY <= 1'b0;
                        S_AXI_WREADY  <= 1'b0;
                        S_AXI_ARREADY <= 1'b0;

                        // First read old SRAM word for read-modify-write
                        sram_addr <= S_AXI_AWADDR[11:2];
                        sram_csb  <= 1'b0;
                        sram_web  <= 1'b1;

                        state <= WRITE_READ_WAIT;
                    end
                    else if (S_AXI_ARVALID) begin
                        S_AXI_ARREADY <= 1'b0;
                        S_AXI_AWREADY <= 1'b0;
                        S_AXI_WREADY  <= 1'b0;

                        // Start SRAM read
                        sram_addr <= S_AXI_ARADDR[11:2];
                        sram_csb  <= 1'b0;
                        sram_web  <= 1'b1;

                        state <= READ_WAIT;
                    end
                    else begin
                        state <= IDLE;
                    end
                end

                // ====================================================
                // READ_WAIT
                // SRAM samples address on negedge because CE = ~clk.
                // Wait one cycle, then capture sram_o.
                // ====================================================
                READ_WAIT: begin
                    S_AXI_ARREADY <= 1'b0;
                    S_AXI_AWREADY <= 1'b0;
                    S_AXI_WREADY  <= 1'b0;

                    sram_csb <= 1'b0;
                    sram_web <= 1'b1;

                    state <= READ_RESP;
                end

                              // ====================================================
                // READ_RESP
                // Return AXI read data.
                // Keep RVALID high for at least one full cycle so the
                // AXI master can sample it.
                // ====================================================
                READ_RESP: begin
                    sram_csb <= 1'b1;
                    sram_web <= 1'b1;

                        if (!S_AXI_RVALID) begin
                        S_AXI_RDATA  <= sram_o[31:0];
                        S_AXI_RRESP  <= 2'b00;      // OKAY
                        S_AXI_RVALID <= 1'b1;
                        state        <= READ_RESP;
                    end
                    else if (S_AXI_RREADY) begin
                        S_AXI_RVALID <= 1'b0;
                        state <= IDLE;
                    end
                    else begin
                        state <= READ_RESP;
                    end
                end

                // ====================================================
                // WRITE_READ_WAIT
                // Wait for old SRAM word to become available.
                // This is needed because SPRAM has no byte write enable.
                // We use AXI WSTRB by doing read-modify-write.
                // ====================================================
                WRITE_READ_WAIT: begin
                    sram_csb <= 1'b0;
                    sram_web <= 1'b1;

                    state <= WRITE_DO;
                end

                // ====================================================
                // WRITE_DO
                // Merge old SRAM word with new AXI write data using WSTRB.
                // Then perform SRAM write.
                // ====================================================
                WRITE_DO: begin
                    sram_addr <= awaddr_q[11:2];

                    sram_i[31:0] <= merge_wstrb(sram_o[31:0], wdata_q, wstrb_q);
                    sram_i[35:32] <= 4'b0000;

                    sram_csb <= 1'b0;
                    sram_web <= 1'b0;

                    state <= WRITE_RESP;
                end

                             // ====================================================
                // WRITE_RESP
                // Return AXI write response.
                // Keep BVALID high for at least one full cycle so the
                // AXI master can sample it.
                // ====================================================
                WRITE_RESP: begin
                    sram_csb <= 1'b1;
                    sram_web <= 1'b1;

                    if (!S_AXI_BVALID) begin
                        S_AXI_BRESP  <= 2'b00;      // OKAY
                        S_AXI_BVALID <= 1'b1;
                        state        <= WRITE_RESP;
                    end
                    else if (S_AXI_BREADY) begin
                        S_AXI_BVALID <= 1'b0;
                        state        <= IDLE;
                    end
                    else begin
                        state <= WRITE_RESP;
                    end
                end

                default: begin
                    state <= IDLE;
                end

            endcase
        end
    end

endmodule
