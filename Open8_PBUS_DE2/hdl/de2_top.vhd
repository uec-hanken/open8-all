-- VHDL units : de2_top
-- Description: Connects all of the components to form a test-bed computer
--
-- Revision History
-- Author          Date     Change
------------------ -------- ---------------------------------------------------
-- Seth Henry      04/16/20 Version block added

library ieee;
  use ieee.std_logic_1164.all;

library work;
  use work.open8_pkg.all;
  use work.open8_cfg.all;

entity de2_top is
port(
  -- Master oscillator
  CLOCK_50                   : in  std_logic;
  -- Push buttons
  KEY0                       : in  std_logic;
  KEY1                       : in  std_logic;
  KEY2                       : in  std_logic;
  KEY3                       : in  std_logic;
  -- LED outputs
  LEDG                       : out std_logic_vector(7 downto 0);
  LEDR                       : out std_logic_vector(17 downto 0);
  -- Switches
  SW                         : in  std_logic_vector(9 downto 0);
  -- DRAM
  DRAM_ADDR                  : out std_logic_vector(12 downto 0);
  DRAM_BA                    : out std_logic_vector(1 downto 0);
  DRAM_CAS_N                 : out std_logic;
  DRAM_CKE                   : out std_logic;
  DRAM_CLK                   : out std_logic;
  DRAM_CS_N                  : out std_logic;
  DRAM_DQ                    : inout std_logic_vector(15 downto 0);
  DRAM_LDQM                  : out std_logic;
  DRAM_RAS_N                 : out std_logic;
  DRAM_UDQM                  : out std_logic;
  DRAM_WE_N                  : out std_logic;
  -- I2C PROM
  I2C_SCLK                   : out std_logic;
  I2C_SDAT                   : inout std_logic;
  -- ADC
  ADC_CONVST                 : out std_logic;
  ADC_DIN                    : out std_logic;
  ADC_DOUT                   : in  std_logic;
  ADC_SCLK                   : out std_logic;
  -- GPIO
  GPIO0                      : inout std_logic_vector(35 downto 0);
  GPIO1                      : inout std_logic_vector(35 downto 0);
  UNCONNECTED                : inout std_logic_vector(35 downto 0)
);
end entity;

architecture behave of de2_top is

  -- I/O mapping aliases

  -- Clock & Reset
  alias  CPU_PLL_Asyn_Reset  is KEY0;
  alias  CPU_PLL_Clock       is CLOCK_50;

  -- LED Paddleboard
  alias  LED_R0              is LEDR(0);
  alias  LED_R1              is LEDR(1);
  alias  LED_R2              is LEDR(2);
  alias  LED_R3              is LEDR(3);

  -- SDLC Serial Interface   
  alias  SDLC_In             is UNCONNECTED(0);  
  alias  SDLC_MClk           is UNCONNECTED(1);  
  alias  SDLC_Out            is UNCONNECTED(2);  

  -- Async Serial Port    
  alias  TX_Out              is UNCONNECTED(4);  
  alias  RX_In               is UNCONNECTED(5);  

  -- Trigger Signal   
  alias  DUT_Trig            is UNCONNECTED(6);  

  -- Unused I/O to DE0   
  alias  DUT_Misc            is UNCONNECTED(7);  

  -- Vector RX (TS Input)   
  alias  Req_Rx              is UNCONNECTED(8); 

  -- MAX 7221 SPI Interface    
  alias  Mx_Data             is UNCONNECTED(9); 
  alias  Mx_Clock            is UNCONNECTED(10); 
  alias  MX_LDCSn            is UNCONNECTED(12); 

  -- Internal signals

  signal CPU_PLL_Reset_q     : std_logic := '0';
  signal CPU_PLL_Reset       : std_logic := '0';

  signal CPU_Clock           : std_logic := '0';
  signal CPU_PLL_Locked      : std_logic := '0';
  signal Buttons             : std_logic_vector(7 downto 0) := x"00";

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
  
  GPIO0(14) <= CPU_Clock; -- clock
  GPIO0(15) <= not CPU_PLL_Locked; -- reset

  U_CPU : entity work.soc_top
  port map(
    Address                    => GPIO0(15 downto 0),
    Wr_Data                    => GPIO0(23 downto 16),
    Rd_Data                    => GPIO0(31 downto 24),
    Wr_En                      => GPIO0(32),
    Rd_En                      => GPIO0(33),
    
    Interrupts                 => GPIO1(7 downto 0),
    GP_Flags                   => GPIO1(12 downto 8),
    uSec_Tick                  => GPIO1(13),
    clock                      => GPIO1(14),
    reset                      => GPIO1(15),
    
    LED_R0              => LED_R0,
    LED_R1              => LED_R1,
    LED_R2              => LED_R2,
    LED_R3              => LED_R3, 
    LEDG                => LEDG, 
    SW                  => SW, 
    Buttons             => Buttons, 
    SDLC_In             => SDLC_In, 
    SDLC_MClk           => SDLC_MClk,
    SDLC_Out            => SDLC_Out, 
    TX_Out              => TX_Out,
    RX_In               => RX_In,  
    DUT_Trig            => DUT_Trig,
    DUT_Misc            => DUT_Misc,  
    Req_Rx              => Req_Rx,
    Mx_Data             => Mx_Data,
    Mx_Clock            => Mx_Clock,
    MX_LDCSn            => MX_LDCSn
  );
  Buttons(0) <= KEY1;
  Buttons(1) <= KEY1;
  Buttons(2) <= KEY1;
  Buttons(7 downto 3) <= (others => '0');

end architecture;
