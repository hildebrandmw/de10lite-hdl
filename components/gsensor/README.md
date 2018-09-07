# G-Sensor Interface

| Required Submodules   |
|-----------------------|
| [spi.v](https://github.com/hildebrandmw/de10lite-hdl/tree/master/components/spi)|

Controller for the ADXL345 accelerometer on the DE10-Lite board. This module
initializes the accelerometer chip and periodically samples the X, Y, and Z
axes.

## Parameters

| Parameter | Description |
|-|-|
| `CLK_FREQUENCY` | The clock frequency driving the logic of this component. |
| `SPI_FREQUENCY` | The frequency at which to create the `SPI_CLK`. Note that `CLK_FREQUENCY` must be an even multiple of `SPI_FREQUENCY`. |
| `IDLE_NS` | SPI timing signal: minimum time to deassert `SPI_CSN` between transactions. |
| `UPDATE_FREQUENCY` | Number of times to sample the accelerometer per second. |

## Ports

| Port | Description |
|-|-|
| `reset_n` | Reset signal. After reset, accelerometer initialization begins. |
| `clk` | Logic clock. |
| `data_valid` | Flag indicating new data is available. High for one clock cycle. |
| `data_x`, `data_y`, `data_z` | Accelerometer data. Only guarenteed valid when `data_valid == 1`. |
| `SPI_SDI` | SPI slave data-in. |
| `SPI_SDO` | SPI slave data-out. |
| `SPI_CSN` | SPI chip select. |
| `SPI_CLK` | SPI clock. Generated internally. |

## Using this module

This module is very simple to use. Simply instantiate it, connect the `SPI_*` 
signals to the top level `SPI` signals, and connect `clk` and `reset_n`. The
module will run automatically. At each update, `data_valid` will be asserted
for one clock cycle, at which time, the `data_*` are valid to be sampled.

## Internal Operation (Processor)

Internally, the module consists of a simple processor and minor peripheral logic.
The processor consists of a program `spi_program`. Each instruction in the 
program consists of an `opcode_t` opcode, and an 8-bit immediate (even if the
immediate is not used for the instruction). A program counter `pc` is used to
access the current instruction.

A small 6-byte memory signal `memory` is used to store accelerometer data 
between reads.

### Opcodes
* `READ` - Read 8 bits from the SPI. Store result in `memory` at address given
    by immediate. Move to `pc+1` when SPI signal `ack_request == 1`. 

    *Immediate* - Pointer to memory location where read result is stored.

* `WRITE` - Write 8-bit immediate to the SPI. Move to `pc+1` when SPI signal
    `ack_request == 1`.

    *Immediate* - Value to write to the SPI slave.

* `WAIT_FOR_IDLE` - Stall until SPI signal `active == 0`. Allows for stalling
    when subsequent requests require `SPI_CSN` to be deasserted.

    *Immediate* - Unused.

* `WAIT_FOR_UPDATE` - Stall until periodic `update` signal is asserted. This 
    signal timing is controlled by a free-running counter.

    *Immediate* - Unused.

* `JUMP` - Set `pc` to immediate. Allows for a simple loop.

    *Immediate* - `pc` of destination.

* `NOTIFY` - Assert `data_valid` for one clock cycle. Increment `pc`.

The program begins with an initialization routine, then forever loops through a
read routine.

## Testing

The provided testbench simply executes until the module until the first 
`data_valid` signal assertion.

**External modules needed for testing** - In addition to the modules in this 
folder, the files `spi_secondary_mimic.sv`, `file_reader.sv` and `spi.sv` from 
the [SPI](https://github.com/hildebrandmw/de10lite-hdl/tree/master/components/spi)
component are needed for simulation to run.
