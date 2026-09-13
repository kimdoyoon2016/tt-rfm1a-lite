`timescale 1ns/1ps

module p1_matmul4x4 #(
    parameter int ELEM_W = 16,
    parameter int ACC_W = 40
) (
    input  logic                         clk,
    input  logic                         rst_n,
    input  logic                         load_valid,
    output logic                         load_ready,
    input  logic                         load_matrix_b,
    input  logic [3:0]                   load_index,
    input  logic signed [ELEM_W-1:0]     load_data,
    input  logic                         start,
    output logic                         start_ready,
    output logic                         busy,
    output logic                         done,
    input  logic [3:0]                   result_index,
    output logic signed [ACC_W-1:0]      result_data
);
    logic signed [ELEM_W-1:0] a [0:15];
    logic signed [ELEM_W-1:0] b [0:15];
    logic signed [ACC_W-1:0] c [0:15];
    logic [1:0] row_q, col_q, k_q;
    logic signed [ACC_W-1:0] accum_q;
    logic signed [2*ELEM_W-1:0] product;
    logic signed [ACC_W-1:0] sum_next;

    assign load_ready = !busy;
    assign start_ready = !busy;
    assign result_data = c[result_index];
    assign product = a[{row_q, k_q}] * b[{k_q, col_q}];
    assign sum_next = accum_q + product;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy <= 1'b0;
            done <= 1'b0;
            row_q <= '0;
            col_q <= '0;
            k_q <= '0;
            accum_q <= '0;
        end else begin
            done <= 1'b0;
            if (load_valid && load_ready) begin
                if (load_matrix_b)
                    b[load_index] <= load_data;
                else
                    a[load_index] <= load_data;
            end

            if (start && start_ready) begin
                busy <= 1'b1;
                row_q <= '0;
                col_q <= '0;
                k_q <= '0;
                accum_q <= '0;
            end else if (busy) begin
                if (k_q == 2'd3) begin
                    c[{row_q, col_q}] <= sum_next;
                    k_q <= '0;
                    accum_q <= '0;
                    if (col_q == 2'd3) begin
                        col_q <= '0;
                        if (row_q == 2'd3) begin
                            row_q <= '0;
                            busy <= 1'b0;
                            done <= 1'b1;
                        end else begin
                            row_q <= row_q + 1'b1;
                        end
                    end else begin
                        col_q <= col_q + 1'b1;
                    end
                end else begin
                    accum_q <= sum_next;
                    k_q <= k_q + 1'b1;
                end
            end
        end
    end
endmodule

