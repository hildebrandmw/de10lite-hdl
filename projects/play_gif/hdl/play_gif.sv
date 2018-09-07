module play_gif(

    //////////// CLOCK //////////
    input ADC_CLK_10,
    input MAX10_CLK1_50,
    input MAX10_CLK2_50,

    //////////// SDRAM //////////
    output [12:0]   DRAM_ADDR,
    output [1:0]    DRAM_BA,
    output          DRAM_CAS_N,
    output          DRAM_CKE,
    output          DRAM_CLK,
    output          DRAM_CS_N,
    inout  [15:0]   DRAM_DQ,
    output          DRAM_LDQM,
    output          DRAM_RAS_N,
    output          DRAM_UDQM,
    output          DRAM_WE_N,

    //////////// KEY //////////
    input [1:0] KEY,

    //////////// LED //////////
    output logic [9:0] LEDR,

    //////////// VGA //////////
    output [3:0] VGA_B,
    output [3:0] VGA_G,
    output       VGA_HS,
    output [3:0] VGA_R,
    output       VGA_VS
);

// ---------------- //
// Local Parameters //
// ---------------- //

// Number of bits read at a time from the QSYS system
localparam INTERFACE_WIDTH_BITS  = 128;
localparam INTERFACE_ADDR_BITS   = 26;
localparam BITS_PER_PIXEL        = 16;

// Don't touch without being ready to really fix things.
localparam DISPLAY_WIDTH           = 640;
localparam DISPLAY_HEIGHT          = 480;

// Defived parameters
localparam INTERFACE_WIDTH_BYTES = INTERFACE_WIDTH_BITS / 8;
localparam PIXELS_PER_TRANSFER = INTERFACE_WIDTH_BITS / BITS_PER_PIXEL;

// NOTE: If this division is not exact, you must compute the ceiling manually
// because $ceil is not supported for synthesis :(
localparam NUM_BUFFER_ENTRIES = DISPLAY_WIDTH / PIXELS_PER_TRANSFER;

// Number of bytes to store the whole image. Useful for computing where one
// image ends and the next begins.
//
// Again, if this arithmetic is not exact, it probably will not behave as
// expected.
localparam IMAGE_SIZE = DISPLAY_WIDTH * DISPLAY_HEIGHT * INTERFACE_WIDTH_BYTES / PIXELS_PER_TRANSFER;

// ------------------------------------ //
// Clocks and Global Synchrounous Reset //
// ------------------------------------ //

// 50 MHz external clock
logic clk_50;
logic reset_n;

assign clk_50 = MAX10_CLK1_50;
assign reset_n = KEY[0];

// Derived 25 MHz and 100 MHz clocks from PLL in the QSYS system.
logic clk_25, clk_100;

// ------------- //
// SDRAM Signals //
// ------------- //

// SDRAM controller only has a single DQM port. Wire this to both the UDQM and
// LDQM ports at the top leve.
logic DRAM_DQM;
assign DRAM_LDQM = DRAM_DQM;
assign DRAM_UDQM = DRAM_DQM;

// -------------- //
// Bridge Signals //
// -------------- //

// Signals for interfacing with the external bridge side of the External
// Bridge to Avalon Master component.
logic [INTERFACE_ADDR_BITS-1:0]      interface_address;
logic [INTERFACE_WIDTH_BYTES-1:0]    interface_byte_enable;
logic                                interface_read;
logic                                interface_write;
logic [INTERFACE_WIDTH_BITS-1:0]     interface_write_data;
logic [INTERFACE_WIDTH_BITS-1:0]     interface_read_data;
logic                                interface_acknowledge;

// ------------------------------------ //
// Communication between VGA and Buffer //
// ------------------------------------ //
logic [INTERFACE_ADDR_BITS-1:0]          buffer_base_address;
logic [INTERFACE_WIDTH_BITS-1:0]         buffer_read_data;
logic [$clog2(NUM_BUFFER_ENTRIES)-1:0]   buffer_read_address;
logic                                    buffer_start;

// ----------- //
// VGA Signals //
// ----------- //
localparam COL_WIDTH = $clog2(DISPLAY_WIDTH);
localparam ROW_WIDTH = $clog2(DISPLAY_HEIGHT);
logic [INTERFACE_ADDR_BITS-1:0] image_base_address;
logic end_frame;

// --------------- //
// Control signals //
// --------------- //
logic [7:0] max_frame_count;
logic [7:0] max_image_count;

logic [7:0] frame_count, frame_count_next;
logic [7:0] image_count, image_count_next;

////////////////////////////////////////////////////////////////////////////////
// QSYS System Instantiation
////////////////////////////////////////////////////////////////////////////////
system u0 (
    .clk_clk               (clk_50),    //     clk.clk
    .reset_reset_n         (reset_n),   //     reset.reset_n

    // SDRAM SIGNALS
    .sdram_addr            (DRAM_ADDR), //     sdram.addr
    .sdram_ba              (DRAM_BA),   //          .ba
    .sdram_cas_n           (DRAM_CAS_N),//          .cas_n
    .sdram_cke             (DRAM_CKE),  //          .cke
    .sdram_cs_n            (DRAM_CS_N), //          .cs_n
    .sdram_dq              (DRAM_DQ),   //          .dq
    .sdram_dqm             (DRAM_DQM),  //          .dqm
    .sdram_ras_n           (DRAM_RAS_N),//          .ras_n
    .sdram_we_n            (DRAM_WE_N), //          .we_n
    .sdram_clk_100_clk     (DRAM_CLK),

    // External Bridge interface signals.
    .interface_address     (interface_address),     // interface.address
    .interface_byte_enable (interface_byte_enable), //          .byte_enable
    .interface_read        (interface_read),        //          .read
    .interface_write       (interface_write),       //          .write
    .interface_write_data  (interface_write_data),  //          .write_data
    .interface_acknowledge (interface_acknowledge), //          .acknowledge
    .interface_read_data   (interface_read_data),   //          .read_data

    // Clocks exported by PLL.
    .clk_25_clk            (clk_25),    //    clk_25.clk
    .clk_100_clk           (clk_100),   //   clk_100.clk

    // export frame-rate and frame-count registers
    .framecount_export (max_frame_count),
    .imagecount_export (max_image_count)
);


////////////////////////////////////////////////////////////////////////////////
// Line Buffer instantiation.
////////////////////////////////////////////////////////////////////////////////

buffer #(
    .INTERFACE_WIDTH_BITS   (INTERFACE_WIDTH_BITS),
    .INTERFACE_ADDR_BITS    (INTERFACE_ADDR_BITS),
    .NUM_BUFFER_ENTRIES     (NUM_BUFFER_ENTRIES)
) u2 (
    .interface_clock    (clk_100),
    .read_clock         (clk_25),
    .reset_n            (reset_n),
    // Interface signals
    .interface_address     (interface_address),
    .interface_byte_enable (interface_byte_enable),
    .interface_read        (interface_read),
    .interface_write       (interface_write),
    .interface_write_data  (interface_write_data),
    .interface_acknowledge (interface_acknowledge),
    .interface_read_data   (interface_read_data),
    // VGA signals
    .read_address          (buffer_read_address),
    .read_data             (buffer_read_data),
    .start                 (buffer_start),
    .base_address          (buffer_base_address),
    // Timing Error indication
    .timing_error       (LEDR[0]),
    .timing_error_reset (~KEY[1])
);

////////////////////////////////////////////////////////////////////////////////
// VGA Controller Instantiation
////////////////////////////////////////////////////////////////////////////////

vga #(
    .INTERFACE_WIDTH_BITS   (INTERFACE_WIDTH_BITS),
    .INTERFACE_ADDR_BITS    (INTERFACE_ADDR_BITS),
    .BITS_PER_PIXEL         (BITS_PER_PIXEL),
    .DISPLAY_WIDTH          (DISPLAY_WIDTH),
    .DISPLAY_HEIGHT         (DISPLAY_HEIGHT),
    .NUM_BUFFER_ENTRIES     (NUM_BUFFER_ENTRIES)
) u3 (
    .clk                    (clk_25),
    .reset_n                (reset_n),
    // VGA Signals
    .VGA_R      (VGA_R),
    .VGA_G      (VGA_G),   
    .VGA_B      (VGA_B),
    .VGA_HS     (VGA_HS),
    .VGA_VS     (VGA_VS),
    // For the time being, set base address to 0
    .image_base_address (image_base_address),
    // Buffer signals
    .buffer_start           (buffer_start),
    .buffer_base_address    (buffer_base_address),
    .buffer_read_addr       (buffer_read_address),
    .buffer_read_data       (buffer_read_data),
    // Indication that frame is done.
    .end_frame              (end_frame)
    // unconnected signals
    // .display_enabled
);

////////////////////////////////////////////////////////////////////////////////
// Frame control
////////////////////////////////////////////////////////////////////////////////
always @(posedge clk_25) begin
    if (reset_n == 1'b0) begin
        frame_count <= 0;
        image_count <= 0;
    end else begin
        frame_count <= frame_count_next;
        image_count <= image_count_next;
    end  
end

always @(*) begin
    frame_count_next = frame_count;
    image_count_next = image_count;

    // Update on frames
    if (end_frame) begin
        if (frame_count >= max_frame_count) begin
            frame_count_next = 0;
            // Update image count if we've reached the maximum number of
            // frames.
            if (image_count >= max_image_count) begin
                image_count_next = 0;
            end else begin
                image_count_next = image_count + 1;
            end
        end else begin
            frame_count_next = frame_count + 1;
        end
    end 
end

// Assign the base address of the image based on the image count.
assign image_base_address = IMAGE_SIZE * image_count;

endmodule
