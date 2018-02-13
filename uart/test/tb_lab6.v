`timescale 1ns/1ps

module tb_lab6;

   localparam BAUD_RATE = 115200;
   localparam RAM_SIZE = 8;
   localparam ADDR_BITS = 3;
   // Define Operating Conditions
   localparam TINT     = 2'b00;
   localparam INVERT   = 2'b01;
   localparam THRESHOLD= 2'b10;
   localparam CONTRAST = 2'b11;

   localparam testMode = TINT;
   reg clk, reset;
   reg [1:0] mode;

   // UART SIGNALS
   reg UART_RX;
   wire UART_TX;

   reg [7:0] testData;

   // Derived Parameters
   localparam BAUD_DELAY = 10 ** 9 / BAUD_RATE;

   // Instantiate Device Under Test
   lab6 UUT (
      .CLOCK_50(clk),
      .KEY(reset),
      .SW(mode),
      .UART_RXD(UART_RX),
      .UART_TXD(UART_TX)
      );

   // Setup 50 MHz clock Clock
   initial begin
      clk = 0;
      forever #10 clk = ~clk;
   end


   // BAUD Transmit Task
   integer j;
   task uartTransmit;
      input [7:0] data;
         begin
         // Start Bit
         UART_RX = 0;
         #BAUD_DELAY;
         // Data Packet
         for (j = 0; j < 8; j = j+1) begin
            UART_RX = data[j];
            #BAUD_DELAY;
         end
         // Stop Bit
         UART_RX = 1;
         #BAUD_DELAY;
      end
   endtask

   // Test Setup
   integer i;
   initial begin
      UART_RX = 1;
      reset = 0;
      mode = testMode;
      repeat (2) @(posedge clk);
      reset = 1;
      repeat (2) @(posedge clk);
      // Initialize Data
      for (i = 0; i < RAM_SIZE; i = i+1) begin
         testData = 255/RAM_SIZE * i;
         uartTransmit(testData);
      end

      // Wait for processing and transmitting
      #(RAM_SIZE * 10 * BAUD_DELAY + 50 * RAM_SIZE);

      $stop;
   end



endmodule
