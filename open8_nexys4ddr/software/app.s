;-----------------------------------------------------------------------------
; Open8_II Test Application
;-----------------------------------------------------------------------------

; Note that the order of included files is important due to the way the
;  assembler works. Any constant which is used to derive another constant must
;  be defined first. The exception is creating pointer tables, which occurs on
;  a later pass.

.INCLUDE "config.s"
.INCLUDE "constant.s"
.INCLUDE "variable.s"
.INCLUDE "macro.s"
.INCLUDE "task.s"
.INCLUDE "test_fn.s"
.INCLUDE "count_fn.s"
.INCLUDE "chrono_fn.s"
.INCLUDE "user_fn.s"
.INCLUDE "isr_fn.s"

