`timescale 1ns/1ps

// Four-by-four matrix tile with sixteen parallel MAC lanes.
// Every active cycle evaluates all 16 output cells for one K slice.
module p1_matmul4x4_parallel #(
    parameter int ELEM_W = 16,
    parameter int ACC_W  = 40
) (
    input  logic                         clk,
    input  logic                         rst_n,

    input  logic                         in_valid,
    output logic                         in_ready,
    input  logic [16*ELEM_W-1:0]         matrix_a,
    input  logic [16*ELEM_W-1:0]         matrix_b,

    output logic                         out_valid,
    input  logic                         out_ready,
    output logic [16*ACC_W-1:0]          matrix_c,
    output logic                         overflow,
    output logic                         busy
);
    logic signed [ELEM_W-1:0] a_q [0:15];
    logic signed [ELEM_W-1:0] b_q [0:15];
    logic signed [ACC_W-1:0] acc_q [0:15];
    logic [1:0] k_q;
    logic signed [2*ELEM_W-1:0] product [0:15];
    logic signed [ACC_W:0] wide_sum [0:15];
    integer i, r, c;

    assign in_ready = !busy && !out_valid;

    always_comb begin
        for (r = 0; r < 4; r = r + 1) begin
            for (c = 0; c < 4; c = c + 1) begin
                product[r*4+c] = a_q[r*4+k_q] * b_q[k_q*4+c];
                wide_sum[r*4+c] = acc_q[r*4+c] + product[r*4+c];
            end
        end
        for (i = 0; i < 16; i = i + 1)
            matrix_c[i*ACC_W +: ACC_W] = acc_q[i];
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy <= 1'b0;
            out_valid <= 1'b0;
            overflow <= 1'b0;
            k_q <= '0;
            for (i = 0; i < 16; i = i + 1) begin
                a_q[i] <= '0;
                b_q[i] <= '0;
                acc_q[i] <= '0;
            end
        end else begin
            if (out_valid && out_ready)
                out_valid <= 1'b0;

            if (in_valid && in_ready) begin
                for (i = 0; i < 16; i = i + 1) begin
                    a_q[i] <= matrix_a[i*ELEM_W +: ELEM_W];
                    b_q[i] <= matrix_b[i*ELEM_W +: ELEM_W];
                    acc_q[i] <= '0;
                end
                overflow <= 1'b0;
                k_q <= '0;
                busy <= 1'b1;
            end else if (busy) begin
                for (i = 0; i < 16; i = i + 1) begin
                    acc_q[i] <= wide_sum[i][ACC_W-1:0];
                    if (wide_sum[i][ACC_W] != wide_sum[i][ACC_W-1])
                        overflow <= 1'b1;
                end

                if (k_q == 2'd3) begin
                    busy <= 1'b0;
                    out_valid <= 1'b1;
                end else begin
                    k_q <= k_q + 1'b1;
                end
            end
        end
    end
endmodule

