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
-- VHDL Units :  o8_clk_detect
-- Description:  Provides up/down status and interrupt for monitoring a clock
--
-- Register Map:
-- Offset  Bitfield Description                          Read/Write
--  0x00   BA------ Recieve Clock Status                   (RO)
--                    A = Clock Line State (follows input)
--                    B = Clock Detect (1 = transition detected)
--
-- Revision History
-- Author          Date     Change
------------------ -------- ---------------------------------------------------
-- Seth Henry      04/16/20 Revision block added

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_misc.all;

library work;
  use work.open8_pkg.all;

entity o8_clk_detect is
generic(
  Threshold_Count            : integer;
  Address                    : ADDRESS_TYPE
);
port(
  Ref_Clk_In                 : in  std_logic;
  --
  Open8_Bus                  : in  OPEN8_BUS_TYPE;
  Rd_Data                    : out DATA_TYPE;
  Interrupt                  : out std_logic
);
end entity;

architecture behave of o8_clk_detect is

  alias Clock                is Open8_Bus.Clock;
  alias Reset                is Open8_Bus.Reset;

  constant User_Addr         : std_logic_vector(15 downto 0) := Address;
  alias  Comp_Addr           is Open8_Bus.Address(15 downto 0);
  signal Addr_Match          : std_logic := '0';

  signal Rd_En               : std_logic := '0';

  constant Threshold_bits    : integer := ceil_log2(Threshold_Count);
  constant THRESHOLD         : std_logic_vector(Threshold_bits - 1 downto 0) :=
                        conv_std_logic_vector(Threshold_Count,Threshold_bits);

  signal RE_Threshold_Ctr    : std_logic_vector(Threshold_Bits - 1 downto 0) :=
                                (others => '0');
  signal FE_Threshold_Ctr    : std_logic_vector(Threshold_Bits - 1 downto 0) :=
                                (others => '0');

  signal Ref_In_SR           : std_logic_vector(3 downto 0) := (others => '0');
  alias  Ref_In_q1           is Ref_In_SR(2);
  alias  Ref_In_q2           is Ref_In_SR(3);
  signal Ref_In_RE           : std_logic := '0';
  signal Ref_In_FE           : std_logic := '0';

  signal Ref_Detect          : std_logic := '0';
  signal Ref_Detect_q1       : std_logic := '0';
  signal Ref_Detect_CoS      : std_logic := '0';

begin

  Addr_Match                 <= Open8_Bus.Rd_En when Comp_Addr = User_Addr else '0';

  io_reg: process( Clock, Reset )
  begin
    if( Reset = Reset_Level )then
      Rd_En                  <= '0';
      Rd_Data                <= OPEN8_NULLBUS;
    elsif( rising_edge( Clock ) )then
      Rd_En                  <= Addr_Match;

      Rd_Data                <= OPEN8_NULLBUS;
      if( Rd_En = '1' )then
        Rd_Data(6)           <= Ref_In_q2;
        Rd_Data(7)           <= Ref_Detect;
      end if;

    end if;
  end process;

  Detect_proc: process( Clock, Reset )
  begin
    if( Reset = Reset_Level )then
      Ref_In_SR              <= (others => '0');
      Ref_In_RE              <= '0';
      Ref_In_FE              <= '0';
      RE_Threshold_Ctr       <= (others => '0');
      FE_Threshold_Ctr       <= (others => '0');
      Ref_Detect             <= '0';
      Interrupt              <= '0';
    elsif( rising_edge(Clock) )then
      Ref_In_SR              <= Ref_In_SR(2 downto 0) & Ref_Clk_In;
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


      Ref_Detect             <= or_reduce(RE_Threshold_Ctr) and
                                or_reduce(FE_Threshold_Ctr);
      Ref_Detect_q1          <= Ref_Detect;
      Ref_Detect_CoS         <= Ref_Detect xor Ref_Detect_q1;

      Interrupt              <= Ref_Detect_CoS;
    end if;
  end process;

end architecture;