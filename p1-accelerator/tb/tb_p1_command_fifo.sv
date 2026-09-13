`timescale 1ns/1ps

module tb_p1_command_fifo;
    logic clk = 0, rst_n = 0;
    logic push_valid, push_ready, pop_valid, pop_ready;
    logic [31:0] push_data, pop_data;
    logic [3:0] occupancy;
    logic overflow_attempt, underflow_attempt;
    integer i;

    p1_command_fifo #(.WIDTH(32), .DEPTH(8)) dut (.*);
    always #5 clk = ~clk;

    initial begin
        push_valid = 0;
        pop_ready = 0;
        push_data = 0;
        repeat (3) @(posedge clk);
        rst_n = 1;

        for (i = 0; i < 8; i = i + 1) begin
            @(negedge clk);
            push_valid = 1;
            push_data = 32'h1000 + i;
        end
        @(negedge clk);
        push_valid = 0;
        if (occupancy !== 8) $fatal(1, "FIFO occupancy is not 8");

        for (i = 0; i < 8; i = i + 1) begin
            if (!pop_valid || pop_data !== 32'h1000 + i)
                $fatal(1, "FIFO ordering mismatch at %0d", i);
            pop_ready = 1;
            @(negedge clk);
        end
        pop_ready = 0;
        if (occupancy !== 0) $fatal(1, "FIFO did not drain");

        $display("PASS: P1 command FIFO");
        $finish;
    end
endmodule

