`timescale 1ns/1ns
module gsensor_tb;

localparam CLK_FREQUENCY = 16_000_000;
localparam SPI_FREQUENCY =  2_000_000;
localparam IDLE_NS = 500;
localparam UPDATE_FREQUENCY = 50;

// Interface signals
logic reset_n, clk;
logic data_valid;
logic [15:0] data_x, data_y, data_z;

logic SPI_SDI, SPI_SDO, SPI_CSN, SPI_CLK;

// Instantiate DUT
gsensor #(
    .CLK_FREQUENCY (CLK_FREQUENCY),
    .SPI_FREQUENCY (SPI_FREQUENCY),
    .IDLE_NS (IDLE_NS),
    .UPDATE_FREQUENCY (UPDATE_FREQUENCY)
) DUT (.*); 

// Instantiate mimic
spi_secondary_mimic mimic (.*);

// Stup clock
localparam CLK_PERIOD = 1E9 / CLK_FREQUENCY;
initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD / 2) clk = ~clk;
end

// Test routine - wait for done flag.
initial begin
    reset_n = 1'b0;
    repeat (10) @(posedge clk);
    reset_n = 1'b1;

    wait (data_valid);
    $stop;
end

endmodule // gsensor_tb
