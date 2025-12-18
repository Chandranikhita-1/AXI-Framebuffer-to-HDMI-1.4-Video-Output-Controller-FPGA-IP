/*---------------------------------------------------------------------------------------------------------
Name		:seven_seg_4digit.v
Author		:Sesha Sayana Reddy Koppula
Student ID	:018399576
Description	:This is a 4-digit 7-segment driver for FPGA board
----------------------------------------------------------------------------------------------------------*/
`timescale 1ns / 1ps

module seven_seg_4digit (
    input          clk,       // system clock (e.g., 100 MHz)
    
    input       [15:0] value,
    output wire [9:0] led,
    
    output reg  [3:0]  seg_an,    // digit enables (active low)
    output reg  [7:0]  seg_cat    // segments {DP,g,f,e,d,c,b,a} (active low)
);

    // Simple refresh counter for multiplexing digits
    reg [15:0] refresh_cnt;
    reg [1:0]  digit_sel;      // which digit is active: 0..3
    reg [3:0]  current_nibble; // hex digit being displayed
    
            
    wire rst_n = 1'b1;
    
    // Refresh/multiplex logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            refresh_cnt    <= 16'd0;
            digit_sel      <= 2'd0;
            seg_an         <= 4'b1111; // all digits off
        end else begin
            refresh_cnt <= refresh_cnt + 16'd1;

            // Use top bits of counter to select digit (slow enough to see steady)
            digit_sel <= refresh_cnt[15:14];  // ~1.5kHz / 4 per digit at 100MHz clk

            case (digit_sel)
                2'd0: begin
                    current_nibble <= value[3:0];      // rightmost digit
                    seg_an         <= 4'b1110;         // digit 0 ON (active low)
                end
                2'd1: begin
                    current_nibble <= value[7:4];
                    seg_an         <= 4'b1101;         // digit 1 ON
                end
                2'd2: begin
                    current_nibble <= value[11:8];
                    seg_an         <= 4'b1011;         // digit 2 ON
                end
                2'd3: begin
                    current_nibble <= value[15:12];    // leftmost digit
                    seg_an         <= 4'b0111;         // digit 3 ON
                end
            endcase
        end
    end

    // Hex to 7-seg decoder (active low, DP off)
    always @(*) begin
        case (current_nibble)
            4'h0: seg_cat = 8'b1100_0000; // 0
            4'h1: seg_cat = 8'b1111_1001; // 1
            4'h2: seg_cat = 8'b1010_0100; // 2
            4'h3: seg_cat = 8'b1011_0000; // 3
            4'h4: seg_cat = 8'b1001_1001; // 4
            4'h5: seg_cat = 8'b1001_0010; // 5
            4'h6: seg_cat = 8'b1000_0010; // 6
            4'h7: seg_cat = 8'b1111_1000; // 7
            4'h8: seg_cat = 8'b1000_0000; // 8
            4'h9: seg_cat = 8'b1001_0000; // 9
            4'hA: seg_cat = 8'b1000_1000; // A
            4'hB: seg_cat = 8'b1000_0011; // b
            4'hC: seg_cat = 8'b1100_0110; // C
            4'hD: seg_cat = 8'b1010_0001; // d
            4'hE: seg_cat = 8'b1000_0110; // E
            4'hF: seg_cat = 8'b1000_1110; // F
            default: seg_cat = 8'b1111_1111; // all off
        endcase
    end

endmodule

