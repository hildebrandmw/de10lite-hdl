# DE10 Lite HDL

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

If you try to use any part of this repository and experience problems,
of if any instructions are unclear, please open an issue or contact me.

# Contents

This repository will be split into two main subdirectories, 

* A `components` directory with Verilog modules, associated testbenches, and other
    auxiliary code if necessary.

* A `projects` directory with sample Quartus projects using the various 
    components to demonstrate how they work in the "real world".
    
## Projects

* [sdram_tester](https://github.com/hildebrandmw/de10lite-hdl/tree/master/projects/sdram_tester): 
   A simple QSYS project demonstrating how to:
   * Use the SDRAM chip on the DE10-Lite board using the Intel SDRAM controller IP.
   * Transfer data between the FPGA and host PC using the USB-Blaster cable.
   
## Components

* [SPI Driver](https://github.com/hildebrandmw/de10lite-hdl/tree/master/components/spi):
    4-wire SPI driver. This module is primarily for communication with the GSensor chip on the DE10-Lite
    board, but is hackable enough for use in other situations if needed.

* [SDRAM Controller](https://github.com/hildebrandmw/de10lite-hdl/tree/master/components/dram):
   Tutorial on how to use the SDRAM chip on the DE10-Lite using the Intel SDRAM controller IP
   
* [USB-Blaster](https://github.com/hildebrandmw/de10lite-hdl/tree/master/components/usb-blaster):
   Tutorial on how to transfer data between the FPGA and host PC using the USB-Blaster
   cable.
   
* [VGA Driver](https://github.com/hildebrandmw/de10lite-hdl/tree/master/components/vga):
   Simple VGA signal generator. Allows building of more complex display based projects. The base
   design is targeted for the `640x480` resolution that the DE10-Lite is capable of, but is
   parameterized to be used at different resolutions.
   
## Upcoming

*Projects*

* `GIF Player`: Play GIFs from the DE10-Lite using VGA. GIFs or static images can be transferred
   from the host PC to the FPGA over the USB-Blaster at runtime. This project is complete,
   but just needs cleaning up for presentation.
   
* `GSensor Monitor`: Use the GSensor to move a box around a screen. Also transmit GSensor
   data from the FPGA to host PC.
   
*Components*

While more projects exist in the `components` directory than are listed above (and all of them
worked at one point or another), I'm working on cleaning up the components to make
them more generic and easier to use in other contexts.

* `UART`: Simple, parametric UART driver.
* `GSensor`: Module for initializing and reading data from the GSensor on the DE10-Lite board.
