-- Copyright (c)2006, 2016, 2020 Jeremy Seth Henry
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
-- VHDL Units :  async_ser_tx
-- Description:  Asynchronous transmitter wired for 8[N/E/O]1 data. Parity mode
--                and bit rate are set with generics.
--
-- Note: The baud rate generator will produce an approximate frequency. The
--        final bit rate should be within +/- 1% of the true bit rate to
--        ensure the receiver can successfully receive. With a sufficiently
--        high core clock, this is generally achievable for common PC serial
--        data rates.
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

entity async_ser_tx is
generic(
  Reset_Level                : std_logic;
  Enable_Parity              : boolean;
  Parity_Odd_Even_n          : std_logic;
  Clock_Divider              : integer
);
port(
  Clock                      : in  std_logic;
  Reset                      : in  std_logic;
  --
  Tx_Data                    : in  std_logic_vector(7 downto 0);
  Tx_Valid                   : in  std_logic;
  --
  Tx_Out                     : out std_logic;
  Tx_Done                    : out std_logic
);
end entity;

architecture behave of async_ser_tx is

  -- The ceil_log2 function returns the minimum register width required to
  --  hold the supplied integer.
  function ceil_log2 (x : in natural) return natural is
    variable retval          : natural;
  begin
    retval                   := 1;
    while ((2**retval) - 1) < x loop
      retval                 := retval + 1;
    end loop;
    return retval;
  end ceil_log2;

  constant Tick_Base         : integer := Clock_Divider - 1;
  constant Tick_Bits         : integer := ceil_log2(Tick_Base);
  constant TICK_DIV          : std_logic_vector(Tick_Bits - 1 downto 0) :=
                                 conv_std_logic_vector(Tick_Base, Tick_Bits);

  signal Tick_Cntr           : std_logic_vector(Tick_Bits - 1 downto 0) :=
                                 (others => '0');

  signal Tick_Trig           : std_logic := '0';
  signal Tx_Enable           : std_logic := '0';
  signal Tx_Buffer           : std_logic_vector(7 downto 0) := x"00";
  signal Tx_Parity           : std_logic := '0';
  signal Tx_State            : std_logic_vector(3 downto 0) := x"0";
  alias  Tx_Bit_Sel          is Tx_State(2 downto 0);

  -- State machine definitions
  constant IO_RSV0           : std_logic_vector(3 downto 0) := "1011"; -- B
  constant IO_RSV1           : std_logic_vector(3 downto 0) := "1100"; -- C
  constant IO_RSV2           : std_logic_vector(3 downto 0) := "1101"; -- D
  constant IO_IDLE           : std_logic_vector(3 downto 0) := "1110"; -- E
  constant IO_STRT           : std_logic_vector(3 downto 0) := "1111"; -- F
  constant IO_BIT0           : std_logic_vector(3 downto 0) := "0000"; -- 0
  constant IO_BIT1           : std_logic_vector(3 downto 0) := "0001"; -- 1
  constant IO_BIT2           : std_logic_vector(3 downto 0) := "0010"; -- 2
  constant IO_BIT3           : std_logic_vector(3 downto 0) := "0011"; -- 3
  constant IO_BIT4           : std_logic_vector(3 downto 0) := "0100"; -- 4
  constant IO_BIT5           : std_logic_vector(3 downto 0) := "0101"; -- 5
  constant IO_BIT6           : std_logic_vector(3 downto 0) := "0110"; -- 6
  constant IO_BIT7           : std_logic_vector(3 downto 0) := "0111"; -- 7
  constant IO_PARI           : std_logic_vector(3 downto 0) := "1000"; -- 8
  constant IO_STOP           : std_logic_vector(3 downto 0) := "1001"; -- 9
  constant IO_DONE           : std_logic_vector(3 downto 0) := "1010"; -- A

begin

  UART_Regs: process( Clock, Reset )
  begin
    if( Reset = Reset_Level )then
      Tick_Cntr              <= (others => '0');
      Tick_Trig              <= '0';
      Tx_State               <= IO_IDLE;
      Tx_Enable              <= '0';
      Tx_Buffer              <= (others => '0');
      if( Enable_Parity )then
        Tx_Parity            <= '0';
      end if;
      Tx_Out                 <= '1';
      Tx_Done                <= '0';
    elsif( rising_edge(Clock) )then
      Tick_Cntr              <= (others => '0');
      Tick_Trig              <= '0';

      if( Tx_Enable = '1' )then
        Tick_Cntr            <= Tick_Cntr - 1;
        Tick_Trig            <= '0';
        if( or_reduce(Tick_Cntr) = '0' )then
          Tick_Cntr          <= TICK_DIV;
          Tick_Trig          <= '1';
        end if;
      end if;

      if( Tx_Valid = '1' )then
        Tx_Buffer            <= Tx_Data;
        Tx_Enable            <= '1';
      end if;

      Tx_State               <= Tx_State + Tick_Trig;
      Tx_Done                <= '0';
      Tx_Out                 <= '1';

      case( Tx_State )is
        when IO_IDLE =>
          if( Enable_Parity )then
            Tx_Parity        <= Parity_Odd_Even_n;
          end if;

        when IO_STRT =>
          Tx_Out             <= '0';

        when IO_BIT0 | IO_BIT1 | IO_BIT2 | IO_BIT3 |
             IO_BIT4 | IO_BIT5 | IO_BIT6 | IO_BIT7 =>
          Tx_Out             <= Tx_Buffer(conv_integer(Tx_Bit_Sel));
          if( Tick_Trig = '1' and Enable_Parity )then
            Tx_Parity        <= Tx_Parity xor Tx_Buffer(conv_integer(Tx_Bit_Sel));
          end if;

        when IO_PARI =>
          if( Enable_Parity )then
            Tx_Out           <= Tx_Parity;
          end if;

        when IO_STOP =>

        when IO_DONE =>
          Tx_Done            <= '1';
          Tx_Enable          <= '0';
          Tx_State           <= IO_IDLE;

        when others =>

      end case;

      if( Tx_Enable = '0' )then
        Tx_State             <= IO_IDLE;
      end if;

    end if;
  end process;

end architecture;