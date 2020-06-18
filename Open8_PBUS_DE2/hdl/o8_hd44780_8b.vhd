-- Copyright (c)2013, 2020 Jeremy Seth Henry
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
-- VHDL Entity: o8_hd44780_8b
-- Description: Provides low-level access to a "standard" character LCD using
--               the ST/HD44780(U) control ASIC wired in full (8-bit) mode.
--              All low-level timing of the control signals are handled by
--               this module, allowing client firmware to use a simple
--               register interface to program the LCD panel.
--              Init routine initializes the display and displays a single
--               character to demonstrate correct function, then listens for
--               user data on its external interface.
--
-- Register Map
-- Address  Function
-- Offset  Bitfield Description                        Read/Write
-- 0x0     AAAAAAAA LCD Register Write                 (Write-only)
-- 0x1     AAAAAAAA LCD Data Write                     (Write-only)
-- 0x2     AAAAAAAA LCD Contrast                       (Read-Write)
-- 0x3     AAAAAAAA LCD Backlight                      (Read-Write)
--
--------------------------------------------------------------------------------
-- LCD Controller
--------------------------------------------------------------------------------
--
-- LCD Instruction Set
-- Instruction             RS  RW  D7  D6  D5  D4  D3  D2  D1  D0  Time
------------------------------------------------------------------------
-- Clear Display         | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1 | 1.52mS
-- Return Home           | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1 | x | 1.52mS
-- Entry Mode            | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1 | ID| S |   37uS
-- Display Pwr           | 0 | 0 | 0 | 0 | 0 | 0 | 1 | D | C | B |   37uS
-- Cursor/Display Shift  | 0 | 0 | 0 | 0 | 0 | 1 | SC| RL| x | x |   37uS
-- Function Set          | 0 | 0 | 0 | 0 | 1 | DL| N | F | x | x |   37uS
-- Set CGRAM Address     | 0 | 0 | 0 | 1 | A | A | A | A | A | A |   37uS
-- Set DDRAM Address     | 0 | 0 | 1 | A | A | A | A | A | A | A |   37uS

-- Notes:
-- ID = Increment/Decrement DDRAM Address (1 = increment, 0 = decrement)
-- S  = Shift Enable (1 = Shift display according to ID, 0 = Don't shift)
-- D  = Display On/Off (1 = on, 0 = off)
-- C  = Cursor On/Off  (1 = on, 0 = off)
-- B  = Cursor Blink   (1 = block cursor, 0 = underline cursor)
-- SC / RL = Shift Cursor/Display Right/Left (see data sheet - not needed for init)
-- F  = Font (0 = 5x8, 1 = 5x11) Ignored on 2-line displays (N = 1)
-- N  = Number of Lines (0 = 1 lines, 1 = 2 lines)
-- DL = Data Length (0 = 4-bit bus, 1 = 8-bit bus) This is fixed at 1 in this module
-- A  = Address (see data sheet for usage)
--
-- Revision History
-- Author          Date     Change
------------------ -------- ---------------------------------------------------
-- Seth Henry      01/22/13 Design Start
-- Seth Henry      04/10/20 Code & comment cleanup
-- Seth Henry      04/16/20 Modified to use Open8 bus record

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

library work;
use work.open8_pkg.all;

entity o8_hd44780_8b is
generic(
  Use_Contrast          : boolean;
  Default_Contrast      : std_logic_vector(7 downto 0);
  Use_Backlight         : boolean;
  Default_Brightness    : std_logic_vector(7 downto 0);
  Clock_Frequency       : real;
  Address               : ADDRESS_TYPE
);
port(
  Open8_Bus             : in  OPEN8_BUS_TYPE;
  Rd_Data               : out DATA_TYPE;
  Interrupt             : out std_logic;
  --
  LCD_E                 : out std_logic;
  LCD_RW                : out std_logic;
  LCD_RS                : out std_logic;
  LCD_D                 : out std_logic_vector(7 downto 0);
  LCD_CN                : out std_logic;
  LCD_BL                : out std_logic
);
end entity;

architecture behave of o8_hd44780_8b is

  alias Clock                is Open8_Bus.Clock;
  alias Reset                is Open8_Bus.Reset;
  alias uSec_Tick            is Open8_Bus.uSec_Tick;

  constant User_Addr         : std_logic_vector(15 downto 2)
                               := Address(15 downto 2);
  alias  Comp_Addr           is Open8_Bus.Address(15 downto 2);
  signal Addr_Match          : std_logic := '0';

  alias  Reg_Addr             is Open8_Bus.Address(1 downto 0);
  signal Reg_Addr_q          : std_logic_vector(1 downto 0) := (others => '0');

  signal Wr_En               : std_logic := '0';
  signal Wr_Data_q           : DATA_TYPE := x"00";
  signal Rd_En               : std_logic := '0';

  signal Reg_Valid           : std_logic := '0';
  signal Reg_Sel             : std_logic := '0';
  signal Reg_Data            : DATA_TYPE := x"00";

  signal Tx_Ready            : std_logic := '0';

  constant LCD_CONFIG1       : std_logic_vector(7 downto 0) := x"38"; -- Set 4-bit, 2-line mode
  constant LCD_CONFIG2       : std_logic_vector(7 downto 0) := x"0C"; -- Turn display on, no cursor
  constant LCD_CONFIG3       : std_logic_vector(7 downto 0) := x"01"; -- Clear display
  constant LCD_CONFIG4       : std_logic_vector(7 downto 0) := x"06"; -- Positive increment, no shift
  constant LCD_CONFIG5       : std_logic_vector(7 downto 0) := x"2A"; -- Print a "*"
  constant LCD_CONFIG6       : std_logic_vector(7 downto 0) := x"02"; -- Reset the cursor

  signal init_count          : std_logic_vector(2 downto 0) := (others => '0');

  constant INIT_40MS         : integer := 40000;
  constant INIT_BITS         : integer := ceil_log2(INIT_40MS);
  constant INIT_DELAY        : std_logic_vector(INIT_BITS-1 downto 0) :=
                               conv_std_logic_vector(INIT_40MS,INIT_BITS);

-- For "long" instructions, such as clear display and return home, we need to wait for more
--  than 1.52mS. Experimentally, 2mS seems to work ideally, and for init this isn't an issue
  constant CLDSP_2MS         : integer := 2000;
  constant CLDSP_DELAY       : std_logic_vector(INIT_BITS-1 downto 0) :=
                               conv_std_logic_vector(CLDSP_2MS,INIT_BITS);

 -- For some reason, we are required to wait 80uS before checking the busy flag, despite
 --  most instructions completing in 37uS. No clue as to why, but it works
  constant BUSY_50US         : integer := 50;
  constant BUSY_DELAY        : std_logic_vector(INIT_BITS-1 downto 0) :=
                               conv_std_logic_vector(BUSY_50US-1, INIT_BITS);

  signal busy_timer          : std_logic_vector(INIT_BITS-1 downto 0) := (others => '0');

  constant SNH_600NS         : integer := integer(Clock_Frequency * 0.000000600);
  constant SNH_BITS          : integer := ceil_log2(SNH_600NS);
  constant SNH_DELAY         : std_logic_vector(SNH_BITS-1 downto 0) :=
                               conv_std_logic_vector(SNH_600NS-1, SNH_BITS);

  signal io_timer            : std_logic_vector(SNH_BITS - 1 downto 0) := (others => '0');

  type IO_STATES is (INIT, FN_JUMP, IDLE,
                     WR_PREP, WR_SETUP, WR_HOLD,
                     BUSY_PREP, BUSY_WAIT,
                     ISSUE_INT );
  signal io_state            : IO_STATES;

  signal LCD_Data            : DATA_TYPE := x"00";
  signal LCD_Addr            : std_logic := '0';

--------------------------------------------------------------------------------
-- Backlight & Contrast signals
--------------------------------------------------------------------------------

  signal LCD_Contrast        : DATA_TYPE := x"00";
  signal LCD_Bright          : DATA_TYPE := x"00";

begin

--------------------------------------------------------------------------------
-- Open8 Register interface
--------------------------------------------------------------------------------

  Addr_Match                 <= '1' when Comp_Addr = User_Addr else '0';

  io_reg: process( Clock, Reset )
  begin
    if( Reset = Reset_Level )then
      Reg_Addr_q             <= (others => '0');
      Wr_Data_q              <= (others => '0');
      Wr_En                  <= '0';
      Rd_En                  <= '0';
      Rd_Data                <= OPEN8_NULLBUS;

      Reg_Valid              <= '0';
      Reg_Sel                <= '0';
      Reg_Data               <= x"00";

      LCD_Contrast           <= Default_Contrast;
      LCD_Bright             <= Default_Brightness;
    elsif( rising_edge( Clock ) )then
      Reg_Addr_q             <= Reg_Addr;

      Wr_Data_q              <= Open8_Bus.Wr_Data;
      Wr_En                  <= Addr_Match and Open8_Bus.Wr_En;

      Reg_Valid              <= '0';

      if( Wr_En = '1' )then
        case( Reg_Addr_q )is
          when "00" | "01" =>
            Reg_Valid        <= '1';
            Reg_Sel          <= Reg_Addr_q(0);
            Reg_Data         <= Wr_Data_q;
          when "10" =>
            LCD_Contrast     <= Wr_Data_q;
          when "11" =>
            LCD_Bright       <= Wr_Data_q;
          when others => null;
        end case;
      end if;

      Rd_Data                <= OPEN8_NULLBUS;
      Rd_En                  <= Addr_Match and Open8_Bus.Rd_En;
      if( Rd_En = '1' )then
        case( Reg_Addr_q )is
          when "00" | "01" =>
            Rd_Data(7)       <= Tx_Ready;
          when "10" =>
            Rd_Data          <= LCD_Contrast;
          when "11" =>
            Rd_Data          <= LCD_Bright;
          when others => null;
        end case;
      end if;
    end if;
  end process;

--------------------------------------------------------------------------------
-- LCD and Register logic
--------------------------------------------------------------------------------

  LCD_RW                     <= '0'; -- Permanently wire the RW line low

  LCD_IO: process( Clock, Reset )
  begin
    if( Reset = Reset_Level )then
      io_state               <= INIT;
      init_count             <= (others => '0');
      io_timer               <= (others => '0');
      busy_timer             <= (others => '0');
      LCD_Data               <= (others => '0');
      LCD_Addr               <= '0';
      LCD_E                  <= '0';
      LCD_RS                 <= '0';
      LCD_D                  <= (others => '0');
      Tx_Ready               <= '0';
      Interrupt              <= '0';
    elsif( rising_edge(Clock) )then
      LCD_E                  <= '0';
      LCD_RS                 <= '0';
      LCD_D                  <= (others => '0');
      Tx_Ready               <= '0';
      Interrupt              <= '0';
      io_timer               <= io_timer - 1;
      busy_timer             <= busy_timer - uSec_Tick;
      case( io_state )is

        when INIT =>
          busy_timer         <= INIT_DELAY;
          init_count         <= (others => '1');
          io_state           <= BUSY_WAIT;

        when FN_JUMP =>
          io_state           <= WR_PREP;
          case( init_count )is
            when "000" =>
              io_state       <= IDLE;
            when "001" =>
              LCD_Addr       <= '0';
              LCD_Data       <= LCD_CONFIG6; -- Reset the Cursor
            when "010" =>
              LCD_Addr       <= '1';         -- Print a "*", and
              LCD_Data       <= LCD_CONFIG5; --  set RS to 1
            when "011" =>
              LCD_Data       <= LCD_CONFIG4; -- Entry mode
            when "100" =>
              LCD_Data       <= LCD_CONFIG3; -- Clear Display
            when "101" =>
              LCD_Data       <= LCD_CONFIG2; -- Display control
            when "110" | "111" =>
              LCD_Addr       <= '0';
              LCD_Data       <= LCD_CONFIG1; -- Function set
            when others => null;
          end case;

        when IDLE =>
          Tx_Ready           <= '1';
          if( Reg_Valid = '1' )then
            LCD_Addr         <= Reg_Sel;
            LCD_Data         <= Reg_Data;
            io_state         <= WR_PREP;
          end if;

        when WR_PREP =>
          io_timer           <= SNH_DELAY;
          io_state           <= WR_SETUP;

        when WR_SETUP =>
          LCD_RS             <= LCD_Addr;
          LCD_D              <= LCD_Data;
          LCD_E              <= '1';
          if( io_timer = 0 )then
            io_timer         <= SNH_DELAY;
            io_state         <= WR_HOLD;
          end if;

        when WR_HOLD =>
          LCD_RS             <= LCD_Addr;
          LCD_D              <= LCD_Data;
          if( io_timer = 0 )then
            LCD_E            <= '0';
            io_state         <= BUSY_PREP;
          end if;

        when BUSY_PREP =>
          busy_timer         <= BUSY_DELAY;
          if( LCD_Addr = '0' and LCD_Data < 4 )then
            busy_timer       <= CLDSP_DELAY;
          end if;
          io_state           <= BUSY_WAIT;

        when BUSY_WAIT =>
          if( busy_timer = 0 )then
            io_state         <= ISSUE_INT;
            if( init_count > 0 )then
              init_count     <= init_count - 1;
              io_state       <= FN_JUMP;
            end if;
          end if;

        when ISSUE_INT =>
          Interrupt          <= '1';
          io_state           <= IDLE;

        when others => null;

      end case;

    end if;
  end process;

--------------------------------------------------------------------------------
-- Contrast control logic (optional)
--------------------------------------------------------------------------------

Contrast_Disabled: if( not Use_Contrast )generate
  LCD_CN                     <= '0';
end generate;

Contrast_Enabled: if( Use_Contrast )generate

  U_CN : entity work.vdsm8
  generic map(
    Reset_Level              => Reset_Level
  )
  port map(
    Clock                    => Clock,
    Reset                    => Reset,
    DACin                    => LCD_Contrast,
    DACout                   => LCD_CN
  );

end generate;

--------------------------------------------------------------------------------
-- Backlight control logic (optional)
--------------------------------------------------------------------------------

Backlight_Disabled: if( not Use_Backlight )generate
  LCD_BL                     <= '0';
end generate;

Backlight_Enabled: if( Use_Backlight )generate

  U_BL : entity work.vdsm8
  generic map(
    Reset_Level              => Reset_Level
  )
  port map(
    Clock                    => Clock,
    Reset                    => Reset,
    DACin                    => LCD_Bright,
    DACout                   => LCD_BL
  );

end generate;

end architecture;
