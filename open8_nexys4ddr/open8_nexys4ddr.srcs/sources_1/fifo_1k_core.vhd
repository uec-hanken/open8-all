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

	SIGNAL sub_wire0	: STD_LOGIC ;
	SIGNAL sub_wire1	: STD_LOGIC ;
	SIGNAL sub_wire2	: STD_LOGIC_VECTOR (7 DOWNTO 0);



	COMPONENT fifo_generator_0
	PORT (
			clk : IN STD_LOGIC;
    srst : IN STD_LOGIC;
    din : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    wr_en : IN STD_LOGIC;
    rd_en : IN STD_LOGIC;
    dout : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    full : OUT STD_LOGIC;
    almost_full : OUT STD_LOGIC;
    empty : OUT STD_LOGIC
	);
	END COMPONENT;

BEGIN
	almost_full    <= sub_wire0;
	empty    <= sub_wire1;
	q    <= sub_wire2(7 DOWNTO 0);

	scfifo_component : fifo_generator_0
	PORT MAP (
		srst => aclr,
		clk => clock,
		din => data,
		rd_en => rdreq,
		wr_en => wrreq,
		almost_full => sub_wire0,
		empty => sub_wire1,
		dout => sub_wire2
	);



END SYN;


