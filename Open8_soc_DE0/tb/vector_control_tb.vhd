library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

library work;
  use work.open8_pkg.all;

entity vector_control_tb is
port(
  Switches                   : in  std_logic_vector(9 downto 0) := (others => '0');
  Pushbutton                 : in  std_logic := '1';
  Bus_Address                : in  ADDRESS_TYPE := x"0000";
  Rd_Enable                  : in  std_logic := '0';
  Rd_Data                    : out DATA_TYPE;
  Interrupt                  : out std_logic
);
end entity;

architecture tb of vector_control_tb is

  constant Button_Level      : std_logic := '0';
  constant Enable_Parity     : boolean := TRUE;
  constant Parity_Odd_Even_n : std_logic := '0';
  constant Bit_Rate          : real := 1000000.0;
  constant Sys_Freq          : real := 100000000.0;

  signal PLL_Locked          : std_logic := '0';
  signal Clock               : std_logic := '0';
  signal Reset_q             : std_logic := Reset_Level;
  signal Reset               : std_logic := Reset_Level;

  constant VEC_Address       : ADDRESS_TYPE := x"1000";

  signal Open8_Bus           : OPEN8_BUS_TYPE;

  signal Serial_Loop         : std_logic;

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

  U_VEC_TX : entity work.vector_tx
  generic map(
    Button_Level             => Button_Level,
    Bit_Rate                 => Bit_Rate,
    Enable_Parity            => Enable_Parity,
    Parity_Odd_Even_n        => Parity_Odd_Even_n,
    Sys_Freq                 => Sys_Freq,
    Reset_Level              => Reset_Level
  )
  port map(
    Clock                    => Clock,
    Reset                    => Reset,
    --
    Switches                 => Switches,
    Pushbutton               => Pushbutton,
    --
    Tx_Out                   => Serial_Loop
  );

  Open8_Bus.Clock            <= Clock;
  Open8_Bus.Reset            <= Reset;
  Open8_Bus.uSec_Tick        <= '0';
  Open8_Bus.Address          <= Bus_Address;
  Open8_Bus.Rd_En            <= Rd_Enable;

  U_VEC_RX : entity work.o8_vector_rx
  generic map(
    Bit_Rate                 => Bit_Rate,
    Enable_Parity            => Enable_Parity,
    Parity_Odd_Even_n        => Parity_Odd_Even_n,
    Clock_Frequency          => Sys_Freq,
    Address                  => VEC_Address
  )
  port map(
    Open8_Bus                => Open8_Bus,
    Rd_Data                  => Rd_Data,
    Interrupt                => Interrupt,
    --
    Rx_In                    => Serial_Loop
  );

end architecture;