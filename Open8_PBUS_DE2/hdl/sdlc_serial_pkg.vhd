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
--
-- VHDL Units :  sdlc_serial_pkg
-- Description:  Contains constant definitions for the SDLC packet engine
--
-- Revision History
-- Author          Date     Change
------------------ -------- ---------------------------------------------------
-- Seth Henry      04/14/20 Code cleanup and revision section added

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_arith.all;

package sdlc_serial_pkg is

  subtype DATA_IN_TYPE       is std_logic_vector(7 downto 0);
  subtype CRC_OUT_TYPE       is std_logic_vector(15 downto 0);

  constant SDLC_Flag         : DATA_IN_TYPE := x"7E";

  function ceil_log2 (x : in natural) return natural;

  -- Internal definitions
  constant CK_REGISTER       : DATA_IN_TYPE := x"FE";
  constant TX_REGISTER       : DATA_IN_TYPE := x"FF";
  constant CS_REGISTER       : DATA_IN_TYPE := x"FE";
  constant RX_REGISTER       : DATA_IN_TYPE := x"FF";

  constant TX_RESERVED_LOW   : integer := 0;
  constant TX_RESERVED_HIGH  : integer := 254;

  constant FLAG_DONE         : DATA_IN_TYPE := x"FF";

  constant ERR_LENGTH        : DATA_IN_TYPE := x"00";

end package;

package body sdlc_serial_pkg is

  -- The ceil_log2 function returns the minimum register width required to
  --  hold the supplied integer.
  function ceil_log2 (x : in natural) return natural is
    variable retval          : natural;
  begin
    retval                   := 1;
    while ((2**retval) - 1) < x loop
      retval                 := retval + 1;
    end loop;
    return retval;
  end ceil_log2;

end package body;