module p1_flex_mac_array #(parameter int CELLS=160,parameter int ACC_W=32)(
 input logic clk,input logic rst_n,input logic clear,input logic mode_int8,
 input logic in_valid,output logic in_ready,
 input logic[CELLS*32-1:0] in_a,input logic[CELLS*32-1:0] in_b,
 output logic out_valid,input logic out_ready,
 output logic[CELLS*4*ACC_W-1:0] accum,output logic[CELLS*4-1:0] overflow);
 logic[CELLS-1:0] cell_in_ready,cell_out_valid;
 genvar g;
 assign in_ready=cell_in_ready[0];
 assign out_valid=cell_out_valid[0];
 generate
  for(g=0;g<CELLS;g=g+1) begin:gen_flex_mac
   p1_flex_mac #(.ACC_W(ACC_W)) cell(
    .clk,.rst_n,.clear,.mode_int8,.in_valid,.in_ready(cell_in_ready[g]),
    .in_a(in_a[g*32+:32]),.in_b(in_b[g*32+:32]),
    .out_valid(cell_out_valid[g]),.out_ready,
    .accum(accum[g*4*ACC_W+:4*ACC_W]),.overflow(overflow[g*4+:4]));
  end
 endgenerate
endmodule
