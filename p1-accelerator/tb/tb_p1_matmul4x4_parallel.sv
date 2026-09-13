`timescale 1ns/1ps

module tb_p1_matmul4x4_parallel;
    localparam int EW = 16;
    localparam int AW = 40;
    logic clk = 0, rst_n = 0;
    logic in_valid, in_ready, out_valid, out_ready, overflow, busy;
    logic [16*EW-1:0] matrix_a, matrix_b;
    logic [16*AW-1:0] matrix_c;
    integer i, r, c, k;
    integer expected;

    p1_matmul4x4_parallel dut (.*);
    always #5 clk = ~clk;

    function automatic integer aval(input integer row, input integer col);
        aval = row*4 + col - 5;
    endfunction

    function automatic integer bval(input integer row, input integer col);
        bval = (row == col) ? 2 : ((row + col == 3) ? -1 : 0);
    endfunction

    initial begin
        in_valid = 0;
        out_ready = 1;
        matrix_a = '0;
        matrix_b = '0;
        repeat (3) @(posedge clk);
        rst_n = 1;

        for (r = 0; r < 4; r = r + 1)
            for (c = 0; c < 4; c = c + 1) begin
                matrix_a[(r*4+c)*EW +: EW] = aval(r,c);
                matrix_b[(r*4+c)*EW +: EW] = bval(r,c);
            end

        @(negedge clk);
        in_valid = 1;
        @(negedge clk);
        in_valid = 0;
        while (!out_valid) @(negedge clk);

        for (r = 0; r < 4; r = r + 1)
            for (c = 0; c < 4; c = c + 1) begin
                expected = 0;
                for (k = 0; k < 4; k = k + 1)
                    expected = expected + aval(r,k) * bval(k,c);
                if ($signed(matrix_c[(r*4+c)*AW +: AW]) !== expected)
                    $fatal(1, "parallel matmul C[%0d,%0d] mismatch", r, c);
            end
        if (overflow) $fatal(1, "unexpected accumulator overflow");

        // Hold result stable for a stalled consumer.
        out_ready = 0;
        repeat (3) begin
            @(negedge clk);
            if (!out_valid) $fatal(1, "out_valid dropped under backpressure");
        end
        out_ready = 1;
        $display("PASS: P1 parallel 4x4 matrix multiply");
        $finish;
    end
endmodule

