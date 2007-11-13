library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package accumulator_types is
  constant BLOCKSIZE : integer := 32;
  constant BLOCKBITS : integer := 5;
  constant NUMBLOCKS : integer := 20;
--  constant BLOCKBITS : integer := 7;
--  constant NUMBLOCKS : integer := 68;
  subtype addblock is std_logic_vector(2*BLOCKSIZE-1 downto 0);
  subtype subblock is std_logic_vector(BLOCKSIZE-1 downto 0);
  type accutype is array (NUMBLOCKS-1 downto 0) of subblock;
  subtype flagtype is std_logic_vector(NUMBLOCKS-1 downto 0);
  subtype position is natural range 0 to NUMBLOCKS-2;
  type operation is (op_nop, op_add, op_output);
  component accumulator is
    port (
      ready : out std_logic;
      reset : in std_logic;
      clock : in std_logic;
      sign : in std_logic;
      data_in : in addblock;
      data_out : out addblock;
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
    ready : out std_logic;
    reset : in std_logic;
    clock : in std_logic;
    sign : in std_logic;
    data_in : in addblock;
    data_out : out addblock;
    pos : in position;
    op : in operation
  );
end accumulator;

architecture behaviour of accumulator is
  type state_t is (st_ready, st_add1, st_add2, st_out, st_fixcarry);

  constant allone : subblock := (others => '1');
  constant allzero : subblock := (others => '0');
  signal accu : accutype;
  signal allmask : flagtype;
  signal allvalue : flagtype;
  signal input : addblock;
  signal sig_sign : std_logic;
  signal addpos : natural range 0 to NUMBLOCKS-1;
  signal state : state_t;
  signal out_buf : addblock;
  attribute clock_signal : string;
  attribute clock_signal of clock : signal is "yes";
begin
  ready <= '1' when state = st_ready and reset = '0' else '0';
  data_out <= out_buf;

  process(clock,reset)
    variable outbuf : addblock;
    variable replicate : subblock;
    variable curval : subblock;
    variable carry : std_logic;
    variable next_addpos : natural;

    procedure findcarry(sign : in std_logic; pos : in position;
                        carrypos : out natural) is
      variable i : natural;
      variable add : natural;
      variable tmp : std_logic_vector(NUMBLOCKS - 1 downto 0);
      variable tmp2 : std_logic_vector(NUMBLOCKS - 1 downto 0);
      variable cptmp : unsigned(BLOCKBITS - 1 downto 0);
    begin
      add := 2**pos;
      if sign = '1' then
        tmp := allvalue or not allmask;
        tmp2 := std_logic_vector(unsigned(tmp) - add);
        tmp := tmp and not tmp2;
      else
        tmp := allvalue and allmask;
        tmp2 := std_logic_vector(unsigned(tmp) + add);
        tmp := tmp2 and not tmp;
      end if;
      if (tmp and X"aaaaa") /= X"00000" then
        cptmp(0) := '1';
      else
        cptmp(0) := '0';
      end if;
      if (tmp and X"ccccc") /= X"00000" then
        cptmp(1) := '1';
      else
        cptmp(1) := '0';
      end if;
      if (tmp and X"0f0f0") /= X"00000" then
        cptmp(2) := '1';
      else
        cptmp(2) := '0';
      end if;
      if (tmp and X"0ff00") /= X"00000" then
        cptmp(3) := '1';
      else
        cptmp(3) := '0';
      end if;
      if (tmp and X"f0000") /= X"00000" then
        cptmp(4) := '1';
      else
        cptmp(4) := '0';
      end if;
      carrypos := to_integer(cptmp);
      allvalue <= tmp2;
    end;

    procedure fixcarry(sign : in std_logic; v : inout subblock) is
    begin
      if sign = '0' then
        v := std_logic_vector(unsigned(v) + 1);
      else
        v := std_logic_vector(unsigned(v) - 1);
      end if;
    end fixcarry;

    procedure add(inc : in subblock; v : inout subblock; carry : inout std_logic) is
      variable result : std_logic_vector(BLOCKSIZE downto 0);
      variable c : std_logic_vector(0 downto 0);
      variable i : integer;
    begin
      c(0) := carry;
      result := std_logic_vector("0"&unsigned(inc) + unsigned(v) + unsigned(c));
      v := result(BLOCKSIZE-1 downto 0);
      carry := result(BLOCKSIZE);
    end add;
  begin
    if reset = '1' then
      allmask <= (others => '1');
      allvalue <= (others => '0');
      state <= st_ready;
    elsif clock'event and clock = '1' then
-- start load
      if allmask(addpos) = '1' then
        curval := (others => allvalue(addpos));
      else
        curval := accu(addpos);
      end if;
-- end load
      case state is
      when st_out =>
        out_buf(BLOCKSIZE-1 downto 0) <= curval;
        out_buf(2*BLOCKSIZE-1 downto BLOCKSIZE) <= (others => '0');
        state <= st_ready;
      when st_add1 =>
        carry := '0';
        add(input(BLOCKSIZE-1 downto 0), curval, carry);
        addpos <= addpos + 1;
        state <= st_add2;
      when st_add2 =>
        add(input(2*BLOCKSIZE-1 downto BLOCKSIZE), curval, carry);
        findcarry(sig_sign, addpos + 1, next_addpos);
        if carry /= sig_sign then
          state <= st_fixcarry;
          addpos <= next_addpos;
        else
          state <= st_ready;
          allvalue <= allvalue;
        end if;
      when st_fixcarry =>
        fixcarry(sig_sign, curval);
        state <= st_ready;
      when st_ready =>
-- copy inputs for use in next cycles
        addpos <= pos;
        sig_sign <= sign;
        input <= data_in;
        case op is
        when op_nop => null;
        when op_add => state <= st_add1;
        when op_output => state <= st_out;
        end case;
      end case;
 -- start store
      replicate := (others => curval(0));
      if curval = replicate then
        allmask(addpos) <= '1';
      else
        allmask(addpos) <= '0';
      end if;
      allvalue(addpos) <= curval(0);
      accu(addpos) <= curval;
-- end store
    end if;
  end process;
end behaviour;
