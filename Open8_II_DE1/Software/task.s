;------------------------------------------------------------------------------
; Program Start and Task Setup
;
; Note that the task init and exec functions are set in constant.s by macros
;------------------------------------------------------------------------------

.ORG ROM_Address
INIT:         CLR  R0
              SMSK                        ; Disable all interrupts and make
              STA  R0, RTC_PIT            ;  sure the PIT is disabled for now
INFINITE:     
              ; Turn on some leds
              CLR  R0
              STA  R0, LED_CONTROL
              DEC  R0
              STA  R0, LED_CONTROL
              JMP INFINITE
			  
TASK0_SETUP:  LDA  R0, TASK0_STACK_PTR + 0; Repoint to task0's initial
              LDA  R1, TASK0_STACK_PTR + 1; stack location
              RELOCATE_SP                 ; Push R1:R0 -> TASK0_SP

              CLR  R0                     ; Write initial flag value
              PSH  R0

              LDA  R0, TASK0_INIT_PTR + 1 ; Write return PC MSB
              PSH  R0

              LDA  R0, TASK0_INIT_PTR + 0 ; Write return PC LSB
              PSH  R0

              RETRIEVE_SP                 ; Copy SP -> R1:R0
              STA  R0, TaskMgr.Task0_SP_l ; Store the new task 0 SP to
              STA  R1, TaskMgr.Task0_SP_h ;  its TASK0_SP variable

TASK1_SETUP:  LDA  R0, TASK1_STACK_PTR + 0; Configure the task 2's SP
              LDA  R1, TASK1_STACK_PTR + 1
              RELOCATE_SP                 ; Push R1:R0 -> TASK0_SP

              CLR  R0                     ; Write initial operands
              PSH  R0                     ; Write initial flags

              LDA  R0, TASK1_INIT_PTR + 1 ; Write return PC MSB
              PSH  R0

              LDA  R0, TASK1_INIT_PTR + 0 ; Write return PC LSB
              PSH  R0

              CLR  R0
              PSH  R0                     ; R0
              PSH  R0                     ; R1
              PSH  R0                     ; R2
              PSH  R0                     ; R3
              PSH  R0                     ; R4
              PSH  R0                     ; R5
              PSH  R0                     ; R6
              PSH  R0                     ; R7

              RETRIEVE_SP                 ; Copy SP -> R1:R0
              STA  R0, TaskMgr.Task1_SP_l ; Store the new task 2 SP to
              STA  R1, TaskMgr.Task1_SP_h ;  its TASK2_SP variable

TASK2_SETUP:  LDA  R0, TASK2_STACK_PTR + 0; Configure the task 1's SP
              LDA  R1, TASK2_STACK_PTR + 1
              RELOCATE_SP                 ; Push R1:R0 -> TASK0_SP

              CLR  R0                     ; Write initial operands
              PSH  R0                     ; Write initial flags

              LDA  R0, TASK2_INIT_PTR + 1 ; Write return PC MSB
              PSH  R0

              LDA  R0, TASK2_INIT_PTR + 0 ; Write return PC LSB
              PSH  R0

              CLR  R0
              PSH  R0                     ; R0
              PSH  R0                     ; R1
              PSH  R0                     ; R2
              PSH  R0                     ; R3
              PSH  R0                     ; R4
              PSH  R0                     ; R5
              PSH  R0                     ; R6
              PSH  R0                     ; R7

              RETRIEVE_SP                 ; Copy SP -> R1:R0
              STA  R0, TaskMgr.Task2_SP_l ; Store the new task 1 SP to
              STA  R1, TaskMgr.Task2_SP_h ;  its TASK2_SP variable

TASK3_SETUP:  LDA  R0, TASK3_STACK_PTR + 0; Configure the task 3's SP
              LDA  R1, TASK3_STACK_PTR + 1
              RELOCATE_SP                 ; Push R1:R0 -> TASK0_SP

              CLR  R0                     ; Write initial operands
              PSH  R0                     ; Write initial flags

              LDA  R0, TASK3_INIT_PTR + 1 ; Write return PC MSB
              PSH  R0

              LDA  R0, TASK3_INIT_PTR + 0 ; Write return PC LSB
              PSH  R0

              CLR  R0
              PSH  R0                     ; R0
              PSH  R0                     ; R1
              PSH  R0                     ; R2
              PSH  R0                     ; R3
              PSH  R0                     ; R4
              PSH  R0                     ; R5
              PSH  R0                     ; R6
              PSH  R0                     ; R7

              RETRIEVE_SP                 ; Copy SP -> R1:R0
              STA  R0, TaskMgr.Task3_SP_l ; Store the new task 3 SP to
              STA  R1, TaskMgr.Task3_SP_h ;  its TASK2_SP variable

TASK4_SETUP:  LDA  R0, TASK4_STACK_PTR + 0; Configure the task 4's SP
              LDA  R1, TASK4_STACK_PTR + 1
              RELOCATE_SP                 ; Push R1:R0 -> TASK0_SP

              CLR  R0                     ; Write initial operands
              PSH  R0                     ; Write initial flags

              LDA  R0, TASK4_INIT_PTR + 1 ; Write return PC MSB
              PSH  R0

              LDA  R0, TASK4_INIT_PTR + 0 ; Write return PC LSB
              PSH  R0

              CLR  R0
              PSH  R0                     ; R0
              PSH  R0                     ; R1
              PSH  R0                     ; R2
              PSH  R0                     ; R3
              PSH  R0                     ; R4
              PSH  R0                     ; R5
              PSH  R0                     ; R6
              PSH  R0                     ; R7

              RETRIEVE_SP                 ; Copy SP -> R1:R0
              STA  R0, TaskMgr.Task4_SP_l ; Store the new task 4 SP to
              STA  R1, TaskMgr.Task4_SP_h ;  its TASK2_SP variable

INIT_WRAPUP:  CLR  R0                     ; Initialize the registers
              T0X  R1
              T0X  R2
              T0X  R3
              T0X  R4
              T0X  R5
              T0X  R6
              T0X  R7
              STA  R0, TaskMgr.This_Task  ; Init the task variable to TASK2

              LDA  R0, TaskMgr.Task0_SP_l ; Go back and load R1:R0 with the
              LDA  R1, TaskMgr.Task0_SP_h ; correct SP for task 0
              RELOCATE_SP                 ; Restore R1:R0 -> SP

              LDI  R0, #IDLE_INTMASK      ; Turn on the rest of the interrupts
              SMSK

              LDI  R0, #DEFAULT_INTERVAL  ; Turn on the PIT timer at this point
              STA  R0, RTC_PIT            ;  to kick off the task switcher

; The last bit of code should mirror the final steps of the INTR0 ISR, which
;  implies that we should use RTI rather than RTS to kick off the first task
              RTI
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; Task 0 (the idle task)
;------------------------------------------------------------------------------

TASK0_INIT:   TASK0_INIT

_TASK0_LOOP:  STP  PSR_GP7

; Check for any premature exit conditions by logically OR'ing their semaphore
;  flags to the accumulator
              CLR  R0

              LDA  R1, TaskMgr.Task1_Busy
              OR   R1

              LDA  R1, TaskMgr.Task2_Busy
              OR   R1

              LDA  R1, TaskMgr.Task3_Busy
              OR   R1

              LDA  R1, TaskMgr.Task4_Busy
              OR   R1

              TASK0_EXTERNAL_CHECK

              BNZ  _TASK0_ABORT

; If we are still in IDLE, kick off a WAI and put the bus to sleep until an
;  interrupt wakes up the CPU.
_TASK0_PAUSE: WAI
              JMP  _TASK0_LOOP

_TASK0_ABORT: INT 0
              JMP  _TASK0_LOOP

;------------------------------------------------------------------------------
; Task 1
;----------------- -------------------------------------------------------------
TASK1_INIT:   CLR  R0
              STA  R0, TaskMgr.Task1_Busy

              TASK1_INIT

_TASK1_LOOP:  INT  0

              LDI  R0, #SEMAPHORE_VAL
              STA  R0, TaskMgr.Task1_Busy

              TASK1_EXEC

              CLR  R0
              STA  R0, TaskMgr.Task1_Busy

              JMP  _TASK1_LOOP
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; Task 2
;------------------------------------------------------------------------------
TASK2_INIT:   CLR  R0
              STA  R0, TaskMgr.Task2_Busy

              TASK2_INIT

_TASK2_LOOP:  INT  0

              LDI  R0, #SEMAPHORE_VAL
              STA  R0, TaskMgr.Task2_Busy

              TASK2_EXEC

              CLR  R0
              STA  R0, TaskMgr.Task2_Busy

              JMP  _TASK2_LOOP
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; Task 3
;------------------------------------------------------------------------------
TASK3_INIT:   CLR  R0
              STA  R0, TaskMgr.Task3_Busy

              TASK3_INIT

_TASK3_LOOP:  INT  0

              LDI  R0, #SEMAPHORE_VAL
              STA  R0, TaskMgr.Task3_Busy

              TASK3_EXEC

              CLR  R0
              STA  R0, TaskMgr.Task3_Busy

              JMP  _TASK3_LOOP
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; Task 4
;------------------------------------------------------------------------------
TASK4_INIT:   CLR  R0
              STA  R0, TaskMgr.Task4_Busy

              TASK4_INIT

_TASK4_LOOP:  INT  0

              LDI  R0, #SEMAPHORE_VAL
              STA  R0, TaskMgr.Task4_Busy

              TASK4_EXEC

              CLR  R0
              STA  R0, TaskMgr.Task4_Busy

              JMP  _TASK4_LOOP
_;------------------------------------------------------------------------------