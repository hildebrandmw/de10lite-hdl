# VGA Controller

Note - this code is a Verilog transcription of that posted in
[https://eewiki.net/pages/viewpage.action?pageId=15925278].

Timing information in the parameter list is configured for *640x480* resolution 
and expects to be supplied with a *25 MHz clock*. Consult the link above to
configure for other resolutions.

# Operation
This module is very self-contained with the only `clk` and `reset_n` as the
expected inputs. The correct `h_sync` and `v_sync` signals for the VGA protocol
will automatically be generated from the timing parameters passed.

For practical incorporation in a design, the following signals are exported:
- `disp_ena` - There are periods of display time and blanking time during 
    VGA operation. When `disp_ena = 1`, color values may be sent to the 
    screen.  When `disp_ena = 0`, black should be sent as the color value.
- `row` - The row value of the pixel being drawn. Only valid when 
    `disp_ena = 1`.
- `col` - The column value of the pixel being drawn. Only valid when
    `disp_ena = 1`.

# Simulation
The test bench `test/vga_timer_tb.v` simulates the timing module for one full
frame of drawing. This can be helpful for verifying the timing of the module.

Use the Makefile to build, but note that the Makefile expects
icarus-verilog to be installed. Also note the resulting VCD file as 
approximately 26 MB as this is a large simulation.
