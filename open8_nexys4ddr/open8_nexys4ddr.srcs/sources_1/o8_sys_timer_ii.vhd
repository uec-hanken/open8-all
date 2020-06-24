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
-- Register Map:
-- Offset  Bitfield Description                        Read/Write
--   0x00  AAAAAAAA Req Interval Byte 0                   (RW)
--   0x01  AAAAAAAA Req Interval Byte 1                   (RW)
--   0x02  AAAAAAAA Req Interval Byte 2                   (RW)
--   0x03  BA------ Control/Status Register               (RW)
--                   A: Update timer (WR) or pending (RD) (RW)
--                   B: Output Enable
--
-- Notes      :  Setting the output to 0x000000 will disable the timer
--            :  Update pending is true if bit A is 1, otherwise false
--
-- Revision History
-- Author          Date     Change
------------------ -------- ---------------------------------------------------
-- Seth Henry      07/28/11 Design Start
-- Seth Henry      12/19/19 Renamed Tmr_Out to Interrupt
-- Seth Henry      04/09/20 Modified timer update logic to reset the timer on
--                           interval write.
-- Seth Henry      04/16/20 Modified to use Open8 bus record
-- Seth Henry      04/17/20 Altered interval to be a 24-bit counter
-- Seth Henry      05/18/20 Added write qualification input

library ieee;
use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.std_logic_arith.all;
  use ieee.std_logic_misc.all;

library work;
  use work.open8_pkg.all;

entity o8_sys_timer_ii is
generic(
  Address                    : ADDRESS_TYPE
);
port(
  Open8_Bus                  : in  OPEN8_BUS_TYPE;
  Write_Qual                 : in  std_logic := '1';
  Rd_Data                    : out DATA_TYPE;
  Interrupt                  : out std_logic
);
end entity;

architecture behave of o8_sys_timer_ii is

  alias Clock                is Open8_Bus.Clock;
  alias Reset                is Open8_Bus.Reset;
  alias uSec_Tick            is Open8_Bus.uSec_Tick;

  constant User_Addr         : std_logic_vector(15 downto 2) :=
                                Address(15 downto 2);
  alias  Comp_Addr           is Open8_Bus.Address(15 downto 2);
  signal Addr_Match          : std_logic := '0';

  alias  Reg_Sel_d           is Open8_Bus.Address(1 downto 0);
  signal Reg_Sel_q           : std_logic_vector(1 downto 0) := "00";
  signal Wr_En_d             : std_logic;
  signal Wr_En_q             : std_logic := '0';
  alias  Wr_Data_d           is Open8_Bus.Wr_Data;
  signal Wr_Data_q           : DATA_TYPE := x"00";
  signal Rd_En_d             : std_logic := '0';
  signal Rd_En_q             : std_logic := '0';

  signal Req_Interval        : std_logic_vector(23 downto 0) := x"000000";
  alias  Req_Interval_B0     is Req_Interval( 7 downto  0);
  alias  Req_Interval_B1     is Req_Interval(15 downto  8);
  alias  Req_Interval_B2     is Req_Interval(23 downto 16);

  signal Int_Interval        : std_logic_vector(23 downto 0) := x"000000";

  signal Update_Interval     : std_logic := '0';
  signal Update_Pending      : std_logic := '0';
  signal Output_Enable       : std_logic := '0';
  signal Timer_Cnt           : std_logic_vector(23 downto 0) := x"000000";

begin

  Addr_Match                 <= '1' when Comp_Addr = User_Addr else '0';
  Wr_En_d                    <= Addr_Match and Open8_Bus.Wr_En;
  Rd_En_d                    <= Addr_Match and Open8_Bus.Rd_En;

  io_reg: process( Clock, Reset )
  begin
    if( Reset = Reset_Level )then
      Reg_Sel_q              <= "00";
      Wr_En_q                <= '0';
      Wr_Data_q              <= x"00";
      Rd_En_q                <= '0';
      Rd_Data                <= OPEN8_NULLBUS;
      Req_Interval           <= x"000000";
      Update_Interval        <= '0';
      Update_Pending         <= '0';
      Output_Enable          <= '0';
    elsif( rising_edge( Clock ) )then
      Reg_Sel_q              <= Reg_Sel_d;

      Wr_En_q                <= Wr_En_d;
      Wr_Data_q              <= Wr_Data_d;
      Update_Interval        <= '0';
      if( Wr_En_q = '1' and Write_Qual = '1' )then
        case( Reg_Sel_q )is
          when "00" =>
            Req_Interval_B0  <= Wr_Data_q;
            Update_Pending   <= '1';
          when "01" =>
            Req_Interval_B1  <= Wr_Data_q;
            Update_Pending   <= '1';
          when "10" =>
            Req_Interval_B2  <= Wr_Data_q;
            Update_Pending   <= '1';
          when "11" =>
            Output_Enable    <= Wr_Data_q(7);
            Update_Interval  <= Wr_Data_q(6);
          when others => null;
        end case;
      end if;

      if( Update_Interval = '1' )then
        Update_Pending       <= '0';
      end if;

      Rd_Data                <= OPEN8_NULLBUS;
      Rd_En_q                <= Rd_En_d;
      if( Rd_En_q = '1' )then
        case( Reg_Sel_q )is
          when "00" =>
            Rd_Data          <= Req_Interval_B0;
          when "01" =>
            Rd_Data          <= Req_Interval_B1;
          when "10" =>
            Rd_Data          <= Req_Interval_B2;
          when "11" =>
            Rd_Data          <= Output_Enable & Update_Pending & "000000";
          when others => null;
        end case;
      end if;
    end if;
  end process;

  Interval_proc: process( Clock, Reset )
  begin
    if( Reset = Reset_Level )then
      Int_Interval           <= x"000000";
      Timer_Cnt              <= x"000000";
      Interrupt              <= '0';
    elsif( rising_edge(Clock) )then
      Interrupt              <= '0';
      Timer_Cnt              <= Timer_Cnt - uSec_Tick;
      if( Update_Interval = '1' )then
        Int_Interval         <= Req_Interval;
        Timer_Cnt            <= Req_Interval;
      elsif( or_reduce(Timer_Cnt) = '0' )then
        Timer_Cnt            <= Int_Interval;
        Interrupt            <= Output_Enable;
      end if;
    end if;
  end process;

end architecture;
