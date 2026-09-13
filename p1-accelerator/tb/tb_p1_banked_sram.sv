`timescale 1ns/1ps

module tb_p1_banked_sram;
    logic clk = 0;
    logic rst_n = 0;
    logic req_valid, req_ready, req_write;
    logic [9:0] req_addr;
    logic [127:0] req_wdata;
    logic rsp_valid, rsp_ready;
    logic [127:0] rsp_rdata;

    p1_banked_sram dut (.*);
    always #5 clk = ~clk;

    task automatic request(input logic wr, input logic [9:0] a, input logic [127:0] d);
        begin
            @(negedge clk);
            while (!req_ready) @(negedge clk);
            req_write = wr;
            req_addr = a;
            req_wdata = d;
            req_valid = 1;
            @(negedge clk);
            req_valid = 0;
        end
    endtask

    initial begin
        req_valid = 0;
        req_write = 0;
        req_addr = 0;
        req_wdata = 0;
        rsp_ready = 1;
        repeat (3) @(posedge clk);
        rst_n = 1;

        request(1, 10'd5, 128'h0123456789abcdef_fedcba9876543210);
        request(1, 10'd6, 128'h1111222233334444_5555666677778888);
        request(0, 10'd5, '0);
        while (!rsp_valid) @(negedge clk);
        if (rsp_rdata !== 128'h0123456789abcdef_fedcba9876543210)
            $fatal(1, "banked SRAM read mismatch");

        request(0, 10'd6, '0);
        while (!rsp_valid) @(negedge clk);
        if (rsp_rdata !== 128'h1111222233334444_5555666677778888)
            $fatal(1, "second bank read mismatch");

        $display("PASS: P1 banked SRAM");
        $finish;
    end
endmodule

