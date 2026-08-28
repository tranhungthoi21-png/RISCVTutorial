`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// trng_ctrl48.v - command decode for 48-bit TRNG word
//
// Identical to trng_ctrl.v except:
//   - iWord widened to 48 bits
//   - CMD_WORD reply is SIX bytes (not four), LSB first
//   - rIdx and rLast widened to 3 bits to count up to 5
//
//   'r' (0x72)  send the next TRNG word            - SIX bytes, LSB first
//   'f' (0x66)  send the ring-oscillator frequency - four bytes, LSB first
//   's' (0x73)  send the status byte               - one byte
//////////////////////////////////////////////////////////////////////////////////

module trng_ctrl48 (
    input  wire        iClk,
    input  wire        iRstN,

    input  wire        iRxDV,
    input  wire [7:0]  iRxByte,
    output reg         oTxDV,
    output reg  [7:0]  oTxByte,
    input  wire        iTxActive,
    input  wire        iTxDone,

    input  wire [47:0] iWord,        // from trng_top48 — 6 bytes
    input  wire        iValid,
    input  wire [31:0] iFreq,        // from ro_freq_counter — 4 bytes
    input  wire        iAlarm
);

    localparam [7:0] CMD_WORD = 8'h72,
                     CMD_FREQ = 8'h66,
                     CMD_STAT = 8'h73;

    localparam [1:0] S_IDLE = 2'd0,
                     S_SEND = 2'd1,
                     S_WAIT = 2'd2;

    reg [1:0]  rState;
    reg [2:0]  rIdx;           // 0..5 for 6-byte word
    reg [2:0]  rLast;          // last byte index
    reg [47:0] rShift;         // wide enough for 6 bytes

    reg [47:0] rWord;
    reg        rHave;

    always @(posedge iClk or negedge iRstN) begin
        if (!iRstN) begin
            rWord <= 48'd0;
            rHave <= 1'b0;
        end else begin
            if (iValid) begin
                rWord <= iWord;
                rHave <= 1'b1;
            end
            if (rState == S_IDLE && iRxDV && iRxByte == CMD_WORD)
                rHave <= 1'b0;
        end
    end

    always @(posedge iClk or negedge iRstN) begin
        if (!iRstN) begin
            rState  <= S_IDLE;
            rIdx    <= 3'd0;
            rLast   <= 3'd5;
            rShift  <= 48'd0;
            oTxDV   <= 1'b0;
            oTxByte <= 8'd0;
        end else begin
            oTxDV <= 1'b0;
            case (rState)

            S_IDLE: begin
                rIdx <= 3'd0;
                if (iRxDV) begin
                    if (iRxByte == CMD_WORD) begin
                        rShift  <= rWord;
                        rLast   <= 3'd5;          // 6 bytes: indices 0..5
                        oTxByte <= rWord[7:0];
                        oTxDV   <= 1'b1;
                        rState  <= S_WAIT;
                    end else if (iRxByte == CMD_FREQ) begin
                        rShift  <= {16'd0, iFreq};
                        rLast   <= 3'd3;          // 4 bytes: indices 0..3
                        oTxByte <= iFreq[7:0];
                        oTxDV   <= 1'b1;
                        rState  <= S_WAIT;
                    end else if (iRxByte == CMD_STAT) begin
                        rShift  <= {46'd0, rHave, iAlarm};
                        rLast   <= 3'd0;          // 1 byte
                        oTxByte <= {6'd0, rHave, iAlarm};
                        oTxDV   <= 1'b1;
                        rState  <= S_WAIT;
                    end
                end
            end

            S_WAIT: begin
                if (iTxDone) begin
                    if (rIdx == rLast) begin
                        rState <= S_IDLE;
                    end else begin
                        rIdx   <= rIdx + 3'd1;
                        rShift <= {8'd0, rShift[47:8]};
                        rState <= S_SEND;
                    end
                end
            end

            S_SEND: begin
                if (!iTxActive) begin
                    oTxByte <= rShift[7:0];
                    oTxDV   <= 1'b1;
                    rState  <= S_WAIT;
                end
            end

            default: rState <= S_IDLE;
            endcase
        end
    end

endmodule
