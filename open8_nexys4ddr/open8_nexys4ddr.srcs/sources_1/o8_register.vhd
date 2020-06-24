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
-- VHDL Units :  o8_register
-- Description:  Provides a single addressible 8-bit output register
--
-- Register Map:
-- Offset  Bitfield Description                        Read/Write
--   0x00  AAAAAAAA Registered Outputs                    (RW)
--
-- Revision History
-- Author          Date     Change
------------------ -------- ---------------------------------------------------
-- Seth Henry      12/20/19 Design Start
-- Seth Henry      04/16/20 Modified to use Open8 bus record
-- Seth Henry      05/18/20 Added write qualification input

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.std_logic_arith.all;
  use ieee.std_logic_misc.all;

library work;
  use work.open8_pkg.all;

entity o8_register is
generic(
  Default_Value              : DATA_TYPE := x"00";
  Address                    : ADDRESS_TYPE
);
port(
  Open8_Bus                  : in  OPEN8_BUS_TYPE;
  Write_Qual                 : in  std_logic := '1';
  Rd_Data                    : out DATA_TYPE;
  --
  Register_Out               : out DATA_TYPE
);
end entity;

architecture behave of o8_register is

  alias Clock                is Open8_Bus.Clock;
  alias Reset                is Open8_Bus.Reset;

  constant User_Addr         : std_logic_vector(15 downto 0)
                               := Address(15 downto 0);
  alias  Comp_Addr           is Open8_Bus.Address(15 downto 0);
  signal Addr_Match          : std_logic;

  signal Wr_En_d             : std_logic := '0';
  signal Wr_En_q             : std_logic := '0';
  alias  Wr_Data_d           is Open8_Bus.Wr_Data;
  signal Wr_Data_q           : DATA_TYPE := x"00";
  signal Rd_En_d             : std_logic := '0';
  signal Rd_En_q             : std_logic := '0';

  signal Reg_Out             : DATA_TYPE := x"00";

begin

  Addr_Match                 <= '1' when Comp_Addr = User_Addr else '0';
  Wr_En_d                    <= Addr_Match and Open8_Bus.Wr_En;
  Rd_En_d                    <= Addr_Match and Open8_Bus.Rd_En;

  io_reg: process( Clock, Reset )
  begin
    if( Reset = Reset_Level )then
      Wr_En_q                <= '0';
      Wr_Data_q              <= x"00";
      Reg_Out                <= Default_Value;
      Rd_En_q                <= '0';
      Rd_Data                <= OPEN8_NULLBUS;
    elsif( rising_edge( Clock ) )then
      Wr_En_q                <= Wr_En_d;
      Wr_Data_q              <= Wr_Data_d;
      if( Wr_En_q = '1' and Write_Qual = '1' )then
        Reg_Out              <= Wr_Data_q;
      end if;

      Rd_Data                <= OPEN8_NULLBUS;
      Rd_En_q                <= Rd_En_d;
      if( Rd_En_q = '1' )then
        Rd_Data              <= Reg_Out;
      end if;
    end if;
  end process;

  Register_Out               <= Reg_Out;

end architecture;
