
`default_nettype none
module top(
    input wire clk,
    input wire in_rstn,
    output wire uart_tx,
    input wire uart_rx,
    output wire spi0_clk,
    input wire spi0_miso,
    output wire spi0_mosi,
    output wire spi0_cs,
    output wire[7:0] gpo
);

    (* ASYNC_REG = "TRUE" *) reg[3:0] rstn_sync = '0;
    always_ff @(posedge clk or negedge in_rstn)
        if (!in_rstn)
            rstn_sync <= '0;
        else
            rstn_sync <= {1'b1, rstn_sync[3:1]};
    
    reg rstn = 1'b0;
    always_ff @(posedge clk or negedge rstn_sync[0])
        if (!rstn_sync[0])
            rstn <= 1'b0;
        else
            rstn <= 1'b1;
       
    
            
    localparam SCRATCH_BASE = 32'h7000_0000;
    localparam SCRATCH_SIZE = 32'h1000_0000;
	 
    localparam BOOTROM_BASE = 32'h10000;
    localparam BOOTROM_SIZE = 32'h10000;
    
    localparam CLINT0_BASE = 32'h0200_0000;
    localparam CLINT0_SIZE = 32'h0001_0000;

    localparam PLIC0_BASE  = 32'hC000000;
    localparam PLIC0_SIZE = 32'h4000000;
	 
    localparam UART0_BASE = 32'h10013000;
    localparam UART0_SIZE = 32'h00001000;
    
    localparam SPI0_BASE  = 32'h10024000;
    localparam SPI0_SIZE  = 32'h1000;
    
    localparam SIFIVE_GPO_BASE = 32'h6600_0000;
    localparam SIFIVE_GPO_SIZE = 32'h0000_1000;
    
    localparam SHA256_BASE     = 32'h6700_0000;
    localparam SHA256_SIZE     = 32'h0000_1000;
    
    // STEP 1. ADD 1 whenever there is new device
    localparam DMEM_N_SLAVES = 8;
    localparam logic[31:0] DMEM_ADDRESS_RANGES[DMEM_N_SLAVES][2] = '{
        '{32'(SCRATCH_BASE), 32'(SCRATCH_BASE + SCRATCH_SIZE)},
        '{32'(BOOTROM_BASE), 32'(BOOTROM_BASE + BOOTROM_SIZE)},
        '{32'(CLINT0_BASE), 32'(CLINT0_BASE+CLINT0_SIZE)},
        '{32'(PLIC0_BASE), 32'(PLIC0_BASE+PLIC0_SIZE)},
        '{32'(UART0_BASE), 32'(UART0_BASE+UART0_SIZE)},
        '{32'(SPI0_BASE), 32'(SPI0_BASE+SPI0_SIZE)},
        '{32'(SIFIVE_GPO_BASE), 32'(SIFIVE_GPO_BASE + SIFIVE_GPO_SIZE)},
        //, STEP 2. APPEND THEIR ADDRESS HERE {32'(START), 32'(END)}
         
        '{32'(SHA256_BASE), 32'(SHA256_BASE + SHA256_SIZE)}
    }; 
    
    wire uart0_irq;
    wire spi0_irq;
    slv_interface cpu_dfetch_if();
    slv_interface slave_dfetch_if[DMEM_N_SLAVES](); 

    // STEP 3. ADDING YOUR MMIO MODULE, need wrapper if your module is not SystemVerilog (pure verilog for example)

    SHA256 sha256_accel(
        .clk,
        .rstn,
        .bus_if(slave_dfetch_if[7])
    );
    

    Scratch4096 internal_mem(
        .clk,
        .rstn,
        .bus_if(slave_dfetch_if[0])
    );
    
    boot_rom bootrom0(
        .clk,
        .rstn,
        .bus_if(slave_dfetch_if[1])
    );

    wire[63:0] clint_mtime;
    wire clint0_MTIP;
    wire clint0_MSIP;
    RISCV_CLINT64 clint0(
            .clk,
            .rstn,
            .bus_if(slave_dfetch_if[2]),
            .out_mtime(clint_mtime),
            .out_MTIP0(clint0_MTIP),
            .out_MSIP0(clint0_MSIP)
            
    );
	 
    
    wire[14:0] sources_irq;
    assign sources_irq[0] = uart0_irq;
    assign sources_irq[1] = spi0_irq;
    assign sources_irq[14:2] = '0;
	wire plic0_MEIP;
	wire plic0_SEIP;
	RISCV_PLIC15_OPT #(
        .NUM_DEVICES(15),
        .THRESHOLD_BITS(3)
    ) plic0(
            .clk,
            .rstn,
            .bus_if(slave_dfetch_if[3]),
            .sources_irq(sources_irq),
            .out_MEIP0(plic0_MEIP),
            .out_SEIP0(plic0_SEIP)
    );
    SIFIVE_UART uart0(
        .clk,
        .rstn,
        .bus_if(slave_dfetch_if[4]),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx),
        .uart_irq(uart0_irq)
    );
    SIFIVE_SPI spi0(
        .clk,
        .rstn,
        .bus_if(slave_dfetch_if[5]),
        .spi_cs(spi0_cs),
        .spi_clk(spi0_clk),
        .spi_mosi(spi0_mosi),
        .spi_miso(spi0_miso),
        .spi_irq(spi0_irq)
    );
    
    
    SIFIVE_GPO gpo0(
        .clk,
        .rstn,
        .bus_if(slave_dfetch_if[6]),
        .gpo
    );
    single_master_multi_slave #(
        .N_SLAVES(DMEM_N_SLAVES),
        .ADDRESS_RANGES(DMEM_ADDRESS_RANGES)
    ) dfetch_bus(
        clk,
        rstn,
        cpu_dfetch_if,
        slave_dfetch_if
    );
    riscv64 #(.HART_ID(0)) riscv0(
        .clk,
        .rstn,
        .bus_if(cpu_dfetch_if),
        .clint_mtime(clint_mtime),
        .in_MTIP(clint0_MTIP),
        .in_MSIP(clint0_MSIP),
        .in_MEIP(plic0_MEIP),
        .in_SEIP(plic0_SEIP)
    );
endmodule
