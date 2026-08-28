`timescale 1ns/1ps
`default_nettype none

// Tiny Tapeout byte-wide wrapper for the RFM-1A Lite V2 core.
module tt_um_rfm1a_lite (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);
    localparam BUS_SET_ADDR = 3'd0;
    localparam BUS_WRITE    = 3'd1;
    localparam BUS_READ     = 3'd2;
    localparam BUS_EXEC     = 3'd3;
    localparam BUS_STATUS   = 3'd4;
    localparam BUS_ERROR    = 3'd5;

    wire       request = uio_in[7];
    wire [2:0] bus_op  = uio_in[6:4];
    wire [1:0] byte_no = uio_in[1:0];
    reg        request_d;
    reg  [2:0] word_addr;
    reg  [7:0] response;

    reg        state_wr_valid;
    wire       state_wr_ready;
    reg  [2:0] state_wr_addr;
    reg [31:0] state_wr_data;
    wire [31:0] state_rd_data;
    reg        cmd_valid;
    wire       cmd_ready;
    reg  [2:0] cmd_opcode;
    reg        cmd_branch;
    reg        cmd_frame;
    wire       busy;
    wire       done;
    wire       error;
    wire [3:0] error_code;
    wire       active_branch;
    wire [1:0] active_frame_count;

    wire request_rise = request & ~request_d;
    wire host_ready = ena & cmd_ready & state_wr_ready;

    assign uo_out = response;
    // uio is deliberately input-only. Responses use uo_out, avoiding bus
    // turnaround and accidental feedback from an output-enabled request pin.
    assign uio_out = 8'h00;
    assign uio_oe = 8'h00;

    rfm1a_lite_core core (
        .clk(clk), .rst_n(rst_n),
        .state_wr_valid(state_wr_valid), .state_wr_ready(state_wr_ready),
        .state_wr_addr(state_wr_addr), .state_wr_data(state_wr_data),
        .state_rd_addr(word_addr), .state_rd_data(state_rd_data),
        .cmd_valid(cmd_valid), .cmd_ready(cmd_ready),
        .cmd_opcode(cmd_opcode), .cmd_branch(cmd_branch), .cmd_frame(cmd_frame),
        .busy(busy), .done(done), .error(error), .error_code(error_code),
        .active_branch(active_branch), .active_frame_count(active_frame_count)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            request_d <= 1'b0;
            word_addr <= 3'd0;
            response <= 8'd0;
            state_wr_valid <= 1'b0;
            state_wr_addr <= 3'd0;
            state_wr_data <= 32'd0;
            cmd_valid <= 1'b0;
            cmd_opcode <= 3'd0;
            cmd_branch <= 1'b0;
            cmd_frame <= 1'b0;
        end else begin
            request_d <= request;
            state_wr_valid <= 1'b0;
            cmd_valid <= 1'b0;
            if (ena && request_rise) begin
                case (bus_op)
                    BUS_SET_ADDR: word_addr <= ui_in[2:0];
                    BUS_WRITE: if (host_ready) begin
                        state_wr_addr <= word_addr;
                        state_wr_data <= state_rd_data;
                        case (byte_no)
                            2'd0: state_wr_data[7:0]   <= ui_in;
                            2'd1: state_wr_data[15:8]  <= ui_in;
                            2'd2: state_wr_data[23:16] <= ui_in;
                            2'd3: state_wr_data[31:24] <= ui_in;
                        endcase
                        state_wr_valid <= 1'b1;
                    end
                    BUS_READ: begin
                        case (byte_no)
                            2'd0: response <= state_rd_data[7:0];
                            2'd1: response <= state_rd_data[15:8];
                            2'd2: response <= state_rd_data[23:16];
                            2'd3: response <= state_rd_data[31:24];
                        endcase
                    end
                    BUS_EXEC: if (cmd_ready) begin
                        cmd_opcode <= ui_in[2:0];
                        cmd_branch <= ui_in[3];
                        cmd_frame <= ui_in[4];
                        cmd_valid <= 1'b1;
                    end
                    BUS_STATUS: response <= {active_frame_count, active_branch,
                                             error, busy, done, cmd_ready, state_wr_ready};
                    BUS_ERROR: response <= {4'h0, error_code};
                    default: response <= 8'hEE;
                endcase
            end
        end
    end
endmodule

`default_nettype wire

