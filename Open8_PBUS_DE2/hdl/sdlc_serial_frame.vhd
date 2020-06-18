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
-- VHDL Units :  sdlc_serial_frame
-- Description:  Listens to the raw serial receiver flags and data to detect
--                packet boundaries, sending frame start/stop signals to the
--                byte-level receive logic. Also indirectly controls the RX
--                CRC calculator.
--               Note that this frame detection system can handle either an
--                idle line or repeated flags.
--
-- Revision History
-- Author          Date     Change
------------------ -------- ---------------------------------------------------
-- Seth Henry      04/14/20 Code cleanup and revision section added

library ieee;
  use ieee.std_logic_1164.all;

library work;
  use work.sdlc_serial_pkg.all;

entity sdlc_serial_frame is
generic(
  Reset_Level                : std_logic
);
port(
  Clock                      : in  std_logic;
  Reset                      : in  std_logic;
  --
  RX_Valid                   : in  std_logic;
  RX_Flag                    : in  std_logic;
  RX_Data                    : in  DATA_IN_TYPE;
  RX_Idle                    : in  std_logic;
  --
  RX_Frame_Start             : out std_logic;
  RX_Frame_Stop              : out std_logic;
  RX_Frame_Valid             : out std_logic;
  RX_Frame_Data              : out DATA_IN_TYPE
);
end entity;

architecture behave of sdlc_serial_frame is

  type PACKET_STATES is (IDLE, FRAME_START, FRAME_DATA, FRAME_STOP );
  signal Pkt_State           : PACKET_STATES := IDLE;
  signal First_Byte          : std_logic := '0';

begin

  Packet_Marker_proc: process( Clock, Reset )
  begin
    if( Reset = Reset_Level )then
      Pkt_State              <= IDLE;
      First_Byte             <= '0';
      RX_Frame_Start         <= '0';
      RX_Frame_Stop          <= '0';
      RX_Frame_Valid         <= '0';
      RX_Frame_Data          <= x"00";
    elsif( rising_edge(Clock) )then
      RX_Frame_Start         <= '0';
      RX_Frame_Stop          <= '0';
      RX_Frame_Valid         <= '0';

      case( Pkt_State )is
        when IDLE =>
          if( RX_Valid = '1' and RX_Flag = '1' )then
            Pkt_State        <= FRAME_START;
          end if;

        when FRAME_START =>
            if( RX_Valid = '1' and RX_Flag = '0' )then
              RX_Frame_Start <= '1';
              First_Byte     <= '1';
              Pkt_State      <= FRAME_DATA;
            end if;

        when FRAME_DATA =>
          First_Byte         <= '0';
          if( (RX_Valid = '1' and RX_Flag = '0') or
            First_Byte = '1' )then
            RX_Frame_Valid   <= '1';
            RX_Frame_Data    <= RX_Data;
          elsif( RX_Valid = '1' and RX_Flag = '1' )then
            Pkt_State        <= FRAME_STOP;
          end if;

        when FRAME_STOP =>
          RX_Frame_Stop      <= not RX_Idle;
          Pkt_State          <= IDLE;

        when others => null;
      end case;

      if( RX_Idle = '1' and Pkt_State /= IDLE )then
        Pkt_State            <= FRAME_STOP;
      end if;

    end if;
  end process;

end architecture;