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
-- VHDL Units : sdlc_serial_txfsm
-- Description: Handles packet transmit functions by pulling the length from
--               a predefined control/status field, then loading the packet
--               contents from the dual-port memory and writing them to the
--               low-level SDLC transmitter. Also handles the clock
--               detection function and populates the clock status field.
--              The engine will write 0xFF to transmit control/status field
--               to indicate it is "done".
--              The engine will write 0x00 to the clock status field if
--               BClk_Okay is LOW, otherwise it will write 0xFF

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.std_logic_arith.all;

library work;
  use work.sdlc_serial_pkg.all;

entity sdlc_serial_txfsm is
generic(
  Reset_Level                :std_logic
);
port(
  Clock                      : in  std_logic;
  Reset                      : in  std_logic;
  --
  BClk_Okay                  : in  std_logic := '0';
  --
  Reg_Clk_Sel                : in  std_logic := '0';
  Reg_TxS_Sel                : in  std_logic := '0';
  --
  DP_Port0_Addr              : out DATA_IN_TYPE;
  DP_Port0_RWn               : out std_logic;
  DP_Port0_WrData            : out DATA_IN_TYPE;
  DP_Port0_RdData            : in  DATA_IN_TYPE := x"00";
  DP_Port0_Req               : out std_logic;
  DP_Port0_Ack               : in std_logic := '0';
  --
  TX_Wr_En                   : out std_logic;
  TX_Wr_Flag                 : out std_logic;
  TX_Wr_Data                 : out DATA_IN_TYPE;
  TX_Req_Next                : in  std_logic := '0';
  --
  TX_CRC_Clr                 : out std_logic;
  TX_CRC_En                  : out std_logic;
  TX_CRC_Data                : in  CRC_OUT_TYPE := x"0000";
  TX_CRC_Valid               : in  std_logic := '0';
  --
  TX_Interrupt               : out std_logic
);
end entity;

architecture behave of sdlc_serial_txfsm is

  type TX_FSM_STATES is ( INIT_FLAG,
                          WR_CLOCK_STATE, WAIT_FOR_CLOCK,
                          WAIT_FOR_UPDATE,
                          RD_TX_REGISTER, TX_INIT,
                          TX_START_FLAG, TX_WAIT_START_FLAG,
                          TX_MESG_DATA, TX_ADV_ADDR, TX_WAIT_MESG_DATA,
                          TX_CRC_LB_WR, TX_CRC_LB_WAIT,
                          TX_CRC_UB_WR, TX_CRC_UB_WAIT,
                          TX_STOP_FLAG, TX_WAIT_STOP_FLAG, TX_SET_FLAG );

  signal TX_State            : TX_FSM_STATES := WR_CLOCK_STATE;
  signal TX_Length           : DATA_IN_TYPE  := x"00";

  signal DP_Port0_Addr_i     : DATA_IN_TYPE := x"00";

  alias  TX_CRC_Data_LB      is TX_CRC_Data(7 downto 0);
  alias  TX_CRC_Data_UB      is TX_CRC_Data(15 downto 8);

  signal BClk_q1, BClk_CoS   : std_logic := '0';
  signal TX_Int_pend         : std_logic := '0';

begin

  DP_Port0_Addr              <= DP_Port0_Addr_i;

  TX_Ctrl_proc: process( Reset, Clock )
  begin
    if( Reset = Reset_Level )then
      TX_State               <= INIT_FLAG;

      DP_Port0_Addr_i        <= x"00";
      DP_Port0_RWn           <= '1';
      DP_Port0_WrData        <= x"00";
      DP_Port0_Req           <= '0';

      TX_Length              <= x"00";

      TX_Wr_En               <= '0';
      TX_Wr_Flag             <= '0';
      TX_Wr_Data             <= x"00";

      TX_CRC_Clr             <= '0';
      TX_CRC_En              <= '0';

      BClk_q1                <= '0';
      BClk_CoS               <= '0';

      TX_Int_pend            <= '0';
      TX_Interrupt           <= '0';

    elsif( rising_edge(Clock) )then

      DP_Port0_RWn           <= '1';
      DP_Port0_WrData        <= x"00";
      DP_Port0_Req           <= '0';

      TX_Wr_En               <= '0';
      TX_Wr_Flag             <= '0';
      TX_Wr_Data             <= x"00";

      TX_CRC_Clr             <= '0';
      TX_CRC_En              <= '0';

      BClk_q1                <= BClk_Okay;
      BClk_CoS               <= BClk_q1 xor BClk_Okay;

      TX_Interrupt           <= '0';

      case( TX_State )is

        when INIT_FLAG =>
          DP_Port0_Addr_i    <= TX_REGISTER;
          DP_Port0_Req       <= '1';
          DP_Port0_WrData    <= FLAG_DONE;
          DP_Port0_RWn       <= '0';
          if( DP_Port0_Ack = '1' )then
            DP_Port0_Req     <= '0';
            TX_State         <= WR_CLOCK_STATE;
          end if;

        when WAIT_FOR_UPDATE =>
          if( Reg_Clk_Sel = '1' )then
            TX_State         <= WR_CLOCK_STATE;
          end if;
          if( Reg_TxS_Sel = '1' )then
            TX_State         <= RD_TX_REGISTER;
          end if;

        when WR_CLOCK_STATE =>
          DP_Port0_Addr_i    <= CK_REGISTER;
          DP_Port0_Req       <= '1';
          DP_Port0_WrData    <= (others => BClk_Okay);
          DP_Port0_RWn       <= '0';
          if( DP_Port0_Ack = '1' )then
            TX_Interrupt     <= TX_Int_pend;
            TX_Int_pend      <= '0';
            DP_Port0_Req     <= '0';
            TX_State         <= WAIT_FOR_CLOCK;
          end if;

        when WAIT_FOR_CLOCK =>
          if( BClk_Okay = '1' )then
            TX_State         <= WAIT_FOR_UPDATE;
          end if;

        when RD_TX_REGISTER =>
          DP_Port0_Addr_i    <= TX_REGISTER;
          DP_Port0_Req       <= '1';
          if( DP_Port0_Ack = '1' )then
            DP_Port0_Req     <= '0';
            TX_Length        <= DP_Port0_RdData;
            TX_State         <= TX_INIT;
          end if;

        when TX_INIT =>
          TX_State         <= WAIT_FOR_UPDATE;
          if( TX_Length > TX_RESERVED_LOW and
              TX_Length < TX_RESERVED_HIGH )then
            TX_CRC_Clr       <= '1';
            TX_State         <= TX_START_FLAG;
          end if;

        when TX_START_FLAG =>
          TX_Wr_En           <= '1';
          TX_Wr_Flag         <= '1';
          TX_Wr_Data         <= SDLC_FLAG;
          TX_State           <= TX_WAIT_START_FLAG;

        when TX_WAIT_START_FLAG =>
          if( TX_Req_Next = '1' )then
            DP_Port0_Addr_i  <= x"00";
            TX_State         <= TX_ADV_ADDR;
          end if;

        when TX_ADV_ADDR =>
          DP_Port0_Req       <= '1';
          if( DP_Port0_Ack = '1' )then
            DP_Port0_Req     <= '0';
            DP_Port0_Addr_i  <= DP_Port0_Addr_i + 1;
            TX_Length        <= TX_Length - 1;
            TX_State         <= TX_MESG_DATA;
          end if;

        when TX_MESG_DATA =>
          TX_Wr_En           <= '1';
          TX_Wr_Data         <= DP_Port0_RdData;
          TX_CRC_En          <= '1';
          TX_State           <= TX_WAIT_MESG_DATA;

        when TX_WAIT_MESG_DATA =>
          if( TX_Req_Next = '1' )then
            TX_State         <= TX_ADV_ADDR;
            if( TX_Length = 0 )then
              TX_State       <= TX_CRC_LB_WR;
            end if;
          end if;

        when TX_CRC_LB_WR =>
          TX_Wr_En           <= '1';
          TX_Wr_Data         <= TX_CRC_Data_LB;
          TX_State           <= TX_CRC_LB_WAIT;

        when TX_CRC_LB_WAIT =>
          if( TX_Req_Next = '1' )then
              TX_State       <= TX_CRC_UB_WR;
          end if;

        when TX_CRC_UB_WR =>
          TX_Wr_En           <= '1';
          TX_Wr_Data         <= TX_CRC_Data_UB;
          TX_State           <= TX_CRC_UB_WAIT;

        when TX_CRC_UB_WAIT =>
          if( TX_Req_Next = '1' )then
              TX_State       <= TX_STOP_FLAG;
          end if;

        when TX_STOP_FLAG =>
          TX_Wr_En           <= '1';
          TX_Wr_Flag         <= '1';
          TX_Wr_Data         <= SDLC_FLAG;
          TX_State           <= TX_WAIT_STOP_FLAG;

        when TX_WAIT_STOP_FLAG =>
          if( TX_Req_Next = '1' )then
            TX_State         <= TX_SET_FLAG;
          end if;

        when TX_SET_FLAG =>
          DP_Port0_Addr_i    <= TX_REGISTER;
          DP_Port0_Req       <= '1';
          DP_Port0_WrData    <= FLAG_DONE;
          DP_Port0_RWn       <= '0';
          if( DP_Port0_Ack = '1' )then
            DP_Port0_Req     <= '0';
            TX_State         <= WAIT_FOR_UPDATE;
          end if;

        when others => null;
      end case;

      if( BClk_CoS = '1' )then
        TX_Int_pend          <= '1';
        TX_State             <= WR_CLOCK_STATE;
      end if;

    end if;
  end process;

end architecture;