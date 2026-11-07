`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Mukt Shah
// 
// Create Date: 30.08.2026 04:01:35
// Design Name: 
// Module Name: processor
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


module processor(
    input Clk,
    input Reset,
    // 00 exact, 01 HEAA-4, 10 HOERAA-8. Applied only to R-type ADD/SUB.
    input [1:0] ApproxMode,
    
    output [31:0]PC_debug,
    output [31:0]instruction_debug,
    
    output [6:0]opcode_debug,
    output [4:0]rs2_debug,
    output [4:0]rs1_debug,
    output [4:0]rd_debug,
    output [2:0]funct3_debug,
    output [31:0]immediate_debug,
    output [3:0]ALUControl_debug,
    output [31:0]ALU_Result_debug,
    output Zero_debug,
    output Less_debug,
    output LessU_debug,
    
    output Branch_debug,
    output MemRead_debug,
    output [1:0]WriteBackSel_debug,
    output [1:0]ALUOp_debug,
    output MemWrite_debug,
    output [1:0]ALUSrcA_debug,
    output ALUSrcB_debug,
    output RegWrite_debug,
    
    output Branch_taken_debug,
    output [31:0]jal_target_debug,
    output [31:0]jalr_target_debug,
    output [1:0]PCSel_debug
    );

// Instruction fetch wires
wire [31:0]PC_curr;
wire [31:0]PC_in; 
wire [31:0]instruction;
wire [31:0]PC_plus4;

// Instruction decode wires
wire [6:0] opcode;
wire [4:0] rs2;
wire [4:0] rs1;
wire [4:0] rd;
wire [31:0] immediate;
wire [2:0] funct3;

// Control wires
wire Branch;
wire MemRead;
wire [1:0]WriteBackSel;
wire [1:0]ALUOp;
wire MemWrite;
wire [1:0]ALUSrcA;
wire ALUSrcB;
wire RegWrite;

// Execution wires
wire [31:0] read_data1;
wire [31:0] read_data2;
wire [31:0] ALUSrcA_value;
wire [31:0] ALUSrcB_value;
wire [31:0] ALU_Result;
wire [3:0] ALUControl;
wire Zero;
wire Less;
wire LessU;
wire ApproxEnable;
wire [1:0] ALUApproxMode;

// Branch wires
wire [31:0]branch_address;
wire Branch_taken;

// JAL and JALR wires
wire [31:0]jal_target;
wire [31:0]jalr_target;
wire [1:0] PCSel;

// Memory wires
wire [31:0]data_from_mem;
wire [31:0]write_data_reg;

PC pc(
    .PC_in(PC_in),
    .Clk(Clk),
    .Reset(Reset),
    
    .PC_out(PC_curr)
);

PC_adder PC_add4(
    .PC_in(PC_curr),
    
    .PC_out(PC_plus4)
);
        
instruction_mem inst(
    .read_addr(PC_curr),
    
    .instruction(instruction)
);

assign opcode = instruction[6:0];
assign rs2 = instruction[24:20];
assign rs1 = instruction[19:15];
assign rd = instruction[11:7];
assign funct3 = instruction[14:12];

imm_gen imm(
    .instruction(instruction),
    
    .immediate(immediate)
);


adder branch_calc(
    .A(PC_curr),
    .B(immediate),
    
    .out(branch_address)
);  

main_control_unit MCU(
    .opcode(opcode),
    
    .Branch(Branch),
    .MemRead(MemRead),
    .WriteBackSel(WriteBackSel),
    .ALUOp(ALUOp),
    .MemWrite(MemWrite),
    .ALUSrcA(ALUSrcA),
    .ALUSrcB(ALUSrcB),
    .RegWrite(RegWrite)
);

assign jal_target = immediate + PC_curr;
assign jalr_target = {ALU_Result[31:1], 1'b0};

assign Branch_taken = (Branch & Zero & (funct3 == 3'b000)) |  // beq
                      (Branch & ~Zero & (funct3 == 3'b001))|  // bne
                      (Branch & Less & (funct3 == 3'b100)) |  // blt
                      (Branch & ~Less & (funct3 == 3'b101))|  // bge  
                      (Branch & LessU & (funct3 == 3'b110))|  // bltu  
                      (Branch & ~LessU & (funct3 == 3'b111)); // bgeu  
                      
assign PCSel = (opcode == 7'b1100111) ? 2'b11:     // jalr
               (opcode == 7'b1101111) ? 2'b10:     // jal     
               (Branch_taken)         ? 2'b01:     // B-type  
                                        2'b00;
                                                              
mux4to1 #(32) PC_mux(
    .a(PC_plus4),
    .b(branch_address),
    .c(jal_target),
    .d(jalr_target),
    .sel(PCSel),
    
    .y(PC_in)
);  

register_file registers(
    .Clk(Clk),
    .Reset(Reset),
    .read_reg1(rs1),
    .read_reg2(rs2),
    .write_reg(rd),
    .data(write_data_reg),
    .RegWrite(RegWrite),
    
    .read_data1(read_data1),
    .read_data2(read_data2)
);

mux#(32) ALUSrcB_mux(
    .a(read_data2),
    .b(immediate),
    .sel(ALUSrcB),
    
    .y(ALUSrcB_value)
);

mux4to1 #(32) ALUSrcA_mux(
    .a(read_data1),
    .b(PC_curr),
    .c(32'd0),
    .d(32'd0),
    .sel(ALUSrcA),
    
    .y(ALUSrcA_value)
);

ALU_control_unit ALU_control(
    .ALUOp(ALUOp),
    .funct3(instruction[14:12]),
    .funct7_5(instruction[30]),    
    
    .ALUControl(ALUControl)
);

// Keep all control-flow, comparison, PC, and load/store address arithmetic exact.
// Only R-type ADD and SUB are eligible for approximation in this first integration.
assign ApproxEnable = (opcode == 7'b0110011) && (funct3 == 3'b000);
assign ALUApproxMode = ApproxEnable ? ApproxMode : 2'b00;

ALU alu(
    .A(ALUSrcA_value),
    .B(ALUSrcB_value),
    .ALUControl(ALUControl),
    .ApproxMode(ALUApproxMode),
    
    .Result(ALU_Result),
    .Zero(Zero),
    .Less(Less),
    .LessU(LessU)
);

data_memory mem(
    .Clk(Clk),
    .address(ALU_Result),
    .write_data(read_data2),
    .funct3(funct3),
    .MemWrite(MemWrite),
    .MemRead(MemRead),
    
    .ReadData(data_from_mem)
);

mux4to1 #(32)WriteBackSel_mux(
    .a(ALU_Result),
    .b(data_from_mem),
    .c(PC_plus4),
    .d(32'd0),
    .sel(WriteBackSel),
    
    .y(write_data_reg)
);   
       
// Debug Signals
assign PC_debug = PC_curr;
assign instruction_debug = instruction; 

assign opcode_debug = opcode;
assign rs2_debug = rs2;
assign rs1_debug = rs1;
assign rd_debug = rd;
assign funct3_debug = funct3;
assign immediate_debug = immediate;

assign ALU_Result_debug = ALU_Result;
assign ALUControl_debug = ALUControl;
assign Zero_debug  = Zero;
assign Less_debug  = Less;
assign LessU_debug  = LessU;

assign Branch_debug = Branch;
assign MemRead_debug = MemRead;
assign WriteBackSel_debug = WriteBackSel;
assign ALUOp_debug = ALUOp;
assign MemWrite_debug = MemWrite;
assign ALUSrcA_debug = ALUSrcA;
assign ALUSrcB_debug = ALUSrcB;
assign RegWrite_debug = RegWrite;

assign Branch_taken_debug = Branch_taken; 
assign jal_target_debug = jal_target;
assign jalr_target_debug = jalr_target;
assign PCSel_debug = PCSel;

endmodule
