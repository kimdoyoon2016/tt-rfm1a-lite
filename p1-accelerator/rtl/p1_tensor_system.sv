`timescale 1ns/1ps

module p1_tensor_system #(
    parameter int LANES = 8,
    parameter int ELEM_W = 16,
    parameter int ACC_W = 48,
    parameter int RANK_MAX = 6,
    parameter int MEM_ADDR_W = 10
) (
    input logic clk,
    input logic rst_n,
    input logic host_valid,
    output logic host_ready,
    input logic host_mem_b,
    input logic [MEM_ADDR_W-1:0] host_addr,
    input logic [LANES*ELEM_W-1:0] host_wdata,
    input logic start_valid,
    output logic start_ready,
    input logic [2:0] opcode,
    input logic [2:0] rank,
    input logic [MEM_ADDR_W-1:0] a_base,
    input logic [MEM_ADDR_W-1:0] b_base,
    input logic [MEM_ADDR_W-1:0] c_base,
    input logic [RANK_MAX*16-1:0] shape,
    input logic [RANK_MAX*MEM_ADDR_W-1:0] a_stride,
    input logic [RANK_MAX*MEM_ADDR_W-1:0] b_stride,
    input logic [RANK_MAX*MEM_ADDR_W-1:0] c_stride,
    output logic result_valid,
    input logic result_ready,
    output logic result_scalar,
    output logic [LANES*ELEM_W-1:0] result_vector,
    output logic signed [ACC_W-1:0] result_accumulator,
    output logic store_valid,
    input logic store_ready,
    output logic [MEM_ADDR_W-1:0] store_addr,
    output logic [LANES*ELEM_W-1:0] store_data,
    output logic busy,
    output logic config_error
);
    logic desc_ready, tile_ready;
    logic desc_valid, desc_last, desc_busy, desc_advance;
    logic [MEM_ADDR_W-1:0] desc_a, desc_b, desc_c;
    logic tile_busy;
    logic [63:0] descriptor_beats;
    logic reduction_opcode;
    integer d;

    always_comb begin
        descriptor_beats = 64'd1;
        for (d = 0; d < RANK_MAX; d = d + 1) begin
            if (d < rank)
                descriptor_beats = descriptor_beats *
                    ((shape[d*16 +: 16] == 0) ? 1 : shape[d*16 +: 16]);
        end
    end

    assign reduction_opcode = (opcode >= 3'd2) && (opcode <= 3'd5);
    assign config_error = (rank > RANK_MAX) || (descriptor_beats > 64'd65535);
    assign start_ready = desc_ready && tile_ready && !config_error;
    assign busy = desc_busy || tile_busy;

    p1_descriptor_triplet #(.RANK_MAX(RANK_MAX), .ADDR_W(MEM_ADDR_W),
        .STRIDE_W(MEM_ADDR_W)) descriptors (
        .clk, .rst_n,
        .cfg_valid(start_valid && start_ready), .cfg_ready(desc_ready),
        .cfg_rank(rank), .cfg_a_base(a_base), .cfg_b_base(b_base), .cfg_c_base(c_base),
        .cfg_shape(shape), .cfg_a_stride(a_stride), .cfg_b_stride(b_stride),
        .cfg_c_stride(c_stride), .addr_valid(desc_valid), .addr_ready(desc_advance),
        .addr_a(desc_a), .addr_b(desc_b), .addr_c(desc_c), .addr_last(desc_last),
        .busy(desc_busy)
    );

    p1_compute_tile #(.LANES(LANES), .ELEM_W(ELEM_W), .ACC_W(ACC_W),
        .MEM_ADDR_W(MEM_ADDR_W), .EXTERNAL_ADDR(1'b1)) tile (
        .clk, .rst_n, .host_valid, .host_ready, .host_mem_b, .host_addr, .host_wdata,
        .start_valid(start_valid && start_ready), .start_ready(tile_ready),
        .start_opcode(opcode), .start_beats(descriptor_beats[15:0]),
        .start_a_base('0), .start_b_base('0), .start_c_base('0),
        .ext_addr_valid(desc_valid), .ext_addr_ready(desc_advance),
        .ext_a_addr(desc_a), .ext_b_addr(desc_b),
        .ext_c_addr(reduction_opcode ? c_base : desc_c),
        .result_valid, .result_ready, .result_scalar, .result_vector,
        .result_accumulator, .store_valid, .store_ready, .store_addr, .store_data,
        .busy(tile_busy)
    );
endmodule
