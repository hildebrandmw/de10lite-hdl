module uart_handler
#( parameter RAM_SIZE = 64,
   parameter ADDR_BITS = 5
)
(  input wire clk,
   input wire reset,

   // RS232 Signals
   output wire UART_TX,
   input  wire UART_RX,

   // Interfacing Signals
   input  wire [ADDR_BITS-1:0]  addr,
   input  wire                  write_enable,
   input  wire [7:0]            data_in,
   output wire [7:0]            data_out,

   // Start and Ready Signals
   input  wire start,
   output reg  ready
   );

   ///////////////////////////
   /// SIGNAL DECLARATIONS ///
   ///////////////////////////

   //-------------//
   // RAM Signals //
   //-------------//

   reg [7:0] mem [RAM_SIZE-1:0] /* synthesis ramstyle = "M4K" */;

   // Specify initial contents to zero.
   initial begin : RAM_INIT
      integer i;
      for (i = 0; i < RAM_SIZE; i = i+1) begin
         mem[i] = 0;
      end
   end

   // Data
   reg [7:0] ram_data;

   // Separate signals for
   //   - externally supplied
   //   - internally supplied
   //   - actual (multiplexed between external and internal)
   reg  [ADDR_BITS-1:0] addr_internal;
   reg  [ADDR_BITS-1:0] addr_internal_next;
   wire [ADDR_BITS-1:0] addr_actual;

   reg  write_en_internal;
   wire write_en_actual;

   wire [7:0] ram_data_in_actual;

   //---------------//
   // State Machine //
   //---------------//

   // State Machine Parameters and Signals
   localparam PREPARE_TO_RECEIVE        = 0;
   localparam RECEIVING_UART            = 1;
   localparam IDLE                      = 2;
   localparam PREPARE_TO_TRANSMIT       = 3;
   localparam TRANSMIT_WAIT_FOR_READY   = 4;
   localparam TRANSMIT_DATA             = 5;

   localparam RESET_STATE = PREPARE_TO_RECEIVE;

   // State Signals
   reg [2:0] state, next_state;

   // Output Signals
   reg en_external_addressing;

   //----------------//
   // UART Interface //
   //----------------//

   // From UART
   //  wire fromUartReady;
   wire [7:0] from_uart_data;
   wire fromUartError;
   wire from_uart_valid;

   // To UART
   wire       to_uart_ready;
   wire [7:0] to_uart_data;
   reg        to_uart_valid;
   // wire toUartError;


   /////////////////////
   // IMPLEMENTATIONS //
   /////////////////////

   //-----//
   // RAM //
   //-----//

   /*
   While this module is receiving or transmitting data from the UART module,
   it has total control over this RAM module.

   Otherwise, "en_external_addressing" is asserted and an external module
   has control.
   */

   assign addr_actual        = en_external_addressing ? addr         : addr_internal;
   assign write_en_actual    = en_external_addressing ? write_enable : write_en_internal;
   assign ram_data_in_actual = en_external_addressing ? data_in      : from_uart_data;

   assign data_out      = ram_data;
   assign to_uart_data  = ram_data;

   // RAM READ/WRITE
   always @(posedge clk) begin
      ram_data <= mem[addr_actual];
      if (write_en_actual) begin
         mem[addr_actual] <= ram_data_in_actual;
      end
   end

   //---------------------//
   // RS232 INSTANTIATION //
   //---------------------//

   // Instantiation
   uart u0 (
      // Global Signals
      .clk  (clk),
      .reset(reset),
      .tx   (UART_TX),
      .rx   (UART_RX),

      // From Uart
      .rx_data  (from_uart_data),
      .rx_valid (from_uart_valid),

      // To Uart
      .tx_ready     (to_uart_ready),
      .tx_data      (to_uart_data),
      .tx_transmit  (to_uart_valid)
   );

   //---------------//
   // STATE MACHINE //
   //---------------//

   // Update State
   always @(posedge clk) begin

      // State Update
      if (reset) begin
         state <= RESET_STATE;
      end else begin
         state <= next_state;
      end

      // Addressing Update
      addr_internal <= addr_internal_next;
   end

   // Next State Logic
   always @(*) begin
      // Default Next State (avoid inferring latches)
      next_state         = state;
      addr_internal_next = addr_internal;

      // Default Output Values
      write_en_internal      = 0; // Local RAM Write Enable
      en_external_addressing = 0; // Hand RAM control to external module if 1
      to_uart_valid          = 0; // Valid Data if 1
      ready                  = 0;

      case(state)

         // Initialize local components if necessary
         PREPARE_TO_RECEIVE: begin
            addr_internal_next = 0;
            next_state = RECEIVING_UART;
         end

         // Store Data when it arrives.
         // Exit when expected amount of data received
         RECEIVING_UART: begin
            if (from_uart_valid) begin
               addr_internal_next = addr_internal + 1;
               write_en_internal = 1;
               if (addr_internal == RAM_SIZE - 1) begin
                  next_state = IDLE;
               end
            end
         end

         // Hand Control to external Module.
         // Wait for assertion of "start"
         IDLE : begin
            en_external_addressing = 1;
            ready = 1;
            if (start) begin
               next_state = PREPARE_TO_TRANSMIT;
            end
         end

         // Initialize local components if necessary
         PREPARE_TO_TRANSMIT : begin
            addr_internal_next = 0;   // Reset local addresser
            next_state = TRANSMIT_WAIT_FOR_READY;
         end

         // Stall until UART is ready to transmit the next byte
         TRANSMIT_WAIT_FOR_READY : begin
            if (to_uart_ready) begin
               next_state = TRANSMIT_DATA;
            end
         end

         // Transmit One Byte of data.
         // Repeat for each entry in the the RAM.
         TRANSMIT_DATA : begin
            to_uart_valid = 1;
            addr_internal_next = addr_internal + 1;

            // Test is last RAM entry is written
            if (addr_internal == RAM_SIZE - 1) begin
               next_state = PREPARE_TO_RECEIVE;
            end else begin
               next_state = TRANSMIT_WAIT_FOR_READY;
            end
         end
         default;
      endcase
   end

endmodule
