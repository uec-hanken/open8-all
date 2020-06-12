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
-- VHDL Entity: vector_tx
-- Description: Reads  the pushbuttons and switches on the DE1-SOC board and
--               sends a vector command and argument to a vector_rx receiver
--               which executes them in lieu of a parallel controller.
--
-- Revision History
-- Author          Date     Change
------------------ -------- ---------------------------------------------------
-- Seth Henry      05/06/20 Added version block

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.std_logic_arith.all;
  use ieee.std_logic_misc.all;

entity vector_tx is
generic(
  Button_Level               : std_logic;
  Bit_Rate                   : real;
  Enable_Parity              : boolean;
  Parity_Odd_Even_n          : std_logic;
  Sys_Freq                   : real;
  Reset_Level                : std_logic
);
port(
  Clock                      : in  std_logic;
  Reset                      : in  std_logic;
  --
  Switches                   : in  std_logic_vector(9 downto 0);
  Pushbutton                 : in  std_logic;
  --
  Tx_Out                     : out std_logic
);
end entity;

architecture behave of vector_tx is

  signal uSec_Tick           : std_logic;
  signal mSec_Tick           : std_logic;

  signal Button_Pressed      : std_logic := '0';
  signal Button_CoS          : std_logic := '0';

  type VEC_ARG_TYPE is array(0 to 15) of std_logic_vector(15 downto 0);
  constant VEC_ARGS          : VEC_ARG_TYPE := (
                               x"0000",
                               x"1111",
                               x"2222",
                               x"3333",
                               x"4444",
                               x"5555",
                               x"6666",
                               x"7777",
                               x"8888",
                               x"9999",
                               x"AAAA",
                               x"BBBB",
                               x"CCCC",
                               x"DDDD",
                               x"EEEE",
                               x"FFFF"
                             );

  alias Vector_Arg_Sel       is Switches(9 downto 6);
  alias Vector_Cmd_Sel       is Switches(5 downto 0);

  signal Vector_Cmd          : std_logic_vector(7 downto 0);

  signal Vector_Arg          : std_logic_vector(15 downto 0);
  alias Vector_Arg_LB        is Vector_Arg(7 downto 0);
  alias Vector_Arg_UB        is Vector_Arg(15 downto 8);

  type VECTOR_TX_STATES is (IDLE, SEND_CMD, WAIT_CMD, SEND_ARG_LB, WAIT_ARG_LB, SEND_ARG_UB, WAIT_ARG_UB );
  signal Vector_State        : VECTOR_TX_STATES := IDLE;

  constant BAUD_RATE_DIV     : integer := integer(Sys_Freq / Bit_Rate);

  signal Tx_Data             : std_logic_vector(7 downto 0) := x"00";
  signal Tx_Valid            : std_logic := '0';
  signal Tx_Done             : std_logic := '0';

begin

  U_USEC : entity work.sys_tick
  generic map(
    Reset_Level              => Reset_Level,
    Sys_Freq                 => Sys_Freq
  )
  port map(
    Clock                    => Clock,
    Reset                    => Reset,
    uSec_Tick                => uSec_Tick,
    mSec_Tick                => mSec_Tick
  );

  U_BTN : entity work.button_db
  generic map(
    Button_Level             => Button_Level,
    Reset_Level              => Reset_Level
  )
  port map(
    Clock                    => Clock,
    Reset                    => Reset,
    mSec_Tick                => mSec_Tick,
    --
    Button_In                => Pushbutton,
    --
    Button_Pressed           => Button_Pressed,
    Button_CoS               => Button_CoS
  );

  Input_reg_proc: process( Clock, Reset )
  begin
    if( Reset = Reset_Level )then
      Vector_Cmd             <= x"00";
      Vector_Arg             <= x"0000";
    elsif( rising_edge(Clock) )then
      Vector_Cmd             <= "00" & Vector_Cmd_Sel;
      Vector_Arg             <= VEC_ARGS(conv_integer(Vector_Arg_Sel));
    end if;
  end process;

  TX_FSM_proc: process( Clock, Reset )
  begin
    if( Reset = Reset_Level )then
      Vector_State           <= IDLE;
      Tx_Data                <= x"00";
      Tx_Valid               <= '0';
    elsif( rising_edge(Clock) )then
      Tx_Data                <= x"00";
      Tx_Valid               <= '0';
      case( Vector_State )is
        when IDLE =>
          if( Button_CoS = '1' and Button_Pressed = '1' )then
            Vector_State     <= SEND_CMD;
          end if;

        when SEND_CMD =>
          Tx_Data            <= Vector_Cmd;
          Tx_Valid           <= '1';
          Vector_State       <= WAIT_CMD;

        when WAIT_CMD =>
          if( Tx_Done = '1' )then
            Vector_State     <= SEND_ARG_LB;
          end if;

        when SEND_ARG_LB =>
          Tx_Data            <= Vector_Arg_LB;
          Tx_Valid           <= '1';
          Vector_State       <= WAIT_ARG_LB;

        when WAIT_ARG_LB =>
          if( Tx_Done = '1' )then
            Vector_State     <= SEND_ARG_UB;
          end if;

        when SEND_ARG_UB =>
          Tx_Data            <= Vector_Arg_UB;
          Tx_Valid           <= '1';
          Vector_State       <= WAIT_ARG_UB;

        when WAIT_ARG_UB =>
          if( Tx_Done = '1' )then
            Vector_State     <= IDLE;
          end if;

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
    Tx_Valid                 => Tx_Valid,
    --
    Tx_Out                   => Tx_Out,
    Tx_Done                  => Tx_Done
  );

end architecture;