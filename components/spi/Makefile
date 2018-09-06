SRC=	hdl/spi.sv 					\
	   	test/spi_tb.sv 				\
	   	test/spi_secondary_mimic.v 	\
		test/file_reader.v

TB=spi_tb

spi:
	iverilog -o $(TB).sim -s $(TB) $(SRC)

clean-control:
	rm -rf $(CONTROL_TB).vcd
	rm -rf $(CONTROL_TB).sim

clean-serdes:
	rm -rf $(SERDES_TB).vcd
	rm -rf $(SERDES_TB).sim

clean:
	rm $(TB).vcd
	rm $(TB).sim
