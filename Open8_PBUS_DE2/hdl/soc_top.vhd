-- VHDL units : soc_top
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

entity soc_top is
port(
  -- Master oscillator
  clock                      : in  std_logic; --                                      1
  -- Push buttons
  reset                      : in  std_logic; --                                      1
  -- Open 8 Bus (Unpacked and trimmed)
  uSec_Tick                  : in  std_logic; --                                      1
  Address                    : in  std_logic_vector(OPEN8_ADDR_WIDTH - 1 downto 0);-- 16
  Wr_En                      : in  std_logic; --                                      1
  Wr_Data                    : in  std_logic_vector(OPEN8_DATA_WIDTH - 1 downto 0);-- 8
  Rd_En                      : in  std_logic; --                                      1
  GP_Flags                   : in  std_logic_vector(4 downto 0); --                   5, NOTE: Those can be optional.
  Rd_Data                    : out std_logic_vector(OPEN8_DATA_WIDTH - 1 downto 0);-- 8
  -- Open 8 Interrupts
  Interrupts                 : out std_logic_vector(OPEN8_DATA_WIDTH - 1 downto 0);-- 8
  
  -- The rest of the SOC is here
  -- LED Paddleboard
  LED_R0              : out std_logic;
  LED_R1              : out std_logic;
  LED_R2              : out std_logic;
  LED_R3              : out std_logic;
  
  -- LED outputs
  LEDG                : out std_logic_vector(7 downto 0);
  
  -- Switches
  SW                  : in  std_logic_vector(9 downto 0);
  
  -- Buttons
  Buttons             : in  std_logic_vector(7 downto 0);

  -- SDLC Serial Interface   
  SDLC_In             : in std_logic;  
  SDLC_MClk           : out std_logic;  
  SDLC_Out            : out std_logic;  

  -- Async Serial Port   
  TX_Out              : out std_logic;  
  RX_In               : in std_logic;  

  -- Trigger Signal   
  DUT_Trig            : out std_logic;  

  -- Unused I/O to DE0   
  DUT_Misc            : out std_logic;  

  -- Vector RX (TS Input)    
  Req_Rx              : in std_logic; 

  -- MAX 7221 SPI Interface  
  Mx_Data             : out std_logic; 
  Mx_Clock            : out std_logic; 
  MX_LDCSn            : out std_logic 
);
end entity;

architecture behave of soc_top is

  -- Internal signals
  signal Open8_Bus           : OPEN8_BUS_TYPE  := INIT_OPEN8_BUS;
  signal Read_Buses          : OPEN8_BUS_ARRAY := INIT_READ_BUS;

  signal DipSwitches         : DATA_TYPE    := x"00";
  signal Button_In           : DATA_TYPE    := x"00";

begin

  
  Open8_Bus.Clock      <= clock;
  Open8_Bus.Reset      <= reset;
  Open8_Bus.uSec_Tick  <= uSec_Tick;
  Open8_Bus.Address    <= Address;
  Open8_Bus.Wr_En      <= Wr_En ;
  Open8_Bus.Wr_Data    <= Wr_Data;
  Open8_Bus.Rd_En      <= Rd_En;
  Open8_Bus.GP_Flags   <= GP_Flags;
  Rd_Data              <= merge_buses(Read_Buses);

  LED_R0               <= Open8_Bus.GP_Flags(EXT_GP7);
  LED_R1               <= Open8_Bus.GP_Flags(EXT_GP6);
  LED_R2               <= Open8_Bus.GP_Flags(EXT_GP5);
  LED_R3               <= Open8_Bus.GP_Flags(EXT_GP4);

  DUT_Trig             <= Open8_Bus.GP_Flags(EXT_GP5);

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
    Register_Out             => LEDG
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

  DipSwitches                <= "0000" & SW(3 downto 0);

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

  Button_In                  <= Buttons;

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
