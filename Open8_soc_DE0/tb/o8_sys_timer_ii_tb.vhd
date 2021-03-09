library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

library work;
  use work.open8_pkg.all;

entity o8_sys_timer_ii_tb is
port(
  Rd_Data                    : out DATA_TYPE
);
end entity;

architecture tb of o8_sys_timer_ii_tb is

  constant Sys_Freq          : real := 100000000.0;

  signal PLL_Locked          : std_logic := '0';
  signal Clock               : std_logic := '0';
  signal Reset_q             : std_logic := Reset_Level;
  signal Reset               : std_logic := Reset_Level;

  constant TMR_Address       : ADDRESS_TYPE := x"1000";

  type TEST_STATES is (TEST_START,
                       WR_B0,
                       WR_B1,
                       WR_B2,
                       INSTR0,
                       INSTR1,
                       WAI,
                       INSTR2,
                       RD_B0,
                       RD_B1,
                       RD_B2,
                       RD_B3,
                       TEST_END);

  signal Test_State          : TEST_STATES := TEST_START;

  signal Open8_Bus           : OPEN8_BUS_TYPE := INIT_OPEN8_BUS;

  signal uSec_Tick           : std_logic := '0';

  signal Interrupt           : std_logic := '0';

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

  U_TICK : entity work.usec_tick
  generic map(
    Reset_Level              => Reset_Level,
    Sys_Freq                 => Sys_Freq
  )
  port map(
    Clock                    => Clock,
    Reset                    => Reset,
    uSec_Tick                => uSec_Tick
  );

  Open8_Bus.Clock            <= Clock;
  Open8_Bus.Reset            <= Reset;
  Open8_Bus.uSec_Tick        <= uSec_Tick;

  Test_FSM : process( Open8_Bus.Clock, Open8_Bus.Reset )
  begin
    if( Open8_Bus.Reset = Reset_Level )then
      Test_State             <= TEST_START;
      Open8_Bus.Address      <= x"0000";
      Open8_Bus.Wr_Data      <= x"00";
      Open8_Bus.Wr_En        <= '0';
      Open8_Bus.Rd_En        <= '0';
    elsif( rising_edge(Open8_Bus.Clock) )then
      Open8_Bus.Address      <= x"0000";
      Open8_Bus.Wr_Data      <= x"00";
      Open8_Bus.Wr_En        <= '0';
      Open8_Bus.Rd_En        <= '0';
      case( Test_State )is
        when TEST_START =>
          Test_State         <= WR_B0;

        when WR_B0 =>
          Open8_Bus.Address  <= TMR_Address + 0;
          Open8_Bus.Wr_Data  <= x"40";
          Open8_Bus.Wr_En    <= '1';
          Test_State         <= WR_B1;

        when WR_B1 =>
          Open8_Bus.Address  <= TMR_Address + 1;
          Open8_Bus.Wr_Data  <= x"42";
          Open8_Bus.Wr_En    <= '1';
          Test_State         <= WR_B2;

        when WR_B2 =>
          Open8_Bus.Address  <= TMR_Address + 2;
          Open8_Bus.Wr_Data  <= x"0F";
          Open8_Bus.Wr_En    <= '1';
          Test_State         <= INSTR0;

        when INSTR0 =>
          Open8_Bus.Address  <= TMR_Address + 3;
          Open8_Bus.Rd_En    <= '1';
          Test_State         <= INSTR1;

        when INSTR1 =>
          Open8_Bus.Address  <= TMR_Address + 3;
          Open8_Bus.Wr_Data  <= x"C0";
          Open8_Bus.Wr_En    <= '1';
          Test_State         <= WAI;

        when WAI =>
          if( Interrupt = '1' )then
            Test_State       <= INSTR2;
          end if;

        when INSTR2 =>
          Open8_Bus.Address  <= TMR_Address + 3;
          Open8_Bus.Wr_Data  <= x"00";
          Open8_Bus.Wr_En    <= '1';
          Test_State         <= RD_B0;

        when RD_B0 =>
          Open8_Bus.Address  <= TMR_Address + 0;
          Open8_Bus.Rd_En    <= '1';
          Test_State         <= RD_B1;

        when RD_B1 =>
          Open8_Bus.Address  <= TMR_Address + 1;
          Open8_Bus.Rd_En    <= '1';
          Test_State         <= RD_B2;

        when RD_B2 =>
          Open8_Bus.Address  <= TMR_Address + 2;
          Open8_Bus.Rd_En    <= '1';
          Test_State         <= RD_B3;

        when RD_B3 =>
          Open8_Bus.Address  <= TMR_Address + 3;
          Open8_Bus.Rd_En    <= '1';
          Test_State         <= TEST_END;

        when TEST_END =>

      end case;
    end if;
  end process;

  U_TMR : entity work.o8_sys_timer_ii
  generic map(
    Address                  => TMR_Address
  )
  port map(
    Open8_Bus                => Open8_Bus,
    Rd_Data                  => Rd_Data,
    --
    Interrupt                => Interrupt
  );

end architecture;