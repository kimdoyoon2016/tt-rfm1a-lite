`timescale 1ns/1ps

module tb_p1_fp_vector_mac;
    localparam int LANES = 8;
    logic clk = 0, rst_n = 0;
    logic in_valid, in_ready, format_bf16;
    logic [LANES*16-1:0] in_a, in_b, in_c, out_y;
    logic out_valid, out_ready;
    logic [3:0] status;
    integer i;

    p1_fp_vector_mac #(.LANES(LANES)) dut (.*);
    always #5 clk = ~clk;

    task automatic issue_and_expect(
        input logic format_sel,
        input logic [15:0] a,
        input logic [15:0] b,
        input logic [15:0] c,
        input logic [15:0] expected
    );
        begin
            @(negedge clk);
            format_bf16 = format_sel;
            for (i = 0; i < LANES; i = i + 1) begin
                in_a[i*16 +: 16] = a;
                in_b[i*16 +: 16] = b;
                in_c[i*16 +: 16] = c;
            end
            in_valid = 1'b1;
            @(negedge clk);
            in_valid = 1'b0;
            while (!out_valid) @(negedge clk);
            for (i = 0; i < LANES; i = i + 1)
                if (out_y[i*16 +: 16] !== expected)
                    $fatal(1, "lane %0d got %h expected %h", i,
                           out_y[i*16 +: 16], expected);
            @(negedge clk);
        end
    endtask

    initial begin
        in_valid = 0; format_bf16 = 0; in_a = '0; in_b = '0; in_c = '0;
        out_ready = 1;
        repeat (3) @(posedge clk);
        rst_n = 1;

        // FP16: 1.5 * 2.0 + 0.5 = 3.5
        issue_and_expect(1'b0, 16'h3e00, 16'h4000, 16'h3800, 16'h4300);
        // FP16: -2.0 * 3.0 + 1.0 = -5.0
        issue_and_expect(1'b0, 16'hc000, 16'h4200, 16'h3c00, 16'hc500);
        // BF16: 1.5 * 2.0 + 0.5 = 3.5
        issue_and_expect(1'b1, 16'h3fc0, 16'h4000, 16'h3f00, 16'h4060);
        // BF16: -2.0 * 3.0 + 1.0 = -5.0
        issue_and_expect(1'b1, 16'hc000, 16'h4040, 16'h3f80, 16'hc0a0);
        // FP16 infinity multiplied by zero is a quiet NaN and invalid.
        issue_and_expect(1'b0, 16'h7c00, 16'h0000, 16'h0000, 16'h7e00);
        if (!status[3]) $fatal(1, "invalid flag missing for infinity times zero");

        $display("PASS: P1 FP16/BF16 vector MAC");
        $finish;
    end
endmodule
