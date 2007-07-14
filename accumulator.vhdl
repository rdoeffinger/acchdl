library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package accumulator_types is
  constant BLOCKSIZE : integer := 32;
  constant BLOCKBITS : integer := 5;
  constant NUMBLOCKS : integer := 20;
  subtype addblock is std_logic_vector(2*BLOCKSIZE-1 downto 0);
  subtype subblock is std_logic_vector(BLOCKSIZE-1 downto 0);
  type accutype is array (NUMBLOCKS/2-1 downto 0) of subblock;
  subtype flagtype is std_logic_vector(NUMBLOCKS-1 downto 0);
  subtype position is natural range 0 to NUMBLOCKS-2;
  type operation is (op_nop, op_add, op_output);
  component accumulator is
    port (
      reset : in std_logic;
      clock : in std_logic;
      read : in std_logic;
      sign : in std_logic;
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
    sign : in std_logic;
    data : inout addblock;
    pos : in position;
    op : in operation
  );
end accumulator;

architecture behaviour of accumulator is
  constant allone : subblock := (others => '1');
  constant allzero : subblock := (others => '0');
  signal accu0 : accutype;
  signal accu1 : accutype;
  signal allmask : flagtype;
  signal allvalue : flagtype;
  signal input : addblock;
  signal output : addblock;
  signal sig_op : operation;
  signal sig_pos : position;
  signal sig_sign : std_logic;
  signal cycle : std_logic;
  signal addpos0 : natural;
  signal addpos1 : natural;
  signal swap : boolean;
begin
  data <= output when read = '1' else (others => 'Z');

  process(clock,reset)
    variable outbuf : addblock;
    variable curval : addblock;
    variable curval0 : subblock;
    variable curval1 : subblock;
    variable addpos : natural;
    variable carry : std_logic;

    procedure findcarry(sign : in std_logic; pos : in position;
                        carrypos : out natural) is
      variable i : natural;
      variable start : natural := pos + 2;
    begin
      for i in 1 to NUMBLOCKS - 1 loop
        next when i < start;
        if allmask(i) = '0' or allvalue(i) = sign then
          carrypos := i;
          exit;
        end if;
        allvalue(i) <= sign;
      end loop;
    end;

    procedure fixcarry(sign : in std_logic) is
    begin
      if sign = '0' then
        curval(BLOCKSIZE-1 downto 0) := std_logic_vector(unsigned(curval(BLOCKSIZE-1 downto 0)) + 1);
      else
        curval(BLOCKSIZE-1 downto 0) := std_logic_vector(unsigned(curval(BLOCKSIZE-1 downto 0)) - 1);
      end if;
    end fixcarry;

    procedure add(sign : in std_logic; v : inout addblock) is
      variable result : std_logic_vector(2*BLOCKSIZE downto 0);
      variable i : integer;
    begin
      result := std_logic_vector(unsigned(sign&input) + unsigned(v));
      v := result(input'length-1 downto 0);
      carry := result(input'length);
    end add;
  begin
    if reset = '1' then
      allmask <= (others => '1');
      allvalue <= (others => '0');
      carry := '0';
      cycle <= '0';
    elsif clock'event and clock = '1' then
      addpos := pos;
-- start load
      if allmask(2*addpos0) = '1' then
        curval0 := (others => allvalue(2*addpos0));
      else
        curval0 := accu0(addpos0);
      end if;
      if allmask(2*addpos1+1) = '1' then
        curval1 := (others => allvalue(2*addpos1+1));
      else
        curval1 := accu1(addpos1);
      end if;
      if swap then
        curval := curval0 & curval1;
      else
        curval := curval1 & curval0;
      end if;
-- end load
      if cycle = '1' then
        case sig_op is
          when op_add =>
            add(sig_sign, curval);
            findcarry(sig_sign, sig_pos, addpos);
            if carry = '0' then
              allvalue <= allvalue;
            end if;
          when op_output =>
            output <= curval;
          when op_nop => null;
        end case;
      else
-- copy inputs for use in next cycles
        sig_pos <= addpos;
        sig_op <= op;
        sig_sign <= sign;
        input <= data;

        if carry = '1' then
          fixcarry(sig_sign);
          carry := '0';
        end if;
      end if;
 -- start store
      if swap then
        curval1 := curval(BLOCKSIZE-1 downto 0);
        curval0 := curval(2*BLOCKSIZE-1 downto BLOCKSIZE);
      else
        curval0 := curval(BLOCKSIZE-1 downto 0);
        curval1 := curval(2*BLOCKSIZE-1 downto BLOCKSIZE);
      end if;
      if curval0 = allone or curval0 = allzero then
        allmask(2*addpos0) <= '1';
      else
        allmask(2*addpos0) <= '0';
      end if;
      allvalue(2*addpos0) <= curval0(0);
      accu0(addpos0) <= curval0;
      if curval1 = allone or curval1 = allzero then
        allmask(2*addpos1+1) <= '1';
      else
        allmask(2*addpos1+1) <= '0';
      end if;
      allvalue(2*addpos1+1) <= curval1(0);
      accu1(addpos1) <= curval1;
-- end store
-- calculate addresses for next read
      addpos0 <= (addpos + 1) / 2;
      addpos1 <= addpos / 2;
      swap <= addpos mod 2 = 1;

      cycle <= not cycle;
    end if;
  end process;
end behaviour;
