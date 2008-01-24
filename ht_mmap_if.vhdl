library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use accumulator_types.all;

entity ht_mmap_if is
  port(
    reset_n : in std_logic;
    clock : in std_logic;
    UnitID : in std_logic_vector(4 downto 0);

    nonposted_cmd_in : in std_logic_vector(95 downto 0);
    nonposted_data_in : in std_logic_vector(63 downto 0);
    nonposted_cmd_empty : in std_logic;
    nonposted_data_empty : in std_logic;
    nonposted_cmd_get : out std_logic;
    nonposted_data_get : out std_logic;
    nonposted_data_complete : out std_logic;

    posted_cmd_in : in std_logic_vector(95 downto 0);
    posted_data_in : in std_logic_vector(63 downto 0);
    posted_cmd_empty : in std_logic;
    posted_data_empty : in std_logic;
    posted_cmd_get : out std_logic;
    posted_data_get : out std_logic;
    posted_data_complete : out std_logic;

    response_cmd_out : out std_logic_vector(95 downto 0);
    response_data_out : out std_logic_vector(63 downto 0);
    response_cmd_full : in std_logic;
    response_data_full : in std_logic;
    response_cmd_put : out std_logic;
    response_data_put : out std_logic
  );
end entity;

architecture behaviour of ht_mmap_if is
constant CMD_OFFSET  : integer :=  0;
constant CMD_LEN     : integer :=  6;
constant TAG_OFFSET  : integer := 16;
constant TAG_LEN     : integer :=  5;
constant COUNT_OFFSET: integer := 22;
constant COUNT_LEN   : integer :=  4;
constant ADDR_OFFSET : integer := 26;
constant ADDR_LEN    : integer := 62;

alias posted_cmd_in_cmd       : std_logic_vector(CMD_LEN  - 1 downto 0) is posted_cmd_in(   CMD_OFFSET  + CMD_LEN  - 1 downto CMD_OFFSET);
alias posted_cmd_in_tag       : std_logic_vector(TAG_LEN  - 1 downto 0) is posted_cmd_in(   TAG_OFFSET  + TAG_LEN  - 1 downto TAG_OFFSET);
alias posted_cmd_in_count     : std_logic_vector(COUNT_LEN- 1 downto 0) is posted_cmd_in( COUNT_OFFSET  + COUNT_LEN- 1 downto COUNT_OFFSET);
alias posted_cmd_in_addr      : std_logic_vector(ADDR_LEN - 1 downto 0) is posted_cmd_in(   ADDR_OFFSET + ADDR_LEN - 1 downto ADDR_OFFSET);
alias nonposted_cmd_in_cmd    : std_logic_vector(CMD_LEN  - 1 downto 0) is nonposted_cmd_in(CMD_OFFSET  + CMD_LEN  - 1 downto CMD_OFFSET);
alias nonposted_cmd_in_tag    : std_logic_vector(TAG_LEN  - 1 downto 0) is nonposted_cmd_in(TAG_OFFSET  + TAG_LEN  - 1 downto TAG_OFFSET);
alias nonposted_cmd_in_addr   : std_logic_vector(ADDR_LEN - 1 downto 0) is nonposted_cmd_in(ADDR_OFFSET + ADDR_LEN - 1 downto ADDR_OFFSET);

alias response_cmd_out_cmd    : std_logic_vector(CMD_LEN  - 1 downto 0) is response_cmd_out(CMD_OFFSET  + CMD_LEN  - 1 downto CMD_OFFSET);
alias response_cmd_out_unitid : std_logic_vector(5        - 1 downto 0) is response_cmd_out(12 downto 8);
alias response_cmd_out_tag    : std_logic_vector(TAG_LEN  - 1 downto 0) is response_cmd_out(TAG_OFFSET  + TAG_LEN  - 1 downto TAG_OFFSET);
alias response_cmd_out_format : std_logic_vector(3        - 1 downto 0) is response_cmd_out(95 downto 93);

constant REGBITS : integer := 3;
constant NUMREGS : integer := 2**REGBITS;
type data_array_t is array(0 to NUMREGS-1) of addblock;
signal data_in : data_array_t;
type short_data_array_t is array(0 to NUMREGS-1) of subblock;
signal data_out : short_data_array_t;
signal ready : std_logic_vector(NUMREGS-1 downto 0);
type operation_array_t is array(0 to NUMREGS-1) of operation;
signal op : operation_array_t;
signal accreset : std_logic;
signal sign : std_logic_vector(NUMREGS-1 downto 0);
type position_array_t is array(0 to NUMREGS-1) of position_t;
signal pos : position_array_t;
type state_t is (START, READ_WAIT, READ_WAIT2, READ_WAIT3, READ_WAIT4);
signal state : state_t;
signal read_reg : natural range 0 to NUMREGS - 1;
signal cmd_stop : std_logic;
signal new_cmd : std_logic_vector(CMD_LEN - 1 downto 0);
signal new_cmd_needs_reply : std_logic;
signal new_tag : std_logic_vector(TAG_LEN - 1 downto 0);
signal new_addr : std_logic_vector(ADDR_LEN - 1 downto 0);
signal new_data : std_logic_vector(63 downto 0);
signal last_cmd : std_logic_vector(CMD_LEN - 1 downto 0);
signal last_cmd_needs_reply : std_logic;
signal last_tag : std_logic_vector(TAG_LEN - 1 downto 0);
signal last_addr : std_logic_vector(ADDR_LEN - 1 downto 0);
signal last_data : std_logic_vector(63 downto 0);
signal cmd : std_logic_vector(CMD_LEN - 1 downto 0);
signal cmd_needs_reply : std_logic;
signal tag : std_logic_vector(TAG_LEN - 1 downto 0);
signal addr : std_logic_vector(ADDR_LEN - 1 downto 0);
signal cmd_reg : integer range 0 to NUMREGS - 1;
signal data : std_logic_vector(63 downto 0);

begin
  regs : for I in 0 to NUMREGS-1 generate
  reg0 : accumulator port map (
    ready => ready(I),
    reset => accreset,
    clock => clock,
    data_in => data_in(I),
    data_out => data_out(I),
    sign => sign(I),
    pos => pos(I),
    op => op(I)
  );
  end generate;

  accreset <= not reset_n;
  nonposted_data_complete <= '0';
  response_cmd_out(7 downto 6) <= "00";
  response_cmd_out(15 downto 13) <= "000";
  response_cmd_out(92 downto 21) <= X"000000000000000000";
  response_cmd_out_unitid <= UnitID;

  cmd <= last_cmd when cmd_stop = '1' else new_cmd;
  cmd_needs_reply <= last_cmd_needs_reply when cmd_stop = '1' else new_cmd_needs_reply;
  tag <= last_tag when cmd_stop = '1' else new_tag;
  addr <= last_addr when cmd_stop = '1' else new_addr;
  cmd_reg <= to_integer(unsigned(addr(10 + REGBITS downto 10)));
  data <= last_data when cmd_stop = '1' else new_data;

  handle_reply : process(clock,reset_n)
  begin
    if reset_n = '0' then
      response_cmd_put <= '0';
      response_data_put <= '0';
    elsif rising_edge(clock) then
      if state = START then
        if cmd(5 downto 4) = "01" then
          response_cmd_out_cmd <= "110000"; -- read response
          response_cmd_out_format <= "011"; -- 32 bit, data attached
        else
          response_cmd_out_cmd <= "110011"; -- target done
          response_cmd_out_format <= "010"; -- 32 bit, no data attached
        end if;
        response_cmd_out_tag <= tag;
      elsif state = READ_WAIT3 then
        response_data_out <= X"00000000"&data_out(read_reg);
      end if;
      if state = READ_WAIT4 and response_cmd_full = '0' and response_data_full = '0' then
        response_cmd_put <= '1';
        response_data_put <= response_cmd_out_format(0);
      else
        response_cmd_put <= '0';
        response_data_put <= '0';
      end if;
    end if;
  end process;

  set_state : process(clock,reset_n)
  begin
    if reset_n = '0' then
      state <= START;
    elsif rising_edge(clock) then
      if state = START and cmd_needs_reply = '1' and ready(cmd_reg) = '1' then
        state <= READ_WAIT;
      elsif state = READ_WAIT and ready(read_reg) = '1' then
        state <= READ_WAIT2;
      elsif state = READ_WAIT2 and ready(read_reg) = '1' then
        state <= READ_WAIT3;
      elsif state = READ_WAIT3 then
        state <= READ_WAIT4;
      elsif state = READ_WAIT4 and response_cmd_full = '0' and response_data_full = '0' then
        state <= START;
      end if;
    end if;
  end process;

  set_read_reg : process(clock,reset_n)
  begin
    if reset_n = '0' then
      read_reg <= 0;
    elsif rising_edge(clock) then
      if state = START and cmd(5 downto 4) = "01" and ready(cmd_reg) = '1' then
        read_reg <= cmd_reg;
      end if;
    end if;
  end process;

  move_last : process(clock,reset_n)
  begin
    if reset_n = '0' then
      last_cmd <= (others => '0');
      last_cmd_needs_reply <= '0';
      last_tag <= (others => '0');
      last_addr <= (others => '0');
      last_data <= (others => '0');
    elsif rising_edge(clock) then
      if cmd_stop = '0' then
        last_cmd <= new_cmd;
        last_cmd_needs_reply <= new_cmd_needs_reply;
        last_tag <= new_tag;
        last_addr <= new_addr;
        last_data <= new_data;
      end if;
    end if;
  end process;

  set_stop : process(clock,reset_n)
  begin
    if reset_n = '0' then
	   cmd_stop <= '0';
    elsif rising_edge(clock) then
      if state = START then
        cmd_stop <= not ready(cmd_reg);
      else
        cmd_stop <= '1';
      end if;
    end if;
  end process;

  set_simplestuff : process(clock,reset_n)
  begin
    if reset_n = '0' then
      null;
    elsif rising_edge(clock) then
      if ready(cmd_reg) = '1' then
        data_in(cmd_reg) <= data;
        pos(cmd_reg) <= not addr(8) & addr(7 downto 0);
        sign(cmd_reg) <= addr(8);
      end if;
    end if;
  end process;

  set_op : process(clock,reset_n)
  begin
    if reset_n = '0' then
      for regnum in 0 to NUMREGS-1 loop
        op(regnum) <= op_nop;
      end loop;
    elsif rising_edge(clock) then
      for regnum in 0 to NUMREGS-1 loop
        if ready(regnum) = '1' then
          if regnum = cmd_reg and state = START then
            if cmd(4 downto 2) = "011" then
              if addr(9) = '1' then
                if addr(8 downto 0) = "000000000" then
                  op(regnum) <= op_writeflags;
                else
                  op(regnum) <= op_writeblock;
                end if;
              else
                op(regnum) <= op_floatadd;
              end if;
            elsif cmd(5 downto 4) = "01" then
              if addr(9) = '1' then
                if addr(8 downto 0) = "000000000" then
                  op(regnum) <= op_readflags;
                else
                  op(regnum) <= op_readblock;
                end if;
              else
                op(regnum) <= op_readfloat;
              end if;
            else
              op(regnum) <= op_nop;
            end if;
          else
            op(regnum) <= op_nop;
          end if;
        end if;
      end loop;
    end if;
  end process;

  process(clock,reset_n)
  variable buffered_posted_cmd_avail : std_logic;
  variable buffered_posted_cmd : std_logic_vector(CMD_LEN - 1 downto 0);
  variable buffered_posted_addr : std_logic_vector(ADDR_LEN - 1 downto 0);
  variable buffered_posted_data_avail : std_logic;
  variable buffered_posted_data : std_logic_vector(63 downto 0);
  variable buffered_nonposted_cmd_avail : std_logic;
  variable buffered_nonposted_cmd : std_logic_vector(CMD_LEN - 1 downto 0);
  variable buffered_nonposted_tag : std_logic_vector(TAG_LEN - 1 downto 0);
  variable buffered_nonposted_addr : std_logic_vector(ADDR_LEN - 1 downto 0);
  variable buffered_nonposted_data_avail : std_logic;
  variable buffered_nonposted_data : std_logic_vector(63 downto 0);
  function needs_data(cmd : in std_logic_vector(CMD_LEN - 1 downto 0)) return boolean is
    variable res : boolean;
  begin
    res := cmd(4 downto 3) = "01"; -- write request
	 res := res or cmd = "110000"; -- read response
	 res := res or cmd = "111101"; -- atomic read-modify-write
	 return res;
  end;
  begin
    if reset_n = '0' then
      posted_data_complete <= '0';
      posted_cmd_get <= '1';
      posted_data_get <= '1';
      nonposted_cmd_get <= '1';
      nonposted_data_get <= '1';
      buffered_posted_cmd_avail := '0';
      buffered_posted_data_avail := '0';
      buffered_nonposted_cmd_avail := '0';
      buffered_nonposted_data_avail := '0';
      new_cmd <= (others => '0');
      new_cmd_needs_reply <= '0';
      new_tag <= (others => '0');
      new_addr <= (others => '0');
      new_data <= (others => '0');
    elsif rising_edge(clock) then
      if buffered_posted_cmd_avail = '0' then
        buffered_posted_cmd := posted_cmd_in_cmd;
        buffered_posted_addr := posted_cmd_in_addr;
      end if;
      buffered_posted_cmd_avail := buffered_posted_cmd_avail or not posted_cmd_empty;

      if buffered_posted_data_avail = '0' then
        buffered_posted_data := posted_data_in;
      end if;
      posted_data_complete <= not buffered_posted_data_avail and not posted_data_empty;
      buffered_posted_data_avail := buffered_posted_data_avail or not posted_data_empty;

      if buffered_nonposted_cmd_avail = '0' then
        buffered_nonposted_cmd := nonposted_cmd_in_cmd;
        buffered_nonposted_tag := nonposted_cmd_in_tag;
        buffered_nonposted_addr := nonposted_cmd_in_addr;
      end if;
      buffered_nonposted_cmd_avail := buffered_nonposted_cmd_avail or not nonposted_cmd_empty;

      if buffered_nonposted_data_avail = '0' then
        buffered_nonposted_data := nonposted_data_in;
      end if;
      buffered_nonposted_data_avail := buffered_nonposted_data_avail or not nonposted_data_empty;

      if cmd_stop = '0' then
        if buffered_posted_cmd_avail = '1' and
          (buffered_posted_data_avail = '1' or not needs_data(buffered_posted_cmd)) then
          buffered_posted_cmd_avail := '0';
          buffered_posted_data_avail := '0';
          new_cmd <= buffered_posted_cmd;
          new_cmd_needs_reply <= '0';
          new_tag <= (others => '0');
          new_addr <= buffered_posted_addr;
          new_data <= buffered_posted_data;
        elsif buffered_nonposted_cmd_avail = '1' and
             (buffered_nonposted_data_avail = '1' or not needs_data(buffered_nonposted_cmd)) then
          buffered_nonposted_cmd_avail := '0';
          buffered_nonposted_data_avail := '0';
          new_cmd <= buffered_nonposted_cmd;
          new_cmd_needs_reply <= '1';
          new_tag <= buffered_nonposted_tag;
          new_addr <= buffered_nonposted_addr;
          new_data <= buffered_nonposted_data;
        else
          new_cmd <= (others => '0');
          new_cmd_needs_reply <= '0';
          new_tag <= (others => '0');
          new_addr <= (others => '0');
          new_data <= (others => '0');
        end if;
      end if;

      posted_cmd_get <= not buffered_posted_cmd_avail;
      posted_data_get <= not buffered_posted_data_avail;
      nonposted_cmd_get <= not buffered_nonposted_cmd_avail;
      nonposted_data_get <= not buffered_nonposted_data_avail;
    end if;
  end process;
end architecture;
