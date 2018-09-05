`timescale 1ns/1ps
module spi_tb();
    // Simulation parameters
    localparam GENERATE_DUMP = 1; // set to 0 to turn off
    localparam LOCAL_CLK_FREQ = 16_000_000;
    localparam SPI_CLK_FREQ = 2_000_000;  // Frequency in HZ
    localparam IDLE_NS = 1000;

    // Defived Parameters
    localparam LOCAL_CLK_PERIOD = 1E9 / LOCAL_CLK_FREQ;
    localparam SPI_CLK_PERIOD = 1E9 / SPI_CLK_FREQ;

    //--------------------
    // Internal signals
    //--------------------
    logic [7:0] data_rx_expected;
    logic isread;
    integer primary_data;
    integer secondary_data;

    // Signals for interfacing to the DUT
    logic           reset_n;
    logic           clk;
    logic           ack_request;
    logic           active;
    // TX Signals
    logic [7:0]     tx_data;
    logic           tx_request;
    // RX Signals
    logic           rx_request;
    logic [7:0]     rx_data;
    logic           rx_valid;

    logic SPI_SDI, SPI_SDO, SPI_CLK, SPI_CSN;

    // Instantiate UUT
    spi #(
            .CLK_FREQUENCY(LOCAL_CLK_FREQ),
            .SPI_FREQUENCY(SPI_CLK_FREQ),
            .IDLE_NS(IDLE_NS)
        ) UUT (
            .reset_n    (reset_n),
            .clk        (clk),
            .ack_request(ack_request),
            .active     (active),
            // tx
            .tx_request (tx_request),
            .tx_data    (tx_data),
            // rx
            .rx_request (rx_request),
            .rx_data    (rx_data),
            .rx_valid   (rx_valid),
            // SPI Side signals
            .spi_sdi    (SPI_SDI),
            .spi_sdo    (SPI_SDO),
            .spi_clk    (SPI_CLK),
            .spi_csn    (SPI_CSN)
        );

    // Initialize instructions.
    // Instruction to execute.
    typedef enum logic [1:0] {
        WRITE,  // Write data to the Secondary
        READ,   // Read data from the secondary
        STALL   // Wait for SPI controller to go idle.
    } opcode_t;

    typedef struct packed {
        opcode_t opcode;
        logic [7:0] data;
    } instruction_t;

    // Create an array of instructions.
    instruction_t instructions[];

    instruction_t current_instruction; 
    opcode_t current_opcode;

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
        clk = 1'b0;
        forever begin
            #(LOCAL_CLK_PERIOD/2);
            clk = ~clk;
        end
    end

    // Standard test
    initial begin
        // Set program.
        instructions = new[3]; 
        instructions = {
            {WRITE, 8'b0001_0101}, // Single write
            {WRITE, 8'b0101_0101}, // Payload
            {STALL, 8'b0000_0000}, // Wait for data high.
            // Single Read
            {WRITE, 8'b1001_0101}, // Single read (bit 7 == 1)
            {READ,  8'b0000_0000}, // Payload
            {STALL, 8'b0000_0000}, // Wait for data high.
            // Multi byte write
            {WRITE, 8'b0101_0101}, // Multi write (bit 6 == 1)
            {WRITE, 8'b0101_0101}, 
            {WRITE, 8'b0101_0101}, 
            {WRITE, 8'b0101_0101}, 
            {WRITE, 8'b0101_0101}, 
            {STALL, 8'b0000_0000},
            // Multi byte read
            {WRITE, 8'b1101_0101}, // Multi write (bit 6 == 1)
            {READ,  8'b0000_0000}, 
            {READ,  8'b0000_0000}, 
            {READ,  8'b0000_0000}, 
            {READ,  8'b0000_0000}, 
            {READ,  8'b0000_0000}, 
            {STALL, 8'b0000_0000}  
        };

        // Configure data dump
        if (GENERATE_DUMP == 1) begin
            $dumpfile("spi_tb.vcd");
            $dumpvars(0, spi_tb);
        end

        // Open data files
        //primary_data    = $fopen("primary_data.txt", "r");
        secondary_data  = $fopen("secondary_data.txt", "r");

        rx_request = 0;
        tx_request = 0;
        // Assert reset
        repeat (3) begin
            reset_n = 1'b0;
            @(posedge clk);
        end
        reset_n = 1'b1;

        // Execute instructions

        foreach (instructions[i]) begin
            // Decode instruction
            current_instruction = instructions[i];
            current_opcode = current_instruction.opcode;

            if (current_opcode == WRITE) begin
                // Set TX data
                tx_data = current_instruction.data; 
                write_spi();
            end else if (current_opcode == READ) begin
                read_spi();
            end else if (current_opcode == STALL) begin
                wait (active == 1'b0);
                clkwait();
            end
        end
        $stop;
    end

    // Wait until the rising edge of the clock, and pause for a short period
    // or time afterward.
    task automatic clkwait;
    begin
        @(posedge clk);
        #1;
    end
    endtask

    task write_spi;
    begin
        $display("PRIMARY: transmit %b", tx_data);
        tx_request = 1'b1;

        // Wait for request to be acknowledged.
        wait (ack_request == 1'b1);
        clkwait();

        tx_request = 1'b0;
    end
    endtask

    task read_spi;
    begin
        // Emit a rx request
        rx_request = 1'b1;

        // Wait for acknowledgement.
        wait(ack_request);
        clkwait();
        rx_request = 1'b0;

        // Wait for data to be available and check.
        wait (rx_valid);
        $display("PRIMARY: recieve %b", rx_data);
        fr.get_file_data(secondary_data, data_rx_expected);
        if (data_rx_expected != rx_data) begin
            $display("    Data Mismatch");
            $display("    Expected: %b. Received %b", data_rx_expected, rx_data);
        end
    end
    endtask
endmodule
