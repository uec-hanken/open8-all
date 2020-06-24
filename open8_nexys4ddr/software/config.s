;------------------------------------------------------------------------------
; Hardware Configuration Defines - these should match the constants defined in
;  the Open8_cfg.vhd file.
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; Note, this code requires the following build parameters in the Open8 CPU
;  core to function correctly:
;
; Allow_Stack_Address_Move => true  RSP may relocate/retrieve the SP->R1:R0
; Stack_Xfer_Flag          => PSR4  GP_PSR4 is used to write enable RSP
; Enable_Auto_Increment    => true  Indexed load/store instructions can use
;                                    auto-increment feature when Rn is odd
;                                    (or Rn++ is specified).
; BRK_Implements_WAI       => true  BRK is interpreted as a WAI
; Enable_NMI               => true  Interrupt 0 is not maskable
; Sequential_Interrupts    => true  ISRs are NOT interruptable
; RTI_Ignores_GP_Flags     => true  RTI restores only lower 4 ALU flags
;
; Further note - NOP is mapped to BRK in the assembler. Do NOT use NOP with
;  the BRK_Implements_WAI enabled, as the NOP will instead trigger WAI.
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; System Memory Map from Open8_cfg
.DEFINE RAM_Address          $0000     ; System RAM
.DEFINE ALU_Address          $1000     ; ALU16 coprocessor
.DEFINE RTC_Address          $1100     ; System Timer / RT Clock
.DEFINE ETC_Address          $1200     ; Epoch Timer/Alarm Clock
.DEFINE TMR_Address          $1400     ; PIT timer
.DEFINE SDLC_Address         $1800     ; LCD serial interface
.DEFINE LED_Address          $2000     ; LED Display
.DEFINE DSW_Address          $2100     ; Dip Switches
.DEFINE BTN_Address          $2200     ; Push Buttons
.DEFINE SER_Address          $2400     ; UART interface
.DEFINE MAX_Address          $2800     ; Max 7221 base address
.DEFINE VEC_Address          $3000     ; Vector RX base address
.DEFINE CHR_Address          $3100     ; Elapsed Time / Chronometer
.DEFINE ROM_Address          $8000     ; Application ROM
.DEFINE ISR_Start_Addr       $8FF0     ; ISR Vector Table
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; Variable/Stack Memory Size
.DEFINE RAM_Size             4096
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; System Interrupt Map

;  -- Hardware Interrupt map
;  0 = RTC_Interrupt  / General Purpose Timer (NMI)
;  1 = ETC_Interrupt  / Epoch Timer & Alarm clock
;  2 = TMR_Interrupt  / Timer 2
;  3 = ALU_Interrupt  / ALU16 Math Coprocessor
;  4 = RTC_Interrupt  / Decisecond interrupt from RTC
;  5 = SER_Interrupt  / Serial interface
;  6 = BTN_Interrupt  / Push button interface
;  7 = VEC_Interrupt  / Vector Request interface

.DEFINE PIT_INT              0
.DEFINE ETC_INT              1
.DEFINE TMR_INT              2
.DEFINE ALU_INT              3
.DEFINE RTC_INT              4
.DEFINE SER_INT              5
.DEFINE BTN_INT              6
.DEFINE VEC_INT              7
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; ROM Constants (these indicate where to place blocks of code/data in ROM)
;.DEFINE DSPKEY_FUNC_BLOCK    $8200 ; Start of display/keyboard functions
.DEFINE COUNTER_FUNC_BLOCK   $8200 ; Start of test counter functions
.DEFINE CHRONO_FUNC_BLOCK    $8400 ; Start of the hardware chrono functions
.DEFINE TEST_FUNC_BLOCK      $8600 ; Start of test functions
.DEFINE USER_FUNC_BLOCK      $8A00 ; Start of user functions
.DEFINE TIME_FN1_BLOCK       $8D00 ; Time values for function 1
.DEFINE TIME_FN2_BLOCK       $8D10 ; Time values for function 2
.DEFINE TIME_FN3_BLOCK       $8D20 ; Time values for function 3
.DEFINE JMP_TABLE_BLOCK      $8E00 ; Location of index function addresses
.DEFINE INDEX_PTR_BLOCK      $8E80 ; Location of pointer table in ROM
.DEFINE ISR_FUNC_BLOCK       $8EB0 ; ISR Function Start Address
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; Task initialization, switching time, and init/exec macros

.DEFINE DEFAULT_INTERVAL     $FA

; Warning! Do not redefine these to be too small, as they need to store a full
;  context, consisting of 8 bytes of registers, a flag, and a return address,
;  plus any return addresses for subroutine calls. 16 is the minimum safe
;  stack size given there is at least one guaranteed JSR in every task.

.DEFINE TASK0_STACK_SIZE     16
.DEFINE TASK1_STACK_SIZE     16
.DEFINE TASK2_STACK_SIZE     16
.DEFINE TASK3_STACK_SIZE     16
.DEFINE TASK4_STACK_SIZE     16

.DEFINE TASK0                $00
.DEFINE TASK1                $01
.DEFINE TASK2                $02
.DEFINE TASK3                $03
.DEFINE TASK4                $04

.MACRO  TASK0_INIT
              CLR  R0
              STA  R0, Ints.ETC_Flag
              STA  R0, Ints.TMR_Flag
              STA  R0, Ints.ALU_Flag
              STA  R0, Ints.RTC_Flag1
              STA  R0, Ints.RTC_Flag2
              STA  R0, Ints.SDLC_Flag
              STA  R0, Ints.BTN_Flag1
              STA  R0, Ints.BTN_Flag2
              STA  R0, Ints.VEC_Flag
.ENDM

; Logically OR any additional semaphores that should trigger the IDLE task to
;  exit early. The output of this block is the Z flag
.MACRO  TASK0_EXTERNAL_CHECK
              LDA  R1, Ints.ETC_Flag
              OR   R1

              LDA  R1, Ints.TMR_Flag
              OR   R1

              LDA  R1, Ints.ALU_Flag
              OR   R1

              LDA  R1, Ints.RTC_Flag1
              OR   R1

              LDA  R1, Ints.RTC_Flag2
              OR   R1

              LDA  R1, Ints.SDLC_Flag
              OR   R1

              LDA  R1, Ints.BTN_Flag1
              OR   R1

              LDA  R1, Ints.BTN_Flag2
              OR   R1

              LDA  R0, Ints.VEC_Flag
              OR   R1
.ENDM

.MACRO  TASK1_INIT
              JSR  TEST_INIT
.ENDM

.MACRO  TASK1_EXEC
              JSR  TEST_DISPATCH
.ENDM

.MACRO  TASK2_INIT
;              JSR  DSPKEY_INIT ; DISABLED
.ENDM

.MACRO  TASK2_EXEC
;              JSR  DSPKEY_EXEC ; DISABLED
.ENDM

.MACRO  TASK3_INIT
              JSR  COUNTER_INIT
.ENDM

.MACRO  TASK3_EXEC
              JSR  COUNTER_EXEC
.ENDM

.MACRO  TASK4_INIT
              JSR  RTC_PBRST_INI
.ENDM

.MACRO  TASK4_EXEC
              JSR  RTC_PBRST_CLR
.ENDM
;------------------------------------------------------------------------------
