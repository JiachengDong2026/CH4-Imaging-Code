// Reused from DILA_260823. See Docs/复用代码来源.md.
module reset_sync(input wire clk, input wire arst_n, output wire srst);
  (* ASYNC_REG = "TRUE" *) reg [1:0] pipe;
  always @(posedge clk or negedge arst_n)
    if (!arst_n) pipe <= 2'b11; else pipe <= {pipe[0],1'b0};
  assign srst = pipe[1];
endmodule

