## ---------------------------------------------------------------------------
## arty_a7.xdc - Digilent Arty A7-35T.  Pins, timing, and the four constraints
## without which this design is not a TRNG.
##
## Add this ONE file to the project.  It replaces the Digilent master XDC.
## ---------------------------------------------------------------------------

## ------------------------------------------------------------------- clock
set_property -dict {PACKAGE_PIN E3 IOSTANDARD LVCMOS33} [get_ports CLK100MHZ]
create_clock -period 10.000 -name sys_clk [get_ports CLK100MHZ]

## the design runs at 50 MHz, made by halving the crystal through a BUFG
create_generated_clock -name clk50 -source [get_ports CLK100MHZ] -divide_by 2 \
    [get_pins u_bufg/O]

## ------------------------------------------------------------------- buttons, switches
set_property -dict {PACKAGE_PIN C2 IOSTANDARD LVCMOS33} [get_ports ck_rst]
set_property -dict {PACKAGE_PIN A8 IOSTANDARD LVCMOS33} [get_ports sw0]

## ------------------------------------------------------------------- LEDs
set_property -dict {PACKAGE_PIN H5  IOSTANDARD LVCMOS33} [get_ports {led[0]}]
set_property -dict {PACKAGE_PIN J5  IOSTANDARD LVCMOS33} [get_ports {led[1]}]
set_property -dict {PACKAGE_PIN T9  IOSTANDARD LVCMOS33} [get_ports {led[2]}]
set_property -dict {PACKAGE_PIN T10 IOSTANDARD LVCMOS33} [get_ports {led[3]}]

## ------------------------------------------------------------------- USB-UART
set_property -dict {PACKAGE_PIN D10 IOSTANDARD LVCMOS33} [get_ports uart_rxd_out]
set_property -dict {PACKAGE_PIN A9  IOSTANDARD LVCMOS33} [get_ports uart_txd_in]

## ------------------------------------------------------------------- Pmod JB1, the probe
set_property -dict {PACKAGE_PIN E15 IOSTANDARD LVCMOS33} [get_ports jb1]

## ###########################################################################
## THE FOUR THAT MATTER
## ###########################################################################

## 1. THE COMBINATIONAL LOOP
## Vivado reports the ring oscillator as a combinational loop and, left alone,
## either breaks it or tries to time it.  KEEP and DONT_TOUCH in ro_nand.v stop
## the optimiser removing it; these stop the timing engine chasing a path that
## has no clock.  Remove them and the design still builds, still passes most
## statistical tests, and has ZERO entropy.
set_property ALLOW_COMBINATORIAL_LOOPS TRUE \
    [get_nets -hierarchical -filter {NAME =~ *u_ro/w*}]

## Three separate traps in these two lines, all three measured on 12/08/2026:
##
## 1. An XDC file is not a Tcl script.  `foreach` in here raises
##      CRITICAL WARNING [Designutils 20-1307] Command 'foreach' is not supported
##    and the whole block is DISCARDED.  set_disable_timing takes a list, so no
##    loop is needed anyway.
##
## 2. Match on REF_NAME, not on the cell name.  Synthesis calls these LUTs
##    w0_inferred_i_1 ... w10_inferred_i_1, never w*_LUT*, so the old
##    name-only filter selected 0 cells.  The filter below selects all 11.
##
## 3. The cells only exist AFTER synthesis, so during the SYNTHESIS run the
##    filter is legitimately empty and set_disable_timing raises
##      CRITICAL WARNING [Vivado 12-4739] No valid object(s) found
##    -quiet is the fix.  `if` does not work either - Designutils 20-1307
##    rejects it exactly like foreach.  The constraint still lands on all 11
##    LUTs in the implementation run, which is the run that matters.
set_disable_timing -quiet [get_cells -hierarchical -quiet \
    -filter {NAME =~ *u_ro/w* && REF_NAME =~ LUT*}]

## 2. THE INJECTION PATHS ARE ASYNCHRONOUS ON PURPOSE
## The oscillator taps go straight into the XOR in front of the ring generator
## flip-flops.  They are MEANT to violate setup and hold - that is part of where
## the entropy comes from.  Declaring them false stops Vivado reporting
## thousands of failing paths and, more importantly, stops it inserting logic to
## "fix" them.
set_false_path -through [get_nets -hierarchical -filter {NAME =~ *u_ro/w*}]

## the ripple counters clocked by the oscillator are measurement only
set_false_path -to [get_cells -hierarchical -filter {NAME =~ *rDiv_reg[*]}]
set_false_path -to [get_cells -hierarchical -filter {NAME =~ *rRoDiv_reg[*]}]

## 3. KEEP THE OSCILLATOR IN ONE PLACE
## A ring spread across the die picks up crosstalk from everything around it.
## Crosstalk looks like entropy without being entropy, and it moves whenever the
## rest of the design moves, so the source stops being reproducible.
## Uncomment once the design fits, and keep the region for every later build.
# create_pblock pb_ro
# add_cells_to_pblock [get_pblocks pb_ro] \
#     [get_cells -hierarchical -filter {NAME =~ *u_ro/*}]
# resize_pblock [get_pblocks pb_ro] -add {SLICE_X8Y40:SLICE_X11Y47}

## 4. DO NOT LET THE TOOL MERGE OR REPLICATE THE ACCUMULATOR
## ASYNC_REG in the RTL already asks for this.  Repeated here because a run with
## -flatten_hierarchy full can still replicate them, and a replicated flip-flop
## is fed by a different physical wire - which changes the sampling instant,
## which changes the entropy.
set_property DONT_TOUCH TRUE \
    [get_cells -hierarchical -filter {NAME =~ *u_rg/rS_reg[*]}]

## ---------------------------------------------------------------------------
## Bitstream: the Arty boots from SPI flash, and these keep the flash usable.
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]
