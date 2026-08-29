`default_nettype none

module SinglePortMemx32 #(
    parameter DEPTH = 2
)(
    output wire[31:0] dout,
    input wire clk,
    input wire ce,
    input wire wren,
    input wire[3:0] wstrobe,
    input wire [$clog2(DEPTH)-1:0] addr,
    input wire [31:0] din
);
	generate
	    if (DEPTH == 128) begin
	       RSPB18_128X32M4_G1 sram_inst (
                        .CLK    (clk),
                        .ME     (ce),  //input                 : Master Enable (1: selected; 0: not selected)
                        .ADR    (addr),     //input [8:0]   : Address
                        .WE     (wren),    //input                 : Write Enable (1: Write;  0: Read)
                        .WEM    (wstrobe),  //input [3:0]   : Write Enable Mask (1: data in; 0: data not in)
                        .D      (din), //input [31:0]  : Write Data
                        .OE     (1'b1), //input                 : Output Enable (1: enable; 0: disable)
                        .Q      (dout)   //output [31:0] : Read Data
		  );
	    end else if (DEPTH == 256) begin
	       RSPB18_256X32M4_G1 sram_inst (
                        .CLK    (clk),
                        .ME     (ce),  //input                 : Master Enable (1: selected; 0: not selected)
                        .ADR    (addr),     //input [8:0]   : Address
                        .WE     (wren),    //input                 : Write Enable (1: Write;  0: Read)
                        .WEM    (wstrobe),  //input [3:0]   : Write Enable Mask (1: data in; 0: data not in)
                        .D      (din), //input [31:0]  : Write Data
                        .OE     (1'b1), //input                 : Output Enable (1: enable; 0: disable)
                        .Q      (dout)   //output [31:0] : Read Data
		);
		end else if (DEPTH == 512) begin
			                    RSPB18_512X32M4_G1 sram_inst (
                        .CLK    (clk),
                        .ME     (ce),  //input                 : Master Enable (1: selected; 0: not selected)
                        .ADR    (addr),     //input [8:0]   : Address
                        .WE     (wren),    //input                 : Write Enable (1: Write;  0: Read)
                        .WEM    (wstrobe),  //input [3:0]   : Write Enable Mask (1: data in; 0: data not in)
                        .D      (din), //input [31:0]  : Write Data
                        .OE     (1'b1), //input                 : Output Enable (1: enable; 0: disable)
                        .Q      (dout)   //output [31:0] : Read Data
		);
		end else if (DEPTH == 1024) begin
 		    RSPB18_1KX32M8_G1 sram_inst (
                	.CLK    (clk),
                	.ME     (ce),  //input                 : Master Enable (1: selected; 0: not selected)
                	.ADR    (addr),     //input [8:0]   : Address
                	.WE     (wren),    //input                 : Write Enable (1: Write;  0: Read)
                	.WEM    (wstrobe),  //input [3:0]   : Write Enable Mask (1: data in; 0: data not in)
                	.D      (din), //input [31:0]  : Write Data
                	.OE     (1'b1), //input                 : Output Enable (1: enable; 0: disable)
                	.Q      (dout)   //output [31:0] : Read Data
        	);
		end else if (DEPTH == 2048) begin
            RSPB18_2KX32M4_G1 sram_inst (
                	.CLK    (clk),
                	.ME     (ce),  //input                 : Master Enable (1: selected; 0: not selected)
                	.ADR    (addr),     //input [8:0]   : Address
                	.WE     (wren),    //input                 : Write Enable (1: Write;  0: Read)
                	.WEM    (wstrobe),  //input [3:0]   : Write Enable Mask (1: data in; 0: data not in)
                	.D      (din), //input [31:0]  : Write Data
                	.OE     (1'b1), //input                 : Output Enable (1: enable; 0: disable)
                	.Q      (dout)   //output [31:0] : Read Data
        	);
		end else if (DEPTH == 4096) begin
            RSPB18_4KX32M8_G1 sram_inst (
                        .CLK    (clk),
                        .ME     (ce),  //input                 : Master Enable (1: selected; 0: not selected)
                        .ADR    (addr),     //input [8:0]   : Address
                        .WE     (wren),    //input                 : Write Enable (1: Write;  0: Read)
                        .WEM    (wstrobe),  //input [3:0]   : Write Enable Mask (1: data in; 0: data not in)
                        .D      (din), //input [31:0]  : Write Data
                        .OE     (1'b1), //input                 : Output Enable (1: enable; 0: disable)
                        .Q      (dout)   //output [31:0] : Read Data
                );
        end else if (DEPTH == 8192) begin
            RSPB18_8KX32M16_G1 sram_inst (
                	.CLK    (clk),
                	.ME     (ce),  //input                 : Master Enable (1: selected; 0: not selected)
                	.ADR    (addr),     //input [8:0]   : Address
                	.WE     (wren),    //input                 : Write Enable (1: Write;  0: Read)
                	.WEM    (wstrobe),  //input [3:0]   : Write Enable Mask (1: data in; 0: data not in)
                	.D      (din), //input [31:0]  : Write Data
                	.OE     (1'b1), //input                 : Output Enable (1: enable; 0: disable)
                	.Q      (dout)   //output [31:0] : Read Data
        	);
        end else if (DEPTH == 16384) begin
            RSPB18_16KX32M16_G1 sram_inst (
                	.CLK    (clk),
                	.ME     (ce),  //input                 : Master Enable (1: selected; 0: not selected)
                	.ADR    (addr),     //input [8:0]   : Address
                	.WE     (wren),    //input                 : Write Enable (1: Write;  0: Read)
                	.WEM    (wstrobe),  //input [3:0]   : Write Enable Mask (1: data in; 0: data not in)
                	.D      (din), //input [31:0]  : Write Data
                	.OE     (1'b1), //input                 : Output Enable (1: enable; 0: disable)
                	.Q      (dout)   //output [31:0] : Read Data
        	);
        end else begin
			$error("Invalid 32-bit SRAM Depth!");
		end
	endgenerate

endmodule


module SinglePortMemx16 #(
    parameter DEPTH = 2
)(
    output wire[15:0] dout,
    input wire clk,
    input wire ce,
    input wire wren,
    input wire[1:0] wstrobe,
    input wire [$clog2(DEPTH)-1:0] addr,
    input wire [15:0] din
);
	generate
	    if (DEPTH == 128) begin
	       RSPB18_128X16M8_G1 sram_inst (
                        .CLK    (clk),
                        .ME     (ce),  //input                 : Master Enable (1: selected; 0: not selected)
                        .ADR    (addr),     //input [8:0]   : Address
                        .WE     (wren),    //input                 : Write Enable (1: Write;  0: Read)
                        .WEM    (wstrobe),  //input [3:0]   : Write Enable Mask (1: data in; 0: data not in)
                        .D      (din), //input [31:0]  : Write Data
                        .OE     (1'b1), //input                 : Output Enable (1: enable; 0: disable)
                        .Q      (dout)   //output [31:0] : Read Data
		  );
	    end else if (DEPTH == 256) begin
			RSPB18_256X16M8_G1 sram_inst (
                        .CLK    (clk),
                        .ME     (ce),  //input                 : Master Enable (1: selected; 0: not selected)
                        .ADR    (addr),     //input [8:0]   : Address
                        .WE     (wren),    //input                 : Write Enable (1: Write;  0: Read)
                        .WEM    (wstrobe),  //input [3:0]   : Write Enable Mask (1: data in; 0: data not in)
                        .D      (din), //input [31:0]  : Write Data
                        .OE     (1'b1), //input                 : Output Enable (1: enable; 0: disable)
                        .Q      (dout)   //output [31:0] : Read Data
		  );
		end else if (DEPTH == 512) begin
		  RSPB18_512X16M8_G1 sram_inst (
                        .CLK    (clk),
                        .ME     (ce),  //input                 : Master Enable (1: selected; 0: not selected)
                        .ADR    (addr),     //input [8:0]   : Address
                        .WE     (wren),    //input                 : Write Enable (1: Write;  0: Read)
                        .WEM    (wstrobe),  //input [3:0]   : Write Enable Mask (1: data in; 0: data not in)
                        .D      (din), //input [31:0]  : Write Data
                        .OE     (1'b1), //input                 : Output Enable (1: enable; 0: disable)
                        .Q      (dout)   //output [31:0] : Read Data
		);
		end else if (DEPTH == 1024) begin
 		    RSPB18_1KX16M8_G1 sram_inst (
                	.CLK    (clk),
                	.ME     (ce),  //input                 : Master Enable (1: selected; 0: not selected)
                	.ADR    (addr),     //input [8:0]   : Address
                	.WE     (wren),    //input                 : Write Enable (1: Write;  0: Read)
                	.WEM    (wstrobe),  //input [3:0]   : Write Enable Mask (1: data in; 0: data not in)
                	.D      (din), //input [31:0]  : Write Data
                	.OE     (1'b1), //input                 : Output Enable (1: enable; 0: disable)
                	.Q      (dout)   //output [31:0] : Read Data
        	);
		end else if (DEPTH == 2048) begin
            RSPB18_2KX16M8_G1 sram_inst (
                	.CLK    (clk),
                	.ME     (ce),  //input                 : Master Enable (1: selected; 0: not selected)
                	.ADR    (addr),     //input [8:0]   : Address
                	.WE     (wren),    //input                 : Write Enable (1: Write;  0: Read)
                	.WEM    (wstrobe),  //input [3:0]   : Write Enable Mask (1: data in; 0: data not in)
                	.D      (din), //input [31:0]  : Write Data
                	.OE     (1'b1), //input                 : Output Enable (1: enable; 0: disable)
                	.Q      (dout)   //output [31:0] : Read Data
        	);
		end else if (DEPTH == 4096) begin
            RSPB18_4KX16M8_G1 sram_inst (
                        .CLK    (clk),
                        .ME     (ce),  //input                 : Master Enable (1: selected; 0: not selected)
                        .ADR    (addr),     //input [8:0]   : Address
                        .WE     (wren),    //input                 : Write Enable (1: Write;  0: Read)
                        .WEM    (wstrobe),  //input [3:0]   : Write Enable Mask (1: data in; 0: data not in)
                        .D      (din), //input [31:0]  : Write Data
                        .OE     (1'b1), //input                 : Output Enable (1: enable; 0: disable)
                        .Q      (dout)   //output [31:0] : Read Data
                );
        end else if (DEPTH == 8192) begin
            RSPB18_8KX16M16_G1 sram_inst (
                	.CLK    (clk),
                	.ME     (ce),  //input                 : Master Enable (1: selected; 0: not selected)
                	.ADR    (addr),     //input [8:0]   : Address
                	.WE     (wren),    //input                 : Write Enable (1: Write;  0: Read)
                	.WEM    (wstrobe),  //input [3:0]   : Write Enable Mask (1: data in; 0: data not in)
                	.D      (din), //input [31:0]  : Write Data
                	.OE     (1'b1), //input                 : Output Enable (1: enable; 0: disable)
                	.Q      (dout)   //output [31:0] : Read Data
        	);
        end else if (DEPTH == 16384) begin
            RSPB18_16KX16M16_G1 sram_inst (
                	.CLK    (clk),
                	.ME     (ce),  //input                 : Master Enable (1: selected; 0: not selected)
                	.ADR    (addr),     //input [8:0]   : Address
                	.WE     (wren),    //input                 : Write Enable (1: Write;  0: Read)
                	.WEM    (wstrobe),  //input [3:0]   : Write Enable Mask (1: data in; 0: data not in)
                	.D      (din), //input [31:0]  : Write Data
                	.OE     (1'b1), //input                 : Output Enable (1: enable; 0: disable)
                	.Q      (dout)   //output [31:0] : Read Data
        	);
        end
        else begin
			$error("Invalid 16-bit SRAM Depth!");
		end
	endgenerate

endmodule

module SinglePortMemx64 #(
    parameter DEPTH = 2
)(
    output wire[63:0] dout,
    input wire clk,
    input wire ce,
    input wire wren,
    input wire[7:0] wstrobe,
    input wire [$clog2(DEPTH)-1:0] addr,
    input wire [63:0] din
);

    SinglePortMemx32 #(.DEPTH(DEPTH)) lo32(
        .dout(dout[0+:32]),
        .clk,
        .ce,
        .wren,
        .wstrobe(wstrobe[0+:4]),
        .addr,
        .din(din[0+:32])
    );

    SinglePortMemx32 #(.DEPTH(DEPTH)) hi32(
        .dout(dout[32+:32]),
        .clk,
        .ce,
        .wren,
        .wstrobe(wstrobe[4+:4]),
        .addr,
        .din(din[32+:32])
    );
    
endmodule


module Scratch4096(
	input wire clk,
    input wire rstn,
    slv_interface.slv bus_if
);
    parameter SCRATCH_SIZE = 8192*8; //
    localparam SCALE_IDX = $clog2(SCRATCH_SIZE / 8);
	
	reg rvalid;
    always_ff @(posedge clk or negedge rstn)
        if (!rstn)
            rvalid <= 1'b0;
        else
            rvalid <= bus_if.avalid;
    assign bus_if.rvalid = rvalid;
    wire[7:0] wstrobe = (bus_if.asize == 0 ? 8'h1 : 
                         bus_if.asize == 1 ? 8'h3 :
                         bus_if.asize == 2 ? 8'hF :
						 bus_if.asize == 3 ? 8'hFF : 'x) << bus_if.addr[2:0];
    reg[2:0] addr_q;
    always_ff @(posedge clk or negedge rstn)
        if (!rstn)
            addr_q <= '0;
        else if (bus_if.avalid)
            addr_q <= bus_if.addr[2:0];
    wire[63:0] dout;
    SinglePortMemx64 #(
        .DEPTH(SCRATCH_SIZE/8)
    ) sram64_inst(
        .dout(dout),
        .clk(clk),
        .ce(bus_if.avalid),
        .wren(bus_if.awren),
        .wstrobe(wstrobe),
        .addr(bus_if.addr[3+:SCALE_IDX]),
        .din(bus_if.awdata)
    );
    assign bus_if.rdata = dout >> 8*addr_q[2:0];
	assign bus_if.aready = 1'b1;

endmodule
