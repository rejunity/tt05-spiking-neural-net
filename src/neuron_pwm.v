module li_logic #(
    parameter n_stage = 3,
    parameter n_membrane = n_stage + 2
) (
    input wire [((2**n_stage)-1):0] inputs,
    input wire [((2**n_stage)-1):0] weights,
    input wire [2:0] shift,
    input wire signed [n_membrane-1:0] bias,
    input wire signed [n_membrane-1:0] last_membrane,
    output wire signed [n_membrane-1:0] new_membrane
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

    wire signed [n_membrane-1:0] accumulated_membrane_potential;
    signed_clamped_adder #(.WIDTH(n_membrane)) add_psp(
        .a(decayed_membrane_potential),
        .b(sum_post_synaptic_potential),
        .out(accumulated_membrane_potential)
    );

    signed_clamped_adder #(.WIDTH(n_membrane)) add_bias(
        .a(accumulated_membrane_potential),
        .b(bias),
        .out(new_membrane)
    );

endmodule

module neuron_pwm #(
    parameter SYNAPSES = 32,
    parameter MEMBRANE_BITS = STAGE + 2
) (
    input wire clk,
    input wire reset,
    input wire enable,
    input wire [SYNAPSES-1:0] inputs,
    input wire [SYNAPSES-1:0] weights,
    input wire [2:0] shift,
    input wire signed [MEMBRANE_BITS-1:0] bias,
    output wire [MEMBRANE_BITS-1:0] out_membrane,
    output wire is_spike
);
    localparam STAGE = $clog2(SYNAPSES);

    reg signed [MEMBRANE_BITS-1:0] last_membrane;
    wire signed [MEMBRANE_BITS-1:0] new_membrane;

    li_logic #(.n_stage(STAGE), .n_membrane(MEMBRANE_BITS)) leaky_integrator (
        .inputs(inputs),
        .weights(weights),
        .shift(shift),
        .bias(bias),
        .last_membrane(last_membrane),
        .new_membrane(new_membrane)
    );

    localparam PWM_BITS = STAGE + 1;
    pwm #(.WIDTH(PWM_BITS)) pwm (
        .clk(clk),
        .reset(reset),
        .value(new_membrane > 0 ? new_membrane[PWM_BITS-1:0] : {PWM_BITS{1'b0}}),
        .out(is_spike)
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
