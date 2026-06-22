`timescale 1ns/1ps
//=============================================================================
// rv32i_axi_soc.v  –  Top-level SoC wrapper with I/D Caches
//=============================================================================
module rv32i_axi_soc
(
    input  wire        clk,
    input  wire        rst,
    input  wire        timer_interrupt,

    // GPIO
    input  wire [31:0] gpio_in,
    output wire [31:0] gpio_out,

    // SPI
    output wire        spi_sclk,
    output wire        spi_mosi,
    input  wire        spi_miso,
    output wire        spi_cs
);
    //------------------------------------------------------------------
    // AXI4-Lite Master Bus
    //------------------------------------------------------------------

    wire [31:0] M_AXI_AWADDR;
    wire        M_AXI_AWVALID;
    wire        M_AXI_AWREADY;
    wire [31:0] M_AXI_WDATA;
    wire [3:0]  M_AXI_WSTRB;
    wire        M_AXI_WVALID;
    wire        M_AXI_WREADY;

    wire [1:0]  M_AXI_BRESP;
    wire        M_AXI_BVALID;
    wire        M_AXI_BREADY;
    wire [31:0] M_AXI_ARADDR;
    wire        M_AXI_ARVALID;
    wire        M_AXI_ARREADY;

    wire [31:0] M_AXI_RDATA;
    wire [1:0]  M_AXI_RRESP;
    wire        M_AXI_RVALID;
    wire        M_AXI_RREADY;

    //------------------------------------------------------------------
    // AXI4-Lite Slave buses  (m0=RAM, m1=GPIO, m2=SPI)
    //------------------------------------------------------------------
    
    // Core CPU memory buses (Now connected to Caches)
    wire        imem_valid, imem_ready, dmem_valid, dmem_write, dmem_ready;
    wire [31:0] imem_addr, imem_rdata, dmem_addr, dmem_wdata, dmem_rdata;
    wire [3:0]  dmem_wstrb;

    // Cache to AXI Master wrapper buses
    wire        w_imem_req, w_imem_ready;
    wire [31:0] w_imem_addr, w_imem_rdata;

    wire        w_dmem_req, w_dmem_wr, w_dmem_ready;
    wire [31:0] w_dmem_addr, w_dmem_wdata, w_dmem_rdata;
    wire [3:0]  w_dmem_wstrb;
    
    // RAM slave
    wire [31:0] ram_awaddr;  wire ram_awvalid;  wire ram_awready;
    wire [31:0] ram_wdata;   wire [3:0] ram_wstrb; wire ram_wvalid; wire ram_wready;
    wire [1:0]  ram_bresp;   wire ram_bvalid;      wire ram_bready;
    wire [31:0] ram_araddr;  wire ram_arvalid;  wire ram_arready;
    wire [31:0] ram_rdata;   wire [1:0] ram_rresp; wire ram_rvalid; wire ram_rready;

    // GPIO slave
    wire [31:0] gpio_awaddr; wire gpio_awvalid; wire gpio_awready;
    wire [31:0] gpio_wdata;  wire [3:0] gpio_wstrb; wire gpio_wvalid; wire gpio_wready;
    wire [1:0]  gpio_bresp;  wire gpio_bvalid;  wire gpio_bready;
    wire [31:0] gpio_araddr; wire gpio_arvalid; wire gpio_arready;
    wire [31:0] gpio_rdata;  wire [1:0] gpio_rresp; wire gpio_rvalid; wire gpio_rready;

    // SPI slave
    wire [31:0] spi_awaddr;  wire spi_awvalid;  wire spi_awready;
    wire [31:0] spi_wdata;   wire [3:0] spi_wstrb; wire spi_wvalid; wire spi_wready;
    wire [1:0]  spi_bresp;   wire spi_bvalid;      wire spi_bready;
    wire [31:0] spi_araddr;  wire spi_arvalid;  wire spi_arready;
    wire [31:0] spi_rdata;   wire [1:0] spi_rresp; wire spi_rvalid; wire spi_rready;

    //------------------------------------------------------------------
    // Processor
    //------------------------------------------------------------------

    processor processor_i (
        .clk             (clk),
        .rst             (rst),
        .timer_interrupt (timer_interrupt),

        .imem_addr       (imem_addr),
        .imem_valid      (imem_valid),
        .imem_ready      (imem_ready),
        .imem_rdata      (imem_rdata),

        .dmem_addr       (dmem_addr),
        .dmem_valid      (dmem_valid),
        .dmem_write      (dmem_write),
        .dmem_wstrb      (dmem_wstrb),
        .dmem_wdata      (dmem_wdata),
        .dmem_ready      (dmem_ready),
        .dmem_rdata      (dmem_rdata)
    );

    //------------------------------------------------------------------
    // Instruction & Data Caches
    //------------------------------------------------------------------

    icache icache_i (
        .clk            (clk),
        .rst            (rst),
        
        // CPU Core Side Interface
        .cpu_imem_addr  (imem_addr),
        .cpu_imem_valid (imem_valid),
        .cpu_imem_ready (imem_ready),
        .cpu_imem_rdata (imem_rdata),
        
        // AXI Wrapper Side Interface
        .w_imem_req     (w_imem_req),
        .w_imem_addr    (w_imem_addr),
        .w_imem_ready   (w_imem_ready),
        .w_imem_rdata   (w_imem_rdata)
    );

    dcache dcache_i (
        .clk            (clk),
        .rst            (rst),
        
        // CPU Core Side Interface
        .cpu_dmem_addr  (dmem_addr),
        .cpu_dmem_valid (dmem_valid),
        .cpu_dmem_write (dmem_write),
        .cpu_dmem_wstrb (dmem_wstrb),
        .cpu_dmem_wdata (dmem_wdata),
        .cpu_dmem_ready (dmem_ready),
        .cpu_dmem_rdata (dmem_rdata),
        
        // AXI Wrapper Side Interface
        .w_dmem_req     (w_dmem_req),
        .w_dmem_wr      (w_dmem_wr),
        .w_dmem_addr    (w_dmem_addr),
        .w_dmem_wstrb   (w_dmem_wstrb),
        .w_dmem_wdata   (w_dmem_wdata),
        .w_dmem_ready   (w_dmem_ready),
        .w_dmem_rdata   (w_dmem_rdata)
    );

    //------------------------------------------------------------------
    // AXI Master Adapter
    //------------------------------------------------------------------

    rv32i_axi_master axi_master_i (
        .clk             (clk),
        .rst             (rst),

        // Connect to Wrapper Side of Caches
        .imem_addr       (w_imem_addr),
        .imem_valid      (w_imem_req),
        .imem_ready      (w_imem_ready),
        .imem_rdata      (w_imem_rdata),

        .dmem_addr       (w_dmem_addr),
        .dmem_valid      (w_dmem_req),
        .dmem_write      (w_dmem_wr),
        .dmem_wstrb      (w_dmem_wstrb),
        .dmem_wdata      (w_dmem_wdata),
        .dmem_ready      (w_dmem_ready),
        .dmem_rdata      (w_dmem_rdata),

        .M_AXI_AWADDR    (M_AXI_AWADDR),
        .M_AXI_AWVALID   (M_AXI_AWVALID),
        .M_AXI_AWREADY   (M_AXI_AWREADY),
        .M_AXI_WDATA     (M_AXI_WDATA),
        .M_AXI_WSTRB     (M_AXI_WSTRB),
        .M_AXI_WVALID    (M_AXI_WVALID),
        .M_AXI_WREADY    (M_AXI_WREADY),
        .M_AXI_BRESP     (M_AXI_BRESP),
        .M_AXI_BVALID    (M_AXI_BVALID),
        .M_AXI_BREADY    (M_AXI_BREADY),
        .M_AXI_ARADDR    (M_AXI_ARADDR),
        .M_AXI_ARVALID   (M_AXI_ARVALID),
        .M_AXI_ARREADY   (M_AXI_ARREADY),
        .M_AXI_RDATA     (M_AXI_RDATA),
        .M_AXI_RRESP     (M_AXI_RRESP),
        .M_AXI_RVALID    (M_AXI_RVALID),
        .M_AXI_RREADY    (M_AXI_RREADY)
    );

    //------------------------------------------------------------------
    // AXI Interconnect  (address decode + 1-master / 3-slave crossbar)
    //------------------------------------------------------------------

    axi_interconnect interconnect_i
    (
        .clk (clk), .rst (rst),

        // Slave port (from master)
        .s_awaddr  (M_AXI_AWADDR),  .s_awvalid (M_AXI_AWVALID), .s_awready (M_AXI_AWREADY),
        .s_wdata   (M_AXI_WDATA),   .s_wstrb   (M_AXI_WSTRB),
        .s_wvalid  (M_AXI_WVALID),  .s_wready  (M_AXI_WREADY),
        .s_bresp   (M_AXI_BRESP),   .s_bvalid  (M_AXI_BVALID),  .s_bready  (M_AXI_BREADY),
        .s_araddr  (M_AXI_ARADDR),  .s_arvalid (M_AXI_ARVALID), .s_arready (M_AXI_ARREADY),
        .s_rdata   (M_AXI_RDATA),   .s_rresp   (M_AXI_RRESP),
        .s_rvalid  (M_AXI_RVALID),  .s_rready  (M_AXI_RREADY),

        // Master port 0 — RAM
        .m0_awaddr  (ram_awaddr),  .m0_awvalid (ram_awvalid),  .m0_awready (ram_awready),
        .m0_wdata   (ram_wdata),   .m0_wstrb   (ram_wstrb),
        .m0_wvalid  (ram_wvalid),  .m0_wready  (ram_wready),
        .m0_bresp   (ram_bresp),   .m0_bvalid  (ram_bvalid),   .m0_bready  (ram_bready),
        .m0_araddr  (ram_araddr),  .m0_arvalid (ram_arvalid),  .m0_arready (ram_arready),
        .m0_rdata   (ram_rdata),   .m0_rresp   (ram_rresp),
        .m0_rvalid  (ram_rvalid),  .m0_rready  (ram_rready),

        // Master port 1 — GPIO
        .m1_awaddr  (gpio_awaddr),  .m1_awvalid (gpio_awvalid),  .m1_awready (gpio_awready),
        .m1_wdata   (gpio_wdata),   .m1_wstrb   (gpio_wstrb),
        .m1_wvalid  (gpio_wvalid),  .m1_wready  (gpio_wready),
        .m1_bresp   (gpio_bresp),   .m1_bvalid  (gpio_bvalid),   .m1_bready  (gpio_bready),
        .m1_araddr  (gpio_araddr),  .m1_arvalid (gpio_arvalid),  .m1_arready (gpio_arready),
        .m1_rdata   (gpio_rdata),   .m1_rresp   (gpio_rresp),
        .m1_rvalid  (gpio_rvalid),  .m1_rready  (gpio_rready),

        // Master port 2 — SPI
        .m2_awaddr  (spi_awaddr),  .m2_awvalid (spi_awvalid),  .m2_awready (spi_awready),
        .m2_wdata   (spi_wdata),   .m2_wstrb   (spi_wstrb),
        .m2_wvalid  (spi_wvalid),  .m2_wready  (spi_wready),
        .m2_bresp   (spi_bresp),   .m2_bvalid  (spi_bvalid),   .m2_bready  (spi_bready),
        .m2_araddr  (spi_araddr),  .m2_arvalid (spi_arvalid),  .m2_arready (spi_arready),
        .m2_rdata   (spi_rdata),   .m2_rresp   (spi_rresp),
        .m2_rvalid  (spi_rvalid),  .m2_rready  (spi_rready)
    );

    //------------------------------------------------------------------
    // RAM slave  (64 KB: address 0x0000_0000 – 0x0000_FFFF)
    //------------------------------------------------------------------

    axi4lite_sram_slave ram_i
    (
        .clk             (clk),
        .rst             (rst),

        .S_AXI_AWADDR    (ram_awaddr),.S_AXI_AWVALID   (ram_awvalid),.S_AXI_AWREADY   (ram_awready),
        .S_AXI_WDATA     (ram_wdata), .S_AXI_WSTRB     (ram_wstrb),  .S_AXI_WVALID    (ram_wvalid),.S_AXI_WREADY    (ram_wready),
        .S_AXI_BRESP     (ram_bresp), .S_AXI_BVALID    (ram_bvalid), .S_AXI_BREADY    (ram_bready),
        .S_AXI_ARADDR    (ram_araddr),.S_AXI_ARVALID   (ram_arvalid),.S_AXI_ARREADY   (ram_arready),
        .S_AXI_RDATA     (ram_rdata), .S_AXI_RRESP     (ram_rresp),  .S_AXI_RVALID    (ram_rvalid),.S_AXI_RREADY    (ram_rready)
    );

    //------------------------------------------------------------------
    // GPIO slave  (address 0x1000_0000 – 0x1000_00FF)
    //------------------------------------------------------------------

    axi_gpio gpio_i
    (
        .clk      (clk),         .rst      (rst),
        .awaddr   (gpio_awaddr), .awvalid  (gpio_awvalid), .awready (gpio_awready),
        .wdata    (gpio_wdata),  .wstrb    (gpio_wstrb),   .wvalid  (gpio_wvalid),  .wready  (gpio_wready),
        .bresp    (gpio_bresp),  .bvalid   (gpio_bvalid),  .bready  (gpio_bready),
        .araddr   (gpio_araddr), .arvalid  (gpio_arvalid), .arready (gpio_arready),
        .rdata    (gpio_rdata),  .rresp    (gpio_rresp),   .rvalid  (gpio_rvalid),  .rready  (gpio_rready),
        .gpio_in  (gpio_in),
        .gpio_out (gpio_out)
    );

    //------------------------------------------------------------------
    // SPI slave  (address 0x2000_0000 – 0x2000_00FF)
    //------------------------------------------------------------------

    axi_spi spi_i
    (
        .clk      (clk),         .rst      (rst),
        .awaddr   (spi_awaddr),  .awvalid  (spi_awvalid), .awready (spi_awready),
        .wdata    (spi_wdata),   .wstrb    (spi_wstrb),   .wvalid  (spi_wvalid),  .wready  (spi_wready),
        .bresp    (spi_bresp),   .bvalid   (spi_bvalid),  .bready  (spi_bready),
        .araddr   (spi_araddr),  .arvalid  (spi_arvalid), .arready (spi_arready),
        .rdata    (spi_rdata),   .rresp    (spi_rresp),   .rvalid  (spi_rvalid),  .rready  (spi_rready),
        .spi_sclk (spi_sclk),
        .spi_mosi (spi_mosi),
        .spi_miso (spi_miso),
        .spi_cs   (spi_cs)
    );

endmodule