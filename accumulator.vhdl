library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package accumulator_types is
  constant BLOCKSIZE : integer := 128;
  constant NUMBLOCKS : integer := 33;
  subtype addblock is std_logic_vector(BLOCKSIZE-1 downto 0);
  type accutype is array (NUMBLOCKS-1 downto 0) of addblock;
  subtype flagtype is std_logic_vector(NUMBLOCKS-1 downto 0);
  subtype position is natural range 0 to NUMBLOCKS-1;
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
  constant allzero : addblock := (others => '0');
  constant allone : addblock := (others => '1');
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
  process(clock, reset)
    variable accu : accutype;
    variable allmask : flagtype;
    variable allvalue : flagtype;
    variable outbuf : addblock;
    procedure get_accu(p : in position; v : out addblock) is
    begin
      if allmask(p) = '1' then
        v := (others => allvalue(p));
      else
        v := accu(p);
      end if;
    end get_accu;
    procedure set_accu(p : in position; v : in addblock) is
      variable replicate : addblock := (others => v(0));
    begin
      if v = replicate then
        allmask(p) := '1';
      else
        allmask(p) := '0';
      end if;
      allvalue(p) := v(0);
      accu(p) := v;
    end set_accu;

    procedure add(sign : in std_logic; pos : in position; d : in addblock) is
      variable result : std_logic_vector(d'length downto 0);
      variable curval : std_logic_vector(d'length - 1 downto 0);
      variable i : integer;
      variable enables : flagtype := (others => '0');
      variable inc : integer := 0;
    begin
      get_accu(pos, curval);
      result := std_logic_vector(unsigned(sign & d) + unsigned(curval));
      set_accu(pos, result(data'length-1 downto 0));
      if result(data'length) = '1' then
        enables(pos + 1) := '1';
        for i in 1 to NUMBLOCKS - 1 loop
          enables(i) := enables(i - 1) and allmask(i) and (allvalue(i) xor sign);
          if enables(i - 1) = '1' and enables(i) = '0' then
            inc := i;
          end if;
        end loop;
        allmask := allmask xor enables;
        set_accu(inc, std_logic_vector(unsigned(accu(inc)) + 1));
      end if;
    end add;
  begin
    if reset = '1' then
      accu := (others => allzero);
      allmask := (others => '1');
      allvalue := (others => '0');
    elsif clock = '1' then
      case op is
        when op_add =>
          add('0', pos, data);
        when op_output =>
          get_accu(pos, outbuf);
          output <= outbuf;
        when op_nop => null;
      end case;
    end if;
  end process;
end behaviour;