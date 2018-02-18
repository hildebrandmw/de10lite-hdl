SERDES_SRC=	hdl/spi_serdes.v 			\
		   	test/spi_serdes_tb.v 		\
		   	test/spi_secondary_mimic.v 	\
			test/file_reader.v

SERDES_TB=spi_serdes_tb

CONTROL_SRC= 	hdl/spi_control.v 			\
				hdl/spi_serdes.v 			\
				test/spi_control_tb.v		\
				test/spi_secondary_mimic.v 	\
				test/file_reader.v

CONTROL_TB=spi_control_tb

all:
	make serdes
	make control

control:
	iverilog -o $(CONTROL_TB).sim -s $(CONTROL_TB) $(CONTROL_SRC)


serdes:
	iverilog -o $(SERDES_TB).sim -s $(SERDES_TB) $(SERDES_SRC)

clean-control:
	rm -rf $(CONTROL_TB).vcd
	rm -rf $(CONTROL_TB).sim

clean-serdes:
	rm -rf $(SERDES_TB).vcd
	rm -rf $(SERDES_TB).sim

clean:
	make clean-control
	make clean-serdes
