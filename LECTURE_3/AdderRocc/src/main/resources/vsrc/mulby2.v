`timescale 1ns / 1ps
module adder(
    input               iClk,
    input               iRst,
    input       [63:0]  iData,
    output  reg [63:0]  oData
    );
    
always @ (posedge iClk) begin
  if (iRst) begin
    oData <= 64'd0;
  end
  else begin
    oData <= iData << 1;
  end
end    
endmodule