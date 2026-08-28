`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// ring_generator48.v - the accumulator, 48-bit version
//
// After Rajski et al., IEEE TCAD 42(9), Sep. 2023, Table I entry G48:
//
//     h(x) = x^48 + x^35 + x^22 + x^10 + 1
//
// WHERE THE THREE CHORDS COME FROM.
//
//     d_j = j,     s_j = j - a_j - 1  (mod 48)
//
//     a = 35  ->  d=0, s = 0 - 35 - 1 = -36 mod 48 = 12  ->  rS[0]  takes rS[12]
//     a = 22  ->  d=1, s = 1 - 22 - 1 = -22 mod 48 = 26  ->  rS[1]  takes rS[26]
//     a = 10  ->  d=2, s = 2 - 10 - 1 =  -9 mod 48 = 39  ->  rS[2]  takes rS[39]
//
// ENTROPY INJECTION.  Six taps from the ring oscillator, XORed into six
// flip-flops spread across the upper half of the ring.  iTap is NOT
// synchronised - that is deliberate; see ro_nand.v.
//
// SEED.  All-zero.  A linear generator with no injection stays at zero, so a
// dead oscillator produces an all-zero word every time and the failure is
// loud.  That only works because iClr reseeds before every word.
//////////////////////////////////////////////////////////////////////////////////

module ring_generator48 (
    input  wire        iClk,
    input  wire        iRstN,
    input  wire        iClr,        // synchronous restart to zero
    input  wire [5:0]  iTap,        // ASYNCHRONOUS, from ro_nand
    output wire [47:0] oState
);

    // ASYNC_REG does not remove the metastability - it is wanted here.  It
    // stops the tools retiming or replicating these flops and keeps them
    // placed together, which is what makes the design reproducible.
    (* ASYNC_REG = "true" *) reg [47:0] rS;

    always @(posedge iClk or negedge iRstN) begin
        if (!iRstN) begin
            rS <= 48'h0000_0000_0000;
        end else if (iClr) begin
            rS <= 48'h0000_0000_0000;
        end else begin
            // --- 3 chords (one per interior tap term) ---
            rS[ 0] <= rS[47] ^ rS[12];          // chord for x^35
            rS[ 1] <= rS[ 0] ^ rS[26];          // chord for x^22
            rS[ 2] <= rS[ 1] ^ rS[39];          // chord for x^10
            // --- pure shift ---
            rS[ 3] <= rS[ 2];
            rS[ 4] <= rS[ 3];
            rS[ 5] <= rS[ 4];
            rS[ 6] <= rS[ 5];
            rS[ 7] <= rS[ 6];
            rS[ 8] <= rS[ 7];
            rS[ 9] <= rS[ 8];
            rS[10] <= rS[ 9];
            rS[11] <= rS[10];
            rS[12] <= rS[11];
            rS[13] <= rS[12];
            rS[14] <= rS[13];
            rS[15] <= rS[14];
            rS[16] <= rS[15];
            rS[17] <= rS[16];
            rS[18] <= rS[17];
            rS[19] <= rS[18];
            rS[20] <= rS[19];
            rS[21] <= rS[20];
            rS[22] <= rS[21];
            rS[23] <= rS[22];
            rS[24] <= rS[23] ^ iTap[0];         // entropy injection
            rS[25] <= rS[24];
            rS[26] <= rS[25] ^ iTap[1];         // entropy injection
            rS[27] <= rS[26];
            rS[28] <= rS[27];
            rS[29] <= rS[28] ^ iTap[2];         // entropy injection
            rS[30] <= rS[29];
            rS[31] <= rS[30];
            rS[32] <= rS[31] ^ iTap[3];         // entropy injection
            rS[33] <= rS[32];
            rS[34] <= rS[33] ^ iTap[4];         // entropy injection
            rS[35] <= rS[34];
            rS[36] <= rS[35];
            rS[37] <= rS[36];
            rS[38] <= rS[37] ^ iTap[5];         // entropy injection
            rS[39] <= rS[38];
            rS[40] <= rS[39];
            rS[41] <= rS[40];
            rS[42] <= rS[41];
            rS[43] <= rS[42];
            rS[44] <= rS[43];
            rS[45] <= rS[44];
            rS[46] <= rS[45];
            rS[47] <= rS[46];
        end
    end

    assign oState = rS;

endmodule
