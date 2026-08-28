`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// health_tests.v - NIST SP800-90B section 4.4, both continuous tests
//
// Rajski et al. do not include these.  They are required by SP800-90B for any
// source claiming an entropy estimate, and they are the only part of the whole
// design that runs forever.
//
// BOTH TESTS WATCH iRaw - THE SYNCHRONISED OSCILLATOR SAMPLE, never the ring
// generator output.  That is the entire design content of this module.  If the
// oscillator dies, the ring generator carries on producing a maximum-length
// sequence that passes every statistical test in existence, so a health test
// placed after it would report a healthy source forever.
//
//   4.4.1 Repetition Count
//     Alarm on 32 identical consecutive samples.  For an ideal source that is a
//     2^-31 event: one false alarm per two billion samples, rare enough to
//     ignore and frequent enough to catch a hard stop within a microsecond.
//
//   4.4.2 Adaptive Proportion
//     Over a window of 1024 samples, alarm if the FIRST sample of the window
//     recurs 589 times or more.  Catches slow bias and partial locking, which
//     the repetition count cannot see.  The cutoff is the exact binomial one
//     for H = 1 bit per sample at alpha = 2^-20, not a rounded guess.
//
// No parameters.  The two cutoffs follow from the entropy the source claims,
// and until that is measured on the board there is nothing to tune them with.
//////////////////////////////////////////////////////////////////////////////////

module health_tests (
    input  wire iClk,
    input  wire iRstN,
    input  wire iEn,
    input  wire iRaw,              // SYNCHRONISED oscillator sample
    output reg  oRctAlarm,
    output reg  oAptAlarm,
    output wire oAlarm
);

    localparam integer RCT_CUTOFF = 32;
    localparam integer APT_W      = 1024;
    localparam integer APT_CUTOFF = 589;

    assign oAlarm = oRctAlarm | oAptAlarm;

    // --------------------------------------------------- 4.4.1 repetition count
    reg       rPrev;
    reg [5:0] rRepeat;

    always @(posedge iClk or negedge iRstN) begin
        if (!iRstN) begin
            rPrev     <= 1'b0;
            rRepeat   <= 6'd0;
            oRctAlarm <= 1'b0;
        end else if (!iEn) begin
            rPrev   <= iRaw;
            rRepeat <= 6'd0;
        end else begin
            rPrev <= iRaw;
            if (iRaw == rPrev) begin
                if (rRepeat == RCT_CUTOFF - 1) oRctAlarm <= 1'b1;
                else                           rRepeat   <= rRepeat + 6'd1;
            end else begin
                rRepeat <= 6'd0;
            end
        end
    end

    // ------------------------------------------------ 4.4.2 adaptive proportion
    reg        rRef;               // first sample of the current window
    reg [10:0] rWin;               // samples seen in this window
    reg [10:0] rCount;             // how often rRef has recurred

    always @(posedge iClk or negedge iRstN) begin
        if (!iRstN) begin
            rRef      <= 1'b0;
            rWin      <= 11'd0;
            rCount    <= 11'd0;
            oAptAlarm <= 1'b0;
        end else if (!iEn) begin
            rWin   <= 11'd0;
            rCount <= 11'd0;
        end else begin
            if (rWin == 11'd0) begin            // start a new window
                rRef   <= iRaw;
                rCount <= 11'd1;
                rWin   <= 11'd1;
            end else begin
                if (iRaw == rRef) begin
                    if (rCount == APT_CUTOFF - 1) oAptAlarm <= 1'b1;
                    else                          rCount    <= rCount + 11'd1;
                end
                if (rWin == APT_W - 1) rWin <= 11'd0;
                else                   rWin <= rWin + 11'd1;
            end
        end
    end

endmodule
