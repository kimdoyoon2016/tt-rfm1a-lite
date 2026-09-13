`timescale 1ns/1ps

module tb_p1_execution_cluster;
    localparam int LANES = 8;
    logic clk = 0, rst_n = 0;
    logic cmd_valid, cmd_ready, cmd_floating, cmd_bf16;
    logic [2:0] cmd_opcode;
    logic [15:0] cmd_beats;
    logic in_valid, in_ready, out_valid, out_ready, out_scalar, busy;
    logic [127:0] in_a, in_b, in_c, out_vector;
    logic signed [47:0] out_accumulator;
    logic [3:0] fp_status;
    integer i;

    p1_execution_cluster dut (.*);
    always #5 clk = ~clk;

    task automatic send_command(input logic floating, input logic bf16,
                                input logic [2:0] opcode);
        begin
            @(negedge clk);
            while (!cmd_ready) @(negedge clk);
            cmd_floating = floating; cmd_bf16 = bf16; cmd_opcode = opcode;
            cmd_beats = 1; cmd_valid = 1;
            @(negedge clk); cmd_valid = 0;
        end
    endtask

    task automatic send_beat(input logic [15:0] a,
                             input logic [15:0] b,
                             input logic [15:0] c);
        begin
            @(negedge clk);
            while (!in_ready) @(negedge clk);
            for (i = 0; i < LANES; i = i + 1) begin
                in_a[i*16 +: 16] = a;
                in_b[i*16 +: 16] = b;
                in_c[i*16 +: 16] = c;
            end
            in_valid = 1;
            @(negedge clk); in_valid = 0;
        end
    endtask

    initial begin
        cmd_valid = 0; cmd_floating = 0; cmd_bf16 = 0; cmd_opcode = 0;
        cmd_beats = 0; in_valid = 0; in_a = 0; in_b = 0; in_c = 0;
        out_ready = 1;
        repeat (3) @(posedge clk); rst_n = 1;

        send_command(0, 0, 3'd0);
        send_beat(16'd7, 16'd9, 16'd0);
        while (!out_valid) @(negedge clk);
        if (out_scalar || out_vector[15:0] !== 16'd16)
            $fatal(1, "integer dispatch failed");
        @(negedge clk);

        send_command(1, 0, 3'd0);
        send_beat(16'h3e00, 16'h4000, 16'h3800);
        while (!out_valid) @(negedge clk);
        if (out_scalar || out_vector[15:0] !== 16'h4300 || fp_status !== 0)
            $fatal(1, "FP16 dispatch failed");
        @(negedge clk);

        send_command(1, 1, 3'd0);
        send_beat(16'h3fc0, 16'h4000, 16'h3f00);
        while (!out_valid) @(negedge clk);
        if (out_vector[15:0] !== 16'h4060)
            $fatal(1, "BF16 dispatch failed");

        $display("PASS: P1 unified integer/FP execution cluster");
        $finish;
    end
endmodule
