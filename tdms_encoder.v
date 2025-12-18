/*---------------------------------------------------------------------------------------------------------
Name		:tmds_encoder.v
Author		:Sesha Sayana Reddy Koppula
Student ID	:018399576
Description	:This module is for configuring the HDMI controller. This module provides read/write access
		 to video timing parameters and control flags.
		 Encodes 8-bit RGB data and control signals into 10-bit TMDS characters.
		 And also serializes the 10-bit characters onto differential pairs.
----------------------------------------------------------------------------------------------------------*/
`timescale 1ns / 1ps
module tmds_encoder
#(
    parameter integer C_PIXEL_DATA_WIDTH = 8
)
(
    input  wire                        tmds_clk,       // 10x Pixel Clock
    input  wire                        pixel_clk,      // 1x Pixel Clock
    input  wire                        rst_n,          // Active low reset

    input  wire [C_PIXEL_DATA_WIDTH-1:0] in_data_ch0,   // Blue
    input  wire [C_PIXEL_DATA_WIDTH-1:0] in_data_ch1,   // Green
    input  wire [C_PIXEL_DATA_WIDTH-1:0] in_data_ch2,   // Red

    input  wire                        hsync_pix_clk,
    input  wire                        vsync_pix_clk,
    input  wire                        de_pix_clk,     // Data Enable

    // Differential Outputs
    output wire                        tmds_ch0_p, tmds_ch0_n,
    output wire                        tmds_ch1_p, tmds_ch1_n,
    output wire                        tmds_ch2_p, tmds_ch2_n,
    output wire                        tmds_clk_p, tmds_clk_n
);

    // -------------------------------------------------------------------------
    // TMDS Encoding (8 bits -> 10 bits)
    // -------------------------------------------------------------------------
    // Instantiating three encoders, one for each color channel.
    // The HDMI spec assigns synchronization signals (HSYNC, VSYNC) to Channel 0 (Blue).
    // Channels 1 and 2 usually carry "00" control codes during blanking.

    wire [9:0] encoded_ch0;
    wire [9:0] encoded_ch1;
    wire [9:0] encoded_ch2;

    // Channel 0 (Blue) carries HSYNC and VSYNC
    tmds_encode_channel enc_ch0 (
        .clk(pixel_clk),
        .rst_n(rst_n),
        .data_in(in_data_ch0),
        .c0(hsync_pix_clk),      // HDMI Spec: Bit 0 is HSYNC
        .c1(vsync_pix_clk),      // HDMI Spec: Bit 1 is VSYNC
        .de(de_pix_clk),
        .encoded_out(encoded_ch0)
    );

    // Channel 1 (Green) carries CTL0/CTL1 (usually 0 for video)
    tmds_encode_channel enc_ch1 (
        .clk(pixel_clk),
        .rst_n(rst_n),
        .data_in(in_data_ch1),
        .c0(1'b0),
        .c1(1'b0),
        .de(de_pix_clk),
        .encoded_out(encoded_ch1)
    );

    // Channel 2 (Red) carries CTL2/CTL3 (usually 0 for video)
    tmds_encode_channel enc_ch2 (
        .clk(pixel_clk),
        .rst_n(rst_n),
        .data_in(in_data_ch2),
        .c0(1'b0),
        .c1(1'b0),
        .de(de_pix_clk),
        .encoded_out(encoded_ch2)
    );

    // -------------------------------------------------------------------------
    // Serialization (10 bits parallel -> 1 bit serial)
    // -------------------------------------------------------------------------
    // This requires a clock 10x faster than pixel_clk.
    // Using a modulo-10 counter to load new data every 10 cycles.

    reg [3:0] shift_cnt;
    reg [9:0] shift_reg_ch0, shift_reg_ch1, shift_reg_ch2;

    // Since the pixel clock and TMDS clock are derived from the same PLL but
    // distinct, we need to carefully load data.For this pure Verilog behavioral model, 
    // we rely on the counter wrapping to create the 10-bit window.
    
    always @(posedge tmds_clk or negedge rst_n) 
    begin
        if (!rst_n) 
	begin
            shift_cnt     <= 4'd0;
            shift_reg_ch0 <= 10'd0;
            shift_reg_ch1 <= 10'd0;
	    shift_reg_ch2 <= 10'd0;
        end 
	else 
	begin
            if (shift_cnt == 4'd9) 
	    begin
                shift_cnt     <= 4'd0;
                // Loading the 10-bit encoded data from the pixel domain
                shift_reg_ch0 <= encoded_ch0;
                shift_reg_ch1 <= encoded_ch1;
                shift_reg_ch2 <= encoded_ch2;
	    end 
	    else 
	    begin
                shift_cnt     <= shift_cnt + 1'b1;

                shift_reg_ch0 <= {1'b0, shift_reg_ch0[9:1]};
                shift_reg_ch1 <= {1'b0, shift_reg_ch1[9:1]};
                shift_reg_ch2 <= {1'b0, shift_reg_ch2[9:1]};
            end
        end
    end

    // -------------------------------------------------------------------------
    // 3. Differential Output Drivers
    // -------------------------------------------------------------------------
    // Drive the LSB to the output pins
    
    assign tmds_ch0_p = shift_reg_ch0[0];
    assign tmds_ch0_n = ~shift_reg_ch0[0];

    assign tmds_ch1_p = shift_reg_ch1[0];
    assign tmds_ch1_n = ~shift_reg_ch1[0];

    assign tmds_ch2_p = shift_reg_ch2[0];
    assign tmds_ch2_n = ~shift_reg_ch2[0];

    // Clock Channel
    assign tmds_clk_p = pixel_clk; // Clock is typically 1x pixel rate on the wire (internal 10x is logical)
                                   // Standard HDMI clk is 1x Pixel Clock.
    assign tmds_clk_n = ~pixel_clk;

endmodule


// ----------------------------------------------------------------------------
// Helper Module: Single Channel TMDS Encoder (The "Real" 8b/10b Logic)
// ----------------------------------------------------------------------------
module tmds_encode_channel (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] data_in,
    input  wire       c0,      // Control Bit 0 (HSync)
    input  wire       c1,      // Control Bit 1 (VSync)
    input  wire       de,      // Data Enable
    output reg  [9:0] encoded_out
);

    // --- Minimize Transitions (XOR / XNOR Logic) ---
    // Count the number of 1s in the input byte
    integer i;
    reg [3:0] n1_d; 
    always @(*) 
    begin
        n1_d = 0;
        for (i = 0; i < 8; i = i + 1)
            n1_d = n1_d + data_in[i];
    end

    wire decision1;
    // Decision logic per DVI spec:
    // If (count(1) > 4) OR (count(1) == 4 AND data_in[0] == 0) -> use XNOR
    assign decision1 = (n1_d > 4) || ((n1_d == 4) && (data_in[0] == 1'b0));

    wire [8:0] q_m;
    assign q_m[0] = data_in[0];
    assign q_m[1] = (decision1) ? ~(q_m[0] ^ data_in[1]) : (q_m[0] ^ data_in[1]);
    assign q_m[2] = (decision1) ? ~(q_m[1] ^ data_in[2]) : (q_m[1] ^ data_in[2]);
    assign q_m[3] = (decision1) ? ~(q_m[2] ^ data_in[3]) : (q_m[2] ^ data_in[3]);
    assign q_m[4] = (decision1) ? ~(q_m[3] ^ data_in[4]) : (q_m[3] ^ data_in[4]);
    assign q_m[5] = (decision1) ? ~(q_m[4] ^ data_in[5]) : (q_m[4] ^ data_in[5]);
    assign q_m[6] = (decision1) ? ~(q_m[5] ^ data_in[6]) : (q_m[5] ^ data_in[6]);
    assign q_m[7] = (decision1) ? ~(q_m[6] ^ data_in[7]) : (q_m[6] ^ data_in[7]);
    assign q_m[8] = (decision1) ? 1'b0 : 1'b1; 						// 9th bit encodes the operation used

    // --- DC Balance & Output Generation ---
    // Count 1s and 0s in the transition-minimized 8-bit word (q_m[ 7:0])
    reg [3:0] n1_qm, n0_qm;
    always @(*) 
    begin
        n1_qm = 0;
        for (i = 0; i < 8; i = i + 1)
            n1_qm = n1_qm + q_m[i];
        n0_qm = 4'd8 - n1_qm;
    end

    // Running Disparity Register
    // Tracks the DC bias of the signal transmitted so far.
    // Signed integer (usually 5 bits is enough).
    reg signed [4:0] cnt; 

    always @(posedge clk or negedge rst_n) 
    begin
        if (!rst_n) 
	begin
            cnt         <= 0;
            encoded_out <= 10'b0;
        end 
	else 
	begin
            if (de) 
	    begin
                // Active Video: Perform DC balancing
                if ((cnt == 0) || (n1_qm == n0_qm)) 
		begin
                    //Disparity is neutral, or new data is neutral
                    encoded_out[9]   <= ~q_m[8];
                    encoded_out[8]   <= q_m[8];
                    encoded_out[7:0] <= (q_m[8]) ? q_m[7:0] : ~q_m[7:0];
                    
                    if (q_m[8] == 0) 
                        cnt <= cnt + (n0_qm - n1_qm);
                    else             
                        cnt <= cnt + (n1_qm - n0_qm);
                end 
		else 
		begin
                    // Check if we need to invert data to correct disparity
                    if ((cnt > 0 && n1_qm > n0_qm) || (cnt < 0 && n0_qm > n1_qm)) 
		    begin
                        // Disparity is getting worse so Invert bits
                        encoded_out[9]   <= 1'b1;
                        encoded_out[8]   <= q_m[8];
                        encoded_out[7:0] <= ~q_m[7:0];
                        cnt              <= cnt + {q_m[8], 1'b0} + (n0_qm - n1_qm); 
                    end 
		    else 
		    begin
                        // Disparity is improving so Do not invert
                        encoded_out[9]   <= 1'b0;
                        encoded_out[8]   <= q_m[8];
                        encoded_out[7:0] <= q_m[7:0];
                        cnt              <= cnt - {~q_m[8], 1'b0} + (n1_qm - n0_qm);
                    end
                end
            end 
	    else 
	    begin
                // Blanking Period: Send Control Codes
                // Disparity is reset to 0 during blanking (optional but common practice)
                cnt <= 0;
                
                case ({c1, c0})
                    2'b00: encoded_out <= 10'b1101010100;
                    2'b01: encoded_out <= 10'b0010101011;
                    2'b10: encoded_out <= 10'b0101010100;
                    2'b11: encoded_out <= 10'b1010101011;
                endcase
            end
        end
    end

endmodule

