`timescale 1ns/1ps

module tb_axi_soc;

    // ── Clock & control ────────────────────────────────────────────────
    reg         clk;
    reg         rst;
    reg         timer_interrupt;

    // ── GPIO / SPI ─────────────────────────────────────────────────────
    reg  [31:0] gpio_in;
    wire [31:0] gpio_out;

    wire        spi_sclk;
    wire        spi_mosi;
    reg         spi_miso;
    wire        spi_cs;

    integer i;

    // ── DUT ────────────────────────────────────────────────────────────
    rv32i_axi_soc dut (
        .clk             (clk),
        .rst             (rst),
        .timer_interrupt (timer_interrupt),
        .gpio_in         (gpio_in),
        .gpio_out        (gpio_out),
        .spi_sclk        (spi_sclk),
        .spi_mosi        (spi_mosi),
        .spi_miso        (spi_miso),
        .spi_cs          (spi_cs)
    );

    // ── Clock: 10 ns period ────────────────────────────────────────────
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // ── Stimulus ───────────────────────────────────────────────────────
    initial begin
        rst             = 1'b1;
        timer_interrupt = 1'b0;
        gpio_in         = 32'hA5A5_5A5A;
        spi_miso        = 1'b0;

        // Blank-fill entire RAM with NOP (addi x0,x0,0)
        for (i = 0; i < 1024; i = i + 1)
            dut.ram_i.mem[i] = 32'h00000013;

        // ── Test program ──────────────────────────────────────────────
        // Expected results:
        //   x1  = 5
        //   x2  = 10
        //   x3  = 12   (5+7)
        //   x4  = 12   (loaded back from 0x40)
        //   x5  = 13   (12+1)
        //   mem[0x40] = 12
        //   mem[0x44] = 13
        dut.ram_i.mem[0]  = 32'h0050_0093; // addi  x1,  x0,  5
        dut.ram_i.mem[1]  = 32'h00A0_0113; // addi  x2,  x0, 10
        dut.ram_i.mem[2]  = 32'h0070_8193; // addi  x3,  x1,  7
        dut.ram_i.mem[3]  = 32'h0430_2023; // sw    x3, 64(x0)
        dut.ram_i.mem[4]  = 32'h0400_2203; // lw    x4, 64(x0)
        dut.ram_i.mem[5]  = 32'h0012_0293; // addi  x5,  x4,  1
        dut.ram_i.mem[6]  = 32'h0450_2223; // sw    x5, 68(x0)
        dut.ram_i.mem[7]  = 32'h0000_006F; // jal   x0,  0   (spin)

        // Hold reset for 3 clock cycles
        repeat (3) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;
    end

    // ── AXI bus trace (every cycle after reset) ────────────────────────
    always @(posedge clk) begin
        if (!rst) begin
            $display("[%0t ns] PC=%08h ARVALID=%b ARREADY=%b RVALID=%b RREADY=%b mem_ready=%b mem_rdata=%08h",
                     $time/1000,
                     dut.processor_i.pc_i.pc_out,
                     dut.M_AXI_ARVALID,
                     dut.M_AXI_ARREADY,
                     dut.M_AXI_RVALID,
                     dut.M_AXI_RREADY,
                     dut.mem_ready,
                     dut.mem_rdata);
	$display("inst_IF=%h inst_DE=%h inst_MW=%h \n",
			dut.processor_i.inst_IF,
			dut.processor_i.inst_DE,
			dut.processor_i.inst_MW
			);
		end
    end

    // ── Pass/Fail check ────────────────────────────────────────────────
    initial begin
        // Wait for reset then allow enough cycles for 8-instruction program
        // through a 2-stage pipeline over AXI (≈ 10 cyc/inst × 8 = 80 minimum)
        wait (!rst);
        repeat (300) @(posedge clk);

        $display("──────────────────────────────────────────");
        $display("PC         = 0x%08h", dut.processor_i.pc_i.pc_out);
        $display("inst_MW    = 0x%08h", dut.processor_i.inst_MW);
        $display("mem[0x00]  = 0x%08h (expect 00500093)", dut.ram_i.mem[0]);
        $display("mem[0x40]  = 0x%08h (expect 0000000c=12)", dut.ram_i.mem[16]);
        $display("mem[0x44]  = 0x%08h (expect 0000000d=13)", dut.ram_i.mem[17]);
        $display("──────────────────────────────────────────");

        if (dut.ram_i.mem[0] !== 32'h0050_0093) begin
            $display("FAIL: program memory corrupted at mem[0]");
            $finish;
        end

        if (dut.ram_i.mem[16] !== 32'd12) begin
            $display("FAIL: mem[0x40] expected 12 (0x0000000C), got 0x%08h", dut.ram_i.mem[16]);
            $finish;
        end

	if (dut.ram_i.mem[17] !== 32'd13) begin
            $display("FAIL: mem[0x44] expected 13 (0x0000000D), got 0x%08h", dut.ram_i.mem[17]);
            $finish;
        end

        $display("PASS: SW/LW/ALU/fetch path correct");
        $finish;
    end

    // ── Hard timeout ───────────────────────────────────────────────────
    initial begin
        #50000;
        $display("TIMEOUT after 50 us");
        $finish;
    end

    // ── VCD dump ───────────────────────────────────────────────────────
    initial begin
        $dumpfile("tb_axi_soc.vcd");
        $dumpvars(0, tb_axi_soc);
    end

endmodule
