// Hardware-Optimized and Error-Reduced Approximate Adder (HOERAA).
// APPROX_BITS (K) least-significant bits are imprecise; the upper bits are exact.
// Valid configuration: 3 <= APPROX_BITS < WIDTH.
module hoeraa_adder #(
    parameter WIDTH = 32,
    parameter APPROX_BITS = 4
)(
    input  [WIDTH-1:0] A,
    input  [WIDTH-1:0] B,
    output [WIDTH-1:0] Sum,
    output             Cout
);

    wire boundary_carry = A[APPROX_BITS-1] & B[APPROX_BITS-1];
    wire [WIDTH-APPROX_BITS:0] upper_sum =
        {1'b0, A[WIDTH-1:APPROX_BITS]} +
        {1'b0, B[WIDTH-1:APPROX_BITS]} + boundary_carry;

    assign Cout = upper_sum[WIDTH-APPROX_BITS];
    assign Sum[WIDTH-1:APPROX_BITS] = upper_sum[WIDTH-APPROX_BITS-1:0];

    // MUX(select=boundary_carry, input0=A[K-1]|B[K-1], input1=A[K-2]&B[K-2]).
    assign Sum[APPROX_BITS-1] = boundary_carry ?
                                 (A[APPROX_BITS-2] & B[APPROX_BITS-2]) :
                                 (A[APPROX_BITS-1] | B[APPROX_BITS-1]);
    assign Sum[APPROX_BITS-2] = A[APPROX_BITS-2] | B[APPROX_BITS-2];
    assign Sum[APPROX_BITS-3:0] = {APPROX_BITS-2{1'b1}};

endmodule
