`default_nettype none

module tt_um_rejunity_snn #( parameter INPUTS = 16,
                             // parameter NEURONS_0 = 16, parameter NEURONS_1 = 8
                             parameter NEURONS_0 = 16, parameter NEURONS_1 = 16, parameter NEURONS_2 = 8
) (
    input  wire [7:0] ui_in,    // Dedicated inputs - connected to the input switches
    output wire [7:0] uo_out,   // Dedicated outputs - connected to the 7 segment display
    input  wire [7:0] uio_in,   // IOs: Bidirectional Input path
    output wire [7:0] uio_out,  // IOs: Bidirectional Output path
    output wire [7:0] uio_oe,   // IOs: Bidirectional Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // will go high when the design is enabled
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

    // silence linter unused warnings
    wire _unused_ok = &{1'b0,
                        ena,
                        uio_in[7:2],
                        1'b0};

    assign uio_oe[7:0]  = 8'b1111_11_00; // 2 BIDIRECTIONAL pins are used as INPUT mode
    assign uio_out[7:0] = 8'b0000_0000;

    wire reset = !rst_n;
    wire [7:0] data_in = ui_in;
    wire input_weights = uio_in[0];
    wire execute =       uio_in[1];
    wire input_mode =   !uio_in[1];
    

    localparam SYNAPSES_PER_NEURON_0 = INPUTS;
    localparam SYNAPSES_PER_NEURON_1 = NEURONS_0;
    localparam SYNAPSES_PER_NEURON_2 = NEURONS_1;
    localparam WEIGHTS_0 = SYNAPSES_PER_NEURON_0 * NEURONS_0;
    localparam WEIGHTS_1 = SYNAPSES_PER_NEURON_1 * NEURONS_1;
    localparam WEIGHTS_2 = SYNAPSES_PER_NEURON_2 * NEURONS_2;
    localparam WEIGHTS = WEIGHTS_0 + WEIGHTS_1 + WEIGHTS_2;

    localparam THRESHOLD_0_BITS = $clog2(SYNAPSES_PER_NEURON_0)+1;
    localparam THRESHOLD_1_BITS = $clog2(SYNAPSES_PER_NEURON_1)+1;
    localparam THRESHOLD_2_BITS = $clog2(SYNAPSES_PER_NEURON_2)+1;

    localparam BN_ADD_0_BITS = $clog2(SYNAPSES_PER_NEURON_0);
    localparam BN_ADD_1_BITS = $clog2(SYNAPSES_PER_NEURON_1);
    localparam BN_ADD_2_BITS = $clog2(SYNAPSES_PER_NEURON_2);

    localparam WEIGHT_INIT = {WEIGHTS{1'b1}}; // on reset intialise all weights to +1

    reg [INPUTS-1: 0] inputs;
    reg [THRESHOLD_0_BITS-1:0] threshold_0;
    reg [THRESHOLD_1_BITS-1:0] threshold_1;
    reg [THRESHOLD_2_BITS-1:0] threshold_2;
    reg [2:0] shift;

    reg [3:0] batchnorm_factor_0;
    reg [3:0] batchnorm_factor_1;
    reg [3:0] batchnorm_factor_2;
    reg signed [BN_ADD_0_BITS-1:0] batchnorm_addend_0;
    reg signed [BN_ADD_1_BITS-1:0] batchnorm_addend_1;
    reg signed [BN_ADD_2_BITS-1:0] batchnorm_addend_2;

    // Network ----------------------------------------------------------------
    genvar i;
    generate

    wire [INPUTS-1:0] inputs_0 = inputs;
    wire [WEIGHTS_0-1:0] weights_0;
    wire [NEURONS_0-1:0] outputs_0;
    reg  [NEURONS_0-1:0] inputs_1;
    // wire  [NEURONS_0-1:0] inputs_1 = outputs_0;
    wire [WEIGHTS_1-1:0] weights_1;
    wire [NEURONS_1-1:0] outputs_1;
    reg  [NEURONS_1-1:0] inputs_2;
    // wire [NEURONS_1-1:0] inputs_2 = outputs_1;
    wire [WEIGHTS_2-1:0] weights_2;
    wire [NEURONS_2-1:0] outputs_2;

    always @(posedge clk) begin
        if (reset) begin
            inputs_1 <= 0;
            inputs_2 <= 0;
        end else begin
            inputs_1 <= outputs_0;
            inputs_2 <= outputs_1;
        end
    end

    reg [WEIGHTS-1:0] weights;

    assign weights_0 = weights[0                    +: WEIGHTS_0];
    assign weights_1 = weights[WEIGHTS_0            +: WEIGHTS_1];
    assign weights_2 = weights[WEIGHTS_0+WEIGHTS_1  +: WEIGHTS_2];

    for (i = 0; i < NEURONS_0; i = i+1) begin : layer_0
        neuron_lif #(.SYNAPSES(SYNAPSES_PER_NEURON_0), .THRESHOLD_BITS(THRESHOLD_0_BITS), .BATCHNORM_ADDEND_BITS(BN_ADD_0_BITS)) lif (
            .clk(clk),
            .reset(reset),
            .enable(execute),
            .inputs(inputs_0),
            .weights(weights_0[SYNAPSES_PER_NEURON_0*i +: SYNAPSES_PER_NEURON_0]),
            .batchnorm_factor(batchnorm_factor_0),
            .batchnorm_addend(batchnorm_addend_0),
            .shift(shift),
            .threshold(threshold_0),
            .is_spike(outputs_0[i])
        );
    end

    for (i = 0; i < NEURONS_1; i = i+1) begin : layer_1
        neuron_lif #(.SYNAPSES(SYNAPSES_PER_NEURON_1), .THRESHOLD_BITS(THRESHOLD_1_BITS), .BATCHNORM_ADDEND_BITS(BN_ADD_1_BITS)) lif (
            .clk(clk),
            .reset(reset),
            .enable(execute),
            .inputs(inputs_1),
            .weights(weights_1[SYNAPSES_PER_NEURON_1*i +: SYNAPSES_PER_NEURON_1]),
            .batchnorm_factor(batchnorm_factor_1),
            .batchnorm_addend(batchnorm_addend_1),
            .shift(shift),
            .threshold(threshold_1),
            .is_spike(outputs_1[i])
        );
    end
    // assign uo_out[7:0] = outputs_1[7:0];

    for (i = 0; i < NEURONS_2; i = i+1) begin : layer_2
        neuron_lif #(.SYNAPSES(SYNAPSES_PER_NEURON_2), .THRESHOLD_BITS(THRESHOLD_2_BITS), .BATCHNORM_ADDEND_BITS(BN_ADD_2_BITS)) lif (
            .clk(clk),
            .reset(reset),
            .enable(execute),
            .inputs(inputs_2),
            .weights(weights_2[SYNAPSES_PER_NEURON_2*i +: SYNAPSES_PER_NEURON_2]),
            .batchnorm_factor(batchnorm_factor_2),
            .batchnorm_addend(batchnorm_addend_2),
            .shift(shift),
            .threshold(threshold_2),
            .is_spike(outputs_2[i])
        );
    end
    assign uo_out[7:0] = outputs_2[7:0];

    endgenerate


    // Control ----------------------------------------------------------------
    generate
    wire [INPUTS-1: 0] new_inputs;
    wire [WEIGHTS-1:0] new_weights;
    if (WEIGHTS > 8) begin
        assign new_weights = { data_in, weights[8 +: WEIGHTS-8]}; // upload first layer first
        // assign new_weights = { weights[0 +: WEIGHTS-8], data_in };
    end else begin
        assign new_weights = data_in[WEIGHTS-1:0];
    end
    if (INPUTS > 8) begin
        assign new_inputs = { data_in, inputs[8 +: INPUTS-8] }; // upload with struct.pack "<"" order
        // assign new_inputs = { inputs[0 +: INPUTS-8], data_in };
    end else begin
        assign new_inputs = data_in[INPUTS-1:0];
    end
    endgenerate

    always @(posedge clk) begin
        if (reset) begin
            weights <= WEIGHT_INIT;
            inputs <= 0;
            shift <= 0;
            threshold_0 <= 3;
            threshold_1 <= 7;
            threshold_2 <= 9;
            batchnorm_factor_0 <= 4'b0100;
            batchnorm_factor_1 <= 4'b0100;
            batchnorm_factor_2 <= 4'b0100;
            batchnorm_addend_0 <= 0;
            batchnorm_addend_1 <= 0;
            batchnorm_addend_2 <= 0;
        end else begin
            if (input_mode) begin
                if (input_weights)
                    weights <= new_weights;
                else
                    inputs <= new_inputs;
            end
        end
    end

endmodule
