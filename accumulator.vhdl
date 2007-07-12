library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package accumulator_types is
  constant BLOCKSIZE : integer := 32;
  constant BLOCKBITS : integer := 5;
  constant NUMBLOCKS : integer := 20;
  subtype addblock is std_logic_vector(2*BLOCKSIZE-1 downto 0);
  subtype subblock is std_logic_vector(BLOCKSIZE-1 downto 0);
  type accutype is array (NUMBLOCKS-1 downto 0) of subblock;
  subtype flagtype is std_logic_vector(NUMBLOCKS-1 downto 0);
  subtype position is natural range 0 to NUMBLOCKS-2;
  type operation is (op_nop, op_add, op_output);
  component accumulator is
    port (
      reset : in std_logic;
      clock : in std_logic;
      read : in std_logic;
      data : inout addblock;
      pos : in position;
      op : in operation
    );
  end component;
end accumulator_types;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.accumulator_types.all;
library std;
use std.textio.all;

entity accumulator is
  port (
    reset : in std_logic;
    clock : in std_logic;
    read : in std_logic;
    data : inout addblock;
    pos : in position;
    op : in operation
  );
end accumulator;

architecture behaviour of accumulator is
  signal accu : accutype;
  signal allmask : flagtype;
  signal allvalue : flagtype;
  signal output : addblock;
begin
  process(read)
  begin
    if read = '1' then
      data <= output;
    else
      data <= (others => 'Z');
    end if;
  end process;

  process(clock,reset)
    variable outbuf : addblock;
    procedure get_accu(p : in position; v : out subblock) is
    begin
      if allmask(p) = '1' then
        v := (others => allvalue(p));
      else
        v := accu(p);
      end if;
    end get_accu;

    procedure set_accu(p : in position; v : in subblock) is
      variable replicate : subblock := (others => v(0));
    begin
      if v = replicate then
        allmask(p) <= '1';
      else
        allmask(p) <= '0';
      end if;
      allvalue(p) <= v(0);
      accu(p) <= v;
    end set_accu;

    procedure fixcarry(sign : in std_logic; pos : in position) is
      variable carrytmp : subblock;
      variable carrypos : integer;
      variable i : integer;
    begin
      for i in 1 to NUMBLOCKS - 1 loop
        next when i < pos + 2;
        if allmask(i) = '0' or allvalue(i) = sign then
          carrypos := i;
          exit;
        end if;
        allvalue(i) <= sign;
      end loop;
      get_accu(carrypos, carrytmp);
      if sign = '0' then
        carrytmp := std_logic_vector(unsigned(carrytmp) + 1);
      else
        carrytmp := std_logic_vector(unsigned(carrytmp) - 1);
      end if;
      set_accu(carrypos, carrytmp);
    end fixcarry;

    procedure add(sign : in std_logic; pos : in position; d : in addblock) is
      variable result : std_logic_vector(2*BLOCKSIZE downto 0);
      variable curval : std_logic_vector(2*BLOCKSIZE downto 0);
      variable i : integer;
    begin
      get_accu(pos, curval(BLOCKSIZE - 1 downto 0));
      get_accu(pos + 1, curval(2*BLOCKSIZE - 1 downto BLOCKSIZE));
      curval(2*BLOCKSIZE) := sign;
      result := std_logic_vector(unsigned(d) + unsigned(curval));
      set_accu(pos, result(BLOCKSIZE-1 downto 0));
      set_accu(pos+1, result(2*BLOCKSIZE-1 downto BLOCKSIZE));
      if result(data'length) = '1' then
        fixcarry('0', pos);
      end if;
    end add;
  begin
    if reset = '1' then
      accu <= (others => (others => '0'));
      allmask <= (others => '1');
      allvalue <= (others => '0');
    elsif clock'event and clock = '1' then
      case op is
        when op_add =>
          add('0', pos, data);
        when op_output =>
          get_accu(pos, outbuf(BLOCKSIZE-1 downto 0));
          get_accu(pos+1, outbuf(2*BLOCKSIZE-1 downto BLOCKSIZE));
          output <= outbuf;
        when op_nop => null;
      end case;
    end if;
  end process;
end behaviour;