/*
Description: Very simple UART tx/rx module.  Requires a streaming interface,
provides no buffering for input or output data.
*/

module uart
#(    parameter CLK_FREQ = 50_000_000,
      parameter BAUD     = 115_200
)
(     input clk,
      input reset,

      // Receiving
      input             rx,         // Received serial stream
      output reg [7:0]  rx_data,    // Deserialized byte.
      output            rx_valid,   // Asserted when rx_data is valid

      // Transmitting
      output reg  tx,               // Transmitted serial stream
      input [7:0] tx_data,          // Deserialized byte to transmit.
      input       tx_transmit,      // Start Signal. No effect if tx_ready = 0
      output reg  tx_ready          // Asserted when ready to accept data
   );

   ///////////////////////////////
   // Functionality Description //
   ///////////////////////////////

   /*
   RECEIVING: Module receives a serial stream through the port rx.
   When a byte has been successfully received, the received data will be
   available on the output port rx_data and the output port rx_valid will be
   asserted for 1 clock cycle.

   Validity of output data is not guaranteed if rx_valid is not 1. If this
   is important for you, you may modify this design to register the output.

   TRANSMITTING: When input port tx_transmit is 1 (asserted), module will
   store the data on the input port tx_data and serialize through the output
   port tx.

   Module will only save and transmit the data at tx_data if the signal
   tx_ready is asserted when tx_transmit is asserted. This module will not
   buffer input data. While transmitting, tx_ready is deasserted and the
   input port tx_transmit will have no effect.

   Once tx_ready is deasserted, data at port tx_data is not used and need
   not be stable.
   */

   /////////////////////////
   // Signal Declarations //
   /////////////////////////

   // ---------------------- //
   // -- Local Parameters -- //
   // ---------------------- //

   // Number of synchronization stages to avoid metastability
   localparam SYNC_STAGES = 2;

   // Over Sampling Factor
   localparam OSF = 16;

   // Compute count to generate local clock enable
   localparam CLK_DIV_COUNT = CLK_FREQ / (OSF * BAUD);

   // ---------------------------- //
   // -- Clock Dividing Counter -- //
   // ---------------------------- //

   reg [15:0] count;
   reg enable;       // Local Clock Enable

   // -- RX Synchronizer --
   reg [SYNC_STAGES-1:0] rx_sync;
   reg rx_internal;

   // ---------------- //
   // -- RX Signals -- //
   // ---------------- //

   // State Machine Assignments
   localparam RX_WAIT            = 0;
   localparam RX_CHECK_START     = 1;
   localparam RX_RECEIVING       = 2;
   localparam RX_WAIT_FOR_STOP   = 3;

   localparam RX_INITIAL_STATE = RX_WAIT;
   reg [1:0] rx_state = RX_INITIAL_STATE;

   reg [4:0] rx_count;        // Counts Over-sampling clock enables
   reg [2:0] rx_sampleCount;  // Counts number of bits received

   // These last two signals are used to make sure the "rx_valid" signal
   // is only asserted for one clock cycle.

   reg rx_validInternal, rx_validLast;

   // -----------------//
   // -- TX Signals -- //
   // -----------------//

   // State Machine Assignments
   localparam TX_WAIT         = 0;
   localparam TX_TRANSMITTING = 1;

   localparam TX_INITIAL_STATE = TX_WAIT;
   reg tx_state = TX_INITIAL_STATE;

   reg [9:0] tx_dataBuffer;   // Capture Register for transmitted data
   reg [4:0] tx_count;        // Counts over-sampling clock
   reg [3:0] tx_sampleCount;  // Number of Bits Sent

   /////////////////////
   // Implementations //
   /////////////////////

   // ---------------------------- //
   // -- Misc Synchronous Logic -- //
   // ---------------------------- //

   always @(posedge clk) begin

      // Clock Divider
      if (reset) begin
         count <= 0;
         enable <= 0;
      end else if (count == CLK_DIV_COUNT - 1) begin
         count <= 0;
         enable <= 1;
      end else begin
         count <= count + 1;
         enable <= 0;
      end

      // RX Synchronizer
      if (enable) begin
         {rx_sync,rx_internal} <= {rx, rx_sync};
      end

      // Pulse Shortener for rx_valid signal
      rx_validLast <= rx_validInternal;
   end

   // Pulse Shortner for rx_valid signal
   assign rx_valid = rx_validInternal & ~rx_validLast;


   // ---------------------- //
   // -- RX State Machine -- //
   // ---------------------- //

   always @(posedge clk) begin
      if (reset) begin
         rx_state <= RX_INITIAL_STATE;
         rx_validInternal <= 0;
      end else if (enable) begin
         case (rx_state)

            // Wait for the start bit. (RX = 0)

            RX_WAIT: begin
               rx_validInternal <= 0;
               if (rx_internal == 0) begin
                  rx_state <= RX_CHECK_START;
                  rx_count <= 1;
               end
            end

            // Aligh with center of transmitted bit

            RX_CHECK_START: begin

               // Check if RX is still 0
               if (rx_count == (OSF >> 1) - 1 && rx_internal == 0) begin
                  rx_state <= RX_RECEIVING;
                  rx_count <= 0;
                  rx_sampleCount <= 0;

               // Faulty Start Bit
               end else if (rx_count == (OSF >> 1) - 1 && rx_internal == 1) begin
                  rx_state <= RX_WAIT;

               // Default Option: Count local clocks
               end else begin
                  rx_count <= rx_count + 1;
               end
            end

            // Sample in middle of received bit. Shift data into rx_data
            RX_RECEIVING: begin
               if (rx_count == OSF - 1) begin
                  rx_count <= 0;
                  rx_data <= {rx_internal, rx_data[7:1]};
                  rx_sampleCount <= rx_sampleCount + 1;

                  // Check if this is the last bit of data
                  if (rx_sampleCount == 7) begin
                     rx_state <= RX_WAIT_FOR_STOP;
                  end
               end else begin
                  rx_count <= rx_count + 1;
               end
            end

            // Wait until stop bit is received
            // Not the best logic in the world, but it works.
            RX_WAIT_FOR_STOP: begin
               if (rx_internal == 1'b1) begin
                  rx_state <= RX_WAIT;
                  rx_validInternal <= 1;
               end
            end

            // In case something goes horribly wrong.
            default: begin
               rx_state <= RX_INITIAL_STATE;
            end
         endcase
      end
   end

   // ---------------------- //
   // -- TX State Machine -- //
   // ---------------------- //

   always @(posedge clk) begin
      if (reset) begin
         tx_state <= TX_INITIAL_STATE;
         tx <= 1;
      end else begin
         case (tx_state)
            // Wait for start signal.
            // Register transmitted data and deassert ready.
            TX_WAIT: begin
               tx <= 1;
               if (tx_transmit) begin
                  tx_dataBuffer <= {1'b1, tx_data, 1'b0};
                  tx_count <= 0;
                  tx_sampleCount <= 0;
                  tx_ready <= 0;
                  tx_state <= TX_TRANSMITTING;
               end else begin
                  tx_ready <= 1;
               end
            end

            // Shift Out Data
            TX_TRANSMITTING: begin
               if (enable) begin
                  if (tx_count == OSF - 1) begin
                     tx_count <= 0;
                     tx_sampleCount <= tx_sampleCount + 1;
                     tx <= tx_dataBuffer[0];
                     tx_dataBuffer <= {1'b1, tx_dataBuffer[9:1]};
                     if (tx_sampleCount == 9) begin
                        tx_state <= TX_WAIT;
                     end
                  end else begin
                     tx_count <= tx_count + 1;
                  end
               end
            end

            default: begin
               tx_state <= TX_WAIT;
            end
         endcase
      end
   end
endmodule
