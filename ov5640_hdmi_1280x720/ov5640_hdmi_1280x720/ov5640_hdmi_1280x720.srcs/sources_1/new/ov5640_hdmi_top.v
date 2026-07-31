`timescale  1ns/1ps

module ov5640_hdmi_top
(    
    input   wire      	sys_clk,      // 系统主时钟
    input   wire        sys_rst_n,    // 系统复位信号
    
    // OV5640摄像头接口
    input   wire        ov5640_pclk,  // 摄像头像素时钟
    input   wire        ov5640_vsync, // 摄像头场同步信号
    input   wire        ov5640_href,  // 摄像头行同步信号
    input   wire [7:0]  ov5640_data,  // 摄像头8位像素数据
    output  wire        ov5640_rst_n, // 摄像头复位
    output  wire        ov5640_pwdn,   // 摄像头省电模式
    output  wire        sccb_scl,     // SCCB协议时钟线
    inout   wire        sccb_sda,     // SCCB协议数据线
	output  wire        ov5640_xclk,  // 摄像头主时钟输出（24MHz）
    
    // SDRAM1接口（图像缓存）
    output  wire        sdram1_clk,    // SDRAM时钟（125MHz）
    output  wire        sdram1_cke,   // SDRAM时钟使能
    output  wire        sdram1_cs_n,  // SDRAM片选（低有效）
    output  wire        sdram1_ras_n, // 行地址选通（低有效）
    output  wire        sdram1_cas_n, // 列地址选通（低有效）
    output  wire        sdram1_we_n,  // 写使能（低有效）
    output  wire [1:0]  sdram1_ba,    // Bank选择地址
    output  wire [12:0] sdram1addr,   // 行列复用地址总线
    inout   wire [15:0] sdram1_dq,   // 16位双向数据总线
	
	
	// HDMI输出接口
    output  wire        ddc_scl,       // HDMI DDC配置时钟
    inout   wire        ddc_sda,      // HDMI DDC配置数据
    output  wire        hdmi_out_clk, // HDMI像素时钟
    output  wire        hdmi_out_hsync, // HDMI行同步
    output  wire        hdmi_out_vsync, // HDMI场同步
    output  wire [23:0] hdmi_out_rgb, // RGB888像素数据
    output  wire        hdmi_out_de   // HDMI数据使能信号


   
);


// hdmi水平分辨率参数：1280像素
parameter   H_PIXEL     =   24'd1280 ;   
parameter   V_PIXEL     =   24'd720; 
parameter   H_SIZE      =   1280;        // 图像宽度
parameter   V_SIZE      =   720;        // 图像高度   
// 当前像素的X坐标（水平位置）
wire  [10:0]  pixel_xpos_w;  
// 当前像素的Y坐标（垂直位置）
wire  [10:0]  pixel_ypos_w;  
// 处理后的16位RGB输出数据
wire  [15:0]  video_rgb;  
           
wire          clk_125m;       
wire          clk_125m_shift;       
wire          clk_25m;        
wire pll1_locked;  
wire pll2_locked;
wire          rst_n;          
// 摄像头初始化完成标志  
wire          cfg_done;       
// SDRAM写使能信号
wire          wr_en;          
// 写入SDRAM的数据 
wire [15:0]   wr_data;        
// SDRAM读使能信号    
wire          rd_en;          
// 从SDRAM读取的数据      
wire [15:0]   rd_data;        
// SDRAM1初始化完成标志
wire          sdram1_init_done;
// 系统初始化完成标志（SDRAM+摄像头）
wire          sys_init_done;

wire image_data_hs;
wire image_data_vs; 
       

        
// HDMI输出格式转换：将16位RGB565转换为24位RGB888
assign hdmi_out_rgb = {
    {video_rgb[15:11], video_rgb[13:11]},
    {video_rgb[10:5],  video_rgb[6:5]},
    {video_rgb[4:0],   video_rgb[2:0]}
};
// PLL双锁定状态合成（双PLL稳定标志）
assign locked = (pll1_locked & pll2_locked);
// 全局复位合成：系统复位信号与PLL锁定联合控制
assign rst_n = (sys_rst_n & locked);          
// 系统初始化完成条件：SDRAM1初始化完成 + 摄像头配置完成
assign sys_init_done = sdram1_init_done&cfg_done ;
// 摄像头硬件复位控制（永久高电平：解除复位）
assign ov5640_rst_n = 1'b1;
assign ov5640_pwdn = 1'b0;



clk_pll_1 clk_gen_inst(

    .areset     (~sys_rst_n     ),
    .inclk0     (sys_clk      ),
    .c0         (clk_125m       ),
    .c1         (clk_125m_shift ),
	.c2(clk_sdram_rd),
	.c3         (hdmi_out_clk  ),
    .locked     (pll1_locked    )
);

clk_pll_2 clk_gen_inst2(

    .areset     (~sys_rst_n     ),
    .inclk0     (sys_clk     ),
	.c0         (clk_25m),
	.c1         (ov5640_xclk),
    .locked     (pll2_locked  )
);

sil9134_dri inst_sil9134_dri (
	.clk           (clk_25m ),
	.rst_n         (rst_n		),
	.hdmi_cfg_done (	),
	.hdmi_cfg_scl  (ddc_scl 	),
	.hdmi_cfg_sda  (ddc_sda 	)
	);

//--------ov5640摄像头数据采集与拼接-------------//
wire [11:0]x_addr;
wire [11:0]y_addr;
wire ov5640_wr_en;
wire [15:0]ov5640_data_out;
ov5640_top  ov5640_top_inst(

    .sys_clk         (clk_25m  		),   
    .sys_rst_n       (rst_n         ),  
    .sys_init_done   (sys_init_done ),   

    .ov5640_pclk     (ov5640_pclk   ),   
    .ov5640_href     (ov5640_href   ),   
    .ov5640_vsync    (ov5640_vsync  ),  
    .ov5640_data     (ov5640_data   ),   

    .cfg_done        (cfg_done      ),   
    .sccb_scl        (sccb_scl      ),  
    .sccb_sda        (sccb_sda      ),
//======图像信号输出=============
    .ov5640_wr_en    (ov5640_wr_en         ),   
    .ov5640_data_out (ov5640_data_out       ),
	.image_data_hs(image_data_hs),
	.image_data_vs(image_data_vs),
	.x_addr(x_addr),
	.y_addr(y_addr)

);


assign wr_en = ov5640_wr_en;
assign wr_data = ov5640_data_out;
sdram_top  sdram1_top_inst(

    .ref_clk            (clk_125m     ),  
    .out_clk            (clk_125m_shift),  
    .rst_n          	(rst_n          ),
	
    .wr_clk     		(ov5640_pclk ),  
    .wr_en     			(wr_en  ),    
    .wr_data    		(wr_data ),  
    .wr_min_addr    	(24'd0          ),  
    .wr_max_addr    	(H_PIXEL*V_PIXEL),  
    .wr_len       		(10'd512        ), 
    .wr_load            (~rst_n         ),
	
    .rd_clk     		(clk_sdram_rd),  
    .rd_en     			(rd_en          ),  
    .rd_data    		(rd_data        ), 
    .rd_min_addr    	(24'd0          ), 
    .rd_max_addr    	(H_PIXEL*V_PIXEL),  
    .rd_len       		(10'd512        ), 
    .rd_load            (~rst_n         ),
	
    .sdram_read_valid   (1'b1           ),  
    .sdram_pingpang_en  (1'b1           ), 
	.sdram_init_done    (sdram1_init_done),
	
    .sdram_clk          (sdram1_clk      ), 
    .sdram_cke          (sdram1_cke      ),  
    .sdram_cs_n         (sdram1_cs_n     ),  
    .sdram_ras_n        (sdram1_ras_n    ),  
    .sdram_cas_n        (sdram1_cas_n    ),  
    .sdram_we_n         (sdram1_we_n     ),  
    .sdram_ba           (sdram1_ba       ),  
    .sdram_addr         (sdram1addr    ),  
    .sdram_data         (sdram1_dq       )  
);


//================================输出视频=================================	
video_driver  video_driver_inst(
    .pixel_clk      ( hdmi_out_clk ),
    .sys_rst_n      ( rst_n ),

    .video_hs       ( hdmi_out_hsync ),
    .video_vs       ( hdmi_out_vsync),
    .video_de       ( hdmi_out_de ),
    .video_rgb      ( video_rgb ),
	.data_req		(rd_en ),

    .pixel_xpos     ( pixel_xpos_w ),
    .pixel_ypos     ( pixel_ypos_w ),
	.pixel_data     (rd_data  )
);

endmodule
