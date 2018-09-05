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

    logic [7:0] data_rx, data_rx_expected;
    logic [2:0] count;

    logic writeback;
    logic multibyte;

    file_reader fr ();
    // file for reading data to transmit back.
    integer secondary_data;
    initial begin
        // Get file handle, default SDO line high.
        secondary_data = $fopen("secondary_data.txt", "r");

        // Standard operating loop
        forever begin
            // Wait for CS to go low
            // Don't do anything until it does.
            SPI_SDO = 1'b1;
            wait (SPI_CSN == 1'b0); 

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
            fork // join_any

                // If SPI_CSN goes high, abort operation.
                begin
                    @(posedge SPI_CSN);
                end

                // Transfer data.
                begin
                    read_spi();

                    // Decode recieved data
                    writeback = data_rx[7]; 
                    multibyte = data_rx[6];

                    // If a multibyte transaction is happening, keep reading/
                    // writing until the above branch of the fork kills the
                    // process when CSN goes high.
                    if (multibyte) begin
                        while (1) begin
                            if (writeback)
                                write_spi();
                            else
                                read_spi();
                        end 

                    // Perform one transaction and wait for CSN to go high.
                    end else begin
                        if (writeback)
                            write_spi();
                        else
                            read_spi();
                    end
                end
            join_any
            disable fork;
        end
    end

    // Read Task
    task read_spi;
    begin
        repeat (8) begin
            @(posedge SPI_CLK);
            data_rx = {data_rx[6:0], SPI_SDI};
        end
        if (VERBOSE) begin
            $display("SECONDARY: recieve %b", data_rx);
        end
    end
    endtask

    // Write task
    task automatic write_spi;
    begin
        logic [7:0] data_tx;
        int count = 7;

        // Read TX data.
        fr.get_file_data(secondary_data, data_tx); 
        if (VERBOSE) begin
            $display("SECONDARY: transmit %b", data_tx);
        end
        repeat (8) begin
            // Update data on negative edge of clock.
            @(negedge SPI_CLK);
            SPI_SDO = data_tx[count];
            count = count - 1;
        end
    end
    endtask

endmodule
