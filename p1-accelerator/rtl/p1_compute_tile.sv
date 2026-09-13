`timescale 1ns/1ps

module p1_compute_tile #(
    parameter int LANES = 8,
    parameter int ELEM_W = 16,
    parameter int ACC_W = 48,
    parameter int MEM_ADDR_W = 10,
    parameter bit EXTERNAL_ADDR = 1'b0
) (
    input  logic                         clk,
    input  logic                         rst_n,

    input  logic                         host_valid,
    output logic                         host_ready,
    input  logic                         host_mem_b,
    input  logic [MEM_ADDR_W-1:0]        host_addr,
    input  logic [LANES*ELEM_W-1:0]      host_wdata,

    input  logic                         start_valid,
    output logic                         start_ready,
    input  logic [2:0]                   start_opcode,
    input  logic [15:0]                  start_beats,
    input  logic [MEM_ADDR_W-1:0]        start_a_base,
    input  logic [MEM_ADDR_W-1:0]        start_b_base,
    input  logic [MEM_ADDR_W-1:0]        start_c_base,

    input  logic                         ext_addr_valid,
    output logic                         ext_addr_ready,
    input  logic [MEM_ADDR_W-1:0]        ext_a_addr,
    input  logic [MEM_ADDR_W-1:0]        ext_b_addr,
    input  logic [MEM_ADDR_W-1:0]        ext_c_addr,

    output logic                         result_valid,
    input  logic                         result_ready,
    output logic                         result_scalar,
    output logic [LANES*ELEM_W-1:0]      result_vector,
    output logic signed [ACC_W-1:0]      result_accumulator,
    output logic                         store_valid,
    input  logic                         store_ready,
    output logic [MEM_ADDR_W-1:0]        store_addr,
    output logic [LANES*ELEM_W-1:0]      store_data,
    output logic                         busy
);
    localparam int WORD_W = LANES * ELEM_W;
    typedef enum logic [2:0] {S_IDLE, S_COMMAND, S_ISSUE, S_FEED, S_DRAIN} state_t;
    state_t state_q;

    logic [2:0] opcode_q;
    logic [15:0] beats_q, beat_index_q;
    logic [MEM_ADDR_W-1:0] a_addr_q, b_addr_q, c_addr_q;

    logic a_req_valid, a_req_ready, a_req_write;
    logic b_req_valid, b_req_ready, b_req_write;
    logic [MEM_ADDR_W-1:0] a_req_addr, b_req_addr;
    logic [WORD_W-1:0] a_req_wdata, b_req_wdata;
    logic a_rsp_valid, b_rsp_valid, a_rsp_ready, b_rsp_ready;
    logic [WORD_W-1:0] a_rsp_data, b_rsp_data;

    logic core_cmd_valid, core_cmd_ready;
    logic core_in_valid, core_in_ready;
    logic core_busy;
    logic core_out_valid, core_out_ready, core_out_scalar;
    logic [WORD_W-1:0] core_out_vector;
    logic signed [ACC_W-1:0] core_out_accumulator;
    logic consume_pair;
    logic consume_result;
    logic issue_fire;

    assign busy = (state_q != S_IDLE);
    assign start_ready = (state_q == S_IDLE) && !host_valid;
    assign host_ready = (state_q == S_IDLE) &&
                        (host_mem_b ? b_req_ready : a_req_ready);

    assign a_req_valid = ((state_q == S_IDLE) && host_valid && !host_mem_b) ||
                         ((state_q == S_ISSUE) && !core_out_valid &&
                          (!EXTERNAL_ADDR || ext_addr_valid));
    assign b_req_valid = ((state_q == S_IDLE) && host_valid && host_mem_b) ||
                         ((state_q == S_ISSUE) && !core_out_valid &&
                          (!EXTERNAL_ADDR || ext_addr_valid));
    assign a_req_write = (state_q == S_IDLE);
    assign b_req_write = (state_q == S_IDLE);
    assign a_req_addr = (state_q == S_IDLE) ? host_addr :
                        (EXTERNAL_ADDR ? ext_a_addr : a_addr_q);
    assign b_req_addr = (state_q == S_IDLE) ? host_addr :
                        (EXTERNAL_ADDR ? ext_b_addr : b_addr_q);
    assign a_req_wdata = host_wdata;
    assign b_req_wdata = host_wdata;

    assign core_cmd_valid = (state_q == S_COMMAND);
    assign core_in_valid = (state_q == S_FEED) && a_rsp_valid && b_rsp_valid;
    assign consume_pair = core_in_valid && core_in_ready;
    assign a_rsp_ready = ((state_q == S_IDLE) || consume_pair);
    assign b_rsp_ready = ((state_q == S_IDLE) || consume_pair);
    assign result_valid = core_out_valid && store_ready;
    assign store_valid = core_out_valid && result_ready;
    assign core_out_ready = result_ready && store_ready;
    assign consume_result = core_out_valid && core_out_ready;
    assign issue_fire = (state_q == S_ISSUE) && a_req_valid && b_req_valid &&
                        a_req_ready && b_req_ready;
    assign ext_addr_ready = EXTERNAL_ADDR && issue_fire;
    assign result_scalar = core_out_scalar;
    assign result_vector = core_out_vector;
    assign result_accumulator = core_out_accumulator;
    assign store_addr = c_addr_q;
    assign store_data = core_out_scalar ?
        {{(WORD_W-ACC_W){core_out_accumulator[ACC_W-1]}}, core_out_accumulator} :
        core_out_vector;

    p1_banked_sram #(.WORD_W(WORD_W), .ADDR_W(MEM_ADDR_W)) mem_a (
        .clk, .rst_n,
        .req_valid(a_req_valid), .req_ready(a_req_ready),
        .req_write(a_req_write), .req_addr(a_req_addr), .req_wdata(a_req_wdata),
        .rsp_valid(a_rsp_valid), .rsp_ready(a_rsp_ready), .rsp_rdata(a_rsp_data)
    );

    p1_banked_sram #(.WORD_W(WORD_W), .ADDR_W(MEM_ADDR_W)) mem_b (
        .clk, .rst_n,
        .req_valid(b_req_valid), .req_ready(b_req_ready),
        .req_write(b_req_write), .req_addr(b_req_addr), .req_wdata(b_req_wdata),
        .rsp_valid(b_rsp_valid), .rsp_ready(b_rsp_ready), .rsp_rdata(b_rsp_data)
    );

    p1_tensor_core #(.LANES(LANES), .ELEM_W(ELEM_W), .ACC_W(ACC_W)) core (
        .clk, .rst_n,
        .cmd_valid(core_cmd_valid), .cmd_ready(core_cmd_ready),
        .cmd_opcode(opcode_q), .cmd_beats(beats_q),
        .in_valid(core_in_valid), .in_ready(core_in_ready),
        .in_a(a_rsp_data), .in_b(b_rsp_data),
        .out_valid(core_out_valid), .out_ready(core_out_ready),
        .out_scalar(core_out_scalar), .out_vector(core_out_vector),
        .out_accumulator(core_out_accumulator), .busy(core_busy)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_q <= S_IDLE;
            opcode_q <= '0;
            beats_q <= '0;
            beat_index_q <= '0;
            a_addr_q <= '0;
            b_addr_q <= '0;
            c_addr_q <= '0;
        end else begin
            case (state_q)
                S_IDLE: if (start_valid && start_ready) begin
                    opcode_q <= start_opcode;
                    beats_q <= (start_beats == 0) ? 16'd1 : start_beats;
                    beat_index_q <= '0;
                    a_addr_q <= start_a_base;
                    b_addr_q <= start_b_base;
                    c_addr_q <= start_c_base;
                    state_q <= S_COMMAND;
                end
                S_COMMAND: if (core_cmd_ready)
                    state_q <= S_ISSUE;
                S_ISSUE: if (issue_fire) begin
                    if (EXTERNAL_ADDR)
                        c_addr_q <= ext_c_addr;
                    state_q <= S_FEED;
                end
                S_FEED: if (consume_pair) begin
                    if (beat_index_q + 1'b1 == beats_q) begin
                        state_q <= S_DRAIN;
                    end else begin
                        beat_index_q <= beat_index_q + 1'b1;
                        if (!EXTERNAL_ADDR) begin
                            a_addr_q <= a_addr_q + 1'b1;
                            b_addr_q <= b_addr_q + 1'b1;
                        end
                        state_q <= S_ISSUE;
                    end
                end
                S_DRAIN: if (!core_busy && !core_out_valid)
                    state_q <= S_IDLE;
                default: state_q <= S_IDLE;
            endcase
            if (consume_result && !EXTERNAL_ADDR)
                c_addr_q <= c_addr_q + 1'b1;
        end
    end
endmodule
