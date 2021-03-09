.ORG CHRONO_FUNC_BLOCK

;-----------------------------------------------------------------------------
; Reset the hardware RTC counter

;-----------------------------------------------------------------------------
RTC_PBRST_INI:CLR  R0
              STA  R0, Ints.BTN_Flag1
              RTS
;-----------------------------------------------------------------------------

;-----------------------------------------------------------------------------
RTC_PBRST_CLR:LDA  R0, Ints.BTN_Flag1
              BNZ  _CHRONO_RUN
              RTS

_CHRONO_RUN:  CLR  R0
              STA  R0, RTC_TENTHS
              STA  R0, RTC_SECONDS
              STA  R0, RTC_MINUTES
              STA  R0, RTC_HOURS
              STA  R0, RTC_DOW
              STA  R0, RTC_SET
              STA  R0, Ints.BTN_Flag1
              RTS
;-----------------------------------------------------------------------------