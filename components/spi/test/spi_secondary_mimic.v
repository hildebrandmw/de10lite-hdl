`timescale 1ns/1ps

// Mimic of the SPI interface for the GSensor.
// Meant for use in simulation only.
module spi_secondary_mimic #(
        parameter VERBOSE = 1
    )(
        input  SPI_SDI,
        output reg SPI_SDO,
        input  SPI_CSN,
        input  SPI_CLK
    );

    reg [7:0] data_rx, data_rx_expected;
    reg [7:0] data_tx;
    reg [2:0] count;

    file_reader fr ();
    // file for reading data to transmit back.
    integer secondary_data;
    initial begin
        secondary_data = $fopen("test/secondary_data.txt", "r");
        SPI_SDO = 1'b1;
        // Standard operating loop
        forever begin
            // Wait for CS to go low
            // Don't do anything until it does.
            @(negedge SPI_CSN);

            // Fork into two tasks
            //  1.  If CSN goes high, abort operation early and wait for CSN
            //      to go low again.
            //  2.  Read in 8 bits of data, sampling on the rising edge of
            //      SPI_CLK. If the first bit is a '1', read a line from the
            //      data file and send that data back, changing data on the
            //      falling edge.
            //
            //      If the end of the data file is reached, just transmit
            //      zeros to avoid breaking upstream simulation.
            fork : DATA_TRANSFER_OR_CSN
                // If SPI_CSN goes high, abort operation.
                begin : CSN_CHECK
                    @(posedge SPI_CSN);
                    disable DATA_TRANSFER;
                end
                // Transfer data.
                begin : DATA_TRANSFER
                    repeat (8) begin
                        // Align data read with positive edge of the clk.
                        // Shift in data
                        @(posedge SPI_CLK);
                        data_rx = {data_rx[6:0], SPI_SDI};
                    end
                    if (VERBOSE == 1) begin
                        $display("SPI secondary address: %b", data_rx);
                    end

                    // Check MSB of data_rx. If '1', do a read. Otherwise,
                    // keep reading.
                    if (data_rx[7] == 1'b1) begin
                        fr.get_file_data(secondary_data, data_tx);
                        count = 7;
                        repeat (8) begin
                            @(negedge SPI_CLK);
                            SPI_SDO = data_tx[count];
                            count = count - 1;
                        end
                    end else begin
                        repeat (8) begin
                            @(posedge SPI_CLK);
                            data_rx = {data_rx[6:0], SPI_SDI};
                        end
                        if (VERBOSE == 1) begin
                            $display("SPI secondary data_rx: %b", data_rx);
                        end
                    end
                    disable CSN_CHECK;
                end
            join
        end
    end

endmodule
