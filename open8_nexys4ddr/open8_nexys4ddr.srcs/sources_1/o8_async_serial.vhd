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
-- VHDL Units :  o8_async_serial
-- Description:  Provides a single 8-bit, asynchronous transceiver. While the
--               width is fixed at 8-bits, the bit rate and parity controls
--               are settable via generics.
--
-- Register Map:
-- Offset  Bitfield Description                        Read/Write
--   0x00  AAAAAAAA TX Data (WR) RX Data (RD)             (RW)
--   0x01  EDCBA--- FIFO Status                           (RO*)
--                  A: RX Parity Error (write to clear)
--                  B: RX FIFO Empty
--                  C: RX FIFO almost full (922/1024)
--                  D: TX FIFO Empty
--                  E: TX FIFO almost full (922/1024)
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
-- Seth Henry      12/20/19 Design Start
-- Seth Henry      04/10/20 Code cleanup and register documentation
-- Seth Henry      04/16/20 Modified to use Open8 bus record
-- Seth Henry      05/18/20 Added write qualification input

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_misc.all;

library work;
  use work.open8_pkg.all;

entity o8_async_serial is
generic(
  Disable_Transmit           : boolean := FALSE;
  Disable_Receive            : boolean := FALSE;
  Bit_Rate                   : real;
  Enable_Parity              : boolean;
  Parity_Odd_Even_n          : std_logic;
  Clock_Frequency            : real;
  Address                    : ADDRESS_TYPE
);
port(
  Open8_Bus                  : in  OPEN8_BUS_TYPE;
  Write_Qual                 : in  std_logic := '1';
  Rd_Data                    : out DATA_TYPE;
  --
  TX_Out                     : out std_logic;
  CTS_In                     : in  std_logic := '1';
  RX_In                      : in  std_logic := '1';
  RTS_Out                    : out std_logic
);
end entity;

architecture behave of o8_async_serial is

  alias Clock                is Open8_Bus.Clock;
  alias Reset                is Open8_Bus.Reset;
  alias uSec_Tick            is Open8_Bus.uSec_Tick;
  alias Wr_En                is Open8_Bus.Wr_En;
  alias Wr_Data              is Open8_Bus.Wr_Data;
  alias Rd_En                is Open8_Bus.Rd_En;

  signal FIFO_Reset          : std_logic := '0';

  constant User_Addr         : std_logic_vector(15 downto 1) :=
                                Address(15 downto 1);
  alias  Comp_Addr           is Open8_Bus.Address(15 downto 1);
  signal Addr_Match          : std_logic := '0';

  alias  Reg_Sel_d           is Open8_Bus.Address(0);
  signal Reg_Sel_q           : std_logic := '0';
  signal Wr_En_d             : std_logic := '0';
  signal Wr_En_q             : std_logic := '0';
  alias  Wr_Data_d           is Open8_Bus.Wr_Data;
  signal Wr_Data_q           : DATA_TYPE := x"00";
  signal Rd_En_d             : std_logic := '0';
  signal Rd_En_q             : std_logic := '0';

  signal TX_FIFO_Wr_En       : std_logic := '0';
  signal TX_FIFO_Wr_Data     : DATA_TYPE := x"00";
  signal TX_FIFO_Rd_En       : std_logic := '0';
  signal TX_FIFO_Empty       : std_logic := '0';
  signal TX_FIFO_AFull       : std_logic := '0';
  signal TX_FIFO_Rd_Data     : DATA_TYPE := x"00";

  alias  Tx_Data             is TX_FIFO_Rd_Data;

  type TX_CTRL_STATES is (IDLE, TX_BYTE, TX_START, TX_WAIT );
  signal TX_Ctrl             : TX_CTRL_STATES := IDLE;

  signal TX_Xmit             : std_logic := '0';
  signal TX_Done             : std_logic := '0';

  constant BAUD_RATE_DIV     : integer := integer(Clock_Frequency / Bit_Rate);

  signal CTS_sr              : std_logic_vector(3 downto 0) := "0000";
  alias  CTS_Okay            is CTS_sr(3);

  signal RX_FIFO_Wr_En       : std_logic := '0';
  signal RX_FIFO_Wr_Data     : DATA_TYPE := x"00";
  signal RX_FIFO_Rd_En       : std_logic := '0';
  signal RX_FIFO_Empty       : std_logic := '0';
  signal RX_FIFO_AFull       : std_logic := '0';
  signal RX_FIFO_Rd_Data     : DATA_TYPE := x"00";

  signal Rx_PErr             : std_logic := '0';
  signal RX_Parity_Err       : std_logic := '0';

begin

  Addr_Match                 <= '1' when Comp_Addr = User_Addr else '0';
  Wr_En_d                    <= Addr_Match and Open8_Bus.Wr_En;
  Rd_En_d                    <= Addr_Match and Open8_Bus.Rd_En;

  io_reg: process( Clock, Reset )
  begin
    if( Reset = Reset_Level )then
      Reg_Sel_q              <= '0';
      Wr_En_q                <= '0';
      Wr_Data_q              <= x"00";
      Rd_En_q                <= '0';
      Rd_Data                <= OPEN8_NULLBUS;
      RTS_Out                <= '0';
      RX_Parity_Err          <= '0';
    elsif( rising_edge( Clock ) )then
      Reg_Sel_q              <= Reg_Sel_d;

      Wr_En_q                <= Wr_En_d;
      Wr_Data_q              <= Wr_Data_d;

      TX_FIFO_Wr_En          <= Wr_En_q and not Reg_Sel_q;
      TX_FIFO_Wr_Data        <= Wr_Data_q;

      if( Rx_PErr = '1' )then
        RX_Parity_Err        <= '1';
      elsif( Wr_En_q = '1' and Reg_Sel_q = '1' and Write_Qual = '1' )then
        RX_Parity_Err        <= '0';
      end if;

      Rd_En_q                <= Rd_En_d;
      Rd_Data                <= OPEN8_NULLBUS;
      if( Rd_En_q = '1' and Reg_Sel_q = '1' )then
		  Rd_Data(3)           <= RX_Parity_Err;
        Rd_Data(4)           <= RX_FIFO_Empty;
        Rd_Data(5)           <= RX_FIFO_AFull;
        Rd_Data(6)           <= TX_FIFO_Empty;
        Rd_Data(7)           <= TX_FIFO_AFull;
      end if;
      if( Rd_En_q = '1' and Reg_Sel_q = '0' )then
        Rd_Data              <= RX_FIFO_Rd_Data;
      end if;
      RTS_Out                <= not RX_FIFO_AFull;

    end if;
  end process;

TX_Disabled : if( Disable_Transmit )generate

  TX_FIFO_Empty              <= '1';
  TX_FIFO_AFull              <= '0';
  TX_Out                     <= '1';

end generate;

TX_Enabled : if( not Disable_Transmit )generate

  FIFO_Reset                 <= '1' when Reset = Reset_Level else '0';

  U_TX_FIFO : entity work.fifo_1k_core
  port map(
    aclr                     => FIFO_Reset,
    clock                    => Clock,
    data                     => TX_FIFO_Wr_Data,
    rdreq                    => TX_FIFO_Rd_En,
    wrreq                    => TX_FIFO_Wr_En,
    empty                    => TX_FIFO_Empty,
    almost_full              => TX_FIFO_AFull,
    q                        => TX_FIFO_Rd_Data
  );

  tx_FSM: process( Clock, Reset )
  begin
    if( Reset = Reset_Level )then
      TX_Ctrl                <= IDLE;
      TX_Xmit                <= '0';
      TX_FIFO_Rd_En          <= '0';
      CTS_sr                 <= (others => '0');
    elsif( rising_edge(Clock) )then
      TX_Xmit                <= '0';
      TX_FIFO_Rd_En          <= '0';
      CTS_sr                 <= CTS_sr(2 downto 0) & CTS_In;

      case( TX_Ctrl )is
        when IDLE =>
          if( TX_FIFO_Empty = '0' and CTS_Okay = '1' )then
            TX_FIFO_Rd_En    <= '1';
            TX_Ctrl          <= TX_BYTE;
          end if;

        when TX_BYTE =>
          TX_Xmit            <= '1';
          TX_Ctrl            <= TX_START;

        when TX_START =>
          if( Tx_Done = '0' )then
            TX_Ctrl          <= TX_WAIT;
          end if;

        when TX_WAIT =>
          if( Tx_Done = '1' )then
            TX_Ctrl          <= IDLE;
          end if;

        when others => null;
      end case;

    end if;
  end process;

  U_TX : entity work.async_ser_tx
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
    Tx_Data                  => Tx_Data,
    Tx_Valid                 => TX_Xmit,
    --
    Tx_Out                   => TX_Out,
    Tx_Done                  => Tx_Done
  );

end generate;

RX_Disabled : if( Disable_Receive )generate

  Rx_PErr                    <= '0';
  RX_FIFO_Empty              <= '1';
  RX_FIFO_AFull              <= '0';
  RX_FIFO_Rd_Data            <= x"00";

end generate;

RX_Enabled : if( not Disable_Receive )generate

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
    Rx_Data                  => RX_FIFO_Wr_Data,
    Rx_Valid                 => RX_FIFO_Wr_En,
    Rx_PErr                  => Rx_PErr
  );

  RX_FIFO_Rd_En              <= Open8_Bus.Rd_En and
                                Addr_Match and
                                (not Reg_Sel_d);

  U_RX_FIFO : entity work.fifo_1k_core
  port map(
    aclr                     => FIFO_Reset,
    clock                    => Clock,
    data                     => RX_FIFO_Wr_Data,
    rdreq                    => RX_FIFO_Rd_En,
    wrreq                    => RX_FIFO_Wr_En,
    empty                    => RX_FIFO_Empty,
    almost_full              => RX_FIFO_AFull,
    q                        => RX_FIFO_Rd_Data
  );

end generate;

end architecture;