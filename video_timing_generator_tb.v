/*---------------------------------------------------------------------------------------------------------
Name		:tb_video_timing_generator.v
Author		:Amritha Bhargavi Utla
Student ID	:018399641
Description	:Test Bench for video_timing_generator
----------------------------------------------------------------------------------------------------------*/
`timescale 1ns/1ps

module tb_video_timing_generator;

    // Clock & reset
    reg  pixel_clk;
    reg  rst_n;

    // Inputs
    reg [31:0] h_active_in;
    reg [31:0] v_active_in;
    reg [31:0] h_total_in;
    reg [31:0] v_total_in;
    reg [31:0] h_sync_start_in;
    reg [31:0] h_sync_end_in;
    reg [31:0] v_sync_start_in;
    reg [31:0] v_sync_end_in;

    // Outputs
    wire hsync;
    wire vsync;
    wire de;

    // DUT instance
    video_timing_generator  m(
        .pixel_clk        (pixel_clk),
        .rst_n            (rst_n),
        .h_active_in      (h_active_in),
        .v_active_in      (v_active_in),
        .h_total_in       (h_total_in),
        .v_total_in       (v_total_in),
        .h_sync_start_in  (h_sync_start_in),
        .h_sync_end_in    (h_sync_end_in),
        .v_sync_start_in  (v_sync_start_in),
        .v_sync_end_in    (v_sync_end_in),
        .hsync            (hsync),
        .vsync            (vsync),
        .de               (de)
    );

    // 100 MHz pixel clock
    initial begin
        pixel_clk = 0;
        forever #5 pixel_clk = ~pixel_clk;
    end

    // Stimulus
    initial begin
        $display("Time\th_count current_h_active v_count current_v_active hsync vsync de");
        $monitor("%0t\t %0d               %0d         %0d          %0d            %b      %b    %b", $time,m.h_count,m.current_h_active, m.v_count,m.current_v_active,hsync, vsync, de);

	// Active-low reset asserted
	rst_n = 1'b0;

        h_active_in     = 32'd4;   // active pixels per line
        v_active_in     = 32'd3;   // active lines per frame
        h_total_in      = 32'd6;   // total pixels per line
        v_total_in      = 32'd5;   // total lines per frame
        h_sync_start_in = 32'd4;
        h_sync_end_in   = 32'd5;
        v_sync_start_in = 32'd3;
        v_sync_end_in   = 32'd4;

        // Holding reset for a few cycles
        repeat (5) @(posedge pixel_clk);
        rst_n = 1'b1;   // deassert reset
        $display("Reset deasserted...");
        repeat (80) @(posedge pixel_clk);

        $display("Stopping tb_video_timing_generator simulation.");
        $finish;
    end
    
    //Waveform Generation
    initial 
    begin
    	$dumpfile("tb_video_timing_generator.vcd");
	$dumpvars();
	$dumpon;
    end

endmodule
//----------------------------OUTPUTS-----------------------------------
//Time		h_count current_h_active v_count current_v_active hsync vsync de
//0	 	 0               4         0          3            1      1    1
//Reset deasserted...
//45000	 	 1               4         0          3            1      1    1
//55000	 	 2               4         0          3            1      1    1
//65000	 	 3               4         0          3            1      1    1
//75000	 	 4               4         0          3            0      1    0
//85000	 	 5               4         0          3            1      1    0
//95000	 	 0               4         1          3            1      1    1
//105000	 1               4         1          3            1      1    1
//115000	 2               4         1          3            1      1    1
//125000	 3               4         1          3            1      1    1
//135000	 4               4         1          3            0      1    0
//145000	 5               4         1          3            1      1    0
//155000	 0               4         2          3            1      1    1
//165000	 1               4         2          3            1      1    1
//175000	 2               4         2          3            1      1    1
//185000	 3               4         2          3            1      1    1
//195000	 4               4         2          3            0      1    0
//205000	 5               4         2          3            1      1    0
//215000	 0               4         3          3            1      0    0
//225000	 1               4         3          3            1      0    0
//235000	 2               4         3          3            1      0    0
//245000	 3               4         3          3            1      0    0
//255000	 4               4         3          3            0      0    0
//265000	 5               4         3          3            1      0    0
//275000	 0               4         4          3            1      1    0
//285000	 1               4         4          3            1      1    0
//295000	 2               4         4          3            1      1    0
//305000	 3               4         4          3            1      1    0
//315000	 4               4         4          3            0      1    0
//325000	 5               4         4          3            1      1    0
//335000	 0               4         0          3            1      1    1
//345000	 1               4         0          3            1      1    1
//355000	 2               4         0          3            1      1    1
//365000	 3               4         0          3            1      1    1
//375000	 4               4         0          3            0      1    0
//385000	 5               4         0          3            1      1    0
//395000	 0               4         1          3            1      1    1
//405000	 1               4         1          3            1      1    1
//415000	 2               4         1          3            1      1    1
//425000	 3               4         1          3            1      1    1
//435000	 4               4         1          3            0      1    0
//445000	 5               4         1          3            1      1    0
//455000	 0               4         2          3            1      1    1
//465000	 1               4         2          3            1      1    1
//475000	 2               4         2          3            1      1    1
//485000	 3               4         2          3            1      1    1
//495000	 4               4         2          3            0      1    0
//505000	 5               4         2          3            1      1    0
//515000	 0               4         3          3            1      0    0
//525000	 1               4         3          3            1      0    0
//535000	 2               4         3          3            1      0    0
//545000	 3               4         3          3            1      0    0
//555000	 4               4         3          3            0      0    0
//565000	 5               4         3          3            1      0    0
//575000	 0               4         4          3            1      1    0
//585000	 1               4         4          3            1      1    0
//595000	 2               4         4          3            1      1    0
//605000	 3               4         4          3            1      1    0
//615000	 4               4         4          3            0      1    0
//625000	 5               4         4          3            1      1    0
//635000	 0               4         0          3            1      1    1
//645000	 1               4         0          3            1      1    1
//655000	 2               4         0          3            1      1    1
//665000	 3               4         0          3            1      1    1
//675000	 4               4         0          3            0      1    0
//685000	 5               4         0          3            1      1    0
//695000	 0               4         1          3            1      1    1
//705000	 1               4         1          3            1      1    1
//715000	 2               4         1          3            1      1    1
//725000	 3               4         1          3            1      1    1
//735000	 4               4         1          3            0      1    0
//745000	 5               4         1          3            1      1    0
//755000	 0               4         2          3            1      1    1
//765000	 1               4         2          3            1      1    1
//775000	 2               4         2          3            1      1    1
//785000	 3               4         2          3            1      1    1
//795000	 4               4         2          3            0      1    0
//805000	 5               4         2          3            1      1    0
//815000	 0               4         3          3            1      0    0
//825000	 1               4         3          3            1      0    0
//835000	 2               4         3          3            1      0    0
//Stopping tb_video_timing_generator simulation.
//
