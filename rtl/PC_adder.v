`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Mukt Shah
// 
// Create Date: 30.08.2026 01:59:39
// Design Name: 
// Module Name: PC_adder
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


module PC_adder(
    input [31:0]PC_in,
    output [31:0]PC_out
    );

assign PC_out = PC_in + 4;
    
endmodule
