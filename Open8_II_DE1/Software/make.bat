echo off
cls
cd software
echo Making Application ROM
open8_as -o   app.s app.obj
open8_link -vb mk_app app.out
srec_cat app.out -binary -o APP.HEX -i
del *.obj
echo Done!
