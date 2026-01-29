`timescale 10ps/1ps

module adc_model#(
    parameter CHANNELS = 32,  // number of channels
    parameter DATAWIDTH = 8,  // resolution of adc
    parameter CALIB_CYCLES = 1, // number of calibration cycles
    parameter CALIB_TIME = 16384, // calibration time in clock cycles
    parameter GAIN_CAL_WIDTH = 8, // gain calibration data width
    parameter DESKEW_CAL_WIDTH = 8 // deskew calibration data width
)(
    input wire clk_28G, // 28G clock input
    input wire rst_n, // active low reset

    // timing control
    output reg adc_ready,   // reseting is done
    input wire calib_start, // start calibration
    output reg adc_calib_done,  // calibration done
    input wire adc_run, // start adc

    // data interface 
    output reg [DATAWIDTH*CHANNELS-1:0] adc_data, // adc data output
    output reg clk_sram, // sram clock
    output reg en_sram // sram enable
);


    reg [31:0] calib_counter; // calibration counter
    //reg [DATAWIDTH*CHANNELS-1:0] data_counter;  // counter for adc data generation
    reg [7:0] base_sample; // base sample value for adc data
    reg [7:0] next_base_sample; // next base sample value
    reg [9:0] cycle_counter; // cycle counter for calibration timing
    reg internal_en_run; // internal adc run signal
    reg [4:0] clk_div_cnt; // clock divider counter
    integer i; // for loops

    // initial
    initial begin
        // unkown state at the beginning
        adc_ready = 1'bx;
        adc_calib_done = 1'bx;
        //adc_data = {DATAWIDTH*CHANNELS{1'bx}};
        //clk_sram = 1'bx;
        //en_sram = 1'bx;
        internal_en_run = 1'bx;
        calib_counter = 32'dx;
        //data_counter = {DATAWIDTH*CHANNELS{1'bx}};
        cycle_counter = 10'dx;

        wait (rst_n == 1'b0);
        // system reset
        # 2;    // delay 2 time units
        adc_ready = 1'b0;
        adc_calib_done = 1'b0;
        //adc_data = {DATAWIDTH*CHANNELS{1'b0}};
        //clk_sram = 1'b0;
        //en_sram = 1'b0;
        calib_counter = 32'd0;
        //data_counter = {DATAWIDTH*CHANNELS{1'b0}};
        cycle_counter = 10'd0;
        internal_en_run = 1'b0;

        wait (rst_n);
        // calibration process after reset
        @(posedge clk_28G); #2  // synchronous to clk_28G
        adc_ready = 1'b1;

        wait (calib_start);
        // start calibration
        #2
        adc_ready = 1'b0; // adc is busy in calibration
        repeat (CALIB_CYCLES*CALIB_TIME) @(posedge clk_28G); // wait for calibration time
        #2
        adc_ready = 1'b1; // adc is ready
        adc_calib_done = 1'b1; // calibration done 

        wait(!adc_run);
        // wait for adc_run deassertion
        internal_en_run = 1'b1;
    end

    always @(posedge clk_28G or negedge rst_n) begin
        if (!rst_n) begin
            // reset for data and clk_sram
            adc_data <= {DATAWIDTH*CHANNELS{1'b0}};
            clk_sram <= 1'b1;
            en_sram <= 1'b0;
            //data_counter <= {DATAWIDTH*CHANNELS{1'b0}};
            clk_div_cnt <= 5'd0;
            base_sample <= 8'd0;
        end
        else if(internal_en_run) begin
            //data_counter <= data_counter +1'b1;
            //divider 
            clk_div_cnt <= clk_div_cnt + 1'b1;
            if(clk_div_cnt == 5'd31) begin
                clk_sram <= #1 1'b1;
            end
            else if(clk_div_cnt == 5'd15) begin
                clk_sram <= #1 1'b0;
            end

            if (clk_div_cnt == 5'd31) begin
                next_base_sample = base_sample + CHANNELS;   // use next_base_sample to avoid Non-blocking assignment issue
                base_sample <= next_base_sample;
                en_sram <= #0.5 1'b1;
                for (i = 0; i<CHANNELS; i = i + 1) begin
                    adc_data[i*DATAWIDTH +: DATAWIDTH] <= #1.5 (next_base_sample + i);
                end
            end
            else begin
                en_sram <= #0.5 1'b0;
            end
        end
    end

endmodule