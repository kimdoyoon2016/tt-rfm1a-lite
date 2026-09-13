`timescale 1ns/1ps

module p1_command_fifo #(
    parameter int WIDTH = 256,
    parameter int DEPTH = 8,
    parameter int PTR_W = $clog2(DEPTH)
) (
    input  logic             clk,
    input  logic             rst_n,
    input  logic             push_valid,
    output logic             push_ready,
    input  logic [WIDTH-1:0] push_data,
    output logic             pop_valid,
    input  logic             pop_ready,
    output logic [WIDTH-1:0] pop_data,
    output logic [PTR_W:0]   occupancy,
    output logic             overflow_attempt,
    output logic             underflow_attempt
);
    logic [WIDTH-1:0] mem [0:DEPTH-1];
    logic [PTR_W-1:0] write_ptr_q, read_ptr_q;
    logic push, pop;

    // A full FIFO can still accept a command when one is removed that cycle.
    assign push_ready = (occupancy < DEPTH) || (pop_ready && pop_valid);
    assign pop_valid = (occupancy != 0);
    assign pop_data = mem[read_ptr_q];
    assign push = push_valid && push_ready;
    assign pop = pop_valid && pop_ready;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_ptr_q <= '0;
            read_ptr_q <= '0;
            occupancy <= '0;
            overflow_attempt <= 1'b0;
            underflow_attempt <= 1'b0;
        end else begin
            overflow_attempt <= push_valid && !push_ready;
            underflow_attempt <= pop_ready && !pop_valid;

            if (push) begin
                mem[write_ptr_q] <= push_data;
                write_ptr_q <= (write_ptr_q == DEPTH-1) ? '0 : write_ptr_q + 1'b1;
            end
            if (pop)
                read_ptr_q <= (read_ptr_q == DEPTH-1) ? '0 : read_ptr_q + 1'b1;

            case ({push, pop})
                2'b10: occupancy <= occupancy + 1'b1;
                2'b01: occupancy <= occupancy - 1'b1;
                default: occupancy <= occupancy;
            endcase
        end
    end
endmodule
