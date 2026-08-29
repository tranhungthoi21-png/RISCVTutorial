`default_nettype none


module SIFIVE_GPO #(
    parameter GPIO_PORTS = 8
)(
    input wire clk,
    input wire rstn,
    slv_interface.slv bus_if,
    output wire[GPIO_PORTS-1:0] gpo
);


    reg[GPIO_PORTS-1:0] output_val;


    
    reg[GPIO_PORTS-1:0] output_val_q;
    always_ff @(posedge clk or negedge rstn)
        if (!rstn) begin
            output_val_q <= '0;
        end else begin
            output_val_q <= output_val;
        end
    assign gpo = output_val_q;
    
    reg[GPIO_PORTS-1:0] rdata_out;
    always @(posedge clk or negedge rstn)
        if (!rstn)
            rdata_out <= '0;
        else if (bus_if.avalid)
            case ({bus_if.addr[11:2], 2'b00})
                32'h0C: rdata_out <= output_val;
                default: rdata_out <= '0;
            endcase
    reg rvalid;
    always @(posedge clk or negedge rstn)
        if (!rstn)
            rvalid <= 1'b0;
        else
            rvalid <= bus_if.avalid;
    assign bus_if.rvalid = rvalid;
    assign bus_if.aready = 1'b1;
    assign bus_if.rdata = rdata_out;
    
                        
    reg[GPIO_PORTS-1:0] input_prev;
    always @(posedge clk or negedge rstn)
        if (!rstn) begin
            output_val <= '0;
        end else begin
            if (bus_if.avalid && bus_if.awren)
                case ({bus_if.addr[11:2], 2'b00})
                    32'h0C: output_val <= bus_if.awdata[0+:GPIO_PORTS];
                   
                endcase
        end
endmodule
