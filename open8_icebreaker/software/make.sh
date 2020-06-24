#!/bin/bash
set -e
echo "Making Application ROM"
open8_as -o app.s app.obj
open8_link -vb mk_app app.out
od -t x1 -An -w1 -v app.out > app.hex
echo "Making VHDL, will take a while..."
./hex_2_vhdl app.hex > rom_4k_core.vhdl
echo Done!

