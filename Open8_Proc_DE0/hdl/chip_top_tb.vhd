library ieee;
use ieee.std_logic_1164.all;

library work;
  use work.open8_pkg.all;
  use work.open8_cfg.all;

entity chip_top_tb is
end chip_top_tb;

architecture tb of chip_top_tb is

  constant T : time := 20 ns;
  
  signal clock                      : std_logic;
  signal Locked                     : std_logic;
  signal reset                      : std_logic;
  signal uSec_Tick                  : std_logic;
  signal Address                    : std_logic_vector(OPEN8_ADDR_WIDTH - 1 downto 0);
  signal Wr_En                      : std_logic;
  signal Wr_Data                    : std_logic_vector(OPEN8_DATA_WIDTH - 1 downto 0);
  signal Rd_En                      : std_logic;
  signal GP_Flags                   : std_logic_vector(4 downto 0);
  signal Rd_Data                    : std_logic_vector(OPEN8_DATA_WIDTH - 1 downto 0);
  signal Interrupts                 : std_logic_vector(OPEN8_DATA_WIDTH - 1 downto 0) := x"00";
  
  signal Read_Buses                 : OPEN8_BUS_ARRAY := INIT_READ_BUS;
  signal LEDG                       : std_logic_vector(7 downto 0);
  
begin

  UUT : entity work.chip_top
  port map (
      clock                      => clock,
      Address                    => Address,
      Wr_Data                    => Wr_Data,
      Rd_Data                    => Rd_Data,
      Wr_En                      => Wr_En,
      Interrupts                 => Interrupts,
      GP_Flags                   => GP_Flags,
      uSec_Tick                  => uSec_Tick,
      Rd_En                      => Rd_En,
      reset                      => reset,
      Locked                     => Locked
  );
  
  Open8_Bus.Clock      <= clock;
  Open8_Bus.Reset      <= reset;
  Open8_Bus.uSec_Tick  <= uSec_Tick;
  Open8_Bus.Address    <= Address;
  Open8_Bus.Wr_En      <= Wr_En ;
  Open8_Bus.Wr_Data    <= Wr_Data;
  Open8_Bus.Rd_En      <= Rd_En;
  Open8_Bus.GP_Flags   <= GP_Flags;
  Rd_Data              <= merge_buses(Read_Buses);
  
  U_APP_ROM : entity work.o8_rom_32k
  generic map(
    Address                  => ROM_Address
  )
  port map(
    Open8_Bus                => Open8_Bus,
    Rd_Data                  => Read_Buses(RDB_ROM)
  );
  
  -- NOTE: Comment (or delete) anything you want
  
  -- CUT HERE --

--U_ALU16 : entity work.o8_alu16
--generic map(
--  Address                  => ALU_Address
--)
--port map(
--  Open8_Bus                => Open8_Bus,
--  Rd_Data                  => Read_Buses(RDB_ALU),
--  Interrupt                => Interrupts(INT_ALU)
--);
--
--U_RAM : entity work.o8_ram_4k
--generic map(
--  Address                  => RAM_Address
--)
--port map(
--  Open8_Bus                => Open8_Bus,
--  Rd_Data                  => Read_Buses(RDB_RAM)
--);

  Interrupts(INT_ALU) <= '0';
  
  -- CUT HERE --
  
  U_LED : entity work.o8_register
  generic map(
    Default_Value            => x"00",
    Address                  => LED_Address
  )
  port map(
    Open8_Bus                => Open8_Bus,
    Rd_Data                  => Read_Buses(RDB_LED),
    --
    Register_Out             => LEDG
  );
    
  -- continuous clock
  process 
  begin
    clock <= '0';
    wait for T/2;
    clock <= '1';
    wait for T/2;
  end process;

  -- reset = 1 for first clock cycle and then 0
  Locked <= '0', '1' after T*5;
end tb ;
