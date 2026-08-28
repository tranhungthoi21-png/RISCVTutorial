`timescale 1ns / 1ps

module sha3(
    input                iClk,
    input                iRst,
    input                iLast_blk,
    input       [1599:0] iMsg,
    input                iValid,
    output      [1599:0] oState,
    output reg           oDone,
    output reg           oFinish
    );
    
wire [1599:0] in_data_wire;
wire [1599:0] out_state_wire;
reg  [4:0]cnt;
assign oState = out_state_wire;
assign in_data_wire = (cnt == 0) ? (out_state_wire ^ iMsg) : out_state_wire;

reg [4:0] count;
reg [63:0] rc_wire;
    always @(*) begin
        case (cnt)
            5'd00: rc_wire = 64'h0000000000000001; 5'd01: rc_wire = 64'h0000000000008082;
            5'd02: rc_wire = 64'h800000000000808A; 5'd03: rc_wire = 64'h8000000080008000;
            5'd04: rc_wire = 64'h000000000000808B; 5'd05: rc_wire = 64'h0000000080000001;
            5'd06: rc_wire = 64'h8000000080008081; 5'd07: rc_wire = 64'h8000000000008009;
            5'd08: rc_wire = 64'h000000000000008A; 5'd09: rc_wire = 64'h0000000000000088;
            5'd10: rc_wire = 64'h0000000080008009; 5'd11: rc_wire = 64'h000000008000000A;
            5'd12: rc_wire = 64'h000000008000808B; 5'd13: rc_wire = 64'h800000000000008B;
            5'd14: rc_wire = 64'h8000000000008089; 5'd15: rc_wire = 64'h8000000000008003;
            5'd16: rc_wire = 64'h8000000000008002; 5'd17: rc_wire = 64'h8000000000000080;
            5'd18: rc_wire = 64'h000000000000800A; 5'd19: rc_wire = 64'h800000008000000A;
            5'd20: rc_wire = 64'h8000000080008081; 5'd21: rc_wire = 64'h8000000000008080;
            5'd22: rc_wire = 64'h0000000080000001; 5'd23: rc_wire = 64'h8000000080008008;
            default: rc_wire = 64'h0;
        endcase
    end
    

reg       start, active, valid_delay;
wire      valid_rise;
//============= catch the rising edge of in valid ==========
always @(posedge iClk) begin
  if(iRst) valid_delay <= 1'b0;
  else     valid_delay <= iValid;
end
assign valid_rise = iValid & ~valid_delay;

//=========================================================
always @ (posedge iClk) begin
  if (iRst) begin
    count   <= 5'd0;
    start   <= 1'b0;
    active  <= 1'b0;
    oDone   <= 1'b0;
    oFinish <= 1'b0;
    cnt     <= 5'd0;
  end
  else begin
    if (valid_rise ) begin 
      start <= 1'b1;
      count <= 5'd0;
      oDone <= 1'b0;
    end
    if(start) begin
      cnt    <= count;
      active <= 1'b1;
      if (count == 5'd24) begin
          oDone   <= 1'b1;
          oFinish <= iLast_blk;
          active  <= 1'b0;
          start   <= 1'b0;
        end
      else 
        count <= count + 5'd1;
    end
  end   
end 

keccak_f keccak_core(
    .iClk(iClk),
    .iRst(iRst),
    .iState(in_data_wire),
    .iActive(active),
    .iRC(rc_wire), 
    .oState(out_state_wire)
); 

endmodule
