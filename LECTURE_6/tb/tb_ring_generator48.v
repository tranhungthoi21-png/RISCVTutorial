`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// tb_ring_generator48.v - SELF-CHECKING, against an independent reference
//
// sim/golden_rg48.txt is produced by verify_rtl.py (Python software model),
// which simulates the transition equations directly:
//
//     h(x) = x^48 + x^35 + x^22 + x^10 + 1
//
//     rS[0]  = rS[47] ^ rS[12]   (chord for x^35)
//     rS[1]  = rS[0]  ^ rS[26]   (chord for x^22)
//     rS[2]  = rS[1]  ^ rS[39]   (chord for x^10)
//
// golden_rg48.txt is the independent reference - the design is correct only
// if every cycle matches.  The 8-bit LFSR (x^8+x^6+x^5+x^4+1, seed 0xA5)
// drives iTap identically in both the Python model and this testbench.
//
// All stimulus moves on the NEGATIVE edge so nothing races the DUT.
//
//   iverilog -g2005 -o build/tb_rg48 rtl/ring_generator48.v sim/tb_ring_generator48.v
//   vvp build/tb_rg48
//
// Vivado: add ring_generator48.v + tb_ring_generator48.v, set this as top,
//         put golden_rg48.txt in the sim/ folder, run Behavioral Simulation.
//////////////////////////////////////////////////////////////////////////////////

module tb_ring_generator48;

    localparam integer CYCLES = 512;

    reg         rClk  = 1'b0;
    reg         rRstN = 1'b0;
    reg         rClr  = 1'b1;
    reg  [5:0]  rTap  = 6'd0;
    wire [47:0] wState;

    reg  [47:0] gold [0:CYCLES-1];
    reg  [7:0]  rLfsr;
    integer     t, errors;

    always #5 rClk = ~rClk;

    ring_generator48 dut (
        .iClk  (rClk),
        .iRstN (rRstN),
        .iClr  (rClr),
        .iTap  (rTap),
        .oState(wState)
    );

    initial begin
        $readmemh("/home/hungthoik24/RISCVTutorial/generators/chipyard/src/main/resources/vsrc/lecture_6/golden_rg48.txt", gold);
        errors = 0;
        rRstN = 1'b0;
        rClr  = 1'b1;
        rTap  = 6'd0;
        @(negedge rClk);
        rRstN = 1'b1;           // iClr still 1: next posedge seeds to zero
        @(negedge rClk);
        rClr  = 1'b0;           // rS now holds the all-zero seed
        rLfsr = 8'hA5;          // same LFSR seed used in Python model

        for (t = 0; t < CYCLES; t = t + 1) begin
            rTap = rLfsr[5:0];
            if (wState !== gold[t]) begin
                $display("FAIL  cycle %0d: got %h, expected %h", t, wState, gold[t]);
                errors = errors + 1;
            end
            @(negedge rClk);
            // LFSR next: x^8 + x^6 + x^5 + x^4 + 1
            rLfsr = {rLfsr[6:0], rLfsr[7] ^ rLfsr[5] ^ rLfsr[4] ^ rLfsr[3]};
        end

        if (errors == 0)
            $display("PASS  %0d states match the reference trace", CYCLES);
        else
            $display("FAIL  %0d mismatches in %0d cycles", errors, CYCLES);
        $finish;
    end

    initial begin
        $dumpfile("tb_ring_generator48.vcd");
        $dumpvars(0, tb_ring_generator48);
    end

endmodule