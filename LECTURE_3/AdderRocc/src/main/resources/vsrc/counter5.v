`timescale 1ns / 1ps
module counter5(
  input              iClk,
  input              iRst,
  input      [5:0]   iDelay,
  input              iTrigger,
  output reg         oTrigger,
  output reg [5:0]   oCnt
  );

reg [5:0] count;
reg start;
always @ (posedge iClk) begin
  if (iRst) begin
    count  <= 6'd0;
    start  <= 1'b0;
    oCnt   <= 6'd0;
  end
  else begin
    if (iTrigger) 
      start <= 1'b1;
    else
      start <= start;
    if(start) begin
      oCnt <= count;
      if (count == iDelay)
        oTrigger <= 1'b1;
      else
        oTrigger <= 1'b0;
      if (count == 6'd32) begin
        start <= 1'b0;
        count <= 6'd0;
      end
      else 
        count <= count + 6'd1;
    end
    else oCnt <= 6'd0;
  end   
end 
endmodule
