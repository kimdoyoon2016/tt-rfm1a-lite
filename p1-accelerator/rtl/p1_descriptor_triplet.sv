`timescale 1ns/1ps

module p1_descriptor_triplet #(
    parameter int RANK_MAX = 6,
    parameter int ADDR_W = 10,
    parameter int DIM_W = 16,
    parameter int STRIDE_W = 10
) (
    input  logic clk,
    input  logic rst_n,
    input  logic cfg_valid,
    output logic cfg_ready,
    input  logic [2:0] cfg_rank,
    input  logic [ADDR_W-1:0] cfg_a_base,
    input  logic [ADDR_W-1:0] cfg_b_base,
    input  logic [ADDR_W-1:0] cfg_c_base,
    input  logic [RANK_MAX*DIM_W-1:0] cfg_shape,
    input  logic [RANK_MAX*STRIDE_W-1:0] cfg_a_stride,
    input  logic [RANK_MAX*STRIDE_W-1:0] cfg_b_stride,
    input  logic [RANK_MAX*STRIDE_W-1:0] cfg_c_stride,
    output logic addr_valid,
    input  logic addr_ready,
    output logic [ADDR_W-1:0] addr_a,
    output logic [ADDR_W-1:0] addr_b,
    output logic [ADDR_W-1:0] addr_c,
    output logic addr_last,
    output logic busy
);
    logic a_cfg_ready, b_cfg_ready, c_cfg_ready;
    logic a_valid, b_valid, c_valid;
    logic a_last, b_last, c_last;
    logic a_busy, b_busy, c_busy;
    logic advance;

    assign cfg_ready = a_cfg_ready && b_cfg_ready && c_cfg_ready;
    assign addr_valid = a_valid && b_valid && c_valid;
    assign addr_last = a_last && b_last && c_last;
    assign busy = a_busy || b_busy || c_busy;
    assign advance = addr_valid && addr_ready;

    p1_tensor_walker #(.RANK_MAX(RANK_MAX), .ADDR_W(ADDR_W),
        .DIM_W(DIM_W), .STRIDE_W(STRIDE_W)) walk_a (
        .clk, .rst_n, .cfg_valid(cfg_valid && cfg_ready), .cfg_ready(a_cfg_ready),
        .cfg_rank, .cfg_base(cfg_a_base), .cfg_shape, .cfg_stride(cfg_a_stride),
        .addr_valid(a_valid), .addr_ready(advance), .addr(addr_a),
        .addr_last(a_last), .busy(a_busy)
    );
    p1_tensor_walker #(.RANK_MAX(RANK_MAX), .ADDR_W(ADDR_W),
        .DIM_W(DIM_W), .STRIDE_W(STRIDE_W)) walk_b (
        .clk, .rst_n, .cfg_valid(cfg_valid && cfg_ready), .cfg_ready(b_cfg_ready),
        .cfg_rank, .cfg_base(cfg_b_base), .cfg_shape, .cfg_stride(cfg_b_stride),
        .addr_valid(b_valid), .addr_ready(advance), .addr(addr_b),
        .addr_last(b_last), .busy(b_busy)
    );
    p1_tensor_walker #(.RANK_MAX(RANK_MAX), .ADDR_W(ADDR_W),
        .DIM_W(DIM_W), .STRIDE_W(STRIDE_W)) walk_c (
        .clk, .rst_n, .cfg_valid(cfg_valid && cfg_ready), .cfg_ready(c_cfg_ready),
        .cfg_rank, .cfg_base(cfg_c_base), .cfg_shape, .cfg_stride(cfg_c_stride),
        .addr_valid(c_valid), .addr_ready(advance), .addr(addr_c),
        .addr_last(c_last), .busy(c_busy)
    );
endmodule

