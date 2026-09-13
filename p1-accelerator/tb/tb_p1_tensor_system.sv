`timescale 1ns/1ps

module tb_p1_tensor_system;
    localparam int LANES = 8;
    localparam int RANK_MAX = 6;
    logic clk = 0, rst_n = 0;
    logic host_valid, host_ready, host_mem_b;
    logic [9:0] host_addr;
    logic [127:0] host_wdata;
    logic start_valid, start_ready;
    logic [2:0] opcode, rank;
    logic [9:0] a_base, b_base, c_base;
    logic [RANK_MAX*16-1:0] shape;
    logic [RANK_MAX*10-1:0] a_stride, b_stride, c_stride;
    logic result_valid, result_ready, result_scalar;
    logic [127:0] result_vector;
    logic signed [47:0] result_accumulator;
    logic store_valid, store_ready, busy;
    logic [9:0] store_addr;
    logic [127:0] store_data;
    logic config_error;
    integer i, seen;

    p1_tensor_system dut (.*);
    always #5 clk = ~clk;

    task automatic write_word(
        input logic sel_b,
        input logic [9:0] address,
        input logic signed [15:0] value
    );
        begin
            @(negedge clk);
            host_mem_b = sel_b;
            host_addr = address;
            host_wdata = {LANES{value[15:0]}};
            host_valid = 1;
            @(negedge clk);
            host_valid = 0;
        end
    endtask

    initial begin
        host_valid = 0;
        host_mem_b = 0;
        host_addr = 0;
        host_wdata = 0;
        start_valid = 0;
        opcode = 0;
        rank = 0;
        a_base = 0;
        b_base = 0;
        c_base = 0;
        shape = '0;
        a_stride = '0;
        b_stride = '0;
        c_stride = '0;
        result_ready = 1;
        store_ready = 1;
        repeat (3) @(posedge clk);
        rst_n = 1;

        for (i = 0; i < 4; i = i + 1) begin
            write_word(0, i, i + 1);
            write_word(1, i, 10 + i);
        end

        rank = 2;
        shape[0*16 +: 16] = 2;
        shape[1*16 +: 16] = 2;
        a_stride[0*10 +: 10] = 2;
        a_stride[1*10 +: 10] = 1;
        b_stride[0*10 +: 10] = 2;
        b_stride[1*10 +: 10] = 1;
        c_stride[0*10 +: 10] = 2;
        c_stride[1*10 +: 10] = 1;
        a_base = 0;
        b_base = 0;
        c_base = 32;
        opcode = 3'd0;

        @(negedge clk);
        while (!start_ready) @(negedge clk);
        start_valid = 1;
        @(negedge clk);
        start_valid = 0;

        seen = 0;
        while (seen < 4) begin
            @(negedge clk);
            if (store_valid && store_ready) begin
                if (store_addr !== 32 + seen)
                    $fatal(1, "tensor system store address mismatch");
                for (i = 0; i < LANES; i = i + 1)
                    if ($signed(store_data[i*16 +: 16]) !== 11 + 2*seen)
                        $fatal(1, "tensor system result mismatch");
                seen = seen + 1;
            end
        end
        while (busy) @(negedge clk);

        // The same 2x2 descriptor now feeds one four-beat dot reduction.
        // A reduction must emit exactly one scalar at c_base, regardless of
        // the configured C strides used by element-wise commands.
        opcode = 3'd2;
        c_base = 60;
        @(negedge clk);
        while (!start_ready) @(negedge clk);
        start_valid = 1;
        @(negedge clk);
        start_valid = 0;

        seen = 0;
        while (busy || !seen) begin
            @(negedge clk);
            if (store_valid && store_ready) begin
                if (seen != 0) $fatal(1, "dot emitted more than one result");
                if (!result_scalar) $fatal(1, "dot result was not scalar");
                if (store_addr !== 10'd60) $fatal(1, "dot result address mismatch");
                if ($signed(result_accumulator) !== 48'sd960)
                    $fatal(1, "dot result mismatch");
                seen = 1;
            end
        end

        rank = 7;
        #1;
        if (!config_error || start_ready)
            $fatal(1, "invalid rank was not rejected");
        $display("PASS: P1 descriptor-driven tensor system");
        $finish;
    end
endmodule
