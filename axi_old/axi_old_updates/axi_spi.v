module axi_spi #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input                         aclk,
    input                         aresetn,

    input      [ADDR_WIDTH-1:0]   S_AWADDR,
    input                         S_AWVALID,
    output reg                    S_AWREADY,

    input      [DATA_WIDTH-1:0]   S_WDATA,
    input      [DATA_WIDTH/8-1:0] S_WSTRB,
    input                         S_WVALID,
    output reg                    S_WREADY,

    output reg [1:0]              S_BRESP,
    output reg                    S_BVALID,
    input                         S_BREADY,

    input      [ADDR_WIDTH-1:0]   S_ARADDR,
    input                         S_ARVALID,
    output reg                    S_ARREADY,

    output reg [DATA_WIDTH-1:0]   S_RDATA,
    output reg [1:0]              S_RRESP,
    output reg                    S_RVALID,
    input                         S_RREADY,

    output reg                    spi_sck,
    output reg                    spi_mosi,
    input                         spi_miso,
    output reg                    spi_cs_n
);

    reg [31:0] ctrl_reg;
    reg [31:0] tx_reg;
    reg [31:0] rx_reg;

    reg [7:0]  bit_cnt;
    reg [7:0]  clk_div_cnt;
    reg        spi_busy;
    reg        spi_done;
    reg [7:0]  shift_tx;
    reg [7:0]  shift_rx;

    wire       ctrl_en    = ctrl_reg[0];
    wire       ctrl_cpol  = ctrl_reg[1];
    wire       ctrl_cpha  = ctrl_reg[2];
    wire [3:0] ctrl_div   = ctrl_reg[7:4];
    wire       ctrl_start = ctrl_reg[8];

    localparam W_IDLE = 2'd0;
    localparam W_DATA = 2'd1;
    localparam W_RESP = 2'd2;

    localparam R_IDLE = 2'd0;
    localparam R_DATA = 2'd1;

    reg [1:0] w_state;
    reg [1:0] r_state;

    reg [ADDR_WIDTH-1:0] awaddr_latched;

    always @(posedge aclk) begin
        if (!aresetn) begin
            w_state       <= W_IDLE;
            S_AWREADY     <= 1'b0;
            S_WREADY      <= 1'b0;
            S_BVALID      <= 1'b0;
            S_BRESP       <= 2'b00;
            ctrl_reg      <= 32'h0;
            tx_reg        <= 32'h0;
            awaddr_latched <= {ADDR_WIDTH{1'b0}};
        end else begin
            case (w_state)
                W_IDLE: begin
                    S_BVALID  <= 1'b0;
                    S_AWREADY <= 1'b1;
                    S_WREADY  <= 1'b0;

                    if (S_AWVALID && S_AWREADY) begin
                        awaddr_latched <= S_AWADDR;
                        S_AWREADY      <= 1'b0;
                        S_WREADY       <= 1'b1;
                        w_state        <= W_DATA;
                    end
                end

                W_DATA: begin
                    if (S_WVALID && S_WREADY) begin
                        case (awaddr_latched[5:2])
                            4'h0: ctrl_reg <= S_WDATA;
                            4'h1: tx_reg   <= S_WDATA;
                            default: begin
                            end
                        endcase
                        S_WREADY <= 1'b0;
                        S_BRESP  <= 2'b00;
                        S_BVALID <= 1'b1;
                        w_state  <= W_RESP;
                    end
                end

                W_RESP: begin
                    if (S_BVALID && S_BREADY) begin
                        S_BVALID <= 1'b0;
                        w_state  <= W_IDLE;
                    end
                end

                default: begin
                    w_state <= W_IDLE;
                end
            endcase
        end
    end

    always @(posedge aclk) begin
        if (!aresetn) begin
            r_state    <= R_IDLE;
            S_ARREADY  <= 1'b0;
            S_RVALID   <= 1'b0;
            S_RRESP    <= 2'b00;
            S_RDATA    <= 32'h0;
        end else begin
            case (r_state)
                R_IDLE: begin
                    S_RVALID  <= 1'b0;
                    S_ARREADY <= 1'b1;
                    if (S_ARVALID && S_ARREADY) begin
                        S_ARREADY <= 1'b0;
                        case (S_ARADDR[5:2])
                            4'h0: S_RDATA <= ctrl_reg;
                            4'h1: S_RDATA <= tx_reg;
                            4'h2: S_RDATA <= rx_reg;
                            4'h3: S_RDATA <= {30'h0, spi_done, spi_busy};
                            default: S_RDATA <= 32'hDEAD_BEEF;
                        endcase
                        S_RRESP  <= 2'b00;
                        S_RVALID <= 1'b1;
                        r_state  <= R_DATA;
                    end
                end

                R_DATA: begin
                    if (S_RVALID && S_RREADY) begin
                        S_RVALID <= 1'b0;
                        r_state  <= R_IDLE;
                    end
                end

                default: begin
                    r_state <= R_IDLE;
                end
            endcase
        end
    end

    always @(posedge aclk) begin
        if (!aresetn) begin
            spi_sck     <= 1'b0;
            spi_mosi    <= 1'b0;
            spi_cs_n    <= 1'b1;
            bit_cnt     <= 8'd0;
            clk_div_cnt <= 8'd0;
            spi_busy    <= 1'b0;
            spi_done    <= 1'b0;
            shift_tx    <= 8'd0;
            shift_rx    <= 8'd0;
            rx_reg      <= 32'h0;
        end else begin
            spi_done <= 1'b0;

            if (!spi_busy && ctrl_en && ctrl_start) begin
                spi_busy    <= 1'b1;
                spi_cs_n    <= 1'b0;
                bit_cnt     <= 8'd8;
                clk_div_cnt <= 8'd0;
                shift_tx    <= tx_reg[7:0];
                shift_rx    <= 8'd0;
                spi_sck     <= ctrl_cpol;
            end else if (spi_busy) begin
                if (clk_div_cnt == {4'b0, ctrl_div}) begin
                    clk_div_cnt <= 8'd0;
                    spi_sck <= ~spi_sck;

                    if (spi_sck == ctrl_cpol) begin
                        spi_mosi <= shift_tx[7];
                    end else begin
                        shift_rx <= {shift_rx[6:0], spi_miso};
                        shift_tx <= {shift_tx[6:0], 1'b0};
                        bit_cnt  <= bit_cnt - 1'b1;
                        if (bit_cnt == 1) begin
                            spi_busy <= 1'b0;
                            spi_done <= 1'b1;
                            spi_cs_n <= 1'b1;
                            rx_reg   <= {24'h0, {shift_rx[6:0], spi_miso}};
                        end
                    end
                end else begin
                    clk_div_cnt <= clk_div_cnt + 1'b1;
                end
            end
        end
    end

endmodule
