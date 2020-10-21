-- VHDL units : chip_top
-- Description: Connects open8 core and some peripherals (like the RAM)
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

entity chip_top is
port(
  -- Master oscillator
  clock                      : in  std_logic; --                                      1
  -- Locked (or original reset to the cpu)
  Locked                     : in  std_logic; --                                      1
  -- Push buttons
  reset                      : out std_logic; --                                      1
  -- Open 8 Bus (Unpacked and trimmed)
  uSec_Tick                  : out std_logic; --                                      1
  Address                    : out std_logic_vector(OPEN8_ADDR_WIDTH - 1 downto 0);-- 16
  Wr_En                      : out std_logic; --                                      1
  Wr_Data                    : out std_logic_vector(OPEN8_DATA_WIDTH - 1 downto 0);-- 8
  Rd_En                      : out std_logic; --                                      1
  GP_Flags                   : out std_logic_vector(4 downto 0); --                   5, NOTE: Those can be optional.
  Rd_Data                    : in  std_logic_vector(OPEN8_DATA_WIDTH - 1 downto 0);-- 8
  -- Open 8 Interrupts
  Interrupts                 : in  std_logic_vector(OPEN8_DATA_WIDTH - 1 downto 0) -- 8
  ---------------------------------------------------------------------------------------
  --                                                                                  51 pins
  --                                                                                  46 pins (without GP Flags)
);
end entity;

architecture behave of chip_top is

  -- I/O mapping aliases

  -- Clock & Reset
  alias  CPU_PLL_Locked      is Locked;
  alias  CPU_Clock           is clock;

  -- The real bus, and the real interrupts
  signal Open8_Bus           : OPEN8_BUS_TYPE  := INIT_OPEN8_BUS;
  signal Read_Buses          : DATA_TYPE       := OPEN8_NULLBUS;
  signal Open8_Ints          : INTERRUPT_BUNDLE := x"00";    
  
  signal Read_RAM            : DATA_TYPE       := OPEN8_NULLBUS;
  signal Read_ALU16          : DATA_TYPE       := OPEN8_NULLBUS;
  signal Int_ALU16           : std_logic       := '0';

begin

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
    Rd_Data                  => Read_Buses,
    Interrupts               => Open8_Ints
  );
  
  reset      <= Open8_Bus.Reset;
  uSec_Tick  <= Open8_Bus.uSec_Tick;
  Address    <= Open8_Bus.Address;
  Wr_En      <= Open8_Bus.Wr_En;
  Wr_Data    <= Open8_Bus.Wr_Data;
  Rd_En      <= Open8_Bus.Rd_En;
  GP_Flags   <= Open8_Bus.GP_Flags;
  Read_Buses <= Rd_Data OR Read_RAM OR Read_ALU16;
  Open8_Ints(7 downto INT_ALU+1) <= Interrupts(7 downto INT_ALU+1);
  Open8_Ints(INT_ALU-1 downto 0) <= Interrupts(INT_ALU-1 downto 0);
  Open8_Ints(INT_ALU) <= Int_ALU16 or Interrupts(INT_ALU);
  
  -- NOTE: Comment (or delete) anything you want
  
  -- CUT HERE --

  U_RAM : entity work.o8_ram_1k
  generic map(
    Address                  => RAM_Address
  )
  port map(
    Open8_Bus                => Open8_Bus,
    Rd_Data                  => Read_RAM
  );

--U_ALU16 : entity work.o8_alu16
--generic map(
--  Address                  => ALU_Address
--)
--port map(
--  Open8_Bus                => Open8_Bus,
--  Rd_Data                  => Read_ALU16,
--  Interrupt                => Int_ALU16
--);
  
  -- CUT HERE --

end architecture;
