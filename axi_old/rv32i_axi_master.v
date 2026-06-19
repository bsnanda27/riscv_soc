`timescale 1ns/1ps
//=============================================================================
// rv32i_axi_master.v  –  Simple Memory Interface → AXI4-Lite Master
//=============================================================================
module rv32i_axi_master
(
    input  wire        clk,
    input  wire        rst,

    // CPU-side simple memory interface
    input  wire        mem_valid,
    input  wire        mem_write,
    input  wire [31:0] mem_addr,
    input  wire [31:0] mem_wdata,
    input  wire [3:0]  mem_wstrb,

    output reg         mem_ready,
    output reg  [31:0] mem_rdata,

    // AXI4-Lite Master Interface
    // Write Address Channel
    output reg  [31:0] M_AXI_AWADDR,
    output reg         M_AXI_AWVALID,
    input  wire        M_AXI_AWREADY,

    // Write Data Channel
    output reg  [31:0] M_AXI_WDATA,
    output reg  [3:0]  M_AXI_WSTRB,
    output reg         M_AXI_WVALID,
    input  wire        M_AXI_WREADY,

    // Write Response Channel
    input  wire [1:0]  M_AXI_BRESP,
    input  wire        M_AXI_BVALID,
    output reg         M_AXI_BREADY,

    // Read Address Channel
    output reg  [31:0] M_AXI_ARADDR,
    output reg         M_AXI_ARVALID,
    input  wire        M_AXI_ARREADY,

    // Read Data Channel
    input  wire [31:0] M_AXI_RDATA,
    input  wire [1:0]  M_AXI_RRESP,
    input  wire        M_AXI_RVALID,
    output reg         M_AXI_RREADY
);

    localparam IDLE        = 3'd0;
    localparam WRITE_ADDR  = 3'd1;  // Drive AWVALID + WVALID, wait for both READY
    localparam WRITE_RESP  = 3'd2;  // Wait for BVALID
    localparam READ_ADDR   = 3'd3;  // Drive ARVALID, wait for ARREADY
    localparam READ_DATA   = 3'd4;  // Drive RREADY, wait for RVALID

    reg [2:0] state;

    // Track which write channel handshakes have completed within WRITE_ADDR
    reg aw_done;
    reg w_done;

    always @(posedge clk or posedge rst)
    begin
        if (rst)
        begin
            state          <= IDLE;

            mem_ready      <= 1'b0;
            mem_rdata      <= 32'b0;

            M_AXI_AWADDR   <= 32'b0;
            M_AXI_AWVALID  <= 1'b0;

            M_AXI_WDATA    <= 32'b0;
            M_AXI_WSTRB    <= 4'b0;
            M_AXI_WVALID   <= 1'b0;

            M_AXI_BREADY   <= 1'b0;

            M_AXI_ARADDR   <= 32'b0;
            M_AXI_ARVALID  <= 1'b0;
            M_AXI_RREADY   <= 1'b0;

            aw_done        <= 1'b0;
            w_done         <= 1'b0;
        end
        else
        begin
            // Default: deassert single-cycle signals
            mem_ready <= 1'b0;

            case (state)


            //----------------------------------------------------------
            // IDLE — wait for processor to raise mem_valid
            //----------------------------------------------------------
            IDLE:
            begin
                // Fix: Only accept a new transaction if we are not actively 
                // pulsing mem_ready for the previous transaction.
                if (mem_valid && !mem_ready)
                begin
                    if (mem_write)
                    begin
                        // Latch write address + data and issue both channels
                        M_AXI_AWADDR  <= mem_addr;
                        M_AXI_AWVALID <= 1'b1;

                        M_AXI_WDATA   <= mem_wdata;
                        M_AXI_WSTRB   <= mem_wstrb;
                        M_AXI_WVALID  <= 1'b1;

                        aw_done <= 1'b0;
                        w_done  <= 1'b0;

                        state <= WRITE_ADDR;
                    end
                    else
                    begin
                        // Issue read address
                        M_AXI_ARADDR  <= mem_addr;
                        M_AXI_ARVALID <= 1'b1;

                        state <= READ_ADDR;
                    end
                end
            end

            //----------------------------------------------------------
            // WRITE_ADDR — wait for AWREADY AND WREADY (may arrive
            // on the same cycle or different cycles)
            //----------------------------------------------------------
            WRITE_ADDR:
            begin
                // Write address handshake
                if (M_AXI_AWVALID && M_AXI_AWREADY)
                begin
                    M_AXI_AWVALID <= 1'b0;
                    aw_done       <= 1'b1;
                end

                // Write data handshake
                if (M_AXI_WVALID && M_AXI_WREADY)
                begin
                    M_AXI_WVALID <= 1'b0;
                    w_done       <= 1'b1;
                end

                // Both channels done — move on
                if ((aw_done || (M_AXI_AWVALID && M_AXI_AWREADY)) &&
                    (w_done  || (M_AXI_WVALID  && M_AXI_WREADY)))
                begin
                    M_AXI_AWVALID <= 1'b0;
                    M_AXI_WVALID  <= 1'b0;
                    M_AXI_BREADY  <= 1'b1;
                    aw_done       <= 1'b0;
                    w_done        <= 1'b0;
                    state         <= WRITE_RESP;
                end
            end

            //----------------------------------------------------------
            // WRITE_RESP — wait for BVALID
            //----------------------------------------------------------
            WRITE_RESP:
            begin
                //if (M_AXI_BVALID)
                if (M_AXI_BVALID && M_AXI_BREADY)
                begin
                    M_AXI_BREADY <= 1'b0;
                    mem_ready    <= 1'b1;   // single-cycle pulse to processor
                    state        <= IDLE;
                end
            end

            //----------------------------------------------------------
            // READ_ADDR — wait for ARREADY
            //----------------------------------------------------------
            /*READ_ADDR:
            begin
                if (M_AXI_ARREADY)
                begin
                    M_AXI_ARVALID <= 1'b0;
                    if (M_AXI_RVALID)
                    begin
                        // Data already available: capture and complete in one cycle
                        mem_rdata    <= M_AXI_RDATA;
                        M_AXI_RREADY <= 1'b1;  // pulse RREADY to complete handshake
                        mem_ready    <= 1'b1;
                        state        <= IDLE;
                    end
                    else
                    begin
                        M_AXI_RREADY  <= 1'b1;
                        state         <= READ_DATA;
                    end
                end
            end*/
            READ_ADDR:
	    begin
		    if (M_AXI_ARREADY)
		    begin
			M_AXI_ARVALID <= 1'b0;
			M_AXI_RREADY  <= 1'b1;
			state         <= READ_DATA;
		    end
            end

            //----------------------------------------------------------
            // READ_DATA — wait for RVALID
            //----------------------------------------------------------
            /*READ_DATA:
            begin
                if (M_AXI_RVALID)
                begin
                    mem_rdata    <= M_AXI_RDATA;
                    M_AXI_RREADY <= 1'b0;
                    mem_ready    <= 1'b1;   // single-cycle pulse to processor
                    state        <= IDLE;
                end
            end*/
            //----------------------------------------------------------
            // READ_DATA — wait for RVALID
            //----------------------------------------------------------
            /*READ_DATA:
            begin
                if (M_AXI_RVALID && M_AXI_RREADY)
                begin
                    mem_rdata    <= M_AXI_RDATA;
                    M_AXI_RREADY <= 1'b0;

                    if (mem_write)
                        mem_ready <= 1'b0;
                    else
                        mem_ready <= 1'b1;
                        
                    state <= IDLE;
                end
            end */
            //----------------------------------------------------------
            // READ_DATA — wait for RVALID
            //----------------------------------------------------------
            READ_DATA:
            begin
                if (M_AXI_RVALID && M_AXI_RREADY)
                begin
                    mem_rdata    <= M_AXI_RDATA;
                    M_AXI_RREADY <= 1'b0;

                    // FIX: Always pulse mem_ready high when an AXI Read completes
                    mem_ready    <= 1'b1;   
                    state        <= IDLE;
                end
            end

            default:
                state <= IDLE;

            endcase
        end
    end

endmodule
