-- Copyright (c)2011, 2019 Jeremy Seth Henry
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
-- VHDL Units :  o8_gpin
-- Description:  Provides a single 8-bit input register
--
-- Note: Cut the path between GPIN and GPIN_q1 for timing analysis
--
-- Revision History
-- Author          Date     Change
------------------ -------- ---------------------------------------------------
-- Seth Henry      07/28/11 Design Start
-- Seth Henry      12/19/19 Renamed to "o8_gpin" to fit "theme"
-- Seth Henry      12/20/19 Added metastability registers
-- Seth Henry      04/10/20 Code Cleanup
-- Seth Henry      04/16/20 Modified to make use of Open8 bus record

library ieee;
use ieee.std_logic_1164.all;

library work;
  use work.open8_pkg.all;

entity o8_gpin is
generic(
  Address                    : ADDRESS_TYPE
);
port(
  Open8_Bus                  : in  OPEN8_BUS_TYPE;
  Rd_Data                    : out DATA_TYPE;
  --
  GPIN                       : in  DATA_TYPE
);
end entity;

architecture behave of o8_gpin is
  alias Clock                is Open8_Bus.Clock;
  alias Reset                is Open8_Bus.Reset;

  constant User_Addr         : std_logic_vector(15 downto 0) := Address;
  alias  Comp_Addr           is Open8_Bus.Address(15 downto 0);
  signal Addr_Match          : std_logic;
  signal Rd_En               : std_logic;

  signal GPIN_q1             : DATA_TYPE;
  signal GPIN_q2             : DATA_TYPE;
  signal User_In             : DATA_TYPE;

begin

  Addr_Match                 <= Open8_Bus.Rd_En when Comp_Addr = User_Addr else
                                '0';

  io_reg: process( Clock, Reset )
  begin
    if( Reset = Reset_Level )then
      Rd_En                  <= '0';
      Rd_Data                <= OPEN8_NULLBUS;
      GPIN_q1                <= x"00";
      GPIN_q2                <= x"00";
      User_In                <= x"00";
    elsif( rising_edge( Clock ) )then
      GPIN_q1                <= GPIN;
      GPIN_q2                <= GPIN_q1;
      User_In                <= GPIN_q2;

      Rd_Data                <= OPEN8_NULLBUS;
      Rd_En                  <= Addr_Match;
      if( Rd_En = '1' )then
        Rd_Data              <= User_In;
      end if;
    end if;
  end process;

end architecture;
