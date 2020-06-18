-- Copyright (c)2019, 2020 Jeremy Seth Henry
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
-- VHDL Units :  o8_vdsm12
-- Description:  12-bit variable delta-sigma modulator. Requires Open8_pkg.vhd
--
-- Register Map:
-- Offset  Bitfield Description                        Read/Write
--   0x0   AAAAAAAA Pending DAC Level (7:0)            (R/W)
--   0x1   ----AAAA Pending DAC Level (11:8)           (R/W)
--   0x2   -------- Clear DAC Output (on write)        (WO)
--   0x3   AAAAAAAA Update DAC Output (on write)       (RO)
--
-- Revision History
-- Author          Date     Change
------------------ -------- ---------------------------------------------------
-- Seth Henry      12/18/19 Design start
-- Seth Henry      04/10/20 Code Cleanup
-- Seth Henry      04/16/20 Modified to use Open8 bus record

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

library work;
  use work.open8_pkg.all;

entity o8_vdsm12 is
generic(
  Default_Value              : std_logic_vector(11 downto 0) := x"000";
  Address                    : ADDRESS_TYPE
);
port(
  Open8_Bus                  : in  OPEN8_BUS_TYPE;
  Rd_Data                    : out DATA_TYPE;
  --
  DACOut                     : out std_logic
);
end entity;

architecture behave of o8_vdsm12 is

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

  constant DAC_Width         : integer := 12;

  signal DAC_Val_LB          : std_logic_vector(7 downto 0) := x"00";
  signal DAC_Val_UB          : std_logic_vector(3 downto 0) := x"0";
  signal DAC_Val             : std_logic_vector(DAC_Width-1 downto 0)  :=
                                (others => '0');

  constant DELTA_1_I         : integer := 1;
  constant DELTA_2_I         : integer := 5;
  constant DELTA_3_I         : integer := 25;
  constant DELTA_4_I         : integer := 75;
  constant DELTA_5_I         : integer := 125;
  constant DELTA_6_I         : integer := 250;
  constant DELTA_7_I         : integer := 500;
  constant DELTA_8_I         : integer := 1000;
  constant DELTA_9_I         : integer := 2000;
  constant DELTA_10_I        : integer := 3000;

  constant DELTA_1           : std_logic_vector(DAC_Width-1 downto 0) :=
                                conv_std_logic_vector(DELTA_1_I, DAC_Width);
  constant DELTA_2           : std_logic_vector(DAC_Width-1 downto 0) :=
                                conv_std_logic_vector(DELTA_2_I, DAC_Width);
  constant DELTA_3           : std_logic_vector(DAC_Width-1 downto 0) :=
                                conv_std_logic_vector(DELTA_3_I, DAC_Width);
  constant DELTA_4           : std_logic_vector(DAC_Width-1 downto 0) :=
                                conv_std_logic_vector(DELTA_4_I, DAC_Width);
  constant DELTA_5           : std_logic_vector(DAC_Width-1 downto 0) :=
                                conv_std_logic_vector(DELTA_5_I, DAC_Width);
  constant DELTA_6           : std_logic_vector(DAC_Width-1 downto 0) :=
                                conv_std_logic_vector(DELTA_6_I, DAC_Width);
  constant DELTA_7           : std_logic_vector(DAC_Width-1 downto 0) :=
                                conv_std_logic_vector(DELTA_7_I, DAC_Width);
  constant DELTA_8           : std_logic_vector(DAC_Width-1 downto 0) :=
                                conv_std_logic_vector(DELTA_8_I, DAC_Width);
  constant DELTA_9           : std_logic_vector(DAC_Width-1 downto 0) :=
                                conv_std_logic_vector(DELTA_9_I, DAC_Width);
  constant DELTA_10          : std_logic_vector(DAC_Width-1 downto 0) :=
                                conv_std_logic_vector(DELTA_10_I, DAC_Width);

  constant MAX_PERIOD        : integer := 2**DAC_Width;
  constant DIV_WIDTH         : integer := DAC_Width * 2;

  constant PADJ_1_I          : integer := DELTA_1_I * MAX_PERIOD;
  constant PADJ_2_I          : integer := DELTA_2_I * MAX_PERIOD;
  constant PADJ_3_I          : integer := DELTA_3_I * MAX_PERIOD;
  constant PADJ_4_I          : integer := DELTA_4_I * MAX_PERIOD;
  constant PADJ_5_I          : integer := DELTA_5_I * MAX_PERIOD;
  constant PADJ_6_I          : integer := DELTA_6_I * MAX_PERIOD;
  constant PADJ_7_I          : integer := DELTA_7_I * MAX_PERIOD;
  constant PADJ_8_I          : integer := DELTA_8_I * MAX_PERIOD;
  constant PADJ_9_I          : integer := DELTA_9_I * MAX_PERIOD;
  constant PADJ_10_I         : integer := DELTA_10_I * MAX_PERIOD;

  constant PADJ_1            : std_logic_vector(DIV_WIDTH-1 downto 0) :=
                                conv_std_logic_vector(PADJ_1_I,DIV_WIDTH);
  constant PADJ_2            : std_logic_vector(DIV_WIDTH-1 downto 0) :=
                                conv_std_logic_vector(PADJ_2_I,DIV_WIDTH);
  constant PADJ_3            : std_logic_vector(DIV_WIDTH-1 downto 0) :=
                                conv_std_logic_vector(PADJ_3_I,DIV_WIDTH);
  constant PADJ_4            : std_logic_vector(DIV_WIDTH-1 downto 0) :=
                                conv_std_logic_vector(PADJ_4_I,DIV_WIDTH);
  constant PADJ_5            : std_logic_vector(DIV_WIDTH-1 downto 0) :=
                                conv_std_logic_vector(PADJ_5_I,DIV_WIDTH);
  constant PADJ_6            : std_logic_vector(DIV_WIDTH-1 downto 0) :=
                                conv_std_logic_vector(PADJ_6_I,DIV_WIDTH);
  constant PADJ_7            : std_logic_vector(DIV_WIDTH-1 downto 0) :=
                                conv_std_logic_vector(PADJ_7_I,DIV_WIDTH);
  constant PADJ_8            : std_logic_vector(DIV_WIDTH-1 downto 0) :=
                                conv_std_logic_vector(PADJ_8_I,DIV_WIDTH);
  constant PADJ_9            : std_logic_vector(DIV_WIDTH-1 downto 0) :=
                                conv_std_logic_vector(PADJ_9_I,DIV_WIDTH);
  constant PADJ_10           : std_logic_vector(DIV_WIDTH-1 downto 0) :=
                                conv_std_logic_vector(PADJ_10_I,DIV_WIDTH);

  signal DACin_q             : std_logic_vector(DAC_Width-1 downto 0) :=
                                (others => '0');

  signal Divisor             : std_logic_vector(DIV_WIDTH-1 downto 0) :=
                                (others => '0');

  signal Dividend            : std_logic_vector(DIV_WIDTH-1 downto 0) :=
                                (others => '0');

  signal q                   : std_logic_vector(DIV_WIDTH*2-1 downto 0) :=
                                (others => '0');

  signal diff                : std_logic_vector(DIV_WIDTH downto 0) :=
                                (others => '0');

  constant CB                : integer := ceil_log2(DIV_WIDTH);
  signal count               : std_logic_vector(CB-1 downto 0) :=
                                (others => '0');

  signal Next_Width          : std_logic_vector(DAC_Width-1 downto 0) :=
                                (others => '0');

  signal Next_Period         : std_logic_vector(DAC_Width-1 downto 0) :=
                                (others => '0');

  signal PWM_Width           : std_logic_vector(DAC_Width-1 downto 0) :=
                                (others => '0');

  signal PWM_Period          : std_logic_vector(DAC_Width-1 downto 0) :=
                                (others => '0');

  signal Width_Ctr           : std_logic_vector(DAC_Width-1 downto 0) :=
                                (others => '0');

  signal Period_Ctr          : std_logic_vector(DAC_Width-1 downto 0) :=
                                (others => '0');

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
      DAC_Val_LB             <= x"00";
      DAC_Val_UB             <= x"0";
      DAC_Val                <= Default_Value;
    elsif( rising_edge( Clock ) )then
      Reg_Sel                <= Reg_Addr;

      Wr_En                  <= Addr_Match and Open8_Bus.Wr_En;
      Wr_Data_q              <= Open8_Bus.Wr_Data;
      if( Wr_En = '1' )then
        case( Reg_Sel )is
          when "00" =>
            DAC_Val_LB       <= Wr_Data_q;
          when "01" =>
            DAC_Val_UB       <= Wr_Data_q(3 downto 0);
          when "10" =>
            DAC_Val          <= (others => '0');
          when "11" =>
            DAC_Val          <= DAC_Val_UB & DAC_Val_LB;
          when others => null;
        end case;
      end if;

      Rd_Data                <= OPEN8_NULLBUS;
      Rd_En                  <= Addr_Match and Open8_Bus.Rd_En;
      if( Rd_En = '1' )then
        case( Reg_Sel )is
          when "00" =>
            Rd_Data          <= DAC_Val_LB;
          when "01" =>
            Rd_Data          <= x"0" & DAC_Val_UB;
          when others => null;
        end case;
      end if;
    end if;
  end process;

  diff                       <= ('0' & q(DIV_WIDTH*2-2 downto DIV_WIDTH-1)) -
                                ('0' & Divisor);

  Dividend   <= PADJ_2  when DACin_q >= DELTA_2_I and DACin_q < DELTA_3_I else
                PADJ_3  when DACin_q >= DELTA_3_I and DACin_q < DELTA_4_I else
                PADJ_4  when DACin_q >= DELTA_4_I and DACin_q < DELTA_5_I else
                PADJ_5  when DACin_q >= DELTA_5_I and DACin_q < DELTA_6_I else
                PADJ_6  when DACin_q >= DELTA_6_I and DACin_q < DELTA_7_I else
                PADJ_7  when DACin_q >= DELTA_7_I and DACin_q < DELTA_8_I else
                PADJ_8  when DACin_q >= DELTA_8_I and DACin_q < DELTA_9_I else
                PADJ_9  when DACin_q >= DELTA_9_I and DACin_q < DELTA_10_I else
                PADJ_10 when DACin_q >= DELTA_10_I else
                PADJ_1;

  Next_Width <= DELTA_1  when DACin_q >= DELTA_1_I and DACin_q < DELTA_2_I else
                DELTA_2  when DACin_q >= DELTA_2_I and DACin_q < DELTA_3_I else
                DELTA_3  when DACin_q >= DELTA_3_I and DACin_q < DELTA_4_I else
                DELTA_4  when DACin_q >= DELTA_4_I and DACin_q < DELTA_5_I else
                DELTA_5  when DACin_q >= DELTA_5_I and DACin_q < DELTA_6_I else
                DELTA_6  when DACin_q >= DELTA_6_I and DACin_q < DELTA_7_I else
                DELTA_7  when DACin_q >= DELTA_7_I and DACin_q < DELTA_8_I else
                DELTA_8  when DACin_q >= DELTA_8_I and DACin_q < DELTA_9_I else
                DELTA_9  when DACin_q >= DELTA_9_I and DACin_q < DELTA_10_I else
                DELTA_10 when DACin_q >= DELTA_10_I else
                (others => '0');

  Next_Period                <= q(DAC_Width-1 downto 0) - 1;

  vDSM_proc: process( Clock, Reset )
  begin
    if( Reset = Reset_Level )then
      q                      <= (others => '0');
      count                  <= (others => '1');
      Divisor                <= (others => '0');
      DACin_q                <= (others => '0');
      PWM_Width              <= (others => '0');
      PWM_Period             <= (others => '0');
      Period_Ctr             <= (others => '0');
      Width_Ctr              <= (others => '0');
      DACOut                 <= '0';
    elsif( rising_edge(Clock) )then
      q                      <= diff(DIV_WIDTH-1 downto 0) &
                                q(DIV_WIDTH-2 downto 0) & '1';
      if( diff(DIV_WIDTH) = '1' )then
        q                    <= q(DIV_WIDTH*2-2 downto 0) & '0';
      end if;

      count                  <= count + 1;
      if( count = DIV_WIDTH )then
        PWM_Width            <= Next_Width;
        PWM_Period           <= Next_Period;
        DACin_q              <= DAC_val;
        Divisor              <= (others => '0');
        Divisor(DAC_Width-1 downto 0) <= DACin_q;
        q                   <= conv_std_logic_vector(0,DIV_WIDTH) & Dividend;
        count               <= (others => '0');
      end if;

      Period_Ctr            <= Period_Ctr - 1;
      Width_Ctr             <= Width_Ctr - 1;

      DACOut                <= '1';
      if( Width_Ctr = 0 )then
        DACOut              <= '0';
        Width_Ctr           <= (others => '0');
      end if;

      if( Period_Ctr = 0 )then
        Period_Ctr          <= PWM_Period;
        Width_Ctr           <= PWM_Width;
      end if;

    end if;
  end process;

end architecture;
