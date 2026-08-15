/////////////////////////////////////////////////////////////////////////////////
// 这个是根据小梅哥的代码改的，赞美小梅哥
// 顺便再踩两脚eHiway，你问我为什么？就是想踩，一个例程也不给！ヽ(`Д??)ノ
// 我真得好好调教调教你了eHiway     (??`□??)?? ︵ ┻━┻
/////////////////////////////////////////////////////////////////////////////////
module eth_udp_loopback_gmii(
  input         reset_n,
  //eth_rx
  input         gmii_rx_clk,
  input  [7:0]  gmii_rxd,
  input         gmii_rxdv,
  //eth_tx
  output        gtxclk,
  output  [7:0] gmii_txd,
  output        gmii_txen,
  //eth_rst
  output        eth_reset_n,
  output [3:0]  led
);
parameter LOCAL_MAC  = 48'h00_0a_35_01_fe_c0;
parameter LOCAL_IP   = 32'hc0_a8_00_02;
parameter LOCAL_PORT = 16'd5000;
//eth_rx
wire        reset_p;
wire        clk125m;
wire [47:0] exter_mac;
wire [31:0] exter_ip;
wire [15:0] exter_port;
wire [15:0] rx_data_length;
wire        data_overflow;
wire [7:0]  rx_payload_dat;
wire        rx_payload_valid;
wire        rx_pkt_done;
wire        rx_pkt_err;
reg  [3:0]  pkt_right_cnt;
reg  [3:0]  pkt_err_cnt;
// LED command monitor: internal active-high, external active-low.
parameter [26:0] LED_ON_CYCLES = 27'd125_000_000;
reg  [7:0]  led_payload_byte;
reg         led_payload_seen;
reg  [3:0]  led_active;
reg  [26:0] led_timer;
//eth_tx
wire        tx_done;
wire        tx_en_pulse;
wire [47:0] tx_dst_mac;
wire [31:0] tx_dst_ip;
wire [15:0] tx_dst_port;
wire [15:0] tx_data_length;
wire [7:0]  tx_payload_dat;
wire        tx_payload_req;

//eth_msg_buf interface
wire        eth_msg_wr_en;
wire [111:0]eth_msg_din;
reg         eth_msg_rd_en;
wire [111:0]eth_msg_dout;
wire [4 : 0]eth_msg_dat_cnt;
reg         eth_msg_rd_en_dly1;
reg         eth_tx_state;  //1:tx  0:idle
//
  assign eth_reset_n = reset_n;
  assign led = ~led_active;
//  assign led = {pkt_err_cnt,pkt_right_cnt};
  assign reset_p = ~reset_n;

  always@(posedge clk125m or posedge reset_p)
  begin
    if(reset_p)
      pkt_right_cnt <= 4'd0;
    else if(~rx_pkt_err && rx_pkt_done)
      pkt_right_cnt <= pkt_right_cnt + 1'b1;
    else
      pkt_right_cnt <= pkt_right_cnt;
  end

  always@(posedge clk125m or posedge reset_p)
  begin
    if(reset_p)
      pkt_err_cnt <= 4'd0;
    else if(rx_pkt_err && rx_pkt_done)
      pkt_err_cnt <= pkt_err_cnt + 1'b1;
    else
      pkt_err_cnt <= pkt_err_cnt;  
  end

  //以太网接收
// Capture the one-byte UDP payload and display 00/01/02/03 for one second.
  // rx_pkt_done/rx_pkt_err are sampled with the same latency as the counters above.
  always@(posedge clk125m or posedge reset_p)
  begin
    if(reset_p)
    begin
      led_payload_byte <= 8'h00;
      led_payload_seen <= 1'b0;
      led_active       <= 4'b0000;
      led_timer        <= 27'd0;
    end
    else
    begin
      if(rx_payload_valid && !led_payload_seen)
      begin
        led_payload_byte <= rx_payload_dat;
        led_payload_seen <= 1'b1;
      end

      if(rx_pkt_done)
      begin
        led_payload_seen <= 1'b0;
        if(!rx_pkt_err && led_payload_seen)
        begin
          case(led_payload_byte)
            8'h00: begin led_active <= 4'b0001; led_timer <= LED_ON_CYCLES - 1'b1; end
            8'h01: begin led_active <= 4'b0010; led_timer <= LED_ON_CYCLES - 1'b1; end
            8'h02: begin led_active <= 4'b0100; led_timer <= LED_ON_CYCLES - 1'b1; end
            8'h03: begin led_active <= 4'b1000; led_timer <= LED_ON_CYCLES - 1'b1; end
            default: ;
          endcase
        end
      end
      else if(led_active != 4'b0000)
      begin
        if(led_timer == 27'd0)
          led_active <= 4'b0000;
        else
          led_timer <= led_timer - 1'b1;
      end
    end
  end

  // UDP receive instance.
  eth_udp_rx_gmii eth_udp_rx_gmii(
    .reset_p         (reset_p               ),

    .local_mac       (LOCAL_MAC             ),
    .local_ip        (LOCAL_IP              ),
    .local_port      (LOCAL_PORT            ),

    .clk125m_o       (clk125m               ),
    .exter_mac       (exter_mac             ),
    .exter_ip        (exter_ip              ),
    .exter_port      (exter_port            ),
    .rx_data_length  (rx_data_length        ),
    .data_overflow_i (data_overflow         ),
    .payload_valid_o (rx_payload_valid      ),
    .payload_dat_o   (rx_payload_dat        ),

    .one_pkt_done    (rx_pkt_done           ),
    .pkt_error       (rx_pkt_err            ),
    .debug_crc_check (                      ),

    .gmii_rx_clk     (gmii_rx_clk           ),
    .gmii_rxdv       (gmii_rxdv             ),
    .gmii_rxd        (gmii_rxd              )
  );

  //对以太网接收数据缓存
/*  eth_data_buf eth_data_buf (
    .clk   (clk125m          ), // input wire clk
    .din   (rx_payload_dat   ), // input wire [7 : 0] din
    .wr_en (rx_payload_valid ), // input wire wr_en
    .rd_en (tx_payload_req   ), // input wire rd_en
    .dout  (tx_payload_dat   ), // output wire [7 : 0] dout
    .full  (data_overflow    ), // output wire full
    .empty (                 )  // output wire empty
  );*/
  
  eth_data_buf eth_data_buf (
		.clock (clk125m),          	//input    clock
		.data 	(rx_payload_dat),  	//input    [7:0]    data
		.wrreq 	(rx_payload_valid),	//input    wrreq
		.rdreq 	(tx_payload_req),  	//input    rdreq
		.q 		(tx_payload_dat),   //output    [7:0]    q
		.full 	(data_overflow),    //output    full
		.empty 	()          		//output    empty
);
  //同时对报文中MAC、IP等消息数据缓存
  assign eth_msg_wr_en = rx_pkt_done;
  assign eth_msg_din   = {exter_mac,exter_ip,exter_port,rx_data_length};

/*  eth_msg_buf eth_msg_buf (
    .clk        (clk125m         ), // input wire clk
    .din        (eth_msg_din     ), // input wire [111 : 0] din
    .wr_en      (eth_msg_wr_en   ), // input wire wr_en
    .rd_en      (eth_msg_rd_en   ), // input wire rd_en
    .dout       (eth_msg_dout    ), // output wire [111 : 0] dout
    .full       (                ), // output wire full
    .empty      (                ), // output wire empty
    .data_count (eth_msg_dat_cnt )  // output wire [4 : 0] data_count
  );*/
  
	eth_msg_buf eth_msg_buf (
		.clock (clk125m),          	//input    clock
		.data (eth_msg_din),        //input    [111:0]    data
		.wrreq (eth_msg_wr_en),     //input    wrreq
		.rdreq (eth_msg_rd_en),     //input    rdreq
		.q (eth_msg_dout),          //output    [111:0]    q
		.full (),            		//output    full
		.empty (),          		//output    empty
		.usedw (eth_msg_dat_cnt)   	//output    [4:0]    usedw

	);

  always@(posedge clk125m or posedge reset_p)
  begin
    if(reset_p)
      eth_tx_state <= 1'b0;
    else if(tx_done)
      eth_tx_state <= 1'b0;
    else if(eth_msg_dat_cnt >0)
      eth_tx_state <= 1'b1;
    else
      eth_tx_state <= eth_tx_state;
  end

  always@(posedge clk125m or posedge reset_p)
  begin
    if(reset_p)
      eth_msg_rd_en <= 1'b0;
    else if((eth_tx_state == 1'b0)&&(eth_msg_dat_cnt >0))
      eth_msg_rd_en <= 1'b1;
    else
      eth_msg_rd_en <= 1'b0;
  end

  always@(posedge clk125m)
    eth_msg_rd_en_dly1 <= eth_msg_rd_en;

  assign tx_en_pulse    = eth_msg_rd_en_dly1;
  assign tx_dst_mac     = eth_msg_dout[111:64];
  assign tx_dst_ip      = eth_msg_dout[63:32];
  assign tx_dst_port    = eth_msg_dout[31:16];
  assign tx_data_length = eth_msg_dout[15:0];

  eth_udp_tx_gmii eth_udp_tx_gmii
  (
    .clk125m       (clk125m               ),
    .reset_p       (reset_p               ),

    .tx_en_pulse   (tx_en_pulse           ),
    .tx_done       (tx_done               ),

    .dst_mac       (tx_dst_mac            ),
    .src_mac       (LOCAL_MAC             ),  
    .dst_ip        (tx_dst_ip             ),
    .src_ip        (LOCAL_IP              ),  
    .dst_port      (tx_dst_port           ),
    .src_port      (LOCAL_PORT            ),

    .data_length   (tx_data_length        ),
    
    .payload_req_o (tx_payload_req        ),
    .payload_dat_i (tx_payload_dat        ),

    .gmii_tx_clk   (gtxclk                ),
    .gmii_txen     (gmii_txen             ),
    .gmii_txd      (gmii_txd              )
  );

endmodule