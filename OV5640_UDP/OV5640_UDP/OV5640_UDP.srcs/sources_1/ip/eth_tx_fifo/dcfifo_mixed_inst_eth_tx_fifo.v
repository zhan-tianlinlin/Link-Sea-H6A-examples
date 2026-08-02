//----------------------------------------------------------------------------
// dcfifo
//----------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module dcfifo_mixed_inst_eth_tx_fifo #(
	parameter					lpm_wr_gre_rd 			= 1		,
	parameter					lpm_wr_rd_div 			= 2		,
	parameter					lpm_width_large 		= 16	,		
	parameter					lpm_widthu_large 		= 12		,		
	parameter					lpm_numwords_large 		= 4096	,
	parameter					intended_device_family 	= "Stratix"	,
                                              	
	parameter					lpm_width 				= 16		,		
	parameter					lpm_widthu 				= 12		,		
	parameter					lpm_width_rd 			= 8	,		
	parameter					lpm_widthu_rd 			= 13		,			
	parameter					lpm_numwords 			= 4096	,			
	parameter					lpm_type 				= "dcfifo"				,
	parameter					lpm_hint 				= "RAM_BLOCK_TYPE=M4K"	,
	parameter					add_ram_output_register = "ON"	 ,		
	parameter					clocks_are_synchronized = "FALSE",		
	parameter					lpm_showahead 			= "ON"   ,			
	parameter					overflow_checking 		= "ON"	 ,		
	parameter					underflow_checking 	    = "ON"	 ,		
	parameter					use_eab 				= "ON"	 		
		
)(
	input	  					aclr					,
	input	  					wrclk					,
	input	  					wrreq					,
	input	[lpm_width-1:0]  	data					,	
	
	input	  					rdclk					,
	input	  					rdreq					,
	output	[lpm_width_rd-1:0]  	q						,	
	output	  					rdempty					,
	
	output	  					rdfull					,
	output	[lpm_widthu_rd-1:0]  rdusedw					,
	output	  					wrempty					,
	output	  					wrfull 					,
	output	[lpm_widthu-1:0]  	wrusedw					 
);

//---------------------------------------------------------
//   singal                                                 
//---------------------------------------------------------

	wire	    	  				s_fifo_wrreq		; 
	wire	[lpm_width_large-1:0]  	s_fifo_wdata		; 

	
	wire							s_wrfull			;	
	wire							s_wrempty			; 			
	wire	[lpm_widthu_large-1:0]  s_wrusedw			;	

		
	wire	    	  				s_fifo_rdreq		;
	wire	[lpm_width_large-1:0]  	s_fifo_rdata		;	

	
	wire							s_rdfull			;	
	wire							s_rdempty			; 	
	wire	[lpm_widthu_large-1:0]  s_rdusedw			;	


//---------------------------------------------------------
//   MIXED  write                           
//---------------------------------------------------------
          
    // select write less than read       
	generate
		if ( lpm_wr_rd_div == 1 ) begin
			 	
			assign s_fifo_wrreq = wrreq ; 
			assign s_fifo_wdata = data	;	
			assign wrusedw 	= s_wrusedw ; 																	
		end else if ( lpm_wr_gre_rd == 0 ) begin
						
			reg	    [7:0]  					r_fifo_wcnt			= 0 ; 
			wire	    	  				s_fifo_wr_flag		; 
			reg		[lpm_width_large-1:0]  	r_fifo_wdata		= 0; 
			
			always@(posedge wrclk or posedge aclr )      
				if(aclr)                                
					r_fifo_wcnt	  <= 'b0 ;              
				else if ( r_fifo_wcnt == lpm_wr_rd_div -1  && wrreq == 1 ) 
					r_fifo_wcnt  <= 'b0 ; 	
				else if ( wrreq == 1 ) 
					r_fifo_wcnt  <= r_fifo_wcnt + 1 ;	
		
			assign s_fifo_wr_flag = ((wrreq == 1 && r_fifo_wcnt == 0)|| r_fifo_wcnt > 0) ? 1'b1 : 1'b0 ;
		            
			always@(posedge wrclk or posedge aclr )      
				if(aclr)                                
					r_fifo_wdata  <= 'b0 ;              
				else if ( s_fifo_wr_flag == 1 && wrreq == 1 && (r_fifo_wcnt < lpm_wr_rd_div -1) ) 
					r_fifo_wdata  <= {r_fifo_wdata[(lpm_wr_rd_div-1)*lpm_width-1:0],data} ;	


			assign s_fifo_wrreq = ( aclr == 1 ) ? 1'b0 : 
						  		  ( s_fifo_wr_flag == 1 && wrreq == 1 && r_fifo_wcnt == lpm_wr_rd_div -1 ) ? 1'b1 : 1'b0;

			assign s_fifo_wdata = ( aclr == 1 ) ? {lpm_width_large{1'b0}} : 
						 		  ( s_fifo_wr_flag == 1 && wrreq == 1 && r_fifo_wcnt == lpm_wr_rd_div -1 ) ? {r_fifo_wdata[(lpm_wr_rd_div-1)*lpm_width-1:0],data}: {lpm_width_large{1'b0}}  ; 			 	

			assign wrusedw = ( lpm_wr_rd_div == 2 ) ? {s_wrusedw,1'b0} :
							 ( lpm_wr_rd_div == 4 ) ? {s_wrusedw,2'b0} :
							 ( lpm_wr_rd_div == 8 ) ? {s_wrusedw,3'b0} : s_wrusedw ; 		 //just support lpm_wr_rd_div <= 8 				


		end else begin 
			
			assign s_fifo_wrreq = wrreq ; 
			assign s_fifo_wdata = data	;	
			assign wrusedw 	= s_wrusedw ; 
																												
		end 
	endgenerate	
	

	assign wrempty	= s_wrempty	 ; 	 
	assign wrfull 	= s_wrfull 	 ; 	 
	    
          			
//---------------------------------------------------------
//   MIXED  read                                          
//---------------------------------------------------------
	
	generate
		if ( lpm_wr_rd_div == 1 ) begin	 	

			assign s_fifo_rdreq 	= rdreq 		; 
			assign q 				= s_fifo_rdata	;	
			assign rdempty			= s_rdempty	 	; 	
			assign rdusedw 			= s_rdusedw 	; 																		

		end else if ( lpm_wr_gre_rd == 0 ) begin	
					
			assign s_fifo_rdreq 	= rdreq 		; 
			assign q 				= s_fifo_rdata	;
			assign rdempty			= s_rdempty	 	; 	
			assign rdusedw 			= s_rdusedw 	; 																

		end else begin 	
		
			reg	    [7:0]  					r_fifo_rcnt			=0 ;   
			wire	    	  				s_fifo_rd_flag		   ;   
			reg	    	  					r_fifo_rd_flag		=0 ;   
			reg		[lpm_width_large-1:0]  	r_fifo_rdata 		=0 ;	
			reg	    	  					r_rd_last_flag		=0 ;   		
			wire	[lpm_widthu_rd-1:0]  	s_rdusedw_o 		   ;	
			wire	    	  				s_rdusedw_change	   ;   		
			reg		[lpm_widthu_rd-1:0]  	r_rdusedw_o 		=0 ;	
			reg		[lpm_widthu_rd-1:0]  	r_rdusedw_o_ff 		=0 ;	

				
			always@(posedge rdclk or posedge aclr )      
				if(aclr)                                
					r_fifo_rcnt	  <= 'b0 ;              
				else if ( r_fifo_rcnt == lpm_wr_rd_div -1  && rdreq == 1 ) 
					r_fifo_rcnt  <= 'b0 ; 	
				else if ( rdreq == 1 ) 
					r_fifo_rcnt  <= r_fifo_rcnt + 1 ;	
			
			assign s_fifo_rd_flag = (( rdreq == 1 && r_fifo_rcnt == 0)|| r_fifo_rcnt > 0) ? 1'b1 : 1'b0 ;
			
			always@(posedge rdclk or posedge aclr )      
				if(aclr)                                
					r_fifo_rd_flag	<= 'b0 ;              
				else 
					r_fifo_rd_flag  <= s_fifo_rd_flag ; 	
			
			always@(posedge rdclk or posedge aclr )      
				if(aclr)                                
					r_fifo_rdata	<= 'b0 ;              
				else if ( lpm_showahead == "ON" && s_fifo_rd_flag == 1 && rdreq == 1 && r_fifo_rcnt == 0 )  
					r_fifo_rdata  <= s_fifo_rdata ;
				else if ( lpm_showahead == "ON" && s_fifo_rd_flag == 1 && rdreq == 1 && r_fifo_rcnt > 0 )  
					r_fifo_rdata  <= {r_fifo_rdata[(lpm_wr_rd_div-1)*lpm_width_rd-1:0],{lpm_width_rd{1'b0}}} ;
				else if ( lpm_showahead =="OFF" && r_fifo_rd_flag == 1 &&               r_fifo_rcnt == 1 )  
					r_fifo_rdata  <= s_fifo_rdata ;
				else if ( lpm_showahead =="OFF" && r_fifo_rd_flag == 1 && rdreq == 1 && r_fifo_rcnt != 1 )  
					r_fifo_rdata  <= {r_fifo_rdata[(lpm_wr_rd_div-1)*lpm_width_rd-1:0],{lpm_width_rd{1'b0}}} ;
			
			always@(posedge rdclk or posedge aclr )      
				if(aclr)                                
					r_rd_last_flag	<= 'b0 ;              
				else if ( s_rdusedw == 1  && s_fifo_rdreq == 1 ) 
					r_rd_last_flag  <= 'b1 ;					
				else if ( s_fifo_rd_flag == 1 && rdreq == 1 && r_fifo_rcnt == lpm_wr_rd_div-1 ) 
					r_rd_last_flag  <= 'b0 ;							


					
			assign s_rdusedw_o  = ( lpm_wr_rd_div == 2 )? {s_rdusedw,1'b0}: 
								  ( lpm_wr_rd_div == 4 )? {s_rdusedw,2'b0}: 	
								  ( lpm_wr_rd_div == 8 )? {s_rdusedw,3'b0}: s_rdusedw ;
						
			always@(posedge rdclk or posedge aclr )      
				if(aclr)                                
					r_rdusedw_o	 <= 'b0 ;              
				else 
					r_rdusedw_o  <= s_rdusedw_o ;

			assign s_rdusedw_change	= ( s_rdusedw_o == r_rdusedw_o ) ? 1'b0 : 1'b1 ; 
									

			always@(posedge rdclk or posedge aclr )      
				if(aclr)                                
					r_rdusedw_o_ff	<= 'b0 ;              
				else if ( s_rdusedw_change == 1 && rdreq == 1 ) 
					r_rdusedw_o_ff  <= s_rdusedw_o - 1 ;
				else if ( s_rdusedw_change == 1 && rdreq == 0 ) 
					r_rdusedw_o_ff  <= s_rdusedw_o ;
				else if ( rdreq == 1 ) 
					r_rdusedw_o_ff  <= r_rdusedw_o_ff - 1 ;
			
																								
			assign rdusedw = ( s_rdusedw_change == 1 ) ? s_rdusedw_o :  r_rdusedw_o_ff ;
																
			assign rdempty	= ( r_rd_last_flag == 1 ) ? 1'b0 : s_rdempty ; 	
			
			
			assign s_fifo_rdreq 	= ( aclr == 1 			 ) ? 1'b0 : 
						  		  	  ( s_fifo_rd_flag == 1 && rdreq == 1 && r_fifo_rcnt == 0 ) ? 1'b1 : 1'b0;
			 	
			assign q = ( lpm_showahead == "ON" && s_fifo_rd_flag == 1 && r_fifo_rcnt == 0 ) ?  s_fifo_rdata[lpm_wr_rd_div*lpm_width_rd-1:(lpm_wr_rd_div-1)*lpm_width_rd] : 
			 		   ( lpm_showahead =="OFF" && r_fifo_rd_flag == 1 && r_fifo_rcnt == 1 ) ?  s_fifo_rdata[lpm_wr_rd_div*lpm_width_rd-1:(lpm_wr_rd_div-1)*lpm_width_rd] : 			 		   			 		   
																							   r_fifo_rdata[(lpm_wr_rd_div-1)*lpm_width_rd-1:(lpm_wr_rd_div-2)*lpm_width_rd] ; 	
								
		end 
	endgenerate	
							            
							            
//	assign rdempty	= s_rdempty	 ; 	
	assign rdfull 	= s_rdfull 	 ; 	


//---------------------------------------------------------
// DCFIFO                                  
//---------------------------------------------------------	
	
	dcfifo_inst_eth_tx_fifo #( 
		.lpm_width 	    			( lpm_width_large 	    	) ,
		.lpm_widthu 				( lpm_widthu_large 			) ,
		.lpm_numwords 				( lpm_numwords_large 		) ,
		.add_ram_output_register 	( add_ram_output_register   ) ,		
		.clocks_are_synchronized 	( clocks_are_synchronized   ) ,		
		.lpm_showahead 				( lpm_showahead 			) ,
		.lpm_hint					( lpm_hint					) ,
		.lpm_type					( lpm_type					) ,
		.overflow_checking 			( overflow_checking 		) ,
		.underflow_checking 		( underflow_checking 	    ) ,
		.use_eab 					( use_eab 				    ) 	
	)u_dcfifo_inst (
		.aclr 		( aclr				) ,
		.wrclk 		( wrclk				) ,
		.wrreq 		( s_fifo_wrreq		) ,
		.data 		( s_fifo_wdata		) ,
		.rdclk 		( rdclk				) ,
		.rdreq 		( s_fifo_rdreq		) ,
		.q 			( s_fifo_rdata		) ,
		.wrempty 	( s_wrempty			) ,
		.wrfull 	( s_wrfull 			) ,
		.wrusedw 	( s_wrusedw			) ,
		.rdempty 	( s_rdempty			) ,
		.rdfull 	( s_rdfull 			) ,
		.rdusedw 	( s_rdusedw			) 
	);
			    
endmodule

//----------------------------------------------------------------------------
// dcfifo
//----------------------------------------------------------------------------

`timescale 1 ps / 1 ps

module dcfifo_inst_eth_tx_fifo #(
	parameter					add_ram_output_register = "ON"					,
	parameter					clocks_are_synchronized = "FALSE"				,
	parameter					lpm_numwords 			= 4096					,
	parameter					lpm_showahead 			= "ON"					,
	parameter					lpm_hint 				= "RAM_BLOCK_TYPE=M4K"	,
	parameter					lpm_type 				= "dcfifo"				,
	parameter					lpm_width 				= 16					,
	parameter					lpm_widthu 				= 12						,
	parameter					overflow_checking 		= "ON"					,
	parameter					underflow_checking 		= "ON"					,
	parameter					use_eab 				= "ON"					 
)(
	input	  					aclr			,
	input	  					wrclk			,
	input	  					wrreq			,
	input	[lpm_width-1:0]  	data			,
	input	  					rdclk			,
	input	  					rdreq			,
	output	[lpm_width-1:0]  	q				,
	output	  					rdempty			,
	output	  					rdfull			,
	output	[lpm_widthu-1:0]  	rdusedw			,
	output	  					wrempty			,
	output	  					wrfull			,
	output	[lpm_widthu-1:0]  	wrusedw			 
);


	dcfifo	u_dcfifo_component (
		.rdclk 		( rdclk 		),
		.wrreq 		( wrreq 		),
		.aclr 		( aclr 			),
		.data 		( data 			),
		.rdreq 		( rdreq 		),
		.wrclk 		( wrclk 		),
		.wrempty 	( wrempty 		),
		.wrfull 	( wrfull 		),
		.q 			( q 			),
		.rdempty 	( rdempty 		),
		.rdfull 	( rdfull 		),
		.wrusedw 	( wrusedw 		),
		.rdusedw 	( rdusedw 		)
	);
	
	
	defparam
		u_dcfifo_component.add_ram_output_register 	= add_ram_output_register  	,
		u_dcfifo_component.clocks_are_synchronized 	= clocks_are_synchronized  	,
		u_dcfifo_component.lpm_hint 				= lpm_hint 					,
		u_dcfifo_component.lpm_numwords 			= lpm_numwords 				,
		u_dcfifo_component.lpm_showahead 			= lpm_showahead 			,
		u_dcfifo_component.lpm_type 				= lpm_type 					,
		u_dcfifo_component.lpm_width 				= lpm_width 				,
		u_dcfifo_component.lpm_widthu 			 	= lpm_widthu 				,
		u_dcfifo_component.overflow_checking 		= overflow_checking 		,
		u_dcfifo_component.underflow_checking 	 	= underflow_checking 		,
		u_dcfifo_component.use_eab 				 	= use_eab 					;				    


endmodule
