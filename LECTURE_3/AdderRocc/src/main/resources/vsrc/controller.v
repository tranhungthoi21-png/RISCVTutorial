`timescale 1ns / 1ps
module controller(
    input               iClk,
    input               iValid,
    input               iRst,
    output reg          oRdEn,
    output reg          oWrEn,
    output reg          oReady,
    output reg          oValid
    );
//---------- counter for reading FIFO send to adder -------
wire write_trig;
wire [5:0] cnt_read;    
counter5 CNT0(
  .iClk(iClk),
  .iRst(iRst),
  .iDelay(6'd0),
  .iTrigger(iValid),
  .oTrigger(write_trig),
  .oCnt(cnt_read)
);
reg  read_en;
wire done_trig;
wire read_done;

always @ (posedge iClk) begin
   if(iRst) begin
     read_en <= 1'b0;
   end
   else begin
     if(iValid) 
       read_en <= 1'b1; // turn on the read_en signal for FIFO
     else if (cnt_read == 6'd32) 
       read_en <= 1'b0; // turn off the readen signal for FIFO when all data is read
    end
end

always @ (posedge iClk) begin
  if (iRst) 
    oRdEn <= 1'b0;
  else begin
    oRdEn <= (cnt_read < 6'd31) ? read_en : 1'b0;
  end
end

// ------------- counter for writing the coefficients-----------
wire [5:0] cnt_write;
counter5 CNT2(
  .iClk(iClk),
  .iRst(iRst),
  .iDelay(6'd31),
  .iTrigger(write_trig),
  .oTrigger(done_trig),
  .oCnt(cnt_write)
);

reg start_writing;

always @ (posedge iClk) begin
  if (iRst) begin
    start_writing <= 1'b0;
  end
  else begin
    if (write_trig)   
      start_writing  <= 1'b1; 
    else if(done_trig) 
      start_writing  <= 1'b0;
  end 
end

always @ (posedge iClk) begin
  if (iRst) begin
    oWrEn   <= 1'b0;
    oReady  <= 1'b0;
    oValid  <= 1'b0;
  end
  else begin
    oWrEn   <= (cnt_write < 6'd31) ? start_writing : 1'b0;
    oReady  <= done_trig;
    oValid  <= done_trig;
  end
end

endmodule
