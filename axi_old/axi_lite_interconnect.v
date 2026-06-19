`timescale 1ns/1ps
//=============================================================================
// axi_interconnect.v  –  1-Master / 3-Slave AXI4-Lite address-decode crossbar
//
// Address map:
//   SEL_RAM  (2'b00) : 0x0000_0000 – 0x0FFF_FFFF  (bit[31:28] == 4'h0)
//   SEL_GPIO (2'b01) : 0x1000_0000 – 0x1FFF_FFFF  (bit[31:28] == 4'h1)
//   SEL_SPI  (2'b10) : 0x2000_0000 – 0x2FFF_FFFF  (bit[31:28] == 4'h2)
//   SEL_ERR  (2'b11) : all other addresses (returns SLVERR)
//=============================================================================
module axi_interconnect
(
    input  wire clk,
    input  wire rst,

    // Slave port (connects to AXI master)
    input  wire [31:0] s_awaddr,  input  wire s_awvalid, output wire s_awready,
    input  wire [31:0] s_wdata,   input  wire [3:0] s_wstrb,
    input  wire        s_wvalid,  output wire s_wready,
    output wire [1:0]  s_bresp,   output wire s_bvalid,  input  wire s_bready,
    input  wire [31:0] s_araddr,  input  wire s_arvalid, output wire s_arready,
    output wire [31:0] s_rdata,   output wire [1:0] s_rresp,
    output wire        s_rvalid,  input  wire s_rready,

    // Master port 0 — RAM
    output wire [31:0] m0_awaddr, output wire m0_awvalid, input wire m0_awready,
    output wire [31:0] m0_wdata,  output wire [3:0] m0_wstrb,
    output wire        m0_wvalid, input  wire m0_wready,
    input  wire [1:0]  m0_bresp,  input  wire m0_bvalid,  output wire m0_bready,
    output wire [31:0] m0_araddr, output wire m0_arvalid, input  wire m0_arready,
    input  wire [31:0] m0_rdata,  input  wire [1:0] m0_rresp,
    input  wire        m0_rvalid, output wire m0_rready,

    // Master port 1 — GPIO
    output wire [31:0] m1_awaddr, output wire m1_awvalid, input wire m1_awready,
    output wire [31:0] m1_wdata,  output wire [3:0] m1_wstrb,
    output wire        m1_wvalid, input  wire m1_wready,
    input  wire [1:0]  m1_bresp,  input  wire m1_bvalid,  output wire m1_bready,
    output wire [31:0] m1_araddr, output wire m1_arvalid, input  wire m1_arready,
    input  wire [31:0] m1_rdata,  input  wire [1:0] m1_rresp,
    input  wire        m1_rvalid, output wire m1_rready,

    // Master port 2 — SPI
    output wire [31:0] m2_awaddr, output wire m2_awvalid, input wire m2_awready,
    output wire [31:0] m2_wdata,  output wire [3:0] m2_wstrb,
    output wire        m2_wvalid, input  wire m2_wready,
    input  wire [1:0]  m2_bresp,  input  wire m2_bvalid,  output wire m2_bready,
    output wire [31:0] m2_araddr, output wire m2_arvalid, input  wire m2_arready,
    input  wire [31:0] m2_rdata,  input  wire [1:0] m2_rresp,
    input  wire        m2_rvalid, output wire m2_rready
);

    localparam SEL_RAM  = 2'd0;
    localparam SEL_GPIO = 2'd1;
    localparam SEL_SPI  = 2'd2;
    localparam SEL_ERR  = 2'd3;

    // Decode address to select slave
    function [1:0] decode;
        input [31:0] addr;
        begin
            case (addr[31:28])
                4'h0:    decode = SEL_RAM;
                4'h1:    decode = SEL_GPIO;
                4'h2:    decode = SEL_SPI;
                default: decode = SEL_ERR;
            endcase
        end
    endfunction

    // Latch the selection when a new transaction starts
    reg [1:0] wr_sel;
    reg [1:0] rd_sel;

    wire [1:0] aw_sel = decode(s_awaddr);
    wire [1:0] ar_sel = decode(s_araddr);

    always @(posedge clk or posedge rst)
    begin
        if (rst)
        begin
            wr_sel <= SEL_RAM;
            rd_sel <= SEL_RAM;
        end
        else
        begin
            if (s_awvalid) wr_sel <= aw_sel;
            if (s_arvalid) rd_sel <= ar_sel;
        end
    end

    //------------------------------------------------------------------
    // Write address channel steering
    //------------------------------------------------------------------
    assign m0_awaddr  = s_awaddr;
    assign m0_awvalid = s_awvalid && (aw_sel == SEL_RAM);
    assign m1_awaddr  = s_awaddr;
    assign m1_awvalid = s_awvalid && (aw_sel == SEL_GPIO);
    assign m2_awaddr  = s_awaddr;
    assign m2_awvalid = s_awvalid && (aw_sel == SEL_SPI);

    assign s_awready  = (aw_sel == SEL_RAM)  ? m0_awready :
                        (aw_sel == SEL_GPIO) ? m1_awready :
                        (aw_sel == SEL_SPI)  ? m2_awready : 1'b1; // SEL_ERR: accept and error

    //------------------------------------------------------------------
    // Write data channel steering (follows wr_sel latch)
    //------------------------------------------------------------------
    assign m0_wdata  = s_wdata;  assign m0_wstrb  = s_wstrb;
    assign m1_wdata  = s_wdata;  assign m1_wstrb  = s_wstrb;
    assign m2_wdata  = s_wdata;  assign m2_wstrb  = s_wstrb;

    assign m0_wvalid = s_wvalid && (wr_sel == SEL_RAM);
    assign m1_wvalid = s_wvalid && (wr_sel == SEL_GPIO);
    assign m2_wvalid = s_wvalid && (wr_sel == SEL_SPI);

    assign s_wready  = (wr_sel == SEL_RAM)  ? m0_wready :
                       (wr_sel == SEL_GPIO) ? m1_wready :
                       (wr_sel == SEL_SPI)  ? m2_wready : 1'b1;

    //------------------------------------------------------------------
    // Write response channel steering
    //------------------------------------------------------------------
    assign m0_bready = s_bready && (wr_sel == SEL_RAM);
    assign m1_bready = s_bready && (wr_sel == SEL_GPIO);
    assign m2_bready = s_bready && (wr_sel == SEL_SPI);

    assign s_bresp   = (wr_sel == SEL_RAM)  ? m0_bresp :
                       (wr_sel == SEL_GPIO) ? m1_bresp :
                       (wr_sel == SEL_SPI)  ? m2_bresp : 2'b10; // SLVERR for bad address

    assign s_bvalid  = (wr_sel == SEL_RAM)  ? m0_bvalid :
                       (wr_sel == SEL_GPIO) ? m1_bvalid :
                       (wr_sel == SEL_SPI)  ? m2_bvalid : 1'b0;

    //------------------------------------------------------------------
    // Read address channel steering
    //------------------------------------------------------------------
    assign m0_araddr  = s_araddr;
    assign m0_arvalid = s_arvalid && (ar_sel == SEL_RAM);
    assign m1_araddr  = s_araddr;
    assign m1_arvalid = s_arvalid && (ar_sel == SEL_GPIO);
    assign m2_araddr  = s_araddr;
    assign m2_arvalid = s_arvalid && (ar_sel == SEL_SPI);

    assign s_arready  = (ar_sel == SEL_RAM)  ? m0_arready :
                        (ar_sel == SEL_GPIO) ? m1_arready :
                        (ar_sel == SEL_SPI)  ? m2_arready : 1'b1;

    //------------------------------------------------------------------
    // Read data channel steering (follows rd_sel latch)
    //------------------------------------------------------------------
    assign m0_rready = s_rready && (rd_sel == SEL_RAM);
    assign m1_rready = s_rready && (rd_sel == SEL_GPIO);
    assign m2_rready = s_rready && (rd_sel == SEL_SPI);

    assign s_rdata   = (rd_sel == SEL_RAM)  ? m0_rdata :
                       (rd_sel == SEL_GPIO) ? m1_rdata :
                       (rd_sel == SEL_SPI)  ? m2_rdata : 32'hDEAD_BEEF;

    assign s_rresp   = (rd_sel == SEL_RAM)  ? m0_rresp :
                       (rd_sel == SEL_GPIO) ? m1_rresp :
                       (rd_sel == SEL_SPI)  ? m2_rresp : 2'b10;

    assign s_rvalid  = (rd_sel == SEL_RAM)  ? m0_rvalid :
                       (rd_sel == SEL_GPIO) ? m1_rvalid :
                       (rd_sel == SEL_SPI)  ? m2_rvalid : 1'b0;

endmodule
