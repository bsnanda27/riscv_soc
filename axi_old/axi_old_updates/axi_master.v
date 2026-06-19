`timescale 1ns/1ps

module axi_master #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input  wire                    aclk,
    input  wire                    aresetn,

    input  wire                    core_mem_we,
    input  wire                    core_mem_re,
    input  wire [ADDR_WIDTH-1:0]   core_mem_addr,
    input  wire [DATA_WIDTH-1:0]   core_mem_wdata,
    input  wire [2:0]              core_mem_acc,
    output reg  [DATA_WIDTH-1:0]   core_mem_rdata,
    output wire                    core_stall,

    output reg  [ADDR_WIDTH-1:0]   M_AXI_AWADDR,
    output reg  [2:0]              M_AXI_AWPROT,
    output reg                     M_AXI_AWVALID,
    input  wire                    M_AXI_AWREADY,

    output reg  [DATA_WIDTH-1:0]   M_AXI_WDATA,
    output reg  [DATA_WIDTH/8-1:0] M_AXI_WSTRB,
    output reg                     M_AXI_WVALID,
    input  wire                    M_AXI_WREADY,

    input  wire [1:0]              M_AXI_BRESP,
    input  wire                    M_AXI_BVALID,
    output reg                     M_AXI_BREADY,

    output reg  [ADDR_WIDTH-1:0]   M_AXI_ARADDR,
    output reg  [2:0]              M_AXI_ARPROT,
    output reg                     M_AXI_ARVALID,
    input  wire                    M_AXI_ARREADY,

    input  wire [DATA_WIDTH-1:0]   M_AXI_RDATA,
    input  wire [1:0]              M_AXI_RRESP,
    input  wire                    M_AXI_RVALID,
    output reg                     M_AXI_RREADY
);

    localparam [2:0]
        ST_IDLE  = 3'd0,
        ST_WADDR = 3'd1,
        ST_WDATA = 3'd2,
        ST_WRESP = 3'd3,
        ST_RADDR = 3'd4,
        ST_RDATA = 3'd5;

    reg [2:0] state, next_state;

    reg                    req_we;
    reg [ADDR_WIDTH-1:0]   req_addr;
    reg [DATA_WIDTH-1:0]   req_wdata;
    reg [2:0]              req_acc;

    wire core_req;
    assign core_req = core_mem_we | core_mem_re;

    always @(posedge aclk) begin
        if (!aresetn) begin
            req_we    <= 1'b0;
            req_addr  <= {ADDR_WIDTH{1'b0}};
            req_wdata <= {DATA_WIDTH{1'b0}};
            req_acc   <= 3'b010;
        end else if ((state == ST_IDLE) && core_req) begin
            req_we    <= core_mem_we;
            req_addr  <= core_mem_addr;
            req_wdata <= core_mem_wdata;
            req_acc   <= core_mem_acc;
        end
    end

    reg [DATA_WIDTH/8-1:0] wstrb_comb;

    always @* begin
        case (req_acc[1:0])
            2'b00: begin
                case (req_addr[1:0])
                    2'b00: wstrb_comb = 4'b0001;
                    2'b01: wstrb_comb = 4'b0010;
                    2'b10: wstrb_comb = 4'b0100;
                    2'b11: wstrb_comb = 4'b1000;
                    default: wstrb_comb = 4'b0001;
                endcase
            end
            2'b01: begin
                case (req_addr[1])
                    1'b0: wstrb_comb = 4'b0011;
                    1'b1: wstrb_comb = 4'b1100;
                    default: wstrb_comb = 4'b0011;
                endcase
            end
            default: wstrb_comb = 4'b1111;
        endcase
    end

    reg [DATA_WIDTH-1:0] rdata_extended;
    reg [7:0]  byte_sel;
    reg [15:0] half_sel;

    always @* begin
        case (req_addr[1:0])
            2'b00: byte_sel = M_AXI_RDATA[7:0];
            2'b01: byte_sel = M_AXI_RDATA[15:8];
            2'b10: byte_sel = M_AXI_RDATA[23:16];
            2'b11: byte_sel = M_AXI_RDATA[31:24];
            default: byte_sel = M_AXI_RDATA[7:0];
        endcase

        if (req_addr[1])
            half_sel = M_AXI_RDATA[31:16];
        else
            half_sel = M_AXI_RDATA[15:0];

        case (req_acc[1:0])
            2'b00: begin
                if (req_acc[2])
                    rdata_extended = {{24{byte_sel[7]}}, byte_sel};
                else
                    rdata_extended = {24'b0, byte_sel};
            end
            2'b01: begin
                if (req_acc[2])
                    rdata_extended = {{16{half_sel[15]}}, half_sel};
                else
                    rdata_extended = {16'b0, half_sel};
            end
            default: begin
                rdata_extended = M_AXI_RDATA;
            end
        endcase
    end

    always @(posedge aclk) begin
        if (!aresetn)
            state <= ST_IDLE;
        else
            state <= next_state;
    end

    always @* begin
        next_state    = state;

        M_AXI_AWADDR  = req_addr;
        M_AXI_AWPROT  = 3'b000;
        M_AXI_AWVALID = 1'b0;

        M_AXI_WDATA   = req_wdata;
        M_AXI_WSTRB   = wstrb_comb;
        M_AXI_WVALID  = 1'b0;

        M_AXI_BREADY  = 1'b0;

        M_AXI_ARADDR  = req_addr;
        M_AXI_ARPROT  = 3'b000;
        M_AXI_ARVALID = 1'b0;

        M_AXI_RREADY  = 1'b0;

        case (state)
            ST_IDLE: begin
                if (core_req) begin
                    if (core_mem_we)
                        next_state = ST_WADDR;
                    else
                        next_state = ST_RADDR;
                end
            end

            ST_WADDR: begin
                M_AXI_AWADDR  = req_addr;
                M_AXI_AWVALID = 1'b1;
                M_AXI_WDATA   = req_wdata;
                M_AXI_WSTRB   = wstrb_comb;
                M_AXI_WVALID  = 1'b1;

                if (M_AXI_AWREADY && M_AXI_WREADY)
                    next_state = ST_WRESP;
                else if (M_AXI_AWREADY && !M_AXI_WREADY)
                    next_state = ST_WDATA;
            end

            ST_WDATA: begin
                M_AXI_WDATA  = req_wdata;
                M_AXI_WSTRB  = wstrb_comb;
                M_AXI_WVALID = 1'b1;

                if (M_AXI_WREADY)
                    next_state = ST_WRESP;
            end

            ST_WRESP: begin
                M_AXI_BREADY = 1'b1;
                if (M_AXI_BVALID)
                    next_state = ST_IDLE;
            end

            ST_RADDR: begin
                M_AXI_ARADDR  = req_addr;
                M_AXI_ARVALID = 1'b1;
                if (M_AXI_ARREADY)
                    next_state = ST_RDATA;
            end

            ST_RDATA: begin
                M_AXI_RREADY = 1'b1;
                if (M_AXI_RVALID)
                    next_state = ST_IDLE;
            end

            default: begin
                next_state = ST_IDLE;
            end
        endcase
    end

    always @(posedge aclk) begin
        if (!aresetn)
            core_mem_rdata <= {DATA_WIDTH{1'b0}};
        else if ((state == ST_RDATA) && M_AXI_RVALID && M_AXI_RREADY)
            core_mem_rdata <= rdata_extended;
    end

    assign core_stall = (state != ST_IDLE) || ((state == ST_IDLE) && core_req);

endmodule
