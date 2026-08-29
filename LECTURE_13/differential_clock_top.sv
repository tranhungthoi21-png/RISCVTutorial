`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/18/2026 02:09:52 PM
// Design Name: 
// Module Name: top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module genesystop(
    input wire sysclk_p,
    input wire sysclk_n,
    output wire uart_tx,
    input wire uart_rx,
    
    output wire spi0_clk,
    input wire spi0_miso,
    output wire spi0_mosi,
    output wire spi0_cs
    
    );
    wire clk;
    IBUFDS bufclk(.O(clk), .I(sysclk_p), .IB(sysclk_n));

    reg in_rstn = 1'b0;
    always_ff @(posedge clk)
        in_rstn <= 1'b1;
     top top0_inst(
        .clk, .in_rstn,
        .uart_tx, .uart_rx,
        .spi0_clk, .spi0_miso, .spi0_mosi, .spi0_cs,
        .gpo()
    );
endmodule
