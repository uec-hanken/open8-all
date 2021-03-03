library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

library work;
  use work.open8_pkg.all;

entity o8_max7221_test is
port(
  Mx_Data                    : out std_logic;
  Mx_Clock                   : out std_logic;
  MX_LDCSn                   : out std_logic
);
end entity;

architecture tb of o8_max7221_test is

  constant Bit_Rate          : real := 5000000.0;
  constant Sys_Freq          : real := 100000000.0;

  signal PLL_Locked          : std_logic;
  signal Clock               : std_logic := '0';
  signal Reset               : std_logic;
  signal Reset_q             : std_logic;

  constant SER_Address       : ADDRESS_TYPE := x"0000";

  type TEST_STATES is (TEST_START,
                       BYTE0,
                       BYTE1,
                       BYTE2,
                       BYTE3,
                       TEST_END);

  signal Test_State          : TEST_STATES;

  signal Open8_Bus           : OPEN8_BUS_TYPE;

begin

  U_PLL : entity work.clock_sim
  generic map(
    Clock_Frequency         => Sys_Freq
  )
  port map(
    c0                      => Clock,
    locked                  => PLL_Locked
  );

  Reset_Sync: process( PLL_Locked, Clock )
  begin
    if( PLL_Locked = '0' )then
      Reset_q                <= Reset_Level;
      Reset                  <= Reset_Level;
    elsif( rising_edge(Clock) )then
      Reset_q                <= not Reset_Level;
      Reset                  <= Reset_q;
    end if;
  end process;

  Open8_Bus.Clock            <= Clock;
  Open8_Bus.Reset            <= Reset;
  Open8_Bus.uSec_Tick        <= '0';

  Test_FSM : process( Clock, Reset )
  begin
    if( Reset = Reset_Level )then
      Test_State             <= TEST_START;
      Open8_Bus.Address      <= x"0000";
      Open8_Bus.Wr_Data      <= x"00";
      Open8_Bus.Wr_En        <= '0';
    elsif( rising_edge(Clock) )then
      Open8_Bus.Address      <= x"0000";
      Open8_Bus.Wr_Data      <= x"00";
      Open8_Bus.Wr_En        <= '0';
      case( Test_State )is
        when TEST_START =>
          Test_State         <= BYTE0;

        when BYTE0 =>
          Open8_Bus.Address  <= SER_Address + 8;
          Open8_Bus.Wr_Data  <= x"DE";
          Open8_Bus.Wr_En    <= '1';
          Test_State         <= BYTE1;

        when BYTE1 =>
          Open8_Bus.Address  <= SER_Address + 9;
          Open8_Bus.Wr_Data  <= x"AD";
          Open8_Bus.Wr_En    <= '1';
          Test_State         <= BYTE2;

        when BYTE2 =>
          Open8_Bus.Address  <= SER_Address + 10;
          Open8_Bus.Wr_Data  <= x"BE";
          Open8_Bus.Wr_En    <= '1';
          Test_State         <= BYTE3;

        when BYTE3 =>
          Open8_Bus.Address  <= SER_Address + 11;
          Open8_Bus.Wr_Data  <= x"EF";
          Open8_Bus.Wr_En    <= '1';
          Test_State         <= TEST_END;

        when TEST_END =>

      end case;
    end if;
  end process;

  U_DBG_XMIT : entity work.o8_max7221
  generic map(
    Bitclock_Frequency       => Bit_Rate,
    Clock_Frequency          => Sys_Freq,
    Address                  => SER_Address
  )
  port map(
    Open8_Bus                => Open8_Bus,
    --
    Mx_Data                  => Mx_Data,
    Mx_Clock                 => Mx_Clock,
    MX_LDCSn                 => MX_LDCSn
  );

end architecture;