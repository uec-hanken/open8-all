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
-- VHDL Units :  o8_gpio
-- Description:  Provides a single 8-bit GPIO register
--
-- Register Map:
-- Offset  Bitfield Description                        Read/Write
--   0x00  AAAAAAAA Output Register                       (RW)
--   0x01  AAAAAAAA Direction Register                    (RW)
--   0x03  AAAAAAAA Input Register                        (RO)
--
-- Revision History
-- Author          Date     Change
------------------ -------- ---------------------------------------------------
-- Seth Henry      12/20/13 Design Start
-- Seth Henry      04/10/20 Code cleanup and register documentation
--                          Also removed "input only" generic, as there is a
--                           separate module for that
-- Seth Henry      04/16/20 Modified to make use of Open8 bus record

library ieee;
use ieee.std_logic_1164.all;

library work;
  use work.open8_pkg.all;

entity o8_gpio is
generic(
  Default_Out                : DATA_TYPE := x"00";
  Default_En                 : DATA_TYPE := x"00";
  Address                    : ADDRESS_TYPE
);
port(
  Open8_Bus                  : in  OPEN8_BUS_TYPE;
  Rd_Data                    : out DATA_TYPE;
  --
  GPIO                       : inout DATA_TYPE
);
end entity;

architecture behave of o8_gpio is

  alias Clock                is Open8_Bus.Clock;
  alias Reset                is Open8_Bus.Reset;

  constant User_Addr         : std_logic_vector(15 downto 2)
                               := Address(15 downto 2);
  alias  Comp_Addr           is Open8_Bus.Address(15 downto 2);
  alias  Reg_Addr            is Open8_Bus.Address(1 downto 0);
  signal Reg_Sel             : std_logic_vector(1 downto 0) := "00";
  signal Addr_Match          : std_logic := '0';
  signal Wr_En               : std_logic := '0';
  signal Wr_Data_q           : DATA_TYPE := x"00";
  signal Rd_En               : std_logic := '0';

  signal User_Out            : DATA_TYPE := x"00";
  signal User_En             : DATA_TYPE := x"00";
  signal User_In             : DATA_TYPE := x"00";

begin

  Addr_Match                 <= '1' when Comp_Addr = User_Addr else '0';

  io_reg: process( Clock, Reset )
  begin
    if( Reset = Reset_Level )then
      Reg_Sel                <= "00";
      Rd_En                  <= '0';
      Rd_Data                <= OPEN8_NULLBUS;
      Wr_En                  <= '0';
      Wr_Data_q              <= x"00";
      User_Out               <= Default_Out;
      User_En                <= Default_En;
    elsif( rising_edge( Clock ) )then
      Reg_Sel                <= Reg_Addr;

      Wr_En                  <= Addr_Match and Open8_Bus.Wr_En;
      Wr_Data_q              <= Open8_Bus.Wr_Data;
      if( Wr_En = '1' )then
        case( Reg_Sel )is
          when "00" =>
            User_Out         <= Wr_Data_q;
          when "01" =>
            User_En          <= Wr_Data_q;
          when others => null;
        end case;
      end if;

      User_In                <= GPIO;

      Rd_Data                <= OPEN8_NULLBUS;
      Rd_En                  <= Addr_Match and Open8_Bus.Rd_En;
      if( Rd_En = '1' )then
        Rd_Data              <= User_In;
        case( Reg_Sel )is
          when "00" =>
            Rd_Data          <= User_Out;
          when "01" =>
            Rd_Data          <= User_En;
          when "10" =>
            Rd_Data          <= User_In;
          when others => null;
        end case;
      end if;
    end if;
  end process;

  Output_Ctl_proc: process( User_Out, User_En )
  begin
    for i in 0 to 7 loop
      GPIO(i)                <= 'Z';
      if( User_En(i) = '1' )then
        GPIO(i)              <= User_Out(i);
      end if;
    end loop;
  end process;

end architecture;
