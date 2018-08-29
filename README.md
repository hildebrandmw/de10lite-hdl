# DE10 Lite HDL (WIP)

## DISCLAIMER NOTE
Over the next few weeks, I will endeavor to finally make this repository 
complete. Until then, code and organization will be in a state of flux. To help
keep myself on track, my TODO list will be kept here:

### Components
* `gsensor` - Update documentation for the split into `gsensor` and `spi`.

* `spi` - Update documentation for the split into `gsensor` and `spi`.
    * Make "API" not ridiculous - it's currently set up specifically for the
        GSensor application and is absurd.

* `uart` - Update testbench to test `uart` directly. This somehow got lost some 
    time in the past and needs to be redone.

* `usb-blaster` - This is gonna take a lot of work.

### Projects
All the things.



# The actual README

This repository is a collection of code I've written while TAing EEC180B at 
UC Davis. This is mainly wrapper code for interacting with the various 
peripherals on the Altera/Intel 
[DE10-Lite](http://www.terasic.com.tw/cgi-bin/page/archive.pl?No=1021)
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

This repository will be split into two main subdirectories, 

* A `components` directory with Verilog modules, associated testbenches, and o
    auxiliary code if necessary.

* A `projects` directory with sample Quartus projects using the various 
    components to demonstrate how they work in the "real world".

A summary of `components` can be found below:

- [UART](#uart)
- [SPI](#spi)
- [VGA](#vga)
- [GSensor](#gsensor)
- [DRAM](#dram)
- [USB Blaster](#usb blaster)

## uart
This project was from when we were using the old DE2 boards with a RS232 serial 
port. This code includes 
    - A simple UART RX/TX core.
    - A wrapper for receiving and transmitting multiple bytes.
    - Skeleton testbench code for testing UART.

## spi
A simple 4-wire SPI core. Used for communicating with the GSensor chip on the
board.

## vga
A parameterized core using the VGA port.

## gsensor
Control code for `spi`, which correctly initializes the GSensor chip and 
periodically samples `X`, `Y`, and `Z` data from the chip and makes that easily
available to the internal logic of the FPGA.

## dram
Comprehensive instructions on how to interact with the SDRAM chip the DE10 board
using Quartus IP Components.

## usb_blaster
Code and instructions for how to transfer data between a host computer and
the Max10 FPGA using the USB Blaster cable.
