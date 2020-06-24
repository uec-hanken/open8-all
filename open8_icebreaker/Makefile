PROJ ?= icebreaker_top

SOURCES ?= icebreaker_top.vhd ../VHDL/async_ser_rx.vhd ../VHDL/async_ser_tx.vhd ../VHDL/o8_alu16.vhd ../VHDL/o8_async_serial.vhd ../VHDL/o8_btn_int.vhd ../VHDL/o8_elapsed_usec.vhd ../VHDL/o8_epoch_timer_ii.vhd ../VHDL/o8_gpin.vhd ../VHDL/o8_ram_4k.vhd ../VHDL/o8_register.vhd ../VHDL/o8_rtc.vhd ../VHDL/o8_sys_timer_ii.vhd ../VHDL/Open8_cfg.vhd ../VHDL/Open8_pkg.vhd o8_rom_4k.vhd fifo_1k_core.vhd ram_4k_core.vhd button_db.vhd o8_cpu.vhd software/rom_4k_core.vhdl

PIN_DEF = icebreaker_top.pcf
DEVICE = sg48

all: $(PROJ).bin

software/rom_4k_core.vhdl: software/make.sh
	cd software && ./make.sh

$(PROJ).json: $(SOURCES)
	yosys -m ghdl -p 'ghdl --ieee=synopsys -fexplicit --std=08 $^ -e icebreaker_top; synth_ice40 -json $@'

$(PROJ).asc: $(PROJ).json
	nextpnr-ice40 --up5k --package $(DEVICE) --pcf $(PIN_DEF) --json $< --asc $@

$(PROJ).bin: $(PROJ).asc
	icepack $< $@

prog: $(PROJ).bin
	iceprog $<

clean:
	rm -fv $(PROJ).json $(PROJ).asc $(PROJ).bin software/*.hex software/*.out software/rom_4k_core.vhdl

.SECONDARY:

.PHONY: all prog clean
