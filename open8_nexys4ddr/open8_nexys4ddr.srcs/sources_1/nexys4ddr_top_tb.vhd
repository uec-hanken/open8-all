library ieee;
use ieee.std_logic_1164.all;


entity nexys4ddr_top_tb is
end nexys4ddr_top_tb;

architecture tb of nexys4ddr_top_tb is

    constant T : time := 20 ns;
    
    signal clk, resetn : std_logic;  -- clk and reset
    
    signal KEY1, RX_In : std_logic;  -- input
    signal DIPSW : std_logic_vector(3 downto 0);  -- input
    
    signal LEDS : std_logic_vector(7 downto 0);  -- outputs
    signal DUT_Trig : std_logic;  -- outputs
begin
    UUT : entity work.nexys4ddr_top
    port map (
      clk => clk, 
      resetn => resetn, 
      KEY1 => KEY1, 
      RX_In => RX_In, 
      DIPSW => DIPSW, 
      LEDS => LEDS, 
      DUT_Trig => DUT_Trig
    );
    
     -- continuous clock
    process 
    begin
        clk <= '0';
        wait for T/2;
        clk <= '1';
        wait for T/2;
    end process;


    -- reset = 1 for first clock cycle and then 0
    resetn <= '0', '1' after T*5;
    KEY1 <= '0';
    RX_In <= '1';
    DIPSW <= x"0";
end tb ;
