/*---------------------------------------------------------------------------------------------------------
Name		:tb_axi_lite_slave.v
Author		:Amritha Bhargavi Utla
Student ID	:018399641
Description	:Test Bench for axi_lite_slave
----------------------------------------------------------------------------------------------------------*/
`timescale 1ns/1ps

module tb_axi_lite_slave;

    localparam integer C_S_AXI_DATA_WIDTH = 32;
    localparam integer C_S_AXI_ADDR_WIDTH = 8;

    // Clock/reset
    reg S_AXI_ACLK;
    reg S_AXI_ARESETN;

    // AXI write address channel
    reg  [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_AWADDR;
    reg  [2:0]                    S_AXI_AWPROT;
    reg                           S_AXI_AWVALID;
    wire                          S_AXI_AWREADY;

    // AXI write data channel
    reg  [C_S_AXI_DATA_WIDTH-1:0]    S_AXI_WDATA;
    reg  [C_S_AXI_DATA_WIDTH/8-1:0]  S_AXI_WSTRB;
    reg                              S_AXI_WVALID;
    wire                             S_AXI_WREADY;

    // AXI write response channel
    wire [1:0] S_AXI_BRESP;
    wire       S_AXI_BVALID;
    reg        S_AXI_BREADY;

    // AXI read address channel
    reg  [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_ARADDR;
    reg  [2:0]                    S_AXI_ARPROT;
    reg                           S_AXI_ARVALID;
    wire                          S_AXI_ARREADY;

    // AXI read data channel
    wire [C_S_AXI_DATA_WIDTH-1:0] S_AXI_RDATA;
    wire [1:0]                    S_AXI_RRESP;
    wire                          S_AXI_RVALID;
    reg                           S_AXI_RREADY;

    // Register outputs
    wire [C_S_AXI_DATA_WIDTH-1:0] ctrl_reg_out;
    wire [C_S_AXI_DATA_WIDTH-1:0] h_active_reg_out;
    wire [C_S_AXI_DATA_WIDTH-1:0] v_active_reg_out;
    wire [C_S_AXI_DATA_WIDTH-1:0] h_total_reg_out;
    wire [C_S_AXI_DATA_WIDTH-1:0] v_total_reg_out;
    wire [C_S_AXI_DATA_WIDTH-1:0] h_sync_start_reg_out;
    wire [C_S_AXI_DATA_WIDTH-1:0] h_sync_end_reg_out;
    wire [C_S_AXI_DATA_WIDTH-1:0] v_sync_start_reg_out;
    wire [C_S_AXI_DATA_WIDTH-1:0] v_sync_end_reg_out;

    // DUT instance
    axi_lite_slave #(
        .C_S_AXI_DATA_WIDTH (C_S_AXI_DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH (C_S_AXI_ADDR_WIDTH)
    ) dut (
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
        .ctrl_reg_out         (ctrl_reg_out),
        .h_active_reg_out     (h_active_reg_out),
        .v_active_reg_out     (v_active_reg_out),
        .h_total_reg_out      (h_total_reg_out),
        .v_total_reg_out      (v_total_reg_out),
        .h_sync_start_reg_out (h_sync_start_reg_out),
        .h_sync_end_reg_out   (h_sync_end_reg_out),
        .v_sync_start_reg_out (v_sync_start_reg_out),
        .v_sync_end_reg_out   (v_sync_end_reg_out)
    );

    // Clock generation
    initial 
    begin
        S_AXI_ACLK = 0;
        forever #5 S_AXI_ACLK = ~S_AXI_ACLK;
    end

    integer i;
    reg [31:0] rdata;

    initial 
    begin
        // Initialising
        S_AXI_ARESETN  = 1'b0;
        S_AXI_AWADDR   = '0;
        S_AXI_AWVALID  = 1'b0;
        S_AXI_AWPROT   = 3'b000;
        S_AXI_WDATA    = '0;
        S_AXI_WSTRB    = 4'h0;
        S_AXI_WVALID   = 1'b0;
        S_AXI_BREADY   = 1'b0;
        S_AXI_ARADDR   = '0;
        S_AXI_ARPROT   = 3'b000;
        S_AXI_ARVALID  = 1'b0;
        S_AXI_RREADY   = 1'b0;

        // Reset
        repeat (5) @(posedge S_AXI_ACLK);
        S_AXI_ARESETN = 1'b1;
	$display("Reset Done");
        
	@(posedge S_AXI_ACLK);

        // Writing into some registers
        axi_write(8'h00, 32'h0000_0001); // ctrl_reg_out
        axi_write(8'h04, 32'd1280);      // h_active
        axi_write(8'h08, 32'd720);       // v_active
        axi_write(8'h0C, 32'd1650);      // h_total
        axi_write(8'h10, 32'd750);       // v_total
        axi_write(8'h14, 32'd1390);      // h_sync_start
        axi_write(8'h18, 32'd1430);      // h_sync_end
        axi_write(8'h1C, 32'd725);       // v_sync_start
        axi_write(8'h20, 32'd730);       // v_sync_end

        // Read them back
        axi_read(8'h00, rdata);
        axi_read(8'h04, rdata);
        axi_read(8'h08, rdata);
        axi_read(8'h0C, rdata);
        axi_read(8'h10, rdata);
        axi_read(8'h14, rdata);
        axi_read(8'h18, rdata);
        axi_read(8'h1C, rdata);
        axi_read(8'h20, rdata);

        // Showing direct outputs
        $display("ctrl_reg_out         = 0x%0h", ctrl_reg_out);
        $display("h_active_reg_out     = %0d",   h_active_reg_out);
        $display("v_active_reg_out     = %0d",   v_active_reg_out);
        $display("h_total_reg_out      = %0d",   h_total_reg_out);
        $display("v_total_reg_out      = %0d",   v_total_reg_out);
        $display("h_sync_start_reg_out = %0d",   h_sync_start_reg_out);
        $display("h_sync_end_reg_out   = %0d",   h_sync_end_reg_out);
        $display("v_sync_start_reg_out = %0d",   v_sync_start_reg_out);
        $display("v_sync_end_reg_out   = %0d",   v_sync_end_reg_out);

        $display("Stopping tb_axi_lite_slave simulation.");
        $finish;
    end
    
     // Waveform Generation
    initial 
    begin
    	$dumpfile("tb_axi_lite_slave.vcd");
	$dumpvars();
	$dumpon;
    end



//-----------------AXI write task-------------------------
    task axi_write (
    input [C_S_AXI_ADDR_WIDTH-1:0] addr,
    input [C_S_AXI_DATA_WIDTH-1:0] data
    );
    begin
	@(posedge S_AXI_ACLK);
    	S_AXI_AWADDR  <= addr;
    	S_AXI_AWVALID <= 1'b1;
    	S_AXI_AWPROT  <= 3'b000;

    	S_AXI_WDATA   <= data;
    	S_AXI_WSTRB   <= {C_S_AXI_DATA_WIDTH/8{1'b1}};
    	S_AXI_WVALID  <= 1'b1;

    	//Address handshake
    	wait (S_AXI_AWREADY);          // slave accepts address
    	@(posedge S_AXI_ACLK);
    	S_AXI_AWVALID <= 1'b0;

    	//Data handshake
    	wait (S_AXI_WREADY);           // slave accepts data
    	@(posedge S_AXI_ACLK);
    	S_AXI_WVALID <= 1'b0;

    	//Response handshake
    	S_AXI_BREADY <= 1'b1;
    	wait (S_AXI_BVALID);
    	@(posedge S_AXI_ACLK);
    	S_AXI_BREADY <= 1'b0;	    
		    
        $display("AXI WRITE: addr=0x%0h data=0x%0h, BRESP = 0x%d",$time,addr, data, S_AXI_BRESP);
	             
     end
     endtask
    
//----------------------------- AXI read task------------------------
    task axi_read (
        input  [C_S_AXI_ADDR_WIDTH-1:0] addr,
        output [C_S_AXI_DATA_WIDTH-1:0] data
    );
    begin
        @(posedge S_AXI_ACLK);
        S_AXI_ARADDR  <= addr;
        S_AXI_ARVALID <= 1'b1;
        S_AXI_ARPROT  <= 3'b000;

        // Wait for ARREADY
        wait (S_AXI_ARREADY);
        @(posedge S_AXI_ACLK);
        S_AXI_ARVALID <= 1'b0;

        // Wait for read data
        S_AXI_RREADY <= 1'b1;
        wait (S_AXI_RVALID);
        data = S_AXI_RDATA;
        @(posedge S_AXI_ACLK);
        S_AXI_RREADY <= 1'b0;

        $display("AXI READ  addr=0x%0h data=0x%0h, RRESP=0x%d",$time, addr, data, S_AXI_RRESP);
    end
    endtask

endmodule


//--------------------------------OUTPUTS--------------------------------------
//Reset Done
//AXI WRITE: addr=0x5f data=0x0, BRESP = 0x         10
//AXI WRITE: addr=0x87 data=0x4, BRESP = 0x      12800
//AXI WRITE: addr=0xaf data=0x8, BRESP = 0x       7200
//AXI WRITE: addr=0xd7 data=0xc, BRESP = 0x      16500
//AXI WRITE: addr=0xff data=0x10, BRESP = 0x       7500
//AXI WRITE: addr=0x127 data=0x14, BRESP = 0x      13900
//AXI WRITE: addr=0x14f data=0x18, BRESP = 0x      14300
//AXI WRITE: addr=0x177 data=0x1c, BRESP = 0x       7250
//AXI WRITE: addr=0x19f data=0x20, BRESP = 0x       7300
//AXI READ  addr=0x1bd data=0x0, RRESP=0x         10
//AXI READ  addr=0x1db data=0x4, RRESP=0x      12800
//AXI READ  addr=0x1f9 data=0x8, RRESP=0x       7200
//AXI READ  addr=0x217 data=0xc, RRESP=0x      16500
//AXI READ  addr=0x235 data=0x10, RRESP=0x       7500
//AXI READ  addr=0x253 data=0x14, RRESP=0x      13900
//AXI READ  addr=0x271 data=0x18, RRESP=0x      14300
//AXI READ  addr=0x28f data=0x1c, RRESP=0x       7250
//AXI READ  addr=0x2ad data=0x20, RRESP=0x       7300
//ctrl_reg_out         = 0x1
//h_active_reg_out     = 1280
//v_active_reg_out     = 720
//h_total_reg_out      = 1650
//v_total_reg_out      = 750
//h_sync_start_reg_out = 1390
//h_sync_end_reg_out   = 1430
//v_sync_start_reg_out = 725
//v_sync_end_reg_out   = 730
//Stopping tb_axi_lite_slave simulation.
//-----------------------------------------------------------------------------
