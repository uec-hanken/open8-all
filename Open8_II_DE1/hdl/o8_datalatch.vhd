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
-- VHDL Units :  o8_datalatch
-- Description:  Latches a byte of external data and issues an interrupt on
--                capture.
--
--
-- Register Map:
-- Offset  Bitfield Description                        Read/Write
--   0x00  AAAAAAAA Latched Value                      (RW)
--
-- Note: Cut the path between LData_q1 and L_Data for timing analysis
--
-- Revision History
-- Author          Date     Change
------------------ -------- ---------------------------------------------------
-- Seth Henry      01/22/20 Design Start
-- Seth Henry      04/16/20 Modified to use Open8 bus record

library ieee;
use ieee.std_logic_1164.all;

library work;
  use work.open8_pkg.all;

entity o8_datalatch is
generic(
  Address                    : ADDRESS_TYPE
);
port(
  Open8_Bus                  : in  OPEN8_BUS_TYPE;
  Rd_Data                    : out DATA_TYPE;
  Interrupt                  : out std_logic;
  --
  L_Strobe                   : in  std_logic;
  L_Data                     : in  DATA_TYPE
);
end entity;

architecture behave of o8_datalatch is

  alias Clock                is Open8_Bus.Clock;
  alias Reset                is Open8_Bus.Reset;

  constant User_Addr         : std_logic_vector(15 downto 0) := Address;
  alias  Comp_Addr           is Open8_Bus.Address(15 downto 0);
  signal Addr_Match          : std_logic;
  signal Rd_En               : std_logic;

  signal Strobe_sr           : std_logic_vector(3 downto 0);
  signal Strobe_re           : std_logic;

  signal LData_q1            : DATA_TYPE;
  signal LData_q2            : DATA_TYPE;
  signal LData_q3            : DATA_TYPE;

begin

  Addr_Match                 <= Open8_Bus.Rd_En when Comp_Addr = User_Addr else '0';
  Strobe_re                  <= Strobe_sr(2) and not Strobe_sr(3);

  io_reg: process( Clock, Reset )
  begin
    if( Reset = Reset_Level )then
      Rd_En                  <= '0';
      Rd_Data                <= OPEN8_NULLBUS;
      Strobe_sr              <= (others => '0');
      Interrupt              <= '0';
      LData_q1               <= x"00";
      LData_q2               <= x"00";
      LData_q3               <= x"00";
    elsif( rising_edge( Clock ) )then
      Strobe_sr              <= Strobe_sr(2 downto 0) & L_Strobe;

      LData_q1               <= L_Data;
      LData_q2               <= LData_q1;
      Interrupt              <= Strobe_re;
      if( Strobe_re = '1' )then
        LData_q3             <= LData_q2;
      end if;

      Rd_Data                <= OPEN8_NULLBUS;
      Rd_En                  <= Addr_Match;
      if( Rd_En = '1' )then
        Rd_Data              <= LData_q3;
      end if;
    end if;
  end process;

end architecture;
