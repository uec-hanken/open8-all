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
-- VHDL Units :  sdlc_serial_tx
-- Description:
--  Implements a SDLC compliant serial transmitter based on the SDLC
--  requirements in the ITU X.25 physical layer specification. Entity will
--  insert a zero after every 5 consecutive '1's unless the TX_FSS_Flag is
--  held high while TX_En is driven high. This will allow the SDLC frame
--  flag, 0x7E, to be transmitted unmodified. (FSS = Frame Start/Stop)
--
--  This entity requires the Bitclock rising and falling edge pulses from the
--  bitclock generator. Transmit data is updated on the falling edge, while
--  signals to higher-level logic (TX_Req_Next) are generated on the rising
--  edge.
--

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.std_logic_misc.all;

library work;
  use work.sdlc_serial_pkg.all;

entity sdlc_serial_tx is
generic(
  Reset_Level                : std_logic := '1'
);
port(
  Clock                      : in  std_logic;
  Reset                      : in  std_logic;
  -- Bitclock rising/falling edges
  BClk_FE                    : in  std_logic;
  BClk_RE                    : in  std_logic;
  BClk_Okay                  : in  std_logic;
  -- Write port from higher-level logic
  TX_En                      : in  std_logic;
  TX_FSS_Flag                : in  std_logic;
  TX_Data                    : in  DATA_IN_TYPE;
  TX_Req_Next                : out std_logic;
  -- Bit stream
  Serial_Out                 : out std_logic
);
end entity;

architecture behave of sdlc_serial_tx is

  signal TX_Arm              : std_logic := '0';
  signal TX_Flag             : std_logic := '0';
  signal TX_Buffer           : std_logic_vector(8 downto 0) := (others => '0');
  alias  TX_Buffer_Flag      is TX_Buffer(8);
  alias  TX_Buffer_Data      is TX_Buffer(7 downto 0);

  type TX_STATES is (INIT, IDLE, XMIT, SPACE, TERM, LD_NEXT);
  signal TX_State            : TX_STATES := INIT;

  signal TX_ShftReg          : std_logic_vector(7 downto 0) := (others => '0');
  signal TX_Next             : std_logic := '0';
  signal TX_BitStuff         : std_logic_vector(4 downto 0) := (others => '0');
  signal TX_BitCntr          : std_logic_vector(3 downto 0) := (others => '0');
  alias  TX_BitSel           is TX_BitCntr(2 downto 0);
  alias  TX_Term             is TX_BitCntr(3);

begin

  TX_Proc: process( Clock, Reset )
  begin
    if( Reset = Reset_Level )then
      TX_State               <= IDLE;
      Serial_Out             <= '1';
      TX_Arm                 <= '0';
      TX_Buffer              <= (others => '0');
      TX_Flag                <= '0';
      TX_ShftReg             <= (others => '0');
      TX_BitStuff            <= (others => '0');
      TX_BitCntr             <= (others => '1');
      TX_Req_Next               <= '0';
    elsif( rising_edge(Clock) )then

      if( TX_En = '1' and TX_Arm = '0')then
        TX_Arm               <= '1';
        TX_Buffer_Flag       <= TX_FSS_Flag;
        TX_Buffer_Data       <= TX_Data;
      end if;

      TX_Req_Next               <= '0';

      case( TX_State )is
        when INIT =>
          Serial_Out         <= '1';
          TX_State           <= IDLE;

        when IDLE =>
          Serial_Out         <= '1';
          if( TX_Arm = '1' and BClk_FE = '1' )then
            TX_Arm           <= '0';
            TX_BitCntr       <= (others => '0');
            TX_BitStuff      <= (others => '0');
            TX_Flag          <= TX_Buffer_Flag;
            TX_ShftReg       <= TX_Buffer_Data;
            TX_Req_Next      <= '1';
            TX_State         <= XMIT;
          end if;

        when XMIT =>
          Serial_Out         <= TX_ShftReg(conv_integer(TX_BitSel));
          TX_BitCntr         <= TX_BitCntr + BClk_FE;
          if( BClk_RE = '1' )then
            TX_BitStuff      <= TX_BitStuff(3 downto 0) &
                                TX_ShftReg(conv_integer(TX_BitSel));
          end if;
          if( BClk_FE = '1' )then
            if( TX_BitCntr >= 7 )then
              TX_State       <= TERM;
            elsif( and_reduce(TX_BitStuff) = '1' and TX_Flag = '0' )then
              TX_BitStuff    <= (others => '0');
              TX_State       <= SPACE;
            else
              TX_BitCntr     <= TX_BitCntr + 1;
            end if;
          end if;

        when SPACE =>
          Serial_Out         <= '0';
          if( BClk_FE = '1' )then
            TX_State         <= XMIT;
          end if;

        when TERM =>
          if( TX_Arm = '1' )then
            TX_State         <= LD_NEXT;
          else
            TX_State         <= IDLE;
          end if;

        when LD_NEXT =>
          TX_Arm             <= '0';
          TX_BitCntr         <= (others => '0');
          TX_Flag            <= TX_Buffer_Flag;
          TX_ShftReg         <= TX_Buffer_Data;
          TX_Req_Next        <= '1';
          TX_State           <= XMIT;
          if( and_reduce(TX_BitStuff) = '1' and TX_Flag = '0' )then
            TX_BitStuff      <= (others => '0');
            TX_State         <= SPACE;
          end if;

        when others => null;
      end case;

      if( BClk_Okay = '0' )then
        TX_State                <= INIT;
      end if;

    end if;
  end process;

end architecture;