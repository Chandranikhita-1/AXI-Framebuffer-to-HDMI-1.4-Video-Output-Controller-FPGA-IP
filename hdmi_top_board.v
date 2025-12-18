`timescale 1ns/1ps

module hdmi_top_board (
    // Board-level ports only
    input  sys_clk_p,
    input  sys_clk_n,
    input  sys_rst_n,

    output tmds_clk_p,
    output tmds_clk_n,
    output tmds_ch0_p,
    output tmds_ch0_n,
    output tmds_ch1_p,
    output tmds_ch1_n,
    output tmds_ch2_p,
    output tmds_ch2_n,

    output scl_ddc,
    inout  sda_ddc,
    input  hpd_in,
    output [9:0] led,
    output [3:0] seg_an,
    output [7:0] seg_cat
);

    // Simple internal clocks for AXI domains (for now use sys_clk_p)
    wire axi_clk    = sys_clk_p;
    wire axi_resetn = sys_rst_n;

    // Tie off AXI4-Lite interface (no real PS connected yet)
    wire [31:0] S_AXI_WDATA   = 32'd0;
    wire [31:0] S_AXI_RDATA;
    wire [7:0]  S_AXI_AWADDR  = 8'd0;
    wire [7:0]  S_AXI_ARADDR  = 8'd0;
    wire [3:0]  S_AXI_WSTRB   = 4'hF;
    wire [2:0]  S_AXI_AWPROT  = 3'd0;
    wire [2:0]  S_AXI_ARPROT  = 3'd0;
    wire [1:0]  S_AXI_BRESP;
    wire [1:0]  S_AXI_RRESP;
    wire        S_AXI_AWVALID = 1'b0;
    wire        S_AXI_AWREADY;
    wire        S_AXI_WVALID  = 1'b0;
    wire        S_AXI_WREADY;
    wire        S_AXI_BVALID;
    wire        S_AXI_BREADY  = 1'b0;
    wire        S_AXI_ARVALID = 1'b0;
    wire        S_AXI_ARREADY;
    wire        S_AXI_RVALID;
    wire        S_AXI_RREADY  = 1'b0;

    // Tie off AXI4-Stream video input (no real source yet)
    wire [23:0] M_AXIS_TDATA  = 24'd0;
    wire        M_AXIS_TVALID = 1'b0;
    wire        M_AXIS_TLAST  = 1'b0;
    wire        M_AXIS_TREADY;

    hdmi_top #(
        .C_S_AXI_DATA_WIDTH (32),
        .C_S_AXI_ADDR_WIDTH (8),
        .C_M_AXIS_TDATA_WIDTH (24)
    ) u_hdmi_top (
        .sys_clk_p       (sys_clk_p),
        .sys_clk_n       (sys_clk_n),
        .sys_rst_n       (sys_rst_n),

        .S_AXI_ACLK      (axi_clk),
        .S_AXI_ARESETN   (axi_resetn),
        .S_AXI_AWADDR    (S_AXI_AWADDR),
        .S_AXI_AWPROT    (S_AXI_AWPROT),
        .S_AXI_AWVALID   (S_AXI_AWVALID),
        .S_AXI_AWREADY   (S_AXI_AWREADY),
        .S_AXI_WDATA     (S_AXI_WDATA),
        .S_AXI_WSTRB     (S_AXI_WSTRB),
        .S_AXI_WVALID    (S_AXI_WVALID),
        .S_AXI_WREADY    (S_AXI_WREADY),
        .S_AXI_BRESP     (S_AXI_BRESP),
        .S_AXI_BVALID    (S_AXI_BVALID),
        .S_AXI_BREADY    (S_AXI_BREADY),
        .S_AXI_ARADDR    (S_AXI_ARADDR),
        .S_AXI_ARPROT    (S_AXI_ARPROT),
        .S_AXI_ARVALID   (S_AXI_ARVALID),
        .S_AXI_ARREADY   (S_AXI_ARREADY),
        .S_AXI_RDATA     (S_AXI_RDATA),
        .S_AXI_RRESP     (S_AXI_RRESP),
        .S_AXI_RVALID    (S_AXI_RVALID),
        .S_AXI_RREADY    (S_AXI_RREADY),

        .M_AXIS_ACLK     (axi_clk),
        .M_AXIS_ARESETN  (axi_resetn),
        .M_AXIS_TDATA    (M_AXIS_TDATA),
        .M_AXIS_TVALID   (M_AXIS_TVALID),
        .M_AXIS_TREADY   (M_AXIS_TREADY),
        .M_AXIS_TLAST    (M_AXIS_TLAST),

        .tmds_clk_p      (tmds_clk_p),
        .tmds_clk_n      (tmds_clk_n),
        .tmds_ch0_p      (tmds_ch0_p),
        .tmds_ch0_n      (tmds_ch0_n),
        .tmds_ch1_p      (tmds_ch1_p),
        .tmds_ch1_n      (tmds_ch1_n),
        .tmds_ch2_p      (tmds_ch2_p),
        .tmds_ch2_n      (tmds_ch2_n),

        .scl_ddc         (scl_ddc),
        .sda_ddc         (sda_ddc),
        .hpd_in          (hpd_in)
    );
    reg [15:0] seg_counter;

   always @(posedge axi_clk or negedge axi_resetn) begin
    if (!axi_resetn)
        seg_counter <= 16'h0000;
    else
        seg_counter <= seg_counter + 1;
   end

   seven_seg_4digit u_sevenseg (
    .clk    (axi_clk),      // or sys_clk_p if that's your main clock
    .led  (led),   // active-low reset
    .value  (seg_counter),  // or some internal value you care about
    .seg_an (seg_an),
    .seg_cat(seg_cat)
    );
    assign led = seg_counter[9:0]; 
endmodule
