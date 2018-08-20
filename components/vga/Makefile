TESTBENCH=vga_timer_tb
SOURCES=hdl/vga_timer.v test/${TESTBENCH}.v

testbench:
	iverilog -o ${TESTBENCH}.sim -s ${TESTBENCH} ${SOURCES}

run:
	./${TESTBENCH}.sim

viewer:
	open ${TESTBENCH}.vcd

clean:
	rm ${TESTBENCH}.sim
	rm ${TESTBENCH}.vcd
