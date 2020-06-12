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
-- VHDL Units :  sdlc_serial_clk
-- Description:
--  Implements the serial clock output as well as rising/falling edge pulses
--  for use by the serial transmitter and receiver. Accepts the synchronous
--  serial bit rate as a real (BitClock_Freq). Note that the clock is free-
--  running rather than gated.
--
-- Revision History
-- Author          Date     Change
------------------ -------- ---------------------------------------------------
-- Seth Henry      04/14/20 Code cleanup and revision section added

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.std_logic_arith.all;
  use ieee.std_logic_misc.all;

library work;
  use work.sdlc_serial_pkg.all;

entity sdlc_serial_clk is
generic(
  Set_As_Master              : boolean := true;
  BitClock_Freq              : real := 500000.0;
  Reset_Level                : std_logic;
  Sys_Freq                   : real := 50000000.0
);
port(
  Clock                      : in  std_logic;
  Reset                      : in  std_logic;
  BClk_In                    : in  std_logic := '0';
  BClk_Out                   : out std_logic;
  BClk_FE                    : out std_logic;
  BClk_RE                    : out std_logic;
  BClk_Okay                  : out std_logic
);
end entity;

architecture behave of sdlc_serial_clk is

  constant DLY_VAL           : integer := integer(Sys_Freq / (2.0 * BitClock_Freq) );
  constant DLY_WDT           : integer := ceil_log2(DLY_VAL - 1);
  constant DLY_VEC           : std_logic_vector :=
                               conv_std_logic_vector( DLY_VAL - 1, DLY_WDT);
  signal BClk_Cntr           : std_logic_vector( DLY_WDT - 1 downto 0 ) := (others => '0');

  signal BClk_Adv            : std_logic := '0';
  signal BClk_Accum          : std_logic_vector(31 downto 0) := (others => '0');
  signal BClk_Div            : std_logic := '0';
  signal BClk_Okay_SR        : std_logic_vector(3 downto 0)  := (others => '0');


  signal BClk_SR             : std_logic_vector(2 downto 0)  := (others => '0');

  constant CLK_RATIO_R       : real := Sys_Freq / (1.0 * BitClock_Freq);
  constant CLK_DEVIATION_5P  : real := CLK_RATIO_R * 0.05;
  constant CLK_RATIO_ADJ_R   : real := CLK_RATIO_R + CLK_DEVIATION_5P;
  constant CLK_RATIO_ADJ_I   : integer := integer(CLK_RATIO_ADJ_R);

  constant Threshold_bits    : integer := ceil_log2(CLK_RATIO_ADJ_I);
  constant THRESHOLD         : std_logic_vector(Threshold_bits - 1 downto 0) :=
                        conv_std_logic_vector(CLK_RATIO_ADJ_I,Threshold_bits);

  signal RE_Threshold_Ctr    : std_logic_vector(Threshold_Bits - 1 downto 0) :=
                                (others => '0');
  signal FE_Threshold_Ctr    : std_logic_vector(Threshold_Bits - 1 downto 0) :=
                                (others => '0');

  signal Ref_In_SR           : std_logic_vector(2 downto 0) := (others => '0');
  alias  Ref_In_q1           is Ref_In_SR(1);
  alias  Ref_In_q2           is Ref_In_SR(2);
  signal Ref_In_RE           : std_logic := '0';
  signal Ref_In_FE           : std_logic := '0';

begin

Clock_Master: if( Set_As_Master )generate

  SDLC_Clk_Gen_proc: process( Clock, Reset )
  begin
    if( Reset = Reset_Level )then
      BClk_Cntr              <= DLY_VEC;
      BClk_Adv               <= '0';
      BClk_Accum             <= (others => '0');
      BClk_Div               <= '0';
      BClk_Okay_SR           <= (others => '0');
      BClk_Out               <= '0';
      BClk_RE                <= '0';
      BClk_FE                <= '0';
    elsif( rising_edge( Clock ) )then
      BClk_Cntr              <= BClk_Cntr - 1;
      BClk_Adv               <= '0';
      if( or_reduce(BClk_Cntr) = '0' )then
        BClk_Cntr            <= DLY_VEC;
        BClk_Adv             <= '1';
        BClk_Okay_SR         <= BClk_Okay_SR(2 downto 0) & '1';
      end if;
      BClk_Accum             <= BClk_Accum + BClk_Adv;
      BClk_Div               <= BClk_Div xor BClk_Adv;
      BClk_Out               <= BClk_Div;
      BClk_RE                <= (not BClk_Div) and BClk_Adv;
      BClk_FE                <= BClk_Div and BClk_Adv;
    end if;
  end process;

  BClk_Okay                  <= BClk_Okay_SR(3);

end generate;

Clock_Slave: if( not Set_As_Master )generate

  SDLC_Clock_Edge_proc: process( Clock, Reset )
  begin
    if( Reset = Reset_Level )then
      BClk_SR                <= (others => '0');
      BClk_FE                <= '0';
      BClk_RE                <= '0';
    elsif( rising_edge(Clock) )then
      BClk_SR                <= BClk_SR(1 downto 0) & BClk_In;
      BClk_FE                <= BClk_SR(2) and (not BClk_SR(1));
      BClk_RE                <= (not BClk_SR(2)) and BClk_SR(1);
    end if;
  end process;

  BClk_Out                   <= '0';

  Detect_proc: process( Clock, Reset )
  begin
    if( Reset = Reset_Level )then
      Ref_In_SR              <= (others => '0');
      Ref_In_RE              <= '0';
      Ref_In_FE              <= '0';
      RE_Threshold_Ctr       <= (others => '0');
      FE_Threshold_Ctr       <= (others => '0');
      BClk_Okay              <= '0';

    elsif( rising_edge(Clock) )then
      Ref_In_SR              <= Ref_In_SR(1 downto 0) & BClk_In;
      Ref_In_RE              <= Ref_In_q1 and (not Ref_In_q2);
      Ref_In_FE              <= (not Ref_In_q1) and Ref_In_q2;

      RE_Threshold_Ctr       <= RE_Threshold_Ctr - 1;
      if( Ref_In_RE = '1' )then
        RE_Threshold_Ctr     <= THRESHOLD;
      elsif( or_reduce(RE_Threshold_Ctr) = '0' )then
        RE_Threshold_Ctr     <= (others => '0');
      end if;

      FE_Threshold_Ctr       <= FE_Threshold_Ctr - 1;
      if( Ref_In_FE = '1' )then
        FE_Threshold_Ctr     <= THRESHOLD;
      elsif( or_reduce(FE_Threshold_Ctr) = '0' )then
        FE_Threshold_Ctr     <= (others => '0');
      end if;


      BClk_Okay              <= or_reduce(RE_Threshold_Ctr) and
                                or_reduce(FE_Threshold_Ctr);

    end if;
  end process;

end generate;

end architecture;