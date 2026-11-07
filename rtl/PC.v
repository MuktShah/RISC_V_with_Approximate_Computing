`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Mukt Shah
// 
// Create Date: 30.08.2026 01:58:16
// Design Name: 
// Module Name: PC
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module PC(
    input [31:0]PC_in,
    input Clk,
    input Reset,
    output reg [31:0]PC_out
    );

always@(posedge Clk or negedge Reset) begin
    if(!Reset) begin
        PC_out <= 32'h00000000;
    end else begin
        PC_out <= PC_in;
    end
end
    
endmodule
