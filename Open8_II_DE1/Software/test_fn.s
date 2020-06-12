;------------------------------------------------------------------------------
; Function time constant tables for use with epoch timer II alarm clock
; (4-bytes each at 1uS resolution for the epoch timer ii)

.ORG TIME_FN1_BLOCK
.DB $00,$00,$27,$0F ;  0.010 s
.DB $00,$00,$4E,$1F ;  0.020 s

.ORG TIME_FN2_BLOCK
.DB $00,$00,$27,$0F ;  0.010 s
.DB $00,$00,$4E,$1F ;  0.020 s
.DB $00,$00,$75,$2F ;  0.030 s

.ORG TIME_FN3_BLOCK
.DB $00,$00,$27,$0F ;  0.010 s
.DB $00,$00,$4E,$1F ;  0.020 s

;------------------------------------------------------------------------------

.ORG TEST_FUNC_BLOCK

;------------------------------------------------------------------------------
; Test init: Sets up any variables or hardware required
TEST_INIT:    PSH  R0
              CLR  R0
              STA  R0, Ints.VEC_Flag
              STA  R0, Ints.VEC_Index
              STA  R0, Ints.VEC_Arg_l
              STA  R0, Ints.VEC_Arg_h
              STA  R0, Test.Retval
              CLP  PSR_GP5
              CLP  PSR_GP6
              POP  R0
              RTS
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; Test dispatcher: Uses the VEC_Index variable to execute the requested test

TEST_DISPATCH:LDA  R0, Ints.VEC_Flag
              BNZ  TEST_RUN
              RTS

TEST_RUN:     CLR  R0
              STA  R0, Ints.VEC_Flag
              STA  R0, Test.Retval

; With 64 possible entry points, we need a more efficient branching mechanism
;  This method allows the code to jump to any point at the costs of some
;  pointer math and precalculated pointers in ROM by using a function select
;  variable

; Load the vector table pointer, which is the base address we will be using to
;  which we will add an offset to find our actual jump address

              LDA  R2, VECTOR_PTR      ; Load the pointer to the vector block
              LDA  R3, VECTOR_PTR+1    ;  table

; Compute the offset into the vector table.

              LDA  R0, Ints.VEC_Index ; Load the Ints.VEC_Index variable
              LDI  R1, #INDEX_MASK     ; Mask off the upper 2-bits, so that we
              AND  R1                  ;  only have a 6-bit value
              T0X  R4
              ROL  R0                  ; Multiply by 2, since addrs are 16-bit

; Add the computed offset to the base address of the entry point table. This
;  should leave R3:R2 pointing to the correct entry point in the table.

              ADD  R2                  ; R2 + R0 > R0, set C
              T0X  R2                  ; R0 -> R2
              CLR  R0                  ; We need to add ONLY the carry to R3
              ADC  R3                  ; R3 + 0 + C -> R0
              T0X  R3                  ; R3 -> R3

              TX0  R4
              LDI  R1,#$80
              OR   R1
              STA R0, LED_CONTROL

; Now we do a manual "JSR" by pushing the entry point address onto the stack,
;  and performing an RTS instruction to "return" to the entry point.

              LDX  R2++                ; Load the lower byte of the address
              T0X  R1                  ; Copy to R1 since we are out of order
              LDX  R2                  ; Load the upper byte of the address
              PSH  R0                  ; Push R0 to the stack, then push
              PSH  R1                  ; R1 the stack, so we jump to R1:R0
              RTS                      ; RTS to "return" to the entry point

; Index functions

TASK1_FN00:   JSR  DUT_SAFE_FUNC
              JMP  TASK1_FN_CHK

TASK1_FN01:   JSR  DUT_ARM_FUNC
              JMP  TASK1_FN_CHK

TASK1_FN02:   JSR  DUT_TRIG_FUNC
              JMP  TASK1_FN_CHK

TASK1_FN03:   JSR  DUT_QRY_FUNC
              JMP  TASK1_FN_CHK

TASK1_FN04:   JSR  DUT_VER_FUNC
              JMP  TASK1_FN_CHK

TASK1_FN05:   JMP  TASK1_FN_CHK

TASK1_FN06:   JMP  TASK1_FN_CHK

TASK1_FN07:   JMP  TASK1_FN_CHK

TASK1_FN08:   LDI  R0, #SEMAPHORE_VAL
              STA  R0, Counter.Enable
              STA  R0, Test.Retval
              JMP  TASK1_FN_CHK

TASK1_FN09:   CLR  R0
              STA  R0, Counter.Enable
              LDI  R0, #SEMAPHORE_VAL
              STA  R0, Test.Retval
              JMP  TASK1_FN_CHK

TASK1_FN0A:   LDI  R0, #SEMAPHORE_VAL
              STA  R0, Counter.Enable
              STA  R0, Counter.Reset
              STA  R0, Test.Retval
              JMP  TASK1_FN_CHK

TASK1_FN0B:   JMP  TASK1_FN_CHK

TASK1_FN0C:   JMP  TASK1_FN_CHK

TASK1_FN0D:   JMP  TASK1_FN_CHK

TASK1_FN0E:   JMP  TASK1_FN_CHK

TASK1_FN0F:   JMP  TASK1_FN_CHK

TASK1_FN10:   JMP  TASK1_FN_CHK

TASK1_FN11:   JMP  TASK1_FN_CHK

TASK1_FN12:   JMP  TASK1_FN_CHK

TASK1_FN13:   JMP  TASK1_FN_CHK

TASK1_FN14:   JMP  TASK1_FN_CHK

TASK1_FN15:   JMP  TASK1_FN_CHK

TASK1_FN16:   JMP  TASK1_FN_CHK

TASK1_FN17:   JMP  TASK1_FN_CHK

TASK1_FN18:   JMP  TASK1_FN_CHK

TASK1_FN19:   JMP  TASK1_FN_CHK

TASK1_FN1A:   JMP  TASK1_FN_CHK

TASK1_FN1B:   JMP  TASK1_FN_CHK

TASK1_FN1C:   JMP  TASK1_FN_CHK

TASK1_FN1D:   JMP  TASK1_FN_CHK

TASK1_FN1E:   JMP  TASK1_FN_CHK

TASK1_FN1F:   JMP  TASK1_FN_CHK

TASK1_FN20:   JMP  TASK1_FN_CHK

TASK1_FN21:   JMP  TASK1_FN_CHK

TASK1_FN22:   JMP  TASK1_FN_CHK

TASK1_FN23:   JMP  TASK1_FN_CHK

TASK1_FN24:   JMP  TASK1_FN_CHK

TASK1_FN25:   JMP  TASK1_FN_CHK

TASK1_FN26:   JMP  TASK1_FN_CHK

TASK1_FN27:   JMP  TASK1_FN_CHK

TASK1_FN28:   JMP  TASK1_FN_CHK

TASK1_FN29:   JMP  TASK1_FN_CHK

TASK1_FN2A:   JMP  TASK1_FN_CHK

TASK1_FN2B:   JMP  TASK1_FN_CHK

TASK1_FN2C:   JMP  TASK1_FN_CHK

TASK1_FN2D:   JMP  TASK1_FN_CHK

TASK1_FN2E:   JMP  TASK1_FN_CHK

TASK1_FN2F:   JMP  TASK1_FN_CHK

TASK1_FN30:   JMP  TASK1_FN_CHK

TASK1_FN31:   JMP  TASK1_FN_CHK

TASK1_FN32:   JMP  TASK1_FN_CHK

TASK1_FN33:   JMP  TASK1_FN_CHK

TASK1_FN34:   JMP  TASK1_FN_CHK

TASK1_FN35:   JMP  TASK1_FN_CHK

TASK1_FN36:   JMP  TASK1_FN_CHK

TASK1_FN37:   JMP  TASK1_FN_CHK

TASK1_FN38:   JMP  TASK1_FN_CHK

TASK1_FN39:   JMP  TASK1_FN_CHK

TASK1_FN3A:   JMP  TASK1_FN_CHK

TASK1_FN3B:   JMP  TASK1_FN_CHK

TASK1_FN3C:   JMP  TASK1_FN_CHK

TASK1_FN3D:   JMP  TASK1_FN_CHK

TASK1_FN3E:   JMP  TASK1_FN_CHK

TASK1_FN3F:   JMP  TASK1_FN_CHK
              ;JMP  TASK1_FN_CHK  (implied by position)

TASK1_FN_CHK: LDA  R0, Test.Retval
              BRZ  TASK1_FN_FAIL

TASK1_FN_PASS:STP  PSR_GP6
              JMP  TASK1_END

TASK1_FN_FAIL:CLP  PSR_GP6

TASK1_END:    LDA  R0, LED_CONTROL
              LDI  R1,#$7F
              AND  R1
              STA  R0, LED_CONTROL
              CLR  R0
              STA  R0, Ints.VEC_Index
              STA  R0, Ints.VEC_Arg_l
              STA  R0, Ints.VEC_Arg_h

              RTS
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; Test Function 1 (Disable the DUT)
DUT_SAFE_FUNC:LDA R0, TIME_FN1_BLK_PTR+0
              STA R0, Epoch.Table_Ptr_l
              LDA R0, TIME_FN1_BLK_PTR+1
              STA R0, Epoch.Table_Ptr_h

              CLR R0
              STA R0, Epoch.Index
              STA R0, Test.Step

              CLEAR_ETC_FLAG
              RESET_ETC_ADDRESS
              SET_ETC_ALARM
              ENABLE_ETC_INT

              JSR REQ_DUT_QRY

              LDI R0, #$01
              STA R0, Test.Step

_DUT_SAFE_S0: INT 0
              LDA R0, Ints.ETC_Flag
              BRZ _DUT_SAFE_S0
              CLEAR_ETC_FLAG

              LDI R0, #$01
              STA R0, Epoch.Index
              SET_ETC_ALARM

              JSR SET_DUT_SAFE

              LDI R0, #$02
              STA R0, Test.Step

              DISABLE_ETC_INT

              LDI R0, #SEMAPHORE_VAL
              STA R0, Test.Retval

              RTS
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; Test Function 2 (Enable the DUT)
DUT_ARM_FUNC: LDA R0, TIME_FN2_BLK_PTR+0
              STA R0, Epoch.Table_Ptr_l
              LDA R0, TIME_FN2_BLK_PTR+1
              STA R0, Epoch.Table_Ptr_h

              CLR R0
              STA R0, Epoch.Index
              STA R0, Test.Step

              CLEAR_ETC_FLAG
              RESET_ETC_ADDRESS
              SET_ETC_ALARM
              ENABLE_ETC_INT

              JSR REQ_DUT_QRY

              LDI R0, #$01
              STA R0, Test.Step

_DUT_ARM_S0:  INT 0
              LDA R0, Ints.ETC_Flag
              BRZ _DUT_ARM_S0
              CLEAR_ETC_FLAG

              LDI R0, #$01
              STA R0, Epoch.Index
              SET_ETC_ALARM

              JSR SET_DUT_DTD

              LDI R0, #$02
              STA R0, Test.Step

_DUT_ARM_S1:  INT 0
              LDA R0, Ints.ETC_Flag
              BRZ _DUT_ARM_S1
              CLEAR_ETC_FLAG

              LDI R0, #$02
              STA R0, Epoch.Index
              SET_ETC_ALARM

              JSR SET_DUT_ARM

              LDI R0, #$03
              STA R0, Test.Step

              DISABLE_ETC_INT

              LDI R0, #SEMAPHORE_VAL
              STA R0, Test.Retval

              RTS
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; Test Function 3 (Trigger the DUT)
DUT_TRIG_FUNC:LDA R0, TIME_FN3_BLK_PTR+0
              STA R0, Epoch.Table_Ptr_l
              LDA R0, TIME_FN3_BLK_PTR+1
              STA R0, Epoch.Table_Ptr_h

              CLR R0
              STA R0, Epoch.Index
              STA R0, Test.Step

              CLEAR_ETC_FLAG
              RESET_ETC_ADDRESS
              SET_ETC_ALARM
              ENABLE_ETC_INT

              JSR REQ_DUT_QRY

              LDI R0, #$01
              STA R0, Test.Step

_DUT_TRIG_S0: INT 0
              LDA R0, Ints.ETC_Flag
              BRZ _DUT_TRIG_S0
              CLEAR_ETC_FLAG

              LDI R0, #$01
              STA R0, Epoch.Index
              SET_ETC_ALARM

              STP PSR_GP5

              LDI R0, #$02
              STA R0, Test.Step

_DUT_TRIG_S1: INT 0
              LDA R0, Ints.ETC_Flag
              BRZ _DUT_TRIG_S1
              CLEAR_ETC_FLAG

              CLP PSR_GP5

              LDI R0, #$03
              STA R0, Test.Step

              DISABLE_ETC_INT

              LDI R0, #SEMAPHORE_VAL
              STA R0, Test.Retval

              RTS
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; Test Function 4 (QUERY the DUT status)
DUT_QRY_FUNC: JSR REQ_DUT_QRY
              LDI R0, #SEMAPHORE_VAL
              STA R0, Test.Retval
              RTS
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; Test Function 5 (Get the DUT version)
DUT_VER_FUNC: JSR REQ_DUT_VER
              LDI R0, #SEMAPHORE_VAL
              STA R0, Test.Retval
              RTS
;------------------------------------------------------------------------------