`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// ro_nand.v - the entropy source, written out in full
//
// After Rajski et al., IEEE TCAD 42(9), Sep. 2023: one 2-input NAND gate and an
// EVEN number of inverters, so the loop has an odd number of inversions and
// oscillates.  Eleven elements here - the NAND plus ten inverters.
//
// WHY THE TAPS ARE SPREAD.  The paper is explicit about the purpose:
//
//   "The purpose of sampling many inverters is to populate a relatively long
//    interval with the timing jitter, hence maximizing the probability that at
//    least one noisy signal edge is captured in the ring generator."
//
// Consecutive stages carry the SAME edge one gate delay apart, so tapping six
// adjacent stages would give one signal and five near-copies covering barely a
// fifth of the period.  The six taps below are stages 0, 2, 4, 6, 7 and 9 of
// eleven - never two adjacent.  This is the single change that matters most
// against a design that taps neighbouring stages.
//
// NO SYNCHRONISER.  oTap goes straight into the XOR in front of a ring
// generator flip-flop, so those flops are clocked asynchronously to the
// oscillator and some samples land in the metastable window.  The paper counts
// that as a wanted contribution:
//
//   "some clock samples may stress the metastability region of the ring
//    generator FFs ... producing an additional and desired uncertainty"
//
// oRaw is a SEPARATE, synchronised copy of one tap, for the health tests and a
// scope probe only.  It is outside the entropy path.
//
// SYNTHESIS.  A combinational loop is illegal under every default design rule.
// Without KEEP / DONT_TOUCH the optimiser collapses it to a constant, the
// design still builds, still simulates, and produces a pure m-sequence with
// zero entropy that passes almost every statistical test.  The attributes are
// not style; they are the design.
//////////////////////////////////////////////////////////////////////////////////

(* dont_touch = "yes" *)
module ro_nand (
    input  wire       iClk,          // only for the oRaw observation flops
    input  wire       iRstN,
    input  wire       iEn,           // 0 parks the ring at a known level
    output wire [5:0] oTap,          // asynchronous, straight from the loop
    output wire       oRo,           // probe pin - bring this to a Pmod
    output reg        oRaw           // synchronised, health tests only
);

    (* ALLOW_COMBINATORIAL_LOOPS = "true" *)
    (* KEEP = "true" *) (* DONT_TOUCH = "yes" *)
    wire w0, w1, w2, w3, w4, w5, w6, w7, w8, w9, w10;

    assign w0  = ~(w10 & iEn);      // the NAND: enable AND the odd inversion
    assign w1  = ~w0;
    assign w2  = ~w1;
    assign w3  = ~w2;
    assign w4  = ~w3;
    assign w5  = ~w4;
    assign w6  = ~w5;
    assign w7  = ~w6;
    assign w8  = ~w7;
    assign w9  = ~w8;
    assign w10 = ~w9;

    assign oTap[0] = w0;            // stages 0, 2, 4, 6, 7, 9 of eleven -
    assign oTap[1] = w2;            // spread over the loop, never adjacent
    assign oTap[2] = w4;
    assign oTap[3] = w6;
    assign oTap[4] = w7;
    assign oTap[5] = w9;

    assign oRo = w10;

    // Observation only.  Two flops, so a metastable capture here cannot reach
    // the health-test logic.  The entropy path does not go through them.
    (* ASYNC_REG = "true" *) reg rMeta;

    always @(posedge iClk or negedge iRstN) begin
        if (!iRstN) begin
            rMeta <= 1'b0;
            oRaw  <= 1'b0;
        end else begin
            rMeta <= w0;
            oRaw  <= rMeta;
        end
    end

endmodule
