-- Copyright (c)2020 Jeremy Seth Henry
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
-- VHDL Units :  o8_btn_int
-- Description:  Detects and reports when a user pushbutton is pressed with an
--                interrupt.
--
-- Register Map:
-- Offset  Bitfield Description                        Read/Write
--   0x00  AAAAAAAA Current Button State                 (RW)
--
-- Revision History
-- Author          Date     Change
------------------ -------- ---------------------------------------------------
-- Seth Henry      01/22/20 Re-write of original with separate debouncer
-- Seth Henry      04/16/20 Modified to use Open8 bus record

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.std_logic_arith.all;
  use ieee.std_logic_misc.all;

library work;
  use work.open8_pkg.all;

entity o8_btn_int is
generic(
  Num_Buttons                : integer range 1 to 8 := 8;
  Button_Level               : std_logic := '0';
  Address                    : ADDRESS_TYPE := x"0000"
);
port(
  Open8_Bus                  : in  OPEN8_BUS_TYPE;
  Rd_Data                    : out DATA_TYPE;
  Interrupt                  : out std_logic;
  --
  Button_In                  : in  DATA_TYPE := x"00"
);
end entity;

architecture behave of o8_btn_int is

  alias Clock                is Open8_Bus.Clock;
  alias Reset                is Open8_Bus.Reset;
  alias uSec_Tick            is Open8_Bus.uSec_Tick;

  constant User_Addr         : std_logic_vector(15 downto 0) := Address;
  alias  Comp_Addr           is Open8_Bus.Address(15 downto 0);
  signal Addr_Match          : std_logic := '0';

  signal Rd_En_d             : std_logic := '0';
  signal Rd_En_q             : std_logic := '0';

  constant MSEC_DELAY        : std_logic_vector(9 downto 0) :=
                                conv_std_logic_vector(1000,10);

  signal mSec_Timer          : std_logic_vector(9 downto 0) := (others => '0');
  signal mSec_Tick           : std_logic := '0';

  signal Button_Pressed      : DATA_TYPE := x"00";
  signal Button_CoS          : DATA_TYPE := x"00";

begin

  Addr_Match                 <= '1' when Comp_Addr = User_Addr else '0';
  Rd_En_d                    <= Addr_Match and Open8_Bus.Rd_En;

  io_reg: process( Clock, Reset )
  begin
    if( Reset = Reset_Level )then
      Rd_En_q                <= '0';
      Rd_Data                <= OPEN8_NULLBUS;
      Interrupt              <= '0';
    elsif( rising_edge( Clock ) )then
      Rd_En_q                <= Rd_En_d;
      Rd_Data                <= OPEN8_NULLBUS;
      if( Rd_En_q = '1' )then
        Rd_Data              <= Button_Pressed;
      end if;
      Interrupt              <= or_reduce(Button_CoS);
    end if;
  end process;

  mSec_proc: process( Clock, Reset )
  begin
    if( Reset = Reset_Level )then
      mSec_Timer             <= (others => '0');
      mSec_Tick              <= '0';
    elsif( rising_edge(Clock) )then
      mSec_Timer             <= mSec_Timer - uSec_Tick;
      mSec_Tick              <= '0';
      if( mSec_Timer = 0 )then
        mSec_Timer           <= MSEC_DELAY;
        mSec_Tick            <= '1';
      end if;
    end if;
  end process;

Create_Debouncers: for i in 0 to Num_Buttons - 1 generate

  U_BTN : entity work.button_db
  generic map(
    Button_Level             => Button_Level,
    Reset_Level              => Reset_Level
  )
  port map(
    Clock                    => Clock,
    Reset                    => Reset,
    mSec_Tick                => mSec_Tick,
    --
    Button_In                => Button_In(i),
    --
    Button_Pressed           => Button_Pressed(i),
    Button_CoS               => Button_CoS(i)
  );

end generate;

end architecture;