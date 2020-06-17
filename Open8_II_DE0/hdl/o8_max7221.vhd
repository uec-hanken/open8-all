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
-- VHDL Units :  o8_max7221
-- Description:  Provides a memory mapped SPI interface to the max7221 LED
--                controller/driver.
--
-- Revision History
-- Author          Date     Change
------------------ -------- ---------------------------------------------------
-- Seth Henry      01/22/20 Design Start
-- Seth Henry      04/16/20 Modified to use Open8 bus record

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_misc.all;

library work;
  use work.open8_pkg.all;

entity o8_max7221 is
generic(
  Bitclock_Frequency         : real := 5000000.0;
  Clock_Frequency            : real;
  Address                    : ADDRESS_TYPE
);
port(
  Open8_Bus                  : in  OPEN8_BUS_TYPE;
  --
  Mx_Data                    : out std_logic;
  Mx_Clock                   : out std_logic;
  MX_LDCSn                   : out std_logic
);
end entity;

architecture behave of o8_max7221 is

  alias Clock                is Open8_Bus.Clock;
  alias Reset                is Open8_Bus.Reset;

  signal FIFO_Reset          : std_logic;

  constant User_Addr         : std_logic_vector(15 downto 4) :=
                                 Address(15 downto 4);
  alias  Comp_Addr           is Open8_Bus.Address(15 downto 4);

  signal FIFO_Wr_En          : std_logic;
  signal FIFO_Wr_Data        : std_logic_vector(11 downto 0);

  signal FIFO_Rd_En          : std_logic;
  signal FIFO_Empty          : std_logic;
  signal FIFO_Rd_Data        : std_logic_vector(11 downto 0);

  type TX_CTRL_STATES is (IDLE, TX_BYTE, TX_START, TX_WAIT );
  signal TX_Ctrl             : TX_CTRL_STATES;

  signal TX_En               : std_logic;
  signal TX_Idle             : std_logic;

  constant BAUD_DLY_RATIO    : real := (Clock_Frequency / Bitclock_Frequency);
  constant BAUD_DLY_VAL      : integer := integer(BAUD_DLY_RATIO * 0.5);
  constant BAUD_DLY_WDT      : integer := ceil_log2(BAUD_DLY_VAL - 1);
  constant BAUD_DLY          : std_logic_vector :=
                         conv_std_logic_vector(BAUD_DLY_VAL - 1, BAUD_DLY_WDT);

  signal Baud_Cntr           : std_logic_vector( BAUD_DLY_WDT - 1 downto 0 )
                               := (others => '0');
  signal Baud_Tick           : std_logic;

  type IO_STATES is ( IDLE, SYNC_CLK, SCLK_L, SCLK_H, ADV_BIT, DONE );
  signal io_state            : IO_STATES;
  signal bit_cntr            : std_logic_vector(3 downto 0);
  signal tx_buffer           : std_logic_vector(15 downto 0);

begin

  FIFO_Wr_En                 <= Open8_Bus.Wr_En when Comp_Addr = User_Addr else
                                '0';

  FIFO_Wr_Data               <= Open8_Bus.Address(3 downto 0) &
                                Open8_Bus.Wr_Data;

  FIFO_Reset                 <= Reset when Reset_Level = '1' else (not Reset);

  U_FIFO : entity work.o8_max7221_fifo
  port map(
    aclr                     => FIFO_Reset,
    clock                    => Clock,
    data                     => FIFO_Wr_Data,
    rdreq                    => FIFO_Rd_En,
    wrreq                    => FIFO_Wr_En,
    empty                    => FIFO_Empty,
    q                        => FIFO_Rd_Data
  );

  tx_FSM: process( Clock, Reset )
  begin
    if( Reset = Reset_Level )then
      TX_Ctrl                <= IDLE;
      TX_En                  <= '0';
      FIFO_Rd_En             <= '0';
    elsif( rising_edge(Clock) )then
      TX_En                  <= '0';
      FIFO_Rd_En             <= '0';

      case( TX_Ctrl )is
        when IDLE =>
          if( FIFO_Empty = '0' )then
            FIFO_Rd_En       <= '1';
            TX_Ctrl          <= TX_BYTE;
          end if;

        when TX_BYTE =>
          TX_En              <= '1';
          TX_Ctrl            <= TX_START;

        when TX_START =>
          if( TX_Idle = '0' )then
            TX_Ctrl          <= TX_WAIT;
          end if;

        when TX_WAIT =>
          if( TX_Idle = '1' )then
            TX_Ctrl          <= IDLE;
          end if;

        when others => null;
      end case;

    end if;
  end process;

  Baud_Rate_proc: process( Clock, Reset )
  begin
    if( Reset = Reset_Level )then
      Baud_Cntr              <= (others => '0');
      Baud_Tick              <= '0';
    elsif( rising_edge( Clock ) )then
      Baud_Cntr              <= Baud_Cntr - 1;
      Baud_Tick              <= nor_reduce(Baud_Cntr);
      if( Baud_Cntr = 0 )then
        Baud_Cntr            <= BAUD_DLY;
      end if;
    end if;
  end process;

  io_FSM: process( Clock, Reset )
  begin
    if( Reset = Reset_Level )then
      io_state               <= IDLE;
      bit_cntr               <= (others => '0');
      tx_buffer              <= (others => '0');
      TX_Idle                <= '0';

      Mx_Clock               <= '0';
      Mx_Data                <= '0';
      MX_LDCSn               <= '0';

    elsif( rising_edge(Clock) )then

      TX_Idle                <= '0';
      Mx_Clock               <= '0';

      case( io_state )is
        when IDLE =>
          Mx_Data            <= '0';
          MX_LDCSn           <= '1';
          TX_Idle            <= '1';
          if( TX_En = '1' )then
            tx_buffer        <= "0000" & FIFO_Rd_Data;
            bit_cntr         <= (others => '1');
            io_state         <= SYNC_CLK;
          end if;

        when SYNC_CLK =>
          if( Baud_Tick = '1' )then
            io_state         <= SCLK_L;
          end if;

        when SCLK_L =>
          MX_LDCSn           <= '0';
          Mx_Data            <= tx_buffer(conv_integer(bit_cntr));
          if( Baud_Tick = '1' )then
            io_state         <= SCLK_H;
          end if;

        when SCLK_H =>
          Mx_Clock           <= '1';
          if( Baud_Tick = '1' )then
            bit_cntr         <= bit_cntr - 1;
            io_state         <= ADV_BIT;
          end if;

        when ADV_BIT =>
          io_state           <= SCLK_L;
          if( and_reduce(bit_cntr) = '1' )then
            io_state         <= DONE;
          end if;

        when DONE =>
          Mx_Data            <= '0';
          if( Baud_Tick = '1' )then
            io_state         <= IDLE;
          end if;

        when others => null;
      end case;
    end if;
  end process;

end architecture;