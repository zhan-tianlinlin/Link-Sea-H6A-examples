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

// 1280x720@60Hz 时序参数 (74.25MHz像素时钟)	使用75m时钟
parameter H_SYNC    =   12'd40  ,   //行同步
          H_BACK    =   12'd220 ,   //行时序后沿
          H_DISP   =   12'd1280,   //行有效数据
          H_FRONT   =   12'd110 ,   //行时序前沿
          H_TOTAL   =   12'd1650;   //行扫描周期
parameter V_SYNC    =   12'd5   ,   //场同步
          V_BACK    =   12'd20  ,   //场时序后沿
          V_DISP   =   12'd720 ,   //场有效数据
          V_BOTTOM  =   12'd0   ,   //场时序下边框
          V_FRONT   =   12'd5   ,   //场时序前沿
          V_TOTAL   =   12'd750 ;   //场扫描周期


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
        data_req <= ((cnt_h >= H_START + H_BACK -2) && 
                    (cnt_h <  H_END -2)) && 
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