`timescale 1ns/1ns

module buffer_tb();

// Set up the big parameters used by the buffer module.
// The big ones to vary should be INTERFACE_WIDTH_BITS and NUM_BUFFER_ENTRIES.
//
// Varying INTERFACE_ADDR_BITS shouldn't change the functionality TOO much.
// The module does not implement any checking for going out-of-bounds for the
// address.
localparam INTERFACE_WIDTH_BITS     = 128;
localparam NUM_BUFFER_ENTRIES       = 64;
localparam INTERFACE_ADDR_BITS      = 26;

// Derived parameters. Don't touch these.
localparam INTERFACE_WIDTH_BYTES = INTERFACE_WIDTH_BITS / 8;


// Parameters for testing.
localparam INTERFACE_CLOCK_FREQ_HZ = 100_000_000;
localparam READ_CLOCK_FREQ_HZ      =  25_000_000;
localparam TEST_ITERATIONS         = 10;


// Signals to connect to DUT
logic interface_clock, read_clock;
logic reset_n;
logic [INTERFACE_ADDR_BITS-1:0] interface_address;
logic [INTERFACE_WIDTH_BYTES-1:0] interface_byte_enable;
logic interface_read;
logic interface_write;

logic [INTERFACE_WIDTH_BITS-1:0] interface_read_data;
logic [INTERFACE_WIDTH_BITS-1:0] interface_write_data;
logic interface_acknowledge;

logic [$clog2(NUM_BUFFER_ENTRIES)-1:0] read_address;
logic [INTERFACE_WIDTH_BITS-1:0] read_data;

logic start;
logic [INTERFACE_ADDR_BITS-1:0] base_address;

logic timing_error;
logic timing_error_reset;

// Instantiate DUT
buffer #(
    .INTERFACE_WIDTH_BITS   (INTERFACE_WIDTH_BITS),
    .NUM_BUFFER_ENTRIES     (NUM_BUFFER_ENTRIES),
    .INTERFACE_ADDR_BITS    (INTERFACE_ADDR_BITS)
) DUT (
    // clocks
    .interface_clock        (interface_clock),
    .read_clock             (read_clock),
    .reset_n                (reset_n),
    // avalong interface
    .interface_address      (interface_address),
    .interface_byte_enable  (interface_byte_enable),
    .interface_read         (interface_read),
    .interface_write        (interface_writes),
    .interface_read_data    (interface_read_data),
    .interface_write_data   (interface_write_data),
    .interface_acknowledge  (interface_acknowledge),
    // general io
    .read_address           (read_address),
    .read_data              (read_data),
    .start                  (start),
    .base_address           (base_address),
    .timing_error           (timing_error),
    .timing_error_reset     (timing_error_reset)
);

//------------------------------------------------------------------------------
//
// OUTLINE
//
// A routine will be set up that will service reads generated by the buffer.
// As it provides data to the buffer, it will also store that data in
// an array.
//
// A main test routine will generate the "start" signal. After a period of
// time, it will begin reading from the buffer and checking if the retrieved
// data matches the sent data.

//------------------------------------------------------------------------------
// Local signals for Testbench.

// Array for recording the reads.
logic [INTERFACE_WIDTH_BITS-1:0] generated_reads [NUM_BUFFER_ENTRIES-1:0];
// Index into the "generated_reads" array.
int read_pointer;


// Set up system clocks
initial begin
    interface_clock = 1'b0;
    forever #(1E9 / INTERFACE_CLOCK_FREQ_HZ) interface_clock = ~interface_clock;
end
initial begin
    read_clock = 1'b0;
    forever #(1E9 / READ_CLOCK_FREQ_HZ) read_clock = ~read_clock;
end

//------------------------------------------------------------------------------
// Main test loop
//
task assert_reset();
    reset_n = 1'b0;
    @(posedge read_clock);
    reset_n = 1'b1;
endtask

// Assert reset for one clock cycle.
task assert_timing_reset();
    timing_error_reset = 1'b1;
    @(posedge read_clock);
    timing_error_reset = 1'b0;
endtask

// Assert the start signal and reset the read pointer
task assert_start();
    start = 1'b1;
    read_pointer = 0;
    @(posedge read_clock);
    start = 1'b0;
endtask

// Set up a routine to service reads generated by the buffer after a small
// random number of clock cycles.
initial begin : read_handler
    // Local variable to check read address
    logic [INTERFACE_ADDR_BITS-1:0] this_interface_read_address;

    // Read value
    logic [INTERFACE_WIDTH_BITS-1:0] this_read_data;

    // Number of stall cycles
    logic [4:0] stall_cycles;

    forever begin
        // Wait until "interface_read" is asserted, then begin handling the
        // read. Since the buffer holds this signal high, we can't search for
        // transistions in the signal.
        wait(interface_read == 1'b1);


        // De-assert the "interface_acknowledge" signal.
        interface_acknowledge = 1'b0;

        // Check that the address is correct.
        // Each address points to a byte. Should increment from the base
        // address. We can tell how many reads have been generated by looking
        // at the read pointer.
        assert(interface_address == base_address + INTERFACE_WIDTH_BYTES * read_pointer); 

        // Need to stall for a random number of clock cycles, but also verify that
        // the "interface_read" and "interface_address" signals do not change
        // until the acknowledge is asserted.
        //
        // Use a fork-join construct.

        this_interface_read_address = interface_address;

        fork
            begin
                // stall until signals change.
                wait (interface_address != this_interface_read_address || 
                        interface_read == 1'b0);

                $error("Interface signal error while waiting for read to be serviced.");
            end
            begin
                // Stall for this many cycles
                stall_cycles = $urandom_range(20,8);
                for (int i = 0; i < stall_cycles; i++) begin
                    @(posedge interface_clock);
                end

                // Generate a random number for the read. Do some checking on the
                // read pointer for some bounds checking.
                //
                // Can use the "std::randomize" to generate an arbitrary "n-bit"
                // randomization.
                std::randomize(this_read_data);

                // Check the read pointer if it is out of bounds. This should be
                // reset by the main routine every time it asserts "start".
                if (read_pointer >= NUM_BUFFER_ENTRIES) begin
                    $error("Read pointer out of bounds.");
                end

                generated_reads[read_pointer] = this_read_data;
                read_pointer = read_pointer + 1;

                // Set the external signals.
                interface_read_data = this_read_data; 
                interface_acknowledge = 1'b1;
            end
        join_any
        disable fork;

        // Wait one clock cycle and then kill then acknowledge signals.
        @(posedge interface_clock);
        interface_acknowledge = 1'b0; 

        // Now we repeat the loop again!!
        // Wait until the falling edge of the main clock before starting loop
        // again so we don't immediately kick off the next iteration and then
        // see the address change.
        @(negedge interface_clock);
    end
end

// Set up a watcher for timing errors.
always @(posedge timing_error) begin
    $error("A timing error was generated!");
    repeat (3) @(posedge read_clock);
    assert_timing_reset();
end

initial begin : main_test

    //-- Local variables
    
    // Number of cycles to stall before reading
    int stall_cycles; 

    // Set this to 0. Not testing the full capabilities of this thing, but
    // I don't think that is completely necessary in this case.
    base_address    = 0;
    start           = 1'b0;
    reset_n         = 1'b1;
    interface_acknowledge = 1'b0;

    assert_reset();
    assert_timing_reset();

    for (int i = 0; i < TEST_ITERATIONS; i++) begin
        assert_start();

        stall_cycles = $urandom_range(100,50);
        for (int j = 0; j < stall_cycles; j++) begin
            @(posedge read_clock);
        end

        // Begin reading from the buffer. Check that the data returned matches
        // what is recorded in the "generated_reads" buffer.
        //
        // NOTE: There is a 1 clock cycle delay for these reads.
        for (int addr = 0; addr < NUM_BUFFER_ENTRIES; addr++) begin
            read_address = addr;
            @(posedge read_clock);
            // Wait for one more time step to wait for the non-blocking
            // assignment to "read_data" to take effect.
            #1 assert(read_data == generated_reads[addr]);
            // Wait for a few more cycles.
            repeat (8) @(posedge read_clock);
        end 
    end

    $stop;
end

endmodule
