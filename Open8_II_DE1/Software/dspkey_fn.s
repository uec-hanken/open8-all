.ORG DSPKEY_FUNC_BLOCK

;------------------------------------------------------------------------------
; dspkey_init: Sets up any variables or hardware required for the
;               display/keyboard

DSPKEY_INIT:  CLR  R0
              STA  R0, Ints.SDLC_Flag
              STA  R0, UART.RX_Mesg_Len
              STA  R0, DspKey.Button_Val
              STA  R0, DspKey.Btn1_Pressed
              STA  R0, DspKey.Btn2_Pressed
              STA  R0, DspKey.Btn3_Pressed

              LDI  R0, #$20
              LDI  R1, #$10
              LDA  R2, RX_BUFFER_PTR + 0
              LDA  R3, RX_BUFFER_PTR + 1
              LDA  R4, RX_MESG_PTR + 0
              LDA  R5, RX_MESG_PTR + 1

              LDI  R0, #$FF
              STA  R0, SDLC_TX_CTRL_STS

CLR_RX_LOOP:  STX  R2++
              STX  R4++
              DBNZ R1, CLR_RX_LOOP

              JSR  REQ_DUT_VER
              RTS
;-----------------------------------------------------------------------------

;-----------------------------------------------------------------------------
; dspkey_exec: Handles the SDLC attached keyboard and display

DSPKEY_EXEC:  LDA  R0, Ints.SDLC_Flag
              BRZ  _CHK_TMR

              CLR  R0
              STA  R0, Ints.SDLC_Flag

; Check to see if any of the buttons on the SDLC attached keyboard/display were
;  pressed based on the incoming message

              LDA  R0, SDLC_RX_BUFFER
              STA  R0, DspKey.Button_Val

_CHK_BTN1:    LDI  R1, #$01
              AND  R1
              BRZ  _BTN1_UP

_BTN1_DN:     LDA  R0, DspKey.Btn1_Pressed
              BNZ  _CHK_BTN2

              LDI  R0, #SEMAPHORE_VAL
              STA  R0, DspKey.Btn1_Pressed

              STA  R0, Ints.VEC_Flag

              CLR  R0
              STA  R0, Ints.VEC_Index

              CLR  R0
              BRZ  _CHK_BTN2

_BTN1_UP:     CLR  R0
              STA  R0, DspKey.Btn1_Pressed

_CHK_BTN2:    LDA  R0, DspKey.Button_Val
              LDI  R1, #$02
              AND  R1
              BRZ  _BTN2_UP

_BTN2_DN:     LDA  R0, DspKey.Btn2_Pressed
              BNZ  _CHK_BTN3

              LDI  R0, #SEMAPHORE_VAL
              STA  R0, DspKey.Btn2_Pressed

              STA  R0, Ints.VEC_Flag

              LDI  R0, #$01
              STA  R0, Ints.VEC_Index

              CLR  R0
              BRZ  _CHK_BTN3

_BTN2_UP:     CLR  R0
              STA  R0, DspKey.Btn2_Pressed

_CHK_BTN3:    LDA  R0, DspKey.Button_Val
              LDI  R1, #$04
              AND  R1
              BRZ  _BTN3_UP

_BTN3_DN:     LDA  R0, DspKey.Btn3_Pressed
              BNZ  _CHK_TMR

              LDI  R0, #SEMAPHORE_VAL
              STA  R0, DspKey.Btn3_Pressed

              STA  R0, Ints.VEC_Flag

              LDI  R0, #$02
              STA  R0, Ints.VEC_Index

              CLR  R0
              BRZ  _CHK_TMR

_BTN3_UP:     CLR  R0
              STA  R0, DspKey.Btn3_Pressed

_CHK_TMR:     LDA  R0, Ints.RTC_Flag1
              BRZ  _CHK_SER

              CLR  R0
              STA  R0, Ints.RTC_Flag1

              LDI  R0, #SEMAPHORE_VAL
              STA  R0, UART.RX_Flag
              BNZ  _GETBYTES

_CHK_SER:     CLR  R0
              STA  R0, UART.RX_Flag

; Retrieve any message from the serial UART and store them in a RX buffer

_GETBYTES:    LDA R2, RX_BUFFER_PTR    ; Setup the initial pointer into the RX buffer
              LDA R3, RX_BUFFER_PTR + 1

              LDA R0, UART.RX_Mesg_Len; Add the current offset to it
              ADD R2
              T0X R2
              CLR R0
              ADC R3
              T0X R3

_GB_CHKEMPTY: LDA R0, UART_STATUS
              LDI R1, #UART_RX_EMPTY_BIT
              AND R1
              BNZ _GB_EXIT

              LDA R0, UART.RX_Mesg_Len; increment the message len variable
              INC R0
              STA R0, UART.RX_Mesg_Len

              LDI R1, #$10             ; Check to see if we have exceeded the length
              CMP R1                   ; Ignore data if we would overrun the buffer
              BNN _GB_CHKTERM          ; but keep flushing the FIFO and check for term

              LDA R0, UART_DATA        ; Otherwise, write out the current character
              STX R2++

_GB_CHKTERM:  LDI R1,#$0D              ; Check to see if it is 0x0D (term)
              XOR R1
              BNZ _GB_CHKEMPTY

_GB_RSTCNTR:  LDA R2, RX_MESG_PTR      ; Setup the initial pointer into the RX message
              LDA R3, RX_MESG_PTR + 1

              LDA R4, RX_BUFFER_PTR    ; Setup the initial pointer into the RX buffer
              LDA R5, RX_BUFFER_PTR + 1

              LDA R1, UART.RX_Mesg_Len
_GB_COPY:     LDX R4++
              STX R2++
              DBNZ R1, _GB_COPY

              LDA R1, UART.RX_Mesg_Len
              LDI R0, #$11
              CLP PSR_C
              SBC R1
              T0X R1

              LDI R0, #$20
_GB_FLUSH:    STX R2++
              DBNZ R1, _GB_FLUSH

              CLR R0
              STA R0, UART.RX_Mesg_Len

              LDI R0, #SEMAPHORE_VAL
              STA R0, UART.RX_Flag

              BNZ  _GB_CHKEMPTY

_GB_EXIT:     LDA  R0, UART.RX_Flag
              BNZ  UPD_DISP
              RTS

; Format the display memory
UPD_DISP:     STA R0, RTC_GET          ; Value doesn't matter, just the write

              LDA R2, LCD_BUFFER_PTR
              LDA R3, LCD_BUFFER_PTR + 1

              LDI R0,#$43
              STX R2++

              LDI R0,#$68
              STX R2++

              LDI R0,#$72
              STX R2++

              LDI R0,#$6f
              STX R2++

              LDI R0,#$6e
              STX R2++

              LDI R0,#$20
              STX R2++

              LDA R4, RTC_HOURS
              TX0 R4
              ROR R0
              ROR R0
              ROR R0
              ROR R0

              LDI R1, #$03
              AND R1
              LDI R1, #$30
              OR  R1
              STX R2++

              TX0 R4

              LDI R1, #$0F
              AND R1
              LDI R1, #$30
              OR  R1
              STX R2++

              LDI R0,#$3A
              STX R2++

              LDA R4, RTC_MINUTES
              TX0 R4
              ROR R0
              ROR R0
              ROR R0
              ROR R0

              LDI R1, #$07
              AND R1
              LDI R1, #$30
              OR  R1
              STX R2++

              TX0 R4

              LDI R1, #$0F
              AND R1
              LDI R1, #$30
              OR  R1
              STX R2++

              LDI R0,#$3A
              STX R2++

              LDA R4, RTC_SECONDS
              TX0 R4
              ROR R0
              ROR R0
              ROR R0
              ROR R0

              LDI R1, #$07
              AND R1
              LDI R1, #$30
              OR  R1
              STX R2++

              TX0 R4

              LDI R1, #$0F
              AND R1
              LDI R1, #$30
              OR  R1
              STX R2++

              LDI R0,#$2E
              STX R2++

              LDA R4, RTC_TENTHS
              TX0 R4
              ROR R0
              ROR R0
              ROR R0
              ROR R0

              LDI R1, #$07
              AND R1
              LDI R1, #$30
              OR  R1
              STX R2++

              LDI R1, #$18      ; Skip next 24 due to LCD memory addressing
              LDI R0, #$20
_FM_LOOP1:    STX R2++
              DBNZ R1, _FM_LOOP1

              LDA R4, RX_MESG_PTR ; Copy 16 bytes from the message buffer to the LCD buffer
              LDA R5, RX_MESG_PTR + 1

              LDI R1, #$10
_FN_LOOP2:    LDX R4++
              STX R2++
              DBNZ R1, _FN_LOOP2

              LDI R1, #$18      ; Skip last 24 due to LCD memory addressing
              LDI R0, #$20
_FM_LOOP3:    STX R2++
              DBNZ R1, _FM_LOOP3

; Push the display memory to the keyboard/display unit via the SDLC interface

              LDI R1, #$FF
_PM_CPY_CHK:  LDA R0, SDLC_TX_CTRL_STS
              XOR R1
              BNZ _PM_CPY_CHK

              LDA R2, SER_TX_BUFFER_PTR
              LDA R3, SER_TX_BUFFER_PTR + 1

              LDA R4, LCD_BUFFER_PTR
              LDA R5, LCD_BUFFER_PTR + 1

              LDI R1, #$50
_PM_CPY:      LDX R4++
              STX R2++
              DBNZ R1, _PM_CPY

_PM_CPY_TX:   LDI R0, #$50
              STA R0, SDLC_TX_CTRL_STS

              RTS
;-----------------------------------------------------------------------------