-- Copyright (c)2006, 2016, 2019, 2020 Jeremy Seth Henry
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
-- VHDL Units :  o8_status_led
-- Description:  Provides a multi-state status LED controller
--
-- Register Map:
-- Offset  Bitfield Description                        Read/Write
--   0x00  -----AAA LED Mode (2:0)                     (RW)
--
-- LED Modes:
-- 0x00 - LED is fully off
-- 0x01 - LED is fully on
-- 0x02 - LED is dimmed to 50%
-- 0x03 - LED Toggles at 1Hz
-- 0x04 - LED fades in and out
--
-- Revision History
-- Author          Date     Change
------------------ -------- ---------------------------------------------------
-- Seth Henry      12/20/19 Design Start
-- Seth Henry      04/16/20 Modified to use Open8  bus record

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.std_logic_arith.all;
  use ieee.std_logic_misc.all;

library work;
  use work.open8_pkg.all;

entity o8_status_led is
generic(
  Address                    : ADDRESS_TYPE
);
port(
  Open8_Bus                  : in  OPEN8_BUS_TYPE;
  Rd_Data                    : out DATA_TYPE;
  --
  LED_Out                    : out std_logic
);
end entity;

architecture behave of o8_status_led is

  alias Clock                is Open8_Bus.Clock;
  alias Reset                is Open8_Bus.Reset;

  constant User_Addr         : std_logic_vector(15 downto 0)
                               := Address(15 downto 0);
  alias  Comp_Addr           is Open8_Bus.Address(15 downto 0);
  signal Addr_Match          : std_logic;
  signal Wr_En               : std_logic;
  signal Wr_Data_q           : std_logic_vector(2 downto 0);
  signal LED_Mode            : std_logic_vector(2 downto 0);
  signal Rd_En               : std_logic;

  signal Dim50Pct_Out        : std_logic;

  signal Half_Hz_Timer       : std_logic_vector(15 downto 0);
  constant HALF_HZ_PRD       : std_logic_vector(15 downto 0) :=
                                conv_std_logic_vector(500000,16);
  signal One_Hz_Out          : std_logic;

  constant TIMER_MSB         : integer range 9 to 20 := 18;

  signal Fade_Timer1         : std_logic_vector(TIMER_MSB downto 0);
  signal Fade_Timer2         : std_logic_vector(TIMER_MSB downto 0);
  signal Fade_Out            : std_logic;

begin

  Addr_Match                 <= '1' when Comp_Addr = User_Addr else '0';

  io_reg: process( Clock, Reset )
  begin
    if( Reset = Reset_Level )then
      Wr_En                  <= '0';
      Wr_Data_q              <= (others => '0');
      LED_Mode               <= (others => '0');
      Rd_En                  <= '0';
      Rd_Data                <= OPEN8_NULLBUS;
    elsif( rising_edge( Clock ) )then
      Wr_En                  <= Addr_Match and Open8_Bus.Wr_En;
      Wr_Data_q              <= Open8_Bus.Wr_Data(2 downto 0);
      if( Wr_En = '1' )then
        LED_Mode             <= Wr_Data_q;
      end if;

      Rd_Data                <= OPEN8_NULLBUS;
      Rd_En                  <= Addr_Match and Open8_Bus.Rd_En;
      if( Rd_En = '1' )then
        Rd_Data              <= "00000" & LED_Mode;
      end if;

    end if;
  end process;

  Output_FF: process( Clock, Reset )
  begin
    if( Reset = Reset_Level )then
      LED_Out                <= '0';
    elsif( rising_edge(Clock) )then
      LED_Out                <= '0';
      case( LED_Mode )is
        when "001" =>
          LED_Out            <= '1';
        when "010" =>
          LED_Out            <= Dim50Pct_Out;
        when "011" =>
          LED_Out            <= One_Hz_Out;
        when "100" =>
          LED_Out            <= Fade_out;
        when others => null;
      end case;
    end if;
  end process;

  Timer_proc: process( Clock, Reset )
  begin
    if( Reset = Reset_Level )then
      Dim50Pct_Out           <= '0';
      Half_Hz_Timer          <= (others => '0');
      One_Hz_Out             <= '0';
      Fade_Timer1            <= (others => '0');
      Fade_Timer2            <= (others => '0');
      Fade_out               <= '0';
    elsif( rising_edge(Clock) )then
      Dim50Pct_Out           <= not Dim50Pct_Out;

      Half_Hz_Timer          <= Half_Hz_Timer - 1;
      if( Half_Hz_Timer = 0 )then
        Half_Hz_Timer        <= HALF_HZ_PRD;
        One_Hz_Out           <= not One_Hz_Out;
      end if;

      Fade_Timer1            <= Fade_Timer1 - 1;
      Fade_Timer2            <= Fade_Timer2 - 1;
      if( or_reduce(Fade_Timer2) = '0' )then
        Fade_Timer2(TIMER_MSB downto TIMER_MSB - 8) <= (others => '1');
        Fade_Timer2(TIMER_MSB - 9 downto 0 )        <= (others => '0');
      end if;
      Fade_out               <= Fade_Timer1(TIMER_MSB) xor
                                Fade_Timer2(TIMER_MSB);
    end if;
  end process;

end architecture;
