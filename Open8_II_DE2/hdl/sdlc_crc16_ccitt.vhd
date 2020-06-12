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
-- VHDL Units :  crc16_ccitt
-- Description:  Implements the 16-bit CCITT CRC on byte-wide data. Logic
--  equations were taken from Intel/Altera app note AN049.
--
-- Revision History
-- Author          Date     Change
------------------ -------- ---------------------------------------------------
-- Seth Henry      04/14/20 Code cleanup and revision section added

library ieee;
use ieee.std_logic_1164.all;

library work;
  use work.sdlc_serial_pkg.all;

entity sdlc_crc16_ccitt is
generic(
  Poly_Init                  : std_logic_vector(15 downto 0) := x"0000";
  Reset_Level                : std_logic := '1'
);
port(
  Clock                      : in  std_logic;
  Reset                      : in  std_logic;
  --
  Clear                      : in  std_logic;
  Wr_En                      : in  std_logic;
  Wr_Data                    : in  DATA_IN_TYPE;
  --
  CRC16_Valid                : out std_logic;
  CRC16_Out                  : out CRC_OUT_TYPE
);
end entity;

architecture behave of sdlc_crc16_ccitt is

  signal Calc_En             : std_logic    := '0';
  signal Buffer_En           : std_logic    := '0';
  signal Data                : DATA_IN_TYPE := x"00";
  signal Exr                 : DATA_IN_TYPE := x"00";
  signal Reg                 : CRC_OUT_TYPE := x"0000";

begin

  Exr(0)                     <= Reg(0) xor Data(0);
  Exr(1)                     <= Reg(1) xor Data(1);
  Exr(2)                     <= Reg(2) xor Data(2);
  Exr(3)                     <= Reg(3) xor Data(3);
  Exr(4)                     <= Reg(4) xor Data(4);
  Exr(5)                     <= Reg(5) xor Data(5);
  Exr(6)                     <= Reg(6) xor Data(6);
  Exr(7)                     <= Reg(7) xor Data(7);

  CRC16_Calc: process( Clock, Reset )
  begin
    if( Reset = Reset_Level )then
      Calc_En                <= '0';
      Buffer_En              <= '0';
      Data                   <= x"00";
      Reg                    <= x"0000";
      CRC16_Out              <= x"0000";
      CRC16_Valid            <= '0';
    elsif( rising_edge(Clock) )then
      Calc_En                <= Wr_En;
      if( Wr_En  = '1' )then
        Data                 <= Wr_Data;
      end if;

      if( Calc_En = '1' )then
        Reg(0)               <= Reg(8)  xor            Exr(4) xor Exr(0);
        Reg(1)               <= Reg(9)  xor            Exr(5) xor Exr(1);
        Reg(2)               <= Reg(10) xor            Exr(6) xor Exr(2);
        Reg(3)               <= Reg(11) xor Exr(0) xor Exr(7) xor Exr(3);
        Reg(4)               <= Reg(12) xor Exr(1)                      ;
        Reg(5)               <= Reg(13) xor Exr(2)                      ;
        Reg(6)               <= Reg(14) xor Exr(3)                      ;
        Reg(7)               <= Reg(15) xor Exr(4)            xor Exr(0);
        Reg(8)               <= Exr(0)  xor Exr(5)            xor Exr(1);
        Reg(9)               <= Exr(1)  xor Exr(6)            xor Exr(2);
        Reg(10)              <= Exr(2)  xor Exr(7)            xor Exr(3);
        Reg(11)              <= Exr(3)                                  ;
        Reg(12)              <= Exr(4)                        xor Exr(0);
        Reg(13)              <= Exr(5)                        xor Exr(1);
        Reg(14)              <= Exr(6)                        xor Exr(2);
        Reg(15)              <= Exr(7)                        xor Exr(3);
      end if;

      if( Clear = '1' )then
        Reg                  <= Poly_Init;
      end if;

      Buffer_En              <= Calc_En;
      if( Buffer_En = '1' )then
        CRC16_Out            <= Reg xor x"FFFF";
      end if;
      CRC16_Valid            <= Buffer_En;
    end if;
  end process;

end architecture;
