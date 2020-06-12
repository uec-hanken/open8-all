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
-- (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
-- SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--
-- VHDL Entity: o8_vector_rx
-- Description: Receives a 6-bit vector command and 16-bit argument from the
--               vector_tx entity. Issues interrupt to the CPU on receipt of
--               three bytes.
--
-- Register Map:
-- Offset  Bitfield Description                        Read/Write
--   0x0   --AAAAAA Vector Select
--   0x1   AAAAAAAA Vector Argument LB
--   0x2   AAAAAAAA Vector Argument UB
--
-- Revision History
-- Author          Date     Change
------------------ -------- ---------------------------------------------------
-- Seth Henry      04/15/20 Created from o8_epoch_timer due to requirement
--                           change.
-- Seth Henry      04/16/20 Modified to make use of Open8 bus record
-- Seth Henry      05/06/20 Modified to eliminate request line and detect idle
--                           conditions instead

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.std_logic_arith.all;
  use ieee.std_logic_misc.all;

library work;
  use work.Open8_pkg.all;

entity o8_vector_rx is
generic(
  Bit_Rate                   : real;
  Enable_Parity              : boolean;
  Parity_Odd_Even_n          : std_logic;
  Clock_Frequency            : real;
  Address                    : ADDRESS_TYPE
);
port(
  Open8_Bus                  : in  OPEN8_BUS_TYPE;
  Rd_Data                    : out DATA_TYPE;
  Interrupt                  : out std_logic;
  --
  Rx_In                      : in  std_logic
);
end entity;

architecture behave of o8_vector_rx is

  alias Clock                is Open8_Bus.Clock;
  alias Reset                is Open8_Bus.Reset;

  constant User_Addr         : std_logic_vector(15 downto 2) :=
                                Address(15 downto 2);
  alias  Comp_Addr           is Open8_Bus.Address(15 downto 2);
  signal Addr_Match          : std_logic := '0';

  alias  Reg_Addr            is Open8_Bus.Address(1 downto 0);
  signal Reg_Sel             : std_logic_vector(1 downto 0) := "00";
  signal Rd_En               : std_logic := '0';

  constant BAUD_RATE_DIV     : integer := integer(Clock_Frequency / Bit_Rate);

  -- Period of each bit in sub-clocks (subtract one to account for zero)
  constant Full_Per_i        : integer := BAUD_RATE_DIV - 1;
  constant Baud_Bits         : integer := ceil_log2(Full_Per_i);

  constant FULL_PERIOD       : std_logic_vector(Baud_Bits - 1 downto 0) :=
                                 conv_std_logic_vector(Full_Per_i, Baud_Bits);

  signal Rx_Baud_Cntr        : std_logic_vector(Baud_Bits - 1 downto 0) :=
                                 (others => '0');
  signal Rx_Baud_Tick        : std_logic;

  signal Rx_In_SR            : std_logic_vector(2 downto 0);
  alias  Rx_In_MS            is Rx_In_SR(2);
  signal Rx_Idle_Cntr        : std_logic_vector(3 downto 0);
  signal RX_Idle             : std_logic;

  type VECTOR_RX_STATES is ( GET_VECTOR_CMD, GET_VECTOR_ARG_LB, GET_VECTOR_ARG_UB,
                             SEND_INTERRUPT );
  signal Vector_State        : VECTOR_RX_STATES := GET_VECTOR_CMD;

  signal Vector_Cmd          : DATA_TYPE := x"00";
  signal Vector_Arg_LB       : DATA_TYPE := x"00";
  signal Vector_Arg_UB       : DATA_TYPE := x"00";

  signal Rx_Data             : DATA_TYPE := x"00";
  signal Rx_Valid            : std_logic;

begin

  Addr_Match                 <= '1' when Comp_Addr = User_Addr else '0';

  io_reg: process( Clock, Reset )
  begin
    if( Reset = Reset_Level )then
      Rd_En             <= '0';
      Reg_Sel           <= (others => '0');
      Rd_Data           <= OPEN8_NULLBUS;
    elsif( rising_edge( Clock ) )then
      Rd_Data           <= OPEN8_NULLBUS;
      Rd_En             <= Addr_Match and Open8_Bus.Rd_En;
      Reg_Sel           <= Reg_Addr;
      if( Rd_En = '1'  )then
        case( Reg_Sel )is
          when "00" =>
            Rd_Data     <= Vector_Cmd;
          when "01" =>
            Rd_Data     <= Vector_Arg_LB;
          when "10" =>
            Rd_Data     <= Vector_Arg_UB;
          when others =>
            null;
      end case;
      end if;
    end if;
  end process;

  RX_Idle_proc: process( Clock, Reset )
  begin
    if( Reset = Reset_Level )then
      Rx_Baud_Cntr     <= (others => '0');
      Rx_Baud_Tick     <= '0';
      Rx_In_SR         <= (others => '1');
      Rx_Idle_Cntr     <= (others => '0');
      Rx_Idle          <= '0';
    elsif( rising_edge(Clock) )then
      Rx_Baud_Cntr     <= Rx_Baud_Cntr - 1;
      Rx_Baud_Tick     <= '0';
      if( Rx_Baud_Cntr = 0 )then
        Rx_Baud_Cntr   <= FULL_PERIOD;
        Rx_Baud_Tick   <= '1';
      end if;

      Rx_In_SR         <= Rx_In_SR(1 downto 0) & Rx_In;
      Rx_Idle_Cntr     <= Rx_Idle_Cntr - Rx_Baud_Tick;
      if( Rx_In_MS = '0' )then
        Rx_Idle_Cntr   <= (others => '1');
      elsif( Rx_Idle_Cntr = 0 )then
        Rx_Idle_Cntr   <= (others => '0');
      end if;
      
      Rx_Idle          <= nor_reduce(Rx_Idle_Cntr);
    end if;
  end process;

  U_RX : entity work.async_ser_rx
  generic map(
    Reset_Level              => Reset_Level,
    Enable_Parity            => Enable_Parity,
    Parity_Odd_Even_n        => Parity_Odd_Even_n,
    Clock_Divider            => BAUD_RATE_DIV
  )
  port map(
    Clock                    => Clock,
    Reset                    => Reset,
    --
    Rx_In                    => RX_In,
    --
    Rx_Data                  => RX_Data,
    Rx_Valid                 => RX_Valid,
    Rx_PErr                  => open
  );

  Vector_RX_proc: process( Clock, Reset )
  begin
    if( Reset = Reset_Level )then
      Vector_State           <= GET_VECTOR_CMD;
      Vector_Cmd             <= x"00";
      Vector_Arg_LB          <= x"00";
      Vector_Arg_UB          <= x"00";
      Interrupt              <= '0';
    elsif( rising_edge(Clock) )then
      Interrupt              <= '0';
      case( Vector_State )is
        when GET_VECTOR_CMD =>
          if( Rx_Valid = '1' )then
            Vector_Cmd       <= Rx_Data;
            Vector_State     <= GET_VECTOR_ARG_LB;
          end if;

        when GET_VECTOR_ARG_LB =>
          if( Rx_Valid = '1' )then
            Vector_Arg_LB    <= Rx_Data;
            Vector_State     <= GET_VECTOR_ARG_UB;
          end if;

        when GET_VECTOR_ARG_UB =>
          if( Rx_Valid = '1' )then
            Vector_Arg_UB    <= Rx_Data;
            Vector_State     <= SEND_INTERRUPT;
          end if;

        when SEND_INTERRUPT =>
          Interrupt          <= '1';
          Vector_State       <= GET_VECTOR_CMD;
        when others => null;
      end case;

      if( Rx_Idle = '1' )then
        Vector_State         <= GET_VECTOR_CMD;
      end if;

    end if;
  end process;

end architecture;