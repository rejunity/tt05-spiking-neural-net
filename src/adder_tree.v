
module adder_tree
#(
    parameter   n_stage = 5     // Minumum is 1 stage
)
(
    input         [WX_BITS-1:0]  wx,
    output signed [(n_stage+1):0]         y_out
);

    localparam WX_BITS = 2**(n_stage+1);

    genvar i, j;
    generate
    // Generate connections
    for (i = 0; i < n_stage; i = i+1) begin : connection
        wire signed [(i+2):0] sum [(2**(n_stage-1-i)-1):0]; // partial sum
    end

    // Stage 1
    // for (j = 0; j < 2**(n_stage-1); j = j+1) begin : first_stage
    for (j = 0; j < WX_BITS/4; j = j+1) begin : first_stage
        assign connection[0].sum[j] = $signed(wx[(4*j+1):(4*j+0)]) +
                                      $signed(wx[(4*j+3):(4*j+2)]);
    end

    // Remaining stages
    for (i = 1; i < n_stage; i = i+1) begin : stage_loop
        for (j = 0; j < 2**(n_stage-1-i); j = j+1) begin : stage
            assign connection[i].sum[j] = connection[i-1].sum[2*j+0] +
                                          connection[i-1].sum[2*j+1];
        end
    end

    assign y_out = connection[n_stage-1].sum[0];
    endgenerate

endmodule
