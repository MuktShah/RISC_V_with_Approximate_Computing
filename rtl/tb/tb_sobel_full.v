`timescale 1ns / 1ps

// Run with RTL/sobel_full as the working directory.
module tb_sobel_full;
    reg Clk = 1'b0;
    reg Reset = 1'b0;
    reg [1:0] ApproxMode = 2'b10; // 00 exact, 01 HEAA-4, 10 HOERAA-8
    processor uut (
        .Clk(Clk),
        .Reset(Reset),
        .ApproxMode(ApproxMode)
    );

    always #5 Clk = ~Clk;

    initial begin
        #20 Reset = 1'b1;
        // Worst case: fewer than 2.4 million processor cycles.
        #25000000;
        $writememh("sobel_rtl_output_hoeraa.mem", uut.mem.memory, 17'h10000, 17'h1fc03);
        $display("Full-image Sobel completed: wrote 64,516 output pixels.");
        $finish;
    end
endmodule
