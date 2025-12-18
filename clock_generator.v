/*---------------------------------------------------------------------------------------------------------
Name		:clock_generator.v
Author		:Jiaming Feng
Student ID	:015803515
Description	:This module generates clk_out1: 74.25 MHz (Pixel Clock),clk_out2: 371.25 MHz (TMDS Clock)
		 from a 125 MHz input clock.
----------------------------------------------------------------------------------------------------------*/
`timescale 1ns / 1ps

module clk_gen(
    // Clock Outputs
    output reg clk_out1,
    output reg clk_out2,

    // Status
    output reg locked,

    // Clock Inputs
    input reset,        				// Active high reset (hdmi_top inverts sys_rst_n)
    input clk_in1_p,    				// 125 MHz input
    input clk_in1_n
);

    // 720p 60Hz Pixel Clock: 74.25 MHz
    // Period = 1 / 74.25e6 = ~13.468 ns
    // Half Period = ~6.734 ns
    localparam CLK_OUT1_HALF_PERIOD = 6.734;

    // TMDS Clock (5x Pixel Clock): 371.25 MHz
    // Period = 1 / 371.25e6 = ~2.693 ns
    // Half Period = ~1.3465 ns
    localparam CLK_OUT2_HALF_PERIOD = 1.3465;

    // --- Locked Signal Generation ---
    // Simulates the PLL lock-in time
    initial begin
        locked = 1'b0;
        wait (reset == 1'b0); 				
        #(1000);              				// Wait 1000ns for the "PLL" to stabilize
        locked = 1'b1;        				// Assert locked
    end

    // --- Clock 1 Generator (Pixel Clock) ---
    initial begin
        clk_out1 = 1'b0;
        wait (locked == 1'b1); 				
        
        // Start the clock
        forever #(CLK_OUT1_HALF_PERIOD) clk_out1 = ~clk_out1;
    end

    // --- Clock 2 Generator (TMDS Clock) ---
    initial begin
        clk_out2 = 1'b0;
        wait (locked == 1'b1); 				
        
        // Start the clock
        forever #(CLK_OUT2_HALF_PERIOD) clk_out2 = ~clk_out2;
    end

endmodule
