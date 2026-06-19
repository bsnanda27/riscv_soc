`timescale 1ns/1ps
module axi_gpio
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

    input  wire [31:0] gpio_in,
    output wire [31:0] gpio_out
);

    reg [31:0] gpio_out_reg;
    reg [31:0] gpio_dir_reg;

    assign gpio_out = gpio_out_reg;

    always @(posedge clk)
    begin
        if (rst)
        begin
            awready     <= 1'b0;
            wready      <= 1'b0;
            bvalid      <= 1'b0;
            bresp       <= 2'b00;

            arready     <= 1'b0;
            rvalid      <= 1'b0;
            rresp       <= 2'b00;
            rdata       <= 32'b0;

            gpio_out_reg <= 32'b0;
            gpio_dir_reg <= 32'b0;
        end
        else
        begin
            awready <= 1'b0;
            wready  <= 1'b0;
            arready <= 1'b0;

            if (awvalid && wvalid && !bvalid)
            begin
                awready <= 1'b1;
                wready  <= 1'b1;

                case (awaddr[5:2])
                    4'h0:
                    begin
                        if (wstrb[0]) gpio_out_reg[7:0]   <= wdata[7:0];
                        if (wstrb[1]) gpio_out_reg[15:8]  <= wdata[15:8];
                        if (wstrb[2]) gpio_out_reg[23:16] <= wdata[23:16];
                        if (wstrb[3]) gpio_out_reg[31:24] <= wdata[31:24];
                    end

                    4'h1:
                    begin
                        if (wstrb[0]) gpio_dir_reg[7:0]   <= wdata[7:0];
                        if (wstrb[1]) gpio_dir_reg[15:8]  <= wdata[15:8];
                        if (wstrb[2]) gpio_dir_reg[23:16] <= wdata[23:16];
                        if (wstrb[3]) gpio_dir_reg[31:24] <= wdata[31:24];
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
                    4'h0: rdata <= gpio_out_reg;
                    4'h1: rdata <= gpio_dir_reg;
                    4'h2: rdata <= gpio_in;
                    default: rdata <= 32'b0;
                endcase
            end

            if (rvalid && rready)
            begin
                rvalid <= 1'b0;
            end
        end
    end

endmodule
