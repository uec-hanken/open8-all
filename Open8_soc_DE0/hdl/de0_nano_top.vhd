-- VHDL units : de0_nano_top
-- Description: Connects all of the components to form a test-bed computer
--
-- Revision History
-- Author          Date     Change
------------------ -------- ---------------------------------------------------
-- Seth Henry      04/16/20 Version block added

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.open8_pkg.all;
  use work.open8_cfg.all;

entity de0_nano_top is
port(
  -- Master oscillator
  Ext_50M_Osc                : in  std_logic;
  -- Push buttons
  KEY0                       : in  std_logic;
  KEY1                       : in  std_logic;
  -- LED outputs
  LEDS                       : out std_logic_vector(7 downto 0);
  -- Configuration Switches
  DIPSW                      : in  std_logic_vector(3 downto 0);
  -- DRAM
  DRAM_ADDR                  : out std_logic_vector(12 downto 0);
  DRAM_DQ                    : inout std_logic_vector(15 downto 0);
  DRAM_BANK                  : out std_logic_vector(1 downto 0);
  DRAM_DQM                   : out std_logic_vector(1 downto 0);
  DRAM_RAS_N                 : out std_logic;
  DRAM_CAS_N                 : out std_logic;
  DRAM_CKE                   : out std_logic;
  DRAM_CLK                   : out std_logic;
  DRAM_WE_N                  : out std_logic;
  DRAM_CS_N                  : out std_logic;
  -- I2C PROM
  I2C_SCLK                   : out std_logic;
  I2C_SDAT                   : inout std_logic;
  -- Accelerometer
  GSENSOR_INT                : in  std_logic;
  GSENSOR_CSN                : out std_logic;
  -- ADC
  ADC_CS_N                   : out std_logic;
  ADC_SADDR                  : out std_logic;
  ADC_SDATA                  : in  std_logic;
  ADC_SCLK                   : out std_logic;
  -- GPINs (input only)
  GPIN0                      : in  std_logic_vector(1 downto 0);
  GPIN1                      : in  std_logic_vector(1 downto 0);
  GPIN2                      : in  std_logic_vector(2 downto 0);
  -- GPIO
  GPIO0                      : inout std_logic_vector(33 downto 0);
  GPIO1                      : inout std_logic_vector(33 downto 0);
  GPIO2                      : inout std_logic_vector(12 downto 0)
);
end entity;

architecture behave of de0_nano_top is

  -- I/O mapping aliases

  -- Clock & Reset
  alias  CPU_PLL_Asyn_Reset  is KEY0;
  alias  CPU_PLL_Clock       is Ext_50M_Osc;

  -- LED Paddleboard
  alias  LED_R0              is GPIO1(0);
  alias  LED_R1              is GPIO1(1);
  alias  LED_R2              is GPIO1(2);
  alias  LED_R3              is GPIO1(3);

  -- SDLC Serial Interface       (NANO)        (DEVEL)
  alias  SDLC_In             is GPIN0(0);   -- DIO0 / IO_39
  alias  SDLC_MClk           is GPIO0(1);   -- DIO1 / IO_32
  alias  SDLC_Out            is GPIO0(0);   -- DIO2 / IO_31

  -- Async Serial Port           (NANO)         (DE0)
  alias  TX_Out              is GPIO1(4);   -- GPIO0_D(0)
  alias  RX_In               is GPIO1(5);   -- GPIO0_D(1)

  -- Trigger Signal              (NANO)         (DE0)
  alias  DUT_Trig            is GPIO1(6);   -- GPIO0_D(2)

  -- Unused I/O to DE0           (NANO)         (DE0)
  alias  DUT_Misc            is GPIO1(7);   -- GPIO0_D(3)

  -- Vector RX (TS Input)        (NANO)        (DE0_SOC)
  alias  Req_Rx              is GPIO1(27);  -- GPIO_0(7)

  -- MAX 7221 SPI Interface      (NANO)        (DE0_SOC)
  alias  Mx_Data             is GPIO1(29);  -- GPIO_0(5)
  alias  Mx_Clock            is GPIO1(31);  -- GPIO_0(3)
  alias  MX_LDCSn            is GPIO1(33);  -- GPIO_0(1)

  -- DECA Board I/O              (NANO)          (DECA)
  alias  DECA_IO0            is GPIO0(11);  -- G_GPIO0(0)
  alias  DECA_IO1            is GPIO0(13);  -- G_GPIO0(2)
  alias  DECA_IO2            is GPIO0(15);  -- G_GPIO0(4)
  alias  DECA_IO3            is GPIO0(17);  -- G_GPIO0(6)
  alias  DECA_IO4            is GPIO0(19);  -- G_GPIO0(8)

  alias  DECA_IO5            is GPIO0(21);  -- G_GPIO0(12)
  alias  DECA_IO6            is GPIO0(25);  -- G_GPIO0(14)
  alias  DECA_IO7            is GPIO0(27);  -- G_GPIO0(16)
  alias  DECA_IO8            is GPIO0(29);  -- G_GPIO0(18)
  alias  DECA_IO9            is GPIO0(31);  -- G_GPIO0(20)
  alias  DECA_IO10           is GPIO0(33);  -- G_GPIO0(22)

  alias  DECA_IO11           is GPIO1(11);  -- G_GPIO0(26)
  alias  DECA_IO12           is GPIO1(13);  -- G_GPIO0(28)
  alias  DECA_IO13           is GPIO1(15);  -- G_GPIO0(30)
  alias  DECA_IO14           is GPIO1(17);  -- G_GPIO0(32)
  alias  DECA_IO15           is GPIO1(19);  -- G_GPIO0(34)
  alias  DECA_IO16           is GPIO1(21);  -- G_GPIO0(36)

  -- Internal signals

  signal CPU_PLL_Reset_q     : std_logic := '0';
  signal CPU_PLL_Reset       : std_logic := '0';

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

begin

  CPU_PLL_Reset_proc: process( CPU_PLL_Clock, CPU_PLL_Asyn_Reset )
  begin
    if( CPU_PLL_Asyn_Reset = '0' )then
      CPU_PLL_Reset_q        <= '1';
      CPU_PLL_Reset          <= '1';
    elsif( rising_edge(CPU_PLL_Clock) )then
      CPU_PLL_Reset_q        <= '0';
      CPU_PLL_Reset          <= CPU_PLL_Reset_q;
    end if;
  end process;

  U_CPU_CLK : entity work.cpu_clock
  port map(
    areset                   => CPU_PLL_Reset,
    inclk0                   => CPU_PLL_Clock,
    c0                       => CPU_Clock,
    locked                   => CPU_PLL_Locked
  );
  
 U_OPEN8_SOC : entity work.open8_soc
port map (
  -- Master oscillator
  clk   => CPU_Clock,
  -- Push buttons
  reset => CPU_PLL_Locked,
  btn0  => KEY1,
  -- LED outputs
  leds  => LEDS,
  --LEDS gp debug
  LED_R0 =>LED_R0,
  LED_R1 =>LED_R1,
  LED_R2 =>LED_R2,
  LED_R3 =>LED_R3,
  DUT_Trig =>DUT_Trig,
  -- Configuration Switches
  dipsw =>DIPSW,
  i_sck =>DECA_IO9,
  i_copi=>DECA_IO8,
  o_cipo=>DECA_IO7,
  i_cs  =>DECA_IO6
  );

end architecture;