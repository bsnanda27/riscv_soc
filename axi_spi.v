`timescale 1ns/1ps
module axi_spi
(
    input  wire        clk,
    input  wire        rst,

    // AXI4-Lite Slave Interface
    input  wire [31:0] awaddr,
    input  wire        awvalid,
    output reg         awready,

    input  wire [31:0] wdata,
    input  wire [3:0]  wstrb,
    input  wire        wvalid,
    output reg         wready,

    output reg [1:0]   bresp,
    output reg         bvalid,
    input  wire        bready,

    input  wire [31:0] araddr,
    input  wire        arvalid,
    output reg         arready,

    output reg [31:0]  rdata,
    output reg [1:0]   rresp,
    output reg         rvalid,
    input  wire        rready,

    output wire        spi_sclk,
    output wire        spi_mosi,
    input  wire        spi_miso,
    output wire        spi_cs
);

    reg [31:0] ctrl_reg;
    reg [31:0] status_reg;
    reg [7:0]  tx_reg;
    reg [7:0]  rx_reg;

    reg [7:0]  shift_reg;
    reg [2:0]  bit_cnt;
    reg        busy;
    reg        sclk_reg;
    reg        mosi_reg;
    reg        cs_reg;
    reg        start_d;

    assign spi_sclk = sclk_reg;
    assign spi_mosi = mosi_reg;
    assign spi_cs   = cs_reg;

    always @(posedge clk)
    begin
        if (rst)
        begin
            awready    <= 1'b0;
            wready     <= 1'b0;
            bvalid     <= 1'b0;
            bresp      <= 2'b00;

            arready    <= 1'b0;
            rvalid     <= 1'b0;
            rresp      <= 2'b00;
            rdata      <= 32'b0;

            ctrl_reg   <= 32'b0;
            status_reg <= 32'b0;
            tx_reg     <= 8'b0;
            rx_reg     <= 8'b0;

            shift_reg  <= 8'b0;
            bit_cnt    <= 3'b0;
            busy       <= 1'b0;
            sclk_reg   <= 1'b0;
            mosi_reg   <= 1'b0;
            cs_reg     <= 1'b1;
            start_d    <= 1'b0;
        end
        else
        begin
            awready <= 1'b0;
            wready  <= 1'b0;
            arready <= 1'b0;

            status_reg[0] <= busy;
            status_reg[1] <= 1'b0;

            if (awvalid && wvalid && !bvalid)
            begin
                awready <= 1'b1;
                wready  <= 1'b1;

                case (awaddr[5:2])
                    4'h0:
                    begin
                        if (wstrb[0]) ctrl_reg[7:0]   <= wdata[7:0];
                        if (wstrb[1]) ctrl_reg[15:8]  <= wdata[15:8];
                        if (wstrb[2]) ctrl_reg[23:16] <= wdata[23:16];
                        if (wstrb[3]) ctrl_reg[31:24] <= wdata[31:24];
                    end

                    4'h2:
                    begin
                        if (wstrb[0]) tx_reg <= wdata[7:0];
                    end

                    default:
                    begin
                    end
                endcase

                bvalid <= 1'b1;
                bresp  <= 2'b00;
            end

            if (bvalid && bready)
            begin
                bvalid <= 1'b0;
            end

            if (arvalid && !rvalid)
            begin
                arready <= 1'b1;
                rvalid  <= 1'b1;
                rresp   <= 2'b00;

                case (araddr[5:2])
                    4'h0: rdata <= ctrl_reg;
                    4'h1: rdata <= status_reg;
                    4'h2: rdata <= {24'b0, tx_reg};
                    4'h3: rdata <= {24'b0, rx_reg};
                    default: rdata <= 32'b0;
                endcase
            end

            if (rvalid && rready)
            begin
                rvalid <= 1'b0;
            end

            start_d <= ctrl_reg[0];

            if (!busy && ctrl_reg[0] && !start_d)
            begin
                busy      <= 1'b1;
                cs_reg    <= 1'b0;
                sclk_reg  <= 1'b0;
                bit_cnt   <= 3'd7;
                shift_reg <= tx_reg;
                mosi_reg  <= tx_reg[7];
            end
            else if (busy)
            begin
                sclk_reg <= ~sclk_reg;

                if (sclk_reg == 1'b0)
                begin
                    mosi_reg <= shift_reg[7];
                end
                else
                begin
                    shift_reg <= {shift_reg[6:0], spi_miso};

                    if (bit_cnt == 3'd0)
                    begin
                        busy      <= 1'b0;
                        cs_reg    <= 1'b1;
                        sclk_reg  <= 1'b0;
                        rx_reg    <= {shift_reg[6:0], spi_miso};
                        ctrl_reg[0] <= 1'b0;
                        status_reg[1] <= 1'b1;
                    end
                    else
                    begin
                        bit_cnt <= bit_cnt - 3'd1;
                    end
                end
            end
            else
            begin
                cs_reg   <= 1'b1;
                sclk_reg <= 1'b0;
            end
        end
    end

endmodule
