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
-- VHDL Units :  o8_sys_timer
-- Description:  Provides an 8-bit microsecond resolution timer for generating
--            :   periodic interrupts for the Open8 CPU.
--
-- Notes      :  Setting the output to 0x00 will disable the timer
--
-- Revision History
-- Author          Date     Change
------------------ -------- ---------------------------------------------------
-- Seth Henry      07/28/11 Design Start
-- Seth Henry      12/19/19 Renamed Tmr_Out to Interrupt
-- Seth Henry      04/09/20 Modified timer update logic to reset the timer on
--                           interval write.
-- Seth Henry      04/16/20 Modified to use Open8 bus record

library ieee;
use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.std_logic_arith.all;
  use ieee.std_logic_misc.all;

library work;
  use work.open8_pkg.all;

entity o8_sys_timer is
generic(
  Address                    : ADDRESS_TYPE
);
port(
  Open8_Bus                  : in  OPEN8_BUS_TYPE;
  Rd_Data                    : out DATA_TYPE;
  Interrupt                  : out std_logic
);
end entity;

architecture behave of o8_sys_timer is

  alias Clock                is Open8_Bus.Clock;
  alias Reset                is Open8_Bus.Reset;
  alias uSec_Tick            is Open8_Bus.uSec_Tick;

  constant User_Addr         : ADDRESS_TYPE := Address;
  alias  Comp_Addr           is Open8_Bus.Address(15 downto 0);
  signal Addr_Match          : std_logic := '0';
  signal Wr_En               : std_logic := '0';
  signal Wr_Data_q           : DATA_TYPE := x"00";
  signal Rd_En               : std_logic := '0';
  signal Rd_En_q             : std_logic := '0';

  signal Interval            : DATA_TYPE := x"00";
  signal Update_Interval     : std_logic;
  signal Timer_Cnt           : DATA_TYPE := x"00";

begin

  Addr_Match                 <= '1' when Comp_Addr = User_Addr else '0';

  io_reg: process( Clock, Reset )
  begin
    if( Reset = Reset_Level )then
      Wr_En                  <= '0';
      Wr_Data_q              <= x"00";
      Rd_En                  <= '0';
      Rd_Data                <= OPEN8_NULLBUS;
      Interval               <= x"00";
      Update_Interval        <= '0';
    elsif( rising_edge( Clock ) )then
      Wr_En                  <= Addr_Match and Open8_Bus.Wr_En;
      Wr_Data_q              <= Open8_Bus.Wr_Data;
      Update_Interval        <= '0';
      if( Wr_En = '1' )then
        Interval             <= Wr_Data_q;
        Update_Interval      <= '1';
      end if;

      Rd_Data                <= OPEN8_NULLBUS;
      Rd_En                  <= Addr_Match and Open8_Bus.Rd_En;
      if( Rd_En = '1' )then
        Rd_Data              <= Interval;
      end if;
    end if;
  end process;

  Interval_proc: process( Clock, Reset )
  begin
    if( Reset = Reset_Level )then
      Timer_Cnt              <= x"00";
      Interrupt              <= '0';
    elsif( rising_edge(Clock) )then
      Interrupt              <= '0';
      Timer_Cnt              <= Timer_Cnt - uSec_Tick;
      if( Update_Interval = '1' )then
        Timer_Cnt            <= Interval;
      elsif( or_reduce(Timer_Cnt) = '0' )then
        Timer_Cnt            <= Interval;
        Interrupt            <= or_reduce(Interval); -- Only trigger on Int > 0
      end if;
    end if;
  end process;

end architecture;
