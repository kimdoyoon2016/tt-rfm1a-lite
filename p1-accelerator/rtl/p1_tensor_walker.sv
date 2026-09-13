`timescale 1ns/1ps

module p1_tensor_walker #(
    parameter int RANK_MAX = 6,
    parameter int ADDR_W   = 32,
    parameter int DIM_W    = 16,
    parameter int STRIDE_W = 32
) (
    input  logic                         clk,
    input  logic                         rst_n,

    input  logic                         cfg_valid,
    output logic                         cfg_ready,
    input  logic [2:0]                   cfg_rank,
    input  logic [ADDR_W-1:0]            cfg_base,
    input  logic [RANK_MAX*DIM_W-1:0]    cfg_shape,
    input  logic [RANK_MAX*STRIDE_W-1:0] cfg_stride,

    output logic                         addr_valid,
    input  logic                         addr_ready,
    output logic [ADDR_W-1:0]            addr,
    output logic                         addr_last,
    output logic                         busy
);

    logic [2:0] rank_q;
    logic [ADDR_W-1:0] addr_q;
    logic [DIM_W-1:0] shape_q [0:RANK_MAX-1];
    logic [STRIDE_W-1:0] stride_q [0:RANK_MAX-1];
    logic [DIM_W-1:0] index_q [0:RANK_MAX-1];

    logic [ADDR_W-1:0] next_addr;
    logic [DIM_W-1:0] next_index [0:RANK_MAX-1];
    logic carry;
    integer i;

    always_comb begin
        cfg_ready  = !busy;
        addr_valid = busy;
        addr       = addr_q;
        addr_last  = busy;

        for (i = 0; i < RANK_MAX; i = i + 1) begin
            if (i < rank_q)
                addr_last = addr_last && (index_q[i] == shape_q[i] - 1'b1);
        end

        next_addr = addr_q;
        carry = 1'b1;
        for (i = 0; i < RANK_MAX; i = i + 1)
            next_index[i] = index_q[i];

        // Row-major iteration: the highest active dimension changes fastest.
        for (i = RANK_MAX-1; i >= 0; i = i - 1) begin
            if (carry && (i < rank_q)) begin
                if (index_q[i] + 1'b1 < shape_q[i]) begin
                    next_index[i] = index_q[i] + 1'b1;
                    next_addr = next_addr + stride_q[i];
                    carry = 1'b0;
                end else begin
                    next_addr = next_addr - (index_q[i] * stride_q[i]);
                    next_index[i] = '0;
                end
            end
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rank_q <= '0;
            addr_q <= '0;
            busy <= 1'b0;
            for (i = 0; i < RANK_MAX; i = i + 1) begin
                shape_q[i] <= {{(DIM_W-1){1'b0}}, 1'b1};
                stride_q[i] <= '0;
                index_q[i] <= '0;
            end
        end else begin
            if (cfg_valid && cfg_ready) begin
                rank_q <= (cfg_rank == 0) ? 3'd1 :
                          (cfg_rank > RANK_MAX) ? RANK_MAX[2:0] : cfg_rank;
                addr_q <= cfg_base;
                busy <= 1'b1;
                for (i = 0; i < RANK_MAX; i = i + 1) begin
                    shape_q[i] <= (cfg_shape[i*DIM_W +: DIM_W] == 0) ?
                                  {{(DIM_W-1){1'b0}}, 1'b1} : cfg_shape[i*DIM_W +: DIM_W];
                    stride_q[i] <= cfg_stride[i*STRIDE_W +: STRIDE_W];
                    index_q[i] <= '0;
                end
            end else if (addr_valid && addr_ready) begin
                if (addr_last) begin
                    busy <= 1'b0;
                end else begin
                    addr_q <= next_addr;
                    for (i = 0; i < RANK_MAX; i = i + 1)
                        index_q[i] <= next_index[i];
                end
            end
        end
    end
endmodule

