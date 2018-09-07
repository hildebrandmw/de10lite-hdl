// Simple module for providing stimulus to the module and recording the
// results to a dumpfile
`timescale 1ns/1ns
module vga_timer_tb();
    // Configure display for 640x480 resolution.
    // If configuring for operation other than 640x480, must change timing
    // parameters in UUT.
    localparam NUM_COLS = 640;
    localparam NUM_ROWS = 480;
    localparam CLOCK_PERIOD = 40; // (25 MHz -> 40 ns period)

    // Set to 1 to save all signals to a "vcd" file.
    localparam DUMP_SIGNALS = 0;

    localparam COL_WIDTH = $clog2(NUM_COLS-1);
    localparam ROW_WIDTH = $clog2(NUM_ROWS-1);

    // Signals for connecting to module.
    reg clk;
    reg reset_n;

    wire h_sync, v_sync;
    wire disp_ena;
    wire end_line;
    wire end_frame;

    wire [COL_WIDTH-1:0] col;
    wire [ROW_WIDTH-1:0] row;

    // Instantiate UUT
    vga_timer #(
            .COL_WIDTH(COL_WIDTH),
            .ROW_WIDTH(ROW_WIDTH)
        ) UUT (
            .clk        (clk),
            .reset_n    (reset_n),
            .h_sync     (h_sync),
            .v_sync     (v_sync),
            .disp_ena   (disp_ena),
            .col        (col),
            .row        (row),
            .end_line   (end_line),
            .end_frame  (end_frame)
        );
    // Setup clock
    initial begin
        clk = 1'b0;
        forever #(CLOCK_PERIOD/2) clk = ~clk;
    end
    // Begin test
    initial begin
        // Open up dump file
        if (DUMP_SIGNALS) begin
            $dumpfile("vga_timer_tb.vcd");
            $dumpvars(0, vga_timer_tb);
        end
         
        reset_n = 1'b0;
        repeat (5) @(posedge clk);
        reset_n = 1'b1;

        // Wait for row and col to become nonzero
        wait (row != 0 || col != 0);

        // Wait until row and col are zero again. 
        //
        // Print out if row or col ever become larger than expected.
        while (row != 0 || col != 0) begin
            // Synchronize with the clock
            @(posedge clk);
            if (row >= NUM_ROWS) begin
                $display("Error: Row = %d", row);
            end
            if (col >= NUM_COLS) begin
                $display("Error: Col = %d", col);
            end
        end

        // End simulation
        $stop;
    end
endmodule

