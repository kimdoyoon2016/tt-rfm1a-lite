module tb_p1_flex_mac_array;
 localparam int CELLS=4;localparam int AW=32;
 logic clk=0,rst_n=0,clear,mode_int8,in_valid,in_ready,out_valid,out_ready;
 logic[CELLS*32-1:0] in_a,in_b;logic[CELLS*4*AW-1:0] accum;
 logic[CELLS*4-1:0] overflow;integer cell_i,lane_i,expected;
 p1_flex_mac_array #(.CELLS(CELLS),.ACC_W(AW)) dut(.*);
 always #5 clk=~clk;
 initial begin
  clear=0;mode_int8=1;in_valid=0;out_ready=1;in_a='0;in_b='0;
  repeat(3)@(posedge clk);rst_n=1;
  for(cell_i=0;cell_i<CELLS;cell_i=cell_i+1)
   for(lane_i=0;lane_i<4;lane_i=lane_i+1)begin
    in_a[cell_i*32+lane_i*8+:8]=cell_i*4+lane_i+1;
    in_b[cell_i*32+lane_i*8+:8]=lane_i-3;
   end
  @(negedge clk);if(!in_ready)$fatal(1,"array not ready");
  in_valid=1;@(negedge clk);in_valid=0;
  if(!out_valid)$fatal(1,"array result missing");
  for(cell_i=0;cell_i<CELLS;cell_i=cell_i+1)
   for(lane_i=0;lane_i<4;lane_i=lane_i+1)begin
    expected=(cell_i*4+lane_i+1)*(lane_i-3);
    if($signed(accum[(cell_i*4+lane_i)*AW+:AW])!==expected)
     $fatal(1,"cell %0d lane %0d mismatch",cell_i,lane_i);
   end
  if(overflow!==0)$fatal(1,"unexpected array overflow");
  out_ready=0;@(negedge clk);
  if(in_ready||!out_valid)$fatal(1,"array handshake mismatch");
  out_ready=1;@(negedge clk);
  $display("PASS: P1 FlexMAC array (%0d test cells)",CELLS);$finish;
 end
endmodule
