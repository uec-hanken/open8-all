library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

library work;
  use work.open8_pkg.all;
  use work.open8_cfg.all;

entity o8_cpu_tb is
generic(
  CPU_Ext_Reset_Level        : std_logic := '1'
);
port(
  KEY1                       : in  std_logic := '1';
  DIPSW                      : in  std_logic_vector(3 downto 0) := x"F";
  CPU_Halt                   : in  std_logic := '0';
  CPU_Ext_Reset              : in  std_logic := '0';
  SDLC_In                    : in  std_logic := '0';
  SDLC_MClk                  : out std_logic;
  SDLC_Out                   : out std_logic;
  TX_Out                     : out std_logic;
  CTS_In                     : in  std_logic := '1';
  RX_In                      : in  std_logic := '1';
  RTS_Out                    : out std_logic;
  LEDS                       : out DATA_TYPE;
  LED_R0                     : out std_logic;
  LED_R1                     : out std_logic;
  LED_R2                     : out std_logic;
  LED_R3                     : out std_logic;
  FM_Fire                    : out std_logic;
  Mx_Data                    : out std_logic;
  Mx_Clock                   : out std_logic;
  MX_LDCSn                   : out std_logic;
  Req_Rx                     : in  std_logic;
  Req_Attn                   : in  std_logic
);
end entity;

architecture behave of o8_cpu_tb is

  constant Clock_Frequency   : real := 100000000.0;

  signal CPU_Clock           : std_logic;
  signal CPU_PLL_Locked      : std_logic;

  signal Open8_Bus           : OPEN8_BUS_TYPE;
  signal Read_Buses          : OPEN8_BUS_ARRAY := INIT_READ_BUS;
  -- Hardware Interrupt map. Note that pre-initialization is important if
  --  there are less than 8 interrupt sources.
  signal Interrupts          : DATA_TYPE    := x"00";
  signal DipSwitches         : DATA_TYPE    := x"00";
  signal Button_In           : DATA_TYPE    := x"FF";

begin

  U_PLL : entity work.clock_sim
  generic map(
    Clock_Frequency         => Clock_Frequency
  )
  port map(
    c0                      => CPU_Clock,
    locked                  => CPU_PLL_Locked
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

  FM_Fire                    <= Open8_Bus.GP_Flags(EXT_GP5);

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
    Rx_In                    => Req_Rx,
    Req_Attn                 => Req_Attn
  );

end architecture;
