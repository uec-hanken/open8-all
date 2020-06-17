-- Copyright (c)2018 Jeremy Seth Henry
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
-- (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
-- SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--
-- VHDL Entity: usec_tick
-- Description: Provides a single clock tick every 1 microsecond. Requires that
--               the system clock frequency be passed as a real.

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.std_logic_arith.all;
  use ieee.std_logic_misc.all;

entity usec_tick is
generic(
  Reset_Level           : std_logic;
  Sys_Freq              : real := 50000000.0
);
port(
  Clock                 : in  std_logic;
  Reset                 : in  std_logic;
  uSec_Tick             : out std_logic
);
end entity;

architecture behave of usec_tick is

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
  end ceil_log2;

  constant DLY_1USEC_VAL: integer := integer(Sys_Freq / 1000000.0);
  constant DLY_1USEC_WDT: integer := ceil_log2(DLY_1USEC_VAL - 1);
  constant DLY_1USEC    : std_logic_vector :=
                       conv_std_logic_vector( DLY_1USEC_VAL - 1, DLY_1USEC_WDT);
  signal uSec_Cntr      : std_logic_vector( DLY_1USEC_WDT - 1 downto 0 );

  signal uSec_Adv       : std_logic;
  signal uSec_Accum     : std_logic_vector(31 downto 0);

begin

  uSec_Tick                  <= uSec_Adv;

  uSec_Tick_proc: process( Clock, Reset )
  begin
    if( Reset = Reset_Level )then
      uSec_Cntr         <= DLY_1USEC;
      uSec_Adv          <= '0';
      uSec_Accum        <= (others => '0');
    elsif( rising_edge( Clock ) )then
      uSec_Cntr         <= uSec_Cntr - 1;
      uSec_Adv          <= '0';
      if( or_reduce(uSec_Cntr) = '0' )then
        uSec_Cntr       <= DLY_1USEC;
        uSec_Adv        <= '1';
      end if;
      uSec_Accum        <= uSec_Accum + uSec_Adv;
    end if;
  end process;

end architecture;
