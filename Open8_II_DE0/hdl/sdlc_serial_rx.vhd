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
-- VHDL Units :  sdlc_serial_rx
-- Description:
--  Implements a SDLC compliant serial receiver based on the SDLC
--  requirements in the ITU X.25 physical layer specification.
--
--  This entity will receive synchronously applied SDLC formatted serial data,
--  automatically rejecting bit-stuffed zeros and checking/detecting frame
--  start/stop flags automatically.
--
--  Also, the receiver will automatically idle itself between frames in the
--  event the frame state is lost by detecting 7 or more consecutive '1's.
--  (This assumes the transmitter continuously drives the clock).
--
--  Further, a second shift register listens for the SDLC Flag (0x7E) and will
--  reset the bit counter in the event that a flag is detected "early",
--  implying that the bitcounter is out of alignment with the data. This
--  event shouldn't occur in normal reception and is present as a backup.
--
--  This entity requires the bitclock rising edge pulses from the serial clock
--  generator. Receive data and flag signals are generated to higher-level
--  logic shortly after the rising edge of the bitclock on the "clock" clock
--  domain.
--
-- Revision History
-- Author          Date     Change
------------------ -------- ---------------------------------------------------
-- Seth Henry      04/14/20 Code cleanup and revision section added

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.std_logic_arith.all;
  use ieee.std_logic_misc.all;

library work;
  use work.sdlc_serial_pkg.all;

entity sdlc_serial_rx is
generic(
  Set_As_Master              : boolean := true;
  Clock_Offset               : integer := 6;
  Reset_Level                : std_logic := '1'
);
port(
  Clock                      : in  std_logic;
  Reset                      : in  std_logic;
  -- Bitclock rising edges
  BClk_RE                    : in  std_logic;
  BClk_Okay                  : in  std_logic;
  -- Bit stream in
  Serial_In                  : in std_logic;
  -- Parallel + Flag out
  RX_Valid                   : out std_logic;
  RX_Flag                    : out std_logic;
  RX_Data                    : out DATA_IN_TYPE;
  RX_Idle                    : out std_logic
);
end entity;

architecture behave of sdlc_serial_rx is

  signal RX_LatchEn_SR       : std_logic_vector(Clock_Offset downto 0) := (others => '0');
  alias  RX_LatchEn_M        is RX_LatchEn_SR(Clock_Offset);
  alias  RX_LatchEn_S        is BClk_RE;
  signal RX_LatchEn          : std_logic := '0';

  signal RX_Serial_SR        : std_logic_vector(1 downto 0) := (others => '0');
  alias  RX_Serial           is RX_Serial_SR(1);

  type RX_STATES is (INIT, IDLE, RCV_DATA, SKIP_ZERO, WRITE_DATA);
  signal RX_State            : RX_STATES := INIT;
  signal RX_Buffer           : DATA_IN_TYPE := x"00";
  signal RX_BitStuff_SR      : std_logic_vector(4 downto 0) := (others => '0');
  signal RX_BitCntr          : std_logic_vector(3 downto 0) := (others => '0');
  alias  RX_BitSel           is RX_BitCntr(2 downto 0);
  alias  RX_Term             is RX_BitCntr(3);

  signal RX_Flag_SR          : DATA_IN_TYPE := x"00";

  signal RX_Idle_Cntr        : std_logic_vector(2 downto 0) := (others => '0');

begin

IF_Is_Master: if( Set_As_Master )generate

  Input_proc: process( Clock, Reset )
  begin
    if( Reset = Reset_Level )then
      RX_LatchEn_SR          <= (others => '0');
      RX_Serial_SR           <= (others => '0');
    elsif( rising_edge(Clock) )then
      RX_LatchEn_SR          <= RX_LatchEn_SR(Clock_Offset - 1 downto 0) & BClk_RE;
      RX_Serial_SR           <= RX_Serial_SR(0) & Serial_In;
    end if;
  end process;

  RX_LatchEn                 <= RX_LatchEn_M;

end generate;

IF_Is_Slave: if( not Set_As_Master )generate

  Input_proc: process( Clock, Reset )
  begin
    if( Reset = Reset_Level )then
      RX_Serial_SR           <= (others => '0');
    elsif( rising_edge(Clock) )then
      RX_Serial_SR           <= RX_Serial_SR(0) & Serial_In;
    end if;
  end process;

  RX_LatchEn                 <= RX_LatchEn_S;

end generate;


  RX_Proc: process( Clock, Reset )
  begin
    if( Reset = Reset_Level )then

      RX_BitStuff_SR         <= (others => '0');
      RX_Flag_SR             <= (others => '0');
      RX_Idle_Cntr           <= (others => '0');

      RX_State               <= IDLE;
      RX_Idle                <= '0';

      RX_Buffer              <= (others => '0');
      RX_BitCntr             <= (others => '0');

      RX_Valid               <= '0';
      RX_Flag                <= '0';
      RX_Data                <= (others => '0');

    elsif( rising_edge(Clock) )then

      if( RX_LatchEn = '1' )then
        RX_Flag_SR           <= RX_Flag_SR(6 downto 0) & RX_Serial;
        if( RX_State = IDLE )then
          RX_Flag_SR         <= (others => '0');
        end if;

        RX_Idle_Cntr         <= RX_Idle_Cntr + RX_Serial;
        if( and_reduce(RX_Idle_Cntr) = '1' )then
          RX_Idle_Cntr       <= "111";
        end if;
      end if;

      if( RX_Serial = '0' )then
        RX_Idle_Cntr         <= (others => '0');
      end if;

      RX_Valid               <= '0';
      RX_Flag                <= '0';
      RX_Idle                <= '0';

      case( RX_State )is

        when INIT =>
          RX_Idle            <= '1';
          RX_State           <= IDLE;

        when IDLE =>
          RX_Idle            <= '1';
          RX_BitCntr         <= (others => '0');
          RX_BitStuff_SR     <= (others => '0');
          if( RX_Serial = '0' )then
            RX_State         <= RCV_DATA;
          end if;

        when RCV_DATA =>
          if( RX_Term = '1' )then
            RX_State         <= WRITE_DATA;
          end if;
          if( RX_LatchEn = '1' )then
            RX_Buffer(conv_integer(RX_BitSel)) <= RX_Serial;
            RX_BitStuff_SR   <= RX_BitStuff_SR(3 downto 0) & RX_Serial;
            RX_BitCntr       <= RX_BitCntr + 1;

            if( and_reduce(RX_BitStuff_SR) = '1' )then
              RX_BitStuff_SR <= (others => '0');
              if( RX_Serial = '0' )then
                RX_BitCntr   <= RX_BitCntr;
                RX_State     <= SKIP_ZERO;
              end if;
            end if;
          end if;

        when SKIP_ZERO =>
          RX_State           <= RCV_DATA;

        when WRITE_DATA =>
          RX_BitCntr         <= (others => '0');
          RX_Valid           <= '1';
          RX_Data            <= RX_Buffer;
          if( RX_Flag_SR = SDLC_Flag )then
            RX_Flag          <= '1';
          end if;
          RX_State           <= RCV_DATA;

        when others => null;
      end case;

      -- If we just shifted in the flag character, and the bit counter isn't
      --  0x0, then our bit counter is out of alignment. Reset it to zero so
      --  that the next word is clocked in correctly.
      if( RX_Flag_SR = SDLC_Flag and RX_BitCntr > 0 )then
         RX_BitCntr          <= (others => '0');
      end if;

      -- If the serial line goes idle (In the marking state for more than 7
      --  bit times), and the FSM isn't already in IDLE, force it to IDLE.
      if( and_reduce(RX_Idle_Cntr) = '1' and RX_State /= IDLE )then
        RX_State             <= IDLE;
      end if;

      -- If the bit clock is no longer valid, soft-reset to the INIT state.
      if( BClk_Okay = '0' )then
        RX_State             <= INIT;
      end if;

    end if;
  end process;

end architecture;