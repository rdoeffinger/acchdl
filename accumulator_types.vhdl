library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package accumulator_types is
  constant BLOCKSIZE : integer := 32;
  constant BLOCKBITS : integer := 4;
  constant NUMBLOCKS : integer := 11;
  subtype operation is std_logic_vector(2 downto 0);
  subtype position_t is std_logic_vector(8 downto 0);
  constant op_nop : operation := "000";
  constant op_add : operation := "001";
  constant op_readblock : operation := "010";
  constant op_writeblock : operation := "011";
  constant op_readflags : operation := "100";
  constant op_writeflags : operation := "101";
  constant op_readfloat : operation := "110";
  constant op_floatadd : operation := "111";
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
