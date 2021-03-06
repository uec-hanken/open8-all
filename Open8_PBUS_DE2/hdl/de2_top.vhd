-- VHDL units : de2_top
-- Description: Connects all of the components to form a test-bed computer
--
-- Revision History
-- Author          Date     Change
------------------ -------- ---------------------------------------------------
-- Seth Henry      04/16/20 Version block added

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_arith.all;
  use ieee.std_logic_unsigned.all;
  use ieee.std_logic_misc.all;

library work;
  use work.open8_pkg.all;
  use work.open8_cfg.all;

entity de2_top is
generic(
  IMPL : Integer := 0
);
port(
  -- Master oscillator
  CLOCK_50                   : in  std_logic;
  -- Push buttons
  KEY0                       : in  std_logic;
  KEY1                       : in  std_logic;
  KEY2                       : in  std_logic;
  KEY3                       : in  std_logic;
  -- LED outputs
  --LEDG                       : out std_logic_vector(7 downto 0);
  LEDR                       : out std_logic_vector(17 downto 0);
  
  HEX0                       : out std_logic_vector(6 downto 0);
  HEX1                       : out std_logic_vector(6 downto 0);
  HEX2                       : out std_logic_vector(6 downto 0);
	 
  -- Switches
  SW                         : in  std_logic_vector(9 downto 0);
  SW_10                      : in  std_logic;
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
  
  signal  LED_binary         : std_logic_vector(7 downto 0);

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

  signal CPU_Fast_Clock      : std_logic := '0';
  signal CPU_Clock_Cnt       : std_logic_vector(7 downto 0) := x"00";
  signal CPU_Clock           : std_logic := '0';
  signal CPU_PLL_Locked      : std_logic := '0';
  signal Buttons             : std_logic_vector(7 downto 0) := x"00";
  
  signal counter       		  : std_logic_vector(31 downto 0) := x"00000000";
  signal LED_out             : std_logic := '0';
  signal State       		  : std_logic_vector(4 downto 0) := "00000";
  signal Toggle_led      	  : std_logic := '0';

  signal clock                      : std_logic;
  signal reset                      : std_logic;
  signal uSec_Tick                  : std_logic;
  signal Address                    : std_logic_vector(OPEN8_ADDR_WIDTH - 1 downto 0);
  signal Wr_En                      : std_logic;
  signal Wr_Data                    : std_logic_vector(OPEN8_DATA_WIDTH - 1 downto 0);
  signal Rd_En                      : std_logic;
  signal GP_Flags                   : std_logic_vector(4 downto 0);
  signal Rd_Data                    : std_logic_vector(OPEN8_DATA_WIDTH - 1 downto 0);
  signal Interrupts                 : std_logic_vector(OPEN8_DATA_WIDTH - 1 downto 0);
  
  
  signal buf_Clock           : std_logic := '0';
  
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

begin
  
  LED_DIV: process(Toggle_led)
  begin
		if (rising_edge(Toggle_led)) then 

			if(counter = 50000) then
					counter <= x"00000000";
					LED_out <= not LED_out;
			else counter <= counter + x"00000001";
			end if;
		end if;
  end process;
  
  
  
  FSM: process(CPU_Clock, SW_10)
  begin
		if (rising_edge(CPU_Clock)) then
			if ( SW_10 = '0' )then
				State <= "00000";
				Toggle_led <= '0';
				else 
					case State is 
					
					when "00000" => 
						if(LED_binary = 0) then 
							State <= "00001";
						else State <= "11111";
						end if;
					when "00001" => 
						if(LED_binary = 0) then 
							State <= "00001";
						elsif(LED_binary = 1) then 
							State <= "00010";
						else State <= "11111";
						end if;
					when "00010" => 
						if(LED_binary = 1) then 
							State <= "00010";
						elsif(LED_binary = 2) then 
							State <= "00011";
						else State <= "11111";
						end if;
					when "00011" => 
						if(LED_binary = 2) then 
							State <= "00011";
						elsif(LED_binary = 3) then 
							State <= "00100";
						else State <= "11111";
						end if;
					when "00100" => 
						if(LED_binary = 3) then 
							State <= "00100";
						elsif(LED_binary = 4) then 
							State <= "00101";
						else State <= "11111";
						end if;
					when "00101" => 
						if(LED_binary = 4) then 
							State <= "00101";
						elsif(LED_binary = 5) then 
							State <= "00110";
						else State <= "11111";
						end if;
					when "00110" => 
						if(LED_binary = 5) then 
							State <= "00110";
						elsif(LED_binary = 6) then 
							State <= "00111";
						else State <= "11111";
						end if;		
					when "00111" => 
						if(LED_binary = 6) then 
							State <= "00111";
						elsif(LED_binary = 7) then 
							State <= "01000";
						else State <= "11111";
						end if;	
					when "01000" => 
						if(LED_binary = 7) then 
							State <= "01000";
						elsif(LED_binary = 8) then 
							State <= "01001";
						else State <= "11111";
						end if;
					when "01001" => 
						if(LED_binary = 8) then 
							State <= "01001";
						elsif(LED_binary = 9) then 
							State <= "01010";
						else State <= "11111";
						end if;
					when "01010" => 
						if(LED_binary = 9) then 
							State <= "01010";
						elsif(LED_binary = 10) then 
							State <= "01011";
						else State <= "11111";
						end if;	
					when "01011" => 
						if(LED_binary = 10) then 
							State <= "01011";
						elsif(LED_binary = 11) then 
							State <= "01100";
						else State <= "11111";
						end if;
					when "01100" => 
						if(LED_binary = 11) then 
							State <= "01100";
						elsif(LED_binary = 12) then 
							State <= "01101";
						else State <= "11111";
						end if;
					when "01101" => 
						if(LED_binary = 12) then 
							State <= "01101";
						elsif(LED_binary = 13) then 
							State <= "01110";
						else State <= "11111";
						end if;
					when "01110" => 
						if(LED_binary = 13) then 
							State <= "01110";
						elsif(LED_binary = 14) then 
							State <= "01111";
						else State <= "11111";
						end if;
					when "01111" => 
						if(LED_binary = 14) then 
							State <= "01111";
						elsif(LED_binary = 15) then 
							State <= "10000";
						else State <= "11111";
						end if;
					when "10000" => 
						if(LED_binary = 15) then 
							State <= "10000";
						elsif(LED_binary = 16) then 
							State <= "10001";
						else State <= "11111";
						end if;	
					when "10001" => 
						Toggle_led <= not Toggle_led;
						if(LED_binary = 16) then 
							State <= "10001";
						elsif(LED_binary = 0) then 
							State <= "00000";
						else State <= "11111";
						end if;
					
					when "11111" => 
						Toggle_led <= '0';
					when others => 
						Toggle_led <= '0';
					end case;
			end if;
		end if;	
  end process;
  
  
  
  
  CLK_GEN_0: if(IMPL = 0) generate
    
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
    c0                       => CPU_Fast_Clock,
    locked                   => CPU_PLL_Locked
  );
    
  CPU_Fast_clk_proc: process( CPU_Fast_Clock )
  begin
    if( rising_edge(CPU_Fast_Clock) )then
      CPU_Clock_Cnt          <= CPU_Clock_Cnt + 1;
    end if;
  end process;
  CPU_Clock <= CPU_Clock_Cnt(5);
  
  end generate CLK_GEN_0;

  CLK_GEN_1: if(IMPL = 1) generate
    CPU_Clock <= GPIO1(30);
	
	CPU_PLL_Reset_proc: process( CPU_Clock, CPU_PLL_Asyn_Reset )
    begin
      if( CPU_PLL_Asyn_Reset = '0' )then
        CPU_PLL_Reset_q        <= '1';
        CPU_PLL_Reset          <= '1';
      elsif( rising_edge(CPU_PLL_Clock) )then
        CPU_PLL_Reset_q        <= '0';
        CPU_PLL_Reset          <= CPU_PLL_Reset_q;
      end if;
    end process;
    CPU_PLL_Locked <= not CPU_PLL_Reset;
  
  end generate CLK_GEN_1;
  
  

  U_CPU : entity work.soc_top
  port map(
    -- Connections of the bus and clocks
    -- NOTE: The reason are shifted compared to the DE0 version
    -- is because the DE0 have some weird "GPIOIN" pins
    clock                      => CPU_Clock,
    Address                    => Address,
    Wr_Data                    => Wr_Data,
    Rd_Data                    => Rd_Data,
    Wr_En                      => Wr_En,
    Interrupts                 => Interrupts,
    GP_Flags                   => GP_Flags,
    uSec_Tick                  => uSec_Tick,
    Rd_En                      => Rd_En,
    reset                      => reset,
    -- end: Connections of the bus and clocks
    
    LED_R0              => LED_R0,
    LED_R1              => LED_R1,
    LED_R2              => LED_R2,
    LED_R3              => LED_R3, 
    LEDG                => LED_binary, 
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
  Segment : entity work.binary_7segment
  port map(
	 clk                         => CPU_Clock,
    reset                       => reset,
    binary_in                   => "000000000000000" & LED_out,
    HEX0                        => HEX0,
    HEX1                        => HEX1,
    HEX2                        => HEX2
	 
  );
  GPIO1(27) <= CPU_Clock; -- clock
  --BUF_CPU_Clock : COMPONENT ALT_IOBUF port map (i => CPU_Clock, oe => '1', io => GPIO1(27));
  --Address                    => GPIO0(18) & GPIO0(16 downto 3) & GPIO0(1),
  BUF_Address_00 : COMPONENT ALT_IOBUF port map (i => '0', oe => '0', io => GPIO0(1), o => Address(0));
  BUF_Address_01 : COMPONENT ALT_IOBUF port map (i => '0', oe => '0', io => GPIO0(3), o => Address(1));
  BUF_Address_02 : COMPONENT ALT_IOBUF port map (i => '0', oe => '0', io => GPIO0(4), o => Address(2));
  BUF_Address_03 : COMPONENT ALT_IOBUF port map (i => '0', oe => '0', io => GPIO1(26), o => Address(3));
  BUF_Address_04 : COMPONENT ALT_IOBUF port map (i => '0', oe => '0', io => GPIO0(6), o => Address(4));
  BUF_Address_05 : COMPONENT ALT_IOBUF port map (i => '0', oe => '0', io => GPIO0(7), o => Address(5));
  BUF_Address_06 : COMPONENT ALT_IOBUF port map (i => '0', oe => '0', io => GPIO0(8), o => Address(6));
  BUF_Address_07 : COMPONENT ALT_IOBUF port map (i => '0', oe => '0', io => GPIO0(9), o => Address(7));
  BUF_Address_08 : COMPONENT ALT_IOBUF port map (i => '0', oe => '0', io => GPIO0(10), o => Address(8));
  BUF_Address_09 : COMPONENT ALT_IOBUF port map (i => '0', oe => '0', io => GPIO0(11), o => Address(9));
  BUF_Address_10 : COMPONENT ALT_IOBUF port map (i => '0', oe => '0', io => GPIO0(12), o => Address(10));
  BUF_Address_11 : COMPONENT ALT_IOBUF port map (i => '0', oe => '0', io => GPIO0(13), o => Address(11));
  BUF_Address_12 : COMPONENT ALT_IOBUF port map (i => '0', oe => '0', io => GPIO0(14), o => Address(12));
  BUF_Address_13 : COMPONENT ALT_IOBUF port map (i => '0', oe => '0', io => GPIO0(15), o => Address(13));
  BUF_Address_14 : COMPONENT ALT_IOBUF port map (i => '0', oe => '0', io => GPIO0(16), o => Address(14));
  BUF_Address_15 : COMPONENT ALT_IOBUF port map (i => '0', oe => '0', io => GPIO0(18), o => Address(15));
  --Wr_Data                    => GPIO0(26 downto 19),
  GEN_Wr_Data: for I in 0 to 7 generate
    BUF_Wr_Data : COMPONENT ALT_IOBUF port map (i => '0', oe => '0', io => GPIO0(I+19), o => Wr_Data(I));
  end generate GEN_Wr_Data;
  --Rd_Data                    => GPIO0(34 downto 27),
  GEN_Rd_Data: for I in 0 to 7 generate
    BUF_Rd_Data : COMPONENT ALT_IOBUF port map (i => Rd_Data(I), oe => '1', io => GPIO0(I+27));
  end generate GEN_Rd_Data;
  --Wr_En                      => GPIO0(35),
  BUF_Wr_En : COMPONENT ALT_IOBUF port map (i => '0', oe => '0', io => GPIO0(35), o => Wr_En);
  
  --GPIO1(1) <= Interrupts(0);
  --GPIO1(9 downto 3) <= Interrupts(7 downto 1);
  BUF_Interrupts_0 : COMPONENT ALT_IOBUF port map (i => Interrupts(0), oe => '1', io => GPIO1(1));
  GEN_Interrupts: for I in 1 to 7 generate
    BUF_Interrupts : COMPONENT ALT_IOBUF port map (i => Interrupts(I), oe => '1', io => GPIO1(I+2)); -- For starts in 1
  end generate GEN_Interrupts;
  
  
  --GP_Flags                   => GPIO1(14 downto 10),
  GEN_GP_Flags: for I in 0 to 4 generate
    BUF_GP_Flags : COMPONENT ALT_IOBUF port map (i => '0', oe => '0', io => GPIO1(I+10), o => GP_Flags(I));
  end generate GEN_GP_Flags;
  --uSec_Tick                  => GPIO1(15),
  BUF_uSec_Tick : COMPONENT ALT_IOBUF port map (i => '0', oe => '0', io => GPIO1(15), o => uSec_Tick);
  --Rd_En                      => GPIO1(22),
  BUF_Rd_En : COMPONENT ALT_IOBUF port map (i => '0', oe => '0', io => GPIO1(22), o => Rd_En);
  --GPIO1(24) <= CPU_PLL_Locked; -- Locked
  BUF_CPU_PLL_Locked : COMPONENT ALT_IOBUF port map (i => SW_10, oe => '1', io => GPIO1(24));
  --reset                      => GPIO1(25),
  BUF_reset : COMPONENT ALT_IOBUF port map (i => '0', oe => '0', io => GPIO1(25), o => reset);

  
  -- Non buffered, because reasons
  Buttons(0) <= KEY1;
  Buttons(1) <= KEY2;
  Buttons(2) <= KEY3;
  Buttons(7 downto 3) <= (others => '0');

end architecture;
