# GMII_UDP_lookback

该项目实现以太网 UDP GMII 回环。

代码借鉴于小梅哥。使用前建议先阅读项目中的 PDF 文档，将电脑绑定到对应的 IP；另一个工具是用于发送数据包并进行回环测试的上位机。

具体用法可以去看 B 站上小梅哥的视频。

## 遇见的问题！！！

感觉代码完全没有毛病，IP 也正确设置了，但是却回环失败了，我懵逼了。

更懵逼的是，同样的程序，我都没改，前后下载居然一个能成功实现回环，一个不能成功。试了好多次，只成功了一次，也不知道是电脑的问题还是板卡的问题。

各位佬可以试着用一用

## 测试截图

![UDP GMII 回环测试截图](udp_loopback_result.png)

## 更新内容：GMII_UDP_loopback_Timing_revise

新文件夹名称：`GMII_UDP_loopback_Timing_revise`

相对于最初的 GMII UDP 回环工程，当前主要有以下改动：

1. **增加 4 路 LED 指示功能**

   - 顶层新增 `led[3:0]` 输出。
   - 接收 UDP 数据包的第一个有效字节。
   - `00/01/02/03` 分别点亮 `led[0]/led[1]/led[2]/led[3]`。
   - LED 低电平点亮，持续约 1 秒。
   - 增加了 `led_payload_byte`、`led_timer` 等监测逻辑。
   - 记得在上位机中把发送格式设置为 HEX，不然你数据都发错了，LED 肯定不亮。
   - <img width="1418" height="1157" alt="image" src="https://github.com/user-attachments/assets/210e367c-df95-49ce-bece-5a93340fede9" />


2. **优化 IP 校验和计算**

   - `ip_checksum.v` 中将原先串行累加形式改为平衡加法树。
   - 减少连续加法器和进位链造成的时序延迟。
   - 保持模块接口不变。

3. **优化发送端 IP 总长度计算**

   - 原来：
     ```verilog
     IP_total_len = udp_length + 20;
     ```
   - 现在：
     ```verilog
     IP_total_len = data_length + 28;
     ```
   - 减少一级组合加法逻辑。

4. **调整接收端校验时序**

   - IP 头校验结果的判断位置由 `cnt_udp_header == 4` 调整为 `cnt_udp_header == 2`，用于匹配当前校验和计算延迟。

5. **完善时序约束**

   - 增加 GMII 输入时钟约束。
   - 增加 `gmii_rxd/gmii_rxdv` 输入延迟约束。
   - 增加 GMII 输出延迟约束。
   - 建立 `gtxclk` 与 `gmii_rx_clk` 的生成时钟关系：

     ```tcl
     create_clock -name gmii_rx_clk -period 8.000 -waveform {0.000 4.000} [get_ports {gmii_rx_clk}]
     create_generated_clock -name gtxclk -source [get_ports {gmii_rx_clk}] -divide_by 1 [get_ports {gtxclk}]
     set_input_delay -clock [get_clocks {gmii_rx_clk}] -max 4.000 [get_ports {gmii_rxd[0] gmii_rxd[1] gmii_rxd[2] gmii_rxd[3] gmii_rxd[4] gmii_rxd[5] gmii_rxd[6] gmii_rxd[7] gmii_rxdv}] -add_delay
     set_input_delay -clock [get_clocks {gmii_rx_clk}] -min -1.000 [get_ports {gmii_rxd[0] gmii_rxd[1] gmii_rxd[2] gmii_rxd[3] gmii_rxd[4] gmii_rxd[5] gmii_rxd[6] gmii_rxd[7] gmii_rxdv}] -add_delay
     set_output_delay -clock [get_clocks {gtxclk}] -max 0.500 [get_ports {gmii_txd[0] gmii_txd[1] gmii_txd[2] gmii_txd[3] gmii_txd[4] gmii_txd[5] gmii_txd[6] gmii_txd[7] gmii_txen}] -add_delay
     set_output_delay -clock [get_clocks {gtxclk}] -min -1.500 [get_ports {gmii_txd[0] gmii_txd[1] gmii_txd[2] gmii_txd[3] gmii_txd[4] gmii_txd[5] gmii_txd[6] gmii_txd[7] gmii_txen}] -add_delay
     ```

6. **保持的内容**

   - GMII 接收、UDP 回环和发送模块的主要接口未改变。
   - MAC/IP/端口地址匹配逻辑未重新设计。
   - 模块之间的连接关系保持不变。

当前时序相比最初已有改善，但仍存在约 `-1.553 ns` 的建立时间违例，无伤大雅。

感觉回环率比较低，可能 20%-30% 吧，有时候又不灵，但相较于最初的版本，成功率已大幅上升！！！

### 主要问题

我对最初版本的代码进行过测试，发现时序并不好，FPGA 接收包头匹配都有错误。我原版本（第一个文件夹）留给你们了，你们可以自己试试。

现在的新版本解决了上述问题，FPGA 接收是绝对没有问题了（baka 的谜之自信）。你可以通过工具发送 `00/01/02/03` 数据进行测试，接收对应的数据成功后都会让对应的 LED 亮 1s。

可能是 FPGA 发送还有些问题吧，但是摄像头图像都能正常发给电脑，我也迷糊了，？骂骂 eHiway?

对于时灵时不灵的问题，我怀疑是我板子有问题，我也没有用其他板子测试过，就这样吧
