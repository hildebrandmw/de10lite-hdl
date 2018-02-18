`timescale 1ns/1ns
module spi_control_tb();
    // Sim parameters - configured for conveniend simulation
    localparam GENERATE_DUMP = 1;
    localparam CLK_FREQ      = 400; // FPGA Clock (Hz)
    localparam SPI_CLK_FREQ  = 200; // SPI Clock (Hz)
    localparam UPDATE_FREQ   = 1;    // Sampling frequency (Hz)
    localparam NUM_SAMPLES   = 3;    // Number of samples to take

    // Sim variables
    integer secondary_data; // File for extracting expected data
    reg [15:0] data_x_expected, data_y_expected;
    reg error;

    // Derived Parameters
    localparam CLK_PERIOD       = 1E9 / CLK_FREQ;
    localparam SPI_CLK_PERIOD   = 1E9 / SPI_CLK_FREQ;
    //////////////////// 
    // UUT signals
    //////////////////// 
    
    // clks and reset
    reg reset_n;
    reg clk, spi_clk, spi_clk_out;

    // output data
    wire data_update;
    wire [15:0] data_x, data_y;

    // SPI Signals
    wire SPI_SDI, SPI_SDO, SPI_CLK, SPI_CSN;
    // Ground interrupt because it's not used.
    wire [1:0] interrupt;
    assign interrupt = 2'b00;


    ////////////////////////////////
    // Instantuate UUT
    ////////////////////////////////
    spi_control #(
            .SPI_CLK_FREQ   (SPI_CLK_FREQ),
            .UPDATE_FREQ    (UPDATE_FREQ))
        UUT (
            .reset_n    (reset_n),
            .clk        (clk),
            .spi_clk    (spi_clk),
            .spi_clk_out(spi_clk_out),
            .data_update(data_update),
            .data_x     (data_x),
            .data_y     (data_y),
            .SPI_SDI    (SPI_SDI),
            .SPI_SDO    (SPI_SDO),
            .SPI_CSN    (SPI_CSN),
            .SPI_CLK    (SPI_CLK),
            .interrupt  (interrupt)
        );

    // Instantiate spi_secondary_mimic to interact with UUT
    // Set to silend mode
    spi_secondary_mimic #(
            .VERBOSE(0))
        ssm (
            .SPI_SDI    (SPI_SDI),
            .SPI_SDO    (SPI_SDO),
            .SPI_CLK    (SPI_CLK),
            .SPI_CSN    (SPI_CSN)
        );

    // Instantiate file reader
    file_reader fr ();

    // Setup clocks
    // Main clock
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // SPI Clocks
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

    // Main test routine 
    initial begin : TEST
        // Misc signal for the clearing of the interrupt
        reg [7:0] data_dump;
        error = 1'b0;

        if (GENERATE_DUMP == 1) begin
            $dumpfile("spi_control_tb.vcd");
            $dumpvars(0, spi_control_tb);
        end
        secondary_data = $fopen("test/secondary_data.txt", "r");
        // Assert reset
        repeat (3) begin
            @(posedge clk);
            reset_n = 1'b0;
        end
        reset_n = 1'b1;

        // Repeat the requested number of times.
        //
        // Wait for the data_update signal to be asserted.
        //
        // At this point, read data from the secondary_data.txt file and check
        // that the data returned by the simulated spi_control modulde matches
        // the data expected.
        repeat (NUM_SAMPLES) begin
            wait (data_update == 1'b1);
            // Wait one clock cycle to sample data
            repeat (2) @(posedge clk);
            // Make sure data_update is now 0
            if (data_update == 1'b1) begin
                $display("Update signal high for more than one clock cycle");
            end

            // Get the expected data
            fr.get_file_data(secondary_data, data_x_expected[7:0]);
            fr.get_file_data(secondary_data, data_x_expected[15:8]);
            fr.get_file_data(secondary_data, data_y_expected[7:0]);
            fr.get_file_data(secondary_data, data_y_expected[15:8]);
            // Perform read to mimic reading from the status register
            fr.get_file_data(secondary_data, data_dump);
            
            // Compare with received data
            if (data_x_expected != data_x) begin
                error = 1'b1;
                $display("Data X mismatch");
                $display("Expected: %b, Received: %b", data_x_expected, data_x);
            end

            if (data_y_expected != data_y) begin
                error = 1'b1;
                $display("Data Y mismatch");
                $display("Expected: %b, Received: %b", data_y_expected, data_y);
            end
        end
        repeat (10) @(posedge clk);
        if (error) begin
            $display("Test had error");
        end else begin
            $display("Test completed with no errors");
        end

        $finish;
    end
endmodule
