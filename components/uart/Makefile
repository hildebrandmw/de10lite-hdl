TESTBENCH=uart_tb
SOURCES=hdl/uart.v hdl/uart_handler.v test/${TESTBENCH}.v

testbench:
	iverilog -o ${TESTBENCH}.sim -s ${TESTBENCH} ${SOURCES}

run:
	./${TESTBENCH}.sim

viewer:
	open ${TESTBENCH}.vcd

clean:
	rm ${TESTBENCH}.sim
	rm ${TESTBENCH}.vcd
