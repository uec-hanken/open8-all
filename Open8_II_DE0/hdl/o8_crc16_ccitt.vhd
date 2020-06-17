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
-- VHDL Units : o8_crc16_ccitt
-- Description: Implements the 16-bit CCITT CRC on byte-wide data suitable for
--            :  use with the Open8 CPU. Logic equations were taken from
--            :  Intel/Altera app note AN049.
--
-- Notes      :  Writing to the byte counter will reset all registers, and to
--            :   should be used to clear the CRC accumulator/byte counter
--            :   between frames.
--
-- Register Map:
-- Offset  Bitfield Description                        Read/Write
--   0x0   AAAAAAAA Data Input register (calc on write)(R/W)
--   0x1   AAAAAAAA Byte Counter (clear all on write)  (R/W)
--   0x2   AAAAAAAA B0 of calculated CRC               (RO)
--   0x3   AAAAAAAA B1 of calculated CRC               (RO)
--
-- Revision History
-- Author          Date     Change
------------------ -------- ---------------------------------------------------
-- Seth Henry      12/19/19 Design Start
-- Seth Henry      04/16/20 Modified to use Open8 bus record

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

library work;
  use work.open8_pkg.all;

entity o8_crc16_ccitt is
generic(
  Address                    : ADDRESS_TYPE
);
port(
  Open8_Bus                  : in  OPEN8_BUS_TYPE;
  Rd_Data                    : out DATA_TYPE
);
end entity;

architecture behave of o8_crc16_ccitt is

  alias Clock                is Open8_Bus.Clock;
  alias Reset                is Open8_Bus.Reset;

  constant Poly_Init         : std_logic_vector(15 downto 0) :=
                                (others => '0');

  constant User_Addr         : std_logic_vector(15 downto 2)
                               := Address(15 downto 2);
  alias  Comp_Addr           is Open8_Bus.Address(15 downto 2);
  alias  Reg_Addr            is Open8_Bus.Address(1 downto 0);
  signal Reg_Sel             : std_logic_vector(1 downto 0) :=
                               (others => '0');
  signal Addr_Match          : std_logic;
  signal Wr_En               : std_logic;
  signal Wr_Data_q           : DATA_TYPE := (others => '0');
  signal Rd_En               : std_logic;

  signal Next_Byte           : DATA_TYPE := (others => '0');
  signal Byte_Count          : DATA_TYPE := (others => '0');

  signal Calc_En             : std_logic := '0';
  signal Buffer_En           : std_logic := '0';
  signal Data                : DATA_TYPE := (others => '0');
  signal Exr                 : DATA_TYPE := (others => '0');
  signal Reg                 : std_logic_vector(15 downto 0) :=
                                (others => '0');
  signal Comp_Data           : std_logic_vector(15 downto 0) :=
                                (others => '0');

begin

  Addr_Match                 <= '1' when Comp_Addr = User_Addr else '0';

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
      Reg_Sel                <= "00";
      Wr_En                  <= '0';
      Wr_Data_q              <= x"00";
      Rd_En                  <= '0';
      Rd_Data                <= OPEN8_NULLBUS;

      Byte_Count             <= x"00";
      Calc_En                <= '0';
      Buffer_En              <= '0';
      Data                   <= x"00";
      Reg                    <= x"0000";
    elsif( rising_edge(Clock) )then
      Reg_Sel                <= Reg_Addr;

      Wr_En                  <= Addr_Match and Open8_Bus.Wr_En;
      Wr_Data_q              <= Open8_Bus.Wr_Data;

      if( Wr_En = '1' )then
        case( Reg_Sel )is
          when "00" => -- Load next byte
            Data             <= Wr_Data_q;
            Calc_En          <= '1';

          when "01" => -- Clear accumulator and byte counter
            Byte_Count       <= x"00";
            Reg              <= Poly_Init;

          when others => null;
        end case;
      end if;

      Rd_En                  <= Addr_Match and Open8_Bus.Rd_En;
      Rd_Data                <= OPEN8_NULLBUS;
      if( Rd_En = '1' )then
        case( Reg_Sel )is
          when "00" => -- Read last byte
            Rd_Data          <= Data;

          when "01" => -- Read the byte counter
            Rd_Data          <= Byte_Count;

          when "10" => -- Read the lower byte of the calculated CRC
            Rd_Data          <= Comp_Data(7 downto 0);

          when "11" => -- Read the upper byte of the calculated CRC
            Rd_Data          <= Comp_Data(15 downto 8);

          when others => null;
        end case;
      end if;

      Calc_En                <= '0';
      Buffer_En              <= Calc_En;

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

      if( Buffer_En = '1' )then
        Byte_Count           <= Byte_Count + 1;
        Comp_Data            <= Reg xor x"FFFF";
      end if;

    end if;
  end process;

end architecture;
