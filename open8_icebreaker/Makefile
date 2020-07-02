PROJ ?= icebreaker_top

SOURCES ?= icebreaker_top.vhd ../Open8_II_DE0/hdl/async_ser_rx.vhd ../Open8_II_DE0/hdl/async_ser_tx.vhd ../Open8_II_DE0/hdl/o8_alu16.vhd ../Open8_II_DE0/hdl/o8_async_serial.vhd ../Open8_II_DE0/hdl/o8_btn_int.vhd ../Open8_II_DE0/hdl/o8_elapsed_usec.vhd ../Open8_II_DE0/hdl/o8_epoch_timer_ii.vhd ../Open8_II_DE0/hdl/o8_gpin.vhd ../Open8_II_DE0/hdl/o8_ram_4k.vhd ../Open8_II_DE0/hdl/o8_register.vhd ../Open8_II_DE0/hdl/o8_rtc.vhd ../Open8_II_DE0/hdl/o8_sys_timer_ii.vhd ../Open8_II_DE0/hdl/Open8_cfg.vhd ../Open8_II_DE0/hdl/Open8_pkg.vhd o8_cpu.vhd button_db.vhd o8_rom_4k.vhd fifo_1k_core.vhd ram_4k_core.vhd software/rom_4k_core.vhdl

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
