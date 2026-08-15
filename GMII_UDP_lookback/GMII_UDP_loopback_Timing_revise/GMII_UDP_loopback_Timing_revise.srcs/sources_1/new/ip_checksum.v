/////////////////////////////////////////////////////////////////////////////////
// Module Name   : ip_checksum
// Description   : ip头部校验模块
/////////////////////////////////////////////////////////////////////////////////
module ip_checksum(
  input           clk            ,
  input           reset_p        ,

  input           cal_en         ,

  input   [3:0]   IP_ver         ,
  input   [3:0]   IP_hdr_len     ,
  input   [7:0]   IP_tos         ,
  input   [15:0]  IP_total_len   ,
  input   [15:0]  IP_id          ,
  input           IP_rsv         ,
  input           IP_df          ,
  input           IP_mf          ,
  input   [12:0]  IP_frag_offset ,
  input   [7:0]   IP_ttl         ,
  input   [7:0]   IP_protocol    ,
  input   [31:0]  src_ip         ,
  input   [31:0]  dst_ip         ,

  output  [15:0]  checksum       
);

  reg  [31:0]suma;
  wire [16:0]sumb;
  wire [15:0]sumc;

  // Keep every IPv4 header word explicitly 32 bits wide and add the
  // terms as a balanced tree to reduce the carry-chain depth.
  wire [31:0]sum_word0;
  wire [31:0]sum_word1;
  wire [31:0]sum_word2;
  wire [31:0]sum_word3;
  wire [31:0]sum_word4;
  wire [31:0]sum_word5;
  wire [31:0]sum_word6;
  wire [31:0]sum_word7;
  wire [31:0]sum_word8;
  wire [31:0]sum_pair0;
  wire [31:0]sum_pair1;
  wire [31:0]sum_pair2;
  wire [31:0]sum_pair3;
  wire [31:0]sum_level2_0;
  wire [31:0]sum_level2_1;
  wire [31:0]sum_level3;
  wire [31:0]sum_next;

  assign sum_word0 = {16'd0, IP_ver, IP_hdr_len, IP_tos};
  assign sum_word1 = {16'd0, IP_total_len};
  assign sum_word2 = {16'd0, IP_id};
  assign sum_word3 = {16'd0, IP_rsv, IP_df, IP_mf, IP_frag_offset};
  assign sum_word4 = {16'd0, IP_ttl, IP_protocol};
  assign sum_word5 = {16'd0, src_ip[31:16]};
  assign sum_word6 = {16'd0, src_ip[15:0]};
  assign sum_word7 = {16'd0, dst_ip[31:16]};
  assign sum_word8 = {16'd0, dst_ip[15:0]};

  assign sum_pair0 = sum_word0 + sum_word1;
  assign sum_pair1 = sum_word2 + sum_word3;
  assign sum_pair2 = sum_word4 + sum_word5;
  assign sum_pair3 = sum_word6 + sum_word7;
  assign sum_level2_0 = sum_pair0 + sum_pair1;
  assign sum_level2_1 = sum_pair2 + sum_pair3;
  assign sum_level3 = sum_level2_0 + sum_level2_1;
  assign sum_next = sum_level3 + sum_word8;

  always@(posedge clk or posedge reset_p)
  if(reset_p)
    suma <= 32'd0;
  else if(cal_en)
    suma <= sum_next;
  else
    suma <= suma;

  assign sumb = suma[31:16]+suma[15:0];
  assign sumc = sumb[16]+sumb[15:0];

  assign checksum = ~sumc;

endmodule
