`timescale 1ns/1ps

module p1_banked_sram #(
    parameter int BANKS = 4,
    parameter int WORD_W = 128,
    parameter int WORDS_PER_BANK = 256,
    parameter int ADDR_W = $clog2(BANKS * WORDS_PER_BANK)
) (
    input  logic              clk,
    input  logic              rst_n,
    input  logic              req_valid,
    output logic              req_ready,
    input  logic              req_write,
    input  logic [ADDR_W-1:0] req_addr,
    input  logic [WORD_W-1:0] req_wdata,
    output logic              rsp_valid,
    input  logic              rsp_ready,
    output logic [WORD_W-1:0] rsp_rdata
);
    localparam int BANK_W = $clog2(BANKS);
    localparam int ROW_W = $clog2(WORDS_PER_BANK);

    logic [WORD_W-1:0] mem [0:BANKS-1][0:WORDS_PER_BANK-1];
    logic [BANK_W-1:0] bank_sel;
    logic [ROW_W-1:0] row_sel;

    assign bank_sel = req_addr[BANK_W-1:0];
    assign row_sel = req_addr[ADDR_W-1:BANK_W];
    assign req_ready = !rsp_valid || rsp_ready;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rsp_valid <= 1'b0;
            rsp_rdata <= '0;
        end else begin
            if (rsp_valid && rsp_ready)
                rsp_valid <= 1'b0;

            if (req_valid && req_ready) begin
                if (req_write) begin
                    mem[bank_sel][row_sel] <= req_wdata;
                    rsp_rdata <= '0;
                end else begin
                    rsp_rdata <= mem[bank_sel][row_sel];
                end
                rsp_valid <= 1'b1;
            end
        end
    end
endmodule

