module uart_handler
#( parameter RAM_SIZE = 64,
   parameter ADDR_BITS = 5
)
(  input wire clk,
   input wire reset,

   // RS232 Signals
   output wire UART_TX,
   input wire UART_RX,

   // Interfacing Signals
   input  wire [ADDR_BITS-1:0] addr,
   input  wire writeEnable,
   input  wire [7:0] dataIn,
   output wire [7:0] dataOut,

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

   initial begin : RAM_INIT
      integer i;
      for (i = 0; i < RAM_SIZE; i = i+1) begin
         mem[i] = 0;
      end
   end

   // Data
   reg [7:0] ramData;

   reg [ADDR_BITS-1:0] addrInternal;
   reg [ADDR_BITS-1:0] addrInternalNext;
   wire [ADDR_BITS-1:0] addrActual;

   reg writeEnableInternal;
   wire writeEnableActual;

   wire [7:0] ramDataInActual;

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
   reg [2:0] state, nextState;

   // Output Signals
   reg enableExternalAddressing;

   //----------------//
   // UART Interface //
   //----------------//

   // From UART
   //  wire fromUartReady;
   wire [7:0] fromUartData;
   wire fromUartError;
   wire fromUartValid;

   // To UART
   wire toUartReady;
   wire [7:0] toUartData;
   reg toUartValid;
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

   Otherwise, "enableExternalAddressing" is asserted and an external module
   has control.
   */

   assign addrActual        = enableExternalAddressing ? addr        : addrInternal;
   assign writeEnableActual = enableExternalAddressing ? writeEnable : writeEnableInternal;
   assign ramDataInActual   = enableExternalAddressing ? dataIn      : fromUartData;

   // RAM READ
   //assign ramData = mem[addrActual];
   assign dataOut = ramData;
   assign toUartData = ramData;

   // RAM WRITE
   always @(posedge clk) begin
      ramData <= mem[addrActual];
      if (writeEnableActual) begin
         mem[addrActual] <= ramDataInActual;
      end
   end

   //---------------------//
   // RS232 INSTANTIATION //
   //---------------------//

   // Instantiation
   uart u0 (
      // Global Signals
      .clk(clk),
      .reset(reset),
      .tx(UART_TX),
      .rx(UART_RX),

      // From Uart
      .rx_data(fromUartData),
      .rx_valid(fromUartValid),

      // To Uart
      .tx_ready(toUartReady),
      .tx_data(toUartData),
      .tx_transmit(toUartValid)
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
         state <= nextState;
      end

      // Addressing Update
      addrInternal <= addrInternalNext;
   end

   // Next State Logic
   always @(*) begin
      // Default Next State (avoid inferring latches)
      nextState = state;
      addrInternalNext = addrInternal;

      // Default Output Values

      writeEnableInternal = 0;      // Local RAM Write Enable
      enableExternalAddressing = 0; // Hand RAM control to external module if 1
      toUartValid = 0;              // Valid Data if 1
      ready = 0;

      case(state)

         // Initialize local components if necessary
         PREPARE_TO_RECEIVE: begin
            addrInternalNext = 0;
            nextState = RECEIVING_UART;
         end

         // Store Data when it arrives.
         // Exit when expected amount of data received
         RECEIVING_UART: begin
            if (fromUartValid) begin
               addrInternalNext = addrInternal + 1;
               writeEnableInternal = 1;
               if (addrInternal == RAM_SIZE - 1) begin
                  nextState = IDLE;
               end
            end
         end

         // Hand Control to external Module.
         // Wait for assertion of "start"
         IDLE : begin
            enableExternalAddressing = 1;
            ready = 1;
            if (start) begin
               nextState = PREPARE_TO_TRANSMIT;
            end
         end

         // Initialize local components if necessary
         PREPARE_TO_TRANSMIT : begin
            addrInternalNext = 0;   // Reset local addresser
            nextState = TRANSMIT_WAIT_FOR_READY;
         end

         // Stall until UART is ready to transmit
         TRANSMIT_WAIT_FOR_READY : begin
            if (toUartReady) begin
               nextState = TRANSMIT_DATA;
            end
         end

         // Transmit One Data Packet
         TRANSMIT_DATA : begin
            toUartValid = 1;
            addrInternalNext = addrInternal + 1;

            // Test is last RAM entry is written
            if (addrInternal == RAM_SIZE - 1) begin
               nextState = PREPARE_TO_RECEIVE;
            end else begin
               nextState = TRANSMIT_WAIT_FOR_READY;
            end
         end
         default;
      endcase
   end

endmodule
