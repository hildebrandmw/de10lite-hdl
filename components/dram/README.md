# DRAM (TODO)

The easiest and least messy way of interfacing with the DRAM (that avoids 
writing a custom DRAM controller) is to instantiate the DRAM controller IP 
component offered by Quartus' System Integrator (formerly known as QSYS). I will
include some more details of how to do that in a bit, but in the mean time, 
here's a table of settings I've used to successfully communicate with the DRAM.

Note, there's some schenanigans that must be performed in the `.sdc` file to
get the IO signal timings correct. I will eventually include those details
as well.

Parameter                       | Setting
--------------------------------|--------
Clock frequency                 | 100 MHz
                                |        
CAS Latency                     | 2
                                |        
Initialization refresh cycles   | 8
                                |        
Issue one refresh every         | 7.8125 ns
                                |        
Delay after powerup             | 100 us
                                |        
t\_rfc                          | 55 ns
                                |        
t\_rp                           | 15 ns
                                |        
t\_rcd                          | 15 ns
                                |        
t\_ac                           | 6 ns
                                |        
t\_wr                           | 14 ns
