`timescale 1ns/1ps

module p1_tensor_core #(
    parameter int LANES = 8,
    parameter int ELEM_W = 16,
    parameter int ACC_W = 48,
    parameter int LEN_W = 16
) (
    input  logic                         clk,
    input  logic                         rst_n,

    input  logic                         cmd_valid,
    output logic                         cmd_ready,
    input  logic [2:0]                   cmd_opcode,
    input  logic [LEN_W-1:0]             cmd_beats,

    input  logic                         in_valid,
    output logic                         in_ready,
    input  logic [LANES*ELEM_W-1:0]      in_a,
    input  logic [LANES*ELEM_W-1:0]      in_b,

    output logic                         out_valid,
    input  logic                         out_ready,
    output logic                         out_scalar,
    output logic [LANES*ELEM_W-1:0]      out_vector,
    output logic signed [ACC_W-1:0]      out_accumulator,
    output logic                         busy
);

    localparam logic [2:0] OP_VADD   = 3'd0;
    localparam logic [2:0] OP_VMUL   = 3'd1;
    localparam logic [2:0] OP_DOT    = 3'd2;
    localparam logic [2:0] OP_REDSUM = 3'd3;
    localparam logic [2:0] OP_REDMAX = 3'd4;
    localparam logic [2:0] OP_REDMIN = 3'd5;

    logic [2:0] opcode_q;
    logic [LEN_W-1:0] beats_left_q;
    logic signed [ACC_W-1:0] accum_q;
    logic signed [ELEM_W-1:0] extremum_q;
    logic first_beat_q;

    logic elementwise;
    logic reduction;
    logic consume;
    logic last_beat;
    logic signed [ACC_W-1:0] lane_sum;
    logic signed [ELEM_W-1:0] beat_max;
    logic signed [ELEM_W-1:0] beat_min;
    logic signed [ACC_W-1:0] reduction_result;
    logic [LANES*ELEM_W-1:0] vector_result;

    integer i;
    logic signed [ELEM_W-1:0] a_lane;
    logic signed [ELEM_W-1:0] b_lane;
    logic signed [2*ELEM_W-1:0] product;

    always_comb begin
        elementwise = (opcode_q == OP_VADD) || (opcode_q == OP_VMUL);
        reduction   = (opcode_q == OP_DOT) || (opcode_q == OP_REDSUM) ||
                      (opcode_q == OP_REDMAX) || (opcode_q == OP_REDMIN);

        cmd_ready = !busy && !out_valid;
        in_ready  = busy && !out_valid;
        consume   = in_valid && in_ready;
        last_beat = (beats_left_q == {{(LEN_W-1){1'b0}}, 1'b1});

        lane_sum = '0;
        beat_max = $signed(in_a[ELEM_W-1:0]);
        beat_min = $signed(in_a[ELEM_W-1:0]);
        vector_result = '0;

        for (i = 0; i < LANES; i = i + 1) begin
            a_lane = $signed(in_a[i*ELEM_W +: ELEM_W]);
            b_lane = $signed(in_b[i*ELEM_W +: ELEM_W]);
            product = a_lane * b_lane;

            if (opcode_q == OP_VADD)
                vector_result[i*ELEM_W +: ELEM_W] = a_lane + b_lane;
            else if (opcode_q == OP_VMUL)
                vector_result[i*ELEM_W +: ELEM_W] = product[ELEM_W-1:0];

            if (opcode_q == OP_DOT)
                lane_sum = lane_sum + {{(ACC_W-2*ELEM_W){product[2*ELEM_W-1]}}, product};
            else if (opcode_q == OP_REDSUM)
                lane_sum = lane_sum + {{(ACC_W-ELEM_W){a_lane[ELEM_W-1]}}, a_lane};

            if (a_lane > beat_max)
                beat_max = a_lane;
            if (a_lane < beat_min)
                beat_min = a_lane;
        end

        reduction_result = accum_q + lane_sum;
        if (opcode_q == OP_REDMAX)
            reduction_result = first_beat_q || (beat_max > extremum_q) ? beat_max : extremum_q;
        else if (opcode_q == OP_REDMIN)
            reduction_result = first_beat_q || (beat_min < extremum_q) ? beat_min : extremum_q;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            opcode_q       <= '0;
            beats_left_q   <= '0;
            accum_q        <= '0;
            extremum_q     <= '0;
            first_beat_q   <= 1'b0;
            busy           <= 1'b0;
            out_valid      <= 1'b0;
            out_scalar     <= 1'b0;
            out_vector     <= '0;
            out_accumulator<= '0;
        end else begin
            if (out_valid && out_ready)
                out_valid <= 1'b0;

            if (cmd_valid && cmd_ready) begin
                opcode_q     <= cmd_opcode;
                beats_left_q <= (cmd_beats == '0) ? {{(LEN_W-1){1'b0}}, 1'b1} : cmd_beats;
                accum_q      <= '0;
                extremum_q   <= '0;
                first_beat_q <= 1'b1;
                busy         <= 1'b1;
            end

            if (consume) begin
                if (elementwise) begin
                    out_vector      <= vector_result;
                    out_accumulator <= '0;
                    out_scalar      <= 1'b0;
                    out_valid       <= 1'b1;
                end else if (reduction) begin
                    if ((opcode_q == OP_REDMAX) || (opcode_q == OP_REDMIN))
                        extremum_q <= reduction_result[ELEM_W-1:0];
                    else
                        accum_q <= reduction_result;

                    if (last_beat) begin
                        out_vector      <= '0;
                        out_accumulator <= reduction_result;
                        out_scalar      <= 1'b1;
                        out_valid       <= 1'b1;
                    end
                end

                first_beat_q <= 1'b0;
                if (last_beat) begin
                    beats_left_q <= '0;
                    busy <= 1'b0;
                end else begin
                    beats_left_q <= beats_left_q - 1'b1;
                end
            end
        end
    end

endmodule

