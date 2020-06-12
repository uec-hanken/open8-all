library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

library work;
  use work.open8_pkg.all;

entity o8_async_serial_tb is
port(
  Rd_Enable                  : in  std_logic := '0';
  Rd_Data                    : out DATA_TYPE
);
end entity;

architecture tb of o8_async_serial_tb is

  constant Bit_Rate          : real := 1000000.0;
  constant Sys_Freq          : real := 100000000.0;
  constant Reset_Level       : std_logic := '1';

  signal PLL_Locked          : std_logic := '0';
  signal Clock               : std_logic := '0';
  signal Reset               : std_logic := Reset_Level;
  signal Reset_q             : std_logic := Reset_Level;

  constant SER_Address       : ADDRESS_TYPE := x"0000";

  type TEST_STATES is (TEST_START,
                       BYTE0,
                       BYTE1,
                       BYTE2,
                       BYTE3,
                       TEST_END);

  signal Test_State          : TEST_STATES;

  signal Open8_Bus           : OPEN8_BUS_TYPE;

  signal TX_Loop             : std_logic := '0';
  signal CTL_Loop            : std_logic;

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

  Test_FSM : process( Open8_Bus.Clock, Open8_Bus.Reset )
  begin
    if( Open8_Bus.Reset = Reset_Level )then
      Test_State             <= TEST_START;
      Open8_Bus.Address      <= SER_Address;
      Open8_Bus.Wr_Data      <= x"00";
      Open8_Bus.Wr_En        <= '0';
    elsif( rising_edge(Open8_Bus.Clock) )then
      Open8_Bus.Address      <= SER_Address;
      Open8_Bus.Wr_Data      <= x"00";
      Open8_Bus.Wr_En        <= '0';
      case( Test_State )is
        when TEST_START =>
          Test_State         <= BYTE0;

        when BYTE0 =>
          Open8_Bus.Wr_Data  <= x"DE";
          Open8_Bus.Wr_En    <= '1';
          Test_State         <= BYTE1;

        when BYTE1 =>
          Open8_Bus.Wr_Data  <= x"AD";
          Open8_Bus.Wr_En    <= '1';
          Test_State         <= BYTE2;

        when BYTE2 =>
          Open8_Bus.Wr_Data  <= x"BE";
          Open8_Bus.Wr_En    <= '1';
          Test_State         <= BYTE3;

        when BYTE3 =>
          Open8_Bus.Wr_Data  <= x"EF";
          Open8_Bus.Wr_En    <= '1';
          Test_State         <= TEST_END;

        when TEST_END =>

      end case;
    end if;
  end process;

  U_TM_XMIT : entity work.o8_async_serial
  generic map(
    Bit_Rate                 => Bit_Rate,
    Enable_Parity            => TRUE,
    Parity_Odd_Even_n        => '1',
    Clock_Frequency          => Sys_Freq,
    Address                  => SER_Address
  )
  port map(
    Open8_Bus                => Open8_Bus,
    Rd_Data                  => Rd_Data,
    --
    TX_Out                   => TX_Loop,
    CTS_In                   => CTL_Loop,
    RX_In                    => TX_Loop,
    RTS_Out                  => CTL_Loop
  );

end architecture;