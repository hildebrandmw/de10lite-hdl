SRC= 	hdl/gsensor.v 						\
		../spi/hdl/spi.v					\
		test/gsensor_tb.v					\
		../spi/test/spi_secondary_mimic.v 	\
		../spi/test/file_reader.v

TB=gsensor_tb

gsensor:
	iverilog -o $(TB).sim -s $(TB) $(SRC)

clean:
	rm $(TB).vcd
	rm $(TB).sim
