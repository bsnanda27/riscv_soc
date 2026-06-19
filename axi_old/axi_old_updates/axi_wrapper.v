// =============================================================================
//  axi_wrapper.v  —  RV32I SoC Top with AXI4-Lite Fabric
//
//  Hierarchy:
//    axi_wrapper
//    ├── inst_mem          (external instruction ROM)
//    ├── processor         (3-stage RV32I core — datamem REMOVED)
//    ├── axi_master        (core data bus → AXI4-Lite master)
//    ├── axi_interconnect  (1×3 address decoder)
//    │   ├── S0 → axi_dmem   (on-chip data SRAM, 0x0000_0000–0x0FFF_FFFF)
//    │   ├── S1 → axi_gpio   (GPIO,              0x4000_0000–0x4000_0FFF)
//    │   └── S2 → axi_spi    (SPI,               0x4000_1000–0x4000_1FFF)
//
//  Address Map
//  ┌──────────────────────────────┬──────────────────┬────────┐
//  │ Region                       │ Base             │ Size   │
//  ├──────────────────────────────┼──────────────────┼────────┤
//  │ Data SRAM  (S0)              │ 0x0000_0000      │ 256 MB │
//  │ GPIO       (S1)              │ 0x4000_0000      │ 4 KB   │
//  │ SPI        (S2)              │ 0x4000_1000      │ 4 KB   │
//  └──────────────────────────────┴──────────────────┴────────┘
//
//  GPIO register map  (S1 base + offset)
//    0x00  GPIO_OUT  RW  32-bit output register
//    0x04  GPIO_IN   RO  32-bit sampled input
//    0x08  GPIO_DIR  RW  direction mask (1=output)
//    0x0C  GPIO_IEN  RW  input interrupt enable (future use)
//
//  SPI register map   (S2 base + offset)
//    0x00  SPI_CTRL  RW  [0]=en [1]=CPOL [2]=CPHA [7:4]=clkdiv [8]=start [9]=cs_pol
//    0x04  SPI_TX    RW  transmit byte
//    0x08  SPI_RX    RO  received byte
//    0x0C  SPI_STAT  RO  [0]=busy [1]=done [2]=rxfull
//
// =============================================================================

`timescale 1ns/1ps
`default_nettype none

module axi_wrapper #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH  = 32,
    parameter DMEM_DEPTH  = 8192,
    parameter GPIO_WIDTH  = 32
)(
    input  wire                  clk,
    input  wire                  rst,
    input  wire [GPIO_WIDTH-1:0] gpio_in,
    output wire [GPIO_WIDTH-1:0] gpio_out,
    output wire [GPIO_WIDTH-1:0] gpio_dir,
    output wire                  spi_sck,
    output wire                  spi_mosi,
    input  wire                  spi_miso,
    output wire                  spi_cs_n,
    output wire [31:0]           pc_debug,
    output wire [31:0]           inst_debug,
    output wire                  rf_we,
    output wire [4:0]            rf_waddr,
    output wire [31:0]           rf_wdata,
    output wire                  br_taken_dbg,
    output wire                  trap_taken,
    output wire [31:0]           epc_debug,
    output wire                  timer_irq_dbg
);

    localparam AXI_STRB = DATA_WIDTH / 8;
    wire aresetn = ~rst;

    wire [31:0] imem_addr;
    wire [31:0] imem_rdata;

    inst_mem inst_mem_i (
        .addr(imem_addr),
        .data(imem_rdata)
    );

    wire                  mem_we;
    wire                  mem_re;
    wire [ADDR_WIDTH-1:0] mem_addr;
    wire [DATA_WIDTH-1:0] mem_wdata;
    wire [DATA_WIDTH-1:0] mem_rdata;
    wire                  dmem_stall;
    wire [2:0]            mem_acc_mode;

    processor core (
        .clk(clk),
        .rst(rst),
        .imem_addr(imem_addr),
        .imem_rdata(imem_rdata),
        .mem_we(mem_we),
        .mem_re(mem_re),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_rdata(mem_rdata),
        .dmem_stall(dmem_stall),
        .pc_debug(pc_debug),
        .inst_debug(inst_debug),
        .rf_we(rf_we),
        .rf_waddr(rf_waddr),
        .rf_wdata(rf_wdata),
        .br_taken_dbg(br_taken_dbg),
        .trap_taken(trap_taken),
        .epc_debug(epc_debug),
        .timer_irq_dbg(timer_irq_dbg),
        .mem_acc_mode(mem_acc_mode)
    );

    wire [ADDR_WIDTH-1:0]  M_AWADDR, M_ARADDR;
    wire [2:0]             M_AWPROT, M_ARPROT;
    wire                   M_AWVALID, M_AWREADY;
    wire                   M_WVALID, M_WREADY;
    wire [DATA_WIDTH-1:0]  M_WDATA, M_RDATA;
    wire [AXI_STRB-1:0]    M_WSTRB;
    wire [1:0]             M_BRESP, M_RRESP;
    wire                   M_BVALID, M_BREADY;
    wire                   M_ARVALID, M_ARREADY;
    wire                   M_RVALID, M_RREADY;

    axi_master #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) axi_master_i (
        .aclk(clk),
        .aresetn(aresetn),
        .core_mem_we(mem_we),
        .core_mem_re(mem_re),
        .core_mem_addr(mem_addr),
        .core_mem_wdata(mem_wdata),
        .core_mem_acc(mem_acc_mode),
        .core_mem_rdata(mem_rdata),
        .core_stall(dmem_stall),
        .M_AXI_AWADDR(M_AWADDR),
        .M_AXI_AWPROT(M_AWPROT),
        .M_AXI_AWVALID(M_AWVALID),
        .M_AXI_AWREADY(M_AWREADY),
        .M_AXI_WDATA(M_WDATA),
        .M_AXI_WSTRB(M_WSTRB),
        .M_AXI_WVALID(M_WVALID),
        .M_AXI_WREADY(M_WREADY),
        .M_AXI_BRESP(M_BRESP),
        .M_AXI_BVALID(M_BVALID),
        .M_AXI_BREADY(M_BREADY),
        .M_AXI_ARADDR(M_ARADDR),
        .M_AXI_ARPROT(M_ARPROT),
        .M_AXI_ARVALID(M_ARVALID),
        .M_AXI_ARREADY(M_ARREADY),
        .M_AXI_RDATA(M_RDATA),
        .M_AXI_RRESP(M_RRESP),
        .M_AXI_RVALID(M_RVALID),
        .M_AXI_RREADY(M_RREADY)
    );

    wire [ADDR_WIDTH-1:0]  S0_AWADDR, S0_ARADDR;
    wire [2:0]             S0_AWPROT, S0_ARPROT;
    wire                   S0_AWVALID, S0_AWREADY, S0_WVALID, S0_WREADY, S0_BVALID, S0_BREADY, S0_ARVALID, S0_ARREADY, S0_RVALID, S0_RREADY;
    wire [DATA_WIDTH-1:0]  S0_WDATA, S0_RDATA;
    wire [AXI_STRB-1:0]    S0_WSTRB;
    wire [1:0]             S0_BRESP, S0_RRESP;

    wire [ADDR_WIDTH-1:0]  S1_AWADDR, S1_ARADDR;
    wire [2:0]             S1_AWPROT, S1_ARPROT;
    wire                   S1_AWVALID, S1_AWREADY, S1_WVALID, S1_WREADY, S1_BVALID, S1_BREADY, S1_ARVALID, S1_ARREADY, S1_RVALID, S1_RREADY;
    wire [DATA_WIDTH-1:0]  S1_WDATA, S1_RDATA;
    wire [AXI_STRB-1:0]    S1_WSTRB;
    wire [1:0]             S1_BRESP, S1_RRESP;

    wire [ADDR_WIDTH-1:0]  S2_AWADDR, S2_ARADDR;
    wire [2:0]             S2_AWPROT, S2_ARPROT;
    wire                   S2_AWVALID, S2_AWREADY, S2_WVALID, S2_WREADY, S2_BVALID, S2_BREADY, S2_ARVALID, S2_ARREADY, S2_RVALID, S2_RREADY;
    wire [DATA_WIDTH-1:0]  S2_WDATA, S2_RDATA;
    wire [AXI_STRB-1:0]    S2_WSTRB;
    wire [1:0]             S2_BRESP, S2_RRESP;

    axi_interconnect #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) axi_ic_i (
        .aclk(clk),
        .aresetn(aresetn),
        .M_AWADDR(M_AWADDR),
        .M_AWPROT(M_AWPROT),
        .M_AWVALID(M_AWVALID),
        .M_AWREADY(M_AWREADY),
        .M_WDATA(M_WDATA),
        .M_WSTRB(M_WSTRB),
        .M_WVALID(M_WVALID),
        .M_WREADY(M_WREADY),
        .M_BRESP(M_BRESP),
        .M_BVALID(M_BVALID),
        .M_BREADY(M_BREADY),
        .M_ARADDR(M_ARADDR),
        .M_ARPROT(M_ARPROT),
        .M_ARVALID(M_ARVALID),
        .M_ARREADY(M_ARREADY),
        .M_RDATA(M_RDATA),
        .M_RRESP(M_RRESP),
        .M_RVALID(M_RVALID),
        .M_RREADY(M_RREADY),
        .S0_AWADDR(S0_AWADDR),
        .S0_AWPROT(S0_AWPROT),
        .S0_AWVALID(S0_AWVALID),
        .S0_AWREADY(S0_AWREADY),
        .S0_WDATA(S0_WDATA),
        .S0_WSTRB(S0_WSTRB),
        .S0_WVALID(S0_WVALID),
        .S0_WREADY(S0_WREADY),
        .S0_BRESP(S0_BRESP),
        .S0_BVALID(S0_BVALID),
        .S0_BREADY(S0_BREADY),
        .S0_ARADDR(S0_ARADDR),
        .S0_ARPROT(S0_ARPROT),
        .S0_ARVALID(S0_ARVALID),
        .S0_ARREADY(S0_ARREADY),
        .S0_RDATA(S0_RDATA),
        .S0_RRESP(S0_RRESP),
        .S0_RVALID(S0_RVALID),
        .S0_RREADY(S0_RREADY),
        .S1_AWADDR(S1_AWADDR),
        .S1_AWPROT(S1_AWPROT),
        .S1_AWVALID(S1_AWVALID),
        .S1_AWREADY(S1_AWREADY),
        .S1_WDATA(S1_WDATA),
        .S1_WSTRB(S1_WSTRB),
        .S1_WVALID(S1_WVALID),
        .S1_WREADY(S1_WREADY),
        .S1_BRESP(S1_BRESP),
        .S1_BVALID(S1_BVALID),
        .S1_BREADY(S1_BREADY),
        .S1_ARADDR(S1_ARADDR),
        .S1_ARPROT(S1_ARPROT),
        .S1_ARVALID(S1_ARVALID),
        .S1_ARREADY(S1_ARREADY),
        .S1_RDATA(S1_RDATA),
        .S1_RRESP(S1_RRESP),
        .S1_RVALID(S1_RVALID),
        .S1_RREADY(S1_RREADY),
        .S2_AWADDR(S2_AWADDR),
        .S2_AWPROT(S2_AWPROT),
        .S2_AWVALID(S2_AWVALID),
        .S2_AWREADY(S2_AWREADY),
        .S2_WDATA(S2_WDATA),
        .S2_WSTRB(S2_WSTRB),
        .S2_WVALID(S2_WVALID),
        .S2_WREADY(S2_WREADY),
        .S2_BRESP(S2_BRESP),
        .S2_BVALID(S2_BVALID),
        .S2_BREADY(S2_BREADY),
        .S2_ARADDR(S2_ARADDR),
        .S2_ARPROT(S2_ARPROT),
        .S2_ARVALID(S2_ARVALID),
        .S2_ARREADY(S2_ARREADY),
        .S2_RDATA(S2_RDATA),
        .S2_RRESP(S2_RRESP),
        .S2_RVALID(S2_RVALID),
        .S2_RREADY(S2_RREADY)
    );

    axi_dmem #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DMEM_DEPTH)
    ) axi_dmem_i (
        .aclk(clk),
        .aresetn(aresetn),
        .S_AWADDR(S0_AWADDR),
        .S_AWPROT(S0_AWPROT),
        .S_AWVALID(S0_AWVALID),
        .S_AWREADY(S0_AWREADY),
        .S_WDATA(S0_WDATA),
        .S_WSTRB(S0_WSTRB),
        .S_WVALID(S0_WVALID),
        .S_WREADY(S0_WREADY),
        .S_BRESP(S0_BRESP),
        .S_BVALID(S0_BVALID),
        .S_BREADY(S0_BREADY),
        .S_ARADDR(S0_ARADDR),
        .S_ARPROT(S0_ARPROT),
        .S_ARVALID(S0_ARVALID),
        .S_ARREADY(S0_ARREADY),
        .S_RDATA(S0_RDATA),
        .S_RRESP(S0_RRESP),
        .S_RVALID(S0_RVALID),
        .S_RREADY(S0_RREADY)
    );

    axi_gpio #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .GPIO_WIDTH(GPIO_WIDTH)
    ) axi_gpio_i (
        .aclk(clk),
        .aresetn(aresetn),
        .S_AWADDR(S1_AWADDR),
        .S_AWPROT(S1_AWPROT),
        .S_AWVALID(S1_AWVALID),
        .S_AWREADY(S1_AWREADY),
        .S_WDATA(S1_WDATA),
        .S_WSTRB(S1_WSTRB),
        .S_WVALID(S1_WVALID),
        .S_WREADY(S1_WREADY),
        .S_BRESP(S1_BRESP),
        .S_BVALID(S1_BVALID),
        .S_BREADY(S1_BREADY),
        .S_ARADDR(S1_ARADDR),
        .S_ARPROT(S1_ARPROT),
        .S_ARVALID(S1_ARVALID),
        .S_ARREADY(S1_ARREADY),
        .S_RDATA(S1_RDATA),
        .S_RRESP(S1_RRESP),
        .S_RVALID(S1_RVALID),
        .S_RREADY(S1_RREADY),
        .gpio_in(gpio_in),
        .gpio_out(gpio_out),
        .gpio_dir(gpio_dir)
    );

    axi_spi #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) axi_spi_i (
        .aclk(clk),
        .aresetn(aresetn),
        .S_AWADDR(S2_AWADDR),
        .S_AWPROT(S2_AWPROT),
        .S_AWVALID(S2_AWVALID),
        .S_AWREADY(S2_AWREADY),
        .S_WDATA(S2_WDATA),
        .S_WSTRB(S2_WSTRB),
        .S_WVALID(S2_WVALID),
        .S_WREADY(S2_WREADY),
        .S_BRESP(S2_BRESP),
        .S_BVALID(S2_BVALID),
        .S_BREADY(S2_BREADY),
        .S_ARADDR(S2_ARADDR),
        .S_ARPROT(S2_ARPROT),
        .S_ARVALID(S2_ARVALID),
        .S_ARREADY(S2_ARREADY),
        .S_RDATA(S2_RDATA),
        .S_RRESP(S2_RRESP),
        .S_RVALID(S2_RVALID),
        .S_RREADY(S2_RREADY),
        .spi_sck(spi_sck),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso),
        .spi_cs_n(spi_cs_n)
    );

endmodule

`default_nettype wire
