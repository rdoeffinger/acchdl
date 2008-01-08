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
  type state_t is (st_ready, st_add0, st_add1, st_add2, st_fixcarry,
                   st_out_block0, st_out_block1,
                   st_in_block, st_out_status, st_in_status,
                   st_out_float0, st_out_float1, st_out_float2);

  signal accu : accutype;
  signal allmask : flagtype;
  signal allvalue : flagtype;
  signal input : addblock;
  signal sig_sign : std_logic;
  signal next_pos : natural range 0 to NUMBLOCKS-1;
  signal read_pos : natural range 0 to NUMBLOCKS-1;
  signal write_pos : natural range 0 to NUMBLOCKS-1;
  signal read_block : subblock;
  signal write_block : subblock;
  signal state : state_t;
  signal out_buf : addblock;
  signal carry : unsigned(0 downto 0);
  attribute clock_signal : string;
  attribute clock_signal of clock : signal is "yes";
begin
  ready <= '0' when reset = '1' or
                    state = st_add0 or state = st_add1 or state = st_add2 or
                    state = st_out_block0 or
                    state = st_out_float0 or state = st_out_float1
           else '1';
  data_out <= out_buf;

read : process(clock,reset)
begin
  if reset = '1' then
    read_block <= (others => '0');
  elsif rising_edge(clock) then
    if next_pos = write_pos then
      read_block <= write_block;
    elsif allmask(next_pos) = '1' then
      read_block <= (others => allvalue(next_pos));
    else
      read_block <= accu(next_pos);
    end if;
  end if;
end process;

set_read_pos : process(clock,reset)
begin
  if reset = '1' then
    read_pos <= 0;
  elsif rising_edge(clock) then
    read_pos <= next_pos;
  end if;
end process;

write : process(clock,reset)
begin
  if reset = '1' then
    null;
  elsif rising_edge(clock) then
    accu(write_pos) <= write_block;
  end if;
end process;

write_allmask : process(clock,reset)
  variable replicate : subblock;
begin
  if reset = '1' then
    allmask <= (others => '1');
  elsif rising_edge(clock) then
    replicate := (others => write_block(0));
    if write_block = replicate then
      allmask(write_pos) <= '1';
    else
      allmask(write_pos) <= '0';
    end if;
	 if state = st_in_status and input(17) = '1' then
      allmask(NUMBLOCKS) <= not input(1);
    end if;
  end if;
end process;

write_allvalue : process(clock,reset)
begin
  if reset = '1' then
    allvalue <= (others => '0');
  elsif rising_edge(clock) then
    allvalue(write_pos) <= write_block(0);
    if state = st_in_status and input(16) = '1' then
      allvalue(NUMBLOCKS) <= input(0);
    end if;
  end if;
end process;

execute : process(clock,reset)
  variable tmp : unsigned(BLOCKSIZE downto 0);
  variable curval : subblock;
  variable floatshift : natural range 0 to BLOCKSIZE-1;
begin
  if reset = '1' then
    write_pos <= 0;
    write_block <= (others => '0');
  elsif rising_edge(clock) then
    if read_pos = write_pos then
      curval := write_block;
    else
      curval := read_block;
    end if;
    case state is
      when st_out_block1 =>
        out_buf(BLOCKSIZE-1 downto 0) <= curval;
      when st_in_block =>
        write_pos <= next_pos;
        write_block <= input(BLOCKSIZE-1 downto 0);
      when st_out_status =>
        out_buf(31 downto 16) <= X"0003"; -- valid flags
        out_buf(15 downto 2) <= (others => '0');
        out_buf(1) <= not allmask(NUMBLOCKS);
        out_buf(0) <= allvalue(NUMBLOCKS);
      when st_in_status =>
        -- handled in write_allvalue and write_allmask processes
        null;
      when st_add1 =>
        write_pos <= read_pos;
        write_pos <= read_pos;
        tmp := "0"&unsigned(input(BLOCKSIZE-1 downto 0));
        tmp := tmp + unsigned(curval);
        carry(0) <= tmp(BLOCKSIZE);
        write_block <= subblock(tmp(BLOCKSIZE-1 downto 0));
      when st_add2 =>
        write_pos <= read_pos;
        tmp := "0"&unsigned(input(2*BLOCKSIZE-1 downto BLOCKSIZE));
        tmp := tmp + unsigned(curval) + carry;
        carry(0) <= tmp(BLOCKSIZE);
        write_block <= subblock(tmp(BLOCKSIZE-1 downto 0));
      when st_fixcarry =>
        write_pos <= read_pos;
        write_block <= subblock(unsigned(curval) + 1);
      when st_out_float1 =>
        for floatshift in BLOCKSIZE-1 downto 0 loop
          if curval(floatshift) /= allvalue(NUMBLOCKS) then
            exit;
          end if;
        end loop;
      when st_out_float2 =>
        out_buf(31) <= allvalue(NUMBLOCKS);
        out_buf(30 downto 23) <= std_logic_vector(to_unsigned(read_pos * BLOCKSIZE + floatshift - BLOCKSIZE - 1 + 9, 8));
        out_buf(22 downto 0) <= (others => '0');
      when others =>
        null;
    end case;
  end if;
end process;

get_next_pos : process(clock,reset)
  variable i : integer;
begin
  if reset = '1' then
    next_pos <= 0;
  elsif rising_edge(clock) then
    case state is
      when st_add0 =>
        next_pos <= next_pos + 1;
      when st_add1 =>
        next_pos <= next_pos + 1;
      when st_add2 =>
        next_pos <= 0;
      when st_out_float0 =>
        next_pos <= next_pos - 1;
      when st_out_float1 =>
        next_pos <= 0;
      when others =>
        case op is
          when op_add | op_readblock | op_writeblock =>
            next_pos <= pos + NUMBLOCKS / 2;
          when op_readfloat =>
-- FIXME this is wrong here
            next_pos <= 0;
            for i in NUMBLOCKS - 1 downto 0 loop
              if allmask(i) = '0' or
                 allvalue(i) /= allvalue(NUMBLOCKS) then
                next_pos <= i;
                exit;
              end if;
            end loop;
          when others =>
            next_pos <= 0;
        end case;
    end case;
  end if;
end process;

state_handling : process(clock,reset)
begin
  if reset = '1' then
    state <= st_ready;
  elsif rising_edge(clock) then
    case state is
      when st_add0 =>
        state <= st_add1;
      when st_add1 =>
        state <= st_add2;
      when st_add2 =>
        state <= st_fixcarry;
      when st_out_float0 =>
        state <= st_out_float1;
      when st_out_float1 =>
        state <= st_out_float2;
      when st_out_block0 =>
        state <= st_out_block1;
      when others =>
        case op is
          when op_nop =>
            state <= st_ready;
          when op_add =>
            state <= st_add0;
          when op_readblock =>
            state <= st_out_block0;
          when op_writeblock =>
            state <= st_in_block;
          when op_readflags =>
            state <= st_out_status;
          when op_writeflags =>
            state <= st_in_status;
          when op_readfloat =>
            state <= st_out_float0;
        end case;
    end case;
  end if;
end process;

get_input : process(clock,reset)
begin
  if reset = '1' then
    input <= (others => '0');
    sig_sign <= '0';
  elsif rising_edge(clock) then
    case state is
      when st_add1 | st_add2 | st_out_float1 =>
        null;
      when others =>
        if op = op_add and sign = '1' then
          input <= addblock(unsigned(not data_in) + 1);
        else
          input <= data_in;
        end if;
        sig_sign <= sign;
    end case;
  end if;
end process;

end behaviour;
