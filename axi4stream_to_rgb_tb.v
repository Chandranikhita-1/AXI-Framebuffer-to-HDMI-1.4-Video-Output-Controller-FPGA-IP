/*---------------------------------------------------------------------------------------------------------
Name		:tb_axi4stream_to_rgb.v
Author		:Sesha Sayana Reddy Koppula
Student ID	:018399576
Description	:Test Bench for axi4stream_to_rgb.v
----------------------------------------------------------------------------------------------------------*/
`timescale 1ns/1ps

module tb_axi4stream_to_rgb;

    localparam integer C_M_AXIS_TDATA_WIDTH   = 24;
    localparam integer C_COLOR_CHANNEL_WIDTH  = 8;

    // Clock & reset
    reg M_AXIS_ACLK;
    reg M_AXIS_ARESETN;

    // AXI4-Stream signals
    reg  [C_M_AXIS_TDATA_WIDTH-1:0] M_AXIS_TDATA;
    reg                             M_AXIS_TVALID;
    wire                            M_AXIS_TREADY;
    reg                             M_AXIS_TLAST;

    // RGB outputs
    wire [C_COLOR_CHANNEL_WIDTH-1:0] rgb_r_out;
    wire [C_COLOR_CHANNEL_WIDTH-1:0] rgb_g_out;
    wire [C_COLOR_CHANNEL_WIDTH-1:0] rgb_b_out;
    wire                             pixel_valid_out;

    reg last_aligned;

    // DUT
    axi4stream_to_rgb #(
        .C_M_AXIS_TDATA_WIDTH   (C_M_AXIS_TDATA_WIDTH),
        .C_COLOR_CHANNEL_WIDTH  (C_COLOR_CHANNEL_WIDTH)
    ) dut (
        .M_AXIS_ACLK    (M_AXIS_ACLK),
        .M_AXIS_ARESETN (M_AXIS_ARESETN),
        .M_AXIS_TDATA   (M_AXIS_TDATA),
        .M_AXIS_TVALID  (M_AXIS_TVALID),
        .M_AXIS_TREADY  (M_AXIS_TREADY),
        .M_AXIS_TLAST   (M_AXIS_TLAST),
        .rgb_r_out      (rgb_r_out),
        .rgb_g_out      (rgb_g_out),
        .rgb_b_out      (rgb_b_out),
        .pixel_valid_out(pixel_valid_out)
    );

    // Clock: 100 MHz
    initial 
    begin
        M_AXIS_ACLK = 1'b0;
        forever #5 M_AXIS_ACLK = ~M_AXIS_ACLK;
    end
	
    //This is just written to get the tlast bit signal 
	always @(posedge M_AXIS_ACLK or negedge M_AXIS_ARESETN) 
	begin
	    if (!M_AXIS_ARESETN)
	        last_aligned <= 1'b0;
	    else if (M_AXIS_TVALID && M_AXIS_TREADY)
	        // Capture TLAST at the same time the DUT captures TDATA
	        last_aligned <= M_AXIS_TLAST;
	    else
	        last_aligned <= 1'b0;
	end


    // Stimulus
    integer i;

    initial 
    begin
        // Initialising
        M_AXIS_ARESETN = 1'b0;
        M_AXIS_TDATA   = '0;
        M_AXIS_TVALID  = 1'b0;
        M_AXIS_TLAST   = 1'b0;

        repeat (10) @(posedge M_AXIS_ACLK);
        M_AXIS_ARESETN = 1'b1;
        repeat (5) @(posedge M_AXIS_ACLK);

        // Send 4 pixels, packed as {R[23:16], G[15:8], B[7:0]}
        send_pixel(8'hFF, 8'h00, 8'h00, 1'b0); 				// Red
        send_pixel(8'h00, 8'hFF, 8'h00, 1'b0); 				// Green
        send_pixel(8'h00, 8'h00, 8'hFF, 1'b0); 				// Blue
        send_pixel(8'h12, 8'h34, 8'h56, 1'b1); 				// Last pixel set TLAST = 1

        repeat (5) @(posedge M_AXIS_ACLK);
	send_pixel(8'hFF, 8'h00, 8'h00, 1'b0); 				// Red
        send_pixel(8'h00, 8'hFF, 8'h00, 1'b0); 				// Green
        send_pixel(8'h00, 8'h00, 8'hFF, 1'b0); 				// Blue
        send_pixel(8'h23, 8'h46, 8'hAB, 1'b1); 				// Last pixel set TLAST = 1
	
	@(posedge M_AXIS_ACLK);

        $display("Stopping axi4stream_to_rgb simulation.");
        $finish;
    end

    // Displaying the values only when pixel_valid_out is high
    initial 
    begin
        $display("time\tTVALID\tTREADY\tvalid_out\tLAST\tR\tG\tB");
        forever 
	begin
            @(posedge M_AXIS_ACLK);
            if (pixel_valid_out) 
	    begin
                $display("%0t\t%b\t%b\t%b\t\t%b\t0x%02h\t0x%02h\t0x%02h",$time, M_AXIS_TVALID, M_AXIS_TREADY,  pixel_valid_out,last_aligned,rgb_r_out, rgb_g_out, rgb_b_out);
            end
        end
    end
    
//WaveForm generation
    initial
    begin
	$dumpfile("tb_axi4stream_to_rgb.vcd");
	$dumpon;
	$dumpvars();
    end

//Task for sending the pixels
    task send_pixel(
        input [7:0] r,
        input [7:0] g,
        input [7:0] b,
        input       last
    );
    begin
        @(posedge M_AXIS_ACLK);
        M_AXIS_TDATA  = {r, g, b};
        M_AXIS_TVALID = 1'b1;
        M_AXIS_TLAST  = last;

        // Wait until TREADY 
	wait (M_AXIS_TREADY);
        @(posedge M_AXIS_ACLK);
        M_AXIS_TVALID = 1'b0;
        M_AXIS_TLAST  = 1'b0;
    end
    endtask


endmodule


//----------------------------OUTPUT---------------------------------------
//time  TVALID TREADY valid_out LAST  R    G    B
//165000   0      1      1      0    0xff 0x00 0x00
//185000   0      1      1      0    0x00 0xff 0x00
//205000   0      1      1      0    0x00 0x00 0xff
//225000   0      1      1      1    0x12 0x34 0x56
//295000   0      1      1      0    0xff 0x00 0x00
//315000   0      1      1      0    0x00 0xff 0x00
//335000   0      1      1      0    0x00 0x00 0xff
//355000   0      1      1      1    0x23 0x46 0xab
//Stopping axi4stream_to_rgb simulation.
//---------------------------------------------------------------------------
