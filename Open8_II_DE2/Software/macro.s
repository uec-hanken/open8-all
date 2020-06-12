;------------------------------------------------------------------------------
; The Open8 supports an optional mode for the RSP instruction that
;  converts it from Reset Stack Pointer to Relocate Stack Pointer.
; The new form of the instruction takes one of the CPU flags as a
;  direction/mode bit. Setting PSR_GP4 will cause the instruction
;  to write R1:R0 -> SP, while clearing it will cause the instruction
;  to copy the SP -> R1:R0. This macro creates two pseudo-instructions
;  that automate this.

.MACRO RETRIEVE_SP
              CLP PSR_GP4
              RSP
.ENDM

.MACRO RELOCATE_SP
              STP PSR_GP4
              RSP
              CLP PSR_GP4
.ENDM
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; Epoch Timer macros

.MACRO SET_ETC_ALARM
              JSR UF_ETC_SET
.ENDM

.MACRO LATCH_CURRENT_TIME
              STA R0, ETC_EPOCH_B0
.ENDM

.MACRO RESET_ETC_ADDRESS
              STA R0, ETC_RESET
.ENDM

.MACRO CLEAR_ETC_FLAG
              CLR R0
              STA R0, Ints.ETC_Flag
.ENDM

.MACRO ENABLE_ETC_INT
              JSR UF_ETC_ARM
.ENDM

.MACRO DISABLE_ETC_INT
              JSR UF_ETC_SAFE
.ENDM

;------------------------------------------------------------------------------