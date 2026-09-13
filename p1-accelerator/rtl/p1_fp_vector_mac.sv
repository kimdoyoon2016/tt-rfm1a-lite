`timescale 1ns/1ps

// Eight parallel floating-point multiply-add lanes. format_bf16=0 selects
// IEEE binary16 field widths; format_bf16=1 selects BF16 field widths.
// The operation is non-fused: multiplication and addition round separately.
module p1_fp_vector_mac #(
    parameter int LANES = 8
) (
    input  logic clk,
    input  logic rst_n,
    input  logic in_valid,
    output logic in_ready,
    input  logic format_bf16,
    input  logic [LANES*16-1:0] in_a,
    input  logic [LANES*16-1:0] in_b,
    input  logic [LANES*16-1:0] in_c,
    output logic out_valid,
    input  logic out_ready,
    output logic [LANES*16-1:0] out_y,
    output logic [3:0] status
);
    logic [15:0] fp16_y [0:LANES-1];
    logic [15:0] bf16_y [0:LANES-1];
    logic [3:0] fp16_status [0:LANES-1];
    logic [3:0] bf16_status [0:LANES-1];
    logic [LANES*16-1:0] selected_y;
    logic [3:0] selected_status;
    integer i;

    generate
        genvar g;
        for (g = 0; g < LANES; g = g + 1) begin : gen_lanes
            p1_float_mac #(.EXP_W(5), .FRAC_W(10)) fp16_mac (
                .a(in_a[g*16 +: 16]), .b(in_b[g*16 +: 16]),
                .c(in_c[g*16 +: 16]), .y(fp16_y[g]), .status(fp16_status[g])
            );
            p1_float_mac #(.EXP_W(8), .FRAC_W(7)) bf16_mac (
                .a(in_a[g*16 +: 16]), .b(in_b[g*16 +: 16]),
                .c(in_c[g*16 +: 16]), .y(bf16_y[g]), .status(bf16_status[g])
            );
        end
    endgenerate

    always_comb begin
        selected_y = '0;
        selected_status = '0;
        for (i = 0; i < LANES; i = i + 1) begin
            selected_y[i*16 +: 16] = format_bf16 ? bf16_y[i] : fp16_y[i];
            selected_status = selected_status |
                              (format_bf16 ? bf16_status[i] : fp16_status[i]);
        end
    end

    assign in_ready = !out_valid || out_ready;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_valid <= 1'b0;
            out_y <= '0;
            status <= '0;
        end else begin
            if (out_valid && out_ready)
                out_valid <= 1'b0;
            if (in_valid && in_ready) begin
                out_y <= selected_y;
                status <= selected_status;
                out_valid <= 1'b1;
            end
        end
    end
endmodule
