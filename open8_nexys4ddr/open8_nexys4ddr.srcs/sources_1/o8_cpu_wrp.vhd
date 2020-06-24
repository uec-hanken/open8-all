
library ieee;
  use ieee.std_logic_1164.all;

library work;
  use work.open8_pkg.all;

entity o8_cpu_wrp is
  
  port(
    CLOCK                    : IN  STD_LOGIC;
    PLL_LOCKED               : IN  STD_LOGIC;
    HALT_REQ                 : IN  STD_LOGIC;
    HALT_ACK                 : OUT STD_LOGIC;
    OPEN8_BUS_CLOCK          : OUT STD_LOGIC;
    OPEN8_BUS_RESET          : OUT STD_LOGIC;
    OPEN8_BUS_USEC_TICK      : OUT STD_LOGIC;
    OPEN8_BUS_ADDRESS        : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    OPEN8_BUS_WR_EN          : OUT STD_LOGIC;
    OPEN8_BUS_WR_DATA        : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    OPEN8_BUS_RD_EN          : OUT STD_LOGIC;
    OPEN8_BUS_GP_FLAGS       : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
    RD_DATA                  : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
    INTERRUPTS               : IN  STD_LOGIC_VECTOR(7 DOWNTO 0)
);
end entity;

architecture behave of o8_cpu_wrp is

  signal OPEN8_BUS : OPEN8_BUS_TYPE;

begin

  U_CPU : entity work.o8_cpu_wrp
  port map(
    Clock                    => CLOCK,
    PLL_Locked               => PLL_LOCKED,
    Halt_Req                 => HALT_REQ,
    Halt_Ack                 => HALT_ACK,
    Open8_Bus                => OPEN8_BUS,
    Rd_Data                  => RD_DATA,
    Interrupts               => INTERRUPTS
  );
  
  OPEN8_BUS_CLOCK          <= OPEN8_BUS.Clock;
  OPEN8_BUS_RESET          <= OPEN8_BUS.Reset;
  OPEN8_BUS_USEC_TICK      <= OPEN8_BUS.uSec_Tick;
  OPEN8_BUS_ADDRESS        <= OPEN8_BUS.Address;
  OPEN8_BUS_WR_EN          <= OPEN8_BUS.Wr_En;
  OPEN8_BUS_WR_DATA        <= OPEN8_BUS.Wr_Data;
  OPEN8_BUS_RD_EN          <= OPEN8_BUS.Rd_En;
  OPEN8_BUS_GP_FLAGS       <= OPEN8_BUS.GP_Flags;

end architecture;
