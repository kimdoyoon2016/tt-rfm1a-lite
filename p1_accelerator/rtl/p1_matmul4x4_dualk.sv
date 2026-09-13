`timescale 1ns/1ps

// Throughput-oriented 4x4 signed matrix engine.
// Two K slices are evaluated per active cycle: 32 MACs/cycle, 2 cycles/tile.
module p1_matmul4x4_dualk #(
    parameter int ELEM_W = 16,
    parameter int ACC_W  = 40
) (
    input logic clk, input logic rst_n,
    input logic in_valid, output logic in_ready,
    input logic [16*ELEM_W-1:0] matrix_a,
    input logic [16*ELEM_W-1:0] matrix_b,
    output logic out_valid, input logic out_ready,
    output logic [16*ACC_W-1:0] matrix_c,
    output logic overflow, output logic busy
);
    localparam int PROD_W = 2*ELEM_W;
    localparam int WIDE_W = ACC_W+2;
    logic signed [ELEM_W-1:0] a_q [0:15];
    logic signed [ELEM_W-1:0] b_q [0:15];
    logic signed [ACC_W-1:0] acc_q [0:15];
    logic phase_q;
    logic signed [PROD_W-1:0] product0 [0:15];
    logic signed [PROD_W-1:0] product1 [0:15];
    logic signed [WIDE_W-1:0] wide_sum [0:15];
    integer comb_i, r, c;
    integer seq_i;

    assign in_ready = !busy && (!out_valid || out_ready);

    always_comb begin
        for (r = 0; r < 4; r = r + 1) begin
            for (c = 0; c < 4; c = c + 1) begin
                product0[r*4+c] = a_q[r*4+(phase_q ? 2 : 0)] *
                                  b_q[(phase_q ? 2 : 0)*4+c];
                product1[r*4+c] = a_q[r*4+(phase_q ? 3 : 1)] *
                                  b_q[(phase_q ? 3 : 1)*4+c];
                wide_sum[r*4+c] =
                    {{(WIDE_W-ACC_W){acc_q[r*4+c][ACC_W-1]}}, acc_q[r*4+c]} +
                    {{(WIDE_W-PROD_W){product0[r*4+c][PROD_W-1]}}, product0[r*4+c]} +
                    {{(WIDE_W-PROD_W){product1[r*4+c][PROD_W-1]}}, product1[r*4+c]};
            end
        end
        for (comb_i = 0; comb_i < 16; comb_i = comb_i + 1)
            matrix_c[comb_i*ACC_W +: ACC_W] = acc_q[comb_i];
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy <= 1'b0; out_valid <= 1'b0; overflow <= 1'b0; phase_q <= 1'b0;
            for (seq_i = 0; seq_i < 16; seq_i = seq_i + 1) begin
                a_q[seq_i] <= '0; b_q[seq_i] <= '0; acc_q[seq_i] <= '0;
            end
        end else begin
            if (out_valid && out_ready) out_valid <= 1'b0;
            if (in_valid && in_ready) begin
                for (seq_i = 0; seq_i < 16; seq_i = seq_i + 1) begin
                    a_q[seq_i] <= matrix_a[seq_i*ELEM_W +: ELEM_W];
                    b_q[seq_i] <= matrix_b[seq_i*ELEM_W +: ELEM_W];
                    acc_q[seq_i] <= '0;
                end
                overflow <= 1'b0; phase_q <= 1'b0; busy <= 1'b1;
            end else if (busy) begin
                for (seq_i = 0; seq_i < 16; seq_i = seq_i + 1) begin
                    acc_q[seq_i] <= wide_sum[seq_i][ACC_W-1:0];
                    if (wide_sum[seq_i][ACC_W+1:ACC_W] != {2{wide_sum[seq_i][ACC_W-1]}})
                        overflow <= 1'b1;
                end
                if (phase_q) begin busy <= 1'b0; out_valid <= 1'b1; end
                else phase_q <= 1'b1;
            end
        end
    end
endmodule
