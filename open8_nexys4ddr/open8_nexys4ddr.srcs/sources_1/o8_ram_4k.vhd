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
-- VHDL Units :  o8_ram_4k
-- Description:  Provides a wrapper layer for a 4kx8 RAM model with interface
--            :   logic for the Open8 CPU. Also provides an optional write
--            :   enable register that prevents regions from being written
--            :   by non-ISR code (uses the I flag) as a way to prevent tasks
--            :   from inadvertently writing outside of their designated
--            :   memory space.
--            :  When enabled, the write mask logically divides the memory into
--            :   32, 128 byte regions, corresponding to the 32 bits in the WPR
--            :   register.
--
-- WP Register Map:
-- Offset  Bitfield Description                        Read/Write
--   0x00  AAAAAAAA Region Enables  7:0                  (RW)
--   0x01  AAAAAAAA Region Enables 15:8                  (RW)
--   0x02  AAAAAAAA Region Enables 23:16                 (RW)
--   0x03  AAAAAAAA Region Enables 31:24                 (RW)
--
-- Revision History
-- Author          Date     Change
------------------ -------- ---------------------------------------------------
-- Seth Henry      04/16/20 Revision block added
-- Seth Henry      05/12/20 Added write protect logic

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

library work;
  use work.open8_pkg.all;

entity o8_ram_4k is
generic(
  Write_Protect              : boolean := FALSE;
  Default_Mask               : std_logic_vector(31 downto 0) := x"00000000";
  Address_WPR                : ADDRESS_TYPE := x"1000";
  Address_RAM                : ADDRESS_TYPE
);
port(
  Open8_Bus                  : in  OPEN8_BUS_TYPE;
  Rd_Data                    : out DATA_TYPE
);
end entity;

architecture behave of o8_ram_4k is

  alias  Clock               is Open8_Bus.Clock;
  alias  Reset               is Open8_Bus.Reset;
  alias  ISR_En              is Open8_Bus.GP_Flags(EXT_ISR);
  alias  Wr_En               is Open8_Bus.Wr_En;
  alias  Rd_En               is Open8_Bus.Rd_En;

  constant WPR_User_Addr     : std_logic_vector(15 downto 2)
                               := Address_WPR(15 downto 2);

  constant RAM_User_Addr     : std_logic_vector(15 downto 12)
                               := Address_RAM(15 downto 12);

  alias  WPR_Comp_Addr       is Open8_Bus.Address(15 downto 2);
  signal WPR_Addr_Match      : std_logic := '0';

  alias  WPR_Reg_Sel_d       is Open8_Bus.Address(1 downto 0);
  signal WPR_Reg_Sel_q       : std_logic_vector(1 downto 0) :=
                                (others => '0');

  alias  Wr_Data_d           is Open8_Bus.Wr_Data;
  signal WPR_Wr_Data_q       : DATA_TYPE := x"00";

  signal Write_Mask          : std_logic_vector(31 downto 0) :=
                                x"00000000";
  alias  Write_Mask_0        is Write_Mask( 7 downto  0);
  alias  Write_Mask_1        is Write_Mask(15 downto  8);
  alias  Write_Mask_2        is Write_Mask(23 downto 16);
  alias  Write_Mask_3        is Write_Mask(31 downto 24);

  signal WPR_Wr_En_d         : std_logic := '0';
  signal WPR_Wr_En_q         : std_logic := '0';
  signal WPR_Rd_En_d         : std_logic := '0';
  signal WPR_Rd_En_q         : std_logic := '0';

  alias  RAM_Base_Addr       is Open8_Bus.Address(15 downto 12);
  alias  RAM_Addr            is Open8_Bus.Address(11 downto 0);

  alias  RAM_Rgn_Addr        is Open8_Bus.Address(11 downto 7);

  signal RAM_Region_Match    : std_logic := '0';
  signal RAM_Addr_Match      : std_logic := '0';

  signal RAM_Wr_En_d         : std_logic := '0';
  signal RAM_Rd_En_d         : std_logic := '0';
  signal RAM_Rd_En_q         : std_logic := '0';
  signal RAM_Rd_Data         : DATA_TYPE := OPEN8_NULLBUS;

begin

Write_Protect_On : if( Write_Protect )generate

  WPR_Addr_Match             <= '1' when WPR_Comp_Addr = WPR_User_Addr else '0';
  WPR_Wr_En_d                <= WPR_Addr_Match and Wr_En and ISR_En;
  WPR_Rd_En_d                <= WPR_Addr_Match and Rd_En;

  RAM_Addr_Match             <= '1' when RAM_Base_Addr = RAM_User_Addr else '0';

  RAM_Region_Match           <= Write_Mask(conv_integer(RAM_Rgn_Addr)) or
                                ISR_En;

  RAM_Rd_En_d                <= RAM_Addr_Match and Rd_En;
  RAM_Wr_En_d                <= RAM_Addr_Match and RAM_Region_Match and Wr_En;

  RAM_proc: process( Reset, Clock )
  begin
    if( Reset = Reset_Level )then

      WPR_Reg_Sel_q          <= (others => '0');
      WPR_Wr_Data_q          <= x"00";

      WPR_Wr_En_q            <= '0';
      WPR_Rd_En_q            <= '0';

      Write_Mask             <= Default_Mask;

      RAM_Rd_En_q            <= '0';
      Rd_Data                <= OPEN8_NULLBUS;
    elsif( rising_edge(Clock) )then
      WPR_Reg_Sel_q          <= WPR_Reg_Sel_d;

      WPR_Wr_En_q            <= WPR_Wr_En_d;
      WPR_Wr_Data_q          <= Wr_Data_d;
      if( WPR_Wr_En_q = '1' )then
        case( WPR_Reg_Sel_q )is
          when "00" =>
            Write_Mask_0     <= WPR_Wr_Data_q;
          when "01" =>
            Write_Mask_1     <= WPR_Wr_Data_q;
          when "10" =>
            Write_Mask_2     <= WPR_Wr_Data_q;
          when "11" =>
            Write_Mask_3     <= WPR_Wr_Data_q;
          when others =>
            null;
        end case;
      end if;

      WPR_Rd_En_q            <= WPR_Rd_En_d;
      RAM_Rd_En_q            <= RAM_Rd_En_d;

      Rd_Data                <= OPEN8_NULLBUS;
      if( RAM_Rd_En_q = '1' )then
        Rd_Data              <= RAM_Rd_Data;
      elsif( WPR_Rd_En_q = '1'  )then
        case( WPR_Reg_Sel_q )is
          when "00" =>
            Rd_Data          <= Write_Mask_0;
          when "01" =>
            Rd_Data          <= Write_Mask_1;
          when "10" =>
            Rd_Data          <= Write_Mask_2;
          when "11" =>
            Rd_Data          <= Write_Mask_3;
          when others =>
            null;
        end case;
      end if;
    end if;
  end process;

end generate;

Write_Protect_Off : if( not Write_Protect )generate

  RAM_Addr_Match             <= '1' when RAM_Base_Addr = RAM_User_Addr else '0';

  RAM_Rd_En_d                <= RAM_Addr_Match and Open8_Bus.Rd_En;
  RAM_Wr_En_d                <= RAM_Addr_Match and Open8_Bus.Wr_En;

  RAM_proc: process( Reset, Clock )
  begin
    if( Reset = Reset_Level )then
      RAM_Rd_En_q            <= '0';
      Rd_Data                <= OPEN8_NULLBUS;
    elsif( rising_edge(Clock) )then
      RAM_Rd_En_q            <= RAM_Rd_En_d;
      Rd_Data                <= OPEN8_NULLBUS;
      if( RAM_Rd_En_q = '1' )then
        Rd_Data              <= RAM_Rd_Data;
      end if;
    end if;
  end process;

end generate;

  -- Note that this RAM should be created without an output FF (unregistered Q)
  U_RAM : entity work.ram_4k_core
  port map(
    address                  => RAM_Addr,
    clock                    => Clock,
    data                     => Wr_Data_d,
    wren                     => RAM_Wr_En_d,
    q                        => RAM_Rd_Data
  );

end architecture;
