`timescale 1ns / 1ps
module FIFO_32x64(
  input             iClk,
  input             iRst,
  input             iRdEn,
  input             iWrEn,
  input      [63:0] iData,
  output reg [63:0] oData
);

reg [63:0] fifo [0:31];
reg [ 4:0] read_pointer, write_pointer;
//reg count;    
//------------ writing --------------------
always @ (posedge iClk) begin
  if (iRst) begin
    write_pointer <= 5'd0;    
  end
  else if(iWrEn) begin
    fifo[write_pointer] <= iData;
    if (write_pointer < 5'd31)
      write_pointer <= write_pointer + 5'd1;
    else 
      write_pointer <= 5'd0;
  end
end
//------------- reading ---------------------
always @ (posedge iClk) begin
  if (iRst) begin
    read_pointer  <= 5'd0;
    oData <= 64'd0;
  end
  else if(iRdEn) begin
    oData <= fifo[read_pointer];
    if (read_pointer < 5'd31)
      read_pointer <= read_pointer + 5'd1;
    else 
      read_pointer <= 5'd0;  
  end
end    
endmodule
