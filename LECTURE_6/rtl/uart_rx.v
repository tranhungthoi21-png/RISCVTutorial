`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// uart_rx.v - 8N1 receiver
//
// The incoming line is asynchronous to our clock, so it goes through two
// flip-flops before anything looks at it.  That is the ONE place in this design
// where a synchroniser is correct - the oscillator taps deliberately do not
// have one, and the difference is worth pointing at: there we want the
// metastability, here we must not have it.
//
// Each bit is sampled in the MIDDLE of its bit time, not at the edge, so a
// small baud-rate error cannot walk into the next bit.
//////////////////////////////////////////////////////////////////////////////////

module uart_rx #(
    parameter integer CLK_PER_BIT = 434
)(
    input  wire       iClk,
    input  wire       iRstN,
    input  wire       iRx,
    output reg        oDV,          // one-clock pulse: oByte is valid
    output reg  [7:0] oByte
);

    localparam [2:0] S_IDLE  = 3'd0,
                     S_START = 3'd1,
                     S_DATA  = 3'd2,
                     S_STOP  = 3'd3,
                     S_CLEAN = 3'd4;

    (* ASYNC_REG = "true" *) reg rMeta, rRx;

    reg [2:0] rState;
    reg [8:0] rCnt;
    reg [2:0] rBit;

    always @(posedge iClk or negedge iRstN) begin
        if (!iRstN) begin
            rMeta <= 1'b1;
            rRx   <= 1'b1;
        end else begin
            rMeta <= iRx;
            rRx   <= rMeta;
        end
    end

    always @(posedge iClk or negedge iRstN) begin
        if (!iRstN) begin
            rState <= S_IDLE;
            rCnt   <= 9'd0;
            rBit   <= 3'd0;
            oDV    <= 1'b0;
            oByte  <= 8'd0;
        end else begin
            oDV <= 1'b0;
            case (rState)

            S_IDLE: begin
                rCnt <= 9'd0;
                rBit <= 3'd0;
                if (rRx == 1'b0) rState <= S_START;      // a start bit
            end

            S_START: begin
                if (rCnt == (CLK_PER_BIT - 1) / 2) begin
                    if (rRx == 1'b0) begin               // still low at mid-bit
                        rCnt   <= 9'd0;
                        rState <= S_DATA;
                    end else begin
                        rState <= S_IDLE;                // it was a glitch
                    end
                end else begin
                    rCnt <= rCnt + 9'd1;
                end
            end

            S_DATA: begin
                if (rCnt == CLK_PER_BIT - 1) begin
                    rCnt         <= 9'd0;
                    oByte[rBit]  <= rRx;
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
                if (rCnt == CLK_PER_BIT - 1) begin
                    rCnt   <= 9'd0;
                    oDV    <= 1'b1;
                    rState <= S_CLEAN;
                end else begin
                    rCnt <= rCnt + 9'd1;
                end
            end

            S_CLEAN: rState <= S_IDLE;

            default: rState <= S_IDLE;
            endcase
        end
    end

endmodule
