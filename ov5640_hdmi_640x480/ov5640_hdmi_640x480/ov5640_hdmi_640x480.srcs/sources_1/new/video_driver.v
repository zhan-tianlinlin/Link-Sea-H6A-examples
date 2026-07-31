// 根据时钟信号生成HDMI视频的像素坐标(x,y)和行场同步信号
module video_driver(
    input           pixel_clk,      // 像素时钟
    input           sys_rst_n,      // 复位信号（低有效）
    
    // RGB接口
    output          video_hs,       // 行同步信号（低有效）
    output          video_vs,       // 场同步信号（低有效）
    output          video_de,       // 数据有效使能
    output [15:0]   video_rgb,      // RGB565像素数据
    output reg      data_req,       // 像素数据请求信号
    
    input  [15:0]   pixel_data,     // 输入的像素数据
    output reg [10:0] pixel_xpos,   // 当前像素X坐标 (0~639)
    output reg [10:0] pixel_ypos    // 当前像素Y坐标 (0~479)
);

// 640x480@60Hz 时序参数 (25.175MHz像素时钟)
parameter H_SYNC   = 11'd96;    // 行同步脉冲
parameter H_BACK   = 11'd48;    // 行后肩
parameter H_DISP   = 11'd640;   // 行有效像素
parameter H_FRONT  = 11'd16;    // 行前肩
parameter H_TOTAL  = 11'd800;   // 行总周期

parameter V_SYNC   = 11'd2;     // 场同步脉冲
parameter V_BACK   = 11'd33;    // 场后肩
parameter V_DISP   = 11'd480;   // 场有效行
parameter V_FRONT  = 11'd10;    // 场前肩
parameter V_TOTAL  = 11'd525;   // 场总周期

// 定义关键边界位置（预计算）
localparam H_START = H_SYNC;                     // 行有效区起始点
localparam H_END   = H_SYNC + H_BACK + H_DISP;   // 行有效区结束点 (96+48+640=784)
localparam V_START = V_SYNC;                     // 场有效区起始点
localparam V_END   = V_SYNC + V_BACK + V_DISP;   // 场有效区结束点 (2+33+480=515)

// 内部计数器
reg [10:0] cnt_h;  // 行计数器 (0~799)
reg [10:0] cnt_v;  // 场计数器 (0~524)

// 生成同步信号
assign video_hs = (cnt_h < H_SYNC) ? 1'b0 : 1'b1;  // 行同步（低脉冲有效）
assign video_vs = (cnt_v < V_SYNC) ? 1'b0 : 1'b1;  // 场同步（低脉冲有效）
assign video_de = (cnt_h >= H_START + H_BACK) &&  // 数据有效使能
                 (cnt_h <  H_END) &&
                 (cnt_v >= V_START + V_BACK) &&
                 (cnt_v <  V_END);
assign video_rgb = video_de ? pixel_data : 16'd0; // 有效区域输出像素数据

// 像素坐标计算
always @(posedge pixel_clk) begin
    // X坐标计算（在有效区提前2周期请求）
    pixel_xpos <= (cnt_h >= H_START + H_BACK - 2) && 
                  (cnt_h <  H_END - 2) ? 
                  cnt_h - (H_START + H_BACK - 2) : 11'd0;
    
    // Y坐标计算（从0开始计数）
    pixel_ypos <= (cnt_v >= V_START + V_BACK) && 
                  (cnt_v <  V_END) ? 
                  cnt_v - (V_START + V_BACK) : 11'd0;
end

// 像素数据请求信号（提前2周期）
always @(posedge pixel_clk or negedge sys_rst_n) begin
    if(!sys_rst_n) 
        data_req <= 1'b0;
    else 
        data_req <= ((cnt_h >= H_START + H_BACK - 2) && 
                    (cnt_h <  H_END - 2)) && 
                    ((cnt_v >= V_START + V_BACK) && 
                    (cnt_v <  V_END));
end

// 行计数器 (0 ~ H_TOTAL-1)
always @(posedge pixel_clk or negedge sys_rst_n) begin
    if (!sys_rst_n)
        cnt_h <= 11'd0;
    else
        cnt_h <= (cnt_h < H_TOTAL - 1) ? cnt_h + 1 : 11'd0;
end

// 场计数器 (每行结束时递增)
always @(posedge pixel_clk or negedge sys_rst_n) begin
    if (!sys_rst_n)
        cnt_v <= 11'd0;
    else if (cnt_h == H_TOTAL - 1)
        cnt_v <= (cnt_v < V_TOTAL - 1) ? cnt_v + 1 : 11'd0;
end

endmodule