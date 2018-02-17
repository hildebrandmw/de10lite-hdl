# DE10 Lite HDL

(NOTE: This is a work in progress.)

This repository is a collection of code I've written while TAing EEC180B at 
UC Davis. This is mainly wrapper code for interacting with the various 
peripherals on the Altera/Intel [DE10-Lite](http://www.terasic.com.tw/cgi-bin/page/archive.pl?No=1021)
development board to facilitate various student labs.

The code here is meant to be used as a starting point for using the peripheral
components on the development board.

Since this is wrapper code, it may or may not be functional standalone as-is.
When I have time, I will endeavor to make examples more complete and 
wholly synthesizeable. 

Where appropriate, Makefiles will be included for building and executing 
simulations using icarus-verilog.

Please contact me if you have any questions.

# Contents

- [VGA](#vga)
- [GSensor](#gsensor)
- [UART](#uart)

## vga
A parameterized core using the VGA port.

## gsensor
Code for interacting with the included GSensor. Will include shortly.

## uart
*LEGACY*

This project was from when we were using the old DE2 boards with a RS232 serial 
port. This code includes 
    - A simple UART RX/TX core.
    - A wrapper for receiving and transmitting multiple bytes.
    - Skeleton testbench code for testing UART.

# TODO
- Improve documentation of each included project.

- Documentation of how to get data onto and off of the MAX10 FPGA using the
    included USB Blaster cable. I have a solution working for this, but it
    needs a little more cleaning up and attention.

- Suitable DRAM code. So far, we have not done any labs using the SDRAM on the
    DE10-Lite board, but one of these days I would like to document how to bring
    this up and write some code to interact seamlessly with the SDRAM.
