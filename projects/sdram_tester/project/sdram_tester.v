module sdram_tester(

	//////////// CLOCK //////////
	input 		          		ADC_CLK_10,
	input 		          		MAX10_CLK1_50,
	input 		          		MAX10_CLK2_50,

	//////////// SDRAM //////////
	output		    [12:0]		DRAM_ADDR,
	output		     [1:0]		DRAM_BA,
	output		          		DRAM_CAS_N,
	output		          		DRAM_CKE,
	output		          		DRAM_CLK,
	output		          		DRAM_CS_N,
	inout 		    [15:0]		DRAM_DQ,
	output		          		DRAM_LDQM,
	output		          		DRAM_RAS_N,
	output		          		DRAM_UDQM,
	output		          		DRAM_WE_N,

	//////////// KEY //////////
	input 		     [1:0]		KEY,

	//////////// LED //////////
	output		     [9:0]		LEDR
);

// SDRAM controller only emits 1 DQM Signal. Assign both the low DQM and upper
// DQM signals to this one signal.
wire DRAM_DQM;
assign DRAM_LDQM = DRAM_DQM;
assign DRAM_UDQM = DRAM_DQM;

qsys_system u0 (
    .clk_clk           (MAX10_CLK1_50), //  clk.clk
    .reset_reset_n     (KEY[0]),        //  reset.reset_n
    .dram_clk_ext_clk  (DRAM_CLK),      //  dram_clk_ext.clk
    .dram_export_addr  (DRAM_ADDR),     //  dram_export.addr
    .dram_export_ba    (DRAM_BA),       //             .ba
    .dram_export_cas_n (DRAM_CAS_N),    //             .cas_n
    .dram_export_cke   (DRAM_CKE),      //             .cke
    .dram_export_cs_n  (DRAM_CS_N),     //             .cs_n
    .dram_export_dq    (DRAM_DQ),       //             .dq
    .dram_export_dqm   (DRAM_DQM),      //             .dqm
    .dram_export_ras_n (DRAM_RAS_N),    //             .ras_n
    .dram_export_we_n  (DRAM_WE_N),     //             .we_n
    .led_export_export (LEDR[7:0])      //   led_export.export
);

assign LEDR[9:8] = 2'b00;

endmodule
