library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package accumulator_types is
  constant BLOCKSIZE : integer := 32;
  constant BLOCKBITS : integer := 4;
  constant NUMBLOCKS : integer := 11;
  subtype addblock is std_logic_vector(2*BLOCKSIZE-1 downto 0);
  subtype subblock is std_logic_vector(BLOCKSIZE-1 downto 0);
  type accutype is array (NUMBLOCKS-1 downto 0) of subblock;
  subtype flagtype is std_logic_vector(NUMBLOCKS downto 0);
  subtype position is integer range -256 to 255;
  type operation is (op_nop, op_add, op_readblock, op_writeblock,
                     op_readflags, op_writeflags, op_readfloat);
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
  type state_t is (st_ready, st_add1, st_add2, st_out_block,
                   st_in_block, st_out_status, st_in_status, st_fixcarry,
                   st_out_float1, st_out_float2);

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
    variable replicate : subblock;
    variable curval : subblock;
    variable tmp : addblock;
    variable carry : std_logic;
    variable next_addpos : natural range 0 to NUMBLOCKS;
    variable floatshift : natural range 0 to BLOCKSIZE-1;

    procedure findcarry(sign : in std_logic; pos : in position;
                        carrypos : out natural) is
      variable i : natural;
      variable add : natural;
      variable tmp : flagtype;
      variable tmp2 : flagtype;
      variable cptmp : unsigned(BLOCKBITS - 1 downto 0);
    begin
      add := 2**pos;
      if sign = '1' then
        tmp := allvalue or not allmask;
        tmp2 := std_logic_vector(unsigned(tmp) - add);
        tmp := tmp and not tmp2;
        tmp2 := tmp2 or tmp;
      else
        tmp := allvalue and allmask;
        tmp2 := std_logic_vector(unsigned(tmp) + add);
        tmp := tmp2 and not tmp;
        tmp2 := tmp2 and not tmp;
      end if;
      if (tmp and X"aaa") /= X"000" then
        cptmp(0) := '1';
      else
        cptmp(0) := '0';
      end if;
      if (tmp and X"ccc") /= X"000" then
        cptmp(1) := '1';
      else
        cptmp(1) := '0';
      end if;
      if (tmp and X"0f0") /= X"000" then
        cptmp(2) := '1';
      else
        cptmp(2) := '0';
      end if;
      if (tmp and X"f00") /= X"000" then
        cptmp(3) := '1';
      else
        cptmp(3) := '0';
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
      out_buf <= (others => '0');
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
      when st_out_block =>
        out_buf(BLOCKSIZE-1 downto 0) <= curval;
        state <= st_ready;
      when st_in_block =>
        curval := input(BLOCKSIZE-1 downto 0);
        state <= st_ready;
      when st_out_status =>
        out_buf(31 downto 16) <= X"0003"; -- valid flags
        out_buf(15 downto 2) <= (others => '0');
        out_buf(1) <= not allmask(NUMBLOCKS);
        out_buf(0) <= allvalue(NUMBLOCKS);
        state <= st_ready;
      when st_in_status =>
        if input(17) = '1' then
          allmask(NUMBLOCKS) <= not input(1);
        end if;
        if input(16) = '1' then
          allvalue(NUMBLOCKS) <= input(0);
        end if;
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
      when st_out_float1 =>
--        out_buf(BLOCKSIZE-1 downto 0) <= curval;
        for floatshift in BLOCKSIZE-1 downto 0 loop
          if curval(floatshift) /= allvalue(NUMBLOCKS) then
            exit;
          end if;
        end loop;
        addpos <= addpos - 1;
        state <= st_out_float2;
      when st_out_float2 =>
        out_buf(31) <= allvalue(NUMBLOCKS);
        out_buf(30 downto 23) <= std_logic_vector(to_unsigned(addpos * BLOCKSIZE + floatshift - BLOCKSIZE - 1 + 9, 8));
        out_buf(22 downto 0) <= (others => '0');
--        tmp := std_logic_vector(unsigned(std_logic_vector'(out_buf(BLOCKSIZE-1 downto 0) & curval(BLOCKSIZE-1 downto 0))) srl floatshift);
--        out_buf(22 downto 0) <= tmp(31 downto 9);
        state <= st_ready;
      when st_ready =>
-- copy inputs for use in next cycles
        addpos <= pos + NUMBLOCKS / 2;
        sig_sign <= sign;
        input <= data_in;
        case op is
        when op_nop => null;
        when op_add =>
          if sign = '1' then
            -- we need two's complement representation
            input <= addblock(unsigned(not data_in) + 1);
          end if;
          state <= st_add1;
        when op_readblock => state <= st_out_block;
        when op_writeblock => state <= st_in_block;
        when op_readflags => state <= st_out_status;
        when op_writeflags => state <= st_in_status;
        when op_readfloat =>
          addpos <= 0;
          for next_addpos in NUMBLOCKS - 1 downto 0 loop
            if allmask(next_addpos) = '0' or
               allvalue(next_addpos) /= allvalue(NUMBLOCKS) then
              addpos <= next_addpos;
              exit;
            end if;
          end loop;
          state <= st_out_float1;
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
