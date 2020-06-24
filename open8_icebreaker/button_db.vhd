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
-- VHDL Units :  button_db
-- Description:  Debounces a single button/switch and provides a change of
--                state signal as well as registered level.
--
-- Revision History
-- Author          Date     Change
------------------ -------- ---------------------------------------------------
-- Seth Henry      04/14/20 Code cleanup and revision section added

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.std_logic_misc.all;

entity button_db is
generic(
  Button_Level          : std_logic;
  Reset_Level           : std_logic
);
port(
  Clock                 : in  std_logic;
  Reset                 : in  std_logic;
  mSec_Tick             : in  std_logic;
  --
  Button_In             : in  std_logic;
  --
  Button_Pressed        : out std_logic;
  Button_CoS            : out std_logic
);
end entity;

architecture behave of button_db is

  signal Button_SR      : std_logic_vector(2 downto 0);
  alias  Button_In_q    is Button_SR(2);

  signal Button_Dn_Tmr  : std_logic_vector(5 downto 0);
  signal Button_Dn      : std_logic;

  signal Button_Up_Tmr  : std_logic_vector(5 downto 0);
  signal Button_Up      : std_logic;

  signal Button_State   : std_logic;
  signal Button_State_q : std_logic;

begin

  Button_Pressed         <= Button_State_q;

  Button_trap: process( Clock, Reset )
  begin
    if( Reset = Reset_Level )then
      Button_SR          <= (others => '0');

      Button_Dn_Tmr      <= (others => '0');
      Button_Dn          <= '0';

      Button_Up_Tmr      <= (others => '0');
      Button_Up          <= '0';

      Button_State       <= '0';
      Button_State_q     <= '0';

      Button_CoS         <= '0';
    elsif( rising_edge(Clock) )then
      Button_SR         <= Button_SR(1 downto 0) & Button_In;

      Button_Dn_Tmr     <= (others => '0');
      Button_Dn         <= '0';
      if( Button_In_q = Button_Level )then
        Button_Dn_Tmr   <= Button_Dn_Tmr + mSec_Tick;
        if( and Button_Dn_Tmr) = '1' then
          Button_Dn_Tmr <= Button_Dn_Tmr;
          Button_Dn     <= '1';
        end if;
      end if;

      Button_Up_Tmr     <= (others => '0');
      Button_Up         <= '0';
      if( Button_In_q = not Button_Level )then
        Button_Up_Tmr   <= Button_Up_Tmr + mSec_Tick;
        if( and Button_Up_Tmr) = '1' then
          Button_Up_Tmr <= Button_Up_Tmr;
          Button_Up     <= '1';
        end if;
      end if;

      if( Button_Dn = '1' )then
        Button_State    <= '1';
      elsif( Button_Up  = '1' )then
        Button_State    <= '0';
      end if;

      Button_State_q    <= Button_State;
      Button_CoS        <= Button_State xor Button_State_q;

    end if;
  end process;

end architecture;
