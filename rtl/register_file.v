`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Mukt Shah
// 
// Create Date: 30.08.2026 03:44:20
// Design Name: 
// Module Name: register_file
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


module register_file(
    input Clk,
    input Reset,
    input [4:0]read_reg1,
    input [4:0]read_reg2,
    input [4:0]write_reg,
    input [31:0]data,
    input RegWrite,
    
    output [31:0]read_data1,
    output [31:0]read_data2
    );

reg [31:0] registers [31:0];
integer i;
    
always@(posedge Clk or negedge Reset) begin
    if(!Reset) begin
        for (i=0; i < 32;i = i + 1) begin
            registers[i] <= 32'd0;
        end 
    end else if(RegWrite && (write_reg != 5'b00000)) begin
        registers[write_reg] <= data;
    end
end

assign read_data1 = (read_reg1 == 5'd0) ? 32'd0 : registers[read_reg1];
assign read_data2 = (read_reg2 == 5'd0) ? 32'd0 : registers[read_reg2];
  
endmodule
