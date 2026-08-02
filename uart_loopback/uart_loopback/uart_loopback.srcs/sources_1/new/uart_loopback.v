////////////////////////////////////////////////////////////////////////
// 代码借鉴于野火，鲁迅说的好：拿来主义。  说到这里，踩两脚eHiway
// eHiway的引脚表中tx和rx是反的，不知道改了没有，如果没改，你可以骂了
// uart1： rx接H6    tx接H4
// uart2： rx接D2	tx接H5
// 这个案例我用的是uart1
////////////////////////////////////////////////////////////////////////
module  uart_loopback
(
    input   wire    sys_clk     ,   //系统时钟50MHz
    input   wire    sys_rst_n   ,   //全局复位
    input   wire    rx          ,   //串口接收数据

    output  wire    tx              //串口发送数据
);

//********************************************************************//
//****************** Parameter and Internal Signal *******************//
//********************************************************************//
//parameter define
parameter   UART_BPS    =   14'd9600        ,   //比特率
            CLK_FREQ    =   26'd50_000_000  ;   //时钟频率

//wire  define
wire    [7:0]   po_data;
wire            po_flag;

//********************************************************************//
//*************************** Instantiation **************************//
//********************************************************************//
//------------------------ uart_rx_inst ------------------------
uart_rx
#(
    .UART_BPS    (UART_BPS  ),  //串口波特率
    .CLK_FREQ    (CLK_FREQ  )   //时钟频率
)
uart_rx_inst
(
    .sys_clk    (sys_clk    ),  //input             sys_clk
    .sys_rst_n  (sys_rst_n  ),  //input             sys_rst_n
    .rx         (rx         ),  //input             rx
            
    .po_data    (po_data    ),  //output    [7:0]   po_data
    .po_flag    (po_flag    )   //output            po_flag
);

//------------------------ uart_tx_inst ------------------------
uart_tx
#(
    .UART_BPS    (UART_BPS  ),  //串口波特率
    .CLK_FREQ    (CLK_FREQ  )   //时钟频率
)
uart_tx_inst
(
    .sys_clk    (sys_clk    ),  //input             sys_clk
    .sys_rst_n  (sys_rst_n  ),  //input             sys_rst_n
    .pi_data    (po_data    ),  //input     [7:0]   pi_data
    .pi_flag    (po_flag    ),  //input             pi_flag
                
    .tx         (tx         )   //output            tx
);

endmodule
