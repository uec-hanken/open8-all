library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.open8_pkg.all;
  use work.open8_cfg.all;

entity open8_soc is
port(
  -- Master oscillator
  clk                : in  std_logic;
  -- Push buttons
  reset                      : in  std_logic;
  btn0                       : in  std_logic;
  -- LED outputs
  leds                       : out std_logic_vector(7 downto 0);
  --LEDS gp debug
  LED_R0                     : out  std_logic;
  LED_R1                     : out  std_logic;
  LED_R2                     : out  std_logic;
  LED_R3                     : out  std_logic;
  DUT_Trig                   : out  std_logic;
  -- Configuration Switches
  dipsw                      : in   std_logic_vector(3 downto 0);
  i_sck                      : in   std_logic;
  i_copi                     : in   std_logic;
  o_cipo                     : out  std_logic;
  i_cs                       : in   std_logic
);
end entity;

architecture behave of open8_soc is

  -- Internal signals

  signal CPU_Clock           : std_logic := '0';
  signal CPU_PLL_Locked      : std_logic := '0';
  signal CPU_RESET      : std_logic := '0';

  signal Open8_Bus           : OPEN8_BUS_TYPE  := INIT_OPEN8_BUS;
  signal Open8_Bus_cpu       : OPEN8_BUS_TYPE  := INIT_OPEN8_BUS;
  signal Open8_Bus_spi       : OPEN8_BUS_TYPE  := INIT_OPEN8_BUS;
  signal Read_Buses          : OPEN8_BUS_ARRAY := INIT_READ_BUS;
  signal Interrupts          : DATA_TYPE    := x"00";

  signal DipSwitches         : DATA_TYPE    := x"00";
  signal Button_In           : DATA_TYPE    := x"FF";

  --component from verilog
   component spi_prog
  port(
    i_sck: in  std_logic;
    i_copi: in  std_logic;
    o_cipo: out  std_logic;
    i_cs: in  std_logic;
    clk: in  std_logic;
    o_Address: out  std_logic_vector(16 - 1 downto 0);
    o_Wr_Data: out  std_logic_vector(8 - 1 downto 0);
    o_Wr_En: out  std_logic;
    o_Rd_En: out  std_logic;
    i_Rd_Data: in  std_logic_vector(8 - 1 downto 0);
    wb_rst: in  std_logic;
    cpu_reset: out  std_logic;
	 system_reset: out  std_logic
  );
  end component; 
  
begin

  U_SPI_prog : spi_prog
  port map(
    i_sck=> i_sck,
    i_copi=>i_copi,
    o_cipo=>o_cipo,
    i_cs=>i_cs,
    clk=>clk,
    o_Address=>Open8_Bus_spi.Address,
    o_Wr_Data=>Open8_Bus_spi.Wr_Data,
    o_Wr_En=>Open8_Bus_spi.Wr_En,
    o_Rd_En=>Open8_Bus_spi.Rd_En,
    i_Rd_Data=> merge_buses(Read_Buses),
    wb_rst=> not CPU_PLL_Locked,
    cpu_reset=>CPU_RESET,
	 system_reset =>Open8_Bus_spi.Reset
  );

  Open8_Bus <= Open8_Bus_cpu when CPU_RESET = '0' else Open8_Bus_spi;
  Open8_Bus_spi.uSec_Tick <= Open8_Bus_cpu.uSec_Tick;
  Open8_Bus_spi.Clock <= clk;
  Open8_Bus_spi.GP_Flags <= Open8_Bus_cpu.GP_Flags;
  
   CPU_PLL_Locked <= reset;
	
  U_CPU : entity work.o8_cpu
  generic map(
    Program_Start_Addr       => ROM_Address,
    ISR_Start_Addr           => ISR_Start_Addr,
    Stack_Start_Addr         => Stack_Start_Addr,
    Allow_Stack_Address_Move => Allow_Stack_Address_Move,
    Stack_Xfer_Flag          => Stack_Xfer_Flag,
    Enable_Auto_Increment    => Enable_Auto_Increment,
    BRK_Implements_WAI       => BRK_Implements_WAI,
    Enable_NMI               => Enable_NMI,
    Sequential_Interrupts    => Sequential_Interrupts,
    RTI_Ignores_GP_Flags     => RTI_Ignores_GP_Flags,
    Default_Interrupt_Mask   => Default_Int_Mask,
    Clock_Frequency          => Clock_Frequency
  )
  port map(
    Clock                    => clk,
    PLL_Locked               => CPU_PLL_Locked and (not CPU_RESET),
    Open8_Bus                => Open8_Bus_cpu,
    Rd_Data                  => merge_buses(Read_Buses),
    Interrupts               => Interrupts
  );

  LED_R0                     <= Open8_Bus.GP_Flags(EXT_GP7);
  LED_R1                     <= Open8_Bus.GP_Flags(EXT_GP6);
  LED_R2                     <= Open8_Bus.GP_Flags(EXT_GP5);
  LED_R3                     <= Open8_Bus.GP_Flags(EXT_GP4);

  DUT_Trig                    <= Open8_Bus.GP_Flags(EXT_GP5);

  U_RAM : entity work.o8_ram_4k
  generic map(
    Address                  => RAM_Address
  )
  port map(
    Open8_Bus                => Open8_Bus,
    Rd_Data                  => Read_Buses(RDB_RAM)
  );

  U_APP_ROM : entity work.o8_rom_32k
  generic map(
    Address                  => ROM_Address
  )
  port map(
    Open8_Bus                => Open8_Bus,
    Rd_Data                  => Read_Buses(RDB_ROM)
  );

  U_LED : entity work.o8_register
  generic map(
    Default_Value            => x"00",
    Address                  => LED_Address
  )
  port map(
    Open8_Bus                => Open8_Bus,
    Rd_Data                  => Read_Buses(RDB_LED),
    --
    Register_Out             => LEDS
  );

  U_DIPSW : entity work.o8_gpin
  generic map(
    Address                  => DSW_Address
  )
  port map(
    Open8_Bus                => Open8_Bus,
    Rd_Data                  => Read_Buses(RDB_DSW),
    --
    GPIN                     => DipSwitches
  );

  DipSwitches                <= "0000" & DIPSW;

  U_BTN : entity work.o8_btn_int
  generic map(
    Num_Buttons              => 1,
    Button_Level             => '0',
    Address                  => BTN_Address
  )
  port map(
    Open8_Bus                => Open8_Bus,
    Rd_Data                  => Read_Buses(RDB_BTN),
    Interrupt                => Interrupts(INT_BTN),
    --
    Button_In                => Button_In
  );

  Button_In(0)               <= btn0;
  Button_in(7 downto 1)      <= (others => '0');
  
end architecture;