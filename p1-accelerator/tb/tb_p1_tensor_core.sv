`timescale 1ns/1ps

module tb_p1_tensor_core;
    localparam int LANES = 8;
    localparam int W = 16;
    localparam int AW = 48;

    logic clk = 0;
    logic rst_n = 0;
    logic cmd_valid;
    logic cmd_ready;
    logic [2:0] cmd_opcode;
    logic [15:0] cmd_beats;
    logic in_valid;
    logic in_ready;
    logic [LANES*W-1:0] in_a, in_b;
    logic out_valid, out_ready, out_scalar, busy;
    logic [LANES*W-1:0] out_vector;
    logic signed [AW-1:0] out_accumulator;

    p1_tensor_core dut (.*);
    always #5 clk = ~clk;

    task automatic command(input logic [2:0] op, input integer beats);
        begin
            @(negedge clk);
            while (!cmd_ready) @(negedge clk);
            cmd_opcode = op;
            cmd_beats = beats;
            cmd_valid = 1;
            @(negedge clk);
            cmd_valid = 0;
        end
    endtask

    task automatic send_beat;
        begin
            @(negedge clk);
            while (!in_ready) @(negedge clk);
            in_valid = 1;
            @(negedge clk);
            in_valid = 0;
        end
    endtask

    task automatic wait_result;
        begin
            while (!out_valid) @(negedge clk);
        end
    endtask

    integer i;
    initial begin
        cmd_valid = 0;
        cmd_opcode = 0;
        cmd_beats = 0;
        in_valid = 0;
        in_a = '0;
        in_b = '0;
        out_ready = 1;

        repeat (3) @(posedge clk);
        rst_n = 1;

        // VADD: [0..7] + [10..17] = [10,12,..24]
        for (i = 0; i < LANES; i = i + 1) begin
            in_a[i*W +: W] = i;
            in_b[i*W +: W] = i + 10;
        end
        command(3'd0, 1);
        send_beat();
        wait_result();
        for (i = 0; i < LANES; i = i + 1)
            if ($signed(out_vector[i*W +: W]) !== (2*i + 10)) $fatal(1, "VADD lane %0d", i);

        // VMUL: [1..8] * 3
        for (i = 0; i < LANES; i = i + 1) begin
            in_a[i*W +: W] = i + 1;
            in_b[i*W +: W] = 3;
        end
        command(3'd1, 1);
        send_beat();
        wait_result();
        for (i = 0; i < LANES; i = i + 1)
            if ($signed(out_vector[i*W +: W]) !== (3*(i+1))) $fatal(1, "VMUL lane %0d", i);

        // Two-beat dot product: 8*(1*2) + 8*(3*4) = 112
        in_a = {LANES{16'sd1}};
        in_b = {LANES{16'sd2}};
        command(3'd2, 2);
        send_beat();
        in_a = {LANES{16'sd3}};
        in_b = {LANES{16'sd4}};
        send_beat();
        wait_result();
        if (!out_scalar || out_accumulator !== 48'sd112) $fatal(1, "DOT got %0d", out_accumulator);

        // Sum with signed values: 8*(-2) + 8*(5) = 24
        in_a = {LANES{-16'sd2}};
        command(3'd3, 2);
        send_beat();
        in_a = {LANES{16'sd5}};
        send_beat();
        wait_result();
        if (out_accumulator !== 48'sd24) $fatal(1, "REDSUM got %0d", out_accumulator);

        // Maximum across two beats.
        for (i = 0; i < LANES; i = i + 1) in_a[i*W +: W] = i - 20;
        command(3'd4, 2);
        send_beat();
        for (i = 0; i < LANES; i = i + 1) in_a[i*W +: W] = i + 30;
        send_beat();
        wait_result();
        if (out_accumulator !== 48'sd37) $fatal(1, "REDMAX got %0d", out_accumulator);

        // Minimum across one beat.
        for (i = 0; i < LANES; i = i + 1) in_a[i*W +: W] = 50 - i*9;
        command(3'd5, 1);
        send_beat();
        wait_result();
        if (out_accumulator !== -48'sd13) $fatal(1, "REDMIN got %0d", out_accumulator);

        $display("PASS: P1 tensor core");
        $finish;
    end
endmodule
