--! \file
--! \brief accumulator component and related types and constants
--! \author Reimar Döffinger
--! \date 2007,2008
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--! package declaring the accumulator ALU component and related types and constants
package accumulator_types is
  constant BLOCKSIZE : integer := 32;
  constant BLOCKBITS : integer := 5;
  constant NUMBLOCKS : integer := 23;
  subtype operation is std_logic_vector(3 downto 0);
  subtype position_t is std_logic_vector(8 downto 0);
  --! \name ALU operation constants
  --! \{
  --! no operation (wait)
  constant op_nop          : operation := "0000";
  --! add a 64 bit block at position accumulator::pos
  constant op_add          : operation := "0001";
  --! reads 32 bit block at position accumulator::pos
  constant op_readblock    : operation := "0010";
  --! writes 32 bit block at position accumulator::pos
  constant op_writeblock   : operation := "0011";
  --! reads accumulator flags
  constant op_readflags    : operation := "0100";
  --! write accumulator flags
  constant op_writeflags   : operation := "0101";
  --! read floating-point exponent offsets
  constant op_readoffsets  : operation := "0110";
  --! write floating-point exponent offsets
  constant op_writeoffsets : operation := "0111";
  --! reads current ALU value as floating point value
  constant op_readfloat    : operation := "1000";
  --! adds a floating point value to current ALU value
  constant op_floatadd     : operation := "1001";
  --! \}
  subtype addblock is std_logic_vector(2*BLOCKSIZE-1 downto 0);
  subtype subblock is std_logic_vector(BLOCKSIZE-1 downto 0);
  type accutype is array (NUMBLOCKS-1 downto 0) of subblock;
  subtype flagtype is std_logic_vector(NUMBLOCKS downto 0);
  component accumulator is
    port (
      ready : out std_logic;
      reset : in std_logic;
      clock : in std_logic;
      sign : in std_logic;
      data_in : in addblock;
      data_out : out subblock;
      pos : in position_t;
      op : in operation
    );
  end component;
end accumulator_types;
