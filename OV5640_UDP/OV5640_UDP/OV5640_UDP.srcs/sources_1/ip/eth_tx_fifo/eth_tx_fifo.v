// synopsys translate_off
`timescale 1 ps / 1 ps
// synopsys translate_on
module eth_tx_fifo (
	aclr,
	rdclk,
	wrclk,
	data,
	rdreq,
	wrreq,
	rdusedw,
	wrfull,
	q
	);

	input    aclr;
	input    rdclk;
	input    wrclk;
	input    [15:0]    data;
	input    rdreq;
	input    wrreq;
	output    [7:0]    q;
	output    [12:0]    rdusedw;
	output    wrfull;

	dcfifo_mixed_inst_eth_tx_fifo dcfifo (
		.rdclk (rdclk),
		.wrreq (wrreq),
		.aclr (aclr),
		.data (data),
		.rdreq (rdreq),
		.wrclk (wrclk),
		.wrempty (),
		.wrfull (wrfull),
		.q (q),
		.rdempty (),
		.rdfull (),
		.wrusedw (),
		.rdusedw (rdusedw)
	);

	defparam
		dcfifo.add_ram_output_register = "ON",
		dcfifo.clocks_are_synchronized = "FALSE",
		dcfifo.intended_device_family = "Stratix",
		dcfifo.lpm_hint = "RAM_BLOCK_TYPE=M4K",
		dcfifo.lpm_numwords = 4096,
		dcfifo.lpm_showahead = "ON",
		dcfifo.lpm_type = "dcfifo",
		dcfifo.lpm_width = 16,
		dcfifo.lpm_widthu = 12,
		dcfifo.lpm_width_rd = 8,
		dcfifo.lpm_widthu_rd = 13,
		dcfifo.overflow_checking = "ON",
		dcfifo.underflow_checking = "ON",
		dcfifo.use_eab = "ON";
endmodule