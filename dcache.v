`timescale 1ns/1fs

module dcache (
    input wire clk,
    input wire rst,

    // ============================================================
    // CPU Core Side Interface
    // ============================================================
    input  wire [31:0] cpu_dmem_addr,
    input  wire        cpu_dmem_valid,
    input  wire        cpu_dmem_write,
    input  wire [3:0]  cpu_dmem_wstrb,
    input  wire [31:0] cpu_dmem_wdata,
    output reg         cpu_dmem_ready,
    output reg  [31:0] cpu_dmem_rdata,

    // ============================================================
    // AXI Wrapper Side Interface
    // ============================================================
    output reg         w_dmem_req,
    output reg         w_dmem_wr,
    output reg  [31:0] w_dmem_addr,
    output reg  [3:0]  w_dmem_wstrb,
    output reg  [31:0] w_dmem_wdata,
    input  wire        w_dmem_ready,
    input  wire [31:0] w_dmem_rdata
);

    // States
    localparam IDLE          = 4'd0,
               FETCH_W0_REQ  = 4'd1,
               FETCH_W0_WAIT = 4'd2,
               FETCH_W1_REQ  = 4'd3,
               FETCH_W1_WAIT = 4'd4,
               FETCH_W2_REQ  = 4'd5,
               FETCH_W2_WAIT = 4'd6,
               FETCH_W3_REQ  = 4'd7,
               FETCH_W3_WAIT = 4'd8,
               COMMIT        = 4'd9,
               WRITE_REQ     = 4'd10,
               WRITE_WAIT    = 4'd11;

    reg [3:0] state;

    // Address Slicing
    wire [5:0]  index  = cpu_dmem_addr[9:4];
    wire [21:0] tag    = cpu_dmem_addr[31:10];
    wire [1:0]  offset = cpu_dmem_addr[3:2];

    // Arrays
    reg [21:0] tag_mem   [0:63];
    reg        valid_mem [0:63];
    reg [31:0] mem_w0    [0:63];
    reg [31:0] mem_w1    [0:63];
    reg [31:0] mem_w2    [0:63];
    reg [31:0] mem_w3    [0:63];

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

    reg [31:0] latched_addr, latched_wdata;
    reg [3:0]  latched_wstrb;
    reg [31:0] buf_w0, buf_w1, buf_w2, buf_w3;
    integer i;

    // Combinational Output Assignments
    always @(*) begin
        cpu_dmem_ready = 1'b0;
        cpu_dmem_rdata = 32'b0;
        w_dmem_req     = 1'b0;
        w_dmem_wr      = 1'b0;
        w_dmem_addr    = 32'b0;
        w_dmem_wstrb   = 4'b0;
        w_dmem_wdata   = 32'b0;

        if (state == IDLE) begin
            if (cpu_dmem_valid) begin
                if (!cpu_dmem_write && cache_hit) begin
                    cpu_dmem_ready = 1'b1;
                    cpu_dmem_rdata = hit_rdata;
                end
            end
        end else if (state == WRITE_REQ || state == WRITE_WAIT) begin
            w_dmem_req   = 1'b1;
            w_dmem_wr    = 1'b1;
            w_dmem_addr  = latched_addr;
            w_dmem_wstrb = latched_wstrb;
            w_dmem_wdata = latched_wdata;
            if (w_dmem_ready) begin
                cpu_dmem_ready = 1'b1; // Signal core that write finalized
            end
        end else begin
            // Line Fill Read Transactions
            w_dmem_wr = 1'b0;
            case (state)
                FETCH_W0_REQ, FETCH_W0_WAIT: begin
                    w_dmem_req  = 1'b1;
                    w_dmem_addr = {latched_addr[31:4], 4'b0000};
                end
                FETCH_W1_REQ, FETCH_W1_WAIT: begin
                    w_dmem_req  = 1'b1;
                    w_dmem_addr = {latched_addr[31:4], 4'b0100};
                end
                FETCH_W2_REQ, FETCH_W2_WAIT: begin
                    w_dmem_req  = 1'b1;
                    w_dmem_addr = {latched_addr[31:4], 4'b1000};
                end
                FETCH_W3_REQ, FETCH_W3_WAIT: begin
                    w_dmem_req  = 1'b1;
                    w_dmem_addr = {latched_addr[31:4], 4'b1100};
                end
            endcase
        end
    end

    // Sequential Write Handling and Cache Incoherency Protection
    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            for (i = 0; i < 64; i = i + 1) begin
                valid_mem[i] <= 1'b0;
            end
        end else begin
            case (state)
                IDLE: begin
                    if (cpu_dmem_valid) begin
                        latched_addr  <= cpu_dmem_addr;
                        latched_wdata <= cpu_dmem_wdata;
                        latched_wstrb <= cpu_dmem_wstrb;
                        
                        if (cpu_dmem_write) begin
                            state <= WRITE_REQ;
                            // Synchronous cache write-update if block hits
                            if (cache_hit) begin
                                case (offset)
                                    2'b00: begin
                                        if (cpu_dmem_wstrb[0]) mem_w0[index][7:0]   <= cpu_dmem_wdata[7:0];
                                        if (cpu_dmem_wstrb[1]) mem_w0[index][15:8]  <= cpu_dmem_wdata[15:8];
                                        if (cpu_dmem_wstrb[2]) mem_w0[index][23:16] <= cpu_dmem_wdata[23:16];
                                        if (cpu_dmem_wstrb[3]) mem_w0[index][31:24] <= cpu_dmem_wdata[31:24];
                                    end
                                    2'b01: begin
                                        if (cpu_dmem_wstrb[0]) mem_w1[index][7:0]   <= cpu_dmem_wdata[7:0];
                                        if (cpu_dmem_wstrb[1]) mem_w1[index][15:8]  <= cpu_dmem_wdata[15:8];
                                        if (cpu_dmem_wstrb[2]) mem_w1[index][23:16] <= cpu_dmem_wdata[23:16];
                                        if (cpu_dmem_wstrb[3]) mem_w1[index][31:24] <= cpu_dmem_wdata[31:24];
                                    end
                                    2'b10: begin
                                        if (cpu_dmem_wstrb[0]) mem_w2[index][7:0]   <= cpu_dmem_wdata[7:0];
                                        if (cpu_dmem_wstrb[1]) mem_w2[index][15:8]  <= cpu_dmem_wdata[15:8];
                                        if (cpu_dmem_wstrb[2]) mem_w2[index][23:16] <= cpu_dmem_wdata[23:16];
                                        if (cpu_dmem_wstrb[3]) mem_w2[index][31:24] <= cpu_dmem_wdata[31:24];
                                    end
                                    2'b11: begin
                                        if (cpu_dmem_wstrb[0]) mem_w3[index][7:0]   <= cpu_dmem_wdata[7:0];
                                        if (cpu_dmem_wstrb[1]) mem_w3[index][15:8]  <= cpu_dmem_wdata[15:8];
                                        if (cpu_dmem_wstrb[2]) mem_w3[index][23:16] <= cpu_dmem_wdata[23:16];
                                        if (cpu_dmem_wstrb[3]) mem_w3[index][31:24] <= cpu_dmem_wdata[31:24];
                                    end
                                endcase
                            end
                        end else if (!cache_hit) begin
                            state <= FETCH_W0_REQ;
                        end
                    end
                end

                // Write Handling Loop
                WRITE_REQ:  state <= WRITE_WAIT;
                WRITE_WAIT: begin
                    if (w_dmem_ready) state <= IDLE;
                end

                // Line Fill Handling Loop
                FETCH_W0_REQ:  state <= FETCH_W0_WAIT;
                FETCH_W0_WAIT: begin
                    if (w_dmem_ready) begin
                        buf_w0 <= w_dmem_rdata;
                        state  <= FETCH_W1_REQ;
                    end
                end

                FETCH_W1_REQ:  state <= FETCH_W1_WAIT;
                FETCH_W1_WAIT: begin
                    if (w_dmem_ready) begin
                        buf_w1 <= w_dmem_rdata;
                        state  <= FETCH_W2_REQ;
                    end
                end

                FETCH_W2_REQ:  state <= FETCH_W2_WAIT;
                FETCH_W2_WAIT: begin
                    if (w_dmem_ready) begin
                        buf_w2 <= w_dmem_rdata;
                        state  <= FETCH_W3_REQ;
                    end
                end

                FETCH_W3_REQ:  state <= FETCH_W3_WAIT;
                FETCH_W3_WAIT: begin
                    if (w_dmem_ready) begin
                        buf_w3 <= w_dmem_rdata;
                        state  <= COMMIT;
                    end
                end

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