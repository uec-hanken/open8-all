-- VHDL units : de0_nano_top
-- Description: Connects whatever is going to be inside the chip and routes it to the DE0
--
-- Revision History
-- Author          Date     Change
------------------ -------- ---------------------------------------------------
-- Ckristian Duran 06/19/20 Version block added

library ieee;
  use ieee.std_logic_1164.all;

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

begin

  U_CHIP : entity work.chip_top
  port map(
    clock                      => GPIN0(0),
    reset                      => GPIN0(1),
    Address                    => GPIO0(15 downto 0),
    Wr_Data                    => GPIO0(23 downto 16),
    Rd_Data                    => GPIO0(31 downto 24),
    Wr_En                      => GPIO0(32),
    Rd_En                      => GPIO0(33),
    
    Interrupts                 => GPIO1(7 downto 0),
    GP_Flags                   => GPIO1(12 downto 8),
    uSec_Tick                  => GPIO1(13)
  );
  
end architecture;
