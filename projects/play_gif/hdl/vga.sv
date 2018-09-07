// Module responsible for interacting with the "buffer" for:
//
// - queueing transfers at the right time
// - extracting pixel data out of a full buffer read
// - generating the appropriate timing signals and data for the external VGA
//      display.
//
module vga #(
        // Width of a read from the buffer.
        parameter INTERFACE_WIDTH_BITS = 128,
        // Number of bits for each pixel. Important for address calculation and
        // extracting the right data from each buffer read.
        //
        // Assume pixels are aligned to the read width to avoid a pixel getting
        // split across the buffer.
        parameter BITS_PER_PIXEL = 12,

        // Pixel dimensions of the VGA display.
        parameter DISPLAY_WIDTH = 640,
        parameter DISPLAY_HEIGHT = 480,

        // Number of entries in the line buffer
        parameter NUM_BUFFER_ENTRIES = 64,

        // Number of address bits visible to the buffer
        parameter INTERFACE_ADDR_BITS = 26
    )(
        input clk,
        input reset_n,

        // VGA Timing Signals
        output [3:0] VGA_R,
        output [3:0] VGA_G,
        output [3:0] VGA_B,
        output VGA_HS,
        output VGA_VS,

        // For debugging purposes. Indicate if the external display is active
        // or being blanked.
        output display_enabled,

        // Base address signal for assigning the base location of the image
        // in memory.
        input [INTERFACE_ADDR_BITS-1:0] image_base_address,

        // Buffer signals
        output                                  buffer_start,
        output [INTERFACE_ADDR_BITS-1:0]        buffer_base_address,
        output logic [$clog2(NUM_BUFFER_ENTRIES)-1:0] buffer_read_addr,
        input  [INTERFACE_WIDTH_BITS-1:0]        buffer_read_data,

        // End of frame indicator.
        output end_frame
    );

// Local parameters
localparam COL_WIDTH = $clog2(DISPLAY_WIDTH);
localparam ROW_WIDTH = $clog2(DISPLAY_HEIGHT);

// Number of bytes per read of the interface.
localparam INTERFACE_WIDTH_BYTES = INTERFACE_WIDTH_BITS / 8;

// Number of clock cycles to delay h_sync, v_sync signals. Used to offset
// latency associated with reading from the buffer.
//
// Right now, the buffer has a latency of 1 cycle for reads.
localparam SYNC_DELAY_CYCLES = 1;

// Number of pixels read at a time. It's okay to use integer division with the
// assumption that pixels are packed in such a way that if a whole pixel
// cannot fit in the bits left in an entry in the buffer, it will be placed at
// the next address. (NOTE: this is done during image packing BEFORE it comes
// to the FPGA. Hardware is NOT responsible for this.)
localparam PIXELS_PER_READ = INTERFACE_WIDTH_BITS / BITS_PER_PIXEL;


//------------------------------------------------------------------------------
// Local signals

// signals for connecting to the vga timer.
logic h_sync, v_sync;
logic disp_ena;
logic [COL_WIDTH-1:0] col;
logic [ROW_WIDTH-1:0] row;
logic end_line;

// Local RGB signals
logic [3:0] red, green, blue;

// Delay lines for h_sync, v_sync, and disp_ena
logic [SYNC_DELAY_CYCLES-1:0] h_sync_delay, v_sync_delay, disp_ena_delay;

// Keep track of the next row for establishing the base-address of the next
// buffer iteration.
logic [ROW_WIDTH-1:0] next_row;

// Since the number of pixels stored in each address of the buffer is not
// necessarily a power of two, need to maintain a counter to increment the
// buffer address after the correct number of pixels are read.
logic [$clog2(PIXELS_PER_READ)-1:0] sub_pixel_count;

// The buffer is registered, so reads lag by one cycle. Use a delayed pixel
// count to get the right pixel from the buffer read.
logic [$clog2(PIXELS_PER_READ)-1:0] sub_pixel_count_last;

// Register the image base address to use for calculations of the base address
// for each line buffer.
logic [INTERFACE_ADDR_BITS-1:0] image_base_address_r;

// The actual pixel data.
logic [BITS_PER_PIXEL-1:0] pixel;


//------------------------------------------------------------------------------
// Submodule instantiations

// Instantiate a VGA Timer to generate
vga_timer u0 (
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

//------------------------------------------------------------------------------
// Logic implementation

// Begin the next buffer at the end of each line.
assign buffer_start = end_line;

assign next_row = (row == DISPLAY_HEIGHT - 1) ? 0 : row + 1'b1;
assign buffer_base_address = image_base_address_r +
        (INTERFACE_WIDTH_BYTES * NUM_BUFFER_ENTRIES) * next_row;

// Load a new base address at the end of each frame.
always @(posedge clk) begin
    if (end_frame || (reset_n == 1'b0)) begin
        image_base_address_r <= image_base_address;
    end
end

always @(posedge clk) begin
    if (end_line || (reset_n == 1'b0)) begin
        buffer_read_addr    <= 0;
        sub_pixel_count     <= 0;
    end else if (disp_ena) begin
        if (sub_pixel_count == PIXELS_PER_READ - 1) begin
            sub_pixel_count <= 0;
            buffer_read_addr <= buffer_read_addr + 1;
        end else begin
            sub_pixel_count <= sub_pixel_count + 1;
        end
    end

    // Save last sub_pixel_count for extract sub-pixel from the read done the
    // cycle before.
    sub_pixel_count_last <= sub_pixel_count;
end

// Use the last sub_count to index into the read data and extract the correct
// number of bits. Multipley the sub-count by the bits per pixel to ensure
// these extractions are aligned correctly.
assign pixel = buffer_read_data[(BITS_PER_PIXEL * sub_pixel_count_last) +: BITS_PER_PIXEL];

assign red      = pixel[3:0];
assign green    = pixel[7:4];
assign blue     = pixel[11:8];

// Delay sync signals to account for read latency.
always @(posedge clk) begin
    // Treat unit delay separately to avoid an awkward index of 0:1.
    if (SYNC_DELAY_CYCLES == 1) begin
        h_sync_delay   <= {h_sync};
        v_sync_delay   <= {v_sync};
        disp_ena_delay <= {disp_ena};
    end else begin
        h_sync_delay   <= {h_sync_delay[SYNC_DELAY_CYCLES-1:1], h_sync};
        v_sync_delay   <= {v_sync_delay[SYNC_DELAY_CYCLES-1:1], v_sync};
        disp_ena_delay <= {disp_ena_delay[SYNC_DELAY_CYCLES-1:1], disp_ena};
    end
end

// Route sync signals externally.
assign VGA_HS = h_sync_delay[SYNC_DELAY_CYCLES - 1];
assign VGA_VS = v_sync_delay[SYNC_DELAY_CYCLES - 1];

assign VGA_R = disp_ena_delay[SYNC_DELAY_CYCLES - 1] ? red   : 4'b0000;
assign VGA_G = disp_ena_delay[SYNC_DELAY_CYCLES - 1] ? green : 4'b0000;
assign VGA_B = disp_ena_delay[SYNC_DELAY_CYCLES - 1] ? blue  : 4'b0000;

assign display_enabled = disp_ena_delay[SYNC_DELAY_CYCLES - 1];


endmodule
