library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity binary_7segment is
    port(
        clk, reset: in std_logic;
        binary_in: in std_logic_vector(15 downto 0);
        HEX0, HEX1, HEX2: out std_logic_vector(6 downto 0)
    );
	
end binary_7segment ;
architecture Behavioral of binary_7segment is

signal bcd0		:std_logic_vector(3 downto 0);
signal bcd1		:std_logic_vector(3 downto 0);
signal bcd2		:std_logic_vector(3 downto 0);
signal bcd3		:std_logic_vector(3 downto 0);
signal bcd4		:std_logic_vector(3 downto 0);
signal bcd5		:std_logic_vector(3 downto 0);

begin
 binary2bcd: entity work.binary_bcd
  port map(
    clk                     => clk,
    reset                   => reset,
    binary_in               => binary_in,
    bcd0                    => bcd0,
    bcd1                    => bcd1,
    bcd2                    => bcd2,
    bcd3                    => bcd4,
    bcd4                    => bcd5
  );
  HEX_0 : entity work.bcd_7segment
  port map(
    BCDin                  => bcd0,
    Seven_Segment          => HEX0
  );
  HEX_1 : entity work.bcd_7segment
  port map(
    BCDin                  => bcd1,
    Seven_Segment          => HEX1
  );
  HEX_2 : entity work.bcd_7segment
  port map(
    BCDin                  => bcd2,
    Seven_Segment          => HEX2
  );
  
end Behavioral;