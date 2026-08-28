`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// uart_tx.v - 8N1 transmitter
//
// One frame is ten bit times: a start bit low, eight data bits least
// significant first, one stop bit high.  There is no parity and no flow
// control, which is all this design needs - the host asks for every word, so
// the board can never overrun it.
//
// CLK_PER_BIT = 434 is 50 MHz / 115200 = 434.03, an error of 0.006 %.  Over a
// ten-bit frame that is 0.06 % of a bit time, and a UART tolerates about 2 %,
// so this is nowhere near the edge.
//////////////////////////////////////////////////////////////////////////////////

module uart_tx #(
    parameter integer CLK_PER_BIT = 434
)(
    input  wire       iClk,
    input  wire       iRstN,
    input  wire       iDV,          // one-clock pulse: send iByte
    input  wire [7:0] iByte,
    output reg        oTx,
    output reg        oActive,
    output reg        oDone         // one-clock pulse at the end of the frame
);

    localparam [2:0] S_IDLE  = 3'd0,
                     S_START = 3'd1,
                     S_DATA  = 3'd2,
                     S_STOP  = 3'd3,
                     S_CLEAN = 3'd4;

    reg [2:0]  rState;
    reg [8:0]  rCnt;               // up to CLK_PER_BIT - 1
    reg [2:0]  rBit;
    reg [7:0]  rData;

    always @(posedge iClk or negedge iRstN) begin
        if (!iRstN) begin
            rState  <= S_IDLE;
            rCnt    <= 9'd0;
            rBit    <= 3'd0;
            rData   <= 8'd0;
            oTx     <= 1'b1;       // the line idles high
            oActive <= 1'b0;
            oDone   <= 1'b0;
        end else begin
            oDone <= 1'b0;
            case (rState)

            S_IDLE: begin
                oTx     <= 1'b1;
                oActive <= 1'b0;
                rCnt    <= 9'd0;
                rBit    <= 3'd0;
                if (iDV) begin
                    rData   <= iByte;
                    oActive <= 1'b1;
                    rState  <= S_START;
                end
            end

            S_START: begin
                oTx <= 1'b0;
                if (rCnt == CLK_PER_BIT - 1) begin
                    rCnt   <= 9'd0;
                    rState <= S_DATA;
                end else begin
                    rCnt <= rCnt + 9'd1;
                end
            end

            S_DATA: begin
                oTx <= rData[rBit];
                if (rCnt == CLK_PER_BIT - 1) begin
                    rCnt <= 9'd0;
                    if (rBit == 3'd7) begin
                        rBit   <= 3'd0;
                        rState <= S_STOP;
                    end else begin
                        rBit <= rBit + 3'd1;
                    end
                end else begin
                    rCnt <= rCnt + 9'd1;
                end
            end

            S_STOP: begin
                oTx <= 1'b1;
                if (rCnt == CLK_PER_BIT - 1) begin
                    rCnt   <= 9'd0;
                    oDone  <= 1'b1;
                    rState <= S_CLEAN;
                end else begin
                    rCnt <= rCnt + 9'd1;
                end
            end

            S_CLEAN: begin
                oActive <= 1'b0;
                rState  <= S_IDLE;
            end

            default: rState <= S_IDLE;
            endcase
        end
    end

endmodule
