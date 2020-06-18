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
-- VHDL Units :  o8_rtc
-- Description:  Provides automatically updated registers that maintain the
--            :   time of day. Keeps track of the day of week, hours, minutes
--            :   seconds, and tenths of a second in packed BCD format.
--            :  Module is doubled buffered to ensure time consistency during
--            :   accesses.
--            :  Also provides an 8-bit programmable periodic interrupt timer
--            :   with 1uS resolution, a 10uS fixed interrupt, as well as a
--            :   1 uSec tick (1 clock wide) for external use.
--
-- Register Map:
-- Offset  Bitfield Description                        Read/Write
--   0x0   AAAAAAAA Periodic Interval Timer in uS      (RW)
--   0x1   BBBBAAAA Tenths  (0x00 - 0x99)              (RW)
--   0x2   -BBBAAAA Seconds (0x00 - 0x59)              (RW)
--   0x3   -BBBAAAA Minutes (0x00 - 0x59)              (RW)
--   0x4   --BBAAAA Hours   (0x00 - 0x23)              (RW)
--   0x5   -----AAA Day of Week (0x00 - 0x06)          (RW)
--   0x6   -------- Update RTC regs from Shadow Regs   (WO)
--   0x7   A------- Update Shadow Regs from RTC regs   (RW)
--                  A = Update is Busy
--
-- Revision History
-- Author          Date     Change
------------------ -------- ---------------------------------------------------
-- Seth Henry      04/16/20 Revision block added

library ieee;
use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.std_logic_arith.all;
  use ieee.std_logic_misc.all;

library work;
  use work.open8_pkg.all;

entity o8_rtc is
generic(
  Address                    : ADDRESS_TYPE
);
port(
  Open8_Bus                  : in  OPEN8_BUS_TYPE;
  Rd_Data                    : out DATA_TYPE;
  --
  Interrupt_PIT              : out std_logic;
  Interrupt_RTC              : out std_logic
);
end entity;

architecture behave of o8_rtc is

  alias Clock                is Open8_Bus.Clock;
  alias Reset                is Open8_Bus.Reset;
  alias uSec_Tick            is Open8_Bus.uSec_Tick;

  constant User_Addr         : std_logic_vector(15 downto 3)
                               := Address(15 downto 3);
  alias  Comp_Addr           is Open8_Bus.Address(15 downto 3);
  signal Addr_Match          : std_logic;

  alias  Reg_Addr            is Open8_Bus.Address(2 downto 0);
  signal Reg_Addr_q          : std_logic_vector(2 downto 0);

  signal Wr_En               : std_logic;
  signal Wr_Data_q           : DATA_TYPE;
  signal Rd_En               : std_logic;

  type PIT_TYPE is record
    timer_cnt                : DATA_TYPE;
    timer_ro                 : std_logic;
  end record;

  signal pit                 : PIT_TYPE;

  type RTC_TYPE is record
    frac                     : std_logic_vector(15 downto 0);
    frac_ro                  : std_logic;

    tens_l                   : std_logic_vector(3 downto 0);
    tens_l_ro                : std_logic;

    tens_u                   : std_logic_vector(3 downto 0);
    tens_u_ro                : std_logic;

    secs_l                   : std_logic_vector(3 downto 0);
    secs_l_ro                : std_logic;

    secs_u                   : std_logic_vector(3 downto 0);
    secs_u_ro                : std_logic;

    mins_l                   : std_logic_vector(3 downto 0);
    mins_l_ro                : std_logic;

    mins_u                   : std_logic_vector(3 downto 0);
    mins_u_ro                : std_logic;

    hours_l                  : std_logic_vector(3 downto 0);
    hours_l_ro               : std_logic;

    hours_u                  : std_logic_vector(3 downto 0);
    hours_u_ro               : std_logic;

    dow                      : std_logic_vector(2 downto 0);
  end record;

  constant DECISEC           : std_logic_vector(15 downto 0) :=
                                conv_std_logic_vector(10000,16);

  signal rtc                 : RTC_TYPE;

  signal interval            : DATA_TYPE;
  signal update_interval     : std_logic;

  signal shd_tens            : DATA_TYPE;
  signal shd_secs            : DATA_TYPE;
  signal shd_mins            : DATA_TYPE;
  signal shd_hours           : DATA_TYPE;
  signal shd_dow             : DATA_TYPE;

  signal update_rtc          : std_logic;
  signal update_shd          : std_logic;
  signal update_ctmr         : std_logic_vector(3 downto 0);

begin

  Addr_Match                 <= '1' when Comp_Addr = User_Addr else '0';

  Interrupt_PIT              <= pit.timer_ro;
  Interrupt_RTC              <= rtc.frac_ro;

  io_reg: process( Clock, Reset )
  begin
    if( Reset = Reset_Level )then
      pit.timer_cnt          <= x"00";
      pit.timer_ro           <= '0';

      rtc.frac               <= DECISEC;
      rtc.frac_ro            <= '0';

      rtc.tens_l             <= (others => '0');
      rtc.tens_l_ro          <= '0';

      rtc.tens_u             <= (others => '0');
      rtc.tens_u_ro          <= '0';

      rtc.secs_l             <= (others => '0');
      rtc.secs_l_ro          <= '0';

      rtc.secs_u             <= (others => '0');
      rtc.secs_u_ro          <= '0';

      rtc.mins_l             <= (others => '0');
      rtc.mins_l_ro          <= '0';

      rtc.mins_u             <= (others => '0');
      rtc.mins_u_ro          <= '0';

      rtc.hours_l            <= (others => '0');
      rtc.hours_l_ro         <= '0';

      rtc.hours_u            <= (others => '0');
      rtc.hours_u_ro         <= '0';

      rtc.dow                <= (others => '0');

      shd_tens               <= (others => '0');
      shd_secs               <= (others => '0');
      shd_mins               <= (others => '0');
      shd_hours              <= (others => '0');
      shd_dow                <= (others => '0');

      update_rtc             <= '0';
      update_shd             <= '0';
      update_ctmr            <= (others => '0');

      interval               <= x"00";
      update_interval        <= '0';

      Wr_Data_q              <= (others => '0');
      Reg_Addr_q             <= (others => '0');
      Wr_En                  <= '0';
      Rd_En                  <= '0';
      Rd_Data                <= OPEN8_NULLBUS;

    elsif( rising_edge( Clock ) )then

      -- Periodic Interval Timer
      pit.timer_cnt          <= pit.timer_cnt - uSec_Tick;
      pit.timer_ro           <= '0';
      if( update_interval = '1' )then
        pit.timer_cnt        <= interval;
      elsif( or_reduce(pit.timer_cnt) = '0' )then
        pit.timer_cnt        <= interval;
        pit.timer_ro         <= or_reduce(interval);
      end if;

      -- Fractional decisecond counter - cycles every 10k microseconds
      rtc.frac               <= rtc.frac - uSec_Tick;
      rtc.frac_ro            <= '0';
      if( or_reduce(rtc.frac) = '0' or update_rtc = '1' )then
        rtc.frac             <= DECISEC;
        rtc.frac_ro          <= not update_rtc;
      end if;

      -- Decisecond counter (lower)
      rtc.tens_l             <= rtc.tens_l + rtc.frac_ro;
      rtc.tens_l_ro          <= '0';
      if( update_rtc = '1' )then
        rtc.tens_l           <= shd_tens(3 downto 0);
      elsif( rtc.tens_l > x"9")then
        rtc.tens_l           <= (others => '0');
        rtc.tens_l_ro        <= '1';
      end if;

      -- Decisecond counter (upper)
      rtc.tens_u             <= rtc.tens_u + rtc.tens_l_ro;
      rtc.tens_u_ro          <= '0';
      if( update_rtc = '1' )then
        rtc.tens_u           <= shd_tens(7 downto 4);
      elsif( rtc.tens_u > x"9")then
        rtc.tens_u           <= (others => '0');
        rtc.tens_u_ro        <= '1';
      end if;

      -- Second counter (lower)
      rtc.secs_l             <= rtc.secs_l + rtc.tens_u_ro;
      rtc.secs_l_ro          <= '0';
      if( update_rtc = '1' )then
        rtc.secs_l           <= shd_secs(3 downto 0);
      elsif( rtc.secs_l > x"9")then
        rtc.secs_l           <= (others => '0');
        rtc.secs_l_ro        <= '1';
      end if;

      -- Second counter (upper)
      rtc.secs_u             <= rtc.secs_u + rtc.secs_l_ro;
      rtc.secs_u_ro          <= '0';
      if( update_rtc = '1' )then
        rtc.secs_u           <= shd_secs(7 downto 4);
      elsif( rtc.secs_u > x"5")then
        rtc.secs_u           <= (others => '0');
        rtc.secs_u_ro        <= '1';
      end if;

      -- Minutes counter (lower)
      rtc.mins_l             <= rtc.mins_l + rtc.secs_u_ro;
      rtc.mins_l_ro          <= '0';
      if( update_rtc = '1' )then
        rtc.mins_l           <= shd_mins(3 downto 0);
      elsif( rtc.mins_l > x"9")then
        rtc.mins_l           <= (others => '0');
        rtc.mins_l_ro        <= '1';
      end if;

      -- Minutes counter (upper)
      rtc.mins_u             <= rtc.mins_u + rtc.mins_l_ro;
      rtc.mins_u_ro          <= '0';
      if( update_rtc = '1' )then
        rtc.mins_u           <= shd_mins(7 downto 4);
      elsif( rtc.mins_u > x"5")then
        rtc.mins_u           <= (others => '0');
        rtc.mins_u_ro        <= '1';
      end if;

      -- Hour counter (lower)
      rtc.hours_l            <= rtc.hours_l + rtc.mins_u_ro;
      rtc.hours_l_ro         <= '0';
      if( update_rtc = '1' )then
        rtc.hours_l          <= shd_hours(3 downto 0);
      elsif( rtc.hours_l > x"9")then
        rtc.hours_l          <= (others => '0');
        rtc.hours_l_ro       <= '1';
      end if;

      -- Hour counter (upper)
      rtc.hours_u            <= rtc.hours_u + rtc.hours_l_ro;
      if( update_rtc = '1' )then
        rtc.hours_u          <= shd_hours(7 downto 4);
      end if;

      rtc.hours_u_ro         <= '0';
      if( rtc.hours_u >= x"2" and rtc.hours_l > x"3" )then
        rtc.hours_l          <= (others => '0');
        rtc.hours_u          <= (others => '0');
        rtc.hours_u_ro       <= '1';
      end if;

      -- Day of Week counter
      rtc.dow                <= rtc.dow + rtc.hours_u_ro;
      if( update_rtc = '1' )then
        rtc.dow              <= shd_dow(2 downto 0);
      elsif( rtc.dow = x"07")then
        rtc.dow              <= (others => '0');
      end if;

      -- Copy the RTC registers to the shadow registers when the coherency
      --  timer is zero (RTC registers are static)
      if( update_shd = '1' and or_reduce(update_ctmr) = '0' )then
        shd_tens             <= rtc.tens_u & rtc.tens_l;
        shd_secs             <= rtc.secs_u & rtc.secs_l;
        shd_mins             <= rtc.mins_u & rtc.mins_l;
        shd_hours            <= rtc.hours_u & rtc.hours_l;
        shd_dow              <= "00000" & rtc.dow;
        update_shd           <= '0';
      end if;

      update_interval        <= '0';

      Reg_Addr_q             <= Reg_Addr;
      Wr_Data_q              <= Open8_Bus.Wr_Data;

      Wr_En                  <= Addr_Match and Open8_Bus.Wr_En;
      update_rtc             <= '0';
      if( Wr_En = '1' )then
        case( Reg_Addr_q )is
          when "000" =>
            interval         <= Wr_Data_q;
            update_interval  <= '1';

          when "001" =>
            shd_tens         <= Wr_Data_q;

          when "010" =>
            shd_secs         <= Wr_Data_q;

          when "011" =>
            shd_mins         <= Wr_Data_q;

          when "100" =>
            shd_hours        <= Wr_Data_q;

          when "101" =>
            shd_dow          <= Wr_Data_q;

          when "110" =>
            update_rtc       <= '1';

          when "111" =>
            update_shd  <= '1';

          when others => null;
        end case;
      end if;

      -- Coherency timer - ensures that the shadow registers are updated with
      --  valid time data by delaying updates until the rtc registers have
      --  finished cascading.
      update_ctmr            <= update_ctmr - or_reduce(update_ctmr);
      if( rtc.frac_ro = '1' )then
        update_ctmr          <= (others => '1');
      end if;

      Rd_Data                <= OPEN8_NULLBUS;
      Rd_En                  <= Addr_Match and Open8_Bus.Rd_En;
      if( Rd_En = '1' )then
        case( Reg_Addr_q )is
          when "000" =>
            Rd_Data          <= interval;
          when "001" =>
            Rd_Data          <= shd_tens;
          when "010" =>
            Rd_Data          <= shd_secs;
          when "011" =>
            Rd_Data          <= shd_mins;
          when "100" =>
            Rd_Data          <= shd_hours;
          when "101" =>
            Rd_Data          <= shd_dow;
          when "110" =>
            null;
          when "111" =>
            Rd_Data          <= update_shd & "0000000";
          when others => null;
        end case;
      end if;

    end if;
  end process;

end architecture;