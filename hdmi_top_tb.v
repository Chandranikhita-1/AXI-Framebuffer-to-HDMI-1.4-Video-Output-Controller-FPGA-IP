/*---------------------------------------------------------------------------------------------------------
Name		:hdmi_top_tb.v
Author		:Sesha Sayana Reddy Koppula
Student ID	:018399576
Description	:Test Bench for hdmi_top.v. This module Simulates clock, reset, AXI-Lite configuration, and
		 AXI4-Stream video inputand monitors HDMI TMDS outputs.
----------------------------------------------------------------------------------------------------------*/

`timescale 1ns / 1ps

module hdmi_top_tb;

    // ------------------------------------------------------------------------
    // Testbench Parameters
    // ------------------------------------------------------------------------
    parameter SYS_CLK_PERIOD = 8; 	// 125 MHz system clock 
    parameter AXI_DATA_WIDTH = 32;
    parameter AXI_ADDR_WIDTH = 8;
    parameter VIDEO_DATA_WIDTH = 24; 

    // HDMI Timing Parameters and these will be written to the AXI-Lite registers
    localparam H_ACTIVE_720P      = 1280;
    localparam V_ACTIVE_720P      = 720;
    localparam H_FRONT_PORCH_720P = 110;
    localparam H_SYNC_WIDTH_720P  = 40;
    localparam H_BACK_PORCH_720P  = 220;
    localparam V_FRONT_PORCH_720P = 5;
    localparam V_SYNC_WIDTH_720P  = 5;
    localparam V_BACK_PORCH_720P  = 20;

    localparam H_TOTAL_720P       = H_ACTIVE_720P + H_FRONT_PORCH_720P + H_SYNC_WIDTH_720P + H_BACK_PORCH_720P; // 1650
    localparam V_TOTAL_720P       = V_ACTIVE_720P + V_FRONT_PORCH_720P + V_SYNC_WIDTH_720P + V_BACK_PORCH_720P; // 750

    localparam H_SYNC_START_720P  = H_ACTIVE_720P + H_FRONT_PORCH_720P; 					// 1390
    localparam H_SYNC_END_720P    = H_SYNC_START_720P + H_SYNC_WIDTH_720P; 					// 1430
    localparam V_SYNC_START_720P  = V_ACTIVE_720P + V_FRONT_PORCH_720P; 					// 725
    localparam V_SYNC_END_720P    = V_SYNC_START_720P + V_SYNC_WIDTH_720P; 					// 730

    // TMDS Clock Frequency for 720p60 is 74.25 MHz * 5 = 371.25 MHz
    // Pixel Clock Period for 720p60 is 1/74.25MHz = 13.468 ns
    // TMDS Clock Period = 1/371.25MHz = 2.693 ns

    // ------------------------------------------------------------------------
    // DUT Inputs/Outputs
    // ------------------------------------------------------------------------
    reg           sys_clk_p;
    reg           sys_clk_n; 						// For differential input clock
    reg           sys_rst_n;

    // AXI-Lite Master Signals
    reg [AXI_ADDR_WIDTH-1:0]      s_axi_awaddr_m;
    reg                           s_axi_awvalid_m;
    reg                           s_axi_wvalid_m;
    reg [AXI_DATA_WIDTH-1:0]      s_axi_wdata_m;
    wire [AXI_DATA_WIDTH/8-1:0]    s_axi_wstrb_m;
    reg                           s_axi_bready_m;
    reg [AXI_ADDR_WIDTH-1:0]      s_axi_araddr_m;
    reg                           s_axi_arvalid_m;
    reg                           s_axi_rready_m;

    wire                           s_axi_awready_s;
    wire                           s_axi_wready_s;
    wire [1:0]                     s_axi_bresp_s;
    wire                           s_axi_bvalid_s;
    wire                           s_axi_arready_s;
    wire [AXI_DATA_WIDTH-1:0]      s_axi_rdata_s;
    wire [1:0]                     s_axi_rresp_s;
    wire                           s_axi_rvalid_s;

    // AXI4-Stream Master Signals
    reg [VIDEO_DATA_WIDTH-1:0]    m_axi_tdata_m;
    reg                           m_axi_tvalid_m;
    reg                           m_axi_tlast_m;
    wire                          m_axi_tready_s; // From DUT

    
    reg [AXI_DATA_WIDTH-1:0] read_val;//checking data after writing

    // HDMI TMDS Outputs
    wire                            tmds_clk_p_o;
    wire                            tmds_clk_n_o;
    wire                            tmds_ch0_p_o; // Blue
    wire                            tmds_ch0_n_o;
    wire                            tmds_ch1_p_o; // Green
    wire                            tmds_ch1_n_o;
    wire                            tmds_ch2_p_o; // Red
    wire                            tmds_ch2_n_o;

    integer 			    pixel_accepted;
    integer 			    frame_accepted;
    
    wire                            scl_ddc_o;
    reg                             sda_ddc_io; 
    reg                             hpd_in_i;   
    integer i;
    integer h_idx, v_idx;                               //Used in send video frame task
    reg [VIDEO_DATA_WIDTH-1:0] pixel_data;
  
    // ------------------------------------------------------------------------
    // Instantiate the Top-Level HDMI Controller
    // ------------------------------------------------------------------------
    hdmi_top #(
        .C_S_AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .C_M_AXIS_TDATA_WIDTH(VIDEO_DATA_WIDTH)
    ) dut (
        // System Signals
        .sys_clk_p(sys_clk_p),
        .sys_clk_n(sys_clk_n),
        .sys_rst_n(sys_rst_n),

        // AXI4-Lite Slave Interface
        .S_AXI_ACLK(sys_clk_p), 			// Use sys_clk_p as AXI clock
        .S_AXI_ARESETN(sys_rst_n),
        .S_AXI_AWADDR(s_axi_awaddr_m),
        .S_AXI_AWPROT(3'd0), 				// Not used in this TB
        .S_AXI_AWVALID(s_axi_awvalid_m),
        .S_AXI_AWREADY(s_axi_awready_s),
        .S_AXI_WDATA(s_axi_wdata_m),
        .S_AXI_WSTRB({AXI_DATA_WIDTH/8{1'b1}}), 	// All bytes active
        .S_AXI_WVALID(s_axi_wvalid_m),
        .S_AXI_WREADY(s_axi_wready_s),
        .S_AXI_BRESP(s_axi_bresp_s),
        .S_AXI_BVALID(s_axi_bvalid_s),
        .S_AXI_BREADY(s_axi_bready_m),
        .S_AXI_ARADDR(s_axi_araddr_m),
        .S_AXI_ARPROT(3'd0), 				// Not used in this TB
        .S_AXI_ARVALID(s_axi_arvalid_m),
        .S_AXI_ARREADY(s_axi_arready_s),
        .S_AXI_RDATA(s_axi_rdata_s),
        .S_AXI_RRESP(s_axi_rresp_s),
        .S_AXI_RVALID(s_axi_rvalid_s),
        .S_AXI_RREADY(s_axi_rready_m),

        // AXI4-Stream Video Input
        .M_AXIS_ACLK(sys_clk_p), 			// AXI-Stream clock
        .M_AXIS_ARESETN(sys_rst_n),
        .M_AXIS_TDATA(m_axi_tdata_m),
        .M_AXIS_TVALID(m_axi_tvalid_m),
        .M_AXIS_TREADY(m_axi_tready_s),
        .M_AXIS_TLAST(m_axi_tlast_m),

        // HDMI TMDS Outputs
        .tmds_clk_p(tmds_clk_p_o),
        .tmds_clk_n(tmds_clk_n_o),
        .tmds_ch0_p(tmds_ch0_p_o), // Blue
        .tmds_ch0_n(tmds_ch0_n_o),
        .tmds_ch1_p(tmds_ch1_p_o), // Green
        .tmds_ch1_n(tmds_ch1_n_o),
        .tmds_ch2_p(tmds_ch2_p_o), // Red
        .tmds_ch2_n(tmds_ch2_n_o),

        .scl_ddc(scl_ddc_o),
        .sda_ddc(sda_ddc_io),
        .hpd_in(hpd_in_i)
    );

    // ------------------------------------------------------------------------
    // Clock Generation
    // ------------------------------------------------------------------------
    initial 
    begin
        sys_clk_p = 0;
        sys_clk_n = 1; 					// Differential clock
    end

    always #(SYS_CLK_PERIOD/2) sys_clk_p = ~sys_clk_p;
    always #(SYS_CLK_PERIOD/2) sys_clk_n = ~sys_clk_n; 	// Inverted for difference

    // ------------------------------------------------------------------------
    // Reset Generation
    // ------------------------------------------------------------------------
    initial 
    begin
        sys_rst_n  = 1'b0; 				// Assert reset
        hpd_in_i   = 1'b1; 				// Assuming HDMI cable is plugged in
        sda_ddc_io = 1'bz; 				// Making SDA tri-state

        #(SYS_CLK_PERIOD * 10); 			// Hold reset for 10 clock cycles
        sys_rst_n  = 1'b1; 				// De-assert reset
    end

   
    
    //To check the frames are set out perfectly or not
    always @(posedge sys_clk_p)
    begin
	if (!sys_rst_n)
	begin
       		pixel_accepted = 0;
       		frame_accepted = 0;
	end
	else if (m_axi_tvalid_m && m_axi_tready_s)
	begin
        	pixel_accepted = pixel_accepted + 1'd1;
        	if (m_axi_tlast_m)
		begin
        	    frame_accepted = frame_accepted + 1'd1;
       		    $display("TB: Frame %0d accepted with %0d pixels",frame_accepted - 1, pixel_accepted);
            	    if (pixel_accepted != H_TOTAL_720P * V_TOTAL_720P)
                	$error("Pixel count mismatch! Expected %0d, got %0d",H_TOTAL_720P * V_TOTAL_720P, pixel_accepted);
            	    pixel_accepted = 0;
        	end
   	end
    end


    // ------------------------------------------------------------------------
    // 					Main Test
    // ------------------------------------------------------------------------
    initial begin
        $display("TB: Starting simulation...");

        // Initialize AXI Master signals
        s_axi_awvalid_m = 1'b0;
        s_axi_wvalid_m  = 1'b0;
        s_axi_bready_m  = 1'b0;
        s_axi_arvalid_m = 1'b0;
        s_axi_rready_m  = 1'b0;
        m_axi_tvalid_m  = 1'b0;
        m_axi_tlast_m   = 1'b0;

        @(posedge sys_rst_n); 					// Wait for reset to complete
        $display("TB: Reset de-asserted. Configuring HDMI Controller...");

        
        // Addresses
        axi_lite_write(8'h00, 32'h00000001); 			// Enable controller
        axi_lite_write(8'h04, H_ACTIVE_720P);
        axi_lite_write(8'h08, V_ACTIVE_720P);
        axi_lite_write(8'h0C, H_TOTAL_720P);
        axi_lite_write(8'h10, V_TOTAL_720P);
        axi_lite_write(8'h14, H_SYNC_START_720P);
        axi_lite_write(8'h18, H_SYNC_END_720P);
        axi_lite_write(8'h1C, V_SYNC_START_720P);
        axi_lite_write(8'h20, V_SYNC_END_720P);
        $display("TB: HDMI Controller configured for 1280x720p60.");

        // Reading back a value
        axi_lite_read(32'h04, read_val);
	if (read_val == H_ACTIVE_720P)
		begin
        		$display("PASS: Address 0x04 contains correct data: %0d", read_val);
    		end
	else
		begin
        		$error("FAIL: Address 0x04 mismatch! Expected: %0d, Got: %0d", H_ACTIVE_720P, read_val);
    		end
        
	
        for (i = 0; i < 3; i = i + 1) 
	begin
            $display("TB: Sending Frame %0d", i);
            send_video_frame();
            // A short delay between frames
            repeat (5) @(posedge sys_clk_p);
        end
	
        $display("TB: Simulation finished.");
        $finish;
    end

    //assign sda_ddc_io = 1'bz; 
    
    //Wavefrom Generation
    initial
    begin
	$dumpon;
	$dumpfile("main_tb.vcd");
	$dumpvars();
    end

    
    
    
    // ------------------------------------------------------------------------
    // AXI-Lite Master Task for Writing
    // ------------------------------------------------------------------------
    task automatic axi_lite_write(input [AXI_ADDR_WIDTH-1:0] addr, input [AXI_DATA_WIDTH-1:0] data);
    begin
        $display("AXI WRITE:	Addr is %d\tInput data is %d",addr,data);

	@(posedge sys_clk_p);
        
        //Write Address Channel
        s_axi_awaddr_m <= addr;
        s_axi_awvalid_m <= 1'b0;
        
	@(posedge sys_clk_p);     			// Waiting for 1 cycle for stability
        s_axi_awvalid_m <= 1'b1;
        // Wait for slave to accept the address
        while (!s_axi_awready_s) 
	begin
            @(posedge sys_clk_p);
        end
        
        // Address handshake complete
        @(posedge sys_clk_p);
        s_axi_awvalid_m <= 1'b0;

        //Write Data Channel
        s_axi_wdata_m <= data;
        s_axi_wvalid_m <= 1'b0;

	@(posedge sys_clk_p);     			// Wait 1 cycle
        s_axi_wvalid_m <= 1'b1;   
	
        // Wait for slave to accept the data
        while (!s_axi_wready_s) begin
            @(posedge sys_clk_p);
        end
        
        // Data handshake complete
        @(posedge sys_clk_p);
        s_axi_wvalid_m <= 1'b0;

        //Write Response Channel
        s_axi_bready_m <= 1'b1;
        
        // Wait for slave to send its response
        while (!s_axi_bvalid_s) begin
            @(posedge sys_clk_p);
        end
        
        // Response handshake complete
        @(posedge sys_clk_p);
        s_axi_bready_m <= 1'b0;
     end   
    endtask
    
    
    // ------------------------------------------------------------------------
    // AXI-Lite Master Task for Reading
    // ------------------------------------------------------------------------
    task automatic axi_lite_read(input [AXI_ADDR_WIDTH-1:0] addr, output [AXI_DATA_WIDTH-1:0] data);
    	begin
        @(posedge sys_clk_p);
        s_axi_awvalid_m <= 1'b0; 
        s_axi_wvalid_m  <= 1'b0;

        //Read Address Channel
        s_axi_araddr_m <= addr;
        s_axi_arvalid_m <= 1'b0;

        @(posedge sys_clk_p); 				// Wait one clock cycle for address to settle
        s_axi_arvalid_m <= 1'b1;

        // Wait for slave to accept the address
        while (!s_axi_arready_s) begin
            @(posedge sys_clk_p);
        end
        
        // Address handshake complete
        @(posedge sys_clk_p);
        s_axi_arvalid_m <= 1'b0;

        //Read Data Channel
        s_axi_rready_m <= 1'b1;
        
        // Wait for slave to send valid data
        while (!s_axi_rvalid_s) begin
            @(posedge sys_clk_p);
        end
        
        // Data handshake complete
        data = s_axi_rdata_s;
        @(posedge sys_clk_p);
        s_axi_rready_m <= 1'b0;
        
	$display("AXI READING:	Addr is %d\tOutput data is %d",addr,data);
	end
    endtask
    
    // ------------------------------------------------------------------------
    // AXI4-Stream Video Source Task
    // ------------------------------------------------------------------------
    task automatic send_video_frame;
    begin
      
        $display("TB: Starting to send video frame...");
	
	m_axi_tdata_m = 8'd0;
   	m_axi_tvalid_m = 1'b0;
    	m_axi_tlast_m  = 1'b0;

        for (v_idx = 0; v_idx < V_TOTAL_720P; v_idx = v_idx + 1) begin
            for (h_idx = 0; h_idx < H_TOTAL_720P; h_idx = h_idx + 1) begin
                if (h_idx < H_ACTIVE_720P && v_idx < V_ACTIVE_720P) begin
                    // Active video region
                    pixel_data[7:0]   = (h_idx % 256);        		// Blue component
                    pixel_data[15:8]  = (v_idx % 256);        		// Green component
                    pixel_data[23:16] = (h_idx + v_idx) % 256; 		// Red component
                end else begin
                    pixel_data = 8'd0;					// Blanking region: Send black
                end

		@(posedge sys_clk_p);					//Wait for a cyclw where slave is ready
        	while (!m_axi_tready_s) @(posedge sys_clk_p);
		
		//Set data and assert VALID
                m_axi_tdata_m  = pixel_data;
                m_axi_tvalid_m = 1'b1;
                m_axi_tlast_m  = (h_idx == H_TOTAL_720P - 1) && (v_idx == V_TOTAL_720P - 1);
                
            end
        end
	@(posedge sys_clk_p);
        m_axi_tdata_m = 8'd0;
	    m_axi_tvalid_m = 1'b0; 						// De-assert TVALID after frame is sent
        m_axi_tlast_m  = 1'b0;
	
	@(posedge sys_clk_p);
        $display("TB: Finished sending video frame.");
    end
    endtask



endmodule


//-------------------------OUTPUT----------------------------------
//TB: Starting simulation...
//TB: Reset de-asserted. Configuring HDMI Controller...
//AXI WRITE:	Addr is   0	Input data is          1
//AXI WRITE:	Addr is   4	Input data is       1280
//AXI WRITE:	Addr is   8	Input data is        720
//AXI WRITE:	Addr is  12	Input data is       1650
//AXI WRITE:	Addr is  16	Input data is        750
//AXI WRITE:	Addr is  20	Input data is       1390
//AXI WRITE:	Addr is  24	Input data is       1430
//AXI WRITE:	Addr is  28	Input data is        725
//AXI WRITE:	Addr is  32	Input data is        730
//TB: HDMI Controller configured for 1280x720p60.
//AXI READING:	Addr is   4	Output data is       1280
//PASS: Address 0x04 contains correct data: 1280
//TB: Sending Frame 0
//TB: Starting to send video frame...
//TB: Frame 0 accepted with 1237500 pixels
//TB: Finished sending video frame.
//TB: Sending Frame 1
//TB: Starting to send video frame...
//TB: Frame 1 accepted with 1237500 pixels
//TB: Finished sending video frame.
//TB: Sending Frame 2
//TB: Starting to send video frame...
//TB: Frame 2 accepted with 1237500 pixels
//TB: Finished sending video frame.
//TB: Sending Frame 3
//TB: Starting to send video frame...
//TB: Frame 3 accepted with 1237500 pixels
//TB: Finished sending video frame.
//TB: Sending Frame 4
//TB: Starting to send video frame...
//TB: Frame 4 accepted with 1237500 pixels
//TB: Finished sending video frame.
//TB: Simulation finished.
//$finish called from file "main_testbench.v", line 253.
//$finish at simulation time          49500972000
//           V C S   S i m u l a t i o n   R e p o r t 
//Time: 49500972000 ps
//CPU Time:     13.460 seconds;       Data structure size:   0.0Mb
//Thu Dec  4 16:36:58 2025
//-----------------------------------------------------------------

