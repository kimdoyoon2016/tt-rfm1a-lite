`timescale 1ns/1ps

module tb_p1_compute_tile;
    localparam int LANES = 8;
    localparam int W = 16;
    logic clk = 0, rst_n = 0;
    logic host_valid, host_ready, host_mem_b;
    logic [9:0] host_addr;
    logic [127:0] host_wdata;
    logic start_valid, start_ready;
    logic [2:0] start_opcode;
    logic [15:0] start_beats;
    logic [9:0] start_a_base, start_b_base, start_c_base;
    logic result_valid, result_ready, result_scalar, busy;
    logic [127:0] result_vector;
    logic signed [47:0] result_accumulator;
    logic store_valid, store_ready;
    logic [9:0] store_addr;
    logic [127:0] store_data;
    logic ext_addr_valid;
    logic ext_addr_ready;
    logic [9:0] ext_a_addr, ext_b_addr, ext_c_addr;
    integer i;

    p1_compute_tile dut (.*);
    always #5 clk = ~clk;

    task automatic write_word(input logic sel_b, input logic [9:0] address,
                              input logic [127:0] data);
        begin
            @(negedge clk);
            while (!host_ready) @(negedge clk);
            host_mem_b = sel_b;
            host_addr = address;
            host_wdata = data;
            host_valid = 1;
            @(negedge clk);
            host_valid = 0;
        end
    endtask

    task automatic launch(input logic [2:0] op, input logic [15:0] beats);
        begin
            @(negedge clk);
            while (!start_ready) @(negedge clk);
            start_opcode = op;
            start_beats = beats;
            start_a_base = 0;
            start_b_base = 0;
            start_c_base = 10'd32;
            start_valid = 1;
            @(negedge clk);
            start_valid = 0;
        end
    endtask

    initial begin
        host_valid = 0;
        host_mem_b = 0;
        host_addr = 0;
        host_wdata = 0;
        start_valid = 0;
        start_opcode = 0;
        start_beats = 0;
        start_a_base = 0;
        start_b_base = 0;
        start_c_base = 0;
        result_ready = 1;
        store_ready = 1;
        ext_addr_valid = 0;
        ext_a_addr = 0;
        ext_b_addr = 0;
        ext_c_addr = 0;
        repeat (3) @(posedge clk);
        rst_n = 1;

        write_word(0, 0, {LANES{16'sd2}});
        write_word(1, 0, {LANES{16'sd3}});
        write_word(0, 1, {LANES{16'sd4}});
        write_word(1, 1, {LANES{16'sd5}});

        launch(3'd2, 2); // dot = 8*2*3 + 8*4*5 = 208
        while (!result_valid) @(negedge clk);
        if (!result_scalar || result_accumulator !== 48'sd208)
            $fatal(1, "compute tile dot mismatch: %0d", result_accumulator);
        if (!store_valid || store_addr !== 10'd32 || $signed(store_data[47:0]) !== 48'sd208)
            $fatal(1, "compute tile scalar store mismatch");
        while (busy) @(negedge clk);

        launch(3'd0, 1); // vector add = 5 on all lanes
        while (!result_valid) @(negedge clk);
        for (i = 0; i < LANES; i = i + 1)
            if ($signed(result_vector[i*W +: W]) !== 16'sd5)
                $fatal(1, "compute tile add mismatch lane %0d", i);

        $display("PASS: P1 compute tile");
        $finish;
    end
endmodule
