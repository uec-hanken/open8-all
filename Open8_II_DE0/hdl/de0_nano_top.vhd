-- VHDL units : de0_nano_top
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

  signal Open8_Bus           : OPEN8_BUS_TYPE  := INIT_OPEN8_BUS;
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
    Clock                    => CPU_Clock,
    PLL_Locked               => CPU_PLL_Locked,
    Open8_Bus                => Open8_Bus,
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

  U_ALU16 : entity work.o8_alu16
  generic map(
    Address                  => ALU_Address
  )
  port map(
    Open8_Bus                => Open8_Bus,
    Rd_Data                  => Read_Buses(RDB_ALU),
    Interrupt                => Interrupts(INT_ALU)
  );

  U_RTC : entity work.o8_rtc
  generic map(
    Address                  => RTC_Address
  )
  port map(
    Open8_Bus                => Open8_Bus,
    Rd_Data                  => Read_Buses(RDB_RTC),
    --
    Interrupt_PIT            => Interrupts(INT_PIT),
    Interrupt_RTC            => Interrupts(INT_RTC)
  );

  U_ETC : entity work.o8_epoch_timer_ii
  generic map(
    Address                  => ETC_Address
  )
  port map(
    Open8_Bus                => Open8_Bus,
    Rd_Data                  => Read_Buses(RDB_ETC),
    Interrupt                => Interrupts(INT_ETC)
  );

  U_TMR : entity work.o8_sys_timer_ii
  generic map(
    Address                  => TMR_Address
  )
  port map(
    Open8_Bus                => Open8_Bus,
    Rd_Data                  => Read_Buses(RDB_TMR),
    --
    Interrupt                => Interrupts(INT_TMR)
  );

  U_SDLC : entity work.o8_sdlc_if
  generic map(
    Set_As_Master            => Master_Mode,
    BitClock_Frequency       => BitClock_Freq,
    Clock_Offset             => Clock_Offset,
    Clock_Frequency          => Clock_Frequency,
    Address                  => SDLC_Address
  )
  port map(
    Open8_Bus                => Open8_Bus,
    Rd_Data                  => Read_Buses(RDB_SDLC),
    Interrupt                => Interrupts(INT_SDLC),
    --
    SDLC_In                  => SDLC_In,
    SDLC_SClk                => '0',
    SDLC_MClk                => SDLC_MClk,
    SDLC_Out                 => SDLC_Out
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

  Button_In(0)               <= KEY1;
  Button_in(7 downto 1)      <= (others => '0');

  U_SER : entity work.o8_async_serial
  generic map(
    Disable_Transmit         => FALSE,
    Disable_Receive          => FALSE,
    Bit_Rate                 => SERIAL_58_125K,
    Enable_Parity            => PARITY_ENABLE,
    Parity_Odd_Even_n        => PARITY_ODD_EVENn,
    Clock_Frequency          => Clock_Frequency,
    Address                  => SER_Address
  )
  port map(
    Open8_Bus                => Open8_Bus,
    Rd_Data                  => Read_Buses(RDB_SER),
    --
    TX_Out                   => TX_Out,
    CTS_In                   => '1',
    RX_In                    => RX_In,
    RTS_Out                  => open
  );

  U_MAX : entity work.o8_max7221
  generic map(
    Bitclock_Frequency       => MAX7221_BITRATE,
    Clock_Frequency          => Clock_Frequency,
    Address                  => MAX_Address
  )
  port map(
    Open8_Bus                => Open8_Bus,
    --
    Mx_Data                  => Mx_Data,
    Mx_Clock                 => Mx_Clock,
    MX_LDCSn                 => MX_LDCSn
  );

  U_VEC_RX : entity work.o8_vector_rx
  generic map(
    Bit_Rate                 => VECTOR_BITRATE,
    Enable_Parity            => VECTOR_PARITY,
    Parity_Odd_Even_n        => VECTOR_ODD_EVENn,
    Clock_Frequency          => Clock_Frequency,
    Address                  => VEC_Address
  )
  port map(
    Open8_Bus                => Open8_Bus,
    Rd_Data                  => Read_Buses(RDB_VEC),
    Interrupt                => Interrupts(INT_VEC),
    --
    Rx_In                    => Req_Rx
  );

  U_CHRON : entity work.o8_elapsed_usec
  generic map(
    Address                  => CHR_Address
  )
  port map(
    Open8_Bus                => Open8_Bus,
    Rd_Data                  => Read_Buses(RDB_CHR)
  );

end architecture;