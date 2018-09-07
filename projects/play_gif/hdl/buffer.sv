module buffer #(
        // Size of Reads and Writes to the External Bridge to Avalon Bus
        // System
        parameter INTERFACE_WIDTH_BITS  = 128,
        // Number of entries in the Buffer
        parameter NUM_BUFFER_ENTRIES    = 64,
        // Number of bits used for the interface address space
        parameter INTERFACE_ADDR_BITS   = 26 
    )(
        // CLOCKS //

        // Clock for the interface to the QSYS system
        input interface_clock,
        // Clock used by the VGA circuitry.
        input read_clock,
        // System reset
        input reset_n,

        // QSYS INTERFACE //
        output [INTERFACE_ADDR_BITS-1:0]        interface_address,
        output [(INTERFACE_WIDTH_BITS / 8)-1:0] interface_byte_enable,
        output logic                            interface_read,
        output                                  interface_write,
        input [INTERFACE_WIDTH_BITS-1:0]        interface_read_data,
        output [INTERFACE_WIDTH_BITS-1:0]       interface_write_data,
        input                                   interface_acknowledge,

        // General Module IO
        input [$clog2(NUM_BUFFER_ENTRIES)-1:0] read_address,
        output [INTERFACE_WIDTH_BITS-1:0]      read_data,

        // When asserted, begin buffering the next row.
        input start,
        // Byte address to begin buffering from.
        input [INTERFACE_ADDR_BITS-1:0] base_address,

        // Error indication
        output logic    timing_error,
        input           timing_error_reset
    );

// ------------------- //
// Computed parameters //
// ------------------- //

// Number of bytes read at a time.
localparam INTERFACE_WIDTH_BYTES = INTERFACE_WIDTH_BITS / 8;

// Number of bits needed to address the buffer.
localparam BUFFER_ADDR_WIDTH = $clog2(NUM_BUFFER_ENTRIES);

// ------------------- //
// Signal declarations //
// ------------------- //

// Line buffer memory.
logic [INTERFACE_WIDTH_BITS-1:0] buffer [NUM_BUFFER_ENTRIES-1:0];
// Line buffer write signals
logic                             buffer_write_enable;
logic [BUFFER_ADDR_WIDTH-1:0]     buffer_write_addr;
logic [INTERFACE_WIDTH_BITS-1:0] buffer_write_data;
// Line buffer read signals
logic [BUFFER_ADDR_WIDTH-1:0]    buffer_read_addr;
logic [INTERFACE_WIDTH_BITS-1:0]  buffer_read_data;

// Save the base address so the user of this module can change the input after
// this module starts buffering.
logic [INTERFACE_ADDR_BITS-1:0] base_address_reg;

// Need to ensure that the start signals is only asserted for one clock cycle
// to make timing error detection easier.
//
// Keep a history of the last state of the start signals so we can detect the
// rising edge.
logic start_last;
logic start_rising_edge;

// LINE BUFFER STATE MACHINE
typedef enum logic {IDLE, BUFFERING} state_t;
state_t buffer_state, buffer_state_next;

localparam state_t BUFFER_RESET_STATE = IDLE;

// Next state signals
logic [BUFFER_ADDR_WIDTH-1:0] buffer_write_addr_next;
logic [INTERFACE_ADDR_BITS-1:0] base_address_reg_next;
logic timing_error_next;

// -------------------- //
// CONSTANT ASSIGNMENTS //
// -------------------- //

// Never write to the QSYS system.
assign interface_write = 0;
assign interface_write_data = 0;
// Always read all bytes at a time.
assign interface_byte_enable = (2 ** INTERFACE_WIDTH_BYTES) - 1;

////////////////////////////////////////////////////////////////////////////////
// IMPLEMENTATION
////////////////////////////////////////////////////////////////////////////////

// ----------- //
// Line Buffer //
// ----------- //

// Writes - align with interface clock
always @(posedge interface_clock) begin
    if (buffer_write_enable) begin
        buffer[buffer_write_addr] <= buffer_write_data;
    end
end

// Reads - align with system clock
always @(posedge read_clock) begin
    buffer_read_data <= buffer[buffer_read_addr];
end
assign buffer_read_addr = read_address;
assign read_data = buffer_read_data;

// Write data logic
assign buffer_write_data = interface_read_data;
assign interface_address = base_address_reg + (buffer_write_addr * INTERFACE_WIDTH_BYTES);

////////////////////////////////////////////////////////////////////////////////
// Buffer State machine
////////////////////////////////////////////////////////////////////////////////

// Edge detection for start signal
always @(posedge interface_clock) begin
    start_last <= start;
end
assign start_rising_edge = start_last == 1'b0 && start == 1'b1;

// Next state assignments
always @(posedge interface_clock) begin
    if (reset_n == 1'b0) begin
        buffer_state        <= BUFFER_RESET_STATE;
        base_address_reg    <= 0;
        buffer_write_addr   <= 0;
        timing_error        <= 0;
    end else begin
        buffer_state       <= buffer_state_next;
        base_address_reg   <= base_address_reg_next;
        buffer_write_addr  <= buffer_write_addr_next;
        timing_error       <= timing_error_next;
    end
end

// Next state logic
always @(*) begin
    // Default holding logic.
    buffer_state_next      = buffer_state;
    base_address_reg_next  = base_address_reg;
    buffer_write_addr_next = buffer_write_addr;

    // Default outputs.
    buffer_write_enable = 1'b0;
    interface_read = 1'b0;

    // Timing error indication
    if (timing_error_reset) begin
       timing_error_next = 1'b0;
    end else begin
       timing_error_next = timing_error;
    end

    case (buffer_state)
        IDLE: begin
            // Wait until falling edge of disp_ena. This indicates that a row
            // has just been written to the display and we should begin
            // buffering data during the downtime of h_sync.
            if (start_rising_edge) begin
                base_address_reg_next = base_address;

                // Zero out the column we are reading.
                buffer_write_addr_next = 0;

                // Branch to the buffering state
                buffer_state_next = BUFFERING;
            end
        end

        BUFFERING: begin
            // Error checking for timing.
            if (start_rising_edge) begin
                timing_error_next = 1'b1;
            end
            
            // Hold this signal high as long as we're in this state. New read
            // requests happen immediately after one completes.
            interface_read = 1'b1;

            // Don't do anything unless the interface has acknowledged the
            // read request.
            if (interface_acknowledge) begin
                buffer_write_enable = 1'b1;
                buffer_write_addr_next = buffer_write_addr + 1'b1;

                // Loop until all pixels in the column have been buffered.
                if (buffer_write_addr == NUM_BUFFER_ENTRIES - 1) begin
                    buffer_state_next = IDLE;
                end
            end

        end
    endcase
end

endmodule
