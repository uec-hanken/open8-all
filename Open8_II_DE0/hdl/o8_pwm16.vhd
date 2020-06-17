-- Copyright (c)2018, 2020 Jeremy Seth Henry
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
-- VHDL Units :  o8_pwm16
-- Description:  Provides a 16-bit standard PWM output with 1 uSec resolution,
--                as well as CPU interrupt on overflow. Note that the PWM
--                timers reload from registers on overflow, not on write
--
-- Register Map:
-- Offset  Bitfield Description                        Read/Write
--   0x00  AAAAAAAA Period (lower byte)                  (RW)
--   0x01  AAAAAAAA Period (upper byte)                  (RW)
--   0x02  AAAAAAAA Width (lower byte)                   (RW)
--   0x03  AAAAAAAA Width (upper byte)                   (RW)
--   0x04  A------- Timer Status                         (RW)
--                  A: Enabled on '1' / Disable on '0'
--
-- Revision History
-- Author          Date     Change
------------------ -------- ---------------------------------------------------
-- Seth Henry      04/25/18 Design Start
-- Seth Henry      04/10/20 Code cleanup and comments
-- Seth Henry      04/16/20 Modified to use Open8 bus record

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.std_logic_misc.all;

library work;
  use work.open8_pkg.all;

entity o8_pwm16 is
generic(
  Address                    : ADDRESS_TYPE
);
port(
  Open8_Bus                  : in  OPEN8_BUS_TYPE;
  Rd_Data                    : out DATA_TYPE;
  Interrupt                  : out std_logic;
  --
  PWM_Out                    : out std_logic
);
end entity;

architecture behave of o8_pwm16 is

  alias Clock                is Open8_Bus.Clock;
  alias Reset                is Open8_Bus.Reset;
  alias uSec_Tick            is Open8_Bus.uSec_Tick;

  constant User_Addr         : std_logic_vector(15 downto 3) :=
                                Address(15 downto 3);

  alias  Comp_Addr           is Open8_Bus.Address(15 downto 3);
  signal Addr_Match          : std_logic := '0';

  alias  Reg_Addr            is Open8_Bus.Address(2 downto 0);
  signal Reg_Addr_q          : std_logic_vector(2 downto 0) := (others => '0');

  signal Wr_En               : std_logic := '0';
  signal Wr_Data_q           : DATA_TYPE := x"00";
  signal Rd_En               : std_logic := '0';

  signal PWM_Enable          : std_logic := '0';
  signal PWM_Period          : std_logic_vector(15 downto 0) := (others => '0');
  alias  PWM_Period_l        is PWM_Period(7 downto 0);
  alias  PWM_Period_u        is PWM_Period(15 downto 8);

  signal PWM_Width           : std_logic_vector(15 downto 0) := (others => '0');
  alias  PWM_Width_l         is PWM_Width(7 downto 0);
  alias  PWM_Width_u         is PWM_Width(15 downto 8);

  signal Period_Ctr          : std_logic_vector(15 downto 0) := (others => '0');
  signal Width_Ctr           : std_logic_vector(15 downto 0) := (others => '0');

begin

  Addr_Match                 <= '1' when Comp_Addr = User_Addr else '0';

  PWM_proc: process( Clock, Reset )
  begin
    if( Reset = Reset_Level )then
      Wr_Data_q              <= (others => '0');
      Reg_Addr_q             <= (others => '0');
      Wr_En                  <= '0';
      Rd_En                  <= '0';
      Rd_Data                <= x"00";
      Interrupt              <= '0';

      PWM_Enable             <= '0';
      PWM_Period             <= (others => '0');
      PWM_Width              <= (others => '0');

      Period_Ctr             <= (others => '0');
      Width_Ctr              <= (others => '0');
      PWM_Out                <= '0';
    elsif( rising_edge(Clock) )then
      Reg_Addr_q             <= Reg_Addr;
      Wr_Data_q              <= Open8_Bus.Wr_Data;
      Wr_En                  <= Addr_Match and Open8_Bus.Wr_En;

      if( Wr_En = '1' )then
        case( Reg_Addr_q )is
          when "000" =>
            PWM_Period_l     <= Wr_Data_q;
          when "001" =>
            PWM_Period_u     <= Wr_Data_q;
          when "010" =>
            PWM_Width_l      <= Wr_Data_q;
          when "011" =>
            PWM_Width_u      <= Wr_Data_q;
          when "100" | "101" | "110" | "111" =>
            PWM_Enable       <= Wr_Data_q(7);
          when others => null;
        end case;
      end if;

      Rd_Data                <= (others => '0');
      Rd_En                  <= Addr_Match and Open8_Bus.Rd_En;
      if( Rd_En = '1' )then
        case( Reg_Addr_q )is
          when "000" =>
            Rd_Data          <= PWM_Period_l;
          when "001" =>
            Rd_Data          <= PWM_Period_u;
          when "010" =>
            Rd_Data          <= PWM_Width_l;
          when "011" =>
            Rd_Data          <= PWM_Width_u;
          when "100" | "101" | "110" | "111" =>
            Rd_Data          <= PWM_Enable & "0000000";
          when others => null;
        end case;
      end if;

      Interrupt              <= '0';
      Period_Ctr             <= Period_Ctr - uSec_tick;
      Width_Ctr              <= Width_Ctr - uSec_tick;

      -- Stop the width counter from rolling over at 0
      if( or_reduce(Width_Ctr) = '0' )then
        Width_Ctr            <= (others => '0');
      end if;

      -- Reload both counters when period reaches 0
      if( or_reduce(Period_Ctr) = '0' )then
        Period_Ctr           <= PWM_Period;
        Width_Ctr            <= PWM_Width;
        Interrupt            <= '1';
      end if;

      -- Drive the output high as long as Width > 0 and PWM_Enable is high
      PWM_Out                <= or_reduce(Width_Ctr) and PWM_Enable;

      -- If the counter is disabled, reload the counters, and drive the output
      --  low.
      if( PWM_Enable = '0' )then
        Period_Ctr           <= PWM_Period;
        Width_Ctr            <= PWM_Width;
        Interrupt            <= '0';
      end if;

    end if;
  end process;

end architecture;
