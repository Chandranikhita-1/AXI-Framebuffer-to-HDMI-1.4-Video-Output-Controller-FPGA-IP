/*---------------------------------------------------------------------------------------------------------
Name		:axi_lite_slave.v
Author		:Nikitha 
Student ID	:019109103
Description	:This module is for configuring the HDMI controller. This module provides read/write access
		 to video timing parameters and control flags.

----------------------------------------------------------------------------------------------------------*/
`timescale 1ns / 1ps
module axi_lite_slave
#(
    parameter integer C_S_AXI_DATA_WIDTH    = 32,
    parameter integer C_S_AXI_ADDR_WIDTH    = 8
)
(
    // Global signals
    input  reg                                        S_AXI_ACLK,
    input  reg                                        S_AXI_ARESETN,

    // AXI4-Lite Slave Interface (standard AXI signals)
    input  reg [C_S_AXI_ADDR_WIDTH-1:0]               S_AXI_AWADDR,
    input  reg [2:0]                                  S_AXI_AWPROT,
    input  reg                                        S_AXI_AWVALID,
    output reg                                        S_AXI_AWREADY,
    input  reg [C_S_AXI_DATA_WIDTH-1:0]               S_AXI_WDATA,
    input  reg [C_S_AXI_DATA_WIDTH/8-1:0]             S_AXI_WSTRB,
    input  reg                                        S_AXI_WVALID,
    output reg                                        S_AXI_WREADY,
    output reg [1:0]                                  S_AXI_BRESP,
    output reg                                        S_AXI_BVALID,
    input  reg                                        S_AXI_BREADY,
    input  reg [C_S_AXI_ADDR_WIDTH-1:0]               S_AXI_ARADDR,
    input  reg [2:0]                                  S_AXI_ARPROT,
    input  reg                                        S_AXI_ARVALID,
    output reg                                        S_AXI_ARREADY,
    output reg [C_S_AXI_DATA_WIDTH-1:0]               S_AXI_RDATA,
    output reg [1:0]                                  S_AXI_RRESP,
    output reg                                        S_AXI_RVALID,
    input  reg                                        S_AXI_RREADY,

    // Outputs to control video timing parameters
    output reg [C_S_AXI_DATA_WIDTH-1:0]               ctrl_reg_out,        			// Control bits ([0] = enable, [1] = reset_vtg)
    output reg [C_S_AXI_DATA_WIDTH-1:0]               h_active_reg_out,
    output reg [C_S_AXI_DATA_WIDTH-1:0]               v_active_reg_out,
    output reg [C_S_AXI_DATA_WIDTH-1:0]               h_total_reg_out,
    output reg [C_S_AXI_DATA_WIDTH-1:0]               v_total_reg_out,
    output reg [C_S_AXI_DATA_WIDTH-1:0]               h_sync_start_reg_out,
    output reg [C_S_AXI_DATA_WIDTH-1:0]               h_sync_end_reg_out,
    output reg [C_S_AXI_DATA_WIDTH-1:0]               v_sync_start_reg_out,
    output reg [C_S_AXI_DATA_WIDTH-1:0]               v_sync_end_reg_out
);

    // Internal AXI Lite State Machine States
    typedef enum reg [2:0] {
        IDLE_S,
        WRITE_ADDR_S,
        WRITE_DATA_S,
        WRITE_RESP_S,
        READ_ADDR_S,
        READ_DATA_S
    } axi_state_t;

    axi_state_t axi_current_state, axi_next_state;

    // Internal AXI signals
    reg [C_S_AXI_ADDR_WIDTH-1:0]      axi_awaddr_q;
    reg [C_S_AXI_ADDR_WIDTH-1:0]      axi_araddr_q;
    reg [C_S_AXI_DATA_WIDTH-1:0]      axi_wdata_q;

    reg                               axi_awready_i;
    reg                               axi_wready_i;
    reg                               axi_bvalid_i;
    reg [1:0]                         axi_bresp_i;
    reg                               axi_arready_i;
    reg                               axi_rvalid_i;
    reg [1:0]                         axi_rresp_i;
    reg [C_S_AXI_DATA_WIDTH-1:0]      axi_rdata_i;

    // Registers controlled by AXI-Lite
    reg [C_S_AXI_DATA_WIDTH-1:0]      ctrl_reg_q;
    reg [C_S_AXI_DATA_WIDTH-1:0]      h_active_reg_q;
    reg [C_S_AXI_DATA_WIDTH-1:0]      v_active_reg_q;
    reg [C_S_AXI_DATA_WIDTH-1:0]      h_total_reg_q;
    reg [C_S_AXI_DATA_WIDTH-1:0]      v_total_reg_q;
    reg [C_S_AXI_DATA_WIDTH-1:0]      h_sync_start_reg_q;
    reg [C_S_AXI_DATA_WIDTH-1:0]      h_sync_end_reg_q;
    reg [C_S_AXI_DATA_WIDTH-1:0]      v_sync_start_reg_q;
    reg [C_S_AXI_DATA_WIDTH-1:0]      v_sync_end_reg_q;

    // ------------------------------------------------------------------------
    // Register Assignments 
    // ------------------------------------------------------------------------

    assign ctrl_reg_out         = ctrl_reg_q;
    assign h_active_reg_out     = h_active_reg_q;
    assign v_active_reg_out     = v_active_reg_q;
    assign h_total_reg_out      = h_total_reg_q;
    assign v_total_reg_out      = v_total_reg_q;
    assign h_sync_start_reg_out = h_sync_start_reg_q;
    assign h_sync_end_reg_out   = h_sync_end_reg_q;
    assign v_sync_start_reg_out = v_sync_start_reg_q;
    assign v_sync_end_reg_out   = v_sync_end_reg_q;

    // ------------------------------------------------------------------------
    // AXI4-Lite State Machine
    // ------------------------------------------------------------------------
    always @(posedge S_AXI_ACLK or negedge S_AXI_ARESETN)
    begin
        if (!S_AXI_ARESETN)
	begin
            axi_current_state <= IDLE_S;
            axi_awaddr_q      <= '0;
            axi_araddr_q      <= '0;
            axi_wdata_q       <= '0;
            ctrl_reg_q        <= 32'h0000_0001;
            h_active_reg_q    <= 32'd1280;
            v_active_reg_q    <= 32'd720;
            h_total_reg_q     <= 32'd1650;
            v_total_reg_q     <= 32'd750;
            h_sync_start_reg_q<= 32'd1390;
            h_sync_end_reg_q  <= 32'd1430;
            v_sync_start_reg_q<= 32'd725;
            v_sync_end_reg_q  <= 32'd730;
        end
	else
	begin
            axi_current_state <= axi_next_state;
            if (S_AXI_AWVALID && axi_awready_i) axi_awaddr_q <= S_AXI_AWADDR;
            if (S_AXI_WVALID  && axi_wready_i)  axi_wdata_q  <= S_AXI_WDATA;
            if (S_AXI_ARVALID && axi_arready_i) axi_araddr_q <= S_AXI_ARADDR;

	    if(axi_current_state == WRITE_DATA_S && S_AXI_WVALID && axi_wready_i) 
	    begin
		case (axi_awaddr_q[7:0])
                        8'h00: ctrl_reg_q        <= S_AXI_WDATA;
                        8'h04: h_active_reg_q    <= S_AXI_WDATA;
                        8'h08: v_active_reg_q    <= S_AXI_WDATA;
                        8'h0C: h_total_reg_q     <= S_AXI_WDATA;
                        8'h10: v_total_reg_q     <= S_AXI_WDATA;
                        8'h14: h_sync_start_reg_q<= S_AXI_WDATA;
                        8'h18: h_sync_end_reg_q  <= S_AXI_WDATA;
                        8'h1C: v_sync_start_reg_q<= S_AXI_WDATA;
                        8'h20: v_sync_end_reg_q  <= S_AXI_WDATA;
                        default: ; 								         
		endcase
	    end
        end
    end

    always@(*)
    begin
        axi_next_state = axi_current_state;
        axi_awready_i  = 1'b0;
        axi_wready_i   = 1'b0;
        axi_bvalid_i   = 1'b0;
        axi_bresp_i    = 2'b00; 									// OKAY response
        axi_arready_i  = 1'b0;
        axi_rvalid_i   = 1'b0; 
        axi_rresp_i    = 2'b00; 									// OKAY response
        axi_rdata_i    = '0;

        case (axi_current_state)
            IDLE_S: begin
                if (S_AXI_AWVALID)
		begin
                    axi_awready_i = 1'b1;
                    axi_next_state = WRITE_DATA_S;
                end 
		else if (S_AXI_ARVALID)
		begin
                    axi_arready_i = 1'b1;
                    axi_next_state = READ_DATA_S;
                end
            end
            WRITE_DATA_S: begin
                axi_wready_i = 1'b1;
                if (S_AXI_WVALID)
		begin											// Write data to register based on axi_awaddr_q
                    axi_next_state = WRITE_RESP_S;
                end
            end
            WRITE_RESP_S: begin
                axi_bvalid_i = 1'b1;
                if (S_AXI_BREADY)
		begin
                    axi_next_state = IDLE_S;
                end
            end
            READ_DATA_S: begin
                axi_rvalid_i = 1'b1;									// Read data from register based on axi_araddr_q
                case (axi_araddr_q[7:0])
                    8'h00: axi_rdata_i = ctrl_reg_q;
                    8'h04: axi_rdata_i = h_active_reg_q;
                    8'h08: axi_rdata_i = v_active_reg_q;
                    8'h0C: axi_rdata_i = h_total_reg_q;
                    8'h10: axi_rdata_i = v_total_reg_q;
                    8'h14: axi_rdata_i = h_sync_start_reg_q;
                    8'h18: axi_rdata_i = h_sync_end_reg_q;
                    8'h1C: axi_rdata_i = v_sync_start_reg_q;
                    8'h20: axi_rdata_i = v_sync_end_reg_q;
                    default: axi_rdata_i = '0; 								// Return 0 for invalid addresses
                endcase

                if (S_AXI_RREADY)
		begin
                    axi_next_state = IDLE_S;
                end
            end
            default: axi_next_state = IDLE_S;
        endcase
    end

    // Assign AXI outputs
    assign S_AXI_AWREADY = axi_awready_i;
    assign S_AXI_WREADY  = axi_wready_i;
    assign S_AXI_BRESP   = axi_bresp_i;
    assign S_AXI_BVALID  = axi_bvalid_i;
    assign S_AXI_ARREADY = axi_arready_i;
    assign S_AXI_RDATA   = axi_rdata_i;
    assign S_AXI_RRESP   = axi_rresp_i;
    assign S_AXI_RVALID  = axi_rvalid_i;

endmodule
