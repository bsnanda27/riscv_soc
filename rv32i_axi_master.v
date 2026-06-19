`timescale 1ns/1ps
module rv32i_axi_master
(
    input  wire        clk,
    input  wire        rst,

    // CPU IMEM Port
    input  wire [31:0] imem_addr,
    input  wire        imem_valid,
    output wire        imem_ready,
    output wire [31:0] imem_rdata,

    // CPU DMEM Port
    input  wire [31:0] dmem_addr,
    input  wire        dmem_valid,
    input  wire        dmem_write,
    input  wire [3:0]  dmem_wstrb,
    input  wire [31:0] dmem_wdata,
    output wire        dmem_ready,
    output wire [31:0] dmem_rdata,

    // AXI4-Lite Master Interface
    output reg  [31:0] M_AXI_AWADDR,
    output reg         M_AXI_AWVALID,
    input  wire        M_AXI_AWREADY,

    output reg  [31:0] M_AXI_WDATA,
    output reg  [3:0]  M_AXI_WSTRB,
    output reg         M_AXI_WVALID,
    input  wire        M_AXI_WREADY,

    input  wire [1:0]  M_AXI_BRESP,
    input  wire        M_AXI_BVALID,
    output reg         M_AXI_BREADY,

    output reg  [31:0] M_AXI_ARADDR,
    output reg         M_AXI_ARVALID,
    input  wire        M_AXI_ARREADY,

    input  wire [31:0] M_AXI_RDATA,
    input  wire [1:0]  M_AXI_RRESP,
    input  wire        M_AXI_RVALID,
    output reg         M_AXI_RREADY
);

    reg imem_done, dmem_done;
    reg [31:0] latched_imem_rdata;
    reg [31:0] latched_dmem_rdata;

    assign imem_ready = imem_done;
    assign imem_rdata = latched_imem_rdata;
    
    assign dmem_ready = dmem_done;
    assign dmem_rdata = latched_dmem_rdata;

    wire core_stall = (imem_valid && !imem_done) || (dmem_valid && !dmem_done);

    reg [2:0] state;
    localparam IDLE = 3'd0, D_WADDR_WDATA = 3'd1, D_WRESP = 3'd2;
    localparam D_RADDR = 3'd3, D_RDATA = 3'd4;
    localparam I_RADDR = 3'd5, I_RDATA = 3'd6;

    reg aw_done, w_done;

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            imem_done <= 1'b0; dmem_done <= 1'b0;
            aw_done <= 1'b0; w_done <= 1'b0;
            M_AXI_AWVALID <= 1'b0; M_AXI_WVALID <= 1'b0; M_AXI_BREADY <= 1'b0;
            M_AXI_ARVALID <= 1'b0; M_AXI_RREADY <= 1'b0;
        end else begin
            // Synchronous clear: If CPU advances, drop the done flags.
            if (!core_stall) begin
                if (imem_valid) imem_done <= 1'b0;
                if (dmem_valid) dmem_done <= 1'b0;
            end

            case (state)
                IDLE: begin
                    // Only start new AXI transactions if the pipeline is actually stalled waiting for them.
                    if (core_stall) begin
                        if (dmem_valid && !dmem_done) begin
                            if (dmem_write) begin
                                M_AXI_AWADDR  <= dmem_addr;
                                M_AXI_AWVALID <= 1'b1;
                                M_AXI_WDATA   <= dmem_wdata;
                                M_AXI_WSTRB   <= dmem_wstrb;
                                M_AXI_WVALID  <= 1'b1;
                                aw_done       <= 1'b0;
                                w_done        <= 1'b0;
                                state         <= D_WADDR_WDATA;
                            end else begin
                                M_AXI_ARADDR  <= dmem_addr;
                                M_AXI_ARVALID <= 1'b1;
                                state         <= D_RADDR;
                            end
                        end else if (imem_valid && !imem_done) begin
                            M_AXI_ARADDR  <= imem_addr;
                            M_AXI_ARVALID <= 1'b1;
                            state         <= I_RADDR;
                        end
                    end
                end

                D_WADDR_WDATA: begin
                    if (M_AXI_AWVALID && M_AXI_AWREADY) begin M_AXI_AWVALID <= 1'b0; aw_done <= 1'b1; end
                    if (M_AXI_WVALID && M_AXI_WREADY)   begin M_AXI_WVALID  <= 1'b0; w_done <= 1'b1;  end
                    
                    if ((aw_done || (M_AXI_AWVALID && M_AXI_AWREADY)) &&
                        (w_done  || (M_AXI_WVALID  && M_AXI_WREADY))) begin
                         M_AXI_AWVALID <= 1'b0;
                         M_AXI_WVALID  <= 1'b0;
                         M_AXI_BREADY  <= 1'b1;
                         state         <= D_WRESP;
                    end
                end

                D_WRESP: begin
                    if (M_AXI_BVALID && M_AXI_BREADY) begin
                        M_AXI_BREADY <= 1'b0;
                        dmem_done    <= 1'b1;
                        state        <= IDLE;
                    end
                end

                D_RADDR: begin
                    if (M_AXI_ARVALID && M_AXI_ARREADY) begin
                        M_AXI_ARVALID <= 1'b0;
                        M_AXI_RREADY  <= 1'b1;
                        state         <= D_RDATA;
                    end
                end

                D_RDATA: begin
                    if (M_AXI_RVALID && M_AXI_RREADY) begin
                        M_AXI_RREADY       <= 1'b0;
                        latched_dmem_rdata <= M_AXI_RDATA;
                        dmem_done          <= 1'b1;
                        state              <= IDLE;
                    end
                end

                I_RADDR: begin
                    if (M_AXI_ARVALID && M_AXI_ARREADY) begin
                        M_AXI_ARVALID <= 1'b0;
                        M_AXI_RREADY  <= 1'b1;
                        state         <= I_RDATA;
                    end
                end

                I_RDATA: begin
                    if (M_AXI_RVALID && M_AXI_RREADY) begin
                        M_AXI_RREADY       <= 1'b0;
                        latched_imem_rdata <= M_AXI_RDATA;
                        imem_done          <= 1'b1;
                        state              <= IDLE;
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
