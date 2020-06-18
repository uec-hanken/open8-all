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
-- VHDL Units :  o8_register
-- Description:  Provides a byte of pseudo-random data on every read
--
-- Register Map:
-- Offset  Bitfield Description                        Read/Write
--   0x00  AAAAAAAA Data output                          (RW)
--
-- Revision History
-- Author          Date     Change
------------------ -------- ---------------------------------------------------
-- Seth Henry      04/25/18 Design Start
-- Seth Henry      04/10/20 Code cleanup and comments
-- Seth Henry      04/16/20 Modified to use Open8 bus record

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_misc.all;

library work;
  use work.open8_pkg.all;

entity o8_lfsr32 is
generic(
  Init_Seed                  : std_logic_vector(31 downto 0) := x"CAFEBABE";
  Address                    : ADDRESS_TYPE
);
port(
  Open8_Bus                  : in OPEN8_BUS_TYPE;
  Rd_Data                    : out DATA_TYPE
);
end entity;

architecture behave of o8_lfsr32 is

  alias Clock                is Open8_Bus.Clock;
  alias Reset                is Open8_Bus.Reset;

  constant User_Addr         : std_logic_vector(15 downto 1)
                               := Address(15 downto 1);
  alias  Comp_Addr           is Open8_Bus.Address(15 downto 1);
  alias  Reg_Sel             is Open8_Bus.Address(0);
  signal Reg_Sel_q           : std_logic := '0';
  signal Addr_Match          : std_logic := '0';
  signal Rd_En               : std_logic := '0';

  signal d0                  : std_logic := '0';
  signal lfsr                : std_logic_vector(31 downto 0) := x"00000000";
  signal lfsr_q              : std_logic_vector(31 downto 0) := x"00000000";

begin

  Addr_Match                 <= Open8_Bus.Rd_En when Comp_Addr = User_Addr else
                                '0';
  d0                         <= lfsr(31) xnor lfsr(21) xnor lfsr(1) xnor lfsr(0);

  lfsr_proc: process( Clock, Reset )
  begin
    if( Reset = Reset_Level )then
      Reg_Sel_q              <= '0';
      Rd_En                  <= '0';
      Rd_Data                <= x"00";
      lfsr                   <= Init_Seed;
      lfsr_q                 <= x"00000000";
    elsif( rising_edge(Clock) )then
      Rd_Data                <= x"00";
      Reg_Sel_q              <= Reg_Sel;
      Rd_En                  <= Addr_Match;
      if( Rd_En = '1' )then
        Rd_Data              <= lfsr_q(31 downto 24);
        lfsr_q               <= lfsr_q(23 downto 0) & x"00";
        if( Reg_Sel_q = '1' )then
          Rd_Data            <= lfsr_q(31) & "0000000";
          lfsr_q             <= lfsr_q(30 downto 0) & '0';
        end if;
      end if;

      if( or_reduce(lfsr_q) = '0' )then
        lfsr_q               <= lfsr;
        lfsr                 <= lfsr(30 downto 0) & d0;
      end if;
    end if;
  end process;

end architecture;