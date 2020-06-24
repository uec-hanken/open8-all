-- VHDL units : nexys4ddr_top
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

entity nexys4ddr_top is
port(
  -- Master oscillator
  clk                        : in  std_logic;
  -- Push buttons
  resetn                     : in  std_logic;
  KEY1                       : in  std_logic;
  -- LED outputs
  LEDS                       : out std_logic_vector(7 downto 0);
  -- Configuration Switches
  DIPSW                      : in  std_logic_vector(3 downto 0);
  -- LED Paddleboard
  LED_R0                     : inout  std_logic;
  LED_R1                     : inout  std_logic;
  LED_R2                     : inout  std_logic;
  LED_R3                     : inout  std_logic;
  -- Async Serial Port
  TX_Out                     : inout  std_logic;
  RX_In                      : inout  std_logic;
  -- Trigger Signal
  DUT_Trig                   : inout  std_logic
);
end entity;

architecture behave of nexys4ddr_top is

  -- I/O mapping aliases

  -- Clock & Reset
  alias  CPU_PLL_Asyn_NReset  is resetn;
  alias  CPU_PLL_Clock       is clk;

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

  CPU_PLL_Reset_proc: process( CPU_PLL_Clock, CPU_PLL_Asyn_NReset )
  begin
    if( CPU_PLL_Asyn_NReset = '1' )then
      CPU_PLL_Reset_q        <= '1';
      CPU_PLL_Reset          <= '1';
    elsif( rising_edge(CPU_PLL_Clock) )then
      CPU_PLL_Reset_q        <= '0';
      CPU_PLL_Reset          <= CPU_PLL_Reset_q;
    end if;
  end process;

  -- NOTE: no PLL clock
	PLL : entity work.cpu_clock
  port map(
    reset                    => not CPU_PLL_Reset,
    clk_in1                  => CPU_PLL_Clock,
    clk_out1                 => CPU_Clock,
    locked                   => CPU_PLL_Locked
  );
  DUT_Trig <= CPU_PLL_Locked;

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

  U_RAM : entity work.o8_ram_4k
  generic map(
    Address_RAM                  => RAM_Address
  )
  port map(
    Open8_Bus                => Open8_Bus,
    Rd_Data                  => Read_Buses(RDB_RAM)
  );

  U_APP_ROM : entity work.o8_rom_4k
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
  
  Read_Buses(RDB_SDLC) <= x"00";
  Interrupts(INT_SDLC) <= '0';

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
  
  Read_Buses(RDB_VEC) <= x"00";
  Interrupts(INT_VEC) <= '0';

  U_CHRON : entity work.o8_elapsed_usec
  generic map(
    Address                  => CHR_Address
  )
  port map(
    Open8_Bus                => Open8_Bus,
    Rd_Data                  => Read_Buses(RDB_CHR)
  );

end architecture;
