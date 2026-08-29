`default_nettype none
module SIFIVE_SPI(
    input wire clk,
    input wire rstn,
    slv_interface.slv bus_if,

    output reg spi_cs,
    output reg spi_clk,
    output reg spi_mosi,
    input wire spi_miso,
    output reg spi_irq
    
);
    
    
    reg[7:0] rx_state_data;
    reg rx_state_data_full;
    wire[7:0] rx_fifo_rdata;
    wire rx_fifo_rvalid;
    wire[3:0] rx_fifo_cnt;
    sync_fifo #(
        .WIDTH(8)
    ) rx_fifo_inst(
		.wdata(rx_state_data), //input [7:0] Data
		.clk(clk), //input Clk
		.wvalid(rx_state_data_full), //input WrEn
		.rready({bus_if.addr[11:2], 2'b00} == 32'h4c && !bus_if.awren && bus_if.avalid), //input RdEn
		.rstn(rstn), //input Reset
		.rdata(rx_fifo_rdata), //output [7:0] Q
		.rvalid(rx_fifo_rvalid), //output Empty
		.wready(), //output Full
        .fifo_cnt(rx_fifo_cnt),
        .reset(1'b0)
	);


    reg dir;
    reg endian;
    wire tx_fifo_rden;
    wire[8:0] tx_rdata;
    wire tx_rvalid;
    wire tx_wready;                      
    wire[3:0] tx_fifo_cnt;
    sync_fifo #(
        .WIDTH(9)
    ) tx_fifo_inst(
		.wdata({dir, bus_if.awdata[7:0]}), //input [7:0] Data
		.clk(clk), //input Clk
		.wvalid({bus_if.addr[11:2], 2'b00} == 32'h48 && bus_if.awren && bus_if.avalid), //input WrEn
		.rready(tx_fifo_rden), //input RdEn
		.rstn(rstn), //input Reset
		.rdata(tx_rdata), //output [7:0] Q
		.rvalid(tx_rvalid), //output Empty
		.wready(tx_wready), //output Full
        .fifo_cnt(tx_fifo_cnt),
        .reset(1'b0)
	);

    reg[11:0] sckdiv; // 0x0 fclk / 2(sckdiv+1)
    //reg[1:0] sckmode; // 0x4[pha, pol]
    wire[31:0] csid = '0;
    reg csdef;
    reg[1:0] csmode; // 0x18 0: auto, 2: hold, 3: off (always HIGH)
    reg[7:0] sckcs; reg[7:0] cssck; 
    reg[7:0] intercs;
    //reg[31:0] fmt;
    wire[31:0] txfifo_read = {~tx_wready, 31'h0};
    wire[31:0] rxfifo_read = {~rx_fifo_rvalid, 23'd0, rx_fifo_rdata};
    reg[2:0] txmark;
    reg[2:0] rxmark;
    reg rxwm_ie; reg txwm_ie;
    wire rxwm_ip = rx_fifo_cnt > rxmark; wire txwm_ip = tx_fifo_cnt < txmark;
    
     
    reg[31:0] rdata;
    always @(posedge clk or negedge rstn)
        if (!rstn)
            rdata <= '0;
        else if (bus_if.avalid)
            case ({bus_if.addr[11:2], 2'b00})
                12'h00: rdata <= sckdiv;
//                12'h04: rdata <= sckmode;
                12'h10: rdata <= csid;
                12'h14: rdata <= csdef;
                12'h18: rdata <= csmode;
                12'h28: rdata <= {sckcs, 8'd0, cssck};
                12'h2C: rdata <= intercs;
                12'h40: rdata <= {dir, endian, 2'b00} | 32'h0008_0000;
                12'h48: rdata <= txfifo_read;
                12'h4C: rdata <= rxfifo_read;
                12'h50: rdata <= txmark;
                12'h54: rdata <= rxmark;
                12'h70: rdata <= {rxwm_ie, txwm_ie};
                12'h74: rdata <= {rxwm_ip, txwm_ip};
                default: rdata <= '0;
            endcase  
    reg rvalid;
    always @(posedge clk or negedge rstn)
        if (!rstn)
            rvalid <= 1'b0;
        else
            rvalid <= bus_if.avalid;
    assign bus_if.rdata = rdata;
    assign bus_if.rvalid = rvalid;
    assign bus_if.aready = 1'b1;
              
    
    always @(posedge clk or negedge rstn)
        if (!rstn) begin
            sckdiv <= '0;
            //sckmode <= '0;
            csdef <= 1'b1;
            csmode <= '0;
            sckcs <= 1; cssck <= 1;
            intercs <= 1;
            {dir, endian} <= '0;
            txmark <= 0;
            rxmark <= 0;
            {rxwm_ie, txwm_ie} <= '0;
        end else if (bus_if.awren && bus_if.avalid)
            case ({bus_if.addr[11:2], 2'b00})
                12'h00: sckdiv <= bus_if.awdata[11:0];
                //32'h04: sckmode <= bus_if.awdata[1:0];
                12'h14: csdef <= bus_if.awdata[0];
                12'h18: csmode <= bus_if.awdata[1:0];
                12'h28: {sckcs, cssck} <= {bus_if.awdata[23:16], bus_if.awdata[7:0]};
                12'h2C: intercs <= bus_if.awdata[7:0];
                12'h40: {dir, endian} <= bus_if.awdata[3:2];
                12'h50: txmark <= bus_if.awdata[2:0];
                12'h54: rxmark <= bus_if.awdata[2:0];
                12'h70: {rxwm_ie, txwm_ie} <= bus_if.awdata[1:0];
            endcase
    
                                 
    always_ff @(posedge clk or negedge rstn)                    
        if (!rstn)                                              
            spi_irq <= 1'b0;                                    
        else                                                    
            spi_irq <= txwm_ip && txwm_ie || rxwm_ip && rxwm_ie;
        
    
    reg[12:0] clk_ctr;
    wire[12:0] ctr_limit = {sckdiv, 1'b1};
    wire clk_falling_nxt = clk_ctr >= ctr_limit;
    wire clk_rising_nxt = clk_ctr == sckdiv;
    always @(posedge clk or negedge rstn)
        if (!rstn)
            clk_ctr <= '0;
        else
            clk_ctr <= clk_falling_nxt ? '0 : clk_ctr + 1'b1;
    
    reg[7:0] state_tx_data;
    reg state_rx_en;
    
    reg clk_out;
    reg cs_out;
    wire mosi_out = state_tx_data[7];
    always_ff @(posedge clk or negedge rstn)
        if (!rstn) begin
            spi_clk <= 1'b0;
            spi_cs <= 1'b1;
            spi_mosi <= 1'b1;
        end else begin
            spi_clk <= clk_out;
            spi_cs <= cs_out;
            spi_mosi <= mosi_out;
        end
    
  
    
    reg miso_latch;
    reg[1:0] spi_miso_latch_shift;
    always_ff @(posedge clk or negedge rstn)
        if (!rstn) begin
            spi_miso_latch_shift <= '0;
        end else begin
            spi_miso_latch_shift <= {miso_latch, spi_miso_latch_shift[1]};
        end
    
    (* ASYNC_REG = "TRUE" *) reg[1:0] spi_miso_sync;
    always_ff @(posedge clk or negedge rstn)
        if (!rstn) begin
            spi_miso_sync <= '0;
        end else begin
            spi_miso_sync <= {spi_miso, spi_miso_sync[1]};
        end
        
    reg[2:0] rx_ctr;
    always_ff @(posedge clk or negedge rstn)
        if (!rstn) begin
            rx_ctr <= '0;
            rx_state_data_full <= 1'b0;
            rx_state_data <= '0;
        end else begin
            rx_ctr <= rx_ctr + spi_miso_latch_shift[0];
            rx_state_data_full <= rx_ctr == 7 && spi_miso_latch_shift[0];
            if (spi_miso_latch_shift[0]) begin
                rx_state_data <= {rx_state_data[6:0], spi_miso_sync[0]};
            end
        end
    
    (* fsm_encoding = "one_hot" *) typedef enum {
        IDLE,
        ASSERT_CS,
        CLOCK_DATA,
        WAIT_DEASSERT
    } SPI_STATE;
    
    (* fsm_encoding = "one_hot" *) SPI_STATE state;
    wire hold_cs = csmode == 2;
    wire off_cs = csmode == 3;
    reg[7:0] cycle;
    assign tx_fifo_rden = clk_falling_nxt && (
        state == IDLE && cycle <= 1 ||
        state == CLOCK_DATA && hold_cs && cycle <= 1
    );
    always_ff @(posedge clk or negedge rstn)
        if (!rstn) begin
            state <= IDLE;
            cycle <= '0;
            cs_out <= 1'b1;
            state_tx_data <= '0;
            state_rx_en <= 1'b0;
            clk_out <= 1'b0;
            miso_latch <= 1'b0;
        end else begin
            miso_latch <= 1'b0;
            case (state)
                IDLE: if (clk_falling_nxt) begin
                    cycle <= cycle - (cycle > 0);
                    cs_out <= csdef;
                    if (cycle <= 1 && tx_rvalid) begin
                        state <= ASSERT_CS;
                        cycle <= cssck;
                        cs_out <= csdef ? off_cs : ~off_cs;
                        state_tx_data <= tx_rdata[7:0];
                        state_rx_en <= ~tx_rdata[8];
                    end
                end
                ASSERT_CS: if (clk_falling_nxt) begin
                    cycle <= cycle - (cycle > 0);
                    if (cycle <= 1) begin
                        state <= CLOCK_DATA;
                        cycle <= 8;
                    end
                end
                CLOCK_DATA: begin
                    if (clk_falling_nxt) begin
                        clk_out <= 1'b0;
                        state_tx_data <= {state_tx_data[6:0], 1'b1};
                        cycle <= cycle - (cycle > 0);
                        miso_latch <= state_rx_en && (cycle > 0);
                        if (cycle <= 1) begin
                            if (hold_cs) begin
                                if (tx_rvalid) begin
                                    state_tx_data <= tx_rdata[7:0];
                                    state_rx_en <= ~tx_rdata[8];
                                    cycle <= 8;
                                end
                            end else begin
                            
                                state <= WAIT_DEASSERT;
                                cycle <= sckcs;
                            end
                        end
                    end
                    if (clk_rising_nxt && cycle > 0) begin
                        clk_out <= 1'b1;
                    end
                end
                WAIT_DEASSERT: if (clk_falling_nxt) begin
                    cycle <= cycle - (cycle > 0);
                    if (cycle <= 1) begin
                        cs_out <= csdef;
                        cycle <= intercs;
                        state <= IDLE;
                    end
                end
                default: state <= IDLE;
            endcase 
        end
   
endmodule

