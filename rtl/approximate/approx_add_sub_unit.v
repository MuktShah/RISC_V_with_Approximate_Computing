// Mode-controlled arithmetic datapath for ALU ADD and SUB operations.
// SUB uses A + two's-complement(B); the operand negation is exact, while the
// final addition is selected as exact, HEAA, or HOERAA.
module approx_add_sub_unit #(
    parameter WIDTH = 32,
    parameter HEAA_BITS = 4,
    parameter HOERAA_BITS = 8
)(
    input  [WIDTH-1:0] A,
    input  [WIDTH-1:0] B,
    input              Subtract,
    input  [1:0]       ApproxMode,
    output reg [WIDTH-1:0] Result
);
    localparam MODE_EXACT  = 2'b00;
    localparam MODE_HEAA   = 2'b01;
    localparam MODE_HOERAA = 2'b10;

    // This produces the two's-complement operand for subtraction modulo 2^WIDTH.
    wire [WIDTH-1:0] arithmetic_b = Subtract ? (~B + {{(WIDTH-1){1'b0}}, 1'b1}) : B;
    wire [WIDTH-1:0] exact_result = A + arithmetic_b;

    wire [WIDTH-1:0] heaa_result;
    wire heaa_cout_unused;
    wire [WIDTH-1:0] hoeraa_result;
    wire hoeraa_cout_unused;

    heaa_adder #(.WIDTH(WIDTH), .APPROX_BITS(HEAA_BITS)) heaa (
        .A(A), .B(arithmetic_b), .Sum(heaa_result), .Cout(heaa_cout_unused)
    );

    hoeraa_adder #(.WIDTH(WIDTH), .APPROX_BITS(HOERAA_BITS)) hoeraa (
        .A(A), .B(arithmetic_b), .Sum(hoeraa_result), .Cout(hoeraa_cout_unused)
    );

    always @(*) begin
        case (ApproxMode)
            MODE_HEAA:   Result = heaa_result;
            MODE_HOERAA: Result = hoeraa_result;
            MODE_EXACT:  Result = exact_result;
            default:     Result = exact_result;
        endcase
    end
endmodule
