module file_reader#(
    parameter OUT_WIDTH = 8
    )();
    // File reading task
    // Assumes data is written in binary separated by newline characters.
    // Each invocation, a new line will be read.
    // When the end of a file is reached, will return 0 for data on each
    //  invocation.
    task get_file_data;
        input integer f;
        output [OUT_WIDTH-1:0] data;
        // Internal variables
        integer scanvals;
        begin //task get_file_data
            // Check for end of file
            if ($feof(f)) begin
                data = 0;
            end else begin
                scanvals = $fscanf(f, "%b\n", data);
            end
        end
    endtask
endmodule
