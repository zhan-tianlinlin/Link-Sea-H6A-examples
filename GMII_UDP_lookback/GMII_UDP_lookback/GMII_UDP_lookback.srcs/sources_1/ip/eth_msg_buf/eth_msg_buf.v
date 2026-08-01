// synopsys translate_off
`timescale 1 ps / 1 ps
// synopsys translate_on
module eth_msg_buf (
	clock,
	data,
	rdreq,
	wrreq,
	empty,
	full,
	usedw,
	q
	);

	input    clock;
	input    [111:0]    data;
	input    rdreq;
	input    wrreq;
	output    empty;
	output    full;
	output    [4:0]    usedw;
	output    [111:0]    q;

	scfifo    scfifo (
		.clock (clock),
		.sclr (),
		.wrreq (wrreq),
		.aclr (),
		.data (data),
		.rdreq (rdreq),
		.usedw (usedw),
		.empty (empty),
		.full (full),
		.q (q),
		.almost_empty (),
		.almost_full ()
	);

	defparam
		scfifo.add_ram_output_register = "ON",
		scfifo.intended_device_family = "Stratix",
		scfifo.lpm_hint = "RAM_BLOCK_TYPE=M4K",
		scfifo.lpm_numwords = 32,
		scfifo.lpm_showahead = "OFF",
		scfifo.lpm_type = "scfifo",
		scfifo.lpm_width = 112,
		scfifo.lpm_widthu = 5,
		scfifo.overflow_checking = "ON",
		scfifo.underflow_checking = "ON",
		scfifo.use_eab = "ON";
endmodule