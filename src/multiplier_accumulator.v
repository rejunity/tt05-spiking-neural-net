module multiplier (
    input xi,
    input wi,
    output signed [1:0] y
);
    // An attempt to explain multiplier logic:
    // x * w 
    //
    // x:0 ->  0
    // x:1 ->  1
    // w:0      -> -1
    // w:1      ->  1
    //
    // 0 * 0 = 0 * -1 =  0 = 00
    // 0 * 1 = 0 *  1 =  0 = 00
    // 1 * 0 = 1 * -1 = -1 = 11
    // 1 * 1 = 1 *  1 =  1 = 01

    //       _ 
    // xw    wx   y10 
    // 00 => 10 => 00
    // 01 => 00 => 00
    // 10 => 11 => 11
    // 11 => 01 => 01

    assign y[0] = xi;
    assign y[1] = xi & (~wi);
endmodule


module mulplier_accumulator #(parameter n_stage = 6) (
    input [(2**n_stage)-1:0] w,
    input [(2**n_stage)-1:0] x,
    output signed [(n_stage+1):0] y_out
);

    wire [(2*(2**n_stage))-1:0] mult_out;

    // Generate instances of multiplier for each element in w and x
    genvar i;
    generate
        for (i=0; i<(2**n_stage); i=i+1) begin : mult_i
            multiplier multiplier (
                .xi(x[i]),
                .wi(w[i]),
                .y(mult_out[2*i+1:2*i])
            );
        end
    endgenerate

    adder_tree #(n_stage) adder (
        .wx(mult_out),
        .y_out(y_out)
    );

endmodule

