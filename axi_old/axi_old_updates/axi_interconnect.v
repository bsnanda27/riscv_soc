// =============================================================================
//  axi_interconnect.v  —  AXI4-Lite 1-Master × 3-Slave Address Decoder
//
//  Decode table (top 4 bits):
//    M_AW/ARADDR[31:28] == 4'h0  → Slave 0  (data SRAM)
//    M_AW/ARADDR[31:28] == 4'h4 && addr[12]==0 → Slave 1 (GPIO)
//    M_AW/ARADDR[31:28] == 4'h4 && addr[12]==1 → Slave 2 (SPI)
// =============================================================================
`timescale 1ns/1ps
`default_nettype none

module axi_interconnect #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input  wire                    aclk,
    input  wire                    aresetn,

    input  wire [ADDR_WIDTH-1:0]   M_AWADDR,
    input  wire [2:0]              M_AWPROT,
    input  wire                    M_AWVALID,
    output wire                    M_AWREADY,

    input  wire [DATA_WIDTH-1:0]   M_WDATA,
    input  wire [DATA_WIDTH/8-1:0] M_WSTRB,
    input  wire                    M_WVALID,
    output wire                    M_WREADY,

    output wire [1:0]              M_BRESP,
    output wire                    M_BVALID,
    input  wire                    M_BREADY,

    input  wire [ADDR_WIDTH-1:0]   M_ARADDR,
    input  wire [2:0]              M_ARPROT,
    input  wire                    M_ARVALID,
    output wire                    M_ARREADY,

    output wire [DATA_WIDTH-1:0]   M_RDATA,
    output wire [1:0]              M_RRESP,
    output wire                    M_RVALID,
    input  wire                    M_RREADY,

    output wire [ADDR_WIDTH-1:0]   S0_AWADDR,
    output wire [2:0]              S0_AWPROT,
    output wire                    S0_AWVALID,
    input  wire                    S0_AWREADY,
    output wire [DATA_WIDTH-1:0]   S0_WDATA,
    output wire [DATA_WIDTH/8-1:0] S0_WSTRB,
    output wire                    S0_WVALID,
    input  wire                    S0_WREADY,
    input  wire [1:0]              S0_BRESP,
    input  wire                    S0_BVALID,
    output wire                    S0_BREADY,
    output wire [ADDR_WIDTH-1:0]   S0_ARADDR,
    output wire [2:0]              S0_ARPROT,
    output wire                    S0_ARVALID,
    input  wire                    S0_ARREADY,
    input  wire [DATA_WIDTH-1:0]   S0_RDATA,
    input  wire [1:0]              S0_RRESP,
    input  wire                    S0_RVALID,
    output wire                    S0_RREADY,

    output wire [ADDR_WIDTH-1:0]   S1_AWADDR,
    output wire [2:0]              S1_AWPROT,
    output wire                    S1_AWVALID,
    input  wire                    S1_AWREADY,
    output wire [DATA_WIDTH-1:0]   S1_WDATA,
    output wire [DATA_WIDTH/8-1:0] S1_WSTRB,
    output wire                    S1_WVALID,
    input  wire                    S1_WREADY,
    input  wire [1:0]              S1_BRESP,
    input  wire                    S1_BVALID,
    output wire                    S1_BREADY,
    output wire [ADDR_WIDTH-1:0]   S1_ARADDR,
    output wire [2:0]              S1_ARPROT,
    output wire                    S1_ARVALID,
    input  wire                    S1_ARREADY,
    input  wire [DATA_WIDTH-1:0]   S1_RDATA,
    input  wire [1:0]              S1_RRESP,
    input  wire                    S1_RVALID,
    output wire                    S1_RREADY,

    output wire [ADDR_WIDTH-1:0]   S2_AWADDR,
    output wire [2:0]              S2_AWPROT,
    output wire                    S2_AWVALID,
    input  wire                    S2_AWREADY,
    output wire [DATA_WIDTH-1:0]   S2_WDATA,
    output wire [DATA_WIDTH/8-1:0] S2_WSTRB,
    output wire                    S2_WVALID,
    input  wire                    S2_WREADY,
    input  wire [1:0]              S2_BRESP,
    input  wire                    S2_BVALID,
    output wire                    S2_BREADY,
    output wire [ADDR_WIDTH-1:0]   S2_ARADDR,
    output wire [2:0]              S2_ARPROT,
    output wire                    S2_ARVALID,
    input  wire                    S2_ARREADY,
    input  wire [DATA_WIDTH-1:0]   S2_RDATA,
    input  wire [1:0]              S2_RRESP,
    input  wire                    S2_RVALID,
    output wire                    S2_RREADY
);

    wire aw_s0 = (M_AWADDR[31:28] == 4'h0);
    wire aw_s1 = (M_AWADDR[31:28] == 4'h4) && (M_AWADDR[12] == 1'b0);
    wire aw_s2 = (M_AWADDR[31:28] == 4'h4) && (M_AWADDR[12] == 1'b1);

    wire ar_s0 = (M_ARADDR[31:28] == 4'h0);
    wire ar_s1 = (M_ARADDR[31:28] == 4'h4) && (M_ARADDR[12] == 1'b0);
    wire ar_s2 = (M_ARADDR[31:28] == 4'h4) && (M_ARADDR[12] == 1'b1);

    reg [1:0] wsel;
    reg [1:0] rsel;

    always @(posedge aclk) begin
        if (!aresetn) begin
            wsel <= 2'd0;
            rsel <= 2'd0;
        end else begin
            if (M_AWVALID && M_AWREADY)
                wsel <= aw_s1 ? 2'd1 : aw_s2 ? 2'd2 : 2'd0;
            if (M_ARVALID && M_ARREADY)
                rsel <= ar_s1 ? 2'd1 : ar_s2 ? 2'd2 : 2'd0;
        end
    end

    assign S0_AWADDR  = M_AWADDR;
    assign S0_AWPROT  = M_AWPROT;
    assign S0_AWVALID = M_AWVALID & aw_s0;

    assign S1_AWADDR  = M_AWADDR;
    assign S1_AWPROT  = M_AWPROT;
    assign S1_AWVALID = M_AWVALID & aw_s1;

    assign S2_AWADDR  = M_AWADDR;
    assign S2_AWPROT  = M_AWPROT;
    assign S2_AWVALID = M_AWVALID & aw_s2;

    assign M_AWREADY = aw_s0 ? S0_AWREADY : aw_s1 ? S1_AWREADY : S2_AWREADY;

    assign S0_WDATA  = M_WDATA;
    assign S0_WSTRB  = M_WSTRB;
    assign S0_WVALID = M_WVALID & (wsel == 2'd0);

    assign S1_WDATA  = M_WDATA;
    assign S1_WSTRB  = M_WSTRB;
    assign S1_WVALID = M_WVALID & (wsel == 2'd1);

    assign S2_WDATA  = M_WDATA;
    assign S2_WSTRB  = M_WSTRB;
    assign S2_WVALID = M_WVALID & (wsel == 2'd2);

    assign M_WREADY = (wsel == 2'd0) ? S0_WREADY : (wsel == 2'd1) ? S1_WREADY : S2_WREADY;

    assign S0_BREADY = M_BREADY & (wsel == 2'd0);
    assign S1_BREADY = M_BREADY & (wsel == 2'd1);
    assign S2_BREADY = M_BREADY & (wsel == 2'd2);

    assign M_BVALID = (wsel == 2'd0) ? S0_BVALID : (wsel == 2'd1) ? S1_BVALID : S2_BVALID;
    assign M_BRESP  = (wsel == 2'd0) ? S0_BRESP  : (wsel == 2'd1) ? S1_BRESP  : S2_BRESP;

    assign S0_ARADDR  = M_ARADDR;
    assign S0_ARPROT  = M_ARPROT;
    assign S0_ARVALID = M_ARVALID & ar_s0;

    assign S1_ARADDR  = M_ARADDR;
    assign S1_ARPROT  = M_ARPROT;
    assign S1_ARVALID = M_ARVALID & ar_s1;

    assign S2_ARADDR  = M_ARADDR;
    assign S2_ARPROT  = M_ARPROT;
    assign S2_ARVALID = M_ARVALID & ar_s2;

    assign M_ARREADY = ar_s0 ? S0_ARREADY : ar_s1 ? S1_ARREADY : S2_ARREADY;

    assign S0_RREADY = M_RREADY & (rsel == 2'd0);
    assign S1_RREADY = M_RREADY & (rsel == 2'd1);
    assign S2_RREADY = M_RREADY & (rsel == 2'd2);

    assign M_RVALID = (rsel == 2'd0) ? S0_RVALID : (rsel == 2'd1) ? S1_RVALID : S2_RVALID;
    assign M_RDATA  = (rsel == 2'd0) ? S0_RDATA  : (rsel == 2'd1) ? S1_RDATA  : S2_RDATA;
    assign M_RRESP  = (rsel == 2'd0) ? S0_RRESP  : (rsel == 2'd1) ? S1_RRESP  : S2_RRESP;

endmodule

`default_nettype wire
