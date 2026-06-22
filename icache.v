`timescale 1ns/1fs

module icache (
    input wire clk,
    input wire rst,

    // ============================================================
    // CPU Core Side Interface
    // ============================================================
    input  wire [31:0] cpu_imem_addr,
    input  wire        cpu_imem_valid,
    output reg         cpu_imem_ready,
    output reg  [31:0] cpu_imem_rdata,

    // ============================================================
    // AXI Wrapper Side Interface
    // ============================================================
    output reg         w_imem_req,
    output reg  [31:0] w_imem_addr,
    input  wire        w_imem_ready,
    input  wire [31:0] w_imem_rdata
);

    // Cache States
    localparam IDLE          = 4'd0,
               FETCH_W0_REQ  = 4'd1,
               FETCH_W0_WAIT = 4'd2,
               FETCH_W1_REQ  = 4'd3,
               FETCH_W1_WAIT = 4'd4,
               FETCH_W2_REQ  = 4'd5,
               FETCH_W2_WAIT = 4'd6,
               FETCH_W3_REQ  = 4'd7,
               FETCH_W3_WAIT = 4'd8,
               COMMIT        = 4'd9;

    reg [3:0] state;

    // Address Breakdown
    wire [5:0]  index  = cpu_imem_addr[9:4];
    wire [21:0] tag    = cpu_imem_addr[31:10];
    wire [1:0]  offset = cpu_imem_addr[3:2];

    // Internal Arrays (64 lines deep)
    reg [21:0] tag_mem   [0:63];
    reg        valid_mem [0:63];
    reg [31:0] mem_w0    [0:63];
    reg [31:0] mem_w1    [0:63];
    reg [31:0] mem_w2    [0:63];
    reg [31:0] mem_w3    [0:63];

    // Hit Logic
    wire cache_hit = valid_mem[index] && (tag_mem[index] == tag);

    reg [31:0] hit_rdata;
    always @(*) begin
        case (offset)
            2'b00: hit_rdata = mem_w0[index];
            2'b01: hit_rdata = mem_w1[index];
            2'b10: hit_rdata = mem_w2[index];
            2'b11: hit_rdata = mem_w3[index];
        endcase
    end

    // Line fill staging buffers
    reg [31:0] latched_addr;
    reg [31:0] buf_w0, buf_w1, buf_w2, buf_w3;
    integer i;

    // Combinational Outputs
    always @(*) begin
        cpu_imem_ready = 1'b0;
        cpu_imem_rdata = 32'b0;
        w_imem_req     = 1'b0;
        w_imem_addr    = 32'b0;

        if (state == IDLE) begin
            if (cpu_imem_valid) begin
                if (cache_hit) begin
                    cpu_imem_ready = 1'b1;
                    cpu_imem_rdata = hit_rdata;
                end
            end
        end else begin
            // Drive AXI line fill sequencing
            case (state)
                FETCH_W0_REQ, FETCH_W0_WAIT: begin
                    w_imem_req  = 1'b1;
                    w_imem_addr = {latched_addr[31:4], 4'b0000};
                end
                FETCH_W1_REQ, FETCH_W1_WAIT: begin
                    w_imem_req  = 1'b1;
                    w_imem_addr = {latched_addr[31:4], 4'b0100};
                end
                FETCH_W2_REQ, FETCH_W2_WAIT: begin
                    w_imem_req  = 1'b1;
                    w_imem_addr = {latched_addr[31:4], 4'b1000};
                end
                FETCH_W3_REQ, FETCH_W3_WAIT: begin
                    w_imem_req  = 1'b1;
                    w_imem_addr = {latched_addr[31:4], 4'b1100};
                end
            endcase
        end
    end

    // Sequential Controller State Machine
    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            for (i = 0; i < 64; i = i + 1) begin
                valid_mem[i] <= 1'b0;
            end
        end else begin
            case (state)
                IDLE: begin
                    if (cpu_imem_valid && !cache_hit) begin
                        latched_addr <= cpu_imem_addr;
                        state        <= FETCH_W0_REQ;
                    end
                end

                // Fetch Word 0
                FETCH_W0_REQ:  state <= FETCH_W0_WAIT;
                FETCH_W0_WAIT: begin
                    if (w_imem_ready) begin
                        buf_w0 <= w_imem_rdata;
                        state  <= FETCH_W1_REQ; // wrapper returns to IDLE on drop of req
                    end
                end

                // Fetch Word 1
                FETCH_W1_REQ:  state <= FETCH_W1_WAIT;
                FETCH_W1_WAIT: begin
                    if (w_imem_ready) begin
                        buf_w1 <= w_imem_rdata;
                        state  <= FETCH_W2_REQ;
                    end
                end

                // Fetch Word 2
                FETCH_W2_REQ:  state <= FETCH_W2_WAIT;
                FETCH_W2_WAIT: begin
                    if (w_imem_ready) begin
                        buf_w2 <= w_imem_rdata;
                        state  <= FETCH_W3_REQ;
                    end
                end

                // Fetch Word 3
                FETCH_W3_REQ:  state <= FETCH_W3_WAIT;
                FETCH_W3_WAIT: begin
                    if (w_imem_ready) begin
                        buf_w3 <= w_imem_rdata;
                        state  <= COMMIT;
                    end
                end

                // Commit Entire Cache Block
                COMMIT: begin
                    mem_w0[latched_addr[9:4]]    <= buf_w0;
                    mem_w1[latched_addr[9:4]]    <= buf_w1;
                    mem_w2[latched_addr[9:4]]    <= buf_w2;
                    mem_w3[latched_addr[9:4]]    <= buf_w3;
                    tag_mem[latched_addr[9:4]]   <= latched_addr[31:10];
                    valid_mem[latched_addr[9:4]] <= 1'b1;
                    state                        <= IDLE;
                end
            endcase
        end
    end
endmodule