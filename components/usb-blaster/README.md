# Data Transfer over USB Blaster

Much of this (especially the TCL code) is build upon the excellent
tutorial by Dave Hawkins:

[Tutorial PDF](https://www.ovro.caltech.edu/~dwh/correlator/pdf/altera_jtag_to_avalon_mm_tutorial.pdf?language=ja)
[Tutorial Source (.zip)](http://www.ovro.caltech.edu/~dwh/correlator/pdf/altera_jtag_to_avalon_mm_tutorial.zip)

The 1000 foot view of how this works is summarized by the figure below:
![System Architecture](https://github.com/hildebrandmw/JTAGManager.jl/blob/master/img/arch.png?raw=true)

## On the FPGA
For this scheme to work, a Platform Designer [Avalon](https://www.intel.com/content/www/us/en/programmable/documentation/nik1412467993397.html)
system must be used. In Platform Designer, add a JTAG-to-Avalon-MM component
to the Avalon interface. (Note, the interface allows for multiple masters on a
single bus as it handles arbitration). As with the DRAM, if a simpler interface
is needed in the internal FPGA fabric, use a External Bus to Avalon Bridge.

This is all the really special work that needs to be done on the FPGA side. 
Quartus will deal with the details of connecting the JTAG pins and the necessary
clock domain crossing.

## On the Host PC
I normally use System Console on the host PC, but theoretically D. Hawkin's server
script should work in `stp` as well, though I have never used it.

To open System Console, open Quartus and follow 
```
Tools -> System Debugging Tools -> System Console
```
In the TCL console, press `ctrl-e` to open up an explorer to find a TCL script
to run. The TCL script `jtag_server.tcl` can be found in the Julia package 
[JTAGManager.jl](https://github.com/hildebrandmw/JTAGManager.jl),
which also provides a nice Julia wrapper for the read/write functionality of the
TCL server. 

Once the server is running, read and write commands can be sent to the Avalon MM
system at will. The syntax of the commands is unchanged from the tutorial 
PDF/Source linked above, so check out those links for more details on how the
server system works.
