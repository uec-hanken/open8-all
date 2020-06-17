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
-- VHDL Units : sdlc_serial_arbfsm
-- Description: Handles access to the shared buffer memory
--
-- Revision History
-- Author          Date     Change
------------------ -------- ---------------------------------------------------
-- Seth Henry      04/14/20 Code cleanup and revision section added

library ieee;
  use ieee.std_logic_1164.all;

library work;
  use work.sdlc_serial_pkg.all;

entity sdlc_serial_arbfsm is
generic(
  Reset_Level                : std_logic
);
port(
  Clock                      : in  std_logic;
  Reset                      : in  std_logic;
  --
  DP_Addr                    : out std_logic_vector(8 downto 0);
  DP_Wr_Data                 : out DATA_IN_TYPE;
  DP_Wr_En                   : out std_logic;
  DP_Rd_Data                 : in  DATA_IN_TYPE;
  --
  DP_Port0_Addr              : in  DATA_IN_TYPE  := x"00";
  DP_Port0_RWn               : in  std_logic     := '0';
  DP_Port0_WrData            : in  DATA_IN_TYPE  := x"00";
  DP_Port0_RdData            : out DATA_IN_TYPE ;
  DP_Port0_Req               : in  std_logic     := '0';
  DP_Port0_Ack               : out std_logic;
  --
  DP_Port1_Addr              : in  DATA_IN_TYPE  := x"00";
  DP_Port1_RWn               : in  std_logic     := '0';
  DP_Port1_WrData            : in  DATA_IN_TYPE  := x"00";
  DP_Port1_RdData            : out DATA_IN_TYPE;
  DP_Port1_Req               : in  std_logic     := '0';
  DP_Port1_Ack               : out std_logic
);
end entity;

architecture behave of sdlc_serial_arbfsm is

  -- RAM Arbitration logic
  type DP_ARB_STATES is (PAUSE, IDLE,
                         PORT0_AD, PORT0_WR, PORT0_RD0, PORT0_RD1,
                         PORT1_AD, PORT1_WR, PORT1_RD0, PORT1_RD1  );
  signal DP_Arb_State        : DP_ARB_STATES := IDLE;
  signal DP_Last_Port        : std_logic     := '0';

begin

  RAM_Arb_proc: process( Clock, Reset )
  begin
    if( Reset = Reset_Level )then
      DP_Arb_State           <= IDLE;
      DP_Last_Port           <= '0';
      DP_Addr                <= (others => '0');
      DP_Wr_Data             <= x"00";
      DP_Wr_En               <= '0';
      DP_Port0_RdData        <= x"00";
      DP_Port0_Ack           <= '0';
      DP_Port1_RdData        <= x"00";
      DP_Port1_Ack           <= '0';
    elsif( rising_edge(Clock) )then
      DP_Port0_Ack           <= '0';
      DP_Port1_Ack           <= '0';
      DP_Wr_En               <= '0';

      case( DP_Arb_State )is
        when IDLE =>
          if( DP_Port0_Req = '1' and (DP_Port1_Req = '0' or DP_Last_Port = '1') )then
            DP_Arb_State     <= PORT0_AD;
          elsif( DP_Port1_Req = '1' and (DP_Port0_Req = '0' or DP_Last_Port = '0') )then
            DP_Arb_State     <= PORT1_AD;
          end if;

        when PORT0_AD =>
          DP_Last_Port       <= '0';
          DP_Addr            <= '0' & DP_Port0_Addr;
          DP_Wr_Data         <= DP_Port0_WrData;
          DP_Wr_En           <= not DP_Port0_RWn;
          if( DP_Port0_RWn = '1' )then
            DP_Arb_State     <= PORT0_RD0;
          else
            DP_Port0_Ack     <= '1';
            DP_Arb_State     <= PORT0_WR;
          end if;

        when PORT0_WR =>
          DP_Arb_State       <= IDLE;

        when PORT0_RD0 =>
          DP_Arb_State       <= PORT0_RD1;

        when PORT0_RD1 =>
          DP_Port0_Ack       <= '1';
          DP_Port0_RdData    <= DP_Rd_Data;
          DP_Arb_State       <= PAUSE;

        when PORT1_AD =>
          DP_Last_Port       <= '1';
          DP_Addr            <= '1' & DP_Port1_Addr;
          DP_Wr_Data         <= DP_Port1_WrData;
          DP_Wr_En           <= not DP_Port1_RWn;
          if( DP_Port0_RWn = '1' )then
            DP_Arb_State     <= PORT1_RD0;
          else
            DP_Port1_Ack     <= '1';
            DP_Arb_State     <= PORT1_WR;
          end if;

        when PORT1_WR =>
          DP_Arb_State       <= IDLE;

        when PORT1_RD0 =>
          DP_Arb_State       <= PORT1_RD1;

        when PORT1_RD1 =>
          DP_Port1_Ack       <= '1';
          DP_Port1_RdData    <= DP_Rd_Data;
          DP_Arb_State       <= PAUSE;

        when PAUSE =>
          DP_Arb_State       <= IDLE;

        when others => null;

      end case;
    end if;
  end process;

end architecture;
