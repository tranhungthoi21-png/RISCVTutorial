`timescale 1ns / 1ps
module trng_top48 #(
    parameter integer ACC    = 2048,
    parameter integer ROUNDS = 1
)(
    input  wire        iClk,
    input  wire        iRstN,
    input  wire        iEn,
    output wire [47:0] oWord,
    output wire        oValid,
    output wire        oRo,         
    output wire        oRaw,       
    output wire        oAlarm       
);

    wire wRaw;

    trng_core48 #(.ACC(ACC), .ROUNDS(ROUNDS)) u_core (
        .iClk  (iClk),
        .iRstN (iRstN),
        .iEn   (iEn),
        .oWord (oWord),
        .oValid(oValid),
        .oRo   (oRo),
        .oRaw  (wRaw)
    );

    assign oRaw = wRaw;

    health_tests u_health (
        .iClk     (iClk),
        .iRstN    (iRstN),
        .iEn      (iEn),
        .iRaw     (wRaw),
        .oRctAlarm(),
        .oAptAlarm(),
        .oAlarm   (oAlarm)
    );

endmodule
