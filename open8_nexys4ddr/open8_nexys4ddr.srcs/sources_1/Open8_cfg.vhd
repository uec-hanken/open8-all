-- Copyright (c)2020 Jeremy Seth Henry
-- All rights reserved.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are met:
--     * Redistributions of source code must retain the above copyright
--       notice, this list of conditions and the following disclaimer.
--     * Redistributions in binary form must reproduce the above copyright
--       notice, this list of conditions and the following disclaimer in the
--       documentation and/or other materials provided with the distribution,
--       where applicable (as part of a user interface, debugging port, etc.)
--
-- THIS SOFTWARE IS PROVIDED BY JEREMY SETH HENRY ``AS IS'' AND ANY
-- EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
-- WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
-- DISCLAIMED. IN NO EVENT SHALL JEREMY SETH HENRY BE LIABLE FOR ANY
-- DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
-- (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
-- LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
-- ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
-- (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
-- THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

-- VHDL Units :  open8_cfg
-- Description:  Contains project specific constants to configure an Open8
--                system
--
-- Revision History
-- Author          Date     Change
------------------ -------- ---------------------------------------------------
-- Seth Henry      04/16/20 Design Start

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.std_logic_arith.all;

library work;
  use work.open8_pkg.all;

package open8_cfg is

  -- Internal signals & constants
  constant Clock_Frequency          : real      := 100000000.0;

  -- Peripheral Options

  -- SDLC Configuration
  constant Master_Mode              : boolean   := true;
  constant BitClock_Freq            : real      := 20000000.0;
  constant Clock_Offset             : integer   := 3;

  -- FM Serial Configuration
  constant SERIAL_58_125K           : real      := 58125.0;
  constant PARITY_ENABLE            : boolean   := true;
  constant PARITY_ODD_EVENn         : std_logic := '1';

  -- MAX7221 Driver Configuration
  constant MAX7221_BITRATE          : real      := 5000000.0;

  -- Test Vector Receiver Configuration
  constant VECTOR_BITRATE           : real      := 10000000.0;
  constant VECTOR_PARITY            : boolean   := TRUE;
  constant VECTOR_ODD_EVENn         : std_logic := '0';

  -- Open8 CPU Options
  constant Allow_Stack_Address_Move : boolean   := true;
  constant Stack_Xfer_Flag          : integer   := PSR_GP4;
  constant Enable_Auto_Increment    : boolean   := true;
  constant BRK_Implements_WAI       : boolean   := true;
  constant Enable_NMI               : boolean   := true;
  constant Sequential_Interrupts    : boolean   := true;
  constant RTI_Ignores_GP_Flags     : boolean   := true;
  constant Default_Int_Mask         : DATA_TYPE := x"00";

  -- System Memory Map
  constant RAM_Address              : ADDRESS_TYPE := x"0000";  -- System RAM
  constant ALU_Address              : ADDRESS_TYPE := x"1000";  -- ALU16 coprocessor
  constant RTC_Address              : ADDRESS_TYPE := x"1100";  -- System Timer / RT Clock
  constant ETC_Address              : ADDRESS_TYPE := x"1200";  -- Epoch Timer/Alarm Clock
  constant TMR_Address              : ADDRESS_TYPE := x"1400";  -- PIT timer
  constant SDLC_Address             : ADDRESS_TYPE := x"1800";  -- LCD serial interface
  constant LED_Address              : ADDRESS_TYPE := x"2000";  -- LED Display
  constant DSW_Address              : ADDRESS_TYPE := x"2100";  -- Dip Switches
  constant BTN_Address              : ADDRESS_TYPE := x"2200";  -- Push Buttons
  constant SER_Address              : ADDRESS_TYPE := x"2400";  -- UART interface
  constant MAX_Address              : ADDRESS_TYPE := x"2800";  -- Max 7221 base address
  constant VEC_Address              : ADDRESS_TYPE := x"3000";  -- Vector RX base address
  constant CHR_Address              : ADDRESS_TYPE := x"3100";  -- Elapsed Time / Chronometer
  constant ROM_Address              : ADDRESS_TYPE := x"8000";  -- Application ROM
  constant ISR_Start_Addr           : ADDRESS_TYPE := x"8FF0";  -- ISR Vector Table

  -- RAM size is used to calculate the initial stack pointer, which is set at
  --  the top of the RAM region.
  constant RAM_Size                 : integer   := 4096;

  -- Interrupt assignments
  -- These are assigned in order priority from 0 (highest) to 7 (lowest)
  constant INT_PIT                  : integer range 0 to OPEN8_DATA_WIDTH - 1 := 0;
  constant INT_ETC                  : integer range 0 to OPEN8_DATA_WIDTH - 1 := 1;
  constant INT_TMR                  : integer range 0 to OPEN8_DATA_WIDTH - 1 := 2;
  constant INT_ALU                  : integer range 0 to OPEN8_DATA_WIDTH - 1 := 3;
  constant INT_RTC                  : integer range 0 to OPEN8_DATA_WIDTH - 1 := 4;
  constant INT_SDLC                 : integer range 0 to OPEN8_DATA_WIDTH - 1 := 5;
  constant INT_BTN                  : integer range 0 to OPEN8_DATA_WIDTH - 1 := 6;
  constant INT_VEC                  : integer range 0 to OPEN8_DATA_WIDTH - 1 := 7;

  -- Set this to the number of readable modules (entities wth a Rd_Data port) in the design,
  --  as it sets the number of ports on the read aggregator function.
  constant NUM_READ_BUSES         : integer := 13;

  -- Read Data Bus aggregator and bus assignments.
  --  Note that the ordering isn't important, only that each device has a
  --   unique number less than READ_BUS_COUNT.
  constant RDB_RAM                  : integer range 0 to NUM_READ_BUSES - 1 := 0;
  constant RDB_ALU                  : integer range 0 to NUM_READ_BUSES - 1 := 1;
  constant RDB_RTC                  : integer range 0 to NUM_READ_BUSES - 1 := 2;
  constant RDB_TMR                  : integer range 0 to NUM_READ_BUSES - 1 := 3;
  constant RDB_ETC                  : integer range 0 to NUM_READ_BUSES - 1 := 4;
  constant RDB_LED                  : integer range 0 to NUM_READ_BUSES - 1 := 5;
  constant RDB_DSW                  : integer range 0 to NUM_READ_BUSES - 1 := 6;
  constant RDB_BTN                  : integer range 0 to NUM_READ_BUSES - 1 := 7;
  constant RDB_SDLC                 : integer range 0 to NUM_READ_BUSES - 1 := 8;
  constant RDB_SER                  : integer range 0 to NUM_READ_BUSES - 1 := 9;
  constant RDB_VEC                  : integer range 0 to NUM_READ_BUSES - 1 := 10;
  constant RDB_CHR                  : integer range 0 to NUM_READ_BUSES - 1 := 11;
  constant RDB_ROM                  : integer range 0 to NUM_READ_BUSES - 1 := 12;

  -- System configuration calculations - no adjustable parameters below this point
  type OPEN8_BUS_ARRAY is array(0 to NUM_READ_BUSES - 1) of DATA_TYPE;

  constant INIT_READ_BUS            : OPEN8_BUS_ARRAY := (others => OPEN8_NULLBUS);

  function merge_buses (x : in OPEN8_BUS_ARRAY) return DATA_TYPE;

  -- Compute the stack start address based on the RAM size
  constant RAM_Vector_Size          : integer := ceil_log2(RAM_Size - 1);
  constant RAM_End_Addr             : std_logic_vector(RAM_Vector_Size - 1 downto 0)
                                     := (others => '1');

  constant Stack_Start_Addr         : ADDRESS_TYPE := RAM_Address + RAM_End_Addr;

end package;

package body open8_cfg is

  function merge_buses (x : in OPEN8_BUS_ARRAY) return DATA_TYPE is
    variable i               : integer   := 0;
    variable retval          : DATA_TYPE := x"00";
  begin
    retval                   := x"00";
    for i in 0 to NUM_READ_BUSES - 1 loop
      retval                 := retval or x(i);
    end loop;
    return retval;
  end function;

end package body;
