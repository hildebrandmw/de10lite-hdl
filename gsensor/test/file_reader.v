// Task for retrieving file data.
module file_reader#(
    parameter OUT_WIDTH = 8
    )();
    // File reading task
    task get_file_data;
        input integer f;
        output [OUT_WIDTH-1:0] data;
        // Internal variables
        integer scanvals;
        begin //task get_file_data
            // Check for end of file
            if ($feof(f)) begin
                data = 8'b0000_0000;
            end else begin
                scanvals = $fscanf(f, "%b\n", data);
            end
        end
    endtask
endmodule
