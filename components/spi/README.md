# SPI

A simple 4-wire serialiser/deserializer for communicating with the GSensor chip.
This design should be general enough to allow adaption to other SPI applications
if desired.

## Parameter and Ports

**Parameters**

| Parameter         | Note                                                      |
--------------------|-----------------------------------------------------------|
| `DATASIZE`        | Number of bytes transmitted/recieved at a time.           |
| `CLK_FREQUENCY`   | Clock frequency (`Hz`) of the `clk` in the FPGA logic.    |
| `SPI_FREQUENCY`   | Desired clock frequency of `spi_clk`. `CLK_FREQUENCY` 
                        must be an even multiple of `SPI_FREQUENCY`.            |
| `IDLE_NS`         | Minimum deassertion time for `spi_csn` in `NS`.           |

**Ports**

| Signal        | Note |
|---------------|--|
| `reset_n`     | Reset signal. |
| `clk`         | Primary logic clock. |
| `tx_request`  | Indicate there is data to send. |
| `tx_data`     | Data to transmit. |
| `rx_request`  | Indicate that data should be read from slave. |
| `rx_data`     | Data read from slave. |
| `rx_valid`    | Flag that data from slave is valid. |
| `ack_request` | Acknowledge `tx_request` or `rx_request`. |
| `active`      | Indicate `spi` is communicating with slave. |
| `spi_sdi`     | Slave data in. |
| `spi_sdo`     | Slave data out. |
| `spi_csn`     | Chip select. |
| `spi_clk`     | SPI clock. |

### Timing diagrams for transfer requests
![cookies](./figures/request_interface.png)

The SPI module is capable of servicing simultaneous RX and TX operations or
just single RX/TX operations. Flag `ack_request` is asserted when an operation
has begun. Multiple read/write operations during the same transaction (assertion
of `spi_csn` are supported by asserting `tx_request` or `rx_request` (or both)
before `active` is deasserted. Either request must be held until `ack_request`
is asserted.

Read data is available once `rx_valid` is asserted, as shown in the timing
diagram below

![hello](./figures/response_interface.png)

Once a read request has been acknowledged, the `rx_valid` signal must be
monitored until it is asserted.

### SPI signal timing

![waveforms](./figures/spi.png)

**Timing**

|Signal     | Time                  |
|-----------|-----------------------|
|`T_lead`   | `1/CLK_FREQUENCY`     |
|`T_spi`    | `1/SPI_FREQUENCY`     |
|`T_lag`    | `1/CLK_FREQUENCY`     |
|`T_idle`   | `IDLE_NS`             |

In this version of the protocol, data for both the master and the slave
transitions on the falling edge of the `spi_clk` and is sampled on the rising
edge of `spi_clk`. A single transaction is 8-bits by default, and multiple
transmissions can be chained together by issuing a tx/rx request before the
previous transmission completes.

Output `active` indicates if a transaction is taking place or not. Once a
transaction finishes, chip select `spi_csn` will be deasserted for at least
`IDLE_NS` nanoseconds before the next tranaction occurs.

## Testbench

The testbench for the module consists of the top level testbench itself
(`spi_tb.sv`) and a couple of helper modules:

* `file_reader.v` - Simple module that abstracts the process of reading data
    one line at a time from a file, with a zero default if the end of the file
    is reached.

* `spi_secondary_mimic.sv` - Simple System Verilog implementation of the
    behavior of the GSensor-side SPI signal timings. Allows for multibyte reads
    and writes. Data file `secondary_data.txt` is required for verification.

The testbench executes a series of read and write operations. Verification that
the recieved data is what was expected is done through the `secondary_data.txt`
file: everytime `spi_tb` recieves data from `spi_secondary_mimic`, it check the
recieved data with `secondary_data.txt` to verify the correct data was recieved.
Each byte recieved increments the position in the data file by one line.
