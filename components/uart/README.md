# UART

Simple UART tx/rx module

## Parameters

| Parameter | Description |
|-|-|
| `CLK_FREQ` | Frequency of the clock driving this module. |
| `BAUD` | The baud rate of the UART. |

## Ports

| Port | Description |
|-|-|
| `clk` | Logic clock. |
| `reset` | Reset. |
| `rx` | RX signal. |
| `rx_data` | Desrialized byte. |
| `rx_valid` | Asserted when `rx_data` is valid. |
| `tx` | TX Signal. |
| `tx_data` | Data to transmit. |
| `tx_transmit` | Assert to transmit data. No effect when `tx_ready = 0`. |
| `tx_ready` | Asserted when ready to transmit data. |

## Receiving

Module receives a serial stream through the port rx.
When a byte has been successfully received, the received data will be
available on the output port `rx_data` and the output port `rx_valid` will be
asserted for 1 clock cycle.  Validity of output data is not guaranteed if 
`rx_valid` is not 1.

## Transmitting

When input port `tx_transmit` is 1 (asserted), module will
store the data on the input port `tx_data` and serialize through the output
port `tx`.

Module will only save and transmit the data at `tx_data` if the signal
`tx_read` is asserted when `tx_transmit` is asserted. This module will not
buffer input data. While transmitting, `tx_ready` is deasserted and the
input port `tx_transmit` will have no effect.

Once `tx_ready` is deasserted, data at port `tx_data` is not used and need
not be stable.
