//`default_nettype none


//module sync_fifo #(
//    parameter WIDTH = 0,
//    parameter DEPTH = 8
//)(
//    input wire clk,
//    input wire rstn,
//    input wire reset,
//    input wire wvalid,
//    input wire[WIDTH-1:0] wdata,
//    output wire wready,
    
//    output wire rvalid,
//    output wire[WIDTH-1:0] rdata,
//    input wire rready,
//	 output reg[3:0] fifo_cnt
//);
//    localparam PTR_W = $clog2(DEPTH);
    
//    reg[WIDTH-1:0] mem[DEPTH] = '{default: '0};
//    reg[PTR_W:0] rdptr;
//    reg[PTR_W:0] wrptr;
    
//    wire internal_rvalid = rdptr != wrptr;
    
    
//    wire[PTR_W:0] rdptr_nxt = rdptr + (internal_rvalid & (~rvalid | rready));
//    wire[PTR_W:0] wrptr_nxt = wrptr + (wready & wvalid);
    
//    always_ff @(posedge clk or negedge rstn)
//        if (!rstn)
//            wrptr <= 0;
//        else if (reset)
//            wrptr <= 0;
//        else
//            wrptr <= wrptr_nxt;
    
    
//    always_ff @(posedge clk or negedge rstn)
//        if (!rstn)
//            rdptr <= 0;
//        else if (reset)
//            rdptr <= 0;
//        else
//            rdptr <= rdptr_nxt;        
            
//    reg wready_q;
//    always_ff @(posedge clk or negedge rstn)
//        if (!rstn)
//            wready_q <= 1'b0;
//        else if (reset)
//            wready_q <= 1'b0;
//        else
//            wready_q <= {~wrptr_nxt[PTR_W], wrptr_nxt[PTR_W-1:0]} != rdptr_nxt;
//    assign wready = wready_q;

//    always_ff @(posedge clk)
//    	if (wvalid && wready)
//            mem[wrptr[PTR_W-1:0]] <= wdata;
            
//    reg rvalid_q;
//    always_ff @(posedge clk or negedge rstn)
//        if (!rstn)
//            rvalid_q <= 1'b0;
//        else if (reset)
//            rvalid_q <= 1'b0;
//        else if (~rvalid | rready)
//            rvalid_q <= internal_rvalid;
//    assign rvalid = rvalid_q;
//    reg[WIDTH-1:0] rdata_q;
//    always_ff @(posedge clk or negedge rstn)
//    	if (!rstn)
//            rdata_q <= '0;
//        else if (~rvalid | rready)
//            rdata_q <= mem[rdptr[PTR_W-1:0]];
//    assign rdata = rdata_q;
//    always_ff @(posedge clk or negedge rstn)
//			if (!rstn)
//				fifo_cnt <= '0;
//			else if (reset)
//                fifo_cnt <= '0;
//            else
//				fifo_cnt <= fifo_cnt + (wready & wvalid) - (rvalid & rready);
//endmodule


//module SIFIVE_UART(
//    input wire clk,
//    input wire rstn,
//    slv_interface.slv bus_if,
//    output reg uart_tx,
//    input wire uart_rx,
//	output reg uart_irq
//);

//    localparam COUNTER_W = 16;
    
//    wire tx_fifo_wready;
//    wire rx_fifo_rvalid;
//    wire[7:0] uart_rx_byte;
    
    
//	wire[3:0] tx_fifo_cnt;
//	wire[3:0] rx_fifo_cnt;
	 
//    wire[31:0] sifive_txdata = {~tx_fifo_wready, 31'h0};
//    wire[31:0] sifive_rxdata = {~rx_fifo_rvalid, 23'h0, uart_rx_byte};
//    reg[18:0] sifive_txctrl;
//    reg[18:0] sifive_rxctrl;
//	reg rxwm_en; reg txwm_en;
	
//	wire[2:0] rx_threshold = sifive_rxctrl[18:16]; wire[2:0] tx_threshold = sifive_txctrl[18:16];
//    wire rxwm_pending = rx_fifo_cnt > rx_threshold; wire txwm_pending = tx_fifo_cnt < tx_threshold;
//    reg[COUNTER_W-1:0] UART_BIT_PERIOD;
    
     
//    reg[31:0] rdata;
//    always_ff @(posedge clk or negedge rstn)
//        if (!rstn)
//            rdata <= '0;
//        else if (bus_if.avalid)
//            case ({bus_if.addr[11:2], 2'b00})
//                32'h0:   rdata <= sifive_txdata;
//                32'h4:   rdata <= sifive_rxdata;
//                32'h8:   rdata <= sifive_txctrl;
//                32'hc:   rdata <= sifive_rxctrl;
//			    32'h10:  rdata <= {rxwm_en, txwm_en};
//				32'h14:  rdata <= {rxwm_pending, txwm_pending};
//                32'h18:  rdata <= UART_BIT_PERIOD;
//                default: rdata <= '0;
//            endcase
    
//    reg rvalid;
//    always_ff @(posedge clk or negedge rstn)
//        if (!rstn)
//            rvalid <= 1'b0;
//        else
//            rvalid <= bus_if.avalid;
//    assign bus_if.rdata = rdata;
//    assign bus_if.rvalid = rvalid;
//    assign bus_if.aready = 1'b1;
    
    
//     always_ff @(posedge clk or negedge rstn)
//        if (!rstn) begin
//            sifive_txctrl <= '0;
//            sifive_rxctrl <= '0;
//            {rxwm_en, txwm_en} <= '0;
//            UART_BIT_PERIOD <= 433;
//        end else if (bus_if.avalid && bus_if.awren)
//            case ({bus_if.addr[11:2], 2'b00})
//                32'h8: sifive_txctrl <= bus_if.awdata & 32'h70001;
//                32'hc: sifive_rxctrl <= bus_if.awdata & 32'h70001;
//			    32'h10: {rxwm_en, txwm_en} <= bus_if.awdata[1:0];
//                32'h18: UART_BIT_PERIOD <= bus_if.awdata[COUNTER_W-1:0];
//            endcase
    
//     always_ff @(posedge clk or negedge rstn)
//        if (!rstn)
//            uart_irq <= 1'b0;
//        else
//            uart_irq <= txwm_pending && txwm_en || rxwm_pending && rxwm_en;
            
//	wire sifive_txen = sifive_txctrl[0];
   
    
    
            
//    wire tx_read_en;
//    wire[7:0] tx_data;
//    wire tx_fifo_rvalid;

//    sync_fifo #(
//        .WIDTH(8)
//    ) phy_tx_fifo(
//		.wdata(bus_if.awdata[7:0]), //input [7:0] Data
//		.clk(clk), //input Clk
//		.wvalid(bus_if.avalid && bus_if.awren && {bus_if.addr[11:2], 2'b00} == 32'h0), //input WrEn
//		.rready(tx_read_en), //input RdEn
//		.rstn(rstn), //input Reset
//        .reset(!sifive_txen),
//		.rdata(tx_data), //output [7:0] Q
//		.rvalid(tx_fifo_rvalid), //output Empty
//		.wready(tx_fifo_wready), //output Full
//		.fifo_cnt(tx_fifo_cnt)
//	);
    

//    typedef enum {
//        TX_WAIT,
//        TX_INIT,
//        TX_PAYLOAD0,
//        TX_PAYLOAD1,
//        TX_PAYLOAD2,
//        TX_PAYLOAD3,
//        TX_PAYLOAD4,
//        TX_PAYLOAD5,
//        TX_PAYLOAD6,
//        TX_PAYLOAD7,
//        TX_END
//    } TX_STATE;
    
//    reg[COUNTER_W-1:0] tx_ctr;
//    TX_STATE uart_tx_state;
//    TX_STATE uart_tx_nextstate;
//    assign tx_read_en = uart_tx_state == TX_WAIT;
//    reg[7:0] transmit_frame;
//    always_comb begin
//        case (uart_tx_state)
//            TX_WAIT: uart_tx_nextstate = tx_fifo_rvalid ? TX_INIT : TX_WAIT;
//            TX_INIT: uart_tx_nextstate = tx_ctr == UART_BIT_PERIOD ? TX_PAYLOAD0 : TX_INIT;
//            TX_PAYLOAD0: uart_tx_nextstate = tx_ctr == UART_BIT_PERIOD ? TX_PAYLOAD1 : TX_PAYLOAD0;
//            TX_PAYLOAD1: uart_tx_nextstate = tx_ctr == UART_BIT_PERIOD ? TX_PAYLOAD2 : TX_PAYLOAD1;
//            TX_PAYLOAD2: uart_tx_nextstate = tx_ctr == UART_BIT_PERIOD ? TX_PAYLOAD3 : TX_PAYLOAD2;
//            TX_PAYLOAD3: uart_tx_nextstate = tx_ctr == UART_BIT_PERIOD ? TX_PAYLOAD4 : TX_PAYLOAD3;
//            TX_PAYLOAD4: uart_tx_nextstate = tx_ctr == UART_BIT_PERIOD ? TX_PAYLOAD5 : TX_PAYLOAD4;
//            TX_PAYLOAD5: uart_tx_nextstate = tx_ctr == UART_BIT_PERIOD ? TX_PAYLOAD6 : TX_PAYLOAD5;
//            TX_PAYLOAD6: uart_tx_nextstate = tx_ctr == UART_BIT_PERIOD ? TX_PAYLOAD7 : TX_PAYLOAD6;
//            TX_PAYLOAD7: uart_tx_nextstate = tx_ctr == UART_BIT_PERIOD ? TX_END      : TX_PAYLOAD7;
//            TX_END:      uart_tx_nextstate = tx_ctr == UART_BIT_PERIOD ? TX_WAIT     : TX_END;
//            default: uart_tx_nextstate = TX_WAIT;
//        endcase
//    end
//    always_ff @(posedge clk or negedge rstn)
//        if (!rstn)
//            transmit_frame <= '0;
//        else if (!sifive_txen)
//            transmit_frame <= '0;
//        else if (tx_read_en)
//            transmit_frame <= tx_data;
//    always_ff @(posedge clk or negedge rstn)
//        if (!rstn)
//            tx_ctr <= '0;
//        else if (!sifive_txen)
//            tx_ctr <= '0;
//        else
//            tx_ctr <= uart_tx_nextstate == uart_tx_state ? tx_ctr + 1'b1 : '0;

//    always_ff @(posedge clk or negedge rstn)
//        if (!rstn)
//            uart_tx_state <= TX_WAIT;
//        else if (!sifive_txen)
//            uart_tx_state <= TX_WAIT;
//        else
//            uart_tx_state <= uart_tx_nextstate;
    
//    reg uart_tx_q;
//    always_ff @(posedge clk or negedge rstn)
//        if (!rstn)
//            uart_tx_q <= 1'b1;
//        else if (!sifive_txen)
//            uart_tx_q <= 1'b1;
//        else
//            case (uart_tx_state)
//                TX_WAIT: uart_tx_q <= 1'b1;
//                TX_INIT: uart_tx_q <= 1'b0;
//                TX_PAYLOAD0: uart_tx_q <= transmit_frame[0];
//                TX_PAYLOAD1: uart_tx_q <= transmit_frame[1];
//                TX_PAYLOAD2: uart_tx_q <= transmit_frame[2];
//                TX_PAYLOAD3: uart_tx_q <= transmit_frame[3];
//                TX_PAYLOAD4: uart_tx_q <= transmit_frame[4];
//                TX_PAYLOAD5: uart_tx_q <= transmit_frame[5];
//                TX_PAYLOAD6: uart_tx_q <= transmit_frame[6];
//                TX_PAYLOAD7: uart_tx_q <= transmit_frame[7];
//                TX_END: uart_tx_q <= 1'b1;
//                default: uart_tx_q <= 1'b1;
//            endcase
            
//    always_ff @(posedge clk or negedge rstn)
//        if (!rstn)
//            uart_tx <= 1'b1;
//        else
//            uart_tx <= uart_tx_q;
            
    
//	wire sifive_rxen = sifive_rxctrl[0];
//    wire[COUNTER_W-1:0] UART_SAMPLE_THRESHOLD = UART_BIT_PERIOD[COUNTER_W-1:1];
//    (* ASYNC_REG = "TRUE" *) reg[1:0] uart_rx_sync;
//    always_ff @(posedge clk or negedge rstn)
//        if (!rstn)
//            uart_rx_sync <= '0;
//        else
//            uart_rx_sync <= {uart_rx, uart_rx_sync[1]};
//    wire uart_rx_stable = uart_rx_sync[0];

    
//    typedef enum {
//        RX_INIT,
//        RX_PAYLOAD0,
//        RX_PAYLOAD1,
//        RX_PAYLOAD2,
//        RX_PAYLOAD3,
//        RX_PAYLOAD4,
//        RX_PAYLOAD5,
//        RX_PAYLOAD6,
//        RX_PAYLOAD7,
//        RX_END
//    } RX_STATE;
//    RX_STATE uart_rx_state;
    
//    reg[COUNTER_W-1:0] rx_ctr;
    
//    RX_STATE uart_rx_nextstate;
//    always_comb
//        case (uart_rx_state)
//            RX_INIT: uart_rx_nextstate = rx_ctr == UART_SAMPLE_THRESHOLD ? RX_PAYLOAD0 : RX_INIT;
//            RX_PAYLOAD0: uart_rx_nextstate = rx_ctr == UART_BIT_PERIOD ? RX_PAYLOAD1 : RX_PAYLOAD0;
//            RX_PAYLOAD1: uart_rx_nextstate = rx_ctr == UART_BIT_PERIOD ? RX_PAYLOAD2 : RX_PAYLOAD1;
//            RX_PAYLOAD2: uart_rx_nextstate = rx_ctr == UART_BIT_PERIOD ? RX_PAYLOAD3 : RX_PAYLOAD2;
//            RX_PAYLOAD3: uart_rx_nextstate = rx_ctr == UART_BIT_PERIOD ? RX_PAYLOAD4 : RX_PAYLOAD3;
//            RX_PAYLOAD4: uart_rx_nextstate = rx_ctr == UART_BIT_PERIOD ? RX_PAYLOAD5 : RX_PAYLOAD4;
//            RX_PAYLOAD5: uart_rx_nextstate = rx_ctr == UART_BIT_PERIOD ? RX_PAYLOAD6 : RX_PAYLOAD5;
//            RX_PAYLOAD6: uart_rx_nextstate = rx_ctr == UART_BIT_PERIOD ? RX_PAYLOAD7 : RX_PAYLOAD6;
//            RX_PAYLOAD7: uart_rx_nextstate = rx_ctr == UART_BIT_PERIOD ? RX_END      : RX_PAYLOAD7;
//            RX_END:      uart_rx_nextstate = rx_ctr == UART_BIT_PERIOD ? RX_INIT     : RX_END;
//            default: uart_rx_nextstate = RX_INIT;
//        endcase

//    always_ff @(posedge clk or negedge rstn)
//        if (!rstn)
//            rx_ctr <= 0;
//        else if (!sifive_rxen)
//            rx_ctr <= 0;
//        else if (uart_rx_nextstate != uart_rx_state || uart_rx_state == RX_INIT && uart_rx_stable)
//            rx_ctr <= 0;
//        else
//            rx_ctr <= rx_ctr + 1'b1;
            
   
//    reg[7:0] rcv_frame;
//    always_ff @(posedge clk or negedge rstn)
//        if (!rstn)
//            rcv_frame <= '0;
//        else if (!sifive_rxen)
//            rcv_frame <= '0;
//        else if (uart_rx_nextstate != uart_rx_state)
//            case (uart_rx_state)
//                RX_PAYLOAD0: rcv_frame <= {uart_rx_stable, rcv_frame[7:1]};
//                RX_PAYLOAD1: rcv_frame <= {uart_rx_stable, rcv_frame[7:1]};
//                RX_PAYLOAD2: rcv_frame <= {uart_rx_stable, rcv_frame[7:1]};
//                RX_PAYLOAD3: rcv_frame <= {uart_rx_stable, rcv_frame[7:1]};
//                RX_PAYLOAD4: rcv_frame <= {uart_rx_stable, rcv_frame[7:1]};
//                RX_PAYLOAD5: rcv_frame <= {uart_rx_stable, rcv_frame[7:1]};
//                RX_PAYLOAD6: rcv_frame <= {uart_rx_stable, rcv_frame[7:1]};
//                RX_PAYLOAD7: rcv_frame <= {uart_rx_stable, rcv_frame[7:1]};
//            endcase

//    always_ff @(posedge clk or negedge rstn)
//        if (!rstn)
//            uart_rx_state <= RX_INIT;
//        else if (!sifive_rxen)
//            uart_rx_state <= RX_INIT;
//        else
//            uart_rx_state <= uart_rx_nextstate;
    
	 
//	sync_fifo #(
//        .WIDTH(8)
//    ) phy_rx_fifo(
//		.wdata(rcv_frame), //input [7:0] Data
//		.clk(clk), //input Clk
//		.wvalid(uart_rx_state == RX_END && uart_rx_nextstate == RX_INIT), //input WrEn
//		.rready(bus_if.avalid && !bus_if.awren && {bus_if.addr[11:2], 2'b00} == 32'h4), //input RdEn
//		.rstn(rstn), //input Reset
//        .reset(!sifive_rxen),
//		.rdata(uart_rx_byte), //output [7:0] Q
//		.rvalid(rx_fifo_rvalid), //output Empty
//		.wready(), //output Full
//		.fifo_cnt(rx_fifo_cnt)
//	);
//endmodule
////////////////////////////////////


`default_nettype none


module sync_fifo #(
    parameter WIDTH = 0,
    parameter DEPTH = 8,
    ///t? count c? ??nh 4-bit sang count theo DEPTH
    parameter CNT_W = $clog2(DEPTH + 1)
    
)(
    input wire clk,
    input wire rstn,
    input wire reset,
    input wire wvalid,
    input wire[WIDTH-1:0] wdata,
    output wire wready,
    
    output wire rvalid,
    output wire[WIDTH-1:0] rdata,
    input wire rready,
	 //output reg[3:0] fifo_cnt
	 //t? count c? ??nh 4-bit sang count theo DEPTH
	output reg[CNT_W-1:0] fifo_cnt
);
    localparam PTR_W = $clog2(DEPTH);
    
    reg[WIDTH-1:0] mem[DEPTH] = '{default: '0};
    reg[PTR_W:0] rdptr;
    reg[PTR_W:0] wrptr;
    
    wire internal_rvalid = rdptr != wrptr;
    
    
    wire[PTR_W:0] rdptr_nxt = rdptr + (internal_rvalid & (~rvalid | rready));
    wire[PTR_W:0] wrptr_nxt = wrptr + (wready & wvalid);
    
    always_ff @(posedge clk or negedge rstn)
        if (!rstn)
            wrptr <= 0;
        else if (reset)
            wrptr <= 0;
        else
            wrptr <= wrptr_nxt;
    
    
    always_ff @(posedge clk or negedge rstn)
        if (!rstn)
            rdptr <= 0;
        else if (reset)
            rdptr <= 0;
        else
            rdptr <= rdptr_nxt;        
            
    reg wready_q;
    always_ff @(posedge clk or negedge rstn)
        if (!rstn)
            wready_q <= 1'b0;
        else if (reset)
            wready_q <= 1'b0;
        else
            wready_q <= {~wrptr_nxt[PTR_W], wrptr_nxt[PTR_W-1:0]} != rdptr_nxt;
    assign wready = wready_q;

    always_ff @(posedge clk)
    	if (wvalid && wready)
            mem[wrptr[PTR_W-1:0]] <= wdata;
            
    reg rvalid_q;
    always_ff @(posedge clk or negedge rstn)
        if (!rstn)
            rvalid_q <= 1'b0;
        else if (reset)
            rvalid_q <= 1'b0;
        else if (~rvalid | rready)
            rvalid_q <= internal_rvalid;
    assign rvalid = rvalid_q;
    reg[WIDTH-1:0] rdata_q;
    always_ff @(posedge clk or negedge rstn)
    	if (!rstn)
            rdata_q <= '0;
        else if (~rvalid | rready)
            rdata_q <= mem[rdptr[PTR_W-1:0]];
    assign rdata = rdata_q;
    always_ff @(posedge clk or negedge rstn)
			if (!rstn)
				fifo_cnt <= '0;
			else if (reset)
                fifo_cnt <= '0;
            else
				fifo_cnt <= fifo_cnt + (wready & wvalid) - (rvalid & rready);
endmodule


module SIFIVE_UART(
    input wire clk,
    input wire rstn,
    slv_interface.slv bus_if,
    output reg uart_tx,
    input wire uart_rx,
	output reg uart_irq
);

    localparam COUNTER_W = 16;
    
    wire tx_fifo_wready;
    wire rx_fifo_rvalid;
    wire[7:0] uart_rx_byte;
    
    
	wire[3:0] tx_fifo_cnt;
	wire[3:0] rx_fifo_cnt;
	 
    wire[31:0] sifive_txdata = {~tx_fifo_wready, 31'h0};
    wire[31:0] sifive_rxdata = {~rx_fifo_rvalid, 23'h0, uart_rx_byte};
    reg[18:0] sifive_txctrl;
    reg[18:0] sifive_rxctrl;
	reg rxwm_en; reg txwm_en;
	
	wire[2:0] rx_threshold = sifive_rxctrl[18:16]; wire[2:0] tx_threshold = sifive_txctrl[18:16];
    wire rxwm_pending = rx_fifo_cnt > rx_threshold; wire txwm_pending = tx_fifo_cnt < tx_threshold;
    reg[COUNTER_W-1:0] UART_BIT_PERIOD;
    
     
    reg[31:0] rdata;
    always_ff @(posedge clk or negedge rstn)
        if (!rstn)
            rdata <= '0;
        else if (bus_if.avalid)
            case ({bus_if.addr[11:2], 2'b00})
                32'h0:   rdata <= sifive_txdata;
                32'h4:   rdata <= sifive_rxdata;
                32'h8:   rdata <= sifive_txctrl;
                32'hc:   rdata <= sifive_rxctrl;
			    32'h10:  rdata <= {rxwm_en, txwm_en};
				32'h14:  rdata <= {rxwm_pending, txwm_pending};
                32'h18:  rdata <= UART_BIT_PERIOD;
                default: rdata <= '0;
            endcase
    
    reg rvalid;
    always_ff @(posedge clk or negedge rstn)
        if (!rstn)
            rvalid <= 1'b0;
        else
            rvalid <= bus_if.avalid;
    assign bus_if.rdata = rdata;
    assign bus_if.rvalid = rvalid;
    assign bus_if.aready = 1'b1;
    
    
     always_ff @(posedge clk or negedge rstn)
        if (!rstn) begin
            sifive_txctrl <= '0;
            sifive_rxctrl <= '0;
            {rxwm_en, txwm_en} <= '0;
            UART_BIT_PERIOD <= 433;
        end else if (bus_if.avalid && bus_if.awren)
            case ({bus_if.addr[11:2], 2'b00})
                32'h8: sifive_txctrl <= bus_if.awdata & 32'h70001;
                32'hc: sifive_rxctrl <= bus_if.awdata & 32'h70001;
			    32'h10: {rxwm_en, txwm_en} <= bus_if.awdata[1:0];
                32'h18: UART_BIT_PERIOD <= bus_if.awdata[COUNTER_W-1:0];
            endcase
    
     always_ff @(posedge clk or negedge rstn)
        if (!rstn)
            uart_irq <= 1'b0;
        else
            uart_irq <= txwm_pending && txwm_en || rxwm_pending && rxwm_en;
            
	wire sifive_txen = sifive_txctrl[0];
   
    
    
            
    wire tx_read_en;
    wire[7:0] tx_data;
    wire tx_fifo_rvalid;

    sync_fifo #(
        .WIDTH(8)
    ) phy_tx_fifo(
		.wdata(bus_if.awdata[7:0]), //input [7:0] Data
		.clk(clk), //input Clk
		.wvalid(bus_if.avalid && bus_if.awren && {bus_if.addr[11:2], 2'b00} == 32'h0), //input WrEn
		.rready(tx_read_en), //input RdEn
		.rstn(rstn), //input Reset
        .reset(!sifive_txen),
		.rdata(tx_data), //output [7:0] Q
		.rvalid(tx_fifo_rvalid), //output Empty
		.wready(tx_fifo_wready), //output Full
		.fifo_cnt(tx_fifo_cnt)
	);
    

    typedef enum {
        TX_WAIT,
        TX_INIT,
        TX_PAYLOAD0,
        TX_PAYLOAD1,
        TX_PAYLOAD2,
        TX_PAYLOAD3,
        TX_PAYLOAD4,
        TX_PAYLOAD5,
        TX_PAYLOAD6,
        TX_PAYLOAD7,
        TX_END
    } TX_STATE;
    
    reg[COUNTER_W-1:0] tx_ctr;
    TX_STATE uart_tx_state;
    TX_STATE uart_tx_nextstate;
    assign tx_read_en = uart_tx_state == TX_WAIT;
    reg[7:0] transmit_frame;
    always_comb begin
        case (uart_tx_state)
            TX_WAIT: uart_tx_nextstate = tx_fifo_rvalid ? TX_INIT : TX_WAIT;
            TX_INIT: uart_tx_nextstate = tx_ctr == UART_BIT_PERIOD ? TX_PAYLOAD0 : TX_INIT;
            TX_PAYLOAD0: uart_tx_nextstate = tx_ctr == UART_BIT_PERIOD ? TX_PAYLOAD1 : TX_PAYLOAD0;
            TX_PAYLOAD1: uart_tx_nextstate = tx_ctr == UART_BIT_PERIOD ? TX_PAYLOAD2 : TX_PAYLOAD1;
            TX_PAYLOAD2: uart_tx_nextstate = tx_ctr == UART_BIT_PERIOD ? TX_PAYLOAD3 : TX_PAYLOAD2;
            TX_PAYLOAD3: uart_tx_nextstate = tx_ctr == UART_BIT_PERIOD ? TX_PAYLOAD4 : TX_PAYLOAD3;
            TX_PAYLOAD4: uart_tx_nextstate = tx_ctr == UART_BIT_PERIOD ? TX_PAYLOAD5 : TX_PAYLOAD4;
            TX_PAYLOAD5: uart_tx_nextstate = tx_ctr == UART_BIT_PERIOD ? TX_PAYLOAD6 : TX_PAYLOAD5;
            TX_PAYLOAD6: uart_tx_nextstate = tx_ctr == UART_BIT_PERIOD ? TX_PAYLOAD7 : TX_PAYLOAD6;
            TX_PAYLOAD7: uart_tx_nextstate = tx_ctr == UART_BIT_PERIOD ? TX_END      : TX_PAYLOAD7;
            TX_END:      uart_tx_nextstate = tx_ctr == UART_BIT_PERIOD ? TX_WAIT     : TX_END;
            default: uart_tx_nextstate = TX_WAIT;
        endcase
    end
    always_ff @(posedge clk or negedge rstn)
        if (!rstn)
            transmit_frame <= '0;
        else if (!sifive_txen)
            transmit_frame <= '0;
        else if (tx_read_en)
            transmit_frame <= tx_data;
    always_ff @(posedge clk or negedge rstn)
        if (!rstn)
            tx_ctr <= '0;
        else if (!sifive_txen)
            tx_ctr <= '0;
        else
            tx_ctr <= uart_tx_nextstate == uart_tx_state ? tx_ctr + 1'b1 : '0;

    always_ff @(posedge clk or negedge rstn)
        if (!rstn)
            uart_tx_state <= TX_WAIT;
        else if (!sifive_txen)
            uart_tx_state <= TX_WAIT;
        else
            uart_tx_state <= uart_tx_nextstate;
    
    reg uart_tx_q;
    always_ff @(posedge clk or negedge rstn)
        if (!rstn)
            uart_tx_q <= 1'b1;
        else if (!sifive_txen)
            uart_tx_q <= 1'b1;
        else
            case (uart_tx_state)
                TX_WAIT: uart_tx_q <= 1'b1;
                TX_INIT: uart_tx_q <= 1'b0;
                TX_PAYLOAD0: uart_tx_q <= transmit_frame[0];
                TX_PAYLOAD1: uart_tx_q <= transmit_frame[1];
                TX_PAYLOAD2: uart_tx_q <= transmit_frame[2];
                TX_PAYLOAD3: uart_tx_q <= transmit_frame[3];
                TX_PAYLOAD4: uart_tx_q <= transmit_frame[4];
                TX_PAYLOAD5: uart_tx_q <= transmit_frame[5];
                TX_PAYLOAD6: uart_tx_q <= transmit_frame[6];
                TX_PAYLOAD7: uart_tx_q <= transmit_frame[7];
                TX_END: uart_tx_q <= 1'b1;
                default: uart_tx_q <= 1'b1;
            endcase
            
    always_ff @(posedge clk or negedge rstn)
        if (!rstn)
            uart_tx <= 1'b1;
        else
            uart_tx <= uart_tx_q;
            
    
	wire sifive_rxen = sifive_rxctrl[0];
    wire[COUNTER_W-1:0] UART_SAMPLE_THRESHOLD = UART_BIT_PERIOD[COUNTER_W-1:1];
    (* ASYNC_REG = "TRUE" *) reg[1:0] uart_rx_sync;
    always_ff @(posedge clk or negedge rstn)
        if (!rstn)
            uart_rx_sync <= '0;
        else
            uart_rx_sync <= {uart_rx, uart_rx_sync[1]};
    wire uart_rx_stable = uart_rx_sync[0];

    
    typedef enum {
        RX_INIT,
        RX_PAYLOAD0,
        RX_PAYLOAD1,
        RX_PAYLOAD2,
        RX_PAYLOAD3,
        RX_PAYLOAD4,
        RX_PAYLOAD5,
        RX_PAYLOAD6,
        RX_PAYLOAD7,
        RX_END
    } RX_STATE;
    RX_STATE uart_rx_state;
    
    reg[COUNTER_W-1:0] rx_ctr;
    
    RX_STATE uart_rx_nextstate;
    always_comb
        case (uart_rx_state)
            RX_INIT: uart_rx_nextstate = rx_ctr == UART_SAMPLE_THRESHOLD ? RX_PAYLOAD0 : RX_INIT;
            RX_PAYLOAD0: uart_rx_nextstate = rx_ctr == UART_BIT_PERIOD ? RX_PAYLOAD1 : RX_PAYLOAD0;
            RX_PAYLOAD1: uart_rx_nextstate = rx_ctr == UART_BIT_PERIOD ? RX_PAYLOAD2 : RX_PAYLOAD1;
            RX_PAYLOAD2: uart_rx_nextstate = rx_ctr == UART_BIT_PERIOD ? RX_PAYLOAD3 : RX_PAYLOAD2;
            RX_PAYLOAD3: uart_rx_nextstate = rx_ctr == UART_BIT_PERIOD ? RX_PAYLOAD4 : RX_PAYLOAD3;
            RX_PAYLOAD4: uart_rx_nextstate = rx_ctr == UART_BIT_PERIOD ? RX_PAYLOAD5 : RX_PAYLOAD4;
            RX_PAYLOAD5: uart_rx_nextstate = rx_ctr == UART_BIT_PERIOD ? RX_PAYLOAD6 : RX_PAYLOAD5;
            RX_PAYLOAD6: uart_rx_nextstate = rx_ctr == UART_BIT_PERIOD ? RX_PAYLOAD7 : RX_PAYLOAD6;
            RX_PAYLOAD7: uart_rx_nextstate = rx_ctr == UART_BIT_PERIOD ? RX_END      : RX_PAYLOAD7;
            RX_END:      uart_rx_nextstate = rx_ctr == UART_BIT_PERIOD ? RX_INIT     : RX_END;
            default: uart_rx_nextstate = RX_INIT;
        endcase

    always_ff @(posedge clk or negedge rstn)
        if (!rstn)
            rx_ctr <= 0;
        else if (!sifive_rxen)
            rx_ctr <= 0;
        else if (uart_rx_nextstate != uart_rx_state || uart_rx_state == RX_INIT && uart_rx_stable)
            rx_ctr <= 0;
        else
            rx_ctr <= rx_ctr + 1'b1;
            
   
    reg[7:0] rcv_frame;
    always_ff @(posedge clk or negedge rstn)
        if (!rstn)
            rcv_frame <= '0;
        else if (!sifive_rxen)
            rcv_frame <= '0;
        else if (uart_rx_nextstate != uart_rx_state)
            case (uart_rx_state)
                RX_PAYLOAD0: rcv_frame <= {uart_rx_stable, rcv_frame[7:1]};
                RX_PAYLOAD1: rcv_frame <= {uart_rx_stable, rcv_frame[7:1]};
                RX_PAYLOAD2: rcv_frame <= {uart_rx_stable, rcv_frame[7:1]};
                RX_PAYLOAD3: rcv_frame <= {uart_rx_stable, rcv_frame[7:1]};
                RX_PAYLOAD4: rcv_frame <= {uart_rx_stable, rcv_frame[7:1]};
                RX_PAYLOAD5: rcv_frame <= {uart_rx_stable, rcv_frame[7:1]};
                RX_PAYLOAD6: rcv_frame <= {uart_rx_stable, rcv_frame[7:1]};
                RX_PAYLOAD7: rcv_frame <= {uart_rx_stable, rcv_frame[7:1]};
            endcase

    always_ff @(posedge clk or negedge rstn)
        if (!rstn)
            uart_rx_state <= RX_INIT;
        else if (!sifive_rxen)
            uart_rx_state <= RX_INIT;
        else
            uart_rx_state <= uart_rx_nextstate;
    
	 
	sync_fifo #(
        .WIDTH(8)
    ) phy_rx_fifo(
		.wdata(rcv_frame), //input [7:0] Data
		.clk(clk), //input Clk
		.wvalid(uart_rx_state == RX_END && uart_rx_nextstate == RX_INIT), //input WrEn
		.rready(bus_if.avalid && !bus_if.awren && {bus_if.addr[11:2], 2'b00} == 32'h4), //input RdEn
		.rstn(rstn), //input Reset
        .reset(!sifive_rxen),
		.rdata(uart_rx_byte), //output [7:0] Q
		.rvalid(rx_fifo_rvalid), //output Empty
		.wready(), //output Full
		.fifo_cnt(rx_fifo_cnt)
	);
endmodule






