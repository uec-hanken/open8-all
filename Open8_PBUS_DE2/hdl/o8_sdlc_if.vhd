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
-- VHDL Units :  o8_sdlc_if
-- Description:  Provides a full memory-mapped SDLC stack with automatic CRC16
--                Checksum insertion and integrity checking.
--
-- Transmit Memory Map
-- "0_0000_0000" (0x000) TX Buffer START
-- "0_1111_1101" (0x0FD) TX Buffer END
-- "0_1111_1110" (0x0FE) Clock Status*
-- "0_1111_1111" (0x0FF) TX Length / Status**
--
-- Receive Memory Map
-- "1_0000_0000" (0x100) RX Buffer START
-- "1_1111_1101" (0x1FD) RX Buffer END
-- "1_1111_1110" (0x0FE) RX Checksum Status***
-- "1_1111_1111" (0x1FF) RX Length   Status****
--
-- *    Address 0xFE reports the SDLC bit clock status and updates on changes.
--      1) If BClk_Okay = '0' (Bitclock is NOT present), the field will report
--          0x00. Otherwise, it will report 0xFF if the bitclock is present.
--      2) Writing any value to the register will cause the controller to
--         silently reset the clock status without causing an interrupt.
--
-- **   This location serves as the control/status register for transmit
--      1) Writing a value between 1 and 253 will trigger the transmit engine,
--          using the write value as the packet length.
--      2) Values 0x00, 0xFE, or 0xFF are invalid, and will be ignored.
--      3) This value will change from the user written value to 0xFF once the
--          packet is transmitted to indicate the transmission is complete.
--
-- ***  This location serves as the status register for receive checksum test
--      1) A value of 0x00 indicates the CRC did NOT match, while a value
--         of 0xFF indicates that the recieved CRC matches the calculated CRC.
--
-- **** This location serves as the status register for the receive
--      1) This value is only updated on reception of a full frame, indicated
--          by a start followed by a stop flag. Incomplete frames are ignored.
--      2) If too many bytes are received (buffer overflow), a value of
--          ERR_LENGTH is written.
--
-- Revision History
-- Author          Date     Change
------------------ -------- ---------------------------------------------------
-- Seth Henry      04/16/20 Revision block added

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.std_logic_arith.all;

library work;
  use work.open8_pkg.all;

library work;
  use work.sdlc_serial_pkg.all;

entity o8_sdlc_if is
generic(
  Monitor_Enable             : boolean := false;
  Attach_Monitor_to_CPU_Side : boolean := false;
  Poly_Init                  : std_logic_vector(15 downto 0) := x"0000";
  Set_As_Master              : boolean := true;
  Clock_Offset               : integer := 6;
  BitClock_Frequency         : real := 500000.0;
  Clock_Frequency            : real := 100000000.0;
  Address                    : ADDRESS_TYPE
);
port(
  Open8_Bus                  : in  OPEN8_BUS_TYPE;
  Rd_Data                    : out DATA_TYPE;
  Interrupt                  : out std_logic;
  -- Serial IO
  SDLC_In                    : in  std_logic;
  SDLC_SClk                  : in  std_logic;
  SDLC_MClk                  : out std_logic;
  SDLC_Out                   : out std_logic
);
end entity;

architecture behave of o8_sdlc_if is

  alias Clock                is Open8_Bus.Clock;
  alias Reset                is Open8_Bus.Reset;

  constant Base_Addr         : std_logic_vector(15 downto 9)
                               := Address(15 downto 9);

  alias CPU_Upper_Addr       is Open8_Bus.Address(15 downto 9);
  signal Base_Addr_Match     : std_logic := '0';

  alias DP_A_Addr            is Open8_Bus.Address(8 downto 0);
  signal DP_A_Wr_En          : std_logic := '0';
  alias  DP_A_Wr_Data        is Open8_Bus.Wr_Data;
  signal DP_A_Rd_En          : std_logic := '0';
  signal DP_A_Rd_Data        : DATA_TYPE := OPEN8_NULLBUS;

  constant Reg_Sub_Addr      : std_logic_vector(8 downto 1) := x"7F";
  alias Reg_Upper_Addr       is Open8_Bus.Address(8 downto 1);
  alias Reg_Lower_Addr       is Open8_Bus.Address(0);

  signal Reg_Addr            : std_logic_vector(8 downto 1) := (others => '0');
  signal Reg_Sel             : std_logic     := '0';
  signal Reg_Wr_En           : std_logic     := '0';
  signal Reg_Clk_Sel         : std_logic     := '0';
  signal Reg_TxS_Sel         : std_logic     := '0';

  signal DP_B_Addr           : std_logic_vector(8 downto 0) := (others => '0');
  signal DP_B_Wr_Data        : DATA_IN_TYPE  := x"00";
  signal DP_B_Wr_En          : std_logic     := '0';
  signal DP_B_Rd_Data        : DATA_IN_TYPE  := x"00";

  signal DP_Port0_Addr       : DATA_IN_TYPE  := x"00";
  signal DP_Port0_RWn        : std_logic     := '0';
  signal DP_Port0_WrData     : DATA_IN_TYPE  := x"00";
  signal DP_Port0_RdData     : DATA_IN_TYPE  := x"00";
  signal DP_Port0_Req        : std_logic     := '0';
  signal DP_Port0_Ack        : std_logic     := '0';

  signal DP_Port1_Addr       : DATA_IN_TYPE  := x"00";
  signal DP_Port1_RWn        : std_logic     := '0';
  signal DP_Port1_WrData     : DATA_IN_TYPE  := x"00";
  signal DP_Port1_RdData     : DATA_IN_TYPE  := x"00";
  signal DP_Port1_Req        : std_logic     := '0';
  signal DP_Port1_Ack        : std_logic     := '0';

  signal BClk_RE             : std_logic     := '0';
  signal BClk_FE             : std_logic     := '0';
  signal BClk_Okay           : std_logic     := '0';

  signal TX_Wr_En            : std_logic     := '0';
  signal TX_Wr_Flag          : std_logic     := '0';
  signal TX_Wr_Data          : DATA_IN_TYPE  := x"00";
  signal TX_Req_Next         : std_logic     := '0';

  signal TX_CRC_Clr          : std_logic     := '0';
  signal TX_CRC_En           : std_logic     := '0';
  signal TX_CRC_Data         : CRC_OUT_TYPE  := x"0000";
  signal TX_CRC_Valid        : std_logic     := '0';

  signal TX_Interrupt        : std_logic     := '0';

  signal RX_Valid            : std_logic     := '0';
  signal RX_Flag             : std_logic     := '0';
  signal RX_Data             : DATA_IN_TYPE;
  signal RX_Idle             : std_logic     := '0';

  signal RX_Frame_Start      : std_logic     := '0';
  signal RX_Frame_Stop       : std_logic     := '0';
  signal RX_Frame_Valid      : std_logic     := '0';
  signal RX_Frame_Data       : DATA_IN_TYPE  := x"00";

  signal RX_CRC_Valid        : std_logic     := '0';
  signal RX_CRC_Data         : CRC_OUT_TYPE  := x"0000";

  signal RX_Interrupt        : std_logic     := '0';

begin

-- ***************************************************************************
-- *          Open8 Bus Interface and Control Register Detection             *
-- ***************************************************************************

  -- This decode needs to happen immediately, to give the RAM a chance to
  --  do the lookup before we have to set Rd_Data
  Base_Addr_Match            <= '1' when Base_Addr = CPU_Upper_Addr else '0';
  DP_A_Wr_En                 <= Base_Addr_Match and Open8_Bus.Wr_En;

  CPU_IF_proc: process( Reset, Clock )
  begin
    if( Reset = Reset_Level )then
      Reg_Addr               <= (others => '0');
      Reg_Wr_En              <= '0';
      Reg_Clk_Sel            <= '0';
      Reg_TxS_Sel            <= '0';
      DP_A_Rd_En             <= '0';
      Rd_Data                <= OPEN8_NULLBUS;
      Interrupt              <= '0';
    elsif( rising_edge(Clock) )then
      Reg_Addr               <= Reg_Upper_Addr;
      Reg_Sel                <= Reg_Lower_Addr;
      Reg_Wr_En              <= Base_Addr_Match and Open8_Bus.Wr_En;

      Reg_Clk_Sel            <= '0';
      Reg_TxS_Sel            <= '0';
      if( Reg_Addr = Reg_Sub_Addr )then
        Reg_Clk_Sel          <= Reg_Wr_En and not Reg_Sel;
        Reg_TxS_Sel          <= Reg_Wr_En and Reg_Sel;
      end if;

      DP_A_Rd_En             <= Base_Addr_Match and Open8_Bus.Rd_En;
      Rd_Data                <= OPEN8_NULLBUS;
      if( DP_A_Rd_En = '1' )then
        Rd_Data              <= DP_A_Rd_Data;
      end if;

      Interrupt              <= RX_Interrupt or TX_Interrupt;
    end if;
  end process;

-- ***************************************************************************
-- *                     Shared Dual-Port Memory                             *
-- ***************************************************************************

  U_RAM : entity work.sdlc_dp512b_ram
  port map(
    clock                    => Clock,
    address_a                => DP_A_Addr,
    address_b                => DP_B_Addr,
    data_a                   => DP_A_Wr_Data,
    data_b                   => DP_B_Wr_Data,
    wren_a                   => DP_A_Wr_En,
    wren_b                   => DP_B_Wr_En,
    q_a                      => DP_A_Rd_Data,
    q_b                      => DP_B_Rd_Data
  );

Attach_to_CPU_side: if( Monitor_Enable and Attach_Monitor_to_CPU_Side )generate

  U_MON: entity work.sdlc_monitor
  port map(
    clock                    => Clock,
    address                  => DP_A_Addr,
    data                     => DP_A_Wr_Data,
    wren                     => DP_A_Wr_En,
    q                        => open
  );
end generate;

Attach_to_Int_side: if( Monitor_Enable and not Attach_Monitor_to_CPU_Side )generate

  U_MON: entity work.sdlc_monitor
  port map(
    clock                    => Clock,
    address                  => DP_B_Addr,
    data                     => DP_B_Wr_Data,
    wren                     => DP_B_Wr_En,
    q                        => open
  );

end generate;

-- ***************************************************************************
-- *                     Memory Arbitration                                  *
-- ***************************************************************************

  U_ARB : entity work.sdlc_serial_arbfsm
  generic map(
    Reset_Level              => Reset_Level
  )
  port map(
    Clock                    => Clock,
    Reset                    => Reset,
    --
    DP_Addr                  => DP_B_Addr,
    DP_Wr_Data               => DP_B_Wr_Data,
    DP_Wr_En                 => DP_B_Wr_En,
    DP_Rd_Data               => DP_B_Rd_Data,
    --
    DP_Port0_Addr            => DP_Port0_Addr,
    DP_Port0_RWn             => DP_Port0_RWn,
    DP_Port0_WrData          => DP_Port0_WrData,
    DP_Port0_RdData          => DP_Port0_RdData,
    DP_Port0_Req             => DP_Port0_Req,
    DP_Port0_Ack             => DP_Port0_Ack,
    --
    DP_Port1_Addr            => DP_Port1_Addr,
    DP_Port1_RWn             => DP_Port1_RWn,
    DP_Port1_WrData          => DP_Port1_WrData,
    DP_Port1_RdData          => DP_Port1_RdData,
    DP_Port1_Req             => DP_Port1_Req,
    DP_Port1_Ack             => DP_Port1_Ack
  );

-- ***************************************************************************
-- *                        Serial BitClock                                  *
-- ***************************************************************************

  U_BCLK : entity work.sdlc_serial_clk
  generic map(
    Set_As_Master            => Set_As_Master,
    BitClock_Freq            => BitClock_Frequency,
    Reset_Level              => Reset_Level,
    Sys_Freq                 => Clock_Frequency
  )
  port map(
    Clock                    => Clock,
    Reset                    => Reset,
    --
    BClk_In                  => SDLC_SClk,
    BClk_Out                 => SDLC_MClk,
    BClk_FE                  => BClk_FE,
    BClk_RE                  => BClk_RE,
    BClk_Okay                => BClk_Okay
  );

-- ***************************************************************************
-- *                     Serial Transmit Path                                *
-- ***************************************************************************

  U_TXFSM: entity work.sdlc_serial_txfsm
  generic map(
    Reset_Level              => Reset_Level
  )
  port map(
    Clock                    => Clock,
    Reset                    => Reset,
    --
    BClk_Okay                => BClk_Okay,
    --
    Reg_Clk_Sel              => Reg_Clk_Sel,
    Reg_TxS_Sel              => Reg_TxS_Sel,
    --
    DP_Port0_Addr            => DP_Port0_Addr,
    DP_Port0_RWn             => DP_Port0_RWn,
    DP_Port0_WrData          => DP_Port0_WrData,
    DP_Port0_RdData          => DP_Port0_RdData,
    DP_Port0_Req             => DP_Port0_Req,
    DP_Port0_Ack             => DP_Port0_Ack,
    --
    TX_Wr_En                 => TX_Wr_En,
    TX_Wr_Flag               => TX_Wr_Flag,
    TX_Wr_Data               => TX_Wr_Data,
    TX_Req_Next              => TX_Req_Next,
    --
    TX_CRC_Clr               => TX_CRC_Clr,
    TX_CRC_En                => TX_CRC_En,
    TX_CRC_Data              => TX_CRC_Data,
    TX_CRC_Valid             => TX_CRC_Valid,
    --
    TX_Interrupt             => TX_Interrupt
  );

  U_TX_CRC : entity work.sdlc_crc16_ccitt
  generic map(
    Poly_Init                => Poly_Init,
    Reset_Level              => Reset_Level
  )
  port map(
    Clock                    => Clock,
    Reset                    => Reset,
    --
    Clear                    => TX_CRC_Clr,
    Wr_En                    => TX_CRC_En,
    Wr_Data                  => TX_Wr_Data,
    --
    CRC16_Valid              => TX_CRC_Valid,
    CRC16_Out                => TX_CRC_Data
  );

  U_TX_SER : entity work.sdlc_serial_tx
  generic map(
    Reset_Level              => Reset_Level
  )
  port map(
    Clock                    => Clock,
    Reset                    => Reset,
    --
    BClk_FE                  => BClk_FE,
    BClk_RE                  => BClk_RE,
    BClk_Okay                => BClk_Okay,
    --
    TX_En                    => TX_Wr_En,
    TX_FSS_Flag              => TX_Wr_Flag,
    TX_Data                  => TX_Wr_Data,
    TX_Req_Next              => TX_Req_Next,
    --
    Serial_Out               => SDLC_Out
  );

-- ***************************************************************************
-- *                     Serial Receive Path                                 *
-- ***************************************************************************

  U_RX_SER : entity work.sdlc_serial_rx
  generic map(
    Set_As_Master            => Set_As_Master,
    Clock_Offset             => Clock_Offset,
    Reset_Level              => Reset_Level
  )
  port map(
    Clock                    => Clock,
    Reset                    => Reset,
    --
    BClk_RE                  => BClk_RE,
    BClk_Okay                => BClk_Okay,
    --
    Serial_In                => SDLC_In,
    --
    RX_Valid                 => RX_Valid,
    RX_Flag                  => RX_Flag,
    RX_Data                  => RX_Data,
    RX_Idle                  => RX_Idle
  );

  U_RX_PKT : entity work.sdlc_serial_frame
  generic map(
    Reset_Level              => Reset_Level
  )
  port map(
    Clock                    => Clock,
    Reset                    => Reset,
    --
    RX_Valid                 => RX_Valid,
    RX_Flag                  => RX_Flag,
    RX_Data                  => RX_Data,
    RX_Idle                  => RX_Idle,
    --
    RX_Frame_Start           => RX_Frame_Start,
    RX_Frame_Stop            => RX_Frame_Stop,
    RX_Frame_Valid           => RX_Frame_Valid,
    RX_Frame_Data            => RX_Frame_Data
  );

  U_RX_CRC : entity work.sdlc_crc16_ccitt
  generic map(
    Poly_Init                => Poly_Init,
    Reset_Level              => Reset_Level
  )
  port map(
    Clock                    => Clock,
    Reset                    => Reset,
    --
    Clear                    => RX_Frame_Start,
    Wr_En                    => RX_Frame_Valid,
    Wr_Data                  => RX_Frame_Data,
    --
    CRC16_Valid              => RX_CRC_Valid,
    CRC16_Out                => RX_CRC_Data
  );

  U_RX_FSM : entity work.sdlc_serial_rxfsm
  generic map(
    Reset_Level              => Reset_Level
  )
  port map(
    Clock                    => Clock,
    Reset                    => Reset,
    --
    BClk_Okay                => BClk_Okay,
    --
    DP_Port1_Addr            => DP_Port1_Addr,
    DP_Port1_RWn             => DP_Port1_RWn,
    DP_Port1_WrData          => DP_Port1_WrData,
    DP_Port1_RdData          => DP_Port1_RdData,
    DP_Port1_Req             => DP_Port1_Req,
    DP_Port1_Ack             => DP_Port1_Ack,
    --
    RX_CRC_Valid             => RX_CRC_Valid,
    RX_CRC_Data              => RX_CRC_Data,
    --
    RX_Frame_Start           => RX_Frame_Start,
    RX_Frame_Stop            => RX_Frame_Stop,
    RX_Frame_Valid           => RX_Frame_Valid,
    RX_Frame_Data            => RX_Frame_Data,
    --
    RX_Interrupt             => RX_Interrupt
  );

end architecture;