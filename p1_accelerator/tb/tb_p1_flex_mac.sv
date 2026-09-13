module tb_p1_flex_mac;
 localparam int AW=32;
 logic clk=0,rst_n=0,clear,mode_int8,in_valid,in_ready,out_valid,out_ready;
 logic [31:0] in_a,in_b; logic [4*AW-1:0] accum; logic [3:0] overflow;
 p1_flex_mac #(.ACC_W(AW)) dut(.*);
 always #5 clk=~clk;
 task automatic send(input logic m8,input logic[31:0] a,input logic[31:0] b);
  begin
   @(negedge clk); while(!in_ready) @(negedge clk);
   mode_int8=m8; in_a=a; in_b=b; in_valid=1;
   @(negedge clk); in_valid=0;
  end
 endtask
 initial begin
  clear=0;mode_int8=0;in_valid=0;out_ready=1;in_a='0;in_b='0;
  repeat(3) @(posedge clk);rst_n=1;
  send(0,{16'sd4,-16'sd3},{-16'sd5,16'sd7});
  send(0,{16'sd2,16'sd6},{16'sd9,-16'sd4});
  if($signed(accum[0*AW+:AW])!==-45)$fatal(1,"INT16 lane 0");
  if($signed(accum[1*AW+:AW])!==-2)$fatal(1,"INT16 lane 1");
  if(accum[2*AW+:AW]!==0||accum[3*AW+:AW]!==0)$fatal(1,"inactive lanes");
  @(negedge clk);clear=1;@(negedge clk);clear=0;
  send(1,{8'sd8,-8'sd4,8'sd3,-8'sd2},{-8'sd2,8'sd5,-8'sd6,8'sd7});
  send(1,{8'sd1,8'sd2,8'sd3,8'sd4},{8'sd9,-8'sd3,8'sd2,-8'sd1});
  if($signed(accum[0*AW+:AW])!==-18)$fatal(1,"INT8 lane 0");
  if($signed(accum[1*AW+:AW])!==-12)$fatal(1,"INT8 lane 1");
  if($signed(accum[2*AW+:AW])!==-26)$fatal(1,"INT8 lane 2");
  if($signed(accum[3*AW+:AW])!==-7)$fatal(1,"INT8 lane 3");
  if(overflow!==0)$fatal(1,"unexpected overflow");
  out_ready=0;
  repeat(3) begin
   @(negedge clk);
   if(!out_valid)$fatal(1,"out_valid dropped");
   if($signed(accum[0*AW+:AW])!==-18)$fatal(1,"accum changed");
  end
  out_ready=1;@(negedge clk);
  $display("PASS: P1 FlexMAC INT16x2 / INT8x4");$finish;
 end
endmodule
