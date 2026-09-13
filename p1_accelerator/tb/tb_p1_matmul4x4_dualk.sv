\`timescale 1ns/1ps
module tb_p1_matmul4x4_dualk;
    localparam int EW=16; localparam int AW=40;
    logic clk=0, rst_n=0;
    logic in_valid,in_ready,out_valid,out_ready,overflow,busy;
    logic [16*EW-1:0] matrix_a,matrix_b;
    logic [16*AW-1:0] matrix_c;
    integer r,c,k,expected,active_cycles;
    p1_matmul4x4_dualk dut (.*);
    always #5 clk=~clk;
    function automatic integer aval(input integer row,input integer col);
        aval=row*5-col*2+3;
    endfunction
    function automatic integer bval(input integer row,input integer col);
        bval=row+col-2;
    endfunction
    initial begin
        in_valid=0; out_ready=1; matrix_a='0; matrix_b='0;
        repeat(3) @(posedge clk); rst_n=1;
        for(r=0;r<4;r=r+1) for(c=0;c<4;c=c+1) begin
            matrix_a[(r*4+c)*EW +: EW]=aval(r,c);
            matrix_b[(r*4+c)*EW +: EW]=bval(r,c);
        end
        @(negedge clk);
        if(!in_ready) $fatal(1,"dual-K engine not initially ready");
        in_valid=1; @(negedge clk); in_valid=0;
        active_cycles=0;
        while(!out_valid) begin
            @(negedge clk); active_cycles=active_cycles+1;
            if(active_cycles>3) $fatal(1,"dual-K latency exceeded two cycles");
        end
        if(active_cycles!=2) $fatal(1,"expected 2 active cycles, got %0d",active_cycles);
        for(r=0;r<4;r=r+1) for(c=0;c<4;c=c+1) begin
            expected=0;
            for(k=0;k<4;k=k+1) expected=expected+aval(r,k)*bval(k,c);
            if($signed(matrix_c[(r*4+c)*AW +: AW])!==expected)
                $fatal(1,"dual-K C[%0d,%0d] mismatch",r,c);
        end
        if(overflow) $fatal(1,"unexpected dual-K overflow");
        out_ready=0;
        repeat(2) begin @(negedge clk); if(!out_valid) $fatal(1,"result lost"); end
        out_ready=1; @(negedge clk);
        $display("PASS: P1 dual-K 4x4 matrix multiply (2 cycles, 32 MAC/cycle)");
        $finish;
    end
endmodule
