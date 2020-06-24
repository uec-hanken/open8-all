-- Copyright (c)2006, 2011, 2012, 2013, 2015, 2019, 2020 Jeremy Seth Henry
-- All rights reserved.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are met:
--     * Redistributions of source code must retain the above copyright
--       notice, this list of conditions and the following disclaimer.
--     * Redistributions in binary form must reproduce the above copyright
--       notice, this list of conditions and the following disclaimer in the
--       documentation and/or other materials provided with the distribution,
--       where applicable (as part of a user interface, debugging port, etc.)
--
-- THIS SOFTWARE IS PROVIDED BY JEREMY SETH HENRY ``AS IS'' AND ANY
-- EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
-- WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
-- DISCLAIMED. IN NO EVENT SHALL JEREMY SETH HENRY BE LIABLE FOR ANY
-- DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
-- (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
-- LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
-- ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
-- (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
-- THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--
-- VHDL Units :  o8_cpu
-- Description:  VHDL model of a RISC 8-bit processor core loosely based on the
--            :   V8/ARC uRISC instruction set. Requires Open8_pkg.vhd
--            :
-- Notes      :  Generic definitions
--            :
--            :  Program_Start_Addr sets the initial value of the program
--            :   counter.
--            :
--            :  ISR_Start_Addr sets the location of the interrupt service
--            :   vector table. There are 8 service vectors, or 16 bytes, which
--            :   must be allocated to either ROM or RAM.
--            :
--            :  Stack_Start_Address sets the initial (reset) value of the
--            :   stack pointer. Also used for the RSP instruction if
--            :   Allow_Stack_Address_Move is false.
--            :
--            :  Allow_Stack_Address_Move, when set true, allows the RSP to be
--            :   programmed via thet RSP instruction. If enabled, the
--            :   instruction changes into TSX or TXS based on the flag
--            :   specified by Stack_Xfer_Flag. If the flag is '0', RSP will
--            :   copy the current stack pointer to R1:R0 (TSX). If the flag
--            :   is '1', RSP will copy R1:R0 to the stack pointer (TXS). This
--            :   allows the processor to backup and restore stack pointers
--            :   in a multi-process environment. Note that no flags are
--            :   modified by either form of this instruction.
--            :
--            :  Stack_Xfer_Flag instructs the core to use the specified ALU
--            :   flag to alter the behavior of the RSP instruction when
--            :   Allow_Stack_Address_Move is set TRUE, otherwise it is ignored.
--            :   While technically any of the status bits may be used, the
--            :   intent was to use FL_GP[1,2,3,4], as these are not modified
--            :   by ordinary ALU operations.
--            :
--            :  The Enable_Auto_Increment generic can be used to modify the
--            :   indexed instructions such that specifying an odd register
--            :   will use the next lower register pair, post-incrementing the
--            :   value in that pair. IOW, specifying STX R1 will instead
--            :   result in STX R0++, or R0 = {R1:R0}; {R1:R0} + 1
--            :
--            :  BRK_Implements_WAI modifies the BRK instruction such that it
--            :   triggers the wait for interrupt state, but without triggering
--            :   a soft interrupt in lieu of its normal behavior, which is to
--            :   insert several dead clock cycles - essentially a long NOP
--            :
--            :  Enable_NMI overrides the mask bit for interrupt 0, creating a
--            :   non-maskable interrupt at the highest priority. To remain
--            :   true to the original core, this should be set false.
--            :
--            :  RTI_Ignores_GP_Flags alters the set of flag bits restored
--            :   after an interrupt. By default, all of the flag bits are put
--            :   back to their original state. If this flag is set true, only
--            :   the lower four bits are restored, allowing ISR code to alter
--            :   the GP flags persistently.
--            :
--            :  Supervisor_Mode, when set, disables the STP PSR_I instruction
--            :   preventing code from setting the I bit. When enabled, only
--            :   interrupts can set the I bit, allowing for more robust memory
--            :   protection by preventing errant code execution from
--            :   inadvertently entering an interrupt state.
--            :
--            :   This setting also sets I bit at startup so that any
--            :   initialization code may be run in an ISR context, initially
--            :   bypassing memory protection. Init code should clear the I bit
--            :   when done;
--            :
--            :  Default_Interrupt_Mask sets the intial/reset value of the
--            :   interrupt mask. To remain true to the original core, which
--            :   had no interrupt mask, this should be set to x"FF". Otherwise
--            :   it can be initialized to any value. Note that Enable_NMI
--            :   will logically force the LSB high.
--            :
--            :  Reset_Level determines whether the processor registers reset
--            :   on a high or low level from higher logic.
--            :
--            : Architecture notes
--            :  This model deviates from the original ISA in a few important
--            :   ways.
--            :
--            :  First, there is only one set of registers. Interrupt service
--            :   routines must explicitely preserve context since the the
--            :   hardware doesn't. This was done to decrease size and code
--            :   complexity. Older code that assumes this behavior will not
--            :   execute correctly on this processor model.
--            :
--            :  Second, this model adds an additional pipeline stage between
--            :   the instruction decoder and the ALU. Unfortunately, this
--            :   means that the instruction stream has to be restarted after
--            :   any math instruction is executed, implying that any ALU
--            :   instruction now has a latency of 2 instead of 0. The
--            :   advantage is that the maximum frequency has gone up
--            :   significantly, as the ALU code is vastly more efficient.
--            :   As an aside, this now means that all math instructions,
--            :   including MUL (see below) and UPP have the same instruction
--            :   latency.
--            :
--            :  Third, the original ISA, also a soft core, had two reserved
--            :   instructions, USR and USR2. These have been implemented as
--            :   DBNZ, and MUL respectively.
--            :
--            :  DBNZ decrements the specified register and branches if the
--            :   result is non-zero. The instruction effectively executes a
--            :   DEC Rn instruction prior to branching, so the same flags will
--            :   be set.
--            :
--            :  MUL places the result of R0 * Rn into R1:R0. Instruction
--            :   latency is identical to other ALU instructions. Only the Z
--            :   flag is set, since there is no defined overflow or "negative
--            :   16-bit values"
--            :
--            :  Fourth, indexed load/store instructions now have an (optional)
--            :   ability to post-increment their index registers. If enabled,
--            :   using an odd operand for LDO,LDX, STO, STX will cause the
--            :   register pair to be incremented after the storage access.
--            :
--            :  Fifth, the RSP instruction has been (optionally) altered to
--            :   allow the stack pointer to be sourced from R1:R0.
--            :
--            :  Sixth, the BRK instruction can optionally implement a WAI,
--            :   which is the same as the INT instruction without the soft
--            :   interrupt, as a way to put the processor to "sleep" until the
--            :   next external interrupt.
--            :
--            :  Seventh, the original CPU model had 8 non-maskable interrupts
--            :   with priority. This model has the same 8 interrupts, but
--            :   allows software to mask them (with an additional option to
--            :   override the highest priority interrupt, making it the NMI.)
--            :
--            :  Lastly, previous unmapped instructions in the OP_STK opcode
--            :   were repurposed to support a new interrupt mask.
--            :   SMSK and GMSK transfer the contents of R0 (accumulator)
--            :   to/from the interrupt mask register. SMSK is immediate, while
--            :   GMSK has the same overhead as a math instruction.
--
-- Revision History
-- Author          Date     Change
------------------ -------- ---------------------------------------------------
-- Seth Henry      07/19/06 Design Start
-- Seth Henry      01/18/11 Fixed BTT instruction to match V8
-- Seth Henry      07/22/11 Fixed interrupt transition logic to avoid data
--                           corruption issues.
-- Seth Henry      07/26/11 Optimized logic in ALU, stack pointer, and data
--                           path sections.
-- Seth Henry      07/27/11 Optimized logic for timing, merged blocks into
--                           single entity.
-- Seth Henry      09/20/11 Added BRK_Implements_WAI option, allowing the
--                           processor to wait for an interrupt instead of the
--                           normal BRK behavior.
-- Seth Henry      12/20/11 Modified core to allow WAI_Cx state to idle
--                           the bus entirely (Rd_Enable is low)
-- Seth Henry      02/03/12 Replaced complex interrupt controller with simpler,
--                           faster logic that simply does priority encoding.
-- Seth Henry      08/06/13 Removed HALT functionality
-- Seth Henry      10/29/15 Fixed inverted carry logic in CMP and SBC instrs
-- Seth Henry      12/19/19 Renamed to o8_cpu to fit "theme"
-- Seth Henry      03/09/20 Modified RSP instruction to work with a CPU flag
--                           allowing true backup/restore of the stack pointer
-- Seth Henry      03/11/20 Split the address logic from the main state machine
--                           in order to simplify things and eliminate
--                           redundancies. Came across and fixed a problem with
--                           the STO instruction when Enable_Auto_Increment is
--                           NOT set.
-- Seth Henry      03/12/20 Rationalized the naming of the CPU flags to match
--                           the assembler names. Also fixed an issue where
--                           the I bit wasn't being cleared after interrupts.
--                          Simplified the program counter logic to only use
--                           the offset for increments, redefining the
--                           original modes as fixed offset values.
--                          Modified the ALU section with a new ALU operation
--                           for GMSK. This allowed the .data field to be
--                           removed and Operand1 used in its place, which
--                           simplified the logic a great deal.
-- Seth Henry      03/16/20 Added CPU_Halt input back, only now as an input to
--                           the instruction decode state, where it acts as a
--                           modified form of the BRK instruction that holds
--                           state until CPU_Halt is deasserted. This has a
--                           much smaller impact on Fmax/complexity than the
--                           original clock enable, but imposes a mild impact
--                           due to the need to reset the instruction pipeline
-- Seth Henry      03/17/20 Added generic to control whether RTI full restores
--                           the flags, including the general purpose ones, or
--                           only the core ALU flags (Z, N, and C). Also
--                           brought out copies of the GP flags for external
--                           connection.
-- Seth Henry      04/09/20 Added a compile time setting to block interrupts
--                           while the I bit is set to avoid reentering ISRs
--                           This may slightly affect timing, as this will
--                           potentially block higher priority interrupts
--                           until the lower priority ISR returns or clears
--                           the I bit.
--                          Also added the I bit to the exported flags for
--                           use in memory protection schemes.
-- Seth Henry      04/16/20 Modified to use new Open8 bus record. Also added
--                           reset and usec_tick logic to drive utility
--                           signals. Also added Halt_Ack output.
-- Seth Henry      05/20/20 Added two new generics to alter the way the I bit
--                           is handled. The Supervisor_Mode setting disables
--                           STP PSR_I from being executed, preventing it
--                           from being set outside of an ISR. The
--                           Default_Int_Flag setting allows the I bit to
--                           start set so that initialization code can run,
--                           but not be hijacked later to corrupt any memory
--                           write protection later.
-- Seth Henry      05/21/20 Supervisor_Mode now protects the interrupt mask
--                           and stack pointer as well.
-- Seth Henry      05/24/20 Removed the Default_Int_Flag, as it is covered by
--                           Supervisor_Mode. If Supervisor_Mode isn't set,
--                           code can simply use STP to set the bit

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.std_logic_arith.all;
  use ieee.std_logic_misc.all;

library work;
  use work.Open8_pkg.all;

entity o8_cpu is
  generic(
    Program_Start_Addr       : ADDRESS_TYPE := x"0000"; -- Initial PC location
    ISR_Start_Addr           : ADDRESS_TYPE := x"FFF0"; -- Bottom of ISR vec's
    Stack_Start_Addr         : ADDRESS_TYPE := x"03FF"; -- Top of Stack
    Allow_Stack_Address_Move : boolean      := false;   -- Use Normal v8 RSP
    Stack_Xfer_Flag          : integer      := PSR_GP4; -- GP4 modifies RSP
    Enable_Auto_Increment    : boolean      := false;   -- Modify indexed instr
    BRK_Implements_WAI       : boolean      := false;   -- BRK -> Wait for Int
    Enable_NMI               : boolean      := true;    -- Force INTR0 enabled
    Sequential_Interrupts    : boolean      := false;   -- Interruptable ISRs
    RTI_Ignores_GP_Flags     : boolean      := false;   -- RTI sets all flags
    Supervisor_Mode          : boolean      := false;   -- I bit is restricted
    Default_Interrupt_Mask   : DATA_TYPE    := x"FF";   -- Enable all Ints
    Clock_Frequency          : real                     -- Clock Frequency
);
  port(
    Clock                    : in  std_logic;
    PLL_Locked               : in  std_logic;
    --
    Halt_Req                 : in  std_logic := '0';
    Halt_Ack                 : out std_logic;
    --
    Open8_Bus                : out OPEN8_BUS_TYPE;
    Rd_Data                  : in  DATA_TYPE;
    Interrupts               : in  INTERRUPT_BUNDLE := x"00"
);
end entity;

architecture behave of o8_cpu is

  signal Reset_q             : std_logic := Reset_Level;
  signal Reset               : std_logic := Reset_Level;

  constant USEC_VAL          : integer := integer(Clock_Frequency / 1000000.0);
  constant USEC_WDT          : integer := ceil_log2(USEC_VAL - 1);
  constant USEC_DLY          : std_logic_vector :=
                                conv_std_logic_vector(USEC_VAL - 1, USEC_WDT);
  signal uSec_Cntr           : std_logic_vector( USEC_WDT - 1 downto 0 );
  signal uSec_Tick           : std_logic;

  constant INT_VECTOR_0      : ADDRESS_TYPE := ISR_Start_Addr;
  constant INT_VECTOR_1      : ADDRESS_TYPE := ISR_Start_Addr+2;
  constant INT_VECTOR_2      : ADDRESS_TYPE := ISR_Start_Addr+4;
  constant INT_VECTOR_3      : ADDRESS_TYPE := ISR_Start_Addr+6;
  constant INT_VECTOR_4      : ADDRESS_TYPE := ISR_Start_Addr+8;
  constant INT_VECTOR_5      : ADDRESS_TYPE := ISR_Start_Addr+10;
  constant INT_VECTOR_6      : ADDRESS_TYPE := ISR_Start_Addr+12;
  constant INT_VECTOR_7      : ADDRESS_TYPE := ISR_Start_Addr+14;

  signal CPU_Next_State      : CPU_STATES := IPF_C0;
  signal CPU_State           : CPU_STATES := IPF_C0;

  signal CPU_Halt_Req        : std_logic := '0';
  signal CPU_Halt_Ack        : std_logic := '0';

  signal Cache_Ctrl          : CACHE_MODES := CACHE_IDLE;

  signal Opcode              : OPCODE_TYPE := (others => '0');
  signal SubOp, SubOp_p1     : SUBOP_TYPE  := (others => '0');

  signal Prefetch            : DATA_TYPE   := x"00";
  signal Operand1, Operand2  : DATA_TYPE   := x"00";

  signal Instr_Prefetch      : std_logic   := '0';

  signal PC_Ctrl             : PC_CTRL_TYPE;
  signal Program_Ctr         : ADDRESS_TYPE := x"0000";

  signal ALU_Ctrl            : ALU_CTRL_TYPE;
  signal Regfile             : REGFILE_TYPE;
  signal Flags               : FLAG_TYPE;
  signal Mult                : ADDRESS_TYPE := x"0000";

  signal SP_Ctrl             : SP_CTRL_TYPE;
  signal Stack_Ptr           : ADDRESS_TYPE := x"0000";

  signal DP_Ctrl             : DATA_CTRL_TYPE;

  signal INT_Ctrl            : INT_CTRL_TYPE;
  signal Ack_D, Ack_Q, Ack_Q1: std_logic   := '0';
  signal Int_Req, Int_Ack    : std_logic   := '0';
  signal Set_Mask            : std_logic   := '0';
  signal Int_Mask            : DATA_TYPE   := x"00";
  signal ISR_Addr            : ADDRESS_TYPE := x"0000";
  signal i_Ints              : INTERRUPT_BUNDLE := x"00";
  signal Pending             : INTERRUPT_BUNDLE := x"00";
  signal Wait_for_FSM        : std_logic := '0';
  signal Wait_for_ISR        : std_logic := '0';

begin

-------------------------------------------------------------------------------
-- Reset & uSec Tick
-------------------------------------------------------------------------------

  CPU_Reset_Sync: process( Clock, PLL_Locked )
  begin
    if( PLL_Locked = '0' )then
      Reset_q                <= Reset_Level;
      Reset                  <= Reset_Level;
    elsif( rising_edge(Clock) )then
      Reset_q                <= not Reset_Level;
      Reset                  <= Reset_q;
    end if;
  end process;

  uSec_Tick_proc: process( Clock, Reset )
  begin
    if( Reset = Reset_Level )then
      uSec_Cntr              <= USEC_DLY;
      uSec_Tick              <= '0';
    elsif( rising_edge( Clock ) )then
      uSec_Cntr              <= uSec_Cntr - 1;
      if( or_reduce(uSec_Cntr) = '0' )then
        uSec_Cntr            <= USEC_DLY;
      end if;
      uSec_Tick              <= nor_reduce(uSec_Cntr);
    end if;
  end process;

  Open8_Bus.Clock            <= Clock;
  Open8_Bus.Reset            <= Reset;
  Open8_Bus.uSec_Tick        <= uSec_Tick;

-------------------------------------------------------------------------------
-- Address bus selection/generation logic
-------------------------------------------------------------------------------

  Address_Logic: process(CPU_State, Regfile, SubOp, SubOp_p1, Operand1,
                         Operand2, Program_Ctr, Stack_Ptr, ISR_Addr )
    variable Reg, Reg_1      : integer range 0 to 7 := 0;
    variable Offset_SX       : ADDRESS_TYPE;
  begin

    if( Enable_Auto_Increment )then
      Reg                    := conv_integer(SubOp(2 downto 1) & '0');
      Reg_1                  := conv_integer(SubOp(2 downto 1) & '1');
    else
      Reg                    := conv_integer(SubOp);
      Reg_1                  := conv_integer(SubOp_p1);
    end if;

    Offset_SX(15 downto 0)   := (others => Operand1(7));
    Offset_SX(7 downto 0)    := Operand1;

    case( CPU_State )is

      when LDA_C2 | STA_C2 =>
        Open8_Bus.Address    <= Operand2 & Operand1;

      when LDX_C1 | STX_C1 =>
        Open8_Bus.Address    <= (Regfile(Reg_1) & Regfile(Reg));

      when LDO_C1 | STO_C1 =>
        Open8_Bus.Address    <= (Regfile(Reg_1) & Regfile(Reg)) + Offset_SX;

      when ISR_C1 | ISR_C2 =>
        Open8_Bus.Address    <= ISR_Addr;

      when PSH_C1 | POP_C1 | ISR_C3 | JSR_C1 | JSR_C2 | RTS_C1 | RTS_C2 | RTS_C3 =>
        Open8_Bus.Address    <= Stack_Ptr;

      when others =>
        Open8_Bus.Address    <= Program_Ctr;

    end case;

  end process;

-------------------------------------------------------------------------------
-- Combinatorial portion of CPU finite state machine
-- State Logic / Instruction Decoding & Execution
-------------------------------------------------------------------------------

  State_Logic: process(CPU_State, Flags, Int_Mask, CPU_Halt_Req, Opcode,
                       SubOp , SubOp_p1, Operand1, Operand2, Int_Req )
    variable Reg             : integer range 0 to 7 := 0;
  begin
    CPU_Next_State           <= CPU_State;
    Cache_Ctrl               <= CACHE_IDLE;
    --
    PC_Ctrl.Oper             <= PC_INCR;
    PC_Ctrl.Offset           <= PC_IDLE;
    --
    ALU_Ctrl.Oper            <= ALU_IDLE;
    ALU_Ctrl.Reg             <= ACCUM;
    --
    SP_Ctrl.Oper             <= SP_IDLE;
    --
    DP_Ctrl.Src              <= DATA_RD_MEM;
    DP_Ctrl.Reg              <= ACCUM;
    --
    INT_Ctrl.Mask_Set        <= '0';
    INT_Ctrl.Soft_Ints       <= x"00";
    INT_Ctrl.Incr_ISR        <= '0';
    Ack_D                    <= '0';
    --
    Reg                     := conv_integer(SubOp);
    --
    CPU_Halt_Ack             <= '0';

    case CPU_State is
-------------------------------------------------------------------------------
-- Initial Instruction fetch & decode
-------------------------------------------------------------------------------
      when IPF_C0 =>
        CPU_Next_State       <= IPF_C1;
        PC_Ctrl.Offset       <= PC_NEXT;

      when IPF_C1 =>
        CPU_Next_State       <= IPF_C2;
        PC_Ctrl.Offset       <= PC_NEXT;

      when IPF_C2 =>
        CPU_Next_State       <= IDC_C0;
        Cache_Ctrl           <= CACHE_INSTR;
        PC_Ctrl.Offset       <= PC_NEXT;

      when IDC_C0 =>
        CPU_Next_State       <= IDC_C0;
        Cache_Ctrl           <= CACHE_INSTR;

        case Opcode is
          when OP_PSH =>
            CPU_Next_State   <= PSH_C1;
            Cache_Ctrl       <= CACHE_PREFETCH;
            PC_Ctrl.Offset   <= PC_REV1;
            DP_Ctrl.Src      <= DATA_WR_REG;
            DP_Ctrl.Reg      <= SubOp;

          when OP_POP =>
            CPU_Next_State   <= POP_C1;
            Cache_Ctrl       <= CACHE_PREFETCH;
            PC_Ctrl.Offset   <= PC_REV2;
            SP_Ctrl.Oper     <= SP_POP;

          when OP_BR0 | OP_BR1 =>
            CPU_Next_State   <= BRN_C1;
            Cache_Ctrl       <= CACHE_OPER1;
            PC_Ctrl.Offset   <= PC_NEXT;


          when OP_DBNZ =>
            CPU_Next_State   <= DBNZ_C1;
            Cache_Ctrl       <= CACHE_OPER1;
            PC_Ctrl.Offset   <= PC_NEXT;
            ALU_Ctrl.Oper    <= ALU_DEC;
            ALU_Ctrl.Reg     <= SubOp;

          when OP_INT =>
            PC_Ctrl.Offset   <= PC_NEXT;
            -- Make sure the requested interrupt is actually enabled first.
            --  Also, unlike CPU_Halt, the INT instruction is actually being
            --  executed, so go ahead and increment the program counter before
            --  pausing so the CPU restarts on the next instruction.
            if( Int_Mask(Reg) = '1' )then
              CPU_Next_State <= WAI_Cx;
              INT_Ctrl.Soft_Ints(Reg) <= '1';
            end if;

          when OP_STK =>
            case SubOp is
              when SOP_RSP  =>
                PC_Ctrl.Offset <= PC_NEXT;
                if( not Allow_Stack_Address_Move )then
                  -- The default behavior for this instruction is to simply
                  --  repoint the SP to the HDL default
                  SP_Ctrl.Oper    <= SP_CLR;
                end if;
                if( Allow_Stack_Address_Move and
                    Flags(Stack_Xfer_Flag) = '1' )then
                  -- If RSP is set to allow SP moves, and the specified flag
                  --  is true, then signal the stack pointer logic to load
                  --  from R1:R0
                  SP_Ctrl.Oper    <= SP_SET;
                end if;
                if( Allow_Stack_Address_Move and
                    Flags(Stack_Xfer_Flag) = '0')then
                  -- If RSP is set to allow SP moves, and the specified flag
                  --  is false, then signal the ALU to copy the stack pointer
                  --  to R1:R0
                  ALU_Ctrl.Oper   <= ALU_RSP;
                end if;

              when SOP_RTS | SOP_RTI =>
                CPU_Next_State    <= RTS_C1;
                Cache_Ctrl        <= CACHE_IDLE;
                SP_Ctrl.Oper      <= SP_POP;

              when SOP_BRK  =>
                if( BRK_Implements_WAI )then
                  -- If BRK_Implements_WAI, then jump to the WAI_Cx and
                  --  increment the PC similar to an ISR flow.
                  CPU_Next_State  <= WAI_Cx;
                  PC_Ctrl.Offset  <= PC_NEXT;
                else
                -- If Break is implemented normally, back the PC up by
                --  2 and return through IPF_C0 in order to execute a 5
                --  clock cycle delay
                  CPU_Next_State  <= BRK_C1;
                  PC_Ctrl.Offset  <= PC_REV2;
                end if;

              when SOP_JMP  =>
                CPU_Next_State    <= JMP_C1;
                Cache_Ctrl        <= CACHE_OPER1;

              when SOP_SMSK =>
                PC_Ctrl.Offset    <= PC_NEXT;
                INT_Ctrl.Mask_Set <= '1';

              when SOP_GMSK =>
                PC_Ctrl.Offset    <= PC_NEXT;
                ALU_Ctrl.Oper     <= ALU_GMSK;

              when SOP_JSR =>
                CPU_Next_State <= JSR_C1;
                Cache_Ctrl        <= CACHE_OPER1;
                DP_Ctrl.Src       <= DATA_WR_PC;
                DP_Ctrl.Reg       <= PC_MSB;

              when others => null;
            end case;

          when OP_MUL =>
            CPU_Next_State   <= MUL_C1;
            -- Multiplication requires a single clock cycle to calculate PRIOR
            --  to the ALU writing the result to registers. As a result, this
            --  state needs to idle the ALU initially, and back the PC up by 1
            -- We can get away with only 1 extra clock by pre-fetching the
            --  next instruction, though.
            Cache_Ctrl       <= CACHE_PREFETCH;
            PC_Ctrl.Offset   <= PC_REV1;
            -- Note that both the multiply process AND ALU process need the
            --  source register for Rn (R1:R0 = R0 * Rn). Assert ALU_Ctrl.reg
            --  now, but hold off on the ALU command until the next state.
            ALU_Ctrl.Oper    <= ALU_IDLE;
            ALU_Ctrl.Reg     <= SubOp;

          when OP_UPP =>
            CPU_Next_State   <= UPP_C1;
            Cache_Ctrl       <= CACHE_PREFETCH;
            PC_Ctrl.Offset   <= PC_REV1;
            ALU_Ctrl.Oper    <= Opcode;
            ALU_Ctrl.Reg     <= SubOp;

          when OP_LDA =>
            CPU_Next_State   <= LDA_C1;
            Cache_Ctrl       <= CACHE_OPER1;

          when OP_LDI =>
            CPU_Next_State   <= LDI_C1;
            Cache_Ctrl       <= CACHE_OPER1;
            PC_Ctrl.Offset   <= PC_NEXT;

          when OP_LDO =>
            CPU_Next_State   <= LDO_C1;
            Cache_Ctrl       <= CACHE_OPER1;
            PC_Ctrl.Offset   <= PC_REV2;

          when OP_LDX =>
            CPU_Next_State   <= LDX_C1;
            Cache_Ctrl       <= CACHE_PREFETCH;
            PC_Ctrl.Offset   <= PC_REV2;

          when OP_STA =>
            CPU_Next_State   <= STA_C1;
            Cache_Ctrl       <= CACHE_OPER1;

          when OP_STO =>
            CPU_Next_State   <= STO_C1;
            Cache_Ctrl       <= CACHE_OPER1;
            PC_Ctrl.Offset   <= PC_REV2;
            DP_Ctrl.Src      <= DATA_WR_REG;
            DP_Ctrl.Reg      <= ACCUM;

          when OP_STX =>
            CPU_Next_State   <= STX_C1;
            Cache_Ctrl       <= CACHE_PREFETCH;
            PC_Ctrl.Offset   <= PC_REV2;
            DP_Ctrl.Src      <= DATA_WR_REG;
            DP_Ctrl.Reg      <= ACCUM;

          when OP_STP =>
            PC_Ctrl.Offset   <= PC_NEXT;
            if( Supervisor_Mode )then
              if( SubOp /= PSR_I )then
                ALU_Ctrl.Oper  <= Opcode;
                ALU_Ctrl.Reg   <= SubOp;
              end if;
            else
              ALU_Ctrl.Oper  <= Opcode;
              ALU_Ctrl.Reg   <= SubOp;
            end if;

          when others =>
            PC_Ctrl.Offset   <= PC_NEXT;
            ALU_Ctrl.Oper    <= Opcode;
            ALU_Ctrl.Reg     <= SubOp;

        end case;

        if( Int_Req = '1' )then
          CPU_Next_State     <= ISR_C1;
        end if;

        if( CPU_Halt_Req = '1' )then
          CPU_Next_State     <= WAH_Cx;
        end if;

        -- If either of these override conditions are true, the decoder needs
        --  to undo everything it just setup, since even "single-cycle"
        --  instructions will be executed again upon return.
        if( Int_Req = '1' or CPU_Halt_Req = '1' )then
          -- In either case, we want to skip loading the cache, as the cache
          --  will be invalid by the time we get back.
          Cache_Ctrl         <= CACHE_IDLE;
          -- Rewind the PC by 3 to put the PC back to the current instruction,
          -- compensating for the pipeline registers.
          PC_Ctrl.Offset     <= PC_REV3;
          -- Reset all of the sub-block controls to IDLE, to avoid unintended
          --  operation due to the current instruction.
          ALU_Ctrl.Oper      <= ALU_IDLE;
          SP_Ctrl.Oper       <= SP_IDLE;
          -- Interrupt logic outside of the state machine needs this to be set
          --  to DATA_RD_MEM, while CPU_Halt considers this a "don't care".
          DP_Ctrl.Src        <= DATA_RD_MEM;
          -- If an INT/SMSK instruction was going to be executed, it will get
          --  executed again when normal processing resumes, so axe their
          --  requests for now.
          INT_Ctrl.Mask_Set       <= '0';
          INT_Ctrl.Soft_Ints(Reg) <= '0';
        end if;

-------------------------------------------------------------------------------
-- Program Control (BR0_C1, BR1_C1, DBNZ_C1, JMP )
-------------------------------------------------------------------------------

      when BRN_C1 =>
        CPU_Next_State       <= IDC_C0;
        Cache_Ctrl           <= CACHE_INSTR;
        PC_Ctrl.Offset       <= PC_NEXT;
        if( Flags(Reg) = Opcode(0) )then
          CPU_Next_State     <= IPF_C0;
          Cache_Ctrl         <= CACHE_IDLE;
          PC_Ctrl.Offset     <= Operand1;
        end if;

      when DBNZ_C1 =>
        CPU_Next_State       <= IDC_C0;
        Cache_Ctrl           <= CACHE_INSTR;
        PC_Ctrl.Offset       <= PC_NEXT;
        if( Flags(PSR_Z) = '0' )then
          CPU_Next_State     <= IPF_C0;
          Cache_Ctrl         <= CACHE_IDLE;
          PC_Ctrl.Offset     <= Operand1;
        end if;

      when JMP_C1 =>
        CPU_Next_State       <= JMP_C2;
        Cache_Ctrl           <= CACHE_OPER2;

      when JMP_C2 =>
        CPU_Next_State       <= IPF_C0;
        PC_Ctrl.Oper         <= PC_LOAD;

-------------------------------------------------------------------------------
-- Data Storage - Load from memory (LDA, LDI, LDO, LDX)
-------------------------------------------------------------------------------

      when LDA_C1 =>
        CPU_Next_State       <= LDA_C2;
        Cache_Ctrl           <= CACHE_OPER2;

      when LDA_C2 =>
        CPU_Next_State       <= LDA_C3;

      when LDA_C3 =>
        CPU_Next_State       <= LDA_C4;
        PC_Ctrl.Offset       <= PC_NEXT;

      when LDA_C4 =>
        CPU_Next_State       <= LDI_C1;
        Cache_Ctrl           <= CACHE_OPER1;
        PC_Ctrl.Offset       <= PC_NEXT;

      when LDI_C1 =>
        CPU_Next_State       <= IDC_C0;
        Cache_Ctrl           <= CACHE_INSTR;
        PC_Ctrl.Offset       <= PC_NEXT;
        ALU_Ctrl.Oper        <= ALU_LDI;
        ALU_Ctrl.Reg         <= SubOp;

      when LDO_C1 =>
        CPU_Next_State       <= LDX_C2;
        PC_Ctrl.Offset       <= PC_NEXT;
        if( Enable_Auto_Increment and SubOp(0) = '1' )then
          ALU_Ctrl.Oper      <= ALU_UPP;
          ALU_Ctrl.Reg       <= SubOp(2 downto 1) & '0';
        end if;

      when LDX_C1 =>
        CPU_Next_State       <= LDX_C2;
        if( Enable_Auto_Increment and SubOp(0) = '1' )then
          ALU_Ctrl.Oper      <= ALU_UPP;
          ALU_Ctrl.Reg       <= SubOp(2 downto 1) & '0';
        end if;

      when LDX_C2 =>
        CPU_Next_State       <= LDX_C3;
        PC_Ctrl.Offset       <= PC_NEXT;

      when LDX_C3 =>
        CPU_Next_State       <= LDX_C4;
        Cache_Ctrl           <= CACHE_OPER1;
        PC_Ctrl.Offset       <= PC_NEXT;

      when LDX_C4 =>
        CPU_Next_State       <= IDC_C0;
        Cache_Ctrl           <= CACHE_INSTR;
        PC_Ctrl.Offset       <= PC_NEXT;
        ALU_Ctrl.Oper        <= ALU_LDI;
        ALU_Ctrl.Reg         <= ACCUM;

-------------------------------------------------------------------------------
-- Data Storage - Store to memory (STA, STO, STX)
-------------------------------------------------------------------------------
      when STA_C1 =>
        CPU_Next_State       <= STA_C2;
        Cache_Ctrl           <= CACHE_OPER2;
        DP_Ctrl.Src          <= DATA_WR_REG;
        DP_Ctrl.Reg          <= SubOp;

      when STA_C2 =>
        CPU_Next_State       <= STA_C3;
        PC_Ctrl.Offset       <= PC_NEXT;

      when STA_C3 =>
        CPU_Next_State       <= IPF_C2;
        Cache_Ctrl           <= CACHE_PREFETCH;
        PC_Ctrl.Offset       <= PC_NEXT;

      when STO_C1 =>
        CPU_Next_State       <= IPF_C0;
        Cache_Ctrl           <= CACHE_PREFETCH;
        PC_Ctrl.Offset       <= PC_NEXT;
        if( Enable_Auto_Increment and SubOp(0) = '1' )then
          CPU_Next_State     <= STO_C2;
          ALU_Ctrl.Oper      <= ALU_UPP;
          ALU_Ctrl.Reg       <= SubOp(2 downto 1) & '0';
        end if;

      when STO_C2 =>
        CPU_Next_State       <= IPF_C1;
        PC_Ctrl.Offset       <= PC_NEXT;
        ALU_Ctrl.Oper        <= ALU_UPP2;
        ALU_Ctrl.Reg         <= SubOp(2 downto 1) & '1';

      when STX_C1 =>
        CPU_Next_State       <= IPF_C1;
        PC_Ctrl.Offset       <= PC_NEXT;
        if( Enable_Auto_Increment and SubOp(0) = '1' )then
          CPU_Next_State     <= STX_C2;
          ALU_Ctrl.Oper      <= ALU_UPP;
          ALU_Ctrl.Reg       <= SubOp(2 downto 1) & '0';
        end if;

      when STX_C2 =>
        CPU_Next_State       <= IPF_C2;
        PC_Ctrl.Offset       <= PC_NEXT;
        ALU_Ctrl.Oper        <= ALU_UPP2;
        ALU_Ctrl.Reg         <= SubOp(2 downto 1) & '1';

-------------------------------------------------------------------------------
-- Multi-Cycle Math Operations (UPP, MUL)
-------------------------------------------------------------------------------

      -- Because we have to backup the pipeline by 1 to refetch the 2nd
      --  instruction/first operand, we have to return through PF2. Also, we
      --  need to tell the ALU to store the results to R1:R0 here. Note that
      --  there is no ALU_Ctrl.Reg, as this is implied in the ALU instruction
      when MUL_C1 =>
        CPU_Next_State       <= IPF_C2;
        PC_Ctrl.Offset       <= PC_NEXT;
        ALU_Ctrl.Oper        <= ALU_MUL;

      when UPP_C1 =>
        CPU_Next_State       <= IPF_C2;
        PC_Ctrl.Offset       <= PC_NEXT;
        ALU_Ctrl.Oper        <= ALU_UPP2;
        ALU_Ctrl.Reg         <= SubOp_p1;

-------------------------------------------------------------------------------
-- Basic Stack Manipulation (PSH, POP, RSP)
-------------------------------------------------------------------------------
      when PSH_C1 =>
        CPU_Next_State       <= IPF_C1;
        SP_Ctrl.Oper         <= SP_PUSH;

      when POP_C1 =>
        CPU_Next_State       <= POP_C2;

      when POP_C2 =>
        CPU_Next_State       <= POP_C3;
        PC_Ctrl.Offset       <= PC_NEXT;

      when POP_C3 =>
        CPU_Next_State       <= POP_C4;
        Cache_Ctrl           <= CACHE_OPER1;
        PC_Ctrl.Offset       <= PC_NEXT;

      when POP_C4 =>
        CPU_Next_State       <= IDC_C0;
        Cache_Ctrl           <= CACHE_INSTR;
        PC_Ctrl.Offset       <= PC_NEXT;
        ALU_Ctrl.Oper        <= ALU_POP;
        ALU_Ctrl.Reg         <= SubOp;

-------------------------------------------------------------------------------
-- Subroutines & Interrupts (RTS, JSR)
-------------------------------------------------------------------------------
      when WAI_Cx => -- For soft interrupts only, halt the Program_Ctr
        DP_Ctrl.Src          <= DATA_BUS_IDLE;
        if( Int_Req = '1' )then
          CPU_Next_State     <= ISR_C1;
          -- Rewind the PC by 3 to put the PC back to would have been the next
          --  instruction, compensating for the pipeline registers.
          PC_Ctrl.Offset     <= PC_REV3;
          -- Reset all of the sub-block controls to IDLE, to avoid unintended
          --  operation due to the current instruction
          DP_Ctrl.Src        <= DATA_RD_MEM;
        end if;

      when WAH_Cx => -- Holds until CPU_Halt_Req is deasserted.
        CPU_Halt_Ack         <= '1';
        DP_Ctrl.Src          <= DATA_BUS_IDLE;
        if( CPU_Halt_Req = '0' )then
          CPU_Next_State     <= IPF_C0;
          DP_Ctrl.Src        <= DATA_RD_MEM;
        end if;

      when BRK_C1 => -- Debugging (BRK) Performs a 5-clock NOP.
        CPU_Next_State       <= IPF_C0;

      when ISR_C1 =>
        CPU_Next_State       <= ISR_C2;
        INT_Ctrl.Incr_ISR    <= '1';

      when ISR_C2 =>
        CPU_Next_State       <= ISR_C3;
        DP_Ctrl.Src          <= DATA_WR_FLAG;

      when ISR_C3 =>
        CPU_Next_State       <= JSR_C1;
        Cache_Ctrl           <= CACHE_OPER1;
        ALU_Ctrl.Oper        <= ALU_STP;
        ALU_Ctrl.Reg         <= conv_std_logic_vector(PSR_I,3);
        SP_Ctrl.Oper         <= SP_PUSH;
        DP_Ctrl.Src          <= DATA_WR_PC;
        DP_Ctrl.Reg          <= PC_MSB;
        Ack_D                <= '1';

      when JSR_C1 =>
        CPU_Next_State       <= JSR_C2;
        Cache_Ctrl           <= CACHE_OPER2;
        SP_Ctrl.Oper         <= SP_PUSH;
        DP_Ctrl.Src          <= DATA_WR_PC;
        DP_Ctrl.Reg          <= PC_LSB;

      when JSR_C2 =>
        CPU_Next_State       <= IPF_C0;
        PC_Ctrl.Oper         <= PC_LOAD;
        SP_Ctrl.Oper         <= SP_PUSH;

      when RTS_C1 =>
        CPU_Next_State       <= RTS_C2;
        SP_Ctrl.Oper         <= SP_POP;

      when RTS_C2 =>
        CPU_Next_State       <= RTS_C3;
        -- if this is an RTI, then we need to POP the flags
        if( SubOp = SOP_RTI )then
          SP_Ctrl.Oper       <= SP_POP;
        end if;

      when RTS_C3 =>
        CPU_Next_State       <= RTS_C4;
        Cache_Ctrl           <= CACHE_OPER1;

      when RTS_C4 =>
        CPU_Next_State       <= RTS_C5;
        Cache_Ctrl           <= CACHE_OPER2;

      when RTS_C5 =>
        CPU_Next_State       <= IPF_C0;
        PC_Ctrl.Oper         <= PC_LOAD;
        -- if this is an RTI, then we need to clear the I bit
        if( SubOp = SOP_RTI )then
          CPU_Next_State     <= RTI_C6;
          Cache_Ctrl         <= CACHE_OPER1;
          ALU_Ctrl.Oper      <= ALU_CLP;
          ALU_Ctrl.Reg       <= conv_std_logic_vector(PSR_I,3);
        end if;

      when RTI_C6 =>
        CPU_Next_State       <= IPF_C1;
        PC_Ctrl.Offset       <= PC_NEXT;
        ALU_Ctrl.Oper        <= ALU_RFLG;

      when others =>
        null;
    end case;

  end process;

-------------------------------------------------------------------------------
-- Registered portion of CPU finite state machine
-------------------------------------------------------------------------------

  CPU_Regs: process( Reset, Clock )
    variable Offset_SX       : ADDRESS_TYPE;
    variable i_Ints          : INTERRUPT_BUNDLE := x"00";
    variable Index           : integer range 0 to 7         := 0;
    variable Sum             : std_logic_vector(8 downto 0) := "000000000";
    variable Temp            : std_logic_vector(8 downto 0) := "000000000";
  begin
    if( Reset = Reset_Level )then
      CPU_State              <= IPF_C0;
      Opcode                 <= OP_INC;
      SubOp                  <= ACCUM;
      SubOp_p1               <= ACCUM;
      Operand1               <= x"00";
      Operand2               <= x"00";
      Instr_Prefetch         <= '0';
      Prefetch               <= x"00";

      CPU_Halt_Req           <= '0';
      Halt_Ack               <= '0';

      Open8_Bus.Wr_En        <= '0';
      Open8_Bus.Wr_Data      <= OPEN8_NULLBUS;
      Open8_Bus.Rd_En        <= '1';

      Program_Ctr            <= Program_Start_Addr;
      Stack_Ptr              <= Stack_Start_Addr;

      Ack_Q                  <= '0';
      Ack_Q1                 <= '0';
      Int_Ack                <= '0';

      Int_Req                <= '0';
      Pending                <= x"00";
      Wait_for_FSM           <= '0';
      Wait_for_ISR           <= '0';
      Set_Mask               <= '0';
      if( Enable_NMI )then
        Int_Mask             <= Default_Interrupt_Mask(7 downto 1) & '1';
      else
        Int_Mask             <= Default_Interrupt_Mask;
      end if;
      ISR_Addr               <= INT_VECTOR_0;

      for i in 0 to 7 loop
        Regfile(i)           <= x"00";
      end loop;
      Flags                  <= x"00";
      if( Supervisor_Mode )then
        Flags(PSR_I)         <= '1';
      end if;

      Open8_Bus.GP_Flags     <= (others => '0');

    elsif( rising_edge(Clock) )then

      CPU_Halt_Req           <= Halt_Req;
      Halt_Ack               <= CPU_Halt_Ack;

      Open8_Bus.Wr_En        <= '0';
      Open8_Bus.Wr_Data      <= OPEN8_NULLBUS;
      Open8_Bus.Rd_En        <= '0';

-------------------------------------------------------------------------------
-- Instruction/Operand caching for pipelined memory access
-------------------------------------------------------------------------------
      CPU_State              <= CPU_Next_State;
      case Cache_Ctrl is
        when CACHE_INSTR =>
          Opcode             <= Rd_Data(7 downto 3);
          SubOp              <= Rd_Data(2 downto 0);
          SubOp_p1           <= Rd_Data(2 downto 0) + 1;
          if( Instr_Prefetch = '1' )then
            Opcode           <= Prefetch(7 downto 3);
            SubOp            <= Prefetch(2 downto 0);
            SubOp_p1         <= Prefetch(2 downto 0) + 1;
            Instr_Prefetch   <= '0';
          end if;

        when CACHE_OPER1 =>
          Operand1           <= Rd_Data;

        when CACHE_OPER2 =>
          Operand2           <= Rd_Data;

        when CACHE_PREFETCH =>
          Prefetch           <= Rd_Data;
          Instr_Prefetch     <= '1';

        when CACHE_IDLE =>
          null;
      end case;

-------------------------------------------------------------------------------
-- Program Counter
-------------------------------------------------------------------------------
      Offset_SX(15 downto 8) := (others => PC_Ctrl.Offset(7));
      Offset_SX(7 downto 0)  := PC_Ctrl.Offset;

      case PC_Ctrl.Oper is
        when PC_INCR =>
          Program_Ctr        <= Program_Ctr + Offset_SX - 2;

        when PC_LOAD =>
          Program_Ctr        <= Operand2 & Operand1;

        when others =>
          null;
      end case;

-------------------------------------------------------------------------------
-- (Write) Data Path
-------------------------------------------------------------------------------
      case DP_Ctrl.Src is
        when DATA_BUS_IDLE =>
          null;

        when DATA_RD_MEM =>
          Open8_Bus.Rd_En    <= '1';

        when DATA_WR_REG =>
          Open8_Bus.Wr_En    <= '1';
          Open8_Bus.Wr_Data  <= Regfile(conv_integer(DP_Ctrl.Reg));

        when DATA_WR_FLAG =>
          Open8_Bus.Wr_En    <= '1';
          Open8_Bus.Wr_Data  <= Flags;

        when DATA_WR_PC =>
          Open8_Bus.Wr_En    <= '1';
          Open8_Bus.Wr_Data  <= Program_Ctr(15 downto 8);
          if( DP_Ctrl.Reg = PC_LSB )then
            Open8_Bus.Wr_Data <= Program_Ctr(7 downto 0);
          end if;

        when others =>
          null;
      end case;

-------------------------------------------------------------------------------
-- Stack Pointer
-------------------------------------------------------------------------------
      case SP_Ctrl.Oper is
        when SP_IDLE =>
          null;

        when SP_CLR =>
          Stack_Ptr          <= Stack_Start_Addr;

        when SP_SET =>
          if( Supervisor_Mode )then
            if( Flags(PSR_I) = '1' )then
              Stack_Ptr      <= Regfile(1) & Regfile(0);
            end if;
          else
            Stack_Ptr        <= Regfile(1) & Regfile(0);
          end if;

        when SP_POP  =>
          Stack_Ptr          <= Stack_Ptr + 1;

        when SP_PUSH =>
          Stack_Ptr          <= Stack_Ptr - 1;

        when others =>
          null;

      end case;

-------------------------------------------------------------------------------
-- Interrupt Controller
-------------------------------------------------------------------------------

      -- If Supervisor_Mode is set, restrict the SMSK instruction such that it
      --  requires the I bit to be set.
      if( Supervisor_Mode )then
        Set_Mask             <= INT_Ctrl.Mask_Set and Flags(PSR_I);
      else
        Set_Mask             <= INT_Ctrl.Mask_Set;
      end if;

      -- The interrupt control mask is always sourced out of R0
      if( Set_Mask = '1' )then
        if( Enable_NMI )then
          Int_Mask           <= Regfile(conv_integer(ACCUM))(7 downto 1) & '1';
        else
          Int_Mask           <= Regfile(conv_integer(ACCUM));
        end if;
      end if;

      -- Combine external and internal interrupts, and mask the OR of the two
      --  with the mask. Record any incoming interrupts to the pending buffer
      i_Ints                 := (Interrupts or INT_Ctrl.Soft_Ints) and
                                Int_Mask;

      Pending                <= i_Ints or Pending;

      if( Sequential_Interrupts )then
        Wait_for_ISR         <= Flags(PSR_I);
      else
        Wait_for_ISR         <= '0';
      end if;

      if( Wait_for_FSM = '0' and Wait_for_ISR = '0' )then
        if(    Pending(0) = '1' )then
          ISR_Addr           <= INT_VECTOR_0;
          Pending(0)         <= '0';
        elsif( Pending(1) = '1' )then
          ISR_Addr           <= INT_VECTOR_1;
          Pending(1)         <= '0';
        elsif( Pending(2) = '1' )then
          ISR_Addr           <= INT_VECTOR_2;
          Pending(2)         <= '0';
        elsif( Pending(3) = '1' )then
          ISR_Addr           <= INT_VECTOR_3;
          Pending(3)         <= '0';
        elsif( Pending(4) = '1' )then
          ISR_Addr           <= INT_VECTOR_4;
          Pending(4)         <= '0';
        elsif( Pending(5) = '1' )then
          ISR_Addr           <= INT_VECTOR_5;
          Pending(5)         <= '0';
        elsif( Pending(6) = '1' )then
          ISR_Addr           <= INT_VECTOR_6;
          Pending(6)         <= '0';
        elsif( Pending(7) = '1' )then
          ISR_Addr           <= INT_VECTOR_7;
          Pending(7)         <= '0';
        end if;
        Wait_for_FSM         <= or_reduce(Pending);
      end if;

      -- Reset the Wait_for_FSM flag on Int_Ack
      Ack_Q                  <= Ack_D;
      Ack_Q1                 <= Ack_Q;
      Int_Ack                <= Ack_Q1;
      if( Int_Ack = '1' )then
        Wait_for_FSM         <= '0';
      end if;

      Int_Req                <= Wait_for_FSM and (not Int_Ack);

      -- Incr_ISR allows the CPU Core to advance the vector address to pop the
      --  lower half of the address.
      if( INT_Ctrl.Incr_ISR = '1' )then
        ISR_Addr             <= ISR_Addr + 1;
      end if;

-------------------------------------------------------------------------------
-- ALU (Arithmetic / Logic Unit)
-------------------------------------------------------------------------------
      Index                  := conv_integer(ALU_Ctrl.Reg);
      Sum                    := (others => '0');
      Temp                   := (others => '0');

      case ALU_Ctrl.Oper is
        when ALU_INC => -- Rn = Rn + 1 : Flags N,C,Z
          Sum                := ("0" & x"01") +
                                ("0" & Regfile(Index));
          Flags(PSR_Z)       <= nor_reduce(Sum(7 downto 0));
          Flags(PSR_C)       <= Sum(8);
          Flags(PSR_N)       <= Sum(7);
          Regfile(Index)     <= Sum(7 downto 0);

        when ALU_UPP => -- Rn = Rn + 1
          Sum                := ("0" & x"01") +
                                ("0" & Regfile(Index));
          Flags(PSR_C)       <= Sum(8);
          Regfile(Index)     <= Sum(7 downto 0);

        when ALU_UPP2 => -- Rn = Rn + C
          Sum                := ("0" & x"00") +
                                ("0" & Regfile(Index)) +
                                Flags(PSR_C);
          Flags(PSR_C)       <= Sum(8);
          Regfile(Index)     <= Sum(7 downto 0);

        when ALU_ADC => -- R0 = R0 + Rn + C : Flags N,C,Z
          Sum                := ("0" & Regfile(0)) +
                                ("0" & Regfile(Index)) +
                                Flags(PSR_C);
          Flags(PSR_Z)       <= nor_reduce(Sum(7 downto 0));
          Flags(PSR_C)       <= Sum(8);
          Flags(PSR_N)       <= Sum(7);
          Regfile(0)         <= Sum(7 downto 0);

        when ALU_TX0 => -- R0 = Rn : Flags N,Z
          Temp               := "0" & Regfile(Index);
          Flags(PSR_Z)       <= nor_reduce(Temp(7 downto 0));
          Flags(PSR_N)       <= Temp(7);
          Regfile(0)         <= Temp(7 downto 0);

        when ALU_OR  => -- R0 = R0 | Rn : Flags N,Z
          Temp(7 downto 0)   := Regfile(0) or Regfile(Index);
          Flags(PSR_Z)       <= nor_reduce(Temp(7 downto 0));
          Flags(PSR_N)       <= Temp(7);
          Regfile(0)         <= Temp(7 downto 0);

        when ALU_AND => -- R0 = R0 & Rn : Flags N,Z
          Temp(7 downto 0)   := Regfile(0) and Regfile(Index);
          Flags(PSR_Z)       <= nor_reduce(Temp(7 downto 0));
          Flags(PSR_N)       <= Temp(7);
          Regfile(0)         <= Temp(7 downto 0);

        when ALU_XOR => -- R0 = R0 ^ Rn : Flags N,Z
          Temp(7 downto 0)   := Regfile(0) xor Regfile(Index);
          Flags(PSR_Z)       <= nor_reduce(Temp(7 downto 0));
          Flags(PSR_N)       <= Temp(7);
          Regfile(0)         <= Temp(7 downto 0);

        when ALU_ROL => -- Rn = Rn<<1,C : Flags N,C,Z
          Temp               := Regfile(Index) & Flags(PSR_C);
          Flags(PSR_Z)       <= nor_reduce(Temp(7 downto 0));
          Flags(PSR_C)       <= Temp(8);
          Flags(PSR_N)       <= Temp(7);
          Regfile(Index)     <= Temp(7 downto 0);

        when ALU_ROR => -- Rn = C,Rn>>1 : Flags N,C,Z
          Temp               := Regfile(Index)(0) & Flags(PSR_C) &
                                Regfile(Index)(7 downto 1);
          Flags(PSR_Z)       <= nor_reduce(Temp(7 downto 0));
          Flags(PSR_C)       <= Temp(8);
          Flags(PSR_N)       <= Temp(7);
          Regfile(Index)     <= Temp(7 downto 0);

        when ALU_DEC => -- Rn = Rn - 1 : Flags N,C,Z
          Sum                := ("0" & Regfile(Index)) +
                                ("0" & x"FF");
          Flags(PSR_Z)       <= nor_reduce(Sum(7 downto 0));
          Flags(PSR_C)       <= Sum(8);
          Flags(PSR_N)       <= Sum(7);
          Regfile(Index)     <= Sum(7 downto 0);

        when ALU_SBC => -- Rn = R0 - Rn - C : Flags N,C,Z
          Sum                := ("0" & Regfile(0)) +
                                ("1" & (not Regfile(Index))) +
                                Flags(PSR_C);
          Flags(PSR_Z)       <= nor_reduce(Sum(7 downto 0));
          Flags(PSR_C)       <= Sum(8);
          Flags(PSR_N)       <= Sum(7);
          Regfile(0)         <= Sum(7 downto 0);

        when ALU_ADD => -- R0 = R0 + Rn : Flags N,C,Z
          Sum                := ("0" & Regfile(0)) +
                                ("0" & Regfile(Index));
          Flags(PSR_C)       <= Sum(8);
          Regfile(0)         <= Sum(7 downto 0);
          Flags(PSR_Z)       <= nor_reduce(Sum(7 downto 0));
          Flags(PSR_N)       <= Sum(7);

        when ALU_STP => -- Sets bit(n) in the Flags register
          Flags(Index)       <= '1';

        when ALU_BTT => -- Z = !R0(N), N = R0(7)
          Flags(PSR_Z)       <= not Regfile(0)(Index);
          Flags(PSR_N)       <= Regfile(0)(7);

        when ALU_CLP => -- Clears bit(n) in the Flags register
          Flags(Index)       <= '0';

        when ALU_T0X => -- Rn = R0 : Flags N,Z
          Temp               := "0" & Regfile(0);
          Flags(PSR_Z)       <= nor_reduce(Temp(7 downto 0));
          Flags(PSR_N)       <= Temp(7);
          Regfile(Index)     <= Temp(7 downto 0);

        when ALU_CMP => -- Sets Flags on R0 - Rn : Flags N,C,Z
          Sum                := ("0" & Regfile(0)) +
                                ("1" & (not Regfile(Index))) +
                                '1';
          Flags(PSR_Z)       <= nor_reduce(Sum(7 downto 0));
          Flags(PSR_C)       <= Sum(8);
          Flags(PSR_N)       <= Sum(7);

        when ALU_MUL => -- Stage 1 of 2 {R1:R0} = R0 * Rn : Flags Z
          Regfile(0)         <= Mult(7 downto 0);
          Regfile(1)         <= Mult(15 downto 8);
          Flags(PSR_Z)       <= nor_reduce(Mult);

        when ALU_LDI => -- Rn <= Data : Flags N,Z
          Flags(PSR_Z)       <= nor_reduce(Operand1);
          Flags(PSR_N)       <= Operand1(7);
          Regfile(Index)     <= Operand1;

        when ALU_POP => -- Rn <= Data
          Regfile(Index)     <= Operand1;

        when ALU_RFLG =>
          Flags(3 downto 0)  <= Operand1(3 downto 0);
          if( not RTI_Ignores_GP_Flags )then
            Flags(7 downto 4)<= Operand1(7 downto 4);
          end if;

        when ALU_RSP =>
          Regfile(0)         <= Stack_Ptr(7 downto 0);
          Regfile(1)         <= Stack_Ptr(15 downto 8);

        when ALU_GMSK =>
          Flags(PSR_Z)       <= nor_reduce(Int_Mask);
          Regfile(0)         <= Int_Mask;

        when others =>
          null;
      end case;

      Open8_Bus.GP_Flags     <= Flags(7 downto 3);

    end if;
  end process;

-------------------------------------------------------------------------------
-- Multiplier Logic
--
-- We need to infer a hardware multipler, so we create a special clocked
--  process with no reset or clock enable
-------------------------------------------------------------------------------

  Multiplier_proc: process( Clock )
  begin
    if( rising_edge(Clock) )then
      Mult                   <= Regfile(0) *
                                Regfile(conv_integer(ALU_Ctrl.Reg));
    end if;
  end process;

end architecture;