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
-- VHDL Units :  o8_elapsed_usec
-- Description:  Provides an 24-bit microsecond resolution counter for
--            :   measuring events
--
-- Register Map:
-- Offset  Bitfield Description                        Read/Write
--   0x00  AAAAAAAA Req Interval Byte 0                   (RW)
--   0x01  AAAAAAAA Req Interval Byte 1                   (RW)
--   0x02  AAAAAAAA Req Interval Byte 2                   (RW)
--   0x03  BA------ Control/Status Register               (RW)
--                   A: Reset (1)                         (WR)
--                   B: Start (1) / Stop (0)
--
-- Notes      :  Writing to 0x0 - 0x02 will latch the current value
--            :  Writing a 1 to bit A of 0x03 will cause an
--                immediate timer reset. This bit is a one-shot.
--
-- Revision History
-- Author          Date     Change
------------------ -------- ---------------------------------------------------
-- Seth Henry      04/20/20 Design Start

library ieee;
use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.std_logic_arith.all;
  use ieee.std_logic_misc.all;

library work;
  use work.open8_pkg.all;

entity o8_elapsed_usec is
generic(
  Address                    : ADDRESS_TYPE
);
port(
  Open8_Bus                  : in  OPEN8_BUS_TYPE;
  Rd_Data                    : out DATA_TYPE
);
end entity;

architecture behave of o8_elapsed_usec is

  alias Clock                is Open8_Bus.Clock;
  alias Reset                is Open8_Bus.Reset;
  alias uSec_Tick            is Open8_Bus.uSec_Tick;

  constant User_Addr         : std_logic_vector(15 downto 2) :=
                                Address(15 downto 2);
  alias  Comp_Addr           is Open8_Bus.Address(15 downto 2);
  alias  Reg_Addr            is Open8_Bus.Address(1 downto 0);

  signal Addr_Match          : std_logic := '0';
  signal Reg_Sel             : std_logic_vector(1 downto 0) := "00";
  signal Wr_En               : std_logic := '0';
  signal Wr_Data_q           : DATA_TYPE := x"00";
  signal Rd_En               : std_logic := '0';
  signal Rd_En_q             : std_logic := '0';

  signal Shadow_Time         : std_logic_vector(23 downto 0) := x"000000";
  alias  Shadow_Time_B0      is Shadow_Time( 7 downto  0);
  alias  Shadow_Time_B1      is Shadow_Time(15 downto  8);
  alias  Shadow_Time_B2      is Shadow_Time(23 downto 16);

  signal Update_Shadow       : std_logic := '0';
  signal Timer_Reset         : std_logic := '0';
  signal Timer_En_Req        : std_logic := '0';
  signal Timer_Enable        : std_logic := '0';
  signal Timer_Cnt           : std_logic_vector(23 downto 0) := x"000000";

begin

  Addr_Match                 <= '1' when Comp_Addr = User_Addr else '0';

  io_reg: process( Clock, Reset )
  begin
    if( Reset = Reset_Level )then
      Reg_Sel                <= "00";
      Wr_En                  <= '0';
      Wr_Data_q              <= x"00";
      Rd_En                  <= '0';
      Rd_Data                <= OPEN8_NULLBUS;
      Update_Shadow          <= '0';
      Timer_Reset            <= '0';
      Timer_En_Req           <= '0';
    elsif( rising_edge( Clock ) )then
      Reg_Sel                <= Reg_Addr;

      Wr_En                  <= Addr_Match and Open8_Bus.Wr_En;
      Wr_Data_q              <= Open8_Bus.Wr_Data;

      Update_Shadow          <= '0';
      Timer_Reset            <= '0';
      if( Wr_En = '1' )then
        case( Reg_Sel )is
          when "00" =>
            Update_Shadow    <= '1';
          when "01" =>
            Update_Shadow    <= '1';
          when "10" =>
            Update_Shadow    <= '1';
          when "11" =>
            Timer_Reset      <= Wr_Data_q(6);
            Timer_En_Req     <= Wr_Data_q(7);
          when others => null;
        end case;
      end if;

      Rd_Data                <= OPEN8_NULLBUS;
      Rd_En                  <= Addr_Match and Open8_Bus.Rd_En;
      if( Rd_En = '1' )then
        case( Reg_Sel )is
          when "00" =>
            Rd_Data          <= Shadow_Time_B0;
          when "01" =>
            Rd_Data          <= Shadow_Time_B1;
          when "10" =>
            Rd_Data          <= Shadow_Time_B2;
          when "11" =>
            Rd_Data          <= Timer_En_Req & "0000000";
          when others => null;
        end case;
      end if;
    end if;
  end process;

  Timer_proc: process( Clock, Reset )
  begin
    if( Reset = Reset_Level )then
      Shadow_Time            <= x"000000";
      Timer_Cnt              <= x"000000";
    elsif( rising_edge(Clock) )then
      if( Timer_Reset = '1' )then
        Timer_Cnt              <= x"000000";
      elsif( Timer_Enable = '1' )then
        Timer_Cnt            <= Timer_Cnt + uSec_Tick;
      end if;

      if( uSec_Tick = '1' )then
        Timer_Enable         <= Timer_En_Req;
      end if;

      if( Update_Shadow = '1' )then
        Shadow_Time          <= Timer_Cnt;
      end if;
    end if;
  end process;

end architecture;
