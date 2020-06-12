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
-- VHDL Units :  vdsm8
-- Description:  8-bit variable delta-sigma modulator single-bit DAC
--
-- Revision History
-- Author          Date     Change
------------------ -------- ---------------------------------------------------
-- Seth Henry      04/25/18 Initial design
-- Seth Henry      04/14/20 Code cleanup and revision section added

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity vdsm8 is
generic(
  Reset_Level           : std_logic := '1';
  -- Do not adjust alone! DELTA constants must be
  --  changed as well.
  DAC_Width             : integer := 8
);
port(
  Clock                 : in  std_logic;
  Reset                 : in  std_logic;
  DACin                 : in  std_logic_vector(DAC_Width-1 downto 0);
  DACout                : out std_logic
);
end entity;

architecture behave of vdsm8 is

  function ceil_log2 (x : in natural) return natural is
    variable retval     : natural;
  begin
    retval              := 1;
    while ((2**retval) - 1) < x loop
      retval            := retval + 1;
    end loop;
    return retval;
  end function;

  constant DELTA_1_I    : integer := 1;
  constant DELTA_2_I    : integer := 5;
  constant DELTA_3_I    : integer := 25;
  constant DELTA_4_I    : integer := 75;
  constant DELTA_5_I    : integer := 125;
  constant DELTA_6_I    : integer := 195;

  constant DELTA_1      : std_logic_vector(DAC_Width-1 downto 0) :=
                           conv_std_logic_vector(DELTA_1_I, DAC_Width);
  constant DELTA_2      : std_logic_vector(DAC_Width-1 downto 0) :=
                           conv_std_logic_vector(DELTA_2_I, DAC_Width);
  constant DELTA_3      : std_logic_vector(DAC_Width-1 downto 0) :=
                           conv_std_logic_vector(DELTA_3_I, DAC_Width);
  constant DELTA_4      : std_logic_vector(DAC_Width-1 downto 0) :=
                           conv_std_logic_vector(DELTA_4_I, DAC_Width);
  constant DELTA_5      : std_logic_vector(DAC_Width-1 downto 0) :=
                           conv_std_logic_vector(DELTA_5_I, DAC_Width);
  constant DELTA_6      : std_logic_vector(DAC_Width-1 downto 0) :=
                           conv_std_logic_vector(DELTA_6_I, DAC_Width);

  constant MAX_PERIOD   : integer := 2**DAC_Width;
  constant DIV_WIDTH    : integer := DAC_Width * 2;

  constant PADJ_1_I     : integer := DELTA_1_I * MAX_PERIOD;
  constant PADJ_2_I     : integer := DELTA_2_I * MAX_PERIOD;
  constant PADJ_3_I     : integer := DELTA_3_I * MAX_PERIOD;
  constant PADJ_4_I     : integer := DELTA_4_I * MAX_PERIOD;
  constant PADJ_5_I     : integer := DELTA_5_I * MAX_PERIOD;
  constant PADJ_6_I     : integer := DELTA_6_I * MAX_PERIOD;

  constant PADJ_1       : std_logic_vector(DIV_WIDTH-1 downto 0) :=
                           conv_std_logic_vector(PADJ_1_I,DIV_WIDTH);
  constant PADJ_2       : std_logic_vector(DIV_WIDTH-1 downto 0) :=
                           conv_std_logic_vector(PADJ_2_I,DIV_WIDTH);
  constant PADJ_3       : std_logic_vector(DIV_WIDTH-1 downto 0) :=
                           conv_std_logic_vector(PADJ_3_I,DIV_WIDTH);
  constant PADJ_4       : std_logic_vector(DIV_WIDTH-1 downto 0) :=
                           conv_std_logic_vector(PADJ_4_I,DIV_WIDTH);
  constant PADJ_5       : std_logic_vector(DIV_WIDTH-1 downto 0) :=
                           conv_std_logic_vector(PADJ_5_I,DIV_WIDTH);
  constant PADJ_6       : std_logic_vector(DIV_WIDTH-1 downto 0) :=
                           conv_std_logic_vector(PADJ_6_I,DIV_WIDTH);

  signal DACin_q        : std_logic_vector(DAC_Width-1 downto 0);

  signal Divisor        : std_logic_vector(DIV_WIDTH-1 downto 0);
  signal Dividend       : std_logic_vector(DIV_WIDTH-1 downto 0);

  signal q              : std_logic_vector(DIV_WIDTH*2-1 downto 0);
  signal diff           : std_logic_vector(DIV_WIDTH downto 0);

  constant CB           : integer := ceil_log2(DIV_WIDTH);
  signal count          : std_logic_vector(CB-1 downto 0);

  signal Next_Width     : std_logic_vector(DAC_Width-1 downto 0);
  signal Next_Period    : std_logic_vector(DAC_Width-1 downto 0);

  signal PWM_Width      : std_logic_vector(DAC_Width-1 downto 0);
  signal PWM_Period     : std_logic_vector(DAC_Width-1 downto 0);

  signal Width_Ctr      : std_logic_vector(DAC_Width-1 downto 0);
  signal Period_Ctr     : std_logic_vector(DAC_Width-1 downto 0);

begin

  diff                  <= ('0' & q(DIV_WIDTH*2-2 downto DIV_WIDTH-1)) -
                           ('0' & Divisor);

  Dividend   <= PADJ_2 when DACin_q >= DELTA_2_I and DACin_q < DELTA_3_I else
                PADJ_3 when DACin_q >= DELTA_3_I and DACin_q < DELTA_4_I else
                PADJ_4 when DACin_q >= DELTA_4_I and DACin_q < DELTA_5_I else
                PADJ_5 when DACin_q >= DELTA_5_I and DACin_q < DELTA_6_I else
                PADJ_6 when DACin_q >= DELTA_6_I else
                PADJ_1;

  Next_Width <= DELTA_1 when DACin_q >= DELTA_1_I and DACin_q < DELTA_2_I else
                DELTA_2 when DACin_q >= DELTA_2_I and DACin_q < DELTA_3_I else
                DELTA_3 when DACin_q >= DELTA_3_I and DACin_q < DELTA_4_I else
                DELTA_4 when DACin_q >= DELTA_4_I and DACin_q < DELTA_5_I else
                DELTA_5 when DACin_q >= DELTA_5_I and DACin_q < DELTA_6_I else
                DELTA_6 when DACin_q >= DELTA_6_I else
                (others => '0');

  Next_Period           <= q(7 downto 0) - 1;

  vDSM_proc: process( Clock, Reset )
  begin
    if( Reset = Reset_Level )then
      q                 <= (others => '0');
      count             <= (others => '1');
      Divisor           <= (others => '0');
      DACin_q       <= (others => '0');
      PWM_Width         <= (others => '0');
      PWM_Period        <= (others => '0');
      Period_Ctr        <= (others => '0');
      Width_Ctr         <= (others => '0');
      DACout            <= '0';
    elsif( rising_edge(Clock) )then
      q                 <= diff(DIV_WIDTH-1 downto 0) &
                           q(DIV_WIDTH-2 downto 0) & '1';
      if( diff(DIV_WIDTH) = '1' )then
        q               <= q(DIV_WIDTH*2-2 downto 0) & '0';
      end if;

      count             <= count + 1;
      if( count = DIV_WIDTH )then
        PWM_Width       <= Next_Width;
        PWM_Period      <= Next_Period;
        DACin_q     <= DACin;
        Divisor         <= (others => '0');
        Divisor(DAC_Width-1 downto 0) <= DACin_q;
        q               <= conv_std_logic_vector(0,DIV_WIDTH) & Dividend;
        count           <= (others => '0');
      end if;

      Period_Ctr        <= Period_Ctr - 1;
      Width_Ctr         <= Width_Ctr - 1;

      DACout            <= '1';
      if( Width_Ctr = 0 )then
        DACout          <= '0';
        Width_Ctr       <= (others => '0');
      end if;

      if( Period_Ctr = 0 )then
        Period_Ctr      <= PWM_Period;
        Width_Ctr       <= PWM_Width;
      end if;

    end if;
  end process;

end architecture;
