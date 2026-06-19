module axi_interconnect #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input                        aclk,
    input                        aresetn,

    // Master side (from axi_master)
    input      [ADDR_WIDTH-1:0]  M_AWADDR,
    input                        M_AWVALID,
    output                       M_AWREADY,

    input      [DATA_WIDTH-1:0]  M_WDATA,
    input      [DATA_WIDTH/8-1:0] M_WSTRB,
    input                        M_WVALID,
    output                       M_WREADY,

    output     [1:0]             M_BRESP,
    output                       M_BVALID,
    input                        M_BREADY,

    input      [ADDR_WIDTH-1:0]  M_ARADDR,
    input                        M_ARVALID,
    output                       M_ARREADY,

    output     [DATA_WIDTH-1:0]  M_RDATA,
    output     [1:0]             M_RRESP,
    output                       M_RVALID,
    input                        M_RREADY,

    // Slave 0 (SRAM / RAM)
    output     [ADDR_WIDTH-1:0]  S0_AWADDR,
    output                       S0_AWVALID,
    input                        S0_AWREADY,

    output     [DATA_WIDTH-1:0]  S0_WDATA,
    output     [DATA_WIDTH/8-1:0] S0_WSTRB,
    output                       S0_WVALID,
    input                        S0_WREADY,

    input      [1:0]             S0_BRESP,
    input                        S0_BVALID,
    output                       S0_BREADY,

    output     [ADDR_WIDTH-1:0]  S0_ARADDR,
    output                       S0_ARVALID,
    input                        S0_ARREADY,

    input      [DATA_WIDTH-1:0]  S0_RDATA,
    input      [1:0]             S0_RRESP,
    input                        S0_RVALID,
    output                       S0_RREADY,

    // Slave 1 (GPIO / SPI region)
    output     [ADDR_WIDTH-1:0]  S1_AWADDR,
    output                       S1_AWVALID,
    input                        S1_AWREADY,

    output     [DATA_WIDTH-1:0]  S1_WDATA,
    output     [DATA_WIDTH/8-1:0] S1_WSTRB,
    output                       S1_WVALID,
    input                        S1_WREADY,

    input      [1:0]             S1_BRESP,
    input                        S1_BVALID,
    output                       S1_BREADY,

    output     [ADDR_WIDTH-1:0]  S1_ARADDR,
    output                       S1_ARVALID,
    input                        S1_ARREADY,

    input      [DATA_WIDTH-1:0]  S1_RDATA,
    input      [1:0]             S1_RRESP,
    input                        S1_RVALID,
    output                       S1_RREADY
);

    // Simple address decode
    wire sel_s1_aw = (M_AWADDR[31:28] == 4'h4);
    wire sel_s1_ar = (M_ARADDR[31:28] == 4'h4);
    wire sel_s0_aw = ~sel_s1_aw;
    wire sel_s0_ar = ~sel_s1_ar;

    // Track which slave a transaction went to for response merging
    reg write_sel_s1;
    reg read_sel_s1;

    // Latch selection on address handshake
    always @(posedge aclk) begin
        if (!aresetn) begin
            write_sel_s1 <= 1'b0;
            read_sel_s1  <= 1'b0;
        end else begin
            if (M_AWVALID && M_AWREADY)
                write_sel_s1 <= sel_s1_aw;
            if (M_ARVALID && M_ARREADY)
                read_sel_s1  <= sel_s1_ar;
        end
    end

    // ------------- Write address/data routing -------------
    assign S0_AWADDR  = M_AWADDR;
    assign S0_AWVALID = M_AWVALID && sel_s0_aw;
    assign S1_AWADDR  = M_AWADDR;
    assign S1_AWVALID = M_AWVALID && sel_s1_aw;

    assign M_AWREADY = sel_s0_aw ? S0_AWREADY : S1_AWREADY;

    assign S0_WDATA  = M_WDATA;
    assign S0_WSTRB  = M_WSTRB;
    assign S0_WVALID = M_WVALID && ~write_sel_s1;
    assign S1_WDATA  = M_WDATA;
    assign S1_WSTRB  = M_WSTRB;
    assign S1_WVALID = M_WVALID &&  write_sel_s1;

    assign M_WREADY  = write_sel_s1 ? S1_WREADY : S0_WREADY;

    // ------------- Write response merge -------------
    assign S0_BREADY = M_BREADY && ~write_sel_s1;
    assign S1_BREADY = M_BREADY &&  write_sel_s1;

    assign M_BVALID  = write_sel_s1 ? S1_BVALID : S0_BVALID;
    assign M_BRESP   = write_sel_s1 ? S1_BRESP  : S0_BRESP;

    // ------------- Read address routing -------------
    assign S0_ARADDR  = M_ARADDR;
    assign S0_ARVALID = M_ARVALID && sel_s0_ar;
    assign S1_ARADDR  = M_ARADDR;
    assign S1_ARVALID = M_ARVALID && sel_s1_ar;

    assign M_ARREADY  = sel_s0_ar ? S0_ARREADY : S1_ARREADY;

    // ------------- Read data merge -------------
    assign S0_RREADY  = M_RREADY && ~read_sel_s1;
    assign S1_RREADY  = M_RREADY &&  read_sel_s1;

    assign M_RVALID   = read_sel_s1 ? S1_RVALID : S0_RVALID;
    assign M_RDATA    = read_sel_s1 ? S1_RDATA  : S0_RDATA;
    assign M_RRESP    = read_sel_s1 ? S1_RRESP  : S0_RRESP;

endmodule
