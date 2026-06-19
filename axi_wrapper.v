module axi_wrapper (
    input         clk,
    input         rst,

    // GPIO external pins
    input  [31:0] gpio_in,
    output [31:0] gpio_out

    // TODO: add SPI pins here
);

    // AXI global reset is active-low
    wire aresetn = ~rst;

    // ---------------- Instruction memory ----------------
    wire [31:0] imem_addr;
    wire [31:0] imem_rdata;

    // Your existing ROM instance (as in processor_top)
    inst_mem inst_mem_i (
        .addr (imem_addr),
        .data (imem_rdata)
    );

    // ---------------- Core data bus (to be wired from processor.v) -----------
    wire        core_req;
    wire        core_we;
    wire [31:0] core_addr;
    wire [31:0] core_wdata;
    wire [31:0] core_rdata;
    wire        core_ready;

    // ---------------- Debug signals from core (optional) ---------------------
    wire [31:0] pc_debug;
    wire [31:0] inst_debug;
    wire        rf_we;
    wire [4:0]  rf_waddr;
    wire [31:0] rf_wdata;
    wire        mem_we_dbg;
    wire        mem_re_dbg;
    wire [31:0] mem_addr_dbg;
    wire [31:0] mem_wdata_dbg;
    wire [31:0] mem_rdata_dbg;
    wire        br_taken_dbg;
    wire        trap_taken;
    wire [31:0] epc_debug;
    wire        timer_irq_dbg;

    // Instantiate core
    processor core (
        .clk           (clk),
        .rst           (rst),
        .imem_addr     (imem_addr),
        .imem_rdata    (imem_rdata),
        .pc_debug      (pc_debug),
        .inst_debug    (inst_debug),
        .rf_we         (rf_we),
        .rf_waddr      (rf_waddr),
        .rf_wdata      (rf_wdata),
        .mem_we        (mem_we_dbg),
        .mem_re        (mem_re_dbg),
        .mem_addr      (mem_addr_dbg),
        .mem_wdata     (mem_wdata_dbg),
        .mem_rdata     (mem_rdata_dbg),
        .br_taken_dbg  (br_taken_dbg),
        .trap_taken    (trap_taken),
        .epc_debug     (epc_debug),
        .timer_irq_dbg (timer_irq_dbg)
    );

    // NOTE:
    // After refactoring processor.v, you should drive core_req/core_we/core_addr/core_wdata
    // from the actual MW-stage memory access and feed core_rdata/core_ready back into it.
    // For now, we just show a simple mapping from the debug bus:
    assign core_req   = mem_we_dbg | mem_re_dbg;
    assign core_we    = mem_we_dbg;
    assign core_addr  = mem_addr_dbg;
    assign core_wdata = mem_wdata_dbg;
    // core_rdata should be wired into the core once you expose it as an input.

    // ---------------- AXI master from core ----------------
    wire [31:0] M_AWADDR, M_WDATA, M_ARADDR, M_RDATA;
    wire [3:0]  M_WSTRB;
    wire        M_AWVALID, M_AWREADY;
    wire        M_WVALID,  M_WREADY;
    wire [1:0]  M_BRESP;
    wire        M_BVALID,  M_BREADY;
    wire        M_ARVALID, M_ARREADY;
    wire [1:0]  M_RRESP;
    wire        M_RVALID,  M_RREADY;

    axi_master axi_master_i (
        .aclk       (clk),
        .aresetn    (aresetn),

        .core_req   (core_req),
        .core_we    (core_we),
        .core_addr  (core_addr),
        .core_wdata (core_wdata),
        .core_rdata (core_rdata),
        .core_ready (core_ready),

        .M_AWADDR   (M_AWADDR),
        .M_AWVALID  (M_AWVALID),
        .M_AWREADY  (M_AWREADY),

        .M_WDATA    (M_WDATA),
        .M_WSTRB    (M_WSTRB),
        .M_WVALID   (M_WVALID),
        .M_WREADY   (M_WREADY),

        .M_BRESP    (M_BRESP),
        .M_BVALID   (M_BVALID),
        .M_BREADY   (M_BREADY),

        .M_ARADDR   (M_ARADDR),
        .M_ARVALID  (M_ARVALID),
        .M_ARREADY  (M_ARREADY),

        .M_RDATA    (M_RDATA),
        .M_RRESP    (M_RRESP),
        .M_RVALID   (M_RVALID),
        .M_RREADY   (M_RREADY)
    );

    // ---------------- AXI interconnect ----------------
    // Slave 0 (SRAM) AXI signals – TODO: connect to AXI RAM
    wire [31:0] S0_AWADDR, S0_WDATA, S0_ARADDR, S0_RDATA;
    wire [3:0]  S0_WSTRB;
    wire        S0_AWVALID, S0_AWREADY;
    wire        S0_WVALID,  S0_WREADY;
    wire [1:0]  S0_BRESP;
    wire        S0_BVALID,  S0_BREADY;
    wire        S0_ARVALID, S0_ARREADY;
    wire [1:0]  S0_RRESP;
    wire        S0_RVALID,  S0_RREADY;

    // Slave 1 (GPIO) AXI signals
    wire [31:0] S1_AWADDR, S1_WDATA, S1_ARADDR, S1_RDATA;
    wire [3:0]  S1_WSTRB;
    wire        S1_AWVALID, S1_AWREADY;
    wire        S1_WVALID,  S1_WREADY;
    wire [1:0]  S1_BRESP;
    wire        S1_BVALID,  S1_BREADY;
    wire        S1_ARVALID, S1_ARREADY;
    wire [1:0]  S1_RRESP;
    wire        S1_RVALID,  S1_RREADY;

    axi_interconnect axi_ic_i (
        .aclk       (clk),
        .aresetn    (aresetn),

        .M_AWADDR   (M_AWADDR),
        .M_AWVALID  (M_AWVALID),
        .M_AWREADY  (M_AWREADY),

        .M_WDATA    (M_WDATA),
        .M_WSTRB    (M_WSTRB),
        .M_WVALID   (M_WVALID),
        .M_WREADY   (M_WREADY),

        .M_BRESP    (M_BRESP),
        .M_BVALID   (M_BVALID),
        .M_BREADY   (M_BREADY),

        .M_ARADDR   (M_ARADDR),
        .M_ARVALID  (M_ARVALID),
        .M_ARREADY  (M_ARREADY),

        .M_RDATA    (M_RDATA),
        .M_RRESP    (M_RRESP),
        .M_RVALID   (M_RVALID),
        .M_RREADY   (M_RREADY),

        .S0_AWADDR  (S0_AWADDR),
        .S0_AWVALID (S0_AWVALID),
        .S0_AWREADY (S0_AWREADY),

        .S0_WDATA   (S0_WDATA),
        .S0_WSTRB   (S0_WSTRB),
        .S0_WVALID  (S0_WVALID),
        .S0_WREADY  (S0_WREADY),

        .S0_BRESP   (S0_BRESP),
        .S0_BVALID  (S0_BVALID),
        .S0_BREADY  (S0_BREADY),

        .S0_ARADDR  (S0_ARADDR),
        .S0_ARVALID (S0_ARVALID),
        .S0_ARREADY (S0_ARREADY),

        .S0_RDATA   (S0_RDATA),
        .S0_RRESP   (S0_RRESP),
        .S0_RVALID  (S0_RVALID),
        .S0_RREADY  (S0_RREADY),

        .S1_AWADDR  (S1_AWADDR),
        .S1_AWVALID (S1_AWVALID),
        .S1_AWREADY (S1_AWREADY),

        .S1_WDATA   (S1_WDATA),
        .S1_WSTRB   (S1_WSTRB),
        .S1_WVALID  (S1_WVALID),
        .S1_WREADY  (S1_WREADY),

        .S1_BRESP   (S1_BRESP),
        .S1_BVALID  (S1_BVALID),
        .S1_BREADY  (S1_BREADY),

        .S1_ARADDR  (S1_ARADDR),
        .S1_ARVALID (S1_ARVALID),
        .S1_ARREADY (S1_ARREADY),

        .S1_RDATA   (S1_RDATA),
        .S1_RRESP   (S1_RRESP),
        .S1_RVALID  (S1_RVALID),
        .S1_RREADY  (S1_RREADY)
    );

    // ---------------- AXI-GPIO on slave 1 ----------------
    axi_gpio axi_gpio_i (
        .aclk       (clk),
        .aresetn    (aresetn),

        .S_AWADDR   (S1_AWADDR),
        .S_AWVALID  (S1_AWVALID),
        .S_AWREADY  (S1_AWREADY),

        .S_WDATA    (S1_WDATA),
        .S_WSTRB    (S1_WSTRB),
        .S_WVALID   (S1_WVALID),
        .S_WREADY   (S1_WREADY),

        .S_BRESP    (S1_BRESP),
        .S_BVALID   (S1_BVALID),
        .S_BREADY   (S1_BREADY),

        .S_ARADDR   (S1_ARADDR),
        .S_ARVALID  (S1_ARVALID),
        .S_ARREADY  (S1_ARREADY),

        .S_RDATA    (S1_RDATA),
        .S_RRESP    (S1_RRESP),
        .S_RVALID   (S1_RVALID),
        .S_RREADY   (S1_RREADY),

        .gpio_in    (gpio_in),
        .gpio_out   (gpio_out)
    );

    // TODO: connect S0_* to an AXI RAM or bridge to your existing data_mem

endmodule
