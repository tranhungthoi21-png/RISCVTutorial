`default_nettype none
// DISCLAIMER
// ARTY A7 ONLY USED FOR FPGA, PLEASE SYNTHESIS THE top.sv FOR ASIC
module artya7_top(
    input wire clk,
    output wire uart_tx,
    input wire uart_rx,
    
    output wire spi0_clk,
    input wire spi0_miso,
    output wire spi0_mosi,
    output wire spi0_cs
    
);
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