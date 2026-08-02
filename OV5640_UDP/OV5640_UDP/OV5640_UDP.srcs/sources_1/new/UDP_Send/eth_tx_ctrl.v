/////////////////////////////////////////////////////////////////////////////////
// Module Name   : eth_tx_ctrl
// Description   : 以太网发送数据控制模块
/////////////////////////////////////////////////////////////////////////////////

module eth_tx_ctrl
#(
  parameter PAYLOAD_DATA_BYTE = 2,
  parameter PAYLOAD_LENGTH    = 800
)
(
  input                            reset_p          ,

  input                            clk              ,
  input  [PAYLOAD_DATA_BYTE*8-1:0] data_i           ,
  input                            data_valid_i     ,

  input                            eth_txfifo_rd_clk,
  output reg                       tx_en_pulse      ,
  input                            tx_done          ,
  input                            eth_txfifo_rden  ,
  output    [7:0]                  eth_txfifo_dout  
);

localparam IDLE       = 4'b0001,
           TX_START   = 4'b0010,
           WAIT_DONE  = 4'b0100,
           DELAY      = 4'b1000;

localparam TX_DATA_BYTE = PAYLOAD_LENGTH * PAYLOAD_DATA_BYTE - 2'd2;

wire [12:0] rd_data_count;
reg  [3:0]  eth_interval_cnt;
reg  [3:0]  curr_state;
reg  [3:0]  next_state;

/*
  eth_tx_fifo eth_tx_fifo (
    .rst          (reset_p           ),  // input wire rst
    .wr_clk       (clk               ),  // input wire wr_clk
    .rd_clk       (eth_txfifo_rd_clk ),  // input wire rd_clk
    .din          (data_i            ),  // input wire [15 : 0] din
    .wr_en        (data_valid_i      ),  // input wire wr_en
    .rd_en        (eth_txfifo_rden   ),  // input wire rd_en
    .dout         (eth_txfifo_dout   ),  // output wire [7 : 0] dout
    .full         (                  ),  // output wire full
    .empty        (                  ),  // output wire empty
    .rd_data_count(rd_data_count     ),  // output wire [11 : 0] rd_data_count
    .wr_rst_busy  (                  ),  // output wire wr_rst_busy
    .rd_rst_busy  (                  )   // output wire rd_rst_busy
  );
*/
  eth_tx_fifo eth_tx_fifo (
		.aclr (reset_p),            //input    aclr
		.wrclk (clk),          //input    wrclk
		.rdclk (eth_txfifo_rd_clk),          //input    rdclk
		.data (data_i),            //input    [15:0]    data
		.rdreq (eth_txfifo_rden),          //input    rdreq
		.wrreq (data_valid_i),          //input    wrreq
		.rdusedw (rd_data_count),      //output    [12:0]    rdusedw
		.q (eth_txfifo_dout)                   //output    [7:0]    q
);

  always@(posedge eth_txfifo_rd_clk or posedge reset_p)
  begin
    if(reset_p)
      tx_en_pulse <= 1'b0;
    else if(curr_state == TX_START)
      tx_en_pulse <= 1'b1;
    else
      tx_en_pulse <= 1'b0;
  end

  always@(posedge eth_txfifo_rd_clk or posedge reset_p)
  begin
    if(reset_p)
      eth_interval_cnt <= 1'b0;
    else if(curr_state == DELAY)
      eth_interval_cnt <= eth_interval_cnt + 1'b1;
    else
      eth_interval_cnt <=  1'b0;
  end

//------------------------
//State machine
//------------------------
  always@(posedge eth_txfifo_rd_clk or posedge reset_p)
  begin
    if(reset_p)
      curr_state <= 1'b0;
    else
      curr_state <= next_state;
  end

  always@(*)
  begin
    case(curr_state)
      IDLE:
      begin
        if(rd_data_count >= TX_DATA_BYTE)
          next_state = TX_START;
        else
          next_state = curr_state;
      end
      
      TX_START: next_state = WAIT_DONE;
        
      WAIT_DONE:
      begin
        if(tx_done)
          next_state = DELAY;
        else
          next_state = curr_state;
      end

      DELAY:
      begin
        if(eth_interval_cnt == 4'd7)
          next_state = IDLE;
        else
          next_state = curr_state;
      end
      
      default: next_state = IDLE;
    endcase
  end
 
endmodule