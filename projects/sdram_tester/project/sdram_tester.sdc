#**************************************************************
# Create Clock
#**************************************************************
create_clock -period "10.0 MHz" [get_ports ADC_CLK_10]
create_clock -period "50.0 MHz" [get_ports MAX10_CLK1_50]
create_clock -period "50.0 MHz" [get_ports MAX10_CLK2_50]

#**************************************************************
# Create Generated Clock
#**************************************************************

# Set the names of the external and internal DRAM clocks here.
# Finding the names can sometimes be a little difficult. Consulting 
# TimeQuestAnalyzer can be helpful.
#
# The included names are just example placeholders.
set dram_clk_int    {u0|pll|sd1|pll7|clk[0]}
set dram_clk_ext    {u0|pll|sd1|pll7|clk[1]}

# SDRAM CLK
create_generated_clock -source $dram_clk_ext -name clk_dram_ext [get_ports {DRAM_CLK}]
derive_pll_clocks

#**************************************************************
# Set Clock Uncertainty
#**************************************************************
derive_clock_uncertainty

#**************************************************************
# Set Input Delay
#**************************************************************
# Input delay taken from DE10 reference design.
# suppose +- 100 ps skew
# Board Delay (Data) + Propagation Delay - Board Delay (Clock)
# max 5.4(max) +0.4(trace delay) +0.1  = 5.9
# min 2.7(min) +0.4(trace delay) -0.1 = 3.0
set_input_delay -max -clock clk_dram_ext 5.9 [get_ports DRAM_DQ*]
set_input_delay -min -clock clk_dram_ext 3.0 [get_ports DRAM_DQ*]


#**************************************************************
# Set Output Delay
#**************************************************************
# Output delay taken from DE10 reference design.
# suppose +- 100 ps skew
# max : Board Delay (Data) - Board Delay (Clock) + tsu (External Device)
# min : Board Delay (Data) - Board Delay (Clock) - th (External Device)
# max 1.5+0.1 =1.6
# min -0.8-0.1 = 0.9
set_output_delay -max -clock clk_dram_ext 1.3  [get_ports {DRAM_DQ* DRAM_*DQM}]
set_output_delay -min -clock clk_dram_ext -0.6 [get_ports {DRAM_DQ* DRAM_*DQM}]
set_output_delay -max -clock clk_dram_ext 1.3  [get_ports {DRAM_ADDR* DRAM_BA* DRAM_RAS_N DRAM_CAS_N DRAM_WE_N DRAM_CKE DRAM_CS_N}]
set_output_delay -min -clock clk_dram_ext -0.6 [get_ports {DRAM_ADDR* DRAM_BA* DRAM_RAS_N DRAM_CAS_N DRAM_WE_N DRAM_CKE DRAM_CS_N}]

#**************************************************************
# Set Multicycle Path
#**************************************************************

# Since we've constrained DRAM_DQ to the sdram clock, Quartus is going to get
# confused since the driver for DRAM_DQ is the system clock which is slightly
# out of phase with the DRAM clock. As such, if we don't tell Quartus there
# is a multicycle path between the two clocks, it will think it's not meeting
# timing constraints.
set_multicycle_path -from [get_clocks {clk_dram_ext}] -to [get_clocks $dram_clk_int] -setup 2
