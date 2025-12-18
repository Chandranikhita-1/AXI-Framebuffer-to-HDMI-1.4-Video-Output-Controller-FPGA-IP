/*---------------------------------------------------------------------------------------------------------
Name		:video_timing_generator.v
Author		:Amritha Bhargavi Utla
Student ID	:018399641
Description	:Generates horizontal and vertical synchronization signals and data enable for video output
		 based on configurable parameters.
----------------------------------------------------------------------------------------------------------*/

`timescale 1ns / 1ps
module video_timing_generator
(
    input  reg                    pixel_clk,
    input  reg                    rst_n,              // Active low reset

    // Configurable timing parameters (from AXI Lite)
    input  reg [31:0]             h_active_in,        // Horizontal Active Pixels
    input  reg [31:0]             v_active_in,        // Vertical Active Lines
    input  reg [31:0]             h_total_in,         // Total Horizontal Pixels (active + blanking)
    input  reg [31:0]             v_total_in,         // Total Vertical Lines (active + blanking)
    input  reg [31:0]             h_sync_start_in,    // H total - H Front Porch - H Sync Width
    input  reg [31:0]             h_sync_end_in,      // H total - H Front Porch
    input  reg [31:0]             v_sync_start_in,    // V total - V Front Porch - V Sync Width
    input  reg [31:0]             v_sync_end_in,      // V total - V Front Porch

    // Video timing outputs
    output reg                    hsync,              // Horizontal Sync (active low)
    output reg                    vsync,              // Vertical Sync (active low)
    output reg                    de                  // Data Enable (active high)
);

    // Internal pixel and line counters - sized for up to 4K resolutions
    reg [11:0]    h_count;
    reg [11:0]    v_count;

    // Default parameters
    localparam H_ACTIVE_DEFAULT     = 1280;
    localparam V_ACTIVE_DEFAULT     = 720;
    localparam H_FRONT_PORCH_DEFAULT= 110;
    localparam H_SYNC_WIDTH_DEFAULT = 40;
    localparam H_BACK_PORCH_DEFAULT = 220;
    localparam V_FRONT_PORCH_DEFAULT= 5;
    localparam V_SYNC_WIDTH_DEFAULT = 5;
    localparam V_BACK_PORCH_DEFAULT = 20;

    localparam H_TOTAL_DEFAULT      = H_ACTIVE_DEFAULT + H_FRONT_PORCH_DEFAULT + H_SYNC_WIDTH_DEFAULT + H_BACK_PORCH_DEFAULT; 	// 1280+110+40+220 = 1650
    localparam V_TOTAL_DEFAULT      = V_ACTIVE_DEFAULT + V_FRONT_PORCH_DEFAULT + V_SYNC_WIDTH_DEFAULT + V_BACK_PORCH_DEFAULT; 	// 720+5+5+20 = 750

    localparam H_SYNC_START_DEFAULT = H_ACTIVE_DEFAULT + H_FRONT_PORCH_DEFAULT; 						// 1280+110 = 1390
    localparam H_SYNC_END_DEFAULT   = H_SYNC_START_DEFAULT + H_SYNC_WIDTH_DEFAULT; 						// 1390+40 = 1430
    localparam V_SYNC_START_DEFAULT = V_ACTIVE_DEFAULT + V_FRONT_PORCH_DEFAULT; 						// 720+5 = 725
    localparam V_SYNC_END_DEFAULT   = V_SYNC_START_DEFAULT + V_SYNC_WIDTH_DEFAULT; 						// 725+5 = 730

    // Registers to hold current active timing parameters.
    reg [11:0] current_h_active;
    reg [11:0] current_v_active;
    reg [11:0] current_h_total;
    reg [11:0] current_v_total;
    reg [11:0] current_h_sync_start;
    reg [11:0] current_h_sync_end;
    reg [11:0] current_v_sync_start;
    reg [11:0] current_v_sync_end;

    // Logic to select between default and AXI-configured values
    always@(*) begin
        current_h_active     = (h_active_in == 0)      ? H_ACTIVE_DEFAULT     : h_active_in[11:0];
        current_v_active     = (v_active_in == 0)      ? V_ACTIVE_DEFAULT     : v_active_in[11:0];
        current_h_total      = (h_total_in == 0)       ? H_TOTAL_DEFAULT      : h_total_in[11:0];
        current_v_total      = (v_total_in == 0)       ? V_TOTAL_DEFAULT      : v_total_in[11:0];
        current_h_sync_start = (h_sync_start_in == 0)  ? H_SYNC_START_DEFAULT : h_sync_start_in[11:0];
        current_h_sync_end   = (h_sync_end_in == 0)    ? H_SYNC_END_DEFAULT   : h_sync_end_in[11:0];
        current_v_sync_start = (v_sync_start_in == 0)  ? V_SYNC_START_DEFAULT : v_sync_start_in[11:0];
        current_v_sync_end   = (v_sync_end_in == 0)    ? V_SYNC_END_DEFAULT   : v_sync_end_in[11:0];
    end

    // ------------------------------------------------------------------------
    // Horizontal Counter Logic
    // Increments on each pixel_clk. Resets at end of H_TOTAL.
    // ------------------------------------------------------------------------
    always @(posedge pixel_clk or negedge rst_n) begin
        if (!rst_n) begin
            h_count <= '0;
        end else begin
            if (h_count == current_h_total - 1) begin
                h_count <= '0;
            end else begin
                h_count <= h_count + 1;
            end
        end
    end

    // ------------------------------------------------------------------------
    // Vertical Counter Logic
    // Increments when horizontal counter wraps around. Resets at end of V_TOTAL.
    // ------------------------------------------------------------------------
    always @(posedge pixel_clk or negedge rst_n) begin
        if (!rst_n) begin
            v_count <= '0;
        end else begin
            if (h_count == current_h_total - 1) begin 							// At the end of a horizontal line
                if (v_count == current_v_total - 1) begin
                    v_count <= '0; 									// End of frame, reset vertical counter
                end else begin
                    v_count <= v_count + 1; 								// Increment vertical counter
                end
            end
        end
    end

    // ------------------------------------------------------------------------
    // Output Signal Generation
    // ------------------------------------------------------------------------

    // Data Enable (DE) is active when counters are within the active display area.
    assign de = (h_count < current_h_active) && (v_count < current_v_active);

    // HSYNC (Horizontal Sync) is active low.
    // It is low during the horizontal sync pulse period.
    assign hsync = ~((h_count >= current_h_sync_start) && (h_count < current_h_sync_end));

    // VSYNC (Vertical Sync) is active low.
    // It is low during the vertical sync pulse period.
    assign vsync = ~((v_count >= current_v_sync_start) && (v_count < current_v_sync_end));

endmodule
