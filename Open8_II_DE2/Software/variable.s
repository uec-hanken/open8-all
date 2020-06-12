;------------------------------------------------------------------------------
;  Memory structures and Variable Organization
;------------------------------------------------------------------------------

; Variable    Size      Description
; --------    ----      -------------------------------------------------------

.STRUCT str_isr_flags
ETC_Flag      DB
TMR_Flag      DB
ALU_Flag      DB
RTC_Flag1     DB
RTC_Flag2     DB
SDLC_Flag     DB
BTN_Flag1     DB
BTN_Flag2     DB
VEC_Flag      DB
VEC_Index     DB
VEC_Arg_l     DB
VEC_Arg_h     DB
.ENDST

.STRUCT str_taskman
This_Task     DB
Next_Task     DB
Task0_SP_l    DB
Task0_SP_h    DB
Task1_SP_l    DB
Task1_SP_h    DB
Task2_SP_l    DB
Task2_SP_h    DB
Task3_SP_l    DB
Task3_SP_h    DB
Task4_SP_l    DB
Task4_SP_h    DB
Task1_Busy    DB
Task2_Busy    DB
Task3_Busy    DB
Task4_Busy    DB
.ENDST

; Test Stimulus
.STRUCT str_test
Retval        DB
Step          DB
.ENDST

; Display/Keyboard
.STRUCT str_dsky
Button_Val    DB
LCD_Buffer    DSB 80
Btn1_Pressed  DB
Btn2_Pressed  DB
Btn3_Pressed  DB
.ENDST

; Test Counter
.STRUCT str_counter
Enable        DB
Reset         DB
Value         DSB 7
.ENDST

; Serial UART
.STRUCT str_uart
RX_Flag       DB
RX_Mesg_Len   DB
RX_Buffer     DSB 16
RX_Mesg       DSB 16
.ENDST

; Aux PIT Timer
.STRUCT str_pit2
Interval_B0   DB
Interval_B1   DB
Interval_B2   DB
.ENDST

; Epoch Timer
.STRUCT str_epoch
Index         DB
Table_Ptr_l   DB
Table_Ptr_h   DB
.ENDST

; Allocate the variable structures in memory
.ENUM RAM_Address
Ints          INSTANCEOF str_isr_flags
TaskMgr       INSTANCEOF str_taskman
Test          INSTANCEOF str_test
DspKey        INSTANCEOF str_dsky
Counter       INSTANCEOF str_counter
UART          INSTANCEOF str_uart
Pit2          INSTANCEOF str_pit2
Epoch         INSTANCEOF str_epoch
.ENDE

;------------------------------------------------------------------------------