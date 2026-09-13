`timescale 1ns/1ps

// Unified integer/floating execution block. Integer commands retain the
// original opcode map; floating commands perform one FP16 or BF16 vector MAC
// per beat using A*B+C.
module p1_execution_cluster #(
    parameter int LANES = 8,
    parameter int ELEM_W = 16,
    parameter int ACC_W = 48,
    parameter int LEN_W = 16
) (
    input logic clk,
    input logic rst_n,
    input logic cmd_valid,
    output logic cmd_ready,
    input logic cmd_floating,
    input logic cmd_bf16,
    input logic [2:0] cmd_opcode,
    input logic [LEN_W-1:0] cmd_beats,
    input logic in_valid,
    output logic in_ready,
    input logic [LANES*ELEM_W-1:0] in_a,
    input logic [LANES*ELEM_W-1:0] in_b,
    input logic [LANES*ELEM_W-1:0] in_c,
    output logic out_valid,
    input logic out_ready,
    output logic out_scalar,
    output logic [LANES*ELEM_W-1:0] out_vector,
    output logic signed [ACC_W-1:0] out_accumulator,
    output logic [3:0] fp_status,
    output logic busy
);
    logic int_cmd_ready, int_in_ready, int_out_valid, int_out_scalar, int_busy;
    logic [LANES*ELEM_W-1:0] int_out_vector;
    logic signed [ACC_W-1:0] int_out_accumulator;
    logic fp_active_q, fp_format_q;
    logic [LEN_W-1:0] fp_outputs_left_q;
    logic fp_in_ready, fp_out_valid;
    logic [LANES*16-1:0] fp_out_vector;
    logic [3:0] fp_out_status;
    logic command_fire, fp_output_fire;

    assign cmd_ready = !fp_active_q && !int_busy && !int_out_valid &&
                       (cmd_floating || int_cmd_ready);
    assign command_fire = cmd_valid && cmd_ready;
    assign in_ready = fp_active_q ? fp_in_ready : int_in_ready;
    assign out_valid = fp_active_q ? fp_out_valid : int_out_valid;
    assign out_scalar = fp_active_q ? 1'b0 : int_out_scalar;
    assign out_vector = fp_active_q ? fp_out_vector : int_out_vector;
    assign out_accumulator = fp_active_q ? '0 : int_out_accumulator;
    assign fp_status = fp_active_q ? fp_out_status : '0;
    assign busy = fp_active_q || int_busy || int_out_valid;
    assign fp_output_fire = fp_active_q && fp_out_valid && out_ready;

    p1_tensor_core #(.LANES(LANES), .ELEM_W(ELEM_W), .ACC_W(ACC_W),
        .LEN_W(LEN_W)) integer_core (
        .clk, .rst_n,
        .cmd_valid(command_fire && !cmd_floating), .cmd_ready(int_cmd_ready),
        .cmd_opcode, .cmd_beats,
        .in_valid(in_valid && !fp_active_q), .in_ready(int_in_ready),
        .in_a, .in_b,
        .out_valid(int_out_valid), .out_ready(out_ready && !fp_active_q),
        .out_scalar(int_out_scalar), .out_vector(int_out_vector),
        .out_accumulator(int_out_accumulator), .busy(int_busy)
    );

    p1_fp_vector_mac #(.LANES(LANES)) floating_core (
        .clk, .rst_n,
        .in_valid(in_valid && fp_active_q), .in_ready(fp_in_ready),
        .format_bf16(fp_format_q), .in_a, .in_b, .in_c,
        .out_valid(fp_out_valid), .out_ready(out_ready && fp_active_q),
        .out_y(fp_out_vector), .status(fp_out_status)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fp_active_q <= 1'b0;
            fp_format_q <= 1'b0;
            fp_outputs_left_q <= '0;
        end else begin
            if (command_fire && cmd_floating) begin
                fp_active_q <= 1'b1;
                fp_format_q <= cmd_bf16;
                fp_outputs_left_q <= (cmd_beats == 0) ? 1'b1 : cmd_beats;
            end
            if (fp_output_fire) begin
                if (fp_outputs_left_q == 1) begin
                    fp_outputs_left_q <= '0;
                    fp_active_q <= 1'b0;
                end else begin
                    fp_outputs_left_q <= fp_outputs_left_q - 1'b1;
                end
            end
        end
    end
endmodule
