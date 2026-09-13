`timescale 1ns/1ps

// Synthesizable binary floating-point primitives for FP16 (5/10) and
// BF16 (8/7). Round-to-nearest-even is implemented. Subnormal inputs and
// underflowed outputs are flushed to signed zero in this first revision.
module p1_float_mul #(
    parameter int EXP_W = 5,
    parameter int FRAC_W = 10,
    parameter int W = 1 + EXP_W + FRAC_W
) (
    input  logic [W-1:0] a,
    input  logic [W-1:0] b,
    output logic [W-1:0] y,
    output logic invalid,
    output logic overflow,
    output logic underflow,
    output logic inexact
);
    localparam int BIAS = (1 << (EXP_W-1)) - 1;
    localparam logic [EXP_W-1:0] EXP_MAX = {EXP_W{1'b1}};
    logic sa, sb;
    logic [EXP_W-1:0] ea_f, eb_f;
    logic [FRAC_W-1:0] fa, fb;
    logic a_nan, b_nan, a_inf, b_inf, a_zero, b_zero, a_sub, b_sub;
    logic [FRAC_W:0] ma, mb, kept;
    logic [2*FRAC_W+1:0] product;
    logic [FRAC_W+1:0] rounded;
    logic guard_bit, sticky_bit;
    integer exp_unbiased, exp_field;

    always_comb begin
        sa = a[W-1]; sb = b[W-1];
        ea_f = a[FRAC_W +: EXP_W]; eb_f = b[FRAC_W +: EXP_W];
        fa = a[FRAC_W-1:0]; fb = b[FRAC_W-1:0];
        a_nan = (ea_f == EXP_MAX) && (fa != 0);
        b_nan = (eb_f == EXP_MAX) && (fb != 0);
        a_inf = (ea_f == EXP_MAX) && (fa == 0);
        b_inf = (eb_f == EXP_MAX) && (fb == 0);
        a_zero = (ea_f == 0) && (fa == 0);
        b_zero = (eb_f == 0) && (fb == 0);
        a_sub = (ea_f == 0) && (fa != 0);
        b_sub = (eb_f == 0) && (fb != 0);
        ma = {1'b1, fa}; mb = {1'b1, fb};
        product = ma * mb;
        y = '0; invalid = 1'b0; overflow = 1'b0;
        underflow = 1'b0; inexact = 1'b0;
        kept = '0; rounded = '0; guard_bit = 1'b0; sticky_bit = 1'b0;
        exp_unbiased = 0; exp_field = 0;

        if (a_nan || b_nan || ((a_inf || b_inf) && (a_zero || b_zero || a_sub || b_sub))) begin
            y = {1'b0, EXP_MAX, 1'b1, {(FRAC_W-1){1'b0}}};
            invalid = (a_inf || b_inf) && (a_zero || b_zero || a_sub || b_sub);
        end else if (a_inf || b_inf) begin
            y = {sa ^ sb, EXP_MAX, {FRAC_W{1'b0}}};
        end else if (a_zero || b_zero || a_sub || b_sub) begin
            y = {sa ^ sb, {(W-1){1'b0}}};
            underflow = a_sub || b_sub;
            inexact = a_sub || b_sub;
        end else begin
            exp_unbiased = $unsigned(ea_f) + $unsigned(eb_f) - (2 * BIAS);
            if (product[2*FRAC_W+1]) begin
                kept = product[2*FRAC_W+1 -: FRAC_W+1];
                guard_bit = product[FRAC_W];
                if (FRAC_W > 0) sticky_bit = |product[FRAC_W-1:0];
                exp_unbiased = exp_unbiased + 1;
            end else begin
                kept = product[2*FRAC_W -: FRAC_W+1];
                guard_bit = product[FRAC_W-1];
                if (FRAC_W > 1) sticky_bit = |product[FRAC_W-2:0];
            end
            rounded = {1'b0, kept} + (guard_bit && (sticky_bit || kept[0]));
            if (rounded[FRAC_W+1]) begin
                kept = rounded[FRAC_W+1:1];
                exp_unbiased = exp_unbiased + 1;
            end else begin
                kept = rounded[FRAC_W:0];
            end
            exp_field = exp_unbiased + BIAS;
            inexact = guard_bit || sticky_bit;
            if (exp_field >= ((1 << EXP_W) - 1)) begin
                y = {sa ^ sb, EXP_MAX, {FRAC_W{1'b0}}};
                overflow = 1'b1; inexact = 1'b1;
            end else if (exp_field <= 0) begin
                y = {sa ^ sb, {(W-1){1'b0}}};
                underflow = 1'b1; inexact = 1'b1;
            end else begin
                y = {sa ^ sb, exp_field[EXP_W-1:0], kept[FRAC_W-1:0]};
            end
        end
    end
endmodule

module p1_float_add #(
    parameter int EXP_W = 5,
    parameter int FRAC_W = 10,
    parameter int W = 1 + EXP_W + FRAC_W,
    parameter int MW = FRAC_W + 4
) (
    input  logic [W-1:0] a,
    input  logic [W-1:0] b,
    output logic [W-1:0] y,
    output logic invalid,
    output logic overflow,
    output logic underflow,
    output logic inexact
);
    localparam int BIAS = (1 << (EXP_W-1)) - 1;
    localparam logic [EXP_W-1:0] EXP_MAX = {EXP_W{1'b1}};
    logic sa, sb, sign_result;
    logic [EXP_W-1:0] ea_f, eb_f;
    logic [FRAC_W-1:0] fa, fb;
    logic a_nan, b_nan, a_inf, b_inf, a_zero, b_zero, a_sub, b_sub;
    logic [MW-1:0] ma, mb, aligned_a, aligned_b, normalized;
    logic [MW:0] magnitude;
    logic [FRAC_W:0] kept;
    logic [FRAC_W+1:0] rounded;
    logic guard_bit, round_bit, sticky_bit;
    integer exp_a, exp_b, exp_result, exp_field, shift, j;

    function automatic [MW-1:0] shift_right_sticky(
        input logic [MW-1:0] value,
        input integer amount
    );
        logic [MW-1:0] temp;
        logic lost;
        integer k;
        begin
            temp = '0; lost = 1'b0;
            if (amount <= 0) temp = value;
            else if (amount >= MW) temp[0] = |value;
            else begin
                temp = value >> amount;
                for (k = 0; k < MW; k = k + 1)
                    if (k < amount) lost = lost | value[k];
                temp[0] = temp[0] | lost;
            end
            shift_right_sticky = temp;
        end
    endfunction

    always_comb begin
        sa = a[W-1]; sb = b[W-1];
        ea_f = a[FRAC_W +: EXP_W]; eb_f = b[FRAC_W +: EXP_W];
        fa = a[FRAC_W-1:0]; fb = b[FRAC_W-1:0];
        a_nan = (ea_f == EXP_MAX) && (fa != 0);
        b_nan = (eb_f == EXP_MAX) && (fb != 0);
        a_inf = (ea_f == EXP_MAX) && (fa == 0);
        b_inf = (eb_f == EXP_MAX) && (fb == 0);
        a_zero = (ea_f == 0) && (fa == 0);
        b_zero = (eb_f == 0) && (fb == 0);
        a_sub = (ea_f == 0) && (fa != 0);
        b_sub = (eb_f == 0) && (fb != 0);
        exp_a = $unsigned(ea_f) - BIAS;
        exp_b = $unsigned(eb_f) - BIAS;
        ma = {1'b1, fa, 3'b000};
        mb = {1'b1, fb, 3'b000};
        aligned_a = ma; aligned_b = mb; normalized = '0; magnitude = '0;
        sign_result = 1'b0; exp_result = 0; exp_field = 0; shift = 0;
        kept = '0; rounded = '0;
        guard_bit = 1'b0; round_bit = 1'b0; sticky_bit = 1'b0;
        y = '0; invalid = 1'b0; overflow = 1'b0;
        underflow = 1'b0; inexact = 1'b0;

        if (a_nan || b_nan || (a_inf && b_inf && (sa != sb))) begin
            y = {1'b0, EXP_MAX, 1'b1, {(FRAC_W-1){1'b0}}};
            invalid = a_inf && b_inf && (sa != sb);
        end else if (a_inf) y = a;
        else if (b_inf) y = b;
        else if (a_zero || a_sub) begin
            y = b_sub ? {sb, {(W-1){1'b0}}} : b;
            underflow = a_sub || b_sub; inexact = a_sub || b_sub;
        end else if (b_zero || b_sub) begin
            y = a;
            underflow = b_sub; inexact = b_sub;
        end else begin
            if (exp_a > exp_b) begin
                shift = exp_a - exp_b;
                aligned_b = shift_right_sticky(mb, shift);
                exp_result = exp_a;
            end else begin
                shift = exp_b - exp_a;
                aligned_a = shift_right_sticky(ma, shift);
                exp_result = exp_b;
            end

            if (sa == sb) begin
                magnitude = {1'b0, aligned_a} + {1'b0, aligned_b};
                sign_result = sa;
            end else if (aligned_a >= aligned_b) begin
                magnitude = {1'b0, aligned_a} - {1'b0, aligned_b};
                sign_result = sa;
            end else begin
                magnitude = {1'b0, aligned_b} - {1'b0, aligned_a};
                sign_result = sb;
            end

            if (magnitude == 0) begin
                y = '0;
            end else begin
                if (magnitude[MW]) begin
                    normalized = magnitude[MW:1];
                    normalized[0] = normalized[0] | magnitude[0];
                    exp_result = exp_result + 1;
                end else begin
                    normalized = magnitude[MW-1:0];
                    for (j = 0; j < MW-1; j = j + 1) begin
                        if (!normalized[MW-1]) begin
                            normalized = normalized << 1;
                            exp_result = exp_result - 1;
                        end
                    end
                end
                kept = normalized[MW-1:3];
                guard_bit = normalized[2]; round_bit = normalized[1];
                sticky_bit = normalized[0];
                rounded = {1'b0, kept} +
                          (guard_bit && (round_bit || sticky_bit || kept[0]));
                if (rounded[FRAC_W+1]) begin
                    kept = rounded[FRAC_W+1:1];
                    exp_result = exp_result + 1;
                end else kept = rounded[FRAC_W:0];
                exp_field = exp_result + BIAS;
                inexact = guard_bit || round_bit || sticky_bit;
                if (exp_field >= ((1 << EXP_W) - 1)) begin
                    y = {sign_result, EXP_MAX, {FRAC_W{1'b0}}};
                    overflow = 1'b1; inexact = 1'b1;
                end else if (exp_field <= 0) begin
                    y = {sign_result, {(W-1){1'b0}}};
                    underflow = 1'b1; inexact = 1'b1;
                end else begin
                    y = {sign_result, exp_field[EXP_W-1:0], kept[FRAC_W-1:0]};
                end
            end
        end
    end
endmodule

module p1_float_mac #(
    parameter int EXP_W = 5,
    parameter int FRAC_W = 10,
    parameter int W = 1 + EXP_W + FRAC_W
) (
    input logic [W-1:0] a, b, c,
    output logic [W-1:0] y,
    output logic [3:0] status
);
    logic [W-1:0] product;
    logic mi, mo, mu, mx, ai, ao, au, ax;
    p1_float_mul #(.EXP_W(EXP_W), .FRAC_W(FRAC_W)) mul (
        .a, .b, .y(product), .invalid(mi), .overflow(mo),
        .underflow(mu), .inexact(mx)
    );
    p1_float_add #(.EXP_W(EXP_W), .FRAC_W(FRAC_W)) add (
        .a(product), .b(c), .y, .invalid(ai), .overflow(ao),
        .underflow(au), .inexact(ax)
    );
    assign status = {mi | ai, mo | ao, mu | au, mx | ax};
endmodule
