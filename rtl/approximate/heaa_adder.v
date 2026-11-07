// Hardware-Efficient Approximate Adder (HEAA).
// APPROX_BITS (K) least-significant bits are imprecise; the upper bits are exact.
// Valid configuration: 2 <= APPROX_BITS < WIDTH.
module heaa_adder #(
    parameter WIDTH = 32,
    parameter APPROX_BITS = 4
)(
    input  [WIDTH-1:0] A,
    input  [WIDTH-1:0] B,
    output [WIDTH-1:0] Sum,
    output             Cout
);

    // Approximate carry into the exact upper section.
    wire boundary_carry = A[APPROX_BITS-1] & B[APPROX_BITS-1];

    // Exact upper section, including the approximate boundary carry.
    wire [WIDTH-APPROX_BITS:0] upper_sum =
        {1'b0, A[WIDTH-1:APPROX_BITS]} +
        {1'b0, B[WIDTH-1:APPROX_BITS]} + boundary_carry;

    assign Cout = upper_sum[WIDTH-APPROX_BITS];
    assign Sum[WIDTH-1:APPROX_BITS] = upper_sum[WIDTH-APPROX_BITS-1:0];

    // For the boundary bit, MUX(select=AND, input0=OR, input1=0).
    assign Sum[APPROX_BITS-1] = boundary_carry ? 1'b0 :
                                 (A[APPROX_BITS-1] | B[APPROX_BITS-1]);
    assign Sum[APPROX_BITS-2:0] = A[APPROX_BITS-2:0] | B[APPROX_BITS-2:0];

endmodule
