`timescale 1ns / 1ps

module GCD(
	input iClk,
	input iRst,
	input iValid,
	input [15:0] iA,
	input [15:0] iB,
	output reg oValid,
	output reg oReady,
	output reg [15:0] oC
	);
	
	parameter [1:0] s_Idle = 2'b00, s_Done = 2'b01;
	reg state;
	
	always @(posedge iClk)
	begin	
		if (iRst == 1) begin
			state  <= s_Idle;
			oReady <= 1;
			oValid <= 0;
			oC     <= 16'd0;
		end else begin
			case(state)
			s_Idle:
				begin
					oReady <= 1;
					oValid <= 0;
					if (iValid == 1) begin
						oC     <= iA + iB; // Th?c hi?n phép c?ng
						oReady <= 0;
						state  <= s_Done;
					end
				end
					
			s_Done:
				begin
					oValid <= 1;	
					oReady <= 1;
					state  <= s_Idle;
				end
			endcase
		end			
	end
	
endmodule
