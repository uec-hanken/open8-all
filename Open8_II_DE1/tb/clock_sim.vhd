library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity clock_sim is
generic(
  Clock_Frequency       : real
);
port(
  c0                    : out std_logic;
  locked                : out std_logic
);
end entity;

architecture tb of clock_sim is

  constant Half_Prd     : time := (0.5 / Clock_Frequency) * 1000.0 ms;
  constant LockDelay    : time := Half_Prd * 10.0;

  signal Int_Clock      : std_logic := '0';

begin

  Clock_Gen: process
  begin
    Int_Clock           <= not Int_Clock;
    wait for Half_Prd;
  end process;

  c0                    <= Int_Clock;

  Locked_Gen: process
  begin
    locked              <= '0';
    wait for LockDelay;
    locked              <= '1';
    wait;
  end process;

end architecture;