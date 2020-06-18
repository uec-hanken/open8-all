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
-- VHDL Units : sdlc_serial_rxfsm
-- Description: Handles writing full packets to the dual-port memory based on
--               the framing flags from the packet detection logic and the
--               computed CRC. Note that because the framing engine doesn't
--               know ahead of time where the CRC is, it writes all incoming
--               data. This state machine maintains a three-deep history so
--               that it can "look back" two writes and get the correct CRC
--               that matches the received CRC.

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.std_logic_arith.all;

library work;
  use work.sdlc_serial_pkg.all;

entity sdlc_serial_rxfsm is
generic(
  Reset_Level                :std_logic
);
port(
  Clock                      : in  std_logic;
  Reset                      : in  std_logic;
  --
  BClk_Okay                  : in  std_logic    := '0';
  --
  DP_Port1_Addr              : out DATA_IN_TYPE;
  DP_Port1_RWn               : out std_logic;
  DP_Port1_WrData            : out DATA_IN_TYPE;
  DP_Port1_RdData            : in  DATA_IN_TYPE := x"00";
  DP_Port1_Req               : out std_logic;
  DP_Port1_Ack               : in  std_logic    := '0';
  --
  RX_CRC_Valid               : in  std_logic    := '0';
  RX_CRC_Data                : in  CRC_OUT_TYPE := x"0000";
  --
  RX_Frame_Start             : in  std_logic    := '0';
  RX_Frame_Stop              : in  std_logic    := '0';
  RX_Frame_Valid             : in  std_logic    := '0';
  RX_Frame_Data              : in  DATA_IN_TYPE := x"00";
  --
  RX_CRC_Failed              : out std_logic;
  --
  RX_Interrupt               : out std_logic
);
end entity;

architecture behave of sdlc_serial_rxfsm is

  type RX_FSM_STATES is ( WAIT_FOR_CLOCK, WAIT_FOR_FLAG,
                          RX_MESG_DATA, RX_WR_DATA,
                          RX_CRC_LB_RD, RX_CRC_UB_RD,
                          RX_WR_CRC, RX_WR_COUNT );

  signal RX_State            : RX_FSM_STATES := WAIT_FOR_CLOCK;

  signal RX_Length           : DATA_IN_TYPE  := x"00";

  type CRC_HISTORY is array(0 to 2) of CRC_OUT_TYPE;
  signal RX_CRC_Hist         : CRC_HISTORY := (x"0000",x"0000",x"0000");
  alias  RX_CRC_Calc         is RX_CRC_Hist(2);

  signal RX_CRC_Rcvd         : CRC_OUT_TYPE := x"0000";
  alias  RX_CRC_Rcvd_LB      is RX_CRC_Rcvd(7 downto 0);
  alias  RX_CRC_Rcvd_UB      is RX_CRC_Rcvd(15 downto 8);

begin

  CRC_History_proc: process( Clock, Reset )
  begin
    if( Reset = Reset_Level )then
      RX_CRC_Hist(0)         <= x"0000";
      RX_CRC_Hist(1)         <= x"0000";
      RX_CRC_Hist(2)         <= x"0000";
    elsif( rising_edge(Clock) )then
      if( RX_CRC_Valid = '1' )then
        RX_CRC_Hist(2)       <= RX_CRC_Hist(1);
        RX_CRC_Hist(1)       <= RX_CRC_Hist(0);
        RX_CRC_Hist(0)       <= RX_CRC_Data;
      end if;
    end if;
  end process;

  RX_Ctrl_proc: process( Reset, Clock )
  begin
    if( Reset = Reset_Level )then
      RX_State               <= WAIT_FOR_CLOCK;

      DP_Port1_Addr          <= x"00";
      DP_Port1_RWn           <= '1';
      DP_Port1_WrData        <= x"00";
      DP_Port1_Req           <= '0';

      RX_Length              <= x"00";

      RX_CRC_Rcvd            <= x"0000";

      RX_CRC_Failed          <= '0';

      RX_Interrupt           <= '0';

    elsif( rising_edge(Clock) )then

      DP_Port1_Addr          <= x"00";
      DP_Port1_RWn           <= '1';
      DP_Port1_WrData        <= x"00";
      DP_Port1_Req           <= '0';

      RX_CRC_Failed          <= '0';

      RX_Interrupt           <= '0';

      case( RX_State )is

        when WAIT_FOR_CLOCK =>
          RX_State           <= WAIT_FOR_FLAG;

        when WAIT_FOR_FLAG =>
          if( RX_Frame_Start = '1' )then
            RX_Length        <= x"00";
            RX_State         <= RX_MESG_DATA;
          end if;

        when RX_MESG_DATA =>
          if( RX_Frame_Stop = '1' )then
            RX_Length        <= RX_Length - 1;
            RX_State         <= RX_CRC_UB_RD;
          elsif( RX_Frame_Valid = '1' )then
            RX_State         <= RX_WR_DATA;
            if( RX_Length > 254 )then
              RX_Length      <= ERR_LENGTH;
              RX_State       <= RX_WR_COUNT;
            end if;
          end if;

        when RX_WR_DATA  =>
          RX_Length          <= RX_Length + DP_Port1_Ack;
          DP_Port1_Addr      <= RX_Length;
          DP_Port1_WrData    <= RX_Frame_Data;
          DP_Port1_RWn       <= '0';
          DP_Port1_Req       <= '1';
          if( DP_Port1_Ack = '1' )then
            DP_Port1_Req     <= '0';
            RX_State         <= RX_MESG_DATA;
          end if;

        when RX_CRC_UB_RD =>
          RX_Length          <= RX_Length - DP_Port1_Ack;
          DP_Port1_Addr      <= RX_Length;
          DP_Port1_Req       <= '1';
          if( DP_Port1_Ack = '1' )then
            DP_Port1_Req     <= '0';
            RX_CRC_Rcvd_UB   <= DP_Port1_RdData;
            RX_State         <= RX_CRC_LB_RD;
          end if;

        when RX_CRC_LB_RD =>
          DP_Port1_Addr      <= RX_Length;
          DP_Port1_Req       <= '1';
          if( DP_Port1_Ack = '1' )then
            DP_Port1_Req     <= '0';
            RX_CRC_Rcvd_LB   <= DP_Port1_RdData;
            RX_State         <= RX_WR_CRC;
          end if;

        when RX_WR_CRC =>
          DP_Port1_Addr      <= CS_REGISTER;
          DP_Port1_WrData    <= x"FF";
          if( RX_CRC_Rcvd /= RX_CRC_Calc )then
            RX_CRC_Failed    <= '1';
            DP_Port1_WrData  <= x"00";
          end if;
          DP_Port1_RWn       <= '0';
          DP_Port1_Req       <= '1';
          if( DP_Port1_Ack = '1' )then
            DP_Port1_Req     <= '0';
            RX_State         <= RX_WR_COUNT;
          end if;

        when RX_WR_COUNT =>
          DP_Port1_Addr      <= RX_REGISTER;
          DP_Port1_WrData    <= RX_Length;
          DP_Port1_RWn       <= '0';
          DP_Port1_Req       <= '1';
          if( DP_Port1_Ack = '1' )then
            DP_Port1_Req     <= '0';
            RX_Interrupt     <= '1';
            RX_State         <= WAIT_FOR_FLAG;
          end if;

        when others => null;
      end case;

      if( BClk_Okay = '0' )then
        RX_State             <= WAIT_FOR_FLAG;
      end if;

    end if;
  end process;

end architecture;