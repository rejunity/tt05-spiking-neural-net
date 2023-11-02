
module lif_logic #(
    parameter n_stage = 3,
    parameter n_membrane = n_stage + 2,
    parameter n_threshold = n_membrane - 1
) (
    input wire [((2**n_stage)-1):0] inputs,
    input wire [((2**n_stage)-1):0] weights,
    input wire [2:0] shift,
    input wire [n_threshold-1:0] threshold,
    input wire signed [n_membrane-1:0] last_membrane,
    // input wire was_spike,
    // input wire [3:0] BN_factor,
    // input wire [(n_stage+1):0] BN_addend,
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


    // wire signed [(n_stage+1):0] accumulated_membrane_potential = decayed_membrane_potential + sum_post_synaptic_potential;
    wire signed [n_membrane-1:0] accumulated_membrane_potential;
    signed_clamped_adder #(.WIDTH(n_membrane)) signed_clamped_adder(
        .a(decayed_membrane_potential),
        .b(sum_post_synaptic_potential),
        .out(accumulated_membrane_potential)
    );

    // membrane_reset #(n_stage) membrane_reset (
    //     .u(accumulated_membrane_potential),
    //     .threshold(threshold),
    //     .spike(was_spike),
    //     .u_out(new_membrane)
    // );

    // assign is_spike = (new_membrane >= $signed({1'b0, threshold}));

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
    parameter THRESHOLD_BITS = MEMBRANE_BITS - 1
) (
    input wire clk,
    input wire reset,
    input wire enable,
    input wire [SYNAPSES-1:0] inputs,
    input wire [SYNAPSES-1:0] weights,
    input wire [2:0] shift,
    input wire [THRESHOLD_BITS-1:0] threshold,
    output wire [MEMBRANE_BITS-1:0] out_membrane,
    output wire is_spike
);
    localparam STAGE = $clog2(SYNAPSES);

    reg signed [MEMBRANE_BITS-1:0] last_membrane;
    wire signed [MEMBRANE_BITS-1:0] new_membrane;

    lif_logic #(.n_stage(STAGE), .n_membrane(MEMBRANE_BITS), .n_threshold(THRESHOLD_BITS)) lif (
        .inputs(inputs),
        .weights(weights),
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
