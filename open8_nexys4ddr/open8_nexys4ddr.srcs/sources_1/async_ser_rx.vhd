-- Copyright (c)2006, 2016, 2019 Jeremy Seth Henry
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
-- VHDL Units :  async_ser_rx
-- Description:  Asynchronous receiver wired for 8[N/E/O]1 data. Parity mode
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

entity async_ser_rx is
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
  Rx_In                      : in  std_logic;
  --
  Rx_Data                    : out std_logic_vector(7 downto 0);
  Rx_Valid                   : out std_logic;
  Rx_PErr                    : out std_logic
);
end entity;

architecture behave of async_ser_rx is

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

  -- Period of each bit in sub-clocks (subtract one to account for zero)
  constant Half_Per_i        : integer := (Clock_Divider / 2) - 1;
  constant Full_Per_i        : integer := Clock_Divider - 1;
  constant Baud_Bits         : integer := ceil_log2(Full_Per_i);

  constant HALF_PERIOD       : std_logic_vector(Baud_Bits - 1 downto 0) :=
                                 conv_std_logic_vector(Half_Per_i, Baud_Bits);
  constant FULL_PERIOD       : std_logic_vector(Baud_Bits - 1 downto 0) :=
                                 conv_std_logic_vector(Full_Per_i, Baud_Bits);

  signal Rx_Baud_Cntr        : std_logic_vector(Baud_Bits - 1 downto 0) :=
                                 (others => '0');

  signal Rx_In_SR            : std_logic_vector(3 downto 0) := x"0";
  alias  Rx_In_Q             is Rx_In_SR(3);

  signal Rx_Buffer           : std_logic_vector(7 downto 0) := x"00";
  signal Rx_Parity           : std_logic := '0';
  signal Rx_PErr_int         : std_logic := '0';

  signal Rx_State            : std_logic_vector(3 downto 0) := x"0";
  alias  Rx_Bit_Sel          is Rx_State(2 downto 0);

  -- State machine definitions
  constant IO_RSV0           : std_logic_vector(3 downto 0) := "1011"; -- B
  constant IO_RSV1           : std_logic_vector(3 downto 0) := "1100"; -- C
  constant IO_STRT           : std_logic_vector(3 downto 0) := "1101"; -- D
  constant IO_IDLE           : std_logic_vector(3 downto 0) := "1110"; -- E
  constant IO_SYNC           : std_logic_vector(3 downto 0) := "1111"; -- F
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

  Rx_Perr                    <= Rx_PErr_int;

  UART_Regs: process( Clock, Reset )
  begin
    if( Reset = Reset_Level )then
      Rx_In_SR               <= (others => '0');
      Rx_State               <= IO_IDLE;
      Rx_Baud_Cntr           <= (others => '0');
      Rx_Buffer              <= (others => '0');
      Rx_Parity              <= '0';
      Rx_Data                <= (others => '0');
      Rx_Valid               <= '0';
      Rx_PErr_int            <= '0';
    elsif( rising_edge(Clock) )then
      Rx_In_SR               <= Rx_In_SR(2 downto 0) & Rx_In;

      Rx_Valid               <= '0';
      case( Rx_State )is
        when IO_STRT =>
          if( Rx_In_Q = '1' )then
            Rx_State         <= Rx_State + 1;
          end if;

        when IO_IDLE =>
          Rx_Baud_Cntr       <= HALF_PERIOD;
          Rx_Parity          <= Parity_Odd_Even_n;
          if( Rx_In_Q = '0' )then
            Rx_State         <= Rx_State + 1;
          end if;

        when IO_SYNC =>
          Rx_Baud_Cntr       <= Rx_Baud_Cntr - 1;
          if( Rx_Baud_Cntr = 0)then
            Rx_Baud_Cntr     <= FULL_PERIOD;
            Rx_State         <= Rx_State + 1;
            if( Rx_In_Q = '1' )then -- RxD going low was spurious
              Rx_State       <= IO_IDLE;
            end if;
          end if;

        when IO_BIT0 | IO_BIT1 | IO_BIT2 | IO_BIT3 |
             IO_BIT4 | IO_BIT5 | IO_BIT6 | IO_BIT7 =>
          Rx_Baud_Cntr       <= Rx_Baud_Cntr - 1;
          if( Rx_Baud_Cntr = 0 )then
            Rx_Baud_Cntr     <= FULL_PERIOD;
            Rx_Buffer(conv_integer(Rx_Bit_Sel)) <= Rx_In_Q;
            if( Enable_Parity )then
              Rx_Parity      <= Rx_Parity xor Rx_In_Q;
              Rx_State       <= Rx_State + 1;
            else
              Rx_PErr_int    <= '0';
              Rx_State       <= Rx_State + 2;
            end if;
          end if;

        when IO_PARI =>
          Rx_Baud_Cntr       <= Rx_Baud_Cntr - 1;
          if( Rx_Baud_Cntr = 0 )then
            Rx_Baud_Cntr     <= FULL_PERIOD;
            Rx_PErr_int      <= Rx_Parity xor Rx_In_Q;
            Rx_State         <= Rx_State + 1;
          end if;

        when IO_STOP =>
          Rx_Baud_Cntr       <= Rx_Baud_Cntr - 1;
          if( Rx_Baud_Cntr = 0 )then
            Rx_State         <= Rx_State + 1;
          end if;

        when IO_DONE =>
          Rx_Data            <= Rx_Buffer;
          Rx_Valid           <= not Rx_PErr_int;
          Rx_State           <= Rx_State + 1;

        when others =>
          Rx_State           <= IO_IDLE;

      end case;

    end if;
  end process;

end architecture;