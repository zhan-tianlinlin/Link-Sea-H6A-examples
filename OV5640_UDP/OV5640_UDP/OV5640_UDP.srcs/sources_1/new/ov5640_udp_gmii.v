`timescale 1ns/1ps

module ov5640_hdmi_top (
    input  wire        sys_clk,
    input  wire        sys_rst_n,

    input  wire        ov5640_pclk,
    input  wire        ov5640_vsync,
    input  wire        ov5640_href,
    input  wire [7:0]  ov5640_data,

    output wire        ov5640_rst_n,
    output wire        ov5640_pwdn,
    output wire        sccb_scl,
    inout  wire        sccb_sda,
    output wire        ov5640_xclk,

    output wire        gtxclk,
    output wire [7:0]  gmii_txd,
    output wire        gmii_txen,
    output wire        eth_reset_n
);

//====================================================
// 参数定义
//====================================================

parameter IMAGE_WIDTH  = 1280;
parameter IMAGE_HEIGHT = 720;

parameter DST_MAC  = 48'hC8_A3_62_E2_75_5E;
parameter SRC_MAC  = 48'h00_0A_35_01_FE_C0;
parameter DST_IP   = 32'hC0_A8_00_03;
parameter SRC_IP   = 32'hC0_A8_00_02;
parameter DST_PORT = 16'd6102;
parameter SRC_PORT = 16'd5000;

//====================================================
// 时钟与复位
//====================================================

wire loc_clk125m;
wire pll1_locked;
wire pll2_locked;
wire rst_n;

//====================================================
// OV5640采集信号
//====================================================

wire        cfg_done;
wire        sys_init_done;
wire        image_data_hs;
wire        ov5640_wr_en;
wire [15:0] ov5640_data_out;
wire [11:0] image_data_yaddr;

//====================================================
// UDP发送信号
//====================================================

wire       tx_en_pulse;
wire       tx_done;
wire       fifo_rd;
wire [7:0] fifo_dout;

//====================================================
// OV5640数据处理寄存器
//====================================================

reg        image_data_hs_dly1;
reg [15:0] image_data_dly1;
reg        image_data_valid_dly1;
reg [15:0] pixel_data;
reg        pixel_data_valid;

//====================================================
// 复位与控制
//====================================================

assign rst_n = sys_rst_n & pll1_locked & pll2_locked;

assign sys_init_done = cfg_done;

assign ov5640_rst_n = rst_n;
assign ov5640_pwdn  = 1'b0;

assign eth_reset_n = rst_n;

//====================================================
// PLL1：生成GMII 125MHz时钟
// 当前工程clk_pll_1的c0为125MHz
//====================================================

clk_pll_1 clk_gen_inst (
    .areset(~sys_rst_n),
    .inclk0(sys_clk),
    .c0(loc_clk125m),
    .locked(pll1_locked)
);

//====================================================
// PLL2：生成OV5640 24MHz时钟
// 当前工程clk_pll_2的c1为24MHz
//====================================================

clk_pll_2 clk_gen_inst2 (
    .areset(~sys_rst_n),
    .inclk0(sys_clk),
    .c0(clk_25m),
    .c1(ov5640_xclk),
    .locked(pll2_locked)
);

//====================================================
// OV5640配置与采集   ov5640初始化时钟用25M，用系统时钟会黑屏
//====================================================

ov5640_top ov5640_top_inst (
    .sys_clk(clk_25m),
    .sys_rst_n(rst_n),
    .sys_init_done(sys_init_done),

    .ov5640_pclk(ov5640_pclk),
    .ov5640_href(ov5640_href),
    .ov5640_vsync(ov5640_vsync),
    .ov5640_data(ov5640_data),

    .cfg_done(cfg_done),
    .sccb_scl(sccb_scl),
    .sccb_sda(sccb_sda),

    .ov5640_wr_en(ov5640_wr_en),
    .ov5640_data_out(ov5640_data_out),

    .image_data_hs(image_data_hs),
    .image_data_vs(),
    .x_addr(),
    .y_addr(image_data_yaddr)
);

//====================================================
// OV5640图像数据处理
//
// 每个UDP包：
// 2字节行号 + 1280个RGB565像素
//
// 每行数据长度：
// 2 + 1280 * 2 = 2562字节
//====================================================

always @(posedge ov5640_pclk or negedge rst_n) begin
    if (!rst_n) begin
        image_data_hs_dly1    <= 1'b0;
        image_data_dly1       <= 16'd0;
        image_data_valid_dly1 <= 1'b0;
    end
    else begin
        image_data_hs_dly1    <= image_data_hs;
        image_data_dly1       <= ov5640_data_out;
        image_data_valid_dly1 <= ov5640_wr_en;
    end
end

always @(posedge ov5640_pclk or negedge rst_n) begin
    if (!rst_n) begin
        pixel_data <= 16'd0;
    end
    else if (!image_data_hs_dly1 && image_data_hs) begin
        if (image_data_yaddr != 12'd0)
            pixel_data <= {4'd0, image_data_yaddr - 1'b1};
        else
            pixel_data <= 16'd0;
    end
    else if (image_data_valid_dly1) begin
        pixel_data <= image_data_dly1;
    end
end

always @(posedge ov5640_pclk or negedge rst_n) begin
    if (!rst_n) begin
        pixel_data_valid <= 1'b0;
    end
    else if (!image_data_hs_dly1 && image_data_hs) begin
        pixel_data_valid <= 1'b1;
    end
    else if (image_data_valid_dly1) begin
        pixel_data_valid <= 1'b1;
    end
    else begin
        pixel_data_valid <= 1'b0;
    end
end

//====================================================
// 以太网发送FIFO控制
//====================================================

eth_tx_ctrl #(
    .PAYLOAD_DATA_BYTE(2),
    .PAYLOAD_LENGTH(IMAGE_WIDTH + 1)
) eth_tx_ctrl_inst (
    .reset_p(~rst_n),
    .clk(ov5640_pclk),
    .data_i({pixel_data[7:0], pixel_data[15:8]}),
    .data_valid_i(pixel_data_valid),
    .eth_txfifo_rd_clk(loc_clk125m),
    .tx_en_pulse(tx_en_pulse),
    .tx_done(tx_done),
    .eth_txfifo_rden(fifo_rd),
    .eth_txfifo_dout(fifo_dout)
);

//====================================================
// UDP GMII发送模块
//====================================================

eth_udp_tx_gmii eth_udp_tx_gmii_inst (
    .clk125m(loc_clk125m),
    .reset_p(~rst_n),
    .tx_en_pulse(tx_en_pulse),
    .tx_done(tx_done),

    .dst_mac(DST_MAC),
    .src_mac(SRC_MAC),
    .dst_ip(DST_IP),
    .src_ip(SRC_IP),
    .dst_port(DST_PORT),
    .src_port(SRC_PORT),

    .data_length(IMAGE_WIDTH * 2 + 2),

    .payload_req_o(fifo_rd),
    .payload_dat_i(fifo_dout),

    .gmii_tx_clk(gtxclk),
    .gmii_txen(gmii_txen),
    .gmii_txd(gmii_txd)
);

endmodule