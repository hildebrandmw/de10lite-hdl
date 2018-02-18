`timescale 1ns/1ps
module spi_serdes_tb();
    // Simulation parameters
    localparam GENERATE_DUMP = 1; // set to 0 to turn off
    localparam SPI_CLK_FREQ = 2_000_000;  // Frequency in HZ

    // Defived Parameters
    localparam SPI_CLK_PERIOD = 1E9 / SPI_CLK_FREQ;

    //--------------------
    // Internal signals
    //--------------------
    reg [7:0] data_rx_expected;
    reg isread;
    integer primary_data;
    integer secondary_data;

    // Signals for interfacing to the DUT
    reg         reset_n;
    reg         spi_clk, spi_clk_out;
    reg [15:0]  data_tx;
    reg         start;
    wire        done;
    wire [7:0]  data_rx;

    wire SPI_SDI, SPI_SDO, SPI_CLK, SPI_CSN;

    // Instantiate UUT
    spi_serdes UUT (
            .reset_n    (reset_n),
            .spi_clk    (spi_clk),
            .spi_clk_out(spi_clk_out),
            .data_tx    (data_tx),
            .start      (start),
            .done       (done),
            .data_rx    (data_rx),
            // SPI Side signals
            .SPI_SDI    (SPI_SDI),
            .SPI_SDO    (SPI_SDO),
            .SPI_CLK    (SPI_CLK),
            .SPI_CSN    (SPI_CSN)
        );

    // Instantiate spi_secondary_mimic to interact with UUT
    spi_secondary_mimic ssm (
            .SPI_SDI    (SPI_SDI),
            .SPI_SDO    (SPI_SDO),
            .SPI_CLK    (SPI_CLK),
            .SPI_CSN    (SPI_CSN)
        );

    // Instantiate file reading module for file reading task
    file_reader fr ();

    // Set up out of phase clocks
    initial begin
        spi_clk = 1'b0;
        spi_clk_out = 1'b1;
        forever begin
            #(SPI_CLK_PERIOD/4);
            spi_clk = ~spi_clk;
            #(SPI_CLK_PERIOD/4);
            spi_clk_out = ~spi_clk_out;
        end
    end

    // Standard test
    initial begin
        // Configure data dump
        if (GENERATE_DUMP == 1) begin
            $dumpfile("spi_serdes_tb.vcd");
            $dumpvars(0, spi_serdes_tb);
        end
        // Open data files
        primary_data    = $fopen("test/primary_data.txt", "r");
        secondary_data  = $fopen("test/secondary_data.txt", "r");

        // Assert reset
        repeat (3) begin
            reset_n = 1'b0;
            @(posedge spi_clk);
        end
        reset_n = 1'b1;

        // Repeat until end of primary data file.
        while (!$feof(primary_data)) begin
            // Read 8 bits from the data file. Check MSB to determine if htis
            //  is a read or a write.
            fr.get_file_data(primary_data, data_tx[15:8]);
            isread = (data_tx[15] == 1'b1);

            $display("Primary transmitting: %b", data_tx[15:8]);
            if (!isread) begin
                // Get next 8 bits from data file
                fr.get_file_data(primary_data, data_tx[7:0]);
                $display("Primary transmitting: %b", data_tx[7:0]);
            end

            // Assert start signal and wait for done
            @(posedge spi_clk);
            start = 1'b1;
            @(posedge spi_clk);
            wait (done == 1'b1);
            start = 1'b0;

            if (isread) begin
                fr.get_file_data(secondary_data, data_rx_expected);
                // Check data
                if (data_rx_expected != data_rx) begin 
                    $display("Data Mismatch");
                    $display("Expected: %b. Received %b", data_rx_expected, data_rx);
                end
            end
        end
        $finish;
    end
endmodule
