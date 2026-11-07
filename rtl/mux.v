`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Mukt Shah
// 
// Create Date: 30.08.2026 01:34:30
// Design Name: 
// Module Name: mux
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


module mux#(
    parameter WIDTH = 32)(
    input  [WIDTH-1:0] a,
    input  [WIDTH-1:0] b,
    input  sel,
    output [WIDTH-1:0] y

    );
    
    assign y = sel ? b : a;
endmodule
