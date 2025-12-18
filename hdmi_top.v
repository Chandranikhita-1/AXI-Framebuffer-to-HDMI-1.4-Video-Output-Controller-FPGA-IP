/*---------------------------------------------------------------------------------------------------------
Name		:hdmi_top.v
Author		:Jiaming Feng
Student ID	:015803515
Description	:This is top-level module for AXI Framebuffer to HDMI 1.4 Video Output Controller.
		 This integrates AXI-Lite for configuration, AXI4-Stream for video input,
		 Video Timing Generator, TMDS Encoder, and a Clocking Wizard.
----------------------------------------------------------------------------------------------------------*/

//`include "clock_generator.v"
//`include "axi4stream_to_rgb.v"
//`include "axi_lite_slave.v"
//`include "tdms_encoder.v"
//`include "video_timing_generator.v"

`timescale 1ns / 1ps
module hdmi_top
#(
    // AXI4-Lite Parameters
    parameter integer C_S_AXI_DATA_WIDTH    = 32,
    parameter integer C_S_AXI_ADDR_WIDTH    = 8,

    // AXI4-Stream Parameters
    parameter integer C_M_AXIS_TDATA_WIDTH  = 24 			// 24-bit RGB (8 bits per channel)
)
(
    // --------------------------------------------------------------------
    // System Inputs
    // --------------------------------------------------------------------
    input                      sys_clk_p,      			// Differential System Clock Input (e.g., 125 MHz for Pynq-Z1)
    input                      sys_clk_n,
    input                      sys_rst_n,      			// Active Low System Reset

    // --------------------------------------------------------------------
    // AXI4-Lite Slave Interface (for control and configuration)
    // Connects to the Zynq's PS or another AXI Master
    // --------------------------------------------------------------------
    input                      S_AXI_ACLK,
    input                      S_AXI_ARESETN,
    input   [C_S_AXI_ADDR_WIDTH-1:0]               S_AXI_AWADDR,
    input   [2:0]                                  S_AXI_AWPROT,
    input                                          S_AXI_AWVALID,
    output                                         S_AXI_AWREADY,
    input   [C_S_AXI_DATA_WIDTH-1:0]               S_AXI_WDATA,
    input   [C_S_AXI_DATA_WIDTH/8-1:0]             S_AXI_WSTRB,
    input                                          S_AXI_WVALID,
    output                                         S_AXI_WREADY,
    output  [1:0]                                  S_AXI_BRESP,
    output                                         S_AXI_BVALID,
    input                                          S_AXI_BREADY,
    input   [C_S_AXI_ADDR_WIDTH-1:0]               S_AXI_ARADDR,
    input   [2:0]                                  S_AXI_ARPROT,
    input                                          S_AXI_ARVALID,
    output                                         S_AXI_ARREADY,
    output  [C_S_AXI_DATA_WIDTH-1:0]               S_AXI_RDATA,
    output  [1:0]                                  S_AXI_RRESP,
    output                                         S_AXI_RVALID,
    input                                          S_AXI_RREADY,

    // --------------------------------------------------------------------
    // AXI4-Stream Slave Interface (for incoming video pixel data)
    // Connects to an AXI4-Stream Video Source (e.g., VDMA, video test pattern generator)
    // --------------------------------------------------------------------
    input                      		      M_AXIS_ACLK,
    input                      		      M_AXIS_ARESETN,
    input   [C_M_AXIS_TDATA_WIDTH-1:0]             M_AXIS_TDATA,
    input                                          M_AXIS_TVALID,
    output                                        M_AXIS_TREADY,
    input                                          M_AXIS_TLAST,

    // --------------------------------------------------------------------
    // HDMI TMDS Outputs (Physical Pins to HDMI Connector)
    // --------------------------------------------------------------------
    output                         tmds_clk_p,
    output                         tmds_clk_n,
    output                         tmds_ch0_p, 			// Data Channel 0 (Blue)
    output                         tmds_ch0_n,
    output                         tmds_ch1_p, 			// Data Channel 1 (Green)
    output                         tmds_ch1_n,
    output                         tmds_ch2_p, 			// Data Channel 2 (Red)
    output                         tmds_ch2_n,

    // --------------------------------------------------------------------
    // DDC (Display Data Channel)
    // --------------------------------------------------------------------
    output                         scl_ddc,    // Clock
    input                          sda_ddc,    // Data 
    input                          hpd_in      // Hot-Plug Detect Input

);

    // --------------------------------------------------------------------
    // Internal Signals
    // --------------------------------------------------------------------

    // Clock and Reset Signals from Clocking Wizard
    wire clk_74m25_pixel;  						// Pixel clock for 720p/60Hz (74.25 MHz)
    wire clk_371m25_tmds;  						// TMDS clock (5x pixel clock, 371.25 MHz)
    wire locked;           						// PLL lock status
    reg rst_n_int;        						// Internal synchronized reset

    // AXI-Lite Register Outputs (to VTG)
    wire [C_S_AXI_DATA_WIDTH-1:0] ctrl_reg;
    wire [C_S_AXI_DATA_WIDTH-1:0] h_active_reg_val;
    wire [C_S_AXI_DATA_WIDTH-1:0] v_active_reg_val;
    wire [C_S_AXI_DATA_WIDTH-1:0] h_total_reg_val;
    wire [C_S_AXI_DATA_WIDTH-1:0] v_total_reg_val;
    wire [C_S_AXI_DATA_WIDTH-1:0] h_sync_start_reg_val;
    wire [C_S_AXI_DATA_WIDTH-1:0] h_sync_end_reg_val;
    wire [C_S_AXI_DATA_WIDTH-1:0] v_sync_start_reg_val;
    wire [C_S_AXI_DATA_WIDTH-1:0] v_sync_end_reg_val;

    // Video Timing Generator Outputs (to TMDS Encoder)
    wire hsync_vtg;
    wire vsync_vtg;
    wire de_vtg;

    // AXI4-Stream to RGB Converter Outputs
    wire [7:0] rgb_r_from_stream;
    wire [7:0] rgb_g_from_stream;
    wire [7:0] rgb_b_from_stream;
    wire pixel_valid_from_stream; 					// Indicates active pixel from stream

    
    // Synchronizing global reset to pixel clock domain
    always @(posedge clk_74m25_pixel or negedge sys_rst_n) 
    begin
        if (!sys_rst_n)
	begin
            rst_n_int <= 1'b0;
        end 
	else if (locked) 
	begin 								// Only de-assert reset once PLL is locked
            rst_n_int <= 1'b1;
        end
    end

    // --------------------------------------------------------------------
    // Clocking Wizard IP (clk_wiz_0) - PLL/MMCM
    // Generates 74.25 MHz pixel clock and 371.25 MHz TMDS clock from sys_clk.
    // --------------------------------------------------------------------
    /*clk_gen_tb clk_inst (
        .clk_out1 (clk_74m25_pixel), 					// Output pixel clock (e.g., 74.25 MHz for 720p)
        .clk_out2 (clk_371m25_tmds), 					// Output TMDS clock (e.g., 371.25 MHz for 720p)
        .reset    (~sys_rst_n),      					// Active high reset for PLL
        .locked   (locked),          					// PLL lock status
        .clk_in1_p(sys_clk_p),       					// Differential input clock
        .clk_in1_n(sys_clk_n)	
    );*/

    // --------------------------------------------------------------------
    // AXI4-Lite Slave Instance
    // --------------------------------------------------------------------
    axi_lite_slave #(
        .C_S_AXI_DATA_WIDTH (C_S_AXI_DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH (C_S_AXI_ADDR_WIDTH)
    ) axi_lite_inst (
        .S_AXI_ACLK           (S_AXI_ACLK),
        .S_AXI_ARESETN        (S_AXI_ARESETN),
        .S_AXI_AWADDR         (S_AXI_AWADDR),
        .S_AXI_AWPROT         (S_AXI_AWPROT),
        .S_AXI_AWVALID        (S_AXI_AWVALID),
        .S_AXI_AWREADY        (S_AXI_AWREADY),
        .S_AXI_WDATA          (S_AXI_WDATA),
        .S_AXI_WSTRB          (S_AXI_WSTRB),
        .S_AXI_WVALID         (S_AXI_WVALID),
        .S_AXI_WREADY         (S_AXI_WREADY),
        .S_AXI_BRESP          (S_AXI_BRESP),
        .S_AXI_BVALID         (S_AXI_BVALID),
        .S_AXI_BREADY         (S_AXI_BREADY),
        .S_AXI_ARADDR         (S_AXI_ARADDR),
        .S_AXI_ARPROT         (S_AXI_ARPROT),
        .S_AXI_ARVALID        (S_AXI_ARVALID),
        .S_AXI_ARREADY        (S_AXI_ARREADY),
        .S_AXI_RDATA          (S_AXI_RDATA),
        .S_AXI_RRESP          (S_AXI_RRESP),
        .S_AXI_RVALID         (S_AXI_RVALID),
        .S_AXI_RREADY         (S_AXI_RREADY),
        .ctrl_reg_out         (ctrl_reg),
        .h_active_reg_out     (h_active_reg_val),
        .v_active_reg_out     (v_active_reg_val),
        .h_total_reg_out      (h_total_reg_val),
        .v_total_reg_out      (v_total_reg_val),
        .h_sync_start_reg_out (h_sync_start_reg_val),
        .h_sync_end_reg_out   (h_sync_end_reg_val),
        .v_sync_start_reg_out (v_sync_start_reg_val),
        .v_sync_end_reg_out   (v_sync_end_reg_val)
    );

    // --------------------------------------------------------------------
    // Video Timing Generator Instance
    // Drives hsync, vsync, de based on AXI-Lite configured parameters.
    // --------------------------------------------------------------------
    video_timing_generator vtg_inst (
        .pixel_clk          (clk_74m25_pixel),
        .rst_n              (rst_n_int), 				// Use internal synchronized reset
        .h_active_in        (h_active_reg_val),
        .v_active_in        (v_active_reg_val),
        .h_total_in         (h_total_reg_val),
        .v_total_in         (v_total_reg_val),
        .h_sync_start_in    (h_sync_start_reg_val),
        .h_sync_end_in      (h_sync_end_reg_val),
        .v_sync_start_in    (v_sync_start_reg_val),
        .v_sync_end_in      (v_sync_end_reg_val),
        .hsync              (hsync_vtg),
        .vsync              (vsync_vtg),
        .de                 (de_vtg)
    );

    // --------------------------------------------------------------------
    // AXI4-Stream to RGB Converter Instance
    // Takes packed AXI-Stream data and separates it into R, G, B components.
    // --------------------------------------------------------------------
   axi4stream_to_rgb #(
        .C_M_AXIS_TDATA_WIDTH  (C_M_AXIS_TDATA_WIDTH),
        .C_COLOR_CHANNEL_WIDTH (8) 					// Assuming 8 bits per color channel
    ) axi2rgb_inst (
        .M_AXIS_ACLK        (M_AXIS_ACLK),
        .M_AXIS_ARESETN     (M_AXIS_ARESETN),
        .M_AXIS_TDATA       (M_AXIS_TDATA),
        .M_AXIS_TVALID      (M_AXIS_TVALID),
        .M_AXIS_TREADY      (M_AXIS_TREADY),
        .M_AXIS_TLAST       (M_AXIS_TLAST),
        .rgb_r_out          (rgb_r_from_stream),
        .rgb_g_out         (rgb_g_from_stream),
        .rgb_b_out          (rgb_b_from_stream),
        .pixel_valid_out    (pixel_valid_from_stream)
        //.hsync_out          (), 
        //.vsync_out          (), 
        //.de_out             ()  
    ); 
    // --------------------------------------------------------------------
    // TMDS Encoder Instance
    // Encodes RGB data and timing signals into differential TMDS pairs.
    // --------------------------------------------------------------------
    tmds_encoder #(
        .C_PIXEL_DATA_WIDTH (8) 					// 8 bits per color channel
    ) tmds_enc_inst (
        .tmds_clk           (clk_371m25_tmds),
        .pixel_clk          (clk_74m25_pixel),
        .rst_n              (rst_n_int),
        .in_data_ch0        (rgb_b_from_stream), 			// Blue channel
        .in_data_ch1        (rgb_g_from_stream), 			// Green channel
        .in_data_ch2        (rgb_r_from_stream), 			// Red channel
        .hsync_pix_clk      (hsync_vtg),
        .vsync_pix_clk      (vsync_vtg),
        .de_pix_clk         (de_vtg), 					// Use DE from VTG to control data/control char selection
        .tmds_ch0_p         (tmds_ch0_p),
        .tmds_ch0_n         (tmds_ch0_n),
        .tmds_ch1_p         (tmds_ch1_p),
        .tmds_ch1_n         (tmds_ch1_n),
        .tmds_ch2_p         (tmds_ch2_p),
        .tmds_ch2_n         (tmds_ch2_n),
        .tmds_clk_p         (tmds_clk_p),
        .tmds_clk_n         (tmds_clk_n)
    );
    
    reg [25:0] tick_div = 26'd0;
    reg [15:0] frame_count = 16'd0;

    always @(posedge sys_clk_p) begin
        tick_div <= tick_div + 26'd1;

        // Change number about once per ~0.5 s if clk ≈ 100 MHz
        if (tick_div == 26'd50_000_000) begin
            tick_div    <= 26'd0;
            frame_count <= frame_count + 16'd1;
        end
    end
    assign led = frame_count[9:0];
    // Instantiate the 4-digit driver
    seven_seg_4digit u_sevenseg (
    .clk    (sys_clk_p),     // or a buffered system clock
    .led    (led),
    .value  (frame_count),
    .seg_an (seg_an),
    .seg_cat(seg_cat)
    );
    // --------------------------------------------------------------------
    // DDC (Display Data Channel) and HPD Connections
    // --------------------------------------------------------------------
    assign scl_ddc = 1'b0; 
   // assign sda_ddc = 1'bz; 
   

    
endmodule
