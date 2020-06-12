-- Copyright (c)2016, 2020 Jeremy Seth Henry
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
-- VHDL Units :  o8_vdsm8
-- Description:  8-bit variable delta-sigma modulator.
--
-- Register Map:
-- Offset  Bitfield Description                        Read/Write
--   0x00  AAAAAAAA DAC Value                             (RW)
--
-- Revision History
-- Author          Date     Change
------------------ -------- ---------------------------------------------------
-- Seth Henry      06/23/16 Design start
-- Seth Henry      04/10/20 Code Cleanup
-- Seth Henry      04/16/20 Modified to use Open8 bus record

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

library work;
  use work.open8_pkg.all;

entity o8_vdsm8 is
generic(
  Default_Value              : DATA_TYPE := x"00";
  Address                    : ADDRESS_TYPE
);
port(
  Open8_Bus                  : in  OPEN8_BUS_TYPE;
  Rd_Data                    : out DATA_TYPE;
  --
  DACout                     : out std_logic
);
end entity;

architecture behave of o8_vdsm8 is

  alias Clock                is Open8_Bus.Clock;
  alias Reset                is Open8_Bus.Reset;

  constant User_Addr         : std_logic_vector(15 downto 0)
                               := Address(15 downto 0);
  alias  Comp_Addr           is Open8_Bus.Address(15 downto 0);
  signal Addr_Match          : std_logic;
  signal Wr_En               : std_logic;
  signal Wr_Data_q           : DATA_TYPE;
  signal Reg_Out             : DATA_TYPE;
  signal Rd_En               : std_logic;

begin

  Addr_Match                 <= '1' when Comp_Addr = User_Addr else '0';

  io_reg: process( Clock, Reset )
  begin
    if( Reset = Reset_Level )then
      Wr_En                  <= '0';
      Wr_Data_q              <= x"00";
      Reg_Out                <= Default_Value;
      Rd_En                  <= '0';
      Rd_Data                <= OPEN8_NULLBUS;
    elsif( rising_edge( Clock ) )then
      Wr_En                  <= Addr_Match and Open8_Bus.Wr_En;
      Wr_Data_q              <= Open8_Bus.Wr_Data;
      if( Wr_En = '1' )then
        Reg_Out              <= Wr_Data_q;
      end if;

      Rd_Data                <= OPEN8_NULLBUS;
      Rd_En                  <= Addr_Match and Open8_Bus.Rd_En;
      if( Rd_En = '1' )then
        Rd_Data              <= Reg_Out;
      end if;
    end if;
  end process;

  U_DAC : entity work.vdsm8
  generic map(
    Reset_Level              => Reset_Level
  )
  port map(
    Clock                    => Clock,
    Reset                    => Reset,
    DACin                    => Reg_Out,
    DACout                   => DACout
  );

end architecture;
