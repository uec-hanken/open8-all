-- Copyright (c)2011, 2019, 2020 Jeremy Seth Henry
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
-- VHDL Units :  o8_epoch_timer_ii
-- Description:  Provides a 32-bit, 1uS resolution elapsed timer with
--            :   alarm and interrupt for the Open8 CPU.
--
-- Notes      :  Requires an externally provided uSec tick input - one clock
--            :   per microsecond.
--
-- Register Map:
-- Offset  Bitfield Description                        Read/Write
--   0x0   AAAAAAAA B0 of Buffered Setpoint (W) or Current Setpoint(R)
--   0x1   AAAAAAAA B1 of Buffered Setpoint (W) or Current Setpoint(R)
--   0x2   AAAAAAAA B2 of Buffered Setpoint (W) or Current Setpoint(R)
--   0x3   AAAAAAAA B3 of Buffered Setpoint (W) or Current Setpoint(R)
--   0x4   AAAAAAAA B0 of Current Epoch Time(RO)
--   0x5   AAAAAAAA B1 of Current Epoch Time(RO)
--   0x6   AAAAAAAA B2 of Current Epoch Time(RO)
--   0x7   AAAAAAAA B3 of Current Epoch Time(RO)
--                  Note that any write to 0x04,0x05, 0x06, or 0x07 will copy
--                   the current epoch time to a readable output buffer
--   0x8   xxxxxxxx (not used - returns 0x00)
--   0x9   xxxxxxxx (not used - returns 0x00)
--   0xA   xxxxxxxx (not used - returns 0x00)
--   0xB   xxxxxxxx (not used - returns 0x00)
--   0xC   xxxxxxxx (not used - returns 0x00)
--   0xD   xxxxxxxx (not used - returns 0x00)
--   0xE   -------- Epoch Time Latch/Clear Control Register
--                  Any write to 0xE will clear/reset the all timer regs
--   0xF   BA------ Status of buffer/alarm (1 = pending, 0 = current)
--                  A = Pending status (R)
--                  B = Alarm status (R)
--                  Note that any write will update the internal set point
--                  and clear the alarm
--
-- Revision History
-- Author          Date     Change
------------------ -------- ---------------------------------------------------
-- Seth Henry      04/15/20 Created from o8_epoch_timer due to requirement
--                           change.
-- Seth Henry      04/16/20 Modifiefd to make use of Open8 bus record
-- Seth Henry      05/18/20 Added write qualification input

library ieee;
use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.std_logic_arith.all;
  use ieee.std_logic_misc.all;

library work;
  use work.open8_pkg.all;

entity o8_epoch_timer_ii is
generic(
  Address                    : ADDRESS_TYPE
);
port(
  Open8_Bus                  : in  OPEN8_BUS_TYPE;
  Write_Qual                 : in  std_logic := '1';
  Rd_Data                    : out DATA_TYPE;
  Interrupt                  : out std_logic
);
end entity;

architecture behave of o8_epoch_timer_ii is

  alias Clock                is Open8_Bus.Clock;
  alias Reset                is Open8_Bus.Reset;
  alias uSec_Tick            is Open8_Bus.uSec_Tick;

  constant User_Addr         : std_logic_vector(15 downto 4)
                               := Address(15 downto 4);

  alias  Comp_Addr           is Open8_Bus.Address(15 downto 4);
  signal Addr_Match          : std_logic := '0';

  alias  Reg_Sel_d           is Open8_Bus.Address(3 downto 0);
  signal Reg_Sel_q           : std_logic_vector(3 downto 0) := "0000";
  signal Wr_En_d             : std_logic := '0';
  signal Wr_En_q             : std_logic := '0';
  alias  Wr_Data_d           is Open8_Bus.Wr_Data;
  signal Wr_Data_q           : DATA_TYPE := x"00";
  signal Rd_En_d             : std_logic := '0';
  signal Rd_En_q             : std_logic := '0';

  signal setpt_buffer        : std_logic_vector(31 downto 0) :=
                                (others => '0');

  alias  setpt_buffer_b0     is setpt_buffer( 7 downto  0);
  alias  setpt_buffer_b1     is setpt_buffer(15 downto  8);
  alias  setpt_buffer_b2     is setpt_buffer(23 downto 16);
  alias  setpt_buffer_b3     is setpt_buffer(31 downto 24);

  signal buffer_pending      : std_logic := '0';
  signal buffer_update       : std_logic := '0';

  signal epoch_buffer        : std_logic_vector(31 downto 0) :=
                                (others => '0');

  alias  epoch_buffer_b0     is epoch_buffer( 7 downto  0);
  alias  epoch_buffer_b1     is epoch_buffer(15 downto  8);
  alias  epoch_buffer_b2     is epoch_buffer(23 downto 16);
  alias  epoch_buffer_b3     is epoch_buffer(31 downto 24);

  signal capture_epoch       : std_logic := '0';

  signal timer_clear         : std_logic := '0';

  signal epoch_tmr           : std_logic_vector(31 downto 0) :=
                                (others => '0');

  alias  epoch_tmrcmp        is epoch_tmr(31 downto 2);
  signal epoch_setpt         : std_logic_vector(31 downto 0) :=
                                (others => '0');

  alias  epoch_setpt_b0      is epoch_setpt( 7 downto  0);
  alias  epoch_setpt_b1      is epoch_setpt(15 downto  8);
  alias  epoch_setpt_b2      is epoch_setpt(23 downto 16);
  alias  epoch_setpt_b3      is epoch_setpt(31 downto 24);

  signal epoch_alarm         : std_logic := '0';
  signal epoch_alarm_q       : std_logic := '0';

begin

  Addr_Match                 <= '1' when Comp_Addr = User_Addr else '0';
  Wr_En_d                    <= Addr_Match and Open8_Bus.Wr_En;
  Rd_En_d                    <= Addr_Match and Open8_Bus.Rd_En;

  io_reg: process( Clock, Reset )
  begin
    if( Reset = Reset_Level )then
      Reg_Sel_q              <= "0000";
      Wr_En_q                <= '0';
      Wr_Data_q              <= x"00";
      Rd_En_q                <= '0';
      Rd_Data                <= OPEN8_NULLBUS;

      setpt_buffer           <= (others => '0');
      buffer_pending         <= '0';
      buffer_update          <= '0';
      capture_epoch          <= '0';
      timer_clear            <= '0';
    elsif( rising_edge( Clock ) )then

      Reg_Sel_q              <= Reg_Sel_d;

      Wr_En_q                <= Wr_En_d;
      Wr_Data_q              <= Wr_Data_d;

      buffer_update          <= '0';
      timer_clear            <= '0';
      capture_epoch          <= '0';

      if( Wr_En_q = '1' and Write_Qual = '1' )then
        case( Reg_Sel_q )is
          when x"0" =>
            setpt_buffer_b0  <= Wr_Data_q;
            buffer_pending   <= '1';

          when x"1" =>
            setpt_buffer_b1  <= Wr_Data_q;
            buffer_pending   <= '1';

          when x"2" =>
            setpt_buffer_b2  <= Wr_Data_q;
            buffer_pending   <= '1';

          when x"3" =>
            setpt_buffer_b3  <= Wr_Data_q;
            buffer_pending   <= '1';

          when x"4" | x"5" | x"6" | x"7" =>
            capture_epoch    <= '1';

          when x"E" =>
            timer_clear      <= '1';

          when x"F" =>
            buffer_update    <= '1';
            buffer_pending   <= '0';

          when others => null;
        end case;
      end if;

      Rd_Data                <= OPEN8_NULLBUS;
      Rd_En_q                <= Rd_En_d;
      if( Rd_En_q = '1' )then
        case( Reg_Sel_q )is
          when x"0" =>
            Rd_Data          <= epoch_setpt_b0;
          when x"1" =>
            Rd_Data          <= epoch_setpt_b1;
          when x"2" =>
            Rd_Data          <= epoch_setpt_b2;
          when x"3" =>
            Rd_Data          <= epoch_setpt_b3;
          when x"4" =>
            Rd_Data          <= epoch_buffer_b0;
          when x"5" =>
            Rd_Data          <= epoch_buffer_b1;
          when x"6" =>
            Rd_Data          <= epoch_buffer_b2;
          when x"7" =>
            Rd_Data          <= epoch_buffer_b3;
          when x"F" =>
            Rd_Data          <= epoch_alarm & buffer_pending & "000000";
          when others => null;
        end case;
      end if;
    end if;
  end process;

  timer_proc: process( Clock, Reset )
  begin
    if( Reset = Reset_Level )then
      epoch_setpt            <= (others => '0');
      epoch_buffer           <= (others => '0');
      epoch_tmr              <= (others => '0');
      epoch_alarm            <= '0';
      epoch_alarm_q          <= '0';
      Interrupt              <= '0';

    elsif( rising_edge(Clock) )then

      epoch_tmr              <= epoch_tmr + uSec_Tick;

      if( epoch_tmr > epoch_setpt )then
        epoch_alarm          <= or_reduce(epoch_setpt);
      end if;

      if( buffer_update = '1' )then
        epoch_setpt          <= setpt_buffer;
        epoch_alarm          <= '0';
      end if;

      if( timer_clear = '1' )then
        epoch_setpt          <= (others => '0');
        epoch_tmr            <= (others => '0');
        epoch_alarm          <= '0';
      end if;

      epoch_alarm_q          <= epoch_alarm;
      Interrupt              <= epoch_alarm and not epoch_alarm_q;

      if( capture_epoch = '1' )then
        epoch_buffer         <= epoch_tmr;
      end if;

    end if;
  end process;

end architecture;
