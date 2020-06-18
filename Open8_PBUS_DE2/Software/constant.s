;------------------------------------------------------------------------------
; Defined constants & Tables
; This is where local constants are copied from hardware API definitions or are
;  computed from values in config.s. Once built, this file shouldn't changed
;  unless the hardware is added/removed or functionality is significantly
;  altered.
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; Semaphore Value - should always be non-zero
.DEFINE SEMAPHORE_VAL        $FF       ; Standard value used to set semaphores
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; Stack pointer calculations
.DEFINE RAM_END_ADDR         RAM_Address + RAM_Size - 1

.DEFINE TASK0_STACK_START    RAM_END_ADDR
.DEFINE TASK1_STACK_START    TASK0_STACK_START - TASK0_STACK_SIZE
.DEFINE TASK2_STACK_START    TASK1_STACK_START - TASK1_STACK_SIZE
.DEFINE TASK3_STACK_START    TASK2_STACK_START - TASK2_STACK_SIZE
.DEFINE TASK4_STACK_START    TASK3_STACK_START - TASK3_STACK_SIZE
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; Interrupt bit & mask definitions
.DEFINE PIT_INT_EN_BIT       2^PIT_INT
.DEFINE PIT_INT_EN_MASK      PIT_INT_EN_BIT ~ $FF

.DEFINE ETC_INT_EN_BIT       2^ETC_INT
.DEFINE ETC_INT_EN_MASK      ETC_INT_EN_BIT ~ $FF

.DEFINE TMR_INT_EN_BIT       2^TMR_INT
.DEFINE TMR_INT_EN_MASK      TMR_INT_EN_BIT ~ $FF

.DEFINE ALU_INT_EN_BIT       2^ALU_INT
.DEFINE ALU_INT_EN_MASK      ALU_INT_EN_BIT ~ $FF

.DEFINE RTC_INT_EN_BIT       2^RTC_INT
.DEFINE RTC_INT_EN_MASK      RTC_INT_EN_BIT ~ $FF

.DEFINE SER_INT_EN_BIT       2^SER_INT
.DEFINE SER_INT_EN_MASK      SER_INT_EN_BIT ~ $FF

.DEFINE BTN_INT_EN_BIT       2^BTN_INT
.DEFINE BTN_INT_EN_MASK      BTN_INT_EN_BIT ~ $FF

.DEFINE VEC_INT_EN_BIT       2^VEC_INT
.DEFINE VEC_INT_EN_MASK      VEC_INT_EN_BIT ~ $FF

.DEFINE IDLE_INTMASK         RTC_INT_EN_BIT | SER_INT_EN_BIT | BTN_INT_EN_BIT | VEC_INT_EN_BIT
;------------------------------------------------------------------------------

;-----------------------------------------------------------------------------
; ALU16 (16-bit Math Co-processor)
.DEFINE ALU16_REG0           ALU_Address + 0  ; (offset 0)
.DEFINE ALU16_REG1           ALU_Address + 2  ; (offset 2)
.DEFINE ALU16_REG2           ALU_Address + 4  ; (offset 4)
.DEFINE ALU16_REG3           ALU_Address + 6  ; (offset 6)
.DEFINE ALU16_REG4           ALU_Address + 8  ; (offset 8)
.DEFINE ALU16_REG5           ALU_Address + 10 ; (offset 10)
.DEFINE ALU16_REG6           ALU_Address + 12 ; (offset 12)
.DEFINE ALU16_REG7           ALU_Address + 14 ; (offset 14)
.DEFINE ALU16_TOLREG         ALU_Address + 28 ; (offset 28)
.DEFINE ALU16_STATUS         ALU_Address + 30 ; (offset 30)
.DEFINE ALU16_CONTROL        ALU_Address + 31 ; (offset 31)

; ALU Instruction (Opcode)   Mask
.DEFINE ALU_OP_T0X           $00   ; "0000 0xxx"
.DEFINE ALU_OP_TX0           $08   ; "0000 1xxx"
.DEFINE ALU_OP_CLR           $10   ; "0001 0xxx"
.DEFINE ALU_OP_IDIV          $18   ; "0001 1xxx"
.DEFINE ALU_OP_UMUL          $20   ; "0010 0xxx"
.DEFINE ALU_OP_UADD          $28   ; "0010 1xxx"
.DEFINE ALU_OP_UADC          $30   ; "0011 0xxx"
.DEFINE ALU_OP_USUB          $38   ; "0011 1xxx"
.DEFINE ALU_OP_USBC          $40   ; "0100 0xxx"
.DEFINE ALU_OP_UCMP          $48   ; "0100 1xxx"
.DEFINE ALU_OP_SMUL          $50   ; "0101 0xxx"
.DEFINE ALU_OP_SADD          $58   ; "0101 1xxx"
.DEFINE ALU_OP_SSUB          $60   ; "0110 0xxx"
.DEFINE ALU_OP_SCMP          $68   ; "0110 1xxx"
.DEFINE ALU_OP_SMAG          $70   ; "0111 0xxx"
.DEFINE ALU_OP_SNEG          $78   ; "0111 1xxx"
.DEFINE ALU_OP_ACMP          $80   ; "1000 0xxx"
.DEFINE ALU_OP_SCRY          $88   ; "1000 1xxx"
.DEFINE ALU_OP_UDAB          $90   ; "1001 0xxx"
.DEFINE ALU_OP_SDAB          $98   ; "1001 1xxx"
.DEFINE ALU_OP_UDAW          $A0   ; "1010 0xxx"
.DEFINE ALU_OP_SDAW          $A8   ; "1010 1xxx"
.DEFINE ALU_OP_RSVD          $B0   ; "1011 0xxx"
.DEFINE ALU_OP_BSWP          $B8   ; "1011 1xxx"
.DEFINE ALU_OP_BOR           $C0   ; "1100 0xxx"
.DEFINE ALU_OP_BAND          $C8   ; "1100 1xxx"
.DEFINE ALU_OP_BXOR          $D0   ; "1101 0xxx"
.DEFINE ALU_OP_BINV          $D8   ; "1101 1xxx"
.DEFINE ALU_OP_BSFL          $E0   ; "1110 0xxx"
.DEFINE ALU_OP_BROL          $E8   ; "1110 1xxx"
.DEFINE ALU_OP_BSFR          $F0   ; "1111 0xxx"
.DEFINE ALU_OP_BROR          $F8   ; "1111 1xxx"

.DEFINE ALU_R0               0
.DEFINE ALU_R1               1
.DEFINE ALU_R2               2
.DEFINE ALU_R3               3
.DEFINE ALU_R4               4
.DEFINE ALU_R5               5
.DEFINE ALU_R6               6
.DEFINE ALU_R7               7

.DEFINE ALU_Z                $01
.DEFINE ALU_C                $02
.DEFINE ALU_N                $04
.DEFINE ALU_O                $08
.DEFINE ALU_BUSY             $80

; Register Map:
; Offset  Bitfield Description                        Read/Write
;   0x00   AAAAAAAA Register 0 ( 7:0)                  (RW)
;   0x01   AAAAAAAA Register 0 (15:8)                  (RW)
;   0x02   AAAAAAAA Register 1 ( 7:0)                  (RW)
;   0x03   AAAAAAAA Register 1 (15:8)                  (RW)
;   0x04   AAAAAAAA Register 2 ( 7:0)                  (RW)
;   0x05   AAAAAAAA Register 2 (15:8)                  (RW)
;   0x06   AAAAAAAA Register 3 ( 7:0)                  (RW)
;   0x07   AAAAAAAA Register 3 (15:8)                  (RW)
;   0x08   AAAAAAAA Register 4 ( 7:0)                  (RW)
;   0x09   AAAAAAAA Register 4 (15:8)                  (RW)
;   0x0A   AAAAAAAA Register 5 ( 7:0)                  (RW)
;   0x0B   AAAAAAAA Register 5 (15:8)                  (RW)
;   0x0C   AAAAAAAA Register 6 ( 7:0)                  (RW)
;   0x0D   AAAAAAAA Register 6 (15:8)                  (RW)
;   0x0E   AAAAAAAA Register 7 ( 7:0)                  (RW)
;   0x0F   AAAAAAAA Register 7 (15:8)                  (RW)
;   0x10   -------- Reserved                           (--)
;   0x11   -------- Reserved                           (--)
;   0x12   -------- Reserved                           (--)
;   0x13   -------- Reserved                           (--)
;   0x14   -------- Reserved                           (--)
;   0x15   -------- Reserved                           (--)
;   0x16   -------- Reserved                           (--)
;   0x17   -------- Reserved                           (--)
;   0x18   -------- Reserved                           (--)
;   0x19   -------- Reserved                           (--)
;   0x1A   -------- Reserved                           (--)
;   0x1B   -------- Reserved                           (--)
;   0x1C   AAAAAAAA Tolerance  ( 7:0)                  (RW)
;   0x1D   AAAAAAAA Tolerance  (15:8)                  (RW)
;   0x1E   BBBBBAAA Instruction Register               (RW)
;                   A = Operand (register select)
;                   B = Opcode  (instruction select)
;   0x1F   E---DCBA Status & Flags                     (RW)
;                   A = Zero Flag
;                   B = Carry Flag
;                   C = Negative Flag
;                   D = Overflow / Error Flag
;                   E = Busy Flag (1 = busy, 0 = idle)
;
; Instruction Map:
; OP_T0X  "0000 0xxx" : Transfer R0 to Rx    R0      -> Rx (Sets Z,N)
; OP_TX0  "0000 1xxx" : Transfer Rx to R0    Rx      -> R0 (Sets Z,N)
; OP_CLR  "0001 0xxx" : Set Rx to 0          0x00    -> Rx (Sets Z,N)
;
; OP_IDIV "0001 1xxx" : Integer Division     R0/Rx   -> Q:R0, R:Rx
;
; OP_UMUL "0010 0xxx" : Unsigned Multiply    R0*Rx   -> R1:R0 (Sets Z)
; OP_UADD "0010 1xxx" : Unsigned Addition    R0+Rx   -> R0 (Sets N,Z,C)
; OP_UADC "0011 0xxx" : Unsigned Add w/Carry R0+Rx+C -> R0 (Sets N,Z,C)
; OP_USUB "0011 1xxx" : Unsigned Subtraction R0-Rx   -> R0 (Sets N,Z,C)
; OP_USBC "0100 0xxx" : Unsigned Sub w/Carry R0-Rx-C -> R0 (Sets N,Z,C)
; OP_UCMP "0100 1xxx" : Unsigned Compare     R0-Rx - Sets N,Z,C only
;
; OP_SMUL "0101 0xxx" : Signed Multiply      R0*Rx   -> R1:R0 (Sets N,Z)
; OP_SADD "0101 1xxx" : Signed Addition      R0+Rx   -> R0 (Sets N,Z,O)
; OP_SSUB "0110 0xxx" : Signed Subtraction   R0-Rx   -> R0 (Sets N,Z,O)
; OP_SCMP "0110 1xxx" : Signed Compare       R0-Rx - Sets N,Z,O only
; OP_SMAG "0111 0xxx" : Signed Magnitude     |Rx|    -> R0 (Sets Z,O)
; OP_SNEG "0111 1xxx" : Signed Negation      -Rx     -> R0 (Sets N,Z,O)
;
; OP_ACMP "1000 0xxx" : Signed Almost Equal (see description)
; OP_SCRY "1000 1---" : Set the carry bit   (ignores operand)
;
; OP_UDAB "1001 0xxx" : Decimal Adjust Byte (see description)
; OP_SDAB "1001 1xxx" : Decimal Adjust Byte (see description)
; OP_UDAW "1010 0xxx" : Decimal Adjust Word (see description)
; OP_SDAW "1010 1xxx" : Decimal Adjust Word (see description)
;
; OP_RSVD "1011 0---" : Reserved
;
; OP_BSWP "1011 1xxx" : Byte Swap (Swaps upper and lower bytes)
;
; OP_BOR  "1100 0xxx" : Bitwise Logical OR   Rx or  R0 -> R0
; OP_BAND "1100 1xxx" : Bitwise Logical AND  Rx and R0 -> R0
; OP_BXOR "1101 0xxx" : Bitwise Logical XOR  Rx xor R0 -> R0
;
; OP_BINV "1101 1xxx" : Bitwise logical NOT #Rx      -> Rx
; OP_BSFL "1110 0xxx" : Logical Shift Left   Rx<<1,0 -> Rx
; OP_BROL "1110 1xxx" : Logical Rotate Left  Rx<<1,C -> Rx,C
; OP_BSFR "1111 0xxx" : Logical Shift Right  0,Rx>>1 -> Rx
; OP_BROR "1111 1xxx" : Logical Rotate Right C,Rx>>1 -> Rx,C
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; RTC (Periodic Interval Timer (PIT) & Real Time Clock (RTC))
.DEFINE RTC_PIT              RTC_Address + 0 ; (PIT)
.DEFINE RTC_TENTHS           RTC_Address + 1 ; (RTC/10ths)
.DEFINE RTC_SECONDS          RTC_Address + 2 ; (RTC/Seconds)
.DEFINE RTC_MINUTES          RTC_Address + 3 ; (RTC/Minutes)
.DEFINE RTC_HOURS            RTC_Address + 4 ; (RTC/Hours)
.DEFINE RTC_DOW              RTC_Address + 5 ; (RTC/Day of Week)
.DEFINE RTC_SET              RTC_Address + 6 ; (Pull time from int regs)
.DEFINE RTC_GET              RTC_Address + 7 ; (Push time to int regs)

; Register Map:
; Offset  Bitfield Description                        Read/Write
;   0x0   AAAAAAAA Periodic Interval Timer in uS      (RW)
;   0x1   BBBBAAAA Tenths  (0x00 - 0x99)              (RW)
;   0x2   -BBBAAAA Seconds (0x00 - 0x59)              (RW)
;   0x3   -BBBAAAA Minutes (0x00 - 0x59)              (RW)
;   0x4   --BBAAAA Hours   (0x00 - 0x23)              (RW)
;   0x5   -----AAA Day of Week (0x00 - 0x06)          (RW)
;   0x6   -------- Update RTC regs from Shadow Regs   (WO)
;   0x7   A------- Update Shadow Regs from RTC regs   (RW)
;                  A = Update is Busy
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
;-- Epoch Timer II (Alarm Clock)
; Note that this version is a 32-bit, 1-uS resolution timer/comparator
.DEFINE ETC_SETPT_B0         ETC_Address + 0  ; RW
.DEFINE ETC_SETPT_B1         ETC_Address + 1  ; RW
.DEFINE ETC_SETPT_B2         ETC_Address + 2  ; RW
.DEFINE ETC_SETPT_B3         ETC_Address + 3  ; RW
.DEFINE ETC_EPOCH_B0         ETC_Address + 4  ; RW (trigger only on WR)
.DEFINE ETC_EPOCH_B1         ETC_Address + 5  ; RW (trigger only on WR)
.DEFINE ETC_EPOCH_B2         ETC_Address + 6  ; RW (trigger only on WR)
.DEFINE ETC_EPOCH_B3         ETC_Address + 7  ; RW (trigger only on WR)
.DEFINE ETC_RESET            ETC_Address + 14 ; WO (trigger only on WR)
.DEFINE ETC_CTRL_STS         ETC_Address + 15 ; RW (trigger only on WR)

.DEFINE ETC_ENTRY_LEN        $04

; Bitfield Description for ETC_CTRL_STS
; BA------ Primary waveform control
;          A = Buffer pending flag
;          B = Alarm State Flag
;
; (Any write to this register will both update the internal timer with the buffer
;  and clear the alarm flag)

; Note that writing to ANY of the ETC_EPOCH bytes will capture the current
;  time to an internal 32-bit buffer, allowing the time to be read without
;  pressure.
; Further, writing to ETC_RESET will trigger an internal reset of the
;  comparison timer, and should be written prior to using the alarm function
;
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; Sys Timer II (Aux PIT Timer)
.DEFINE INTERVAL_B0          TMR_Address + 0  ; RW
.DEFINE INTERVAL_B1          TMR_Address + 1  ; RW
.DEFINE INTERVAL_B2          TMR_Address + 2  ; RW
.DEFINE TIMER_CTRL           TMR_Address + 3  ; RW

.DEFINE TIMER_UPDATE_BIT     $40
.DEFINE TIMER_ENABLE_BIT     $80
.DEFINE TIMER_ENABLE_MASK    TIMER_ENABLE_BIT ~ $FF

; Register Map:
; Offset  Bitfield Description                        Read/Write
;   0x00  AAAAAAAA Req Interval Byte 0                   (RW)
;   0x01  AAAAAAAA Req Interval Byte 1                   (RW)
;   0x02  AAAAAAAA Req Interval Byte 2                   (RW)
;   0x03  BA------ Control/Status Register               (RW)
;                   A: Update timer (WR) or Update pending (RD)
;                   B: Output Enable
;
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
;-- LCD Display (SDLC attached)
.DEFINE SDLC_TX_BUFFER       SDLC_Address + 0
.DEFINE SDLC_TX_CTRL_STS     SDLC_Address + 255
.DEFINE SDLC_RX_BUFFER       SDLC_Address + 256
.DEFINE SDLC_RX_STATUS       SDLC_Address + 511
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
;-- LED Display
.DEFINE LED_CONTROL          LED_Address
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
;-- DIP Switches
.DEFINE DIPSWITCHES          DSW_Address
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
;-- Button Status
.DEFINE BUTTON_STATUS        BTN_Address
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
;-- Serial Port
.DEFINE UART_DATA            SER_Address + 0
.DEFINE UART_STATUS          SER_Address + 1

.DEFINE UART_RX_EMPTY_BIT    $10
.DEFINE UART_RX_EMPTY_MASK   UART_RX_EMPTY_BIT ~ $FF

.DEFINE UART_RX_FULL_BIT     $20
.DEFINE UART_RX_FULL_MASK    UART_RX_FULL_BIT ~ $FF

.DEFINE UART_TX_EMPTY_BIT    $40
.DEFINE UART_TX_EMPTY_MASK   UART_TX_EMPTY_BIT ~ $FF

.DEFINE UART_TX_FULL_BIT     $80
.DEFINE UART_TX_FULL_MASK    UART_TX_FULL_BIT ~ $FF
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
;-- MAX 7221 Serial LED Driver Port
.DEFINE MAXLED_NOP           MAX_Address + 0
.DEFINE MAXLED_DIG0          MAX_Address + 1
.DEFINE MAXLED_DIG1          MAX_Address + 2
.DEFINE MAXLED_DIG2          MAX_Address + 3
.DEFINE MAXLED_DIG3          MAX_Address + 4
.DEFINE MAXLED_DIG4          MAX_Address + 5
.DEFINE MAXLED_DIG5          MAX_Address + 6
.DEFINE MAXLED_DIG6          MAX_Address + 7
.DEFINE MAXLED_DIG7          MAX_Address + 8
.DEFINE MAXLED_DEC_MODE      MAX_Address + 9
.DEFINE MAXLED_INTENSITY     MAX_Address + 10
.DEFINE MAXLED_SCAN_LIM      MAX_Address + 11
.DEFINE MAXLED_SHUTDOWN      MAX_Address + 12
.DEFINE MAXLED_DISPTEST      MAX_Address + 15
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; Vector Select RX
.DEFINE VECTOR_SEL           VEC_Address + 0
.DEFINE VECTOR_ARG_LB        VEC_Address + 1
.DEFINE VECTOR_ARG_UB        VEC_Address + 2
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; Vector Select RX
.DEFINE CHRONOMETER_B0       CHR_Address + 0
.DEFINE CHRONOMETER_B1       CHR_Address + 1
.DEFINE CHRONOMETER_B2       CHR_Address + 2
.DEFINE CHRONOMETER_CTL      CHR_Address + 3

.DEFINE CHRONO_RESET_BIT     $40

.DEFINE CHRONO_ENABLE_BIT    $80
.DEFINE CHRONO_ENABLE_MASK   CHRONO_ENABLE_BIT ~ $FF
;
; Register Map:
; Offset  Bitfield Description                        Read/Write
;   0x00  AAAAAAAA Req Interval Byte 0                   (RW)
;   0x01  AAAAAAAA Req Interval Byte 1                   (RW)
;   0x02  AAAAAAAA Req Interval Byte 2                   (RW)
;   0x03  BA------ Control/Status Register               (RW)
;                   A: Reset (1)                         (WR)
;                   B: Start (1) / Stop (0)
;
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
;End of hardware defines
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; Test Vector Table
;  Allows for an index jump table to simplify branching. Each entry in the
;   table is the entry point for a segment of the test code.
;------------------------------------------------------------------------------

; There are only 64 possible index functions as of now, so we need to mask off
;  the upper bits to avoid illegal offset calculations
.DEFINE INDEX_MASK           $3F

.ORG JMP_TABLE_BLOCK
.DW TASK1_FN00
.DW TASK1_FN01
.DW TASK1_FN02
.DW TASK1_FN03
.DW TASK1_FN04
.DW TASK1_FN05
.DW TASK1_FN06
.DW TASK1_FN07
.DW TASK1_FN08
.DW TASK1_FN09
.DW TASK1_FN0A
.DW TASK1_FN0B
.DW TASK1_FN0C
.DW TASK1_FN0D
.DW TASK1_FN0E
.DW TASK1_FN0F
.DW TASK1_FN10
.DW TASK1_FN11
.DW TASK1_FN12
.DW TASK1_FN13
.DW TASK1_FN14
.DW TASK1_FN15
.DW TASK1_FN16
.DW TASK1_FN17
.DW TASK1_FN18
.DW TASK1_FN19
.DW TASK1_FN1A
.DW TASK1_FN1B
.DW TASK1_FN1C
.DW TASK1_FN1D
.DW TASK1_FN1E
.DW TASK1_FN1F
.DW TASK1_FN20
.DW TASK1_FN21
.DW TASK1_FN22
.DW TASK1_FN23
.DW TASK1_FN24
.DW TASK1_FN25
.DW TASK1_FN26
.DW TASK1_FN27
.DW TASK1_FN28
.DW TASK1_FN29
.DW TASK1_FN2A
.DW TASK1_FN2B
.DW TASK1_FN2C
.DW TASK1_FN2D
.DW TASK1_FN2E
.DW TASK1_FN2F
.DW TASK1_FN30
.DW TASK1_FN31
.DW TASK1_FN32
.DW TASK1_FN33
.DW TASK1_FN34
.DW TASK1_FN35
.DW TASK1_FN36
.DW TASK1_FN37
.DW TASK1_FN38
.DW TASK1_FN39
.DW TASK1_FN3A
.DW TASK1_FN3B
.DW TASK1_FN3C
.DW TASK1_FN3D
.DW TASK1_FN3E
.DW TASK1_FN3F
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; Table of index pointers
; Build the table at the INDEX_PTR_BLOCK address

.ORG INDEX_PTR_BLOCK
.DW TASK0_INIT         ; ( +0) Task 0 Entry pointer
.DW TASK0_STACK_START  ; ( +2) Task 0 Stack pointer
.DW TASK1_INIT         ; ( +4) Task 1 Entry pointer
.DW TASK1_STACK_START  ; ( +6) Task 1 Stack pointer
.DW TASK2_INIT         ; ( +8) Task 2 Entry pointer
.DW TASK2_STACK_START  ; (+10) Task 2 Stack pointer
.DW TASK3_INIT         ; (+12) Task 3 Entry pointer
.DW TASK3_STACK_START  ; (+14) Task 3 Stack pointer
.DW TASK4_INIT         ; (+16) Task 4 Entry pointer
.DW TASK4_STACK_START  ; (+18) Task 4 Stack pointer
.DW JMP_TABLE_BLOCK    ; (+20) Task 2 Jump table pointer
.DW SDLC_TX_BUFFER     ; (+22) SDLC TX Buffer pointer
.DW SDLC_RX_BUFFER     ; (+24) SDLC RX Buffer pointer
.DW DspKey.LCD_Buffer   ; (+26) LCD buffer pointer
.DW UART.RX_Buffer     ; (+28) UART RX buffer pointer
.DW UART.RX_Mesg       ; (+30) RX Message Buffer
.DW TIME_FN1_BLOCK     ; (+32) Time values for FN1
.DW TIME_FN2_BLOCK     ; (+34) Time values for FN2
.DW TIME_FN3_BLOCK     ; (+36) Time values for FN3

; Vector pointer calculations. These are all offsets from the INDEX_PTR_BLOCK
;  and are used to actually the contents (addresses) of the table into
;  registers using LDA Rn, NAMED_PTR, etc.

.DEFINE TASK0_INIT_PTR    INDEX_PTR_BLOCK + 0
.DEFINE TASK0_STACK_PTR   INDEX_PTR_BLOCK + 2
.DEFINE TASK1_INIT_PTR    INDEX_PTR_BLOCK + 4
.DEFINE TASK1_STACK_PTR   INDEX_PTR_BLOCK + 6
.DEFINE TASK2_INIT_PTR    INDEX_PTR_BLOCK + 8
.DEFINE TASK2_STACK_PTR   INDEX_PTR_BLOCK + 10
.DEFINE TASK3_INIT_PTR    INDEX_PTR_BLOCK + 12
.DEFINE TASK3_STACK_PTR   INDEX_PTR_BLOCK + 14
.DEFINE TASK4_INIT_PTR    INDEX_PTR_BLOCK + 16
.DEFINE TASK4_STACK_PTR   INDEX_PTR_BLOCK + 18
.DEFINE VECTOR_PTR        INDEX_PTR_BLOCK + 20
.DEFINE SER_TX_BUFFER_PTR INDEX_PTR_BLOCK + 22
.DEFINE SER_RX_BUFFER_PTR INDEX_PTR_BLOCK + 24
.DEFINE LCD_BUFFER_PTR    INDEX_PTR_BLOCK + 26
.DEFINE RX_BUFFER_PTR     INDEX_PTR_BLOCK + 28
.DEFINE RX_MESG_PTR       INDEX_PTR_BLOCK + 30
.DEFINE TIME_FN1_BLK_PTR  INDEX_PTR_BLOCK + 32
.DEFINE TIME_FN2_BLK_PTR  INDEX_PTR_BLOCK + 34
.DEFINE TIME_FN3_BLK_PTR  INDEX_PTR_BLOCK + 36
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
;  Form vector address table at the end of the ROM
;------------------------------------------------------------------------------
.ORG ISR_Start_Addr
.DW INTR0
.DW INTR1
.DW INTR2
.DW INTR3
.DW INTR4
.DW INTR5
.DW INTR6
.DW INTR7
;------------------------------------------------------------------------------