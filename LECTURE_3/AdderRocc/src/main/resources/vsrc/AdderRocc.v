`timescale 1ns / 1ps
module AdderRocc(
    input               iClk,
    input               iRst,
    input               iWrEn,
    input               iRdEn,
    input               iValid,
    input               iSel,
    input       [63:0]  iData,
    output reg  [63:0]  oData,
    output reg          oValid,
    output reg          oReady
);
//-------------------------------------------//
//------------- executing NTT ---------------//

wire [63:0] adder_in_data, adder_out_data;

adder A0(
    .iClk(iClk),
    .iRst(iRst),
    .iData(adder_in_data),
    .oData(adder_out_data)
);
//----------------------------------------//
//---------- signal form controller ------//
wire out_ready, out_valid;
wire rocc_read_en, rocc_write_en;

controller CTR(
    .iClk(iClk),
    .iValid(iValid),
    .iRst(iRst),
    .oRdEn(rocc_read_en),
    .oWrEn(rocc_write_en),
    .oReady(out_ready),
    .oValid(out_valid)
);
//---------------------------------------//
// ------------- signal for FIFO --------//
wire fifo_read_en, fifo_write_en;
wire [63:0] fifo_in_data, fifo_out_data;

FIFO_32x64 FIFO(
  .iClk(iClk),
  .iRst(iRst),
  .iRdEn(fifo_read_en),
  .iWrEn(fifo_write_en),
  .iData(fifo_in_data),
  .oData(fifo_out_data)
);
//---------------------------------------//
wire [63:0] rocc_out_data;
assign fifo_in_data  = iSel ? adder_out_data : iData;
assign fifo_read_en  = iSel ? rocc_read_en  : iRdEn;
assign fifo_write_en = iSel ? rocc_write_en : iWrEn;
assign {adder_in_data, rocc_out_data} = iSel ? {fifo_out_data, 64'd0} : {64'd0,fifo_out_data};
//---------------------------------------------------------------------------------------------//
always @ (posedge iClk) begin
  oValid <= out_valid;
  oReady <= out_ready;
  oData  <= rocc_out_data;
end
endmodule
