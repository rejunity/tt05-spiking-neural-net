
module lif_logic #(
    parameter n_stage = 3,
    parameter n_membrane = n_stage + 2,
    parameter n_threshold = n_membrane - 1,
    parameter n_batchnorm_addend = n_membrane - 2
) (
    input wire [((2**n_stage)-1):0] inputs,
    input wire [((2**n_stage)-1):0] weights,
    input wire [3:0] batchnorm_factor,
    input wire signed [n_batchnorm_addend-1:0] batchnorm_addend,
    input wire [2:0] shift,
    input wire [n_threshold-1:0] threshold,
    input wire signed [n_membrane-1:0] last_membrane,
    output wire signed [n_membrane-1:0] new_membrane,
    output wire is_spike
);

    wire signed [n_membrane-1:0] sum_post_synaptic_potential;
    wire signed [n_membrane-1:0] decayed_membrane_potential;

    // range: -(2**n_stage) .. 0 .. (2**n_stage)
    // case n_stages == 2:
    // -4..4   1100..0100
    //         ^^^^ - 4 bits membrane
    mulplier_accumulator #(n_stage) multiplier_accumulator (
        .w(weights),
        .x(inputs),
        .y_out(sum_post_synaptic_potential)
    );

    // OBSERVATIONS about 'shift'
    //       for threshold < 9 only the range of 0..3 is effective
    //           threshold < 18                  0..4 is effective
    //           threshold < 36                  0..5 is effective
    //               ...

    // --    beta |  shift   -- gamma=1-beta
    // --  1      |    0
    // -- 0.5     |    1
    // -- 0.75    |    2
    // -- 0.875   |    3
    // -- 0.9375  |    4
    // -- 0.96875 |    5
    // -- 0.98438 |    6
    // -- 0.99219 |    7
    //
    // decayed_potential = u - gamma
    membrane_decay #(n_stage) membrane_decay (
        .u(last_membrane),
        .shift(shift),
        .beta_u(decayed_membrane_potential)
    );

    // 1) fails with overflow & underflow
    // wire signed [(n_stage+1):0] accumulated_membrane_potential = decayed_membrane_potential + sum_post_synaptic_potential;
    //
    // 2) safe, no batch norm support
    // wire signed [n_membrane-1:0] accumulated_membrane_potential;
    // signed_clamped_adder #(.WIDTH(n_membrane)) signed_clamped_adder(
    //     .a(decayed_membrane_potential),
    //     .b(sum_post_synaptic_potential),
    //     .out(accumulated_membrane_potential)
    // );

    wire signed [n_membrane-1:0] accumulated_membrane_potential;
    batch_normalization #(.WIDTH(n_membrane), .ADDEND_WIDTH(n_batchnorm_addend)) batch_normalization (
        .u(decayed_membrane_potential),
        .z(sum_post_synaptic_potential),
        // .BN_factor(4'b1000), // scale=0.25
        // .BN_factor(4'b0100), // scale=1
        // .BN_factor(4'b1100), // scale=4
        // .BN_factor(4'b0011), // scale=8
        // .BN_factor(4'b0111), // scale=9 (invalid, here just for testing)
        // .BN_factor(4'b1111), // scale=12 (invalid, here just for testing)
        .BN_factor(batchnorm_factor),
        // .BN_addend(5'b0),
        .BN_addend(batchnorm_addend),
        .u_out(accumulated_membrane_potential)
    );

    membrane_reset #(n_stage) membrane_reset (
        .u(accumulated_membrane_potential),
        .threshold(threshold),
        .spike(is_spike),
        .u_out(new_membrane)
    );

    assign is_spike = (accumulated_membrane_potential >= $signed({1'b0, threshold}));

endmodule

module neuron_lif #(
    parameter SYNAPSES = 32,
    parameter MEMBRANE_BITS = STAGE + 2,
    parameter THRESHOLD_BITS = MEMBRANE_BITS - 1,
    parameter BATCHNORM_ADDEND_BITS = MEMBRANE_BITS - 2
) (
    input wire clk,
    input wire reset,
    input wire enable,
    input wire [SYNAPSES-1:0] inputs,
    input wire [SYNAPSES-1:0] weights,
    input wire [3:0] batchnorm_factor,
    input wire signed [BATCHNORM_ADDEND_BITS-1:0] batchnorm_addend,
    input wire [2:0] shift,
    input wire [THRESHOLD_BITS-1:0] threshold,
    output wire signed [MEMBRANE_BITS-1:0] out_membrane,
    output wire is_spike
);
    localparam STAGE = $clog2(SYNAPSES);

    reg signed [MEMBRANE_BITS-1:0] last_membrane;
    wire signed [MEMBRANE_BITS-1:0] new_membrane;

    lif_logic #(.n_stage(STAGE), .n_membrane(MEMBRANE_BITS),
                .n_threshold(THRESHOLD_BITS), .n_batchnorm_addend(BATCHNORM_ADDEND_BITS)) lif (
        .inputs(inputs),
        .weights(weights),
        .batchnorm_factor(batchnorm_factor),
        .batchnorm_addend(batchnorm_addend),
        .shift(shift),
        .threshold(threshold),
        .last_membrane(last_membrane),
        .new_membrane(new_membrane),
        .is_spike(is_spike)
    );

    always @(posedge clk) begin
        if (reset) begin
            last_membrane <= 0;
        end else begin
            if (enable)
                last_membrane <= new_membrane;
        end
    end

    assign out_membrane = new_membrane;

endmodule
