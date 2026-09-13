`timescale 1ns/1ps

module tb_p1_tensor_walker;
    localparam int RANK_MAX = 6;
    logic clk = 0;
    logic rst_n = 0;
    logic cfg_valid, cfg_ready;
    logic [2:0] cfg_rank;
    logic [31:0] cfg_base;
    logic [RANK_MAX*16-1:0] cfg_shape;
    logic [RANK_MAX*32-1:0] cfg_stride;
    logic addr_valid, addr_ready, addr_last, busy;
    logic [31:0] addr;
    integer count;

    p1_tensor_walker dut (.*);
    always #5 clk = ~clk;

    task automatic expect_addr(input logic [31:0] expected, input logic expected_last);
        begin
            while (!addr_valid) @(negedge clk);
            if (addr !== expected) $fatal(1, "address %0d expected %0d", addr, expected);
            if (addr_last !== expected_last) $fatal(1, "last mismatch at %0d", addr);
            @(negedge clk);
        end
    endtask

    initial begin
        cfg_valid = 0;
        cfg_rank = 0;
        cfg_base = 0;
        cfg_shape = '0;
        cfg_stride = '0;
        addr_ready = 1;
        repeat (3) @(posedge clk);
        rst_n = 1;

        // 2x3 row-major tensor at base 100, row stride 12, element stride 4.
        cfg_rank = 2;
        cfg_base = 100;
        cfg_shape[0*16 +: 16] = 2;
        cfg_shape[1*16 +: 16] = 3;
        cfg_stride[0*32 +: 32] = 12;
        cfg_stride[1*32 +: 32] = 4;
        @(negedge clk);
        cfg_valid = 1;
        @(negedge clk);
        cfg_valid = 0;

        expect_addr(100, 0);
        expect_addr(104, 0);
        expect_addr(108, 0);
        expect_addr(112, 0);
        expect_addr(116, 0);
        expect_addr(120, 1);
        @(negedge clk);
        if (busy) $fatal(1, "walker remained busy");

        // Backpressure must hold both address and last stable.
        cfg_rank = 1;
        cfg_base = 40;
        cfg_shape[0*16 +: 16] = 2;
        cfg_stride[0*32 +: 32] = 8;
        @(negedge clk);
        cfg_valid = 1;
        @(negedge clk);
        cfg_valid = 0;
        addr_ready = 0;
        repeat (3) begin
            @(negedge clk);
            if (addr !== 40) $fatal(1, "address changed under backpressure");
        end
        addr_ready = 1;
        expect_addr(40, 0);
        expect_addr(48, 1);

        $display("PASS: P1 tensor walker");
        $finish;
    end
endmodule
