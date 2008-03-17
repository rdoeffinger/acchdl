--! \file
--! \brief declarations of some HyperTransport-related constants
--! \author Reimar Döffinger
--! \date 2007,2008
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--! package containing some commonly-used HyperTransport-related constants
package ht_constants is
constant CMD_OFFSET  : integer :=  0;
constant CMD_LEN     : integer :=  6;
constant TAG_OFFSET  : integer := 16;
constant TAG_LEN     : integer :=  5;
constant COUNT_OFFSET: integer := 22;
constant COUNT_LEN   : integer :=  4;
constant ADDR_OFFSET : integer := 26;
constant ADDR_LEN    : integer := 62;
end ht_constants;
