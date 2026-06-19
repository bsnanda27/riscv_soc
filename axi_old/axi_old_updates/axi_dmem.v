// =============================================================================
//  axi_dmem.v  —  AXI4-Lite Data SRAM Slave
//  Single-cycle read latency (register on RDATA output for timing closure).
//  Byte-lane write enable via WSTRB.
//  Depth = DEPTH words (4 bytes each).
// =============================================================================
`timescale 1ns/1ps
`default_nettype none

module axi_dmem #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter DEPTH      = 8192         // 32 KB
)(
    input  wire                    aclk,
    input  wire                    aresetn,

    input  wire [ADDR_WIDTH-1:0]   S_AWADDR,
    input  wire [2:0]              S_AWPROT,
    input  wire                    S_AWVALID,
    output reg                     S_AWREADY,

    input  wire [DATA_WIDTH-1:0]   S_WDATA,
    input  wire [DATA_WIDTH/8-1:0] S_WSTRB,
    input  wire                    S_WVALID,
    output reg                     S_WREADY,

    output reg  [1:0]              S_BRESP,
    output reg                     S_BVALID,
    input  wire                    S_BREADY,

    input  wire [ADDR_WIDTH-1:0]   S_ARADDR,
    input  wire [2:0]              S_ARPROT,
    input  wire                    S_ARVALID,
    output reg                     S_ARREADY,

    output reg  [DATA_WIDTH-1:0]   S_RDATA,
    output reg  [1:0]              S_RRESP,
    output reg                     S_RVALID,
    input  wire                    S_RREADY
);
    // ---- Memory array -------------------------------------------------------
    localparam AW = $clog2(DEPTH);
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    wire [AW-1:0] waddr = S_AWADDR[AW+1:2];   // word-indexed
    wire [AW-1:0] raddr = S_ARADDR[AW+1:2];

    // ---- Write FSM ----------------------------------------------------------
    localparam [1:0] W_IDLE=2'd0, W_DATA=2'd1, W_RESP=2'd2;
    reg [1:0] w_state;
    reg [ADDR_WIDTH-1:0] aw_lat;

    always @(posedge aclk) begin
        if (!aresetn) begin
            w_state   <= W_IDLE;
            S_AWREADY <= 1'b0;
            S_WREADY  <= 1'b0;
            S_BVALID  <= 1'b0;
            S_BRESP   <= 2'b00;
        end else begin
            case (w_state)
                W_IDLE: begin
                    S_BVALID  <= 1'b0;
                    S_AWREADY <= 1'b1;
                    if (S_AWVALID && S_AWREADY) begin
                        aw_lat    <= S_AWADDR;
                        S_AWREADY <= 1'b0;
                        S_WREADY  <= 1'b1;
                        w_state   <= W_DATA;
                    end
                end
                W_DATA: begin
                    if (S_WVALID && S_WREADY) begin
                        if (S_WSTRB[0]) mem[aw_lat[AW+1:2]][ 7: 0] <= S_WDATA[ 7: 0];
                        if (S_WSTRB[1]) mem[aw_lat[AW+1:2]][15: 8] <= S_WDATA[15: 8];
                        if (S_WSTRB[2]) mem[aw_lat[AW+1:2]][23:16] <= S_WDATA[23:16];
                        if (S_WSTRB[3]) mem[aw_lat[AW+1:2]][31:24] <= S_WDATA[31:24];
                        S_WREADY <= 1'b0;
                        S_BRESP  <= 2'b00;
                        S_BVALID <= 1'b1;
                        w_state  <= W_RESP;
                    end
                end
                W_RESP: begin
                    if (S_BREADY && S_BVALID) begin
                        S_BVALID <= 1'b0;
                        w_state  <= W_IDLE;
                    end
                end
                default: w_state <= W_IDLE;
            endcase
        end
    end

    // ---- Read FSM -----------------------------------------------------------
    localparam [1:0] R_IDLE=2'd0, R_DATA=2'd1;
    reg [1:0] r_state;

    always @(posedge aclk) begin
        if (!aresetn) begin
            r_state   <= R_IDLE;
            S_ARREADY <= 1'b0;
            S_RVALID  <= 1'b0;
            S_RRESP   <= 2'b00;
            S_RDATA   <= {DATA_WIDTH{1'b0}};
        end else begin
            case (r_state)
                R_IDLE: begin
                    S_RVALID  <= 1'b0;
                    S_ARREADY <= 1'b1;
                    if (S_ARVALID && S_ARREADY) begin
                        S_ARREADY <= 1'b0;
                        S_RDATA   <= mem[raddr];
                        S_RRESP   <= 2'b00;
                        S_RVALID  <= 1'b1;
                        r_state   <= R_DATA;
                    end
                end
                R_DATA: begin
                    if (S_RVALID && S_RREADY) begin
                        S_RVALID <= 1'b0;
                        r_state  <= R_IDLE;
                    end
                end
                default: r_state <= R_IDLE;
            endcase
        end
    end
endmodule
`default_nettype wire
