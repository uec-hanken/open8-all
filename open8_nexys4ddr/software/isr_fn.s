;------------------------------------------------------------------------------
;  Interrupt Service Routines
;------------------------------------------------------------------------------

.ORG ISR_FUNC_BLOCK

;------------------------------------------------------------------------------
;  PIT Timer (programmable) Task Selector
;------------------------------------------------------------------------------
INTR0:        PSH R0
              PSH R1
              PSH R2
              PSH R3
              PSH R4
              PSH R5
              PSH R6
              PSH R7

              CLP PSR_GP7

              RETRIEVE_SP              ; Retrieve the SP -> R1:R0
              T0X R2                   ; Copy R1:R0 -> R3:R2 so that
              TX0 R1                   ; R0 and R1 can be reused
              T0X R3

_I0_CUR_TASK: LDA R1, TaskMgr.This_Task; Get the current task number

              LDI R0, #TASK1           ; Check to see if it is task 1-4
              XOR R1                   ;  and if so, jump to its sleep label
              BRZ _I0_SLP_TASK1

              LDI R0, #TASK2
              XOR R1
              BRZ _I0_SLP_TASK2

              LDI R0, #TASK3
              XOR R1
              BRZ _I0_SLP_TASK3

              LDI R0, #TASK4
              XOR R1
              BRZ _I0_SLP_TASK4

              ; Fall into _I0_SLP_IDLE

_I0_SLP_IDLE: STA R2, TaskMgr.Task0_SP_l
              STA R3, TaskMgr.Task0_SP_h
              BNGP7 _I0_NEXT_TASK

_I0_SLP_TASK1:STA R2, TaskMgr.Task1_SP_l
              STA R3, TaskMgr.Task1_SP_h
              BNGP7 _I0_NEXT_TASK

_I0_SLP_TASK2:STA R2, TaskMgr.Task2_SP_l
              STA R3, TaskMgr.Task2_SP_h
              BNGP7 _I0_NEXT_TASK

_I0_SLP_TASK3:STA R2, TaskMgr.Task3_SP_l
              STA R3, TaskMgr.Task3_SP_h
              BNGP7 _I0_NEXT_TASK

_I0_SLP_TASK4:STA R2, TaskMgr.Task4_SP_l
              STA R3, TaskMgr.Task4_SP_h
              ; Fall into _I0_NEXT_TASK

_I0_NEXT_TASK:LDA R1, TaskMgr.Next_Task ; Load the next task number

              LDI R0, #TASK1            ; Check to see if it is task 1-4
              XOR R1                    ;  and if so, jump to its wake label
              BRZ _I0_WK_TASK1

              LDI R0, #TASK2
              XOR R1
              BRZ _I0_WK_TASK2

              LDI R0, #TASK3
              XOR R1
              BRZ _I0_WK_TASK3

              LDI R0, #TASK4
              XOR R1
              BRZ _I0_WK_TASK4

              ; Fall into _I0_WK_IDLE

_I0_WK_IDLE:  LDA R0, TaskMgr.Task0_SP_l
              LDA R1, TaskMgr.Task0_SP_h

              LDI R2, #TASK0
              STA R2, TaskMgr.This_Task

              LDI R2, #TASK1
              STA R2, TaskMgr.Next_Task

              BNGP7 _I0_EXIT

_I0_WK_TASK1: LDA R0, TaskMgr.Task1_SP_l
              LDA R1, TaskMgr.Task1_SP_h

              LDI R2, #TASK1
              STA R2, TaskMgr.This_Task

              LDI R2, #TASK2
              STA R2, TaskMgr.Next_Task

              BNGP7 _I0_EXIT

_I0_WK_TASK2: LDA R0, TaskMgr.Task2_SP_l
              LDA R1, TaskMgr.Task2_SP_h

              LDI R2, #TASK2
              STA R2, TaskMgr.This_Task

              LDI R2, #TASK3
              STA R2, TaskMgr.Next_Task

              BNGP7 _I0_EXIT

_I0_WK_TASK3: LDA R0, TaskMgr.Task3_SP_l
              LDA R1, TaskMgr.Task3_SP_h

              LDI R2, #TASK3
              STA R2, TaskMgr.This_Task

              LDI R2, #TASK4
              STA R2, TaskMgr.Next_Task

              BNGP7 _I0_EXIT

_I0_WK_TASK4: LDA R0, TaskMgr.Task4_SP_l
              LDA R1, TaskMgr.Task4_SP_h

              LDI R2, #TASK4
              STA R2, TaskMgr.This_Task

              LDI R2, #TASK0
              STA R2, TaskMgr.Next_Task

              ; Fall into _I0_EXIT

_I0_EXIT:      RELOCATE_SP              ; Push R1:R0 -> SP

              LDI R0, #DEFAULT_INTERVAL
              STA R0, RTC_PIT

              POP R7
              POP R6
              POP R5
              POP R4
              POP R3
              POP R2
              POP R1
              POP R0
              RTI

;------------------------------------------------------------------------------
;  Epoch Timer (Test stimulus control)
;------------------------------------------------------------------------------

INTR1:        PSH R0

              LDI R0, #$01       ; Set the PIT timer to 0x01 in order to force
              STA R0, RTC_PIT    ;  the task switch ASAP (do NOT set to 0x00!)

              LDI R0, #TASK1           ; Insert the STIM task as the NEXT_TASK
              STA R0, TaskMgr.Next_Task

              LDI R0, #SEMAPHORE_VAL   ; Set the ETC semaphore flag
              STA R0, Ints.ETC_Flag

              POP R0
              RTI

;------------------------------------------------------------------------------
;  Aux Task Timer (Timer2)
;------------------------------------------------------------------------------
INTR2:        PSH R0

              LDI R0, #SEMAPHORE_VAL
              STA R0, Ints.TMR_Flag

              POP R0
              RTI

;------------------------------------------------------------------------------
;  ALU Done
;------------------------------------------------------------------------------
INTR3:        PSH R0

              LDI R0, #SEMAPHORE_VAL
              STA R0, Ints.ALU_Flag

              POP R0
              RTI

;------------------------------------------------------------------------------
;  RTC Timer (Fixed 10mS)
;------------------------------------------------------------------------------
INTR4:        PSH R0

              LDI R0, #SEMAPHORE_VAL
              STA R0, Ints.RTC_Flag1
              STA R0, Ints.RTC_Flag2

              POP R0
              RTI

;------------------------------------------------------------------------------
;  SDLC Receiver
;------------------------------------------------------------------------------
INTR5:        PSH R0

              LDI R0, #SEMAPHORE_VAL
              STA R0, Ints.SDLC_Flag

              POP R0
              RTI

;------------------------------------------------------------------------------
;  Pushbutton
;------------------------------------------------------------------------------
INTR6:        PSH R0

              LDI R0, #SEMAPHORE_VAL
              STA R0, Ints.BTN_Flag1
              STA R0, Ints.BTN_Flag2

              POP R0
              RTI

;------------------------------------------------------------------------------
;  Vector Request
;------------------------------------------------------------------------------
INTR7:        PSH R0

              LDA R0, VECTOR_SEL
              STA R0, Ints.VEC_Index

              LDA R0, VECTOR_ARG_LB
              STA R0, Ints.VEC_Arg_l

              LDA R0, VECTOR_ARG_UB
              STA R0, Ints.VEC_Arg_h

              LDI R0, #SEMAPHORE_VAL
              STA R0, Ints.VEC_Flag

              POP R0
              RTI
