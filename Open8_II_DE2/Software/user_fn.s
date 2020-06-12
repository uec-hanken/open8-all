;------------------------------------------------------------------------------
; Utility functions for hardware abstraction
;
; REQ_DUT_VER  - Sends a requests for the DUT version via the UART
; REQ_DUT_QRY  - Sends a requests for the DUT status via the UART
; SET_DUT_DTD  - Sends a time delay value to the DUT version via the UART
; SET_DUT_ARM  - Sends the enable timer command to the DUT version via the UART
; SET_DUT_SAFE - Sends the disable timer command to the DUT version via the UART
;
; GET_BYTES    - Gets any messages from the UART and formats them into a string
; BCD_CNTR     - Implements an 8-digit BCD counter
; FORMAT_MESG  - Formats the LCD display array
; PUSH_2_LCD   - Transmits the LCD display array to the SDLC serial engine
;
; UF_ETC_SET   - Sets the Epoch Timer Alarm clock
; UF_ETC_ARM   - Enables the Epoch Timer interrupt
; UF_ETC_SAFE  - Disables the Epoch Timer interrupt
;
; UF_PIT2_SET  - Sets the Aux PIT timer (timer 2)
; UF_PIT2_ARM  - Enables the Aux PIT timer 2 interrupt
; UF_PIT2_SAFE - Disables the Aux PIT timer 2 interrupt
;
; UF_ALU_EXEC  - Triggers a calculation on the o8_alu16 and waits for interrupt
;
; UF_DBG_INIT  - Initializes an external MAX7221 display driver
; UF_DGB_UPD   - Updates an external MAX7221 with diagnostic data
;
;------------------------------------------------------------------------------

.ORG USER_FUNC_BLOCK

;------------------------------------------------------------------------------
REQ_DUT_VER:  PSH R0

              LDI R0, #$56
              STA R0, UART_DATA

              LDI R0, #$0D
              STA R0, UART_DATA

              POP R0
              RTS
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
REQ_DUT_QRY:  PSH R0

              LDI R0, #$45
              STA R0, UART_DATA

              LDI R0, #$0D
              STA R0, UART_DATA

              POP R0
              RTS
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
SET_DUT_DTD:  PSH R0

              LDI R0, #$44
              STA R0, UART_DATA

              LDI R0, #$44
              STA R0, UART_DATA

              LDI R0, #$45
              STA R0, UART_DATA

              LDI R0, #$41
              STA R0, UART_DATA

              LDI R0, #$44
              STA R0, UART_DATA

              LDI R0, #$0D
              STA R0, UART_DATA

              POP R0
              RTS
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
SET_DUT_ARM:  PSH R0

              LDI R0, #$41
              STA R0, UART_DATA

              LDI R0, #$0D
              STA R0, UART_DATA

              POP R0
              RTS
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
SET_DUT_SAFE: PSH R0

              LDI R0, #$53
              STA R0, UART_DATA

              LDI R0, #$0D
              STA R0, UART_DATA

              POP R0
              RTS
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; Epoch Timer controls - used to set or reset the hardware Epoch Timer system
;  UF_ETC_ASET takes a single variable, Epoch.Index, which is used to compute
;  an index into the time table, and programs an alarm value into the timer.
;  UF_ETC_ARM sets the epoch timer interrupt enable bit
;  UF_ETC_SAFE clears the epoch timer interrupt enable bit
;------------------------------------------------------------------------------
UF_ETC_SET:   PSH  R0
              PSH  R1
              PSH  R2
              PSH  R3

              LDA  R2, Epoch.Table_Ptr_l ; Load R3:R2 with starting address for
              LDA  R3, Epoch.Table_Ptr_h ;  the selected time value table
              LDA  R0, Epoch.Index       ; Load the index value, and multiply by
              LDI  R1, #ETC_ENTRY_LEN    ;  field length of each entry
              MUL  R1                    ; R1 * R0 -> R1:R0
                                         ; Add R3:R2 + R1:R0 -> R3:R2
              ADD  R2                    ; R2 + R0 > R0, set C
              T0X  R2                    ; R0 -> R2
              TX0  R1                    ; R1 -> R0
              ADC  R3                    ; R3 + R3 + C -> R0
              T0X  R3                    ; R0 -> R3

              LDX  R2++
              STA  R0, ETC_SETPT_B3
              LDX  R2++
              STA  R0, ETC_SETPT_B2
              LDX  R2++
              STA  R0, ETC_SETPT_B1
              LDX  R2
              STA  R0, ETC_SETPT_B0

; This is a write-only register where the data isn't used. The write itself
;  triggers the timer clear
              STA  R0, ETC_CTRL_STS

              POP  R3
              POP  R2
              POP  R1
              POP  R0
              RTS

UF_ETC_ARM:   PSH  R0
              PSH  R1

              GMSK
              LDI  R1, #ETC_INT_EN_BIT
              OR   R1
              SMSK

              POP  R1
              POP  R0
              RTS

UF_ETC_SAFE:  PSH  R0
              PSH  R1

              GMSK
              LDI  R1, #ETC_INT_EN_MASK
              AND  R1
              SMSK

              POP  R1
              POP  R0
              RTS
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; Aux PIT Timer functions
;------------------------------------------------------------------------------

UF_SET_PIT2: PSH R0

             LDA R0, Pit2.Interval_B0
             STA R0, INTERVAL_B0

             LDA R0, Pit2.Interval_B1
             STA R0, INTERVAL_B1

             LDA R0, Pit2.Interval_B2
             STA R0, INTERVAL_B2

             LDA R0, TIMER_CTRL
             LDI R1, #TIMER_UPDATE_BIT
             OR  R1
             STA R0, TIMER_CTRL

             POP R0
             RTS

UF_EN_PIT2:  PSH R0

             LDI R0, #TIMER_ENABLE_BIT
             STA R0, TIMER_CTRL

             POP R0
             RTS

UF_DIS_PIT2: PSH R0

             CLR R0
             STA R0, TIMER_CTRL

             POP R0
             RTS
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; ALU16 Execute Subroutine - handles starting the ALU and waiting for the calc
;  to finish using the ALU/MATH16 interrupt and semaphore
;------------------------------------------------------------------------------

UF_ALU_EXEC:  PSH  R0
              PSH  R1

              GMSK                     ; Enable the ALU interrupt
              LDI  R1, #ALU_INT_EN_BIT
              OR   R1
              SMSK

              CLR  R0
              STA  R0, Ints.ALU_Flag   ; Reset the ALU semaphore
              STA  R0, ALU16_STATUS    ; Write to the ALU16_STATUS register

_ALU_WAIT:    WAI                      ; Halt the processor waiting for out
              LDA  R0, Ints.ALU_Flag   ;  ALU semaphore
              BRZ  _ALU_WAIT

              GMSK                     ; Disable the ALU interrupt
              LDI  R1, #ALU_INT_EN_MASK
              AND  R1
              SMSK

              POP  R1
              POP  R0
              RTS
;------------------------------------------------------------------------------