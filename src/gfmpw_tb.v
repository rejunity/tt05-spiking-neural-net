`default_nettype none
`timescale 1ns/1ps

// testbench is controlled by test.py
// module tb_gfmpw ();
module tb ();

    // this part dumps the trace to a vcd file that can be viewed with GTKWave
    initial begin
        $dumpfile ("tb_gfmpw.vcd");
        $dumpvars (0, tb);
        #1;
    end

    // wire up the inputs and outputs
    reg  clk;
    reg  rst_n;
    reg  [37:0] io_in;
    wire [37:0] io_out;
    wire [37:0] io_oeb;
    wire [63:0] la_data_out;
    wire [2:0] irq;

    gfmpw_rejunity_snn gfmpw_rejunity_snn (
    // @TODO: figure out if USE_POWER_PINS is OK here
    `ifdef USE_POWER_PINS
        .vdd( 1'b1),
        .vss( 1'b0),
    `endif
    // `ifdef GL_TEST
    //     .VPWR( 1'b1),
    //     .VGND( 1'b0),
    // `endif
        .io_in      (io_in),        // IOs: Input path
        .io_out     (io_out),       // IOs: Output path
        .io_oeb     (io_oeb),       // IOs: Enable path (active high: 0=input, 1=output)
        .la_data_out(la_data_out),  // Logic analyzer probes
        .irq        (irq),          // IRQs
        .wb_clk_i   (clk)           // clock
        );

endmodule
