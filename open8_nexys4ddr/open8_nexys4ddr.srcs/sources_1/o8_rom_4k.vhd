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
-- VHDL Units :  o8_rom_32k
-- Description:  Provides a wrapper layer for a 32kx8 ROM model
--
-- Revision History
-- Author          Date     Change
------------------ -------- ---------------------------------------------------
-- Seth Henry      04/16/20 Revision block added

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

library work;
  use work.open8_pkg.all;

entity o8_rom_4k is
generic(
  Address                    : ADDRESS_TYPE
);
port(
  Open8_Bus                  : in  OPEN8_BUS_TYPE;
  Rd_Data                    : out DATA_TYPE
);
end entity;

architecture behave of o8_rom_4k is

  alias Clock                is Open8_Bus.Clock;
  alias Reset                is Open8_Bus.Reset;

  constant User_Addr         : std_logic_vector(15 downto 12) :=
                               Address(15 downto 12);
  signal Comp_Addr           : std_logic_vector(15 downto 12);
  signal ROM_Addr            : std_logic_vector(11 downto 0);

  signal Addr_Match          : std_logic := '0';
  signal Rd_En               : std_logic := '0';
  signal Rd_Data_i           : DATA_TYPE := OPEN8_NULLBUS;

begin

  -- Note that this RAM should be created without an output FF (unregistered Q)
  U_ROM_CORE : entity work.rom_4k_core
  port map(
    address                  => ROM_Addr,
    clock                    => Clock,
    q                        => Rd_Data_i
  );

  Addr_Match                 <= Open8_Bus.Rd_En when Comp_Addr = User_Addr else
                                '0';
  Comp_Addr <= Open8_Bus.Address(15 downto 12);
  ROM_Addr <= Open8_Bus.Address(11 downto 0);

  RAM_proc: process( Reset, Clock )
  begin
    if( Reset = Reset_Level )then
      Rd_En                  <= '0';
      Rd_Data                <= OPEN8_NULLBUS;
    elsif( rising_edge(Clock) )then
      Rd_En                  <= Addr_Match;
      Rd_Data                <= OPEN8_NULLBUS;
      if( Rd_En = '1' )then
        Rd_Data              <= Rd_Data_i;
      end if;
    end if;
  end process;

end architecture;
