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
-- VHDL Units :  o8_serlcd_tx
-- Description:  Provides a client for sending data to a SPI attached LCD
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

entity o8_serlcd_tx is
generic(
  Address                    : ADDRESS_TYPE
);
port(
  Open8_Bus                  : in  OPEN8_BUS_TYPE;
  Rd_Data                    : out DATA_TYPE;
  Interrupt                  : out std_logic;
  --
  SPI_CLK                    : out std_logic;
  SPI_SDI                    : out std_logic;
  SPI_SDO                    : in  std_logic
);
end entity;

architecture behave of o8_serlcd_tx is

  alias Clock                is Open8_Bus.Clock;
  alias Reset                is Open8_Bus.Reset;

  constant User_Addr         : std_logic_vector(15 downto 2)
                               := Address(15 downto 2);
  alias  Comp_Addr           is Open8_Bus.Address(15 downto 2);
  alias  Reg_Sel             is Open8_Bus.Address(1 downto 0);
  signal Addr_Match          : std_logic;
  signal Rd_En               : std_logic;

  signal Reg_Addr            : std_logic_vector(1 downto 0);
  signal Reg_Data            : std_logic_vector(7 downto 0);
  signal Reg_Valid           : std_logic;
  signal Tx_Ready            : std_logic;

-- Data Format
-- <START><A1><A0><D7><D6><D5><D4><D3><D2><D1><D0><NULL/ACK>

  type IO_STATES is ( INIT, IDLE, SETUP, RISING, HOLD, FALLING, IF_WAIT );
  signal io_state            : IO_STATES;

  signal tx_buffer           : std_logic_vector(11 downto 0);
  alias  ADDR                is tx_buffer(10 downto 9);
  alias  DATA                is tx_buffer(8 downto 1);

  signal bit_cnt             : std_logic_vector(3 downto 0);
  constant VEC_LEN           : integer := tx_buffer'length - 1;
  constant BITS              : std_logic_vector(3 downto 0) :=
                                conv_std_logic_vector(VEC_LEN,4);

  signal snh_tmr             : std_logic_vector(0 downto 0);

  signal SPI_SDO_q           : std_logic_vector(2 downto 0);
  alias  SPI_ACK             is SPI_SDO_q(2);

begin

  Addr_Match                 <= '1' when Comp_Addr = User_Addr else '0';

  io_reg: process( Clock, Reset )
  begin
    if( Reset = Reset_Level )then
      Reg_Addr               <= (others => '0');
      Reg_Data               <= x"00";
      Reg_Valid              <= '0';
      Rd_En                  <= '0';
      Rd_Data                <= OPEN8_NULLBUS;
    elsif( rising_edge( Clock ) )then
      Reg_Valid              <= '0';
      if( (Addr_Match and Open8_Bus.Wr_En) = '1' )then
        Reg_Addr             <= Reg_Sel;
        Reg_Data             <= Open8_Bus.Wr_Data;
        Reg_Valid            <= '1';
      end if;

      Rd_Data                <= OPEN8_NULLBUS;
      Rd_En                  <= Addr_Match and Open8_Bus.Rd_En;
      if( Rd_En = '1' )then
        Rd_Data(7)           <= Tx_Ready;
      end if;
    end if;
  end process;

  tx_buffer(VEC_LEN)         <= '1'; -- start bit
  tx_buffer(0)               <= '0'; -- stop bit

  tx_proc: process( Clock, Reset )
  begin
    if( Reset = Reset_Level )then
      io_state               <= INIT;
      ADDR                   <= (others => '0');
      DATA                   <= (others => '0');
      bit_cnt                <= (others => '0');
      snh_tmr                <= (others => '0');
      SPI_CLK                <= '0';
      SPI_SDI                <= '0';
      Tx_Ready               <= '0';
      Interrupt              <= '0';
      SPI_SDO_q              <= (others => '0');
    elsif( rising_edge(Clock) )then
      SPI_CLK                <= '0';
      SPI_SDI                <= tx_buffer(conv_integer(bit_cnt));
      SPI_SDO_q              <= SPI_SDO_q(1 downto 0) & SPI_SDO;
      Tx_Ready               <= '0';
      Interrupt              <= '0';

      case( io_state )is
        when INIT =>
          if( SPI_SDO = '1' )then
            io_state         <= IDLE;
          end if;

        when IDLE =>
          Tx_Ready           <= '1';
          bit_cnt            <= (others => '0');
          snh_tmr            <= (others => '1');
          if( Reg_Valid = '1' )then
            ADDR             <= Reg_Addr;
            DATA             <= Reg_Data;
            bit_cnt          <= BITS;
            io_state         <= FALLING;
          end if;

        when SETUP =>
          snh_tmr            <= snh_tmr - 1;
          if( snh_tmr = 0 )then
            io_state         <= RISING;
          end if;

        when RISING =>
          SPI_CLK            <= '1';
          io_state           <= HOLD;

        when HOLD =>
          SPI_CLK            <= '1';
          snh_tmr            <= snh_tmr - 1;
          if( snh_tmr = 0 )then
            bit_cnt          <= bit_cnt - or_reduce(bit_cnt);
            io_state         <= FALLING;
          end if;

        when FALLING =>
          io_state           <= SETUP;
          if( bit_cnt = 0 )then
            io_state         <= IF_WAIT;
          end if;

        when IF_WAIT =>
          if( SPI_ACK = '1' )then
            Interrupt        <= '1';
            io_state         <= IDLE;
          end if;

        when others =>
          null;

      end case;
    end if;
  end process;

end architecture;
