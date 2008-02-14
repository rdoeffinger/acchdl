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
    data_out : out subblock;
    pos : in position_t;
    op : in operation
  );
end accumulator;

architecture behaviour of accumulator is
  type state_t is (st_ready, st_in_float0, st_add0, st_add1, st_add2, st_fixcarry,
                   st_out_block0, st_out_block1,
                   st_in_block, st_out_status, st_in_status,
                   st_out_float0, st_out_float1, st_out_float2, st_out_float3,
                   st_out_float4, st_out_float5,
                   st_out_float_normal, st_out_float_denormal, st_out_float_inf);

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
  signal out_buf : subblock;
  signal carry : unsigned(0 downto 0);
  attribute clock_signal : string;
  attribute clock_signal of clock : signal is "yes";
  signal floatshift : natural range 0 to BLOCKSIZE-1;
  signal exp : integer;
  signal shift_cnt : natural range 0 to BLOCKSIZE-1;
  signal ready_sig : std_logic;
  signal carry_pos : natural range 0 to NUMBLOCKS-1;
  signal carry_allvalue : flagtype;
  function maxbit(v: subblock) return integer is
    variable i : natural range 1 to BLOCKSIZE-1;
  begin
    for i in BLOCKSIZE - 1 downto 1 loop
      if v(i) = '1' then
        return i;
      end if;
    end loop;
    return 0;
  end;
begin
  exp <= read_pos * BLOCKSIZE - floatshift - (NUMBLOCKS / 2 - 4) * BLOCKSIZE + 8;
  ready <= ready_sig;
  ready_sig <= not reset when state = st_ready or state = st_fixcarry or
                              state = st_out_block1 or state = st_in_block or
                              state = st_out_status or state = st_in_status or
                              state = st_out_float_normal or state = st_out_float_denormal or state = st_out_float_inf
                         else '0';
  data_out <= out_buf;

find_carry_pos : process(clock,reset)
  variable add : natural;
  variable tmp : flagtype;
  variable tmp2 : flagtype;
  variable cptmp : unsigned(BLOCKBITS - 1 downto 0);
begin
  if reset = '1' then
    carry_pos <= 0;
    carry_allvalue <= (others => '0');
  elsif rising_edge(clock) then
    case state is
      when st_add1 =>
        add := 2**(read_pos + 2);
        if sig_sign = '0' then
          tmp := allvalue and allmask;
          tmp2 := std_logic_vector(unsigned(tmp) + add);
          tmp := tmp2 and not tmp;
          tmp2 := tmp2 and not tmp;
        else
          tmp := allvalue or not allmask;
          tmp2 := std_logic_vector(unsigned(tmp) - add);
          tmp := tmp and not tmp2;
          tmp2 := tmp2 or tmp;
        end if;
        carry_allvalue <= allvalue xor tmp2;
        carry_pos <= maxbit(X"00"&"0"&tmp(NUMBLOCKS-1 downto 0));
      when others =>
        null;
    end case;
  end if;
end process;

read : process(clock,reset)
variable pos : natural range 0 to NUMBLOCKS - 1;
begin
  if reset = '1' then
    read_block <= (others => '0');
  elsif rising_edge(clock) then
    if state = st_add2 then
      pos := carry_pos;
    else
      pos := next_pos;
    end if;
    if pos = write_pos then
      read_block <= write_block;
    elsif allmask(pos) = '1' then
      read_block <= (others => allvalue(pos));
    else
      read_block <= accu(pos);
    end if;
  end if;
end process;

set_read_pos : process(clock,reset)
begin
  if reset = '1' then
    read_pos <= 0;
  elsif rising_edge(clock) then
    if state = st_add2 then
      read_pos <= carry_pos;
    else
      read_pos <= next_pos;
    end if;
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
    if state = st_in_status and input(17) = '1' then
      allmask(NUMBLOCKS) <= not input(1);
    end if;
    if state = st_fixcarry and carry_pos = 0 and carry(0) = '1' and
       sig_sign = allvalue(NUMBLOCKS) then
      -- overflow (we have a sign change when we should not)
      allmask(NUMBLOCKS) <= '0';
    end if;
    if state = st_in_status and input(18) = '1' and input(2) = '1' then
      allmask <= (others => '1');
    else
      replicate := (others => write_block(0));
      if write_block = replicate then
        allmask(write_pos) <= '1';
      else
        allmask(write_pos) <= '0';
      end if;
    end if;
  end if;
end process;

write_allvalue : process(clock,reset)
  variable tmp : flagtype;
begin
  if reset = '1' then
    allvalue <= (others => '0');
  elsif rising_edge(clock) then
    if state = st_in_status and input(16) = '1' then
      allvalue(NUMBLOCKS) <= input(0);
    end if;
    if state = st_in_status and input(18) = '1' and input(2) = '1' then
      allvalue <= (others => '0');
    else
      tmp := allvalue;
      if state = st_fixcarry and carry(0) = '1' then
        tmp := tmp xor carry_allvalue;
      end if;
      tmp(write_pos) := write_block(0);
      if state = st_fixcarry then
        allvalue <= tmp;
      else
        allvalue(NUMBLOCKS - 1 downto 0) <= tmp(NUMBLOCKS - 1 downto 0);
      end if;
    end if;
  end if;
end process;

execute : process(clock,reset)
  variable addtmp : unsigned(BLOCKSIZE downto 0);
  variable bigtmp : addblock;
  variable curval : subblock;
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
        out_buf <= curval;
      when st_in_block =>
        write_pos <= next_pos;
        write_block <= input(BLOCKSIZE-1 downto 0);
      when st_out_status =>
        out_buf(31 downto 16) <= X"0007"; -- valid flags
        out_buf(15 downto 2) <= (others => '0');
        if (allvalue or not allmask) = X"000000" then
          out_buf(2) <= '1';
        else
          out_buf(2) <= '0';
        end if;
        out_buf(1) <= not allmask(NUMBLOCKS);
        out_buf(0) <= allvalue(NUMBLOCKS);
      when st_in_status =>
        -- handled in write_allvalue and write_allmask processes
        if input(18) = '1' and input(2) = '1' then
          write_block <= (others => '0');
        end if;
      when st_add1 =>
        write_pos <= read_pos;
        addtmp := "0"&unsigned(input(BLOCKSIZE-1 downto 0));
        if sig_sign = '0' then
          addtmp := unsigned(curval) + addtmp;
        else
          addtmp := unsigned(curval) - addtmp;
        end if;
        carry(0) <= addtmp(BLOCKSIZE);
        write_block <= subblock(addtmp(BLOCKSIZE-1 downto 0));
      when st_add2 =>
        write_pos <= read_pos;
        addtmp := "0"&unsigned(input(2*BLOCKSIZE-1 downto BLOCKSIZE));
        if sig_sign = '0' then
          addtmp := unsigned(curval) + addtmp + carry;
        else
          addtmp := unsigned(curval) - addtmp - carry;
        end if;
        carry(0) <= addtmp(BLOCKSIZE);
        write_block <= subblock(addtmp(BLOCKSIZE-1 downto 0));
      when st_fixcarry =>
        write_pos <= read_pos;
        if carry(0) = '1' and read_pos /= 0 then -- 0 means overflow
          if sig_sign = '0' then
            write_block <= subblock(unsigned(curval) + carry);
          else
            write_block <= subblock(unsigned(curval) - carry);
          end if;
        else
          write_block <= curval;
        end if;
      when st_out_float2 =>
        if allvalue(NUMBLOCKS) = '1' then
          curval := not curval;
        end if;
        bigtmp(BLOCKSIZE-1 downto 0) := curval;
      when st_out_float3 =>
        if allvalue(NUMBLOCKS) = '1' then
          curval := not curval;
        end if;
        bigtmp(2*BLOCKSIZE-1 downto BLOCKSIZE) := curval;
        if allvalue(NUMBLOCKS) = '1' then
          bigtmp := std_logic_vector(unsigned(bigtmp) + 1);
        end if;
      when st_out_float4 =>
        floatshift <= BLOCKSIZE - 1 - maxbit(bigtmp(2*BLOCKSIZE-1 downto BLOCKSIZE));
      when st_out_float5 =>
        null;
      when st_out_float_normal =>
        out_buf(31) <= allvalue(NUMBLOCKS);
        out_buf(30 downto 23) <= std_logic_vector(to_unsigned(exp, 8));
        bigtmp := std_logic_vector(unsigned(bigtmp) sll floatshift);
        bigtmp(63 downto 32) := std_logic_vector(unsigned(bigtmp(63 downto 32)) + 2**7);
        out_buf(22 downto 0) <= bigtmp(62 downto 40);
      when st_out_float_denormal =>
        out_buf(31) <= allvalue(NUMBLOCKS);
        out_buf(30 downto 23) <= X"00";
        bigtmp(63 downto 32) := std_logic_vector(unsigned(bigtmp(63 downto 32)) + 2**0);
        out_buf(22 downto 0) <= bigtmp(55 downto 33);
      when st_out_float_inf =>
        out_buf(31) <= allvalue(NUMBLOCKS);
        out_buf(30 downto 23) <= X"FF";
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
    if ready_sig = '1' then
      case op is
        when op_add | op_readblock | op_writeblock =>
          next_pos <= to_integer(signed(pos)) + NUMBLOCKS / 2;
        when op_floatadd =>
          next_pos <= to_integer(unsigned(data_in(30 downto 28))) + (NUMBLOCKS / 2 - 4);
        when others =>
          next_pos <= 0;
      end case;
    else
    case state is
      when st_out_float1 | st_in_float0 | st_add0 =>
        next_pos <= next_pos + 1;
      when st_out_float0 =>
        next_pos <= NUMBLOCKS / 2 - 4 - 1;
        for i in NUMBLOCKS / 2 - 4 to NUMBLOCKS - 1 loop
          if allmask(i) = '0' or
            allvalue(i) /= allvalue(NUMBLOCKS) then
            next_pos <= i-1;
          end if;
        end loop;
      when others =>
        null;
    end case;
    end if;
  end if;
end process;

state_handling : process(clock,reset)
begin
  if reset = '1' then
    state <= st_ready;
  elsif rising_edge(clock) then
    if ready_sig = '1' then
      case op is
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
        when op_floatadd =>
          if data_in(30 downto 23) = X"FF" then
            -- Inf or NaN
            state <= st_in_status;
          elsif data_in = X"00000000" then
            state <= st_ready;
          else
            state <= st_in_float0;
          end if;
        when others =>
          state <= st_ready;
      end case;
    else
    case state is
      when st_add0 | st_in_float0 =>
        state <= st_add1;
      when st_add1 =>
        state <= st_add2;
      when st_add2 =>
        state <= st_fixcarry;
      when st_out_float0 =>
        state <= st_out_float1;
      when st_out_float1 =>
        state <= st_out_float2;
      when st_out_float2 =>
        state <= st_out_float3;
      when st_out_float3 =>
        state <= st_out_float4;
      when st_out_float4 =>
        state <= st_out_float5;
      when st_out_float5 =>
        if exp >= 255 or allmask(NUMBLOCKS) = '0' then
          state <= st_out_float_inf;
        elsif exp <= 0 then
          state <= st_out_float_denormal;
        else
          state <= st_out_float_normal;
        end if;
      when st_out_block0 =>
        state <= st_out_block1;
      when others =>
        state <= st_ready;
    end case;
    end if;
  end if;
end process;

get_input : process(clock,reset)
  variable tmp : addblock;
begin
  if reset = '1' then
    input <= (others => '0');
    sig_sign <= '0';
  elsif rising_edge(clock) then
    if ready_sig = '1' then
      if op = op_add and sign = '1' then
        input <= addblock(unsigned(not data_in) + 1);
      elsif op = op_floatadd then
        shift_cnt <= to_integer(unsigned(data_in(27 downto 23)));
        if data_in(30 downto 23) = X"00" then
          input <= X"0000000000"&data_in(22 downto 0)&"0"; -- denormalized value
        elsif data_in(30 downto 23) = X"FF" then
          -- Inf or NaN, set overflow flag
          -- we will be executing an op_writeflags
          input <= X"0000000000020002";
        else
          input <= X"0000000000"&"1"&data_in(22 downto 0);
        end if;
      else
        input <= data_in;
      end if;
      if op = op_floatadd then
        sig_sign <= sign xor data_in(31);
      else
        sig_sign <= sign;
      end if;
    else
    case state is
      when st_in_float0 =>
        input <= addblock(unsigned(input) sll shift_cnt);
      when others =>
        null;
    end case;
    end if;
  end if;
end process;

end behaviour;
