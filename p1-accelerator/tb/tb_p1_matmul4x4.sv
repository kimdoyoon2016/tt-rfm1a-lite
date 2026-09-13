`timescale 1ns/1ps

module tb_p1_matmul4x4;
    logic clk = 0, rst_n = 0;
    logic load_valid, load_ready, load_matrix_b;
    logic [3:0] load_index, result_index;
    logic signed [15:0] load_data;
    logic start, start_ready, busy, done;
    logic signed [39:0] result_data;
    integer i, r, c;

    p1_matmul4x4 dut (.*);
    always #5 clk = ~clk;

    task automatic load(input logic matrix_b, input integer index, input integer value);
        begin
            @(negedge clk);
            load_matrix_b = matrix_b;
            load_index = index;
            load_data = value;
            load_valid = 1;
            @(negedge clk);
            load_valid = 0;
        end
    endtask

    initial begin
        load_valid = 0;
        load_matrix_b = 0;
        load_index = 0;
        load_data = 0;
        start = 0;
        result_index = 0;
        repeat (3) @(posedge clk);
        rst_n = 1;

        // A is 1..16. B is the 4x4 identity matrix, so C must equal A.
        for (i = 0; i < 16; i = i + 1)
            load(0, i, i + 1);
        for (r = 0; r < 4; r = r + 1)
            for (c = 0; c < 4; c = c + 1)
                load(1, r*4+c, (r == c) ? 1 : 0);

        @(negedge clk);
        start = 1;
        @(negedge clk);
        start = 0;
        while (!done) @(negedge clk);

        for (i = 0; i < 16; i = i + 1) begin
            result_index = i;
            #1;
            if (result_data !== i + 1)
                $fatal(1, "matmul C[%0d]=%0d expected %0d", i, result_data, i+1);
        end
        $display("PASS: P1 4x4 matrix multiply");
        $finish;
    end
endmodule

