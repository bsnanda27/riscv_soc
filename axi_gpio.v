module axi_gpio #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input                        aclk,
    input                        aresetn,

    // AXI4-Lite slave interface
    // Write address
    input      [ADDR_WIDTH-1:0]  S_AWADDR,
    input                        S_AWVALID,
    output reg                   S_AWREADY,

    // Write data
    input      [DATA_WIDTH-1:0]  S_WDATA,
    input      [DATA_WIDTH/8-1:0] S_WSTRB,
    input                        S_WVALID,
    output reg                   S_WREADY,

    // Write response
    output reg [1:0]             S_BRESP,
    output reg                   S_BVALID,
    input                        S_BREADY,

    // Read address
    input      [ADDR_WIDTH-1:0]  S_ARADDR,
    input                        S_ARVALID,
    output reg                   S_ARREADY,

    // Read data
    output reg [DATA_WIDTH-1:0]  S_RDATA,
    output reg [1:0]             S_RRESP,
    output reg                   S_RVALID,
    input                        S_RREADY,

    // GPIO pins
    input      [31:0]            gpio_in,
    output reg [31:0]            gpio_out
);

    // Internal registers
    reg [31:0] gpio_out_reg;

    // Address decode (word offsets)
    wire [3:0] addr_word = S_AWVALID ? S_AWADDR[5:2] : S_ARADDR[5:2];

    // ---------------- Write channel ----------------
    typedef enum reg [1:0] {W_IDLE, W_DATA, W_RESP} w_state_t;
    reg [1:0] w_state;

    always @(posedge aclk) begin
        if (!aresetn) begin
            w_state    <= W_IDLE;
            S_AWREADY  <= 1'b0;
            S_WREADY   <= 1'b0;
            S_BVALID   <= 1'b0;
            S_BRESP    <= 2'b00;
            gpio_out_reg <= 32'h0000_0000;
        end else begin
            case (w_state)
                W_IDLE: begin
                    S_BVALID  <= 1'b0;
                    S_AWREADY <= 1'b1;
                    if (S_AWVALID && S_AWREADY) begin
                        S_AWREADY <= 1'b0;
                        S_WREADY  <= 1'b1;
                        w_state   <= W_DATA;
                    end
                end

                W_DATA: begin
                    if (S_WVALID && S_WREADY) begin
                        // Decode write address
                        case (addr_word)
                            4'h0: begin
                                // GPIO_OUT register
                                if (S_WSTRB[0]) gpio_out_reg[7:0]   <= S_WDATA[7:0];
                                if (S_WSTRB[1]) gpio_out_reg[15:8]  <= S_WDATA[15:8];
                                if (S_WSTRB[2]) gpio_out_reg[23:16] <= S_WDATA[23:16];
                                if (S_WSTRB[3]) gpio_out_reg[31:24] <= S_WDATA[31:24];
                            end
                            default: ;
                        endcase

                        S_WREADY <= 1'b0;
                        S_BRESP  <= 2'b00;   // OKAY
                        S_BVALID <= 1'b1;
                        w_state  <= W_RESP;
                    end
                end

                W_RESP: begin
                    if (S_BREADY && S_BVALID) begin
                        S_BVALID <= 1'b0;
                        w_state  <= W_IDLE;
                    end
                end

                default: w_state <= W_IDLE;
            endcase
        end
    end

    // Drive GPIO output
    always @(posedge aclk) begin
        if (!aresetn)
            gpio_out <= 32'h0;
        else
            gpio_out <= gpio_out_reg;
    end

    // ---------------- Read channel ----------------
    typedef enum reg [1:0] {R_IDLE, R_DATA} r_state_t;
    reg [1:0] r_state;

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
                    S_RVALID  <= 1'b0;
                    S_ARREADY <= 1'b1;
                    if (S_ARVALID && S_ARREADY) begin
                        S_ARREADY <= 1'b0;
                        // Decode read address
                        case (S_ARADDR[5:2])
                            4'h0: S_RDATA <= gpio_out_reg;  // GPIO_OUT
                            4'h1: S_RDATA <= gpio_in;       // GPIO_IN
                            default: S_RDATA <= 32'hDEAD_BEEF;
                        endcase
                        S_RRESP  <= 2'b00; // OKAY
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

                default: r_state <= R_IDLE;
            endcase
        end
    end

endmodule
