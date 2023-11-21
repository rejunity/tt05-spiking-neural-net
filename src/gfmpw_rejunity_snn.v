`default_nettype none

module gfmpw_rejunity_snn #( parameter INPUTS = 16,
                             parameter NEURONS_0 = 16, parameter NEURONS_1 = 16, parameter NEURONS_2 = 8
) (
`ifdef USE_POWER_PINS
	inout vdd,
	inout vss,
`endif
	input [37:0] io_in,
	output [37:0] io_out,
	output [37:0] io_oeb, //1 = Input, 0 = Output
	
	input wb_clk_i, //Clock
	
	output [63:0] la_data_out, //Logic analyzer probes
	
	output [2:0] irq
);

// module tt_um_rejunity_snn #( parameter INPUTS = 16,
//                              parameter NEURONS_0 = 16, parameter NEURONS_1 = 16, parameter NEURONS_2 = 8
// ) (
//     input  wire [7:0] ui_in,    // Dedicated inputs - connected to the input switches
//     output wire [7:0] uo_out,   // Dedicated outputs - connected to the 7 segment display
//     input  wire [7:0] uio_in,   // IOs: Bidirectional Input path
//     output wire [7:0] uio_out,  // IOs: Bidirectional Output path
//     output wire [7:0] uio_oe,   // IOs: Bidirectional Enable path (active high: 0=input, 1=output)
//     input  wire       ena,      // will go high when the design is enabled
//     input  wire       clk,      // clock
//     input  wire       rst_n     // reset_n - low to reset
// );

	assign irq = 3'b000;

	assign io_out[4:0] = 5'b00000;
	assign io_oeb[4:0] = 5'b11111;

	assign io_oeb[5] = 1'b1;
	wire rst_n = !io_in[5];

	wire clk   = wb_clk_i;

	localparam CONTROL_PIN_0 = 6;
	localparam CONTROL_PINS = 5;
	localparam DATA_PIN_0 = CONTROL_PIN_0 + CONTROL_PINS;
	localparam DATA_PINS = 8;
	localparam OUTPUT_PIN_0 = 30;
	localparam OUTPUT_PINS = 8;

    assign io_oeb[CONTROL_PINS +: CONTROL_PIN_0] = 5'b11111; // 5 pins in input mode: 2 pins for execution control, 3 pins for SETUP mode.
    assign io_out[CONTROL_PINS +: CONTROL_PIN_0] = 5'b00000;

    assign io_oeb[DATA_PINS +: DATA_PIN_0] = 8'b1111_1111; // 8 pins in input mode.
    assign io_out[DATA_PINS +: DATA_PIN_0] = 8'b0000_0000;

    assign io_oeb[29:19] = {11{1'b1}};
    assign io_out[29:19] = {11{1'b0}};

    //assign io_oeb[OUTPUT_PINS +: OUTPUT_PIN_0] = 8'b0000_0000; // 8 pins in output mode.
    assign io_oeb[37:30] = 8'b0000_0000; // 8 pins in output mode.

    wire reset = !rst_n;
    wire [7:0] data_in = io_in[DATA_PINS +: DATA_PIN_0];

    wire execute = io_in[CONTROL_PIN_0 + 0];
    wire setup_sync = io_in[CONTROL_PIN_0 + 1];
    wire [2:0] setup_control = io_in[3 +: CONTROL_PIN_0 + 2];
    
    wire setup_sync_posedge;
    signal_edge sync_edge (
        .clk(clk),
        .reset(reset),
        .signal(setup_sync),
        .on_posedge(setup_sync_posedge)
    );
    wire setup_enable = !execute; //setup_sync_posedge | (setup_control == 3'b101); // streaming input mode


    localparam NEURONS = NEURONS_0 + NEURONS_1 + NEURONS_2;

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
    localparam THRESHOLD_BITS = THRESHOLD_0_BITS + THRESHOLD_1_BITS + THRESHOLD_0_BITS;

    localparam BN_ADD_0_BITS = $clog2(SYNAPSES_PER_NEURON_0);
    localparam BN_ADD_1_BITS = $clog2(SYNAPSES_PER_NEURON_1);
    localparam BN_ADD_2_BITS = $clog2(SYNAPSES_PER_NEURON_2);
    localparam BN_PARAM_BITS = 8;
    localparam BATCHNORM_PARAMS = NEURONS*BN_PARAM_BITS;


    localparam WEIGHT_INIT = {WEIGHTS{1'b1}}; // on reset intialise all weights to +1
    localparam BATCHNORM_PARAMS_INIT = {NEURONS{8'b0000_0010}}; // on reset intialise all batchnorm
                                                                // params to {scale=2, add=0}

    localparam THRESHOLDS_INIT = {5'd9, 5'd7, 5'd3 };           // on reset intialise thresholds
                                                                // in reverse layer order

    reg [INPUTS-1: 0] inputs;
    reg [THRESHOLD_BITS-1:0] thresholds;
    reg [2:0] shift;

    genvar i;
    // Load sparsity matrices -------------------------------------------------

    reg [NEURONS_0-1:0] CONNECTION_MASK_0 [0:SYNAPSES_PER_NEURON_0-1];
    reg [NEURONS_1-1:0] CONNECTION_MASK_1 [0:SYNAPSES_PER_NEURON_1-1];
    reg [NEURONS_2-1:0] CONNECTION_MASK_2 [0:SYNAPSES_PER_NEURON_2-1];
    initial
    begin
        $readmemb("connections_0.mem", CONNECTION_MASK_0);
        $readmemb("connections_1.mem", CONNECTION_MASK_1);
        $readmemb("connections_2.mem", CONNECTION_MASK_2);
    end

    // Network ----------------------------------------------------------------
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

    wire [NEURONS_0*BN_PARAM_BITS-1:0] batchnorm_params_0;
    wire [NEURONS_1*BN_PARAM_BITS-1:0] batchnorm_params_1;
    wire [NEURONS_2*BN_PARAM_BITS-1:0] batchnorm_params_2;

    wire [THRESHOLD_0_BITS-1:0] threshold_0;
    wire [THRESHOLD_1_BITS-1:0] threshold_1;
    wire [THRESHOLD_2_BITS-1:0] threshold_2;

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
    reg [BATCHNORM_PARAMS-1:0] batchnorm_params;

    assign weights_0 = weights[0                    +: WEIGHTS_0];
    assign weights_1 = weights[WEIGHTS_0            +: WEIGHTS_1];
    assign weights_2 = weights[WEIGHTS_0+WEIGHTS_1  +: WEIGHTS_2];

    assign batchnorm_params_0 = batchnorm_params[0                    *BN_PARAM_BITS +: NEURONS_0*BN_PARAM_BITS];
    assign batchnorm_params_1 = batchnorm_params[NEURONS_0            *BN_PARAM_BITS +: NEURONS_1*BN_PARAM_BITS];
    assign batchnorm_params_2 = batchnorm_params[(NEURONS_0+NEURONS_1)*BN_PARAM_BITS +: NEURONS_2*BN_PARAM_BITS];

    assign threshold_0 = thresholds[0                                   +: THRESHOLD_0_BITS];
    assign threshold_1 = thresholds[THRESHOLD_0_BITS                    +: THRESHOLD_1_BITS];
    assign threshold_2 = thresholds[THRESHOLD_0_BITS+THRESHOLD_1_BITS   +: THRESHOLD_2_BITS];

    for (i = 0; i < NEURONS_0; i = i+1) begin : layer_0

        wire [3:0] bn_factor = batchnorm_params_0[BN_PARAM_BITS*i +: 4];
        wire [BN_ADD_0_BITS-1:0] bn_addend;
        sign_extend #(4, BN_ADD_0_BITS) sign_extend_bn_addend (
            .in(batchnorm_params_0[4 + BN_PARAM_BITS*i +: 4]),
            .out(bn_addend)
        );

        neuron_lif #(.SYNAPSES(SYNAPSES_PER_NEURON_0), .THRESHOLD_BITS(THRESHOLD_0_BITS), .BATCHNORM_ADDEND_BITS(BN_ADD_0_BITS)) lif (
            .clk(clk),
            .reset(reset),
            .enable(execute),
            .inputs(inputs_0 & CONNECTION_MASK_0[i]),
            .weights(weights_0[SYNAPSES_PER_NEURON_0*i +: SYNAPSES_PER_NEURON_0]),
            .batchnorm_factor(bn_factor),
            .batchnorm_addend(bn_addend),
            .shift(shift),
            .threshold(threshold_0),
            .is_spike(outputs_0[i])
        );
    end

    for (i = 0; i < NEURONS_1; i = i+1) begin : layer_1

        wire [3:0] bn_factor = batchnorm_params_1[BN_PARAM_BITS*i +: 4];
        wire [BN_ADD_1_BITS-1:0] bn_addend;
        sign_extend #(4, BN_ADD_1_BITS) sign_extend_bn_addend (
            .in(batchnorm_params_1[4 + BN_PARAM_BITS*i +: 4]),
            .out(bn_addend)
        );

        neuron_lif #(.SYNAPSES(SYNAPSES_PER_NEURON_1), .THRESHOLD_BITS(THRESHOLD_1_BITS), .BATCHNORM_ADDEND_BITS(BN_ADD_1_BITS)) lif (
            .clk(clk),
            .reset(reset),
            .enable(execute),
            .inputs(inputs_1 & CONNECTION_MASK_1[i]),
            .weights(weights_1[SYNAPSES_PER_NEURON_1*i +: SYNAPSES_PER_NEURON_1]),
            .batchnorm_factor(bn_factor),
            .batchnorm_addend(bn_addend),
            .shift(shift),
            .threshold(threshold_1),
            .is_spike(outputs_1[i])
        );
    end
    // assign uo_out[7:0] = outputs_1[7:0];

    for (i = 0; i < NEURONS_2; i = i+1) begin : layer_2

        wire [3:0] bn_factor = batchnorm_params_2[BN_PARAM_BITS*i +: 4];
        wire [BN_ADD_2_BITS-1:0] bn_addend;
        sign_extend #(4, BN_ADD_2_BITS) sign_extend_bn_addend (
            .in(batchnorm_params_2[4 + BN_PARAM_BITS*i +: 4]),
            .out(bn_addend)
        );

        neuron_lif #(.SYNAPSES(SYNAPSES_PER_NEURON_2), .THRESHOLD_BITS(THRESHOLD_2_BITS), .BATCHNORM_ADDEND_BITS(BN_ADD_2_BITS)) lif (
            .clk(clk),
            .reset(reset),
            .enable(execute),
            .inputs(inputs_2 & CONNECTION_MASK_2[i]),
            .weights(weights_2[SYNAPSES_PER_NEURON_2*i +: SYNAPSES_PER_NEURON_2]),
            .batchnorm_factor(bn_factor),
            .batchnorm_addend(bn_addend),
            .shift(shift),
            .threshold(threshold_2),
            .is_spike(outputs_2[i])
        );
    end
    // assign uo_out[7:0] = outputs_2[7:0];

    endgenerate


    // Control ----------------------------------------------------------------
    generate
    wire [INPUTS-1: 0] new_inputs;
    wire [WEIGHTS-1:0] new_weights;
    wire [BATCHNORM_PARAMS-1:0] new_batchnorm_params;
    wire [THRESHOLD_BITS-1:0] new_thresholds;
    wire [2:0] new_shift;
    if (WEIGHTS > 8) begin
        assign new_weights = { data_in, weights[8 +: WEIGHTS-8]}; // upload first layer first
    end else begin
        assign new_weights = data_in[WEIGHTS-1:0];
    end
    if (INPUTS > 8) begin
        assign new_inputs = { data_in, inputs[8 +: INPUTS-8] }; // upload with struct.pack "<"" order
    end else begin
        assign new_inputs = data_in[INPUTS-1:0];
    end
    if (BATCHNORM_PARAMS > 8) begin
        assign new_batchnorm_params = { data_in, batchnorm_params[8 +: BATCHNORM_PARAMS-8] };
    end else begin
        assign new_batchnorm_params = data_in[BATCHNORM_PARAMS-1:0];
    end
    if (THRESHOLD_BITS > 8) begin
        assign new_thresholds = { data_in, thresholds[0 +: THRESHOLD_BITS-8] };
    end else begin
        assign new_thresholds = data_in[THRESHOLD_BITS-1:0];
    end
        assign new_shift = data_in[2:0];
    endgenerate

    always @(posedge clk) begin
        if (reset) begin
            weights <= WEIGHT_INIT;
            batchnorm_params <= BATCHNORM_PARAMS_INIT;
            inputs <= 0;
            shift <= 4;
            thresholds <= THRESHOLDS_INIT;
        end else begin
            if (setup_enable) begin
                case(setup_control)
                    3'b000: inputs <= new_inputs;
                    3'b101: inputs <= new_inputs; // for streaming inputs
                    3'b111: inputs <= new_inputs;

                    3'b001: weights <= new_weights;
                    3'b110: batchnorm_params <= new_batchnorm_params;
                    3'b011: thresholds <= new_thresholds;
                    3'b100: shift <= new_shift;
                    default: begin end
                endcase
            end
        end
    end

    // Debug outputs from neurons in the mid layers
    assign la_data_out[15:0]  = outputs_0[15:0];
    assign la_data_out[32:16] = outputs_1[15:0];
    assign la_data_out[63:33] = {32{1'b0}};


    // Outputs from the last layer
    // assign io_out[8 +: OUTPUT_PIN_0] = outputs_2[7:0];
    assign io_out[37:30] = outputs_2[7:0];

endmodule
