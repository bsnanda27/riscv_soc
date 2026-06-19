module axi_gpio #(
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

    input      [31:0]             gpio_in,
    output reg [31:0]             gpio_out
);

    reg [31:0] gpio_out_reg;

    reg [ADDR_WIDTH-1:0] awaddr_reg;
    reg [DATA_WIDTH-1:0] wdata_reg;
    reg [DATA_WIDTH/8-1:0] wstrb_reg;

    reg aw_captured;
    reg w_captured;

    localparam W_IDLE = 2'd0;
    localparam W_RESP = 2'd1;

    localparam R_IDLE = 2'd0;
    localparam R_DATA = 2'd1;

    reg [1:0] w_state;
    reg [1:0] r_state;

    always @(posedge aclk) begin
        if (!aresetn) begin
            w_state      <= W_IDLE;
            S_AWREADY    <= 1'b0;
            S_WREADY     <= 1'b0;
            S_BVALID     <= 1'b0;
            S_BRESP      <= 2'b00;
            awaddr_reg   <= {ADDR_WIDTH{1'b0}};
            wdata_reg    <= {DATA_WIDTH{1'b0}};
            wstrb_reg    <= {DATA_WIDTH/8{1'b0}};
            aw_captured  <= 1'b0;
            w_captured   <= 1'b0;
            gpio_out_reg <= 32'h0000_0000;
        end else begin
            case (w_state)
                W_IDLE: begin
                    S_AWREADY <= ~aw_captured;
                    S_WREADY  <= ~w_captured;
                    S_BVALID  <= 1'b0;

                    if (S_AWVALID && S_AWREADY) begin
                        awaddr_reg  <= S_AWADDR;
                        aw_captured <= 1'b1;
                    end

                    if (S_WVALID && S_WREADY) begin
                        wdata_reg   <= S_WDATA;
                        wstrb_reg   <= S_WSTRB;
                        w_captured  <= 1'b1;
                    end

                    if ((aw_captured || (S_AWVALID && S_AWREADY)) &&
                        (w_captured  || (S_WVALID && S_WREADY))) begin
                        case (aw_captured ? awaddr_reg[5:2] : S_AWADDR[5:2])
                            4'h0: begin
                                if ((w_captured ? wstrb_reg[0] : S_WSTRB[0]))
                                    gpio_out_reg[7:0]   <= (w_captured ? wdata_reg[7:0]   : S_WDATA[7:0]);
                                if ((w_captured ? wstrb_reg[1] : S_WSTRB[1]))
                                    gpio_out_reg[15:8]  <= (w_captured ? wdata_reg[15:8]  : S_WDATA[15:8]);
                                if ((w_captured ? wstrb_reg[2] : S_WSTRB[2]))
                                    gpio_out_reg[23:16] <= (w_captured ? wdata_reg[23:16] : S_WDATA[23:16]);
                                if ((w_captured ? wstrb_reg[3] : S_WSTRB[3]))
                                    gpio_out_reg[31:24] <= (w_captured ? wdata_reg[31:24] : S_WDATA[31:24]);
                            end
                            default: begin
                            end
                        endcase

                        S_AWREADY   <= 1'b0;
                        S_WREADY    <= 1'b0;
                        S_BRESP     <= 2'b00;
                        S_BVALID    <= 1'b1;
                        aw_captured <= 1'b0;
                        w_captured  <= 1'b0;
                        w_state     <= W_RESP;
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
        if (!aresetn)
            gpio_out <= 32'h0000_0000;
        else
            gpio_out <= gpio_out_reg;
    end

    always @(posedge aclk) begin
        if (!aresetn) begin
            r_state   <= R_IDLE;
            S_ARREADY <= 1'b0;
            S_RVALID  <= 1'b0;
            S_RRESP   <= 2'b00;
            S_RDATA   <= {DATA_WIDTH{1'b0}};
        end else begin
            case (r_state)
                R_IDLE: begin
                    S_ARREADY <= 1'b1;
                    S_RVALID  <= 1'b0;
                    if (S_ARVALID && S_ARREADY) begin
                        S_ARREADY <= 1'b0;
                        case (S_ARADDR[5:2])
                            4'h0: S_RDATA <= gpio_out_reg;
                            4'h1: S_RDATA <= gpio_in;
                            default: S_RDATA <= 32'hDEAD_BEEF;
                        endcase
                        S_RRESP <= 2'b00;
                        S_RVALID <= 1'b1;
                        r_state <= R_DATA;
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

endmodule
