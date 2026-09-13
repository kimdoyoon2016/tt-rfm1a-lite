module p1_flex_mac #(parameter int ACC_W=32) (
 input logic clk,input logic rst_n,input logic clear,input logic mode_int8,
 input logic in_valid,output logic in_ready,input logic [31:0] in_a,input logic [31:0] in_b,
 output logic out_valid,input logic out_ready,output logic [4*ACC_W-1:0] accum,
 output logic [3:0] overflow);
 localparam int WIDE_W=ACC_W+1;
 logic signed [ACC_W-1:0] acc_q[0:3];
 logic signed [WIDE_W-1:0] next_sum[0:3];
 logic signed [15:0] a16[0:1],b16[0:1];
 logic signed [7:0] a8[0:3],b8[0:3];
 integer comb_i,seq_i;
 assign in_ready=!out_valid||out_ready;
 always_comb begin
  for(comb_i=0;comb_i<2;comb_i=comb_i+1) begin
   a16[comb_i]=in_a[comb_i*16+:16]; b16[comb_i]=in_b[comb_i*16+:16];
  end
  for(comb_i=0;comb_i<4;comb_i=comb_i+1) begin
   a8[comb_i]=in_a[comb_i*8+:8]; b8[comb_i]=in_b[comb_i*8+:8];
   next_sum[comb_i]=$signed(acc_q[comb_i]); accum[comb_i*ACC_W+:ACC_W]=acc_q[comb_i];
  end
  if(mode_int8) for(comb_i=0;comb_i<4;comb_i=comb_i+1)
   next_sum[comb_i]=$signed(acc_q[comb_i])+$signed(a8[comb_i])*$signed(b8[comb_i]);
  else for(comb_i=0;comb_i<2;comb_i=comb_i+1)
   next_sum[comb_i]=$signed(acc_q[comb_i])+$signed(a16[comb_i])*$signed(b16[comb_i]);
 end
 always_ff @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
   out_valid<=0; overflow<='0;
   for(seq_i=0;seq_i<4;seq_i=seq_i+1) acc_q[seq_i]<='0;
  end else begin
   if(out_valid&&out_ready) out_valid<=0;
   if(clear) begin
    out_valid<=0; overflow<='0;
    for(seq_i=0;seq_i<4;seq_i=seq_i+1) acc_q[seq_i]<='0;
   end else if(in_valid&&in_ready) begin
    out_valid<=1;
    if(mode_int8) for(seq_i=0;seq_i<4;seq_i=seq_i+1) begin
     acc_q[seq_i]<=next_sum[seq_i][ACC_W-1:0];
     if(next_sum[seq_i][ACC_W]!=next_sum[seq_i][ACC_W-1]) overflow[seq_i]<=1;
    end else for(seq_i=0;seq_i<2;seq_i=seq_i+1) begin
     acc_q[seq_i]<=next_sum[seq_i][ACC_W-1:0];
     if(next_sum[seq_i][ACC_W]!=next_sum[seq_i][ACC_W-1]) overflow[seq_i]<=1;
    end
   end
  end
 end
endmodule
