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

  signal clock_buf                  : std_logic;
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
  signal Interrupts                 : std_logic_vector(OPEN8_DATA_WIDTH - 1 downto 0);
  
  COMPONENT ALT_INBUF
    GENERIC
      (IO_STANDARD : STRING :="NONE";
        WEAK_PULL_UP_RESISTOR : STRING :="NONE";
        LOCATION : STRING :="NONE";
        ENABLE_BUS_HOLD : STRING :="NONE";
        TERMINATION : STRING :="NONE");
    PORT (i : IN STD_LOGIC;
          o : OUT STD_LOGIC);
  END COMPONENT;

  COMPONENT ALT_OUTBUF
    GENERIC(
      IO_STANDARD : STRING :="NONE";
      CURRENT_STRENGTH : STRING :="NONE";
      SLOW_SLEW_RATE : STRING :="NONE";
      LOCATION : STRING :="NONE";
      ENABLE_BUS_HOLD : STRING :="NONE";
      WEAK_PULL_UP_RESISTOR : STRING :="NONE";
      TERMINATION : STRING :="NONE";
      SLEW_RATE:INTEGER := -1
    );
    PORT (
      i : IN STD_LOGIC;
      o : OUT STD_LOGIC
    );
  END COMPONENT;

  COMPONENT ALT_IOBUF
    GENERIC (
      IO_STANDARD : STRING :="NONE";
      CURRENT_STRENGTH : STRING :="NONE";
      SLOW_SLEW_RATE : STRING :="NONE";
      LOCATION : STRING :="NONE";
      ENABLE_BUS_HOLD : STRING :="NONE";
      WEAK_PULL_UP_RESISTOR : STRING :="NONE";
      TERMINATION : STRING :="NONE";
      INPUT_TERMINATION : STRING := "NONE" ;
      OUTPUT_TERMINATION : STRING := "NONE";
      SLEW_RATE:INTEGER := -1
    );
    PORT (
      i : IN STD_LOGIC;
      oe: IN STD_LOGIC;
      io : INOUT STD_LOGIC;
      o : OUT STD_LOGIC );
  END COMPONENT; 

  component clkbuf is
	  port (
		  inclk  : in  std_logic := 'X'; -- inclk
		  outclk : out std_logic         -- outclk
	  );
  end component clkbuf;

begin

  U_CHIP : entity work.chip_top
  port map(
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
  
  --clock <= GPIN0(0);
  BUF_clock_buf : COMPONENT ALT_INBUF port map (i => GPIN0(0), o => clock_buf);
  CLK_BUF_INST : COMPONENT clkbuf port map( inclk => clock_buf, outclk => clock );
  
  BUF_Address_00 : COMPONENT ALT_IOBUF port map (i => Address(0), oe => '1', io => GPIO0(0));
  BUF_Address_01 : COMPONENT ALT_IOBUF port map (i => Address(1), oe => '1', io => GPIO0(1));
  BUF_Address_02 : COMPONENT ALT_IOBUF port map (i => Address(2), oe => '1', io => GPIO0(2));
  BUF_Address_03 : COMPONENT ALT_IOBUF port map (i => Address(3), oe => '1', io => GPIO1(24));
  BUF_Address_04 : COMPONENT ALT_IOBUF port map (i => Address(4), oe => '1', io => GPIO0(4));
  BUF_Address_05 : COMPONENT ALT_IOBUF port map (i => Address(5), oe => '1', io => GPIO0(5));
  BUF_Address_06 : COMPONENT ALT_IOBUF port map (i => Address(6), oe => '1', io => GPIO0(6));
  BUF_Address_07 : COMPONENT ALT_IOBUF port map (i => Address(7), oe => '1', io => GPIO0(7));
  BUF_Address_08 : COMPONENT ALT_IOBUF port map (i => Address(8), oe => '1', io => GPIO0(8));
  BUF_Address_09 : COMPONENT ALT_IOBUF port map (i => Address(9), oe => '1', io => GPIO0(9));
  BUF_Address_10 : COMPONENT ALT_IOBUF port map (i => Address(10), oe => '1', io => GPIO0(10));
  BUF_Address_11 : COMPONENT ALT_IOBUF port map (i => Address(11), oe => '1', io => GPIO0(11));
  BUF_Address_12 : COMPONENT ALT_IOBUF port map (i => Address(12), oe => '1', io => GPIO0(12));
  BUF_Address_13 : COMPONENT ALT_IOBUF port map (i => Address(13), oe => '1', io => GPIO0(13));
  BUF_Address_14 : COMPONENT ALT_IOBUF port map (i => Address(14), oe => '1', io => GPIO0(14));
  BUF_Address_15 : COMPONENT ALT_IOBUF port map (i => Address(15), oe => '1', io => GPIO0(16));
  
  --Wr_Data                    => GPIO0(24 downto 17),
  GEN_Wr_Data: for I in 0 to 7 generate
    BUF_Wr_Data : COMPONENT ALT_IOBUF port map (i => Wr_Data(I), oe => '1', io => GPIO0(I+17));
  end generate GEN_Wr_Data;
  --Rd_Data                    => GPIO0(32 downto 25),
  GEN_Rd_Data: for I in 0 to 7 generate
    BUF_Rd_Data : COMPONENT ALT_IOBUF port map (i => '0', oe => '0', io => GPIO0(I+25), o => Rd_Data(I));
  end generate GEN_Rd_Data;
  --Wr_En                      => GPIO0(33),
  BUF_Wr_En : COMPONENT ALT_IOBUF port map (i => Wr_En, oe => '1', io => GPIO0(33));
  --Interrupts                 => GPIO1(7 downto 0),
  GEN_Interrupts: for I in 0 to 7 generate
    BUF_Interrupts : COMPONENT ALT_IOBUF port map (i => '0', oe => '0', io => GPIO1(I+0), o => Interrupts(I));
  end generate GEN_Interrupts;
  --GP_Flags                   => GPIO1(12 downto 8),
  GEN_GP_Flags: for I in 0 to 4 generate
    BUF_GP_Flags : COMPONENT ALT_IOBUF port map (i => GP_Flags(I), oe => '1', io => GPIO1(I+8));
  end generate GEN_GP_Flags;
  --uSec_Tick                  => GPIO1(13),
  BUF_uSec_Tick : COMPONENT ALT_IOBUF port map (i => uSec_Tick, oe => '1', io => GPIO1(13));
  --Rd_En                      => GPIO1(20),
  BUF_Rd_En : COMPONENT ALT_IOBUF port map (i => Rd_En, oe => '1', io => GPIO1(20));
  --Locked                     => GPIO1(22)
  BUF_Locked : COMPONENT ALT_IOBUF port map (i => '0', oe => '0', io => GPIO1(22), o => Locked);
  --reset                      => GPIO1(23),
  BUF_reset : COMPONENT ALT_IOBUF port map (i => reset, oe => '1', io => GPIO1(23));
  
end architecture;
