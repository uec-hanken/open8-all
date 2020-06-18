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
-- VHDL units : ltc2355_2p
-- Description: Reads out a pair of LTC2355 14-bit ADCs which are wired with
--            :  common clock and CONVERT START inputs. Because they are
--            :  synchronized, this entity provides simultaneously updated
--            :  parallel data buses.
--
-- Notes      : Depends on the fact that the two LTC2355 converters are wired
--            :  with their SCLK and CONV lines tied together, and DATA1 and
--            :  DATA2 independently routed to separate I/O pins.
--
--            : Works best when the clock frequency is 96MHz or lower. Module
--            :  will divide the clock by 2 if it is greater than this.
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

entity o8_ltc2355_2p is
generic(
  Clock_Frequency            : real;
  Address                    : ADDRESS_TYPE
);
port(
  Open8_Bus                  : in  OPEN8_BUS_TYPE;
  Rd_Data                    : out DATA_TYPE;
  Interrupt                  : out std_logic;
  -- ADC IF
  ADC_SCLK                   : out std_logic;
  ADC_CONV                   : out std_logic;
  ADC_DATA1                  : in  std_logic;
  ADC_DATA2                  : in  std_logic
);
end entity;

architecture behave of o8_ltc2355_2p is

  alias Clock                is Open8_Bus.Clock;
  alias Reset                is Open8_Bus.Reset;
  alias uSec_Tick            is Open8_Bus.uSec_Tick;

  constant Divide_SCLK_by_2  : boolean := (Clock_Frequency > 96000000.0);

  constant User_Addr         : std_logic_vector(15 downto 3) := Address(15 downto 3);
  alias  Comp_Addr           is Open8_Bus.Address(15 downto 3);
  alias  Reg_Sel             is Open8_Bus.Address(2 downto 0);
  signal Reg_Sel_q           : std_logic_vector(2 downto 0);
  signal Wr_Data_q           : DATA_TYPE;
  signal Addr_Match          : std_logic;
  signal Wr_En               : std_logic;
  signal Rd_En               : std_logic;
  signal User_In             : DATA_TYPE;

  signal User_Trig           : std_logic;

  signal Timer_Int           : DATA_TYPE;
  signal Timer_Cnt           : DATA_TYPE;
  signal Timer_Trig          : std_logic;

  type ADC_STATES is ( IDLE, START, CLK_HIGH, CLK_HIGH2, CLK_LOW, CLK_LOW2, UPDATE );
  signal ad_state            : ADC_STATES;

  signal rx_buffer1          : std_logic_vector(16 downto 0);
  signal rx_buffer2          : std_logic_vector(16 downto 0);
  signal bit_cntr            : std_logic_vector(4 downto 0);
  constant BIT_COUNT         : std_logic_vector(4 downto 0) :=
                                conv_std_logic_vector(16,5);

  signal ADC1_Data           : std_logic_vector(13 downto 0);
  signal ADC2_Data           : std_logic_vector(13 downto 0);
  signal ADC_Ready           : std_logic;
begin

  Addr_Match                 <= '1' when Comp_Addr = User_Addr else '0';

  io_reg: process( Clock, Reset )
  begin
    if( Reset = Reset_Level )then
      Reg_Sel_q              <= (others => '0');
      Wr_Data_q              <= x"00";
      Wr_En                  <= '0';
      Rd_En                  <= '0';
      Rd_Data                <= OPEN8_NULLBUS;
      User_Trig              <= '0';
      Timer_Int              <= x"00";
    elsif( rising_edge( Clock ) )then
      Reg_Sel_q              <= Reg_Sel;
      Wr_Data_q              <= Open8_Bus.Wr_Data;
      Wr_En                  <= Addr_Match and Open8_Bus.Wr_En;
      User_Trig              <= '0';
      if( Wr_En = '1' )then
        if( Reg_Sel_q = "110" )then
          Timer_Int          <= Wr_Data_q;
        end if;
        if( Reg_Sel_q = "111" )then
          User_Trig          <= '1';
        end if;
      end if;

      Rd_En                  <= Addr_Match and Open8_Bus.Rd_En;
      Rd_Data                <= OPEN8_NULLBUS;

      if( Rd_En = '1' )then
        case( Reg_Sel_q )is
          -- Channel 1, Full resolution, lower byte
          when "000" =>
            Rd_Data          <= ADC1_Data(7 downto 0);
          -- Channel 1, Full resolution, upper byte
          when "001" =>
            Rd_Data          <= "00" & ADC1_Data(13 downto 8);
          -- Channel 2, Full resolution, lower byte
          when "010" =>
            Rd_Data          <= ADC2_Data(7 downto 0);
          -- Channel 2, Full resolution, upper byte
          when "011" =>
            Rd_Data          <= "00" & ADC2_Data(13 downto 8);
          -- Channel 1, 8-bit resolution
          when "100" =>
            Rd_Data          <= ADC1_Data(13 downto 6);
          -- Channel 2, 8-bit resolution
          when "101" =>
            Rd_Data          <= ADC2_Data(13 downto 6);
          -- Self-update rate
          when "110" =>
            Rd_Data          <= Timer_Int;
          -- Interface status
          when "111" =>
            Rd_Data(7)       <= ADC_Ready;
          when others =>
            null;
        end case;
      end if;
    end if;
  end process;

  Interval_proc: process( Clock, Reset )
  begin
    if( Reset = Reset_Level )then
      Timer_Cnt              <= x"00";
      Timer_Trig             <= '0';
    elsif( rising_edge(Clock) )then
      Timer_Trig             <= '0';
      Timer_Cnt              <= Timer_Cnt - uSec_Tick;
      if( or_reduce(Timer_Cnt) = '0' )then
        Timer_Cnt            <= Timer_Int;
        Timer_Trig           <= or_reduce(Timer_Int); -- Only issue output on Int > 0
      end if;
    end if;
  end process;

  ADC_IO_FSM: process( Clock, Reset )
  begin
    if( Reset = Reset_Level )then
      ad_state               <= IDLE;
      ADC_Ready              <= '0';

      rx_buffer1             <= (others => '0');
      rx_buffer2             <= (others => '0');

      bit_cntr               <= (others => '0');

      ADC1_Data              <= (others => '0');
      ADC2_Data              <= (others => '0');

      ADC_SCLK               <= '1';
      ADC_CONV               <= '0';

      Interrupt              <= '0';
    elsif( rising_edge(Clock) )then
      ADC_Ready              <= '0';
      ADC_SCLK               <= '1';
      ADC_CONV               <= '0';

      Interrupt              <= '0';

      case( ad_state )is
        when IDLE =>
          ADC_Ready          <= '1';
          if( (User_Trig or Timer_Trig) = '1' )then
            ad_state         <= START;
          end if;

        when START =>
          ADC_SCLK           <= '0';
          ADC_CONV           <= '1';
          bit_cntr           <= BIT_COUNT;
          ad_state           <= CLK_HIGH;

        when CLK_HIGH =>
          ad_state           <= CLK_LOW;
          if( Divide_SCLK_by_2 )then
            ad_state         <= CLK_HIGH2;
          end if;

        when CLK_HIGH2 =>
          ad_state           <= CLK_LOW;

        when CLK_LOW =>
          ADC_SCLK           <= '0';
          rx_buffer1(conv_integer(bit_cntr)) <= ADC_DATA1;
          rx_buffer2(conv_integer(bit_cntr)) <= ADC_DATA2;
          bit_cntr           <= bit_cntr - 1;
          ad_state           <= CLK_HIGH;
          if( bit_cntr = 0 )then
            ad_state         <= UPDATE;
          elsif( Divide_SCLK_by_2 )then
            ad_state         <= CLK_LOW2;
          end if;

        when CLK_LOW2 =>
          ADC_SCLK           <= '0';
          ad_state           <= CLK_HIGH;

        when UPDATE =>
          ADC_SCLK           <= '0';
          ad_state           <= IDLE;
          ADC1_Data          <= rx_buffer1(14 downto 1);
          ADC2_Data          <= rx_buffer2(14 downto 1);
          Interrupt          <= '1';

        when others =>
          null;
      end case;

    end if;
  end process;

end architecture;
