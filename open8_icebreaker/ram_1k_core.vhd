-- Only a generic RAM

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

ENTITY ram_1k_core IS
	PORT
	(
		address		: IN STD_LOGIC_VECTOR (9 DOWNTO 0);
		clock		: IN STD_LOGIC  := '1';
		data		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
		wren		: IN STD_LOGIC ;
		q		: OUT STD_LOGIC_VECTOR (7 DOWNTO 0)
	);
END ram_1k_core;


ARCHITECTURE SYN OF ram_1k_core IS

	 type ram_type is array (0 to (2**address'length)-1) of std_logic_vector(data'range);
   signal ram : ram_type;
   signal read_address : std_logic_vector(address'range);

begin

  RamProc: process(clock) is

  begin
    if rising_edge(clock) then
      if wren = '1' then
        ram(to_integer(unsigned(address))) <= data;
      end if;
      read_address <= address;
    end if;
  end process RamProc;

  q <= ram(to_integer(unsigned(read_address)));



END SYN;


