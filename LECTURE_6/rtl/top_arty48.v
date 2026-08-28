`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// top_arty.v - the board.  This is the file Vivado synthesises.
//
// Digilent Arty A7-35T.  Seven pins do everything:
//
//   E3   100 MHz crystal
//   C2   reset button (active low on this board)
//   A8   slide switch SW0 - the enable.  Down = source parked.
//   A9   USB-UART, host -> FPGA
//   D10  USB-UART, FPGA -> host
//   E15  Pmod JB1 - the divided ring oscillator, for a scope
//   LEDs H5 J5 T9 T10
//
// THE CLOCK.  Everything in the design and every number in the lecture assumes
// 50 MHz: ACC = 2048 is 41 us per word, and the UART divider is 434.  The Arty
// crystal is 100 MHz, so it is halved here.  A toggled flip-flop is not a clock
// until it goes through a BUFG - without one Vivado routes it on local fabric
// and the design may or may not close timing depending on placement, which is
// exactly the sort of thing that makes a laboratory irreproducible.
//
// LEDs, so a student can see what is wrong without a debugger:
//   LD0  health alarm  - the source stopped, or is badly biased
//   LD1  enable        - the switch position, so nobody debugs a parked source
//   LD2  activity      - toggles on every word produced
//   LD3  ring alive    - the oscillator, divided down far enough to see
//////////////////////////////////////////////////////////////////////////////////

module top_arty (
    input  wire       CLK100MHZ,
    input  wire       ck_rst,          // active low
    input  wire       sw0,             // enable
    input  wire       uart_txd_in,     // host -> FPGA
    output wire       uart_rxd_out,    // FPGA -> host
    output wire       jb1,             // ring-oscillator probe
    output wire [3:0] led
);

    localparam integer CLK_PER_BIT = 434;      // 50 MHz / 115200
    localparam integer ACC         = 2048;     // as in the paper
    localparam integer ROUNDS      = 1;        // 2 = two windows XORed

    // --------------------------------------------------------------- 100 -> 50 MHz
    reg  rDiv2 = 1'b0;
    wire wClk;

    always @(posedge CLK100MHZ) rDiv2 <= ~rDiv2;

`ifdef SIM
    assign wClk = rDiv2;
`else
    BUFG u_bufg (.I(rDiv2), .O(wClk));
`endif

    // ------------------------------------------------------------------- reset
    // ck_rst is a button: bouncy and asynchronous.  Assert asynchronously,
    // release synchronously, which is the only reset style that is safe here.
    (* ASYNC_REG = "true" *) reg rRst0, rRst1;

    always @(posedge wClk or negedge ck_rst) begin
        if (!ck_rst) begin
            rRst0 <= 1'b0;
            rRst1 <= 1'b0;
        end else begin
            rRst0 <= 1'b1;
            rRst1 <= rRst0;
        end
    end

    wire wRstN = rRst1;
    wire wEn   = sw0;

    // ------------------------------------------------------------------- the TRNG
    wire [47:0] wWord;                   // widened for ring_generator48
    wire        wValid, wRo, wRaw, wAlarm;

    trng_top48 #(.ACC(ACC), .ROUNDS(ROUNDS)) u_trng (
        .iClk (wClk),
        .iRstN(wRstN),
        .iEn  (wEn),
        .oWord(wWord),
        .oValid(wValid),
        .oRo  (wRo),
        .oRaw (wRaw),
        .oAlarm(wAlarm)
    );

    // ------------------------------------------------------- frequency measurement
    wire [31:0] wFreq;

    ro_freq_counter #(.CLK_HZ(50000000)) u_freq (
        .iClk (wClk),
        .iRstN(wRstN),
        .iRo  (wRo),
        .oFreq(wFreq)
    );

    // ------------------------------------------------------------------- the UART
    wire       wRxDV;
    wire [7:0] wRxByte;
    wire       wTxDV, wTxActive, wTxDone;
    wire [7:0] wTxByte;

    uart_rx #(.CLK_PER_BIT(CLK_PER_BIT)) u_rx (
        .iClk (wClk),
        .iRstN(wRstN),
        .iRx  (uart_txd_in),
        .oDV  (wRxDV),
        .oByte(wRxByte)
    );

    uart_tx #(.CLK_PER_BIT(CLK_PER_BIT)) u_tx (
        .iClk (wClk),
        .iRstN(wRstN),
        .iDV  (wTxDV),
        .iByte(wTxByte),
        .oTx  (uart_rxd_out),
        .oActive(wTxActive),
        .oDone(wTxDone)
    );

    trng_ctrl48 u_ctrl (
        .iClk (wClk),
        .iRstN(wRstN),
        .iRxDV(wRxDV),
        .iRxByte(wRxByte),
        .oTxDV(wTxDV),
        .oTxByte(wTxByte),
        .iTxActive(wTxActive),
        .iTxDone(wTxDone),
        .iWord(wWord),
        .iValid(wValid),
        .iFreq(wFreq),
        .iAlarm(wAlarm)
    );

    // ------------------------------------------------------------------- the LEDs
    reg  rBeat;
    always @(posedge wClk or negedge wRstN) begin
        if (!wRstN)      rBeat <= 1'b0;
        else if (wValid) rBeat <= ~rBeat;
    end

    // the oscillator divided far enough down to be visible to a human eye
    (* KEEP = "true" *) reg [23:0] rRoDiv;
    always @(posedge wRo) rRoDiv <= rRoDiv + 24'd1;

    (* ASYNC_REG = "true" *) reg rRoMeta, rRoSeen;
    always @(posedge wClk) begin
        rRoMeta <= rRoDiv[23];
        rRoSeen <= rRoMeta;
    end

    assign led[0] = wAlarm;
    assign led[1] = wEn;
    assign led[2] = rBeat;
    assign led[3] = rRoSeen;

    assign jb1 = rRoDiv[7];        // divided, so a slow scope can see it

endmodule
