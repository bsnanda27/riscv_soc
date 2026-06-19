module axi_ram #( parameter MEM_DEPTH = 1024)
(
    input  wire        clk,
    input  wire        rst,

    //==============================
    // AXI4-Lite Slave Interface
    //==============================

    // Write Address Channel
    input  wire [31:0] awaddr,
    input  wire        awvalid,
    output reg         awready,

    // Write Data Channel
    input  wire [31:0] wdata,
    input  wire [3:0]  wstrb,
    input  wire        wvalid,
    output reg         wready,

    // Write Response Channel
    output reg [1:0]   bresp,
    output reg         bvalid,
    input  wire        bready,

    // Read Address Channel
    input  wire [31:0] araddr,
    input  wire        arvalid,
    output reg         arready,

    // Read Data Channel
    output reg [31:0]  rdata,
    output reg [1:0]   rresp,
    output reg         rvalid,
    input  wire        rready
);

    //--------------------------------------------------
    // Memory Array
    //--------------------------------------------------

    reg [31:0] mem [0:MEM_DEPTH-1];

    integer i;

    //--------------------------------------------------
    // Reset
    //--------------------------------------------------

    always @(posedge clk)
    begin
        if(rst)
        begin
            awready <= 1'b0;
            wready  <= 1'b0;
            bvalid  <= 1'b0;
            bresp   <= 2'b00;

            arready <= 1'b0;
            rvalid  <= 1'b0;
            rresp   <= 2'b00;
            rdata   <= 32'b0;
        end
        else
        begin

            //------------------------------------------
            // Default
            //------------------------------------------

            awready <= 1'b0;
            wready  <= 1'b0;
            arready <= 1'b0;

            //------------------------------------------
            // WRITE
            //------------------------------------------

            if(awvalid && wvalid && !bvalid)
            begin
                awready <= 1'b1;
                wready  <= 1'b1;

                if(wstrb[0])
                    mem[awaddr[11:2]][7:0]   <= wdata[7:0];

                if(wstrb[1])
                    mem[awaddr[11:2]][15:8]  <= wdata[15:8];

                if(wstrb[2])
                    mem[awaddr[11:2]][23:16] <= wdata[23:16];

                if(wstrb[3])
                    mem[awaddr[11:2]][31:24] <= wdata[31:24];

                bvalid <= 1'b1;
                bresp  <= 2'b00; // OKAY
            end

            if(bvalid && bready)
            begin
                bvalid <= 1'b0;
            end

            //------------------------------------------
            // READ
            //------------------------------------------

            if(arvalid && !rvalid)
            begin
                arready <= 1'b1;

                rdata <= mem[araddr[11:2]];
                rresp <= 2'b00;
                rvalid <= 1'b1;
            end

            if(rvalid && rready)
            begin
                rvalid <= 1'b0;
            end

        end
    end


endmodule
