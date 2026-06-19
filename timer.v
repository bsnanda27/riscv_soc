// Timer peripheral : raises timer_interrupt every TIMER_LIMIT cycles.
// In the original repo this lived at testbench level, not inside processor.
`timescale 1ns/1ps
module timer (
    input            clk,
    input            rst,
    output reg       timer_interrupt
);
    parameter TIMER_LIMIT = 100;
    reg [31:0] timer_counter;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            timer_counter   <= 32'b0;
            timer_interrupt <= 1'b0;
        end
        else begin
            timer_counter <= timer_counter + 1'b1;
            if (timer_counter == TIMER_LIMIT) begin
                timer_counter   <= 32'b0;
                timer_interrupt <= 1'b1;
            end
            else begin
                timer_interrupt <= 1'b0;
            end
        end
    end
endmodule
