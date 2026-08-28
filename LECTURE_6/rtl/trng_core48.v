`timescale 1ns / 1ps

module trng_core48 #(
    parameter integer ACC    = 2048,
    parameter integer ROUNDS = 1
)(
    input  wire        iClk,
    input  wire        iRstN,
    input  wire        iEn,
    output reg  [47:0] oWord,
    output reg         oValid,      // one-clock pulse, oWord holds
    output wire        oRo,         // ring-oscillator probe pin
    output wire        oRaw         // synchronised raw sample, health tests
);

    wire [5:0]  wTap;
    wire [47:0] wState;

    reg         rClr;
    reg  [31:0] rCnt;               // wide enough to hold ACC
    reg         rRound;
    reg  [47:0] rAcc0;

    ro_nand u_ro (
        .iClk (iClk),
        .iRstN(iRstN),
        .iEn  (iEn),
        .oTap (wTap),
        .oRo  (oRo),
        .oRaw (oRaw)
    );

    ring_generator48 u_rg (
        .iClk  (iClk),
        .iRstN (iRstN),
        .iClr  (rClr),
        .iTap  (wTap),
        .oState(wState)
    );

    always @(posedge iClk or negedge iRstN) begin
        if (!iRstN) begin
            rClr   <= 1'b1;
            rCnt   <= 32'd0;
            rRound <= 1'b0;
            rAcc0  <= 48'd0;
            oWord  <= 48'd0;
            oValid <= 1'b0;
        end else if (!iEn) begin
            rClr   <= 1'b1;
            rCnt   <= 32'd0;
            rRound <= 1'b0;
            oValid <= 1'b0;
        end else begin
            rClr   <= 1'b0;
            oValid <= 1'b0;

            if (rClr) begin
                rCnt <= 32'd0;
            end else if (rCnt != ACC) begin
                rCnt <= rCnt + 32'd1;
            end else begin
                rCnt <= 32'd0;
                if ((ROUNDS == 2) && (rRound == 1'b0)) begin
                    rAcc0  <= wState;
                    rRound <= 1'b1;
                    rClr   <= 1'b1;
                end else begin
                    oWord  <= (ROUNDS == 2) ? (wState ^ rAcc0) : wState;
                    oValid <= 1'b1;
                    rRound <= 1'b0;
                    rClr   <= 1'b1;
                end
            end
        end
    end

endmodule
