module axi_master #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input                        aclk,
    input                        aresetn,

    // Simple core data bus
    input                        core_req,
    input                        core_we,
    input      [ADDR_WIDTH-1:0]  core_addr,
    input      [DATA_WIDTH-1:0]  core_wdata,
    output reg [DATA_WIDTH-1:0]  core_rdata,
    output reg                   core_ready,

    // AXI4-Lite master interface
    // Write address channel
    output reg [ADDR_WIDTH-1:0]  M_AWADDR,
    output reg                   M_AWVALID,
    input                        M_AWREADY,

    // Write data channel
    output reg [DATA_WIDTH-1:0]  M_WDATA,
    output reg [DATA_WIDTH/8-1:0] M_WSTRB,
    output reg                   M_WVALID,
    input                        M_WREADY,

    // Write response channel
    input      [1:0]             M_BRESP,
    input                        M_BVALID,
    output reg                   M_BREADY,

    // Read address channel
    output reg [ADDR_WIDTH-1:0]  M_ARADDR,
    output reg                   M_ARVALID,
    input                        M_ARREADY,

    // Read data channel
    input      [DATA_WIDTH-1:0]  M_RDATA,
    input      [1:0]             M_RRESP,
    input                        M_RVALID,
    output reg                   M_RREADY
);

    localparam ST_IDLE       = 3'd0;
    localparam ST_W_ADDR     = 3'd1;
    localparam ST_W_DATA     = 3'd2;
    localparam ST_W_RESP     = 3'd3;
    localparam ST_R_ADDR     = 3'd4;
    localparam ST_R_DATA     = 3'd5;

    reg [2:0] state, next_state;

    // Registered copies of core request (so core_req can be a pulse)
    reg              req_we;
    reg [ADDR_WIDTH-1:0] req_addr;
    reg [DATA_WIDTH-1:0] req_wdata;

    // State register
    always @(posedge aclk) begin
        if (!aresetn)
            state <= ST_IDLE;
        else
            state <= next_state;
    end

    // Latch request when we see it in IDLE
    always @(posedge aclk) begin
        if (!aresetn) begin
            req_we    <= 1'b0;
            req_addr  <= {ADDR_WIDTH{1'b0}};
            req_wdata <= {DATA_WIDTH{1'b0}};
        end else if (state == ST_IDLE && core_req) begin
            req_we    <= core_we;
            req_addr  <= core_addr;
            req_wdata <= core_wdata;
        end
    end

    // Outputs and next-state logic
    always @* begin
        // Default outputs
        M_AWADDR  = req_addr;
        M_AWVALID = 1'b0;
        M_WDATA   = req_wdata;
        M_WSTRB   = {DATA_WIDTH/8{1'b1}};
        M_WVALID  = 1'b0;
        M_BREADY  = 1'b0;

        M_ARADDR  = req_addr;
        M_ARVALID = 1'b0;
        M_RREADY  = 1'b0;

        core_ready = 1'b0;

        next_state = state;

        case (state)
            ST_IDLE: begin
                if (core_req) begin
                    if (core_we)
                        next_state = ST_W_ADDR;
                    else
                        next_state = ST_R_ADDR;
                end
            end

            // ------------- WRITE -------------
            ST_W_ADDR: begin
                M_AWVALID = 1'b1;
                if (M_AWREADY) begin
                    next_state = ST_W_DATA;
                end
            end

            ST_W_DATA: begin
                M_WVALID = 1'b1;
                if (M_WREADY) begin
                    next_state = ST_W_RESP;
                end
            end

            ST_W_RESP: begin
                M_BREADY = 1'b1;
                if (M_BVALID) begin
                    core_ready = 1'b1;  // write completed
                    next_state = ST_IDLE;
                end
            end

            // ------------- READ --------------
            ST_R_ADDR: begin
                M_ARVALID = 1'b1;
                if (M_ARREADY) begin
                    next_state = ST_R_DATA;
                end
            end

            ST_R_DATA: begin
                M_RREADY = 1'b1;
                if (M_RVALID) begin
                    core_ready = 1'b1;  // read completed
                    next_state = ST_IDLE;
                end
            end

            default: next_state = ST_IDLE;
        endcase
    end

    // Capture read data
    always @(posedge aclk) begin
        if (!aresetn)
            core_rdata <= {DATA_WIDTH{1'b0}};
        else if (state == ST_R_DATA && M_RVALID && M_RREADY)
            core_rdata <= M_RDATA;
    end

endmodule
