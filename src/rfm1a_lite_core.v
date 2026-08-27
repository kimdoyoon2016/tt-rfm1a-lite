`timescale 1ns/1ps
`default_nettype none

// Fixed V2 configuration: 8 x 32-bit working state, 2 branches, 2 frames.
module rfm1a_lite_core (
    input wire clk, input wire rst_n,
    input wire state_wr_valid, output wire state_wr_ready,
    input wire [2:0] state_wr_addr, input wire [31:0] state_wr_data,
    input wire [2:0] state_rd_addr, output wire [31:0] state_rd_data,
    input wire cmd_valid, output wire cmd_ready,
    input wire [2:0] cmd_opcode, input wire cmd_branch, input wire cmd_frame,
    output wire busy, output reg done, output reg error,
    output reg [3:0] error_code, output reg active_branch,
    output wire [1:0] active_frame_count
);
    localparam IDLE=3'd0, COPY_COMMIT=3'd1, COPY_FORK=3'd2,
               COPY_ROLLBACK=3'd3, CLEAR_WORKING=3'd4;
    reg [2:0] state;
    reg [31:0] working_mem [0:7];
    reg [31:0] frame_store [0:31];
    reg [1:0] frame_count [0:1];
    reg [2:0] word_index;
    reg target_branch, target_frame;
    wire [4:0] store_addr = {target_branch, target_frame, word_index};

    assign busy = state != IDLE;
    assign cmd_ready = state == IDLE;
    assign state_wr_ready = (state == IDLE) && !cmd_valid;
    assign state_rd_data = working_mem[state_rd_addr];
    assign active_frame_count = frame_count[active_branch];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE; active_branch <= 0; word_index <= 0;
            target_branch <= 0; target_frame <= 0;
            done <= 0; error <= 0; error_code <= 0;
            frame_count[0] <= 0; frame_count[1] <= 0;
        end else begin
            done <= 0; error <= 0; error_code <= 0;
            case (state)
                IDLE: begin
                    if (cmd_valid) begin
                        case (cmd_opcode)
                            3'd0: done <= 1;
                            3'd1: if (frame_count[active_branch] >= 2) begin
                                error <= 1; error_code <= 5;
                            end else begin
                                target_branch <= active_branch;
                                target_frame <= frame_count[active_branch][0];
                                word_index <= 0; state <= COPY_COMMIT;
                            end
                            3'd2: if (frame_count[cmd_branch] != 0) begin
                                error <= 1; error_code <= 4;
                            end else begin
                                target_branch <= cmd_branch; target_frame <= 0;
                                word_index <= 0; state <= COPY_FORK;
                            end
                            3'd3: if ({1'b0,cmd_frame} >= frame_count[cmd_branch]) begin
                                error <= 1; error_code <= 3;
                            end else begin
                                target_branch <= cmd_branch; target_frame <= cmd_frame;
                                word_index <= 0; state <= COPY_ROLLBACK;
                            end
                            3'd4: begin word_index <= 0; state <= CLEAR_WORKING; end
                            default: begin error <= 1; error_code <= 1; end
                        endcase
                    end else if (state_wr_valid)
                        working_mem[state_wr_addr] <= state_wr_data;
                end
                COPY_COMMIT: begin
                    frame_store[store_addr] <= working_mem[word_index];
                    if (word_index == 7) begin
                        frame_count[target_branch] <= frame_count[target_branch] + 1'b1;
                        state <= IDLE; done <= 1;
                    end else word_index <= word_index + 1'b1;
                end
                COPY_FORK: begin
                    frame_store[store_addr] <= working_mem[word_index];
                    if (word_index == 7) begin
                        frame_count[target_branch] <= 1;
                        active_branch <= target_branch; state <= IDLE; done <= 1;
                    end else word_index <= word_index + 1'b1;
                end
                COPY_ROLLBACK: begin
                    working_mem[word_index] <= frame_store[store_addr];
                    if (word_index == 7) begin
                        active_branch <= target_branch; state <= IDLE; done <= 1;
                    end else word_index <= word_index + 1'b1;
                end
                CLEAR_WORKING: begin
                    working_mem[word_index] <= 0;
                    if (word_index == 7) begin state <= IDLE; done <= 1; end
                    else word_index <= word_index + 1'b1;
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule

`default_nettype wire

