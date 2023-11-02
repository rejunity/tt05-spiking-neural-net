//  7+1 = 0111 + 0001 = overflow     1000   0^0=0
// -8-1 = 1000 + 1111 = underflow (1)0111   1^1=0

module signed_clamped_adder #(parameter WIDTH = 8) (
    input wire signed [WIDTH-1:0] a,
    input wire signed [WIDTH-1:0] b,
    output wire signed [WIDTH-1:0] out
);
    localparam MAX_VALUE = {1'b0, {(WIDTH-1){1'b1}}};
    localparam MIN_VALUE = {1'b1, {(WIDTH-1){1'b0}}};

    wire signed [WIDTH-1:0] a_plus_b = a + b;

    wire is_a_positive = a[WIDTH-1] == 0;
    wire is_sum_positive = a_plus_b[WIDTH-1] == 0;
    wire overflow = (a[WIDTH-1] == b[WIDTH-1]) & (is_a_positive != is_sum_positive);

    assign out = overflow ? (is_a_positive ? MAX_VALUE : MIN_VALUE) :
                            a_plus_b;

endmodule
