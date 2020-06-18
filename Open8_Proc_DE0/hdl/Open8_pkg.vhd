-- Copyright (c)2006,2011,2012,2013,2015,2020 Jeremy Seth Henry
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

-- VHDL Units :  Open8_pkg
-- Description:  Contains constant definitions for the Open8 processor
--
-- Revision History
-- Author          Date     Change
------------------ -------- ---------------------------------------------------
-- Seth Henry      07/22/06 Design Start
-- Seth Henry      02/03/12 Updated generics to match current model
-- Seth Henry      10/29/15 Migrated type/constant definitions to this file
-- Seth Henry      03/09/20 Created new ALU/SP opcodes for handling new RSP
-- Seth Henry      03/12/20 Rationalized the naming of the CPU flags to match
--                           the assembler names. Also removed superfluous
--                           signals in the ALU and PC records.
-- Seth Henry      03/17/20 Added new subtype and constants for external
--                           GP flags.
-- Seth Henry      03/18/20 Added the ceil_log2 function, since it is used in
--                           memory sizing calculations.
-- Seth Henry      04/09/20 Added the I bit to the exported flags for use in
--                           memory protection schemes.
-- Seth Henry      04/16/20 Added the OPEN8_BUS_TYPE record to simplify
--                           peripheral connections.

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;

package Open8_pkg is

-------------------------------------------------------------------------------
-- External constants and type declarations
--
-- These subtypes can be used with external peripherals to simplify
--  connection to the core.
-------------------------------------------------------------------------------

  -- These must never be changed, as the core requires them to be these static
  --  values for proper operation. These are ONLY defined here to allow user
  --  code to dynamically configure itself to match the Open8 core.

  constant OPEN8_ADDR_WIDTH  : integer := 16; -- DON'T EVEN CONTEMPLATE
  constant OPEN8_DATA_WIDTH  : integer := 8;  -- CHANGING THESE!

  subtype ADDRESS_TYPE is std_logic_vector(OPEN8_ADDR_WIDTH - 1 downto 0);
  subtype DATA_TYPE    is std_logic_vector(OPEN8_DATA_WIDTH - 1 downto 0);
  -- Note: INTERRUPT_BUNDLE must be exactly the same width as DATA_TYPE
  subtype INTERRUPT_BUNDLE is DATA_TYPE;

  subtype EXT_GP_FLAGS is std_logic_vector(4 downto 0);

  constant EXT_ISR           : integer := 0;
  constant EXT_GP4           : integer := 1;
  constant EXT_GP5           : integer := 2;
  constant EXT_GP6           : integer := 3;
  constant EXT_GP7           : integer := 4;

  constant OPEN8_NULLBUS     : DATA_TYPE := x"00";

  constant Reset_Level       : std_logic := '1';

  type OPEN8_BUS_TYPE is record
    Clock                    : std_logic;
    Reset                    : std_logic;
    uSec_Tick                : std_logic;
    Address                  : ADDRESS_TYPE;
    Wr_En                    : std_logic;
    Wr_Data                  : DATA_TYPE;
    Rd_En                    : std_logic;
    GP_Flags                 : EXT_GP_FLAGS;
  end record;

  constant INIT_OPEN8_BUS    : OPEN8_BUS_TYPE := (
                                 '0',           -- Clock
                                 Reset_Level,   -- Reset
                                 '0',           -- uSec_Tick
                                 x"0000",       -- Address
                                 '0',           -- Wr_En
                                 OPEN8_NULLBUS, -- Wr_Data
                                 '0',           -- Rd_En
                                 "00000"        -- GP_Flags
                               );

  -- Component declaration
  --  (assumes a 1K RAM at 0x0000 and ROM at the top of the memory map)
  component o8_cpu is
  generic(
    Program_Start_Addr       : ADDRESS_TYPE := x"8000";
    ISR_Start_Addr           : ADDRESS_TYPE := x"FFF0";
    Stack_Start_Addr         : ADDRESS_TYPE := x"03FF";
    Allow_Stack_Address_Move : boolean      := false;
    Stack_Xfer_Flag          : integer      := 4;
    Enable_Auto_Increment    : boolean      := false;
    BRK_Implements_WAI       : boolean      := false;
    Enable_NMI               : boolean      := true;
    RTI_Ignores_GP_Flags     : boolean      := false;
    Default_Interrupt_Mask   : DATA_TYPE    := x"FF";
    Clock_Frequency          : real
  );
  port(
    Clock                    : in  std_logic;
    PLL_Locked               : in  std_logic;
    Halt_Req                 : in  std_logic := '0';
    Halt_Ack                 : out std_logic;
    Open8_Bus                : out OPEN8_BUS_TYPE;
    Rd_Data                  : in  DATA_TYPE;
    Interrupts               : in  INTERRUPT_BUNDLE := x"00"
  );
  end component;

  -- This function is used to calculate RAM parameters, but is generally
  --  useful for making things more generic.
  function ceil_log2 (x : in natural) return natural;

-------------------------------------------------------------------------------
-- Internal constants and type declarations.
--
-- These are only used in the actual model, and aren't generally useful for
--  external application.
-------------------------------------------------------------------------------

  subtype OPCODE_TYPE  is std_logic_vector(4 downto 0);
  subtype SUBOP_TYPE   is std_logic_vector(2 downto 0);

  -- All opcodes should be identical to the opcode used by the assembler
  -- In this case, they match the original V8/ARC uRISC ISA
  constant OP_INC            : OPCODE_TYPE := "00000";
  constant OP_ADC            : OPCODE_TYPE := "00001";
  constant OP_TX0            : OPCODE_TYPE := "00010";
  constant OP_OR             : OPCODE_TYPE := "00011";
  constant OP_AND            : OPCODE_TYPE := "00100";
  constant OP_XOR            : OPCODE_TYPE := "00101";
  constant OP_ROL            : OPCODE_TYPE := "00110";
  constant OP_ROR            : OPCODE_TYPE := "00111";
  constant OP_DEC            : OPCODE_TYPE := "01000";
  constant OP_SBC            : OPCODE_TYPE := "01001";
  constant OP_ADD            : OPCODE_TYPE := "01010";
  constant OP_STP            : OPCODE_TYPE := "01011";
  constant OP_BTT            : OPCODE_TYPE := "01100";
  constant OP_CLP            : OPCODE_TYPE := "01101";
  constant OP_T0X            : OPCODE_TYPE := "01110";
  constant OP_CMP            : OPCODE_TYPE := "01111";
  constant OP_PSH            : OPCODE_TYPE := "10000";
  constant OP_POP            : OPCODE_TYPE := "10001";
  constant OP_BR0            : OPCODE_TYPE := "10010";
  constant OP_BR1            : OPCODE_TYPE := "10011";
  constant OP_DBNZ           : OPCODE_TYPE := "10100"; -- USR
  constant OP_INT            : OPCODE_TYPE := "10101";
  constant OP_MUL            : OPCODE_TYPE := "10110"; -- USR2
  constant OP_STK            : OPCODE_TYPE := "10111";
  constant OP_UPP            : OPCODE_TYPE := "11000";
  constant OP_STA            : OPCODE_TYPE := "11001";
  constant OP_STX            : OPCODE_TYPE := "11010";
  constant OP_STO            : OPCODE_TYPE := "11011";
  constant OP_LDI            : OPCODE_TYPE := "11100";
  constant OP_LDA            : OPCODE_TYPE := "11101";
  constant OP_LDX            : OPCODE_TYPE := "11110";
  constant OP_LDO            : OPCODE_TYPE := "11111";

  -- OP_STK uses the lower 3 bits to further refine the instruction by
  --  repurposing the source register field. These "sub opcodes" take
  --  the place of the register select for the OP_STK opcode
  constant SOP_RSP           : SUBOP_TYPE := "000";
  constant SOP_RTS           : SUBOP_TYPE := "001";
  constant SOP_RTI           : SUBOP_TYPE := "010";
  constant SOP_BRK           : SUBOP_TYPE := "011";
  constant SOP_JMP           : SUBOP_TYPE := "100";
  constant SOP_SMSK          : SUBOP_TYPE := "101";
  constant SOP_GMSK          : SUBOP_TYPE := "110";
  constant SOP_JSR           : SUBOP_TYPE := "111";

  type CPU_STATES is (
      -- Instruction fetch & Decode
    IPF_C0, IPF_C1, IPF_C2, IDC_C0,
    -- Branching
    BRN_C1, DBNZ_C1, JMP_C1, JMP_C2,
    -- Loads
    LDA_C1, LDA_C2, LDA_C3, LDA_C4, LDI_C1,
    LDO_C1, LDX_C1, LDX_C2, LDX_C3, LDX_C4,
    -- Stores
    STA_C1, STA_C2, STA_C3, STO_C1, STO_C2, STX_C1, STX_C2,
    -- 2-cycle math
    MUL_C1, UPP_C1,
    -- Stack
    PSH_C1, POP_C1, POP_C2, POP_C3, POP_C4,
    -- Subroutines & Interrupts
    WAI_Cx, WAH_Cx, BRK_C1,
    ISR_C1, ISR_C2, ISR_C3, JSR_C1, JSR_C2,
    RTS_C1, RTS_C2, RTS_C3, RTS_C4, RTS_C5, RTI_C6
     );

  type CACHE_MODES is (CACHE_IDLE, CACHE_INSTR, CACHE_OPER1, CACHE_OPER2,
                       CACHE_PREFETCH );

  type PC_MODES is ( PC_INCR, PC_LOAD );

  type PC_CTRL_TYPE is record
    Oper                     : PC_MODES;
    Offset                   : DATA_TYPE;
  end record;

  -- These are fixed constant offsets to the program counter logic, which is
  --  always either incrementing or loading.
  constant PC_NEXT           : DATA_TYPE := x"03";
  constant PC_IDLE           : DATA_TYPE := x"02";
  constant PC_REV1           : DATA_TYPE := x"01";
  constant PC_REV2           : DATA_TYPE := x"00";
  constant PC_REV3           : DATA_TYPE := x"FF";

  type SP_MODES is ( SP_IDLE, SP_CLR, SP_SET, SP_POP, SP_PUSH );

  type SP_CTRL_TYPE is record
    Oper                     : SP_MODES;
  end record;

  type DP_MODES is ( DATA_BUS_IDLE, DATA_RD_MEM,
                     DATA_WR_REG, DATA_WR_FLAG, DATA_WR_PC );

  type DATA_CTRL_TYPE is record
    Src                      : DP_MODES;
    Reg                      : SUBOP_TYPE;
  end record;

  constant PC_LSB            : SUBOP_TYPE := "000";
  constant PC_MSB            : SUBOP_TYPE := "001";

  type INT_CTRL_TYPE is record
    Mask_Set                 : std_logic;
    Soft_Ints                : INTERRUPT_BUNDLE;
    Incr_ISR                 : std_logic;
  end record;

  -- Most of the ALU instructions are the same as their Opcode equivalents,
  --  with exceptions for IDLE, UPP2, RFLG, RSP, and GMSK, which perform
  --  internal operations not otherwise exposed by the instruction set.
  constant ALU_INC           : OPCODE_TYPE := "00000"; -- x"00"
  constant ALU_ADC           : OPCODE_TYPE := "00001"; -- x"01"
  constant ALU_TX0           : OPCODE_TYPE := "00010"; -- x"02"
  constant ALU_OR            : OPCODE_TYPE := "00011"; -- x"03"
  constant ALU_AND           : OPCODE_TYPE := "00100"; -- x"04"
  constant ALU_XOR           : OPCODE_TYPE := "00101"; -- x"05"
  constant ALU_ROL           : OPCODE_TYPE := "00110"; -- x"06"
  constant ALU_ROR           : OPCODE_TYPE := "00111"; -- x"07"
  constant ALU_DEC           : OPCODE_TYPE := "01000"; -- x"08"
  constant ALU_SBC           : OPCODE_TYPE := "01001"; -- x"09"
  constant ALU_ADD           : OPCODE_TYPE := "01010"; -- x"0A"
  constant ALU_STP           : OPCODE_TYPE := "01011"; -- x"0B"
  constant ALU_BTT           : OPCODE_TYPE := "01100"; -- x"0C"
  constant ALU_CLP           : OPCODE_TYPE := "01101"; -- x"0D"
  constant ALU_T0X           : OPCODE_TYPE := "01110"; -- x"0E"
  constant ALU_CMP           : OPCODE_TYPE := "01111"; -- x"0F"
  constant ALU_POP           : OPCODE_TYPE := "10001"; -- x"11"
  constant ALU_MUL           : OPCODE_TYPE := "10110"; -- x"16"
  constant ALU_UPP           : OPCODE_TYPE := "11000"; -- x"18"
  constant ALU_LDI           : OPCODE_TYPE := "11100"; -- x"1C"

  constant ALU_IDLE          : OPCODE_TYPE := "10000"; -- x"10"
  constant ALU_UPP2          : OPCODE_TYPE := "10010"; -- x"12"
  constant ALU_RFLG          : OPCODE_TYPE := "10011"; -- x"13"
  constant ALU_RSP           : OPCODE_TYPE := "10111"; -- x"17"
  constant ALU_GMSK          : OPCODE_TYPE := "11111"; -- x"1F"

  -- These should match the assembler's definitions for the flags
  constant PSR_Z             : integer := 0;
  constant PSR_C             : integer := 1;
  constant PSR_N             : integer := 2;
  constant PSR_I             : integer := 3;
  constant PSR_GP4           : integer := 4;
  constant PSR_GP5           : integer := 5;
  constant PSR_GP6           : integer := 6;
  constant PSR_GP7           : integer := 7;

  type ALU_CTRL_TYPE is record
    Oper                     : OPCODE_TYPE;
    Reg                      : SUBOP_TYPE;
  end record;

  constant ACCUM             : SUBOP_TYPE := "000";

  type REGFILE_TYPE is array (0 to 7) of DATA_TYPE;

  subtype FLAG_TYPE is DATA_TYPE;

end package;

package body Open8_pkg is

  -- The ceil_log2 function returns the minimum register width required to
  --  hold the supplied integer.
  function ceil_log2 (x : in natural) return natural is
    variable retval          : natural;
  begin
    retval                   := 1;
    while ((2**retval) - 1) < x loop
      retval                 := retval + 1;
    end loop;
    return retval;
  end function;

end package body;
