# G-Sensor Interface

HDL source and testbenches for periodically sampling the X and Y axes of the
DE10-Lite G-Sensor. HDL folder contains two main modules:

- `spi_serdes.v` - SERializer/DESerializer for the 4-wire SPI protocol used
    for communication between the Primary FPGA and Secondary Accelerometer.
    Somewhat specialized for the interchange behavior getween primary and
    secondary. Does not support burst reads/writes.
- `spi_control.v` - Higher level module for controlling high level interactions
    between primary and secondary. Reponsibilities include initializing 
    accelerometer and sampling G-Sensor at a set rate.

Control module should be hackable enough to allow adding Z-axis, and changing
initialization/functionality of the G-Sensor as needed. More detailed 
descriptions of the modules and their respective test benches are given below.

# spi\_control.v

Module for periodically sampling the x- and y-axis of the G-Sensor and 
broadcasting the results on the `data_x` and `data_y` output ports respectively.
When new data is available, the output signal `data_update` will be high (1)
for one clock cycle of `clk`. Though these outputs are held for some time after
`data_update`, the are not necessary valid. Any module reading these values 
should capture them as soon as possible.

## Clocking

Clocking for this module is a little tricky. Three separate clocks have to
be provided: one clock running at the speed of the module using this design,
and two slower slightly out of phase clocks for clocking the SPI circuitry.
The reason two SPI clocks are needed is to simpify logic design. The G-Sensor
chip expects data to be sampled on the rising edge of the SPI clock and changed
on the falling edge. Since the same module has to both read and write, and dual
edge triggered flip flops in FPGA design is somewhat shaky, two out of phase
clocks are used to approximate this behavior while only requiring positive edge
flip-flops in the the SPI logic.

Look at the clocks portion of the port list given below for tested frequencies
and phase relationships. All clocks can be generated from a single PLL.

## Parameters

- `SPI_CLK_FREQ` - The frequency (Hz) of the clock used to communicate with the 
    SPI secondary. This is the clock frequency that most of the internal logic
    of `spi_control` and `spi_serdes` will use. Default: `2 MHz`.
- `UPDATE_FREQ` - The frequency (Hz) at which to sample new values from the 
    G-Sensor.  Be sure to read the datasheet for the sensor before making this 
    value any larger. Default: `50 Hz`.

## Ports

- `reset_n` - When `0`, reset all internal logic.

- `clk` - The clock of the logic using this module. This clock is provided to
    ensure that `data_update` is high for only one clock cycle of the 
    intantiating module. Tests values: **25 MHz and 50 MHz**.

- `spi_clk` - Clock used for driving SPI logic internally. **NOTE: This clock
    must be in phase with `clk`. If it is not, timing closure might not be
    achieved.**

    Tested Values: **2 MHz**

- `spi_clk_out` - Clock used for driving SPI logic externally. **NOTE: Must be
    the same frequency as `spi_clk` but 270 degrees ahead.**

- `data_udpate` - Control flow signal, high for one clock cycle when new values
    for `data_x` and `data_y` are valid and available.

- `data_x` - 16 bit signed value for the x-axis of the G-Sensor.

- `data_y` - 16 bit signed value for the y-axis of the G-Sensor.

- `SPI_CSN` - Chip select for SPI protocol.

- `SPI_CLK` - Clock for SPI protocol.

- `SPI_SDI` - Clock from SPI primary to secondary.

- `SPI_SDO` - Data wire from SPI secondary to primary.

# Testing

Makefile can be used as a reference for how to build
simulation environment. **Note that Makefile assumes that iverilog is 
installed.** 

# spi\_secondary\_mimic.v

This is a simple reactive model of the G-Sensor SPI secondary. During a primary 
write command, the mimic will read a full 16 bits of data and display read
results if parameter `VERBOSE = 1`. During a primary read operation, secondary
will read 8 bits and then write back 8 bits. Write back data taken one line at
a time from the `secondary_data.txt` file. Every primary read operation will
increment the secondary's read position in this file by one line.

# spi\_serdes\_tb.v

Testbench for `spi_serdes.v`. Generates a series of read and write requests
taken from `primary_data.txt`. One a read request, will check its decoded data
with the expected data from `secondary_data.txt`. If there is a mismatch, an
error message will be displayed.

# spi\_control\_tb.v

Testbench for `spi_control.v`. Supplies appropriate clocks to `spi_control` and
waits for `data_update` output to be asserted. At this point, the `data_x` and
`data_y` signals are checked and compared with the expected results from
`secondary_data.txt`. If there is a mismatch, an error message will be 
displayed.
