/*---------------------------------------------------------------------------------------------------------
Name		:axi4stream_to_rgb.v
Author		:Amritha Bhargavi Utla
Student ID	:018399641
Description	:Converts an AXI4-Stream video input to parallel R, G, B outputs.Here this modules assumes 
		 the AXI-Stream data is packed RGB.
----------------------------------------------------------------------------------------------------------*/
`timescale 1ns / 1ps
module axi4stream_to_rgb
#(
    parameter integer C_M_AXIS_TDATA_WIDTH = 24, 		// Expected AXI-Stream Data width
    parameter integer C_COLOR_CHANNEL_WIDTH = 8  		// Width of individual R, G, B channels
)
(
    input  reg                                M_AXIS_ACLK,
    input  reg                                M_AXIS_ARESETN,

    // AXI4-Stream Slave Interface
    input  reg [C_M_AXIS_TDATA_WIDTH-1:0]     M_AXIS_TDATA,
    input  reg                                M_AXIS_TVALID,
    output reg                                M_AXIS_TREADY,
    input  reg                                M_AXIS_TLAST, 	// Indicates last beat of a frame/line

    // RGB Video Outputs
    output reg [C_COLOR_CHANNEL_WIDTH-1:0]    rgb_r_out,
    output reg [C_COLOR_CHANNEL_WIDTH-1:0]    rgb_g_out,
    output reg [C_COLOR_CHANNEL_WIDTH-1:0]    rgb_b_out,
    output reg                                pixel_valid_out 	// to indicate when valid pixel data is present.
);

    // Assigned to TREADY to buffer incoming AXI-Stream data if the pixel clock isn't exactly aligned.
    assign M_AXIS_TREADY = M_AXIS_ARESETN; 			

    // Registers to hold current pixel data
    reg [C_COLOR_CHANNEL_WIDTH-1:0] rgb_r_q;
    reg [C_COLOR_CHANNEL_WIDTH-1:0] rgb_g_q;
    reg [C_COLOR_CHANNEL_WIDTH-1:0] rgb_b_q;
    reg pixel_valid_q;

    // AXI-Stream Input Registers (data only valid when TVALID & TREADY)
    always @(posedge M_AXIS_ACLK or negedge M_AXIS_ARESETN)
    begin
        if (!M_AXIS_ARESETN)
	begin
            rgb_r_q <= '0;
            rgb_g_q <= '0;
            rgb_b_q <= '0;
            pixel_valid_q <= 1'b0;
        end
	else
	begin
            if (M_AXIS_TVALID && M_AXIS_TREADY)
	    begin						// Assuming RGB order: Red[23:16], Green[15:8], Blue[7:0]
                rgb_r_q <= M_AXIS_TDATA[23:16];
                rgb_g_q <= M_AXIS_TDATA[15:8];
                rgb_b_q <= M_AXIS_TDATA[7:0];
                pixel_valid_q <= 1'b1; 				// A pixel is received and is valid
            end 
	    else
	    begin
                pixel_valid_q <= 1'b0; 				// No valid pixel received
            end
        end
    end

    assign rgb_r_out = rgb_r_q;
    assign rgb_g_out = rgb_g_q;
    assign rgb_b_out = rgb_b_q;
    assign pixel_valid_out = pixel_valid_q; 			// This will go to the TMDS_encoder

endmodule
