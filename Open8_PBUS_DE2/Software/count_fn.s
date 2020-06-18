.ORG COUNTER_FUNC_BLOCK

;-----------------------------------------------------------------------------
; Initialize the BCD counter

COUNTER_INIT: CLR  R0
              STA  R0, Counter.Enable
              STA  R0, Counter.Reset
              STA  R0, Ints.BTN_Flag2
              STA  R0, Ints.RTC_Flag2

_COUNTER_RST: LDI  R1, #$30
              OR   R0
              STA  R0, MAXLED_DIG0
              STA  R0, MAXLED_DIG1
              STA  R0, MAXLED_DIG2
              STA  R0, MAXLED_DIG3
              STA  R0, MAXLED_DIG4
              STA  R0, MAXLED_DIG5

              LDI  R0, #$3F
              STA  R0, MAXLED_DEC_MODE

              LDI  R0, #$07
              STA  R0, MAXLED_INTENSITY

              LDI  R0, #$05
              STA  R0, MAXLED_SCAN_LIM

              LDI  R0, #$01
              STA  R0, MAXLED_SHUTDOWN

              LDI  R0, #$09
              STA  R0, Counter.Value+0
              STA  R0, Counter.Value+1
              STA  R0, Counter.Value+2
              STA  R0, Counter.Value+3
              STA  R0, Counter.Value+4
              STA  R0, Counter.Value+5
              STA  R0, Counter.Value+6
              RTS
;-----------------------------------------------------------------------------

;-----------------------------------------------------------------------------
; Advance the BCD counter

COUNTER_EXEC: LDA  R0, Counter.Enable
              BNZ  _CTR_CHKRST
              RTS

_CTR_CHKRST:  LDA  R0, Counter.Reset
              BRZ  _CTR_CHKTMR
              BNZ  _COUNTER_RST

_CTR_CHKTMR:  LDA  R0, Ints.RTC_Flag2
              BNZ  _CTR_UPDATE
              RTS

_CTR_UPDATE:  CLR  R0
              STA  R0, Ints.RTC_Flag2

_BCD_CTR:     LDI  R1, #$0A

_BCD_D0:      LDA  R0, Counter.Value+0
              INC  R0
              CMP  R1
              BNN  _BCD_D1
              STA  R0, Counter.Value+0
              BRN  _BCD_EXIT

_BCD_D1:      CLR  R0
              STA  R0, Counter.Value+0

              LDA  R0, Counter.Value+1
              INC  R0
              CMP  R1
              BNN  _BCD_D2
              STA  R0, Counter.Value+1
              BRN  _BCD_EXIT

_BCD_D2:      CLR  R0
              STA  R0, Counter.Value+1

              LDA  R0, Counter.Value+2
              INC  R0
              CMP  R1
              BNN  _BCD_D3
              STA  R0, Counter.Value+2
              BRN  _BCD_EXIT

_BCD_D3:      CLR  R0
              STA  R0, Counter.Value+2

              LDA  R0, Counter.Value+3
              INC  R0
              CMP  R1
              BNN  _BCD_D4
              STA  R0, Counter.Value+3
              BRN  _BCD_EXIT

_BCD_D4:      CLR  R0
              STA  R0, Counter.Value+3

              LDA  R0, Counter.Value+4
              INC  R0
              CMP  R1
              BNN  _BCD_D5
              STA  R0, Counter.Value+4
              BRN  _BCD_EXIT

_BCD_D5:      CLR  R0
              STA  R0, Counter.Value+4

              LDA  R0, Counter.Value+5
              INC  R0
              CMP  R1
              BNN  _BCD_D6
              STA  R0, Counter.Value+5
              BRN  _BCD_EXIT

_BCD_D6:      CLR  R0
              STA  R0, Counter.Value+5

              LDA  R0, Counter.Value+6
              INC  R0
              CMP  R1
              BNN  _BCD_ROLL
              STA  R0, Counter.Value+6
              BRN  _BCD_EXIT

_BCD_ROLL:    CLR  R0
              STA  R0, Counter.Value+6

_BCD_EXIT:    LDA  R0, Counter.Value+6
              STA  R0, MAXLED_DIG5

              LDA  R0, Counter.Value+5
              STA  R0, MAXLED_DIG4

              LDA  R0, Counter.Value+4
              STA  R0, MAXLED_DIG3

              LDA  R0, Counter.Value+3
              STA  R0, MAXLED_DIG2

              LDA  R0, Counter.Value+2
              STA  R0, MAXLED_DIG1

              LDA  R0, Counter.Value+1
              STA  R0, MAXLED_DIG0
              RTS
;-----------------------------------------------------------------------------