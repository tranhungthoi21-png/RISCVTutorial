`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// ro_freq_counter.v - measure the ring-oscillator frequency IN FABRIC
//
// This is the first measurement of the laboratory, and it is not optional.  A
// ring oscillator whose frequency lands near an integer multiple of the
// sampling clock can injection-lock to it, and then every statistical test
// still passes while the entropy is gone.  You cannot see 160 MHz on a Pmod pin
// with a student oscilloscope, so the board has to count it itself.
//
// HOW.  oRo is far too fast to sample at 50 MHz, so it clocks an 8-bit ripple
// counter first.  Bit 7 of that counter completes one cycle every 256 RO edges,
// which is about 630 kHz - slow enough to synchronise and count.  Over exactly
// one second, counting the rising edges of that bit gives
//
//     f_RO  =  edges  x  256
//
// The result sits in oFreq and the host reads it with the 'f' command.
//
// The ripple counter is clocked by a net that is not a real clock, so Vivado
// will complain.  The XDC answers that complaint; it is not something to fix in
// the RTL.
//////////////////////////////////////////////////////////////////////////////////

module ro_freq_counter #(
    parameter integer CLK_HZ = 50000000       // the sampling clock, for the gate
)(
    input  wire        iClk,
    input  wire        iRstN,
    input  wire        iRo,                   // straight from the oscillator
    output reg  [31:0] oFreq                  // hertz, updated once a second
);

    // ------------------------------------------------ divide by 256, in the RO domain
    (* KEEP = "true" *) reg [7:0] rDiv;

    always @(posedge iRo) begin
        rDiv <= rDiv + 8'd1;
    end

    // ------------------------------------------------ back into the sampling domain
    (* ASYNC_REG = "true" *) reg rMeta, rSync, rSyncD;

    always @(posedge iClk or negedge iRstN) begin
        if (!iRstN) begin
            rMeta  <= 1'b0;
            rSync  <= 1'b0;
            rSyncD <= 1'b0;
        end else begin
            rMeta  <= rDiv[7];
            rSync  <= rMeta;
            rSyncD <= rSync;
        end
    end

    wire wEdge = rSync & ~rSyncD;             // one rising edge = 256 RO edges

    // ------------------------------------------------------------- the one-second gate
    reg [31:0] rGate;
    reg [23:0] rCount;

    always @(posedge iClk or negedge iRstN) begin
        if (!iRstN) begin
            rGate  <= 32'd0;
            rCount <= 24'd0;
            oFreq  <= 32'd0;
        end else if (rGate == CLK_HZ - 1) begin
            oFreq  <= {rCount, 8'd0};         // count x 256
            rGate  <= 32'd0;
            rCount <= 24'd0;
        end else begin
            rGate <= rGate + 32'd1;
            if (wEdge) rCount <= rCount + 24'd1;
        end
    end

endmodule
