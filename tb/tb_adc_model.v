/*
    testbench for TI-ADC Verilog Model 
    2026-01-29 version 1.0 without periodic calibration
    imitate controller
*/
//`include "../rtl/adc_model.v"
`timescale 10ps/1ps
module tb_adc_model;

parameter CHANNELS = 32;
parameter DATAWIDTH = 8;
parameter CALIB_CYCLES = 1;
parameter CALIB_TIME = 64;   // shorter calibration time in clock cycles
parameter GAIN_CAL_WIDTH = 8;
parameter DESKEW_CAL_WIDTH = 8;

// input signals
reg clk_25G; //25G clock input
reg rst_n; // active low reset
reg calib_start; // start calibration
reg adc_run; // start adc

// output signals
wire adc_ready; // adc is ready
wire adc_calib_done; // calibration done
wire [DATAWIDTH*CHANNELS-1:0] adc_data; // adc data output
wire clk_sram; // sram clock
wire en_sram; // sram enable

// instantiate the adc model
adc_model #(.CHANNELS(CHANNELS),
            .DATAWIDTH(DATAWIDTH),
            .CALIB_CYCLES(CALIB_CYCLES),
            .CALIB_TIME(CALIB_TIME),
            .GAIN_CAL_WIDTH(GAIN_CAL_WIDTH),
            .DESKEW_CAL_WIDTH(DESKEW_CAL_WIDTH)
) u_adc(
    .clk_28G(clk_25G),
    .rst_n(rst_n),
    .adc_ready(adc_ready),
    .calib_start(calib_start),
    .adc_calib_done(adc_calib_done),
    .adc_run(adc_run),
    .adc_data(adc_data),
    .clk_sram(clk_sram),
    .en_sram(en_sram)
);

// clock generation
initial clk_25G = 0;
always #2 clk_25G = ~clk_25G; // 25G clock


// controller
initial begin
    rst_n = 1;
    calib_start = 0;
    adc_run = 1'b1;     // active low
    // wave file configuration
    $dumpfile("./build/tb_adc_model.vcd");
    $dumpvars(0, tb_adc_model);

    $display("=======Simulation(Clock = 25GHz)=======");
    $display("[%t] Starting Simulation...", $time);

    # 100 
    $display("[%t] Asserting reset...", $time);
    rst_n = 0;
    # 200 
    $display("[%t] Releasing reset...", $time);
    rst_n = 1;
    wait (adc_ready == 1'b1);
    $display("[%t] ADC is ready.", $time);
    @(posedge clk_25G); #2
    calib_start = 1;
    wait (adc_ready == 1'b0);
    $display("[%t] ADC is busy.", $time);
    calib_start = 0; // de-assert calib_start
    wait (adc_calib_done == 1'b1);
    $display("[%t] ADC calibration is done.", $time);
    # 400 
    $display("[%t] ADC start running...", $time);
    @(posedge clk_25G);
    adc_run = 1'b0; // start adc    
    #50000; 
    $display("[%t] Stopping Simulation...", $time);
    $display("=============End=============");
    $finish;
end

always @(posedge clk_25G) begin
    if(en_sram) begin
        $display("[%t] Data Strobe! Output: %h",$time, adc_data);
    end
end 

endmodule