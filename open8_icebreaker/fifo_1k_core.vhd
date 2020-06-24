LIBRARY ieee;
USE ieee.std_logic_1164.all;

ENTITY fifo_1k_core IS
	PORT
	(
		aclr		: IN STD_LOGIC ;
		clock		: IN STD_LOGIC ;
		data		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
		rdreq		: IN STD_LOGIC ;
		wrreq		: IN STD_LOGIC ;
		almost_full		: OUT STD_LOGIC ;
		empty		: OUT STD_LOGIC ;
		q		: OUT STD_LOGIC_VECTOR (7 DOWNTO 0)
	);
END fifo_1k_core;


ARCHITECTURE SYN OF fifo_1k_core IS

BEGIN
	
  almost_full <= '0';
  empty <= '0';
  q <= x"00";


END SYN;

