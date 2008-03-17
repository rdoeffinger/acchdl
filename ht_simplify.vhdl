--! \file
--! \brief code to simplify HyperTransport handling
--! \author Reimar Döffinger
--! \date 2007,2008
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.accumulator_types.all;
use work.ht_constants.all;

--! \brief module to simplify handling of HyperTransport posted and nonposted queues.
--!
--! This module simplifies HyperTransport handling by merging the posted
--! and non-posted queues into a single command queue, handling the
--! data_complete signals, avoiding "empty" signals by generating nop
--! commands instead and splitting multi-dword writes into multiple writes.
--! It does not handle byte-size writes correctly yet.
--! Ideally, it would also handle the response queue and e.g. split
--! multi-dword reads into multiple reads and compose a single reply packet.
entity ht_simplify is
  port(
    reset_n : in std_logic;
    clock : in std_logic;

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

    cmd_stop : in std_logic; --! if set, output the same command during the next cycle
    cmd : out std_logic_vector(CMD_LEN - 1 downto 0); --! current HyperTransport command, or 0 if none available
    cmd_needs_reply : out std_logic; --! set if the command needs a reply (reads, non-posted commands)
    tag : out std_logic_vector(TAG_LEN - 1 downto 0); --! tag associated with current command, if any
    addr : out std_logic_vector(ADDR_LEN - 1 downto 0); --! address associated with current command, if any
    data : out std_logic_vector(31 downto 0) --! data associated with current command, if any
  );
end entity;

--! actual implementation of the ht_simplify module
architecture behaviour of ht_simplify is
alias posted_cmd_in_cmd       : std_logic_vector(CMD_LEN  - 1 downto 0) is posted_cmd_in(   CMD_OFFSET  + CMD_LEN  - 1 downto CMD_OFFSET);
alias posted_cmd_in_tag       : std_logic_vector(TAG_LEN  - 1 downto 0) is posted_cmd_in(   TAG_OFFSET  + TAG_LEN  - 1 downto TAG_OFFSET);
alias posted_cmd_in_count     : std_logic_vector(COUNT_LEN- 1 downto 0) is posted_cmd_in( COUNT_OFFSET  + COUNT_LEN- 1 downto COUNT_OFFSET);
alias posted_cmd_in_addr      : std_logic_vector(ADDR_LEN - 1 downto 0) is posted_cmd_in(   ADDR_OFFSET + ADDR_LEN - 1 downto ADDR_OFFSET);
alias nonposted_cmd_in_cmd    : std_logic_vector(CMD_LEN  - 1 downto 0) is nonposted_cmd_in(CMD_OFFSET  + CMD_LEN  - 1 downto CMD_OFFSET);
alias nonposted_cmd_in_tag    : std_logic_vector(TAG_LEN  - 1 downto 0) is nonposted_cmd_in(TAG_OFFSET  + TAG_LEN  - 1 downto TAG_OFFSET);
alias nonposted_cmd_in_count  : std_logic_vector(COUNT_LEN- 1 downto 0) is nonposted_cmd_in(COUNT_OFFSET+ COUNT_LEN- 1 downto COUNT_OFFSET);
alias nonposted_cmd_in_addr   : std_logic_vector(ADDR_LEN - 1 downto 0) is nonposted_cmd_in(ADDR_OFFSET + ADDR_LEN - 1 downto ADDR_OFFSET);

signal new_cmd : std_logic_vector(CMD_LEN - 1 downto 0);
signal new_cmd_needs_reply : std_logic;
signal new_tag : std_logic_vector(TAG_LEN - 1 downto 0);
signal new_addr : std_logic_vector(ADDR_LEN - 1 downto 0);
signal new_data : std_logic_vector(31 downto 0);
signal last_cmd : std_logic_vector(CMD_LEN - 1 downto 0);
signal last_cmd_needs_reply : std_logic;
signal last_tag : std_logic_vector(TAG_LEN - 1 downto 0);
signal last_addr : std_logic_vector(ADDR_LEN - 1 downto 0);
signal last_data : std_logic_vector(31 downto 0);

signal last_p_cmd_avail : std_logic;
signal last_p_cmd : std_logic_vector(CMD_LEN - 1 downto 0);
signal last_p_count : unsigned(COUNT_LEN - 1 downto 0);
signal last_p_addr : std_logic_vector(ADDR_LEN - 1 downto 0);
signal last_p_data_avail : std_logic;
signal last_p_data : std_logic_vector(63 downto 0);

signal p_cmd_avail : std_logic;
signal p_cmd : std_logic_vector(CMD_LEN - 1 downto 0);
signal p_count : unsigned(COUNT_LEN - 1 downto 0);
signal p_addr : std_logic_vector(ADDR_LEN - 1 downto 0);
signal p_data_avail : std_logic;
signal p_data : std_logic_vector(63 downto 0);

signal p_cmd_stop : std_logic;
signal p_data_stop : std_logic;
signal p_done : unsigned(COUNT_LEN - 1 downto 0);

signal last_np_cmd_avail : std_logic;
signal last_np_cmd : std_logic_vector(CMD_LEN - 1 downto 0);
signal last_np_count : unsigned(COUNT_LEN - 1 downto 0);
signal last_np_tag : std_logic_vector(TAG_LEN - 1 downto 0);
signal last_np_addr : std_logic_vector(ADDR_LEN - 1 downto 0);
signal last_np_data_avail : std_logic;
signal last_np_data : std_logic_vector(63 downto 0);

signal np_cmd_avail : std_logic;
signal np_cmd : std_logic_vector(CMD_LEN - 1 downto 0);
signal np_count : unsigned(COUNT_LEN - 1 downto 0);
signal np_tag : std_logic_vector(TAG_LEN - 1 downto 0);
signal np_addr : std_logic_vector(ADDR_LEN - 1 downto 0);
signal np_data_avail : std_logic;
signal np_data : std_logic_vector(63 downto 0);

signal np_cmd_stop : std_logic;
signal np_data_stop : std_logic;
signal np_done : unsigned(COUNT_LEN - 1 downto 0);

  --! determine if a give HT command has data attached
  function needs_data(cmd : in std_logic_vector(CMD_LEN - 1 downto 0)) return boolean is
    variable res : boolean;
  begin
    res := cmd(4 downto 3) = "01"; -- write request
    res := res or cmd = "110000"; -- read response
    res := res or cmd = "111101"; -- atomic read-modify-write
    return res;
  end;

begin
  cmd <= last_cmd when cmd_stop = '1' else new_cmd;
  cmd_needs_reply <= last_cmd_needs_reply when cmd_stop = '1' else new_cmd_needs_reply;
  tag <= last_tag when cmd_stop = '1' else new_tag;
  addr <= last_addr when cmd_stop = '1' else new_addr;
  data <= last_data when cmd_stop = '1' else new_data;

  posted_cmd_get     <= not p_cmd_stop;
  posted_data_get    <= not p_data_stop;
  nonposted_cmd_get  <= not np_cmd_stop;
  nonposted_data_get <= not np_data_stop;

  p_cmd_avail   <= last_p_cmd_avail   when p_cmd_stop   = '1' else not posted_cmd_empty;
  p_cmd         <= last_p_cmd         when p_cmd_stop   = '1' else posted_cmd_in_cmd;
  p_count       <= last_p_count       when p_cmd_stop   = '1' else unsigned(posted_cmd_in_count);
  p_addr        <= last_p_addr        when p_cmd_stop   = '1' else posted_cmd_in_addr;
  p_data_avail  <= last_p_data_avail  when p_data_stop  = '1' else not posted_data_empty;
  p_data        <= last_p_data        when p_data_stop  = '1' else posted_data_in;

  np_cmd_avail  <= last_np_cmd_avail  when np_cmd_stop  = '1' else not nonposted_cmd_empty;
  np_cmd        <= last_np_cmd        when np_cmd_stop  = '1' else nonposted_cmd_in_cmd;
  np_count      <= last_np_count      when np_cmd_stop  = '1' else unsigned(nonposted_cmd_in_count);
  np_tag        <= last_np_tag        when np_cmd_stop  = '1' else nonposted_cmd_in_tag;
  np_addr       <= last_np_addr       when np_cmd_stop  = '1' else nonposted_cmd_in_addr;
  np_data_avail <= last_np_data_avail when np_data_stop = '1' else not nonposted_data_empty;
  np_data       <= last_np_data       when np_data_stop = '1' else nonposted_data_in;

  process(clock,reset_n)
  begin
    if reset_n = '0' then
      last_p_cmd_avail   <= '0';
      last_p_data_avail  <= '0';
      last_np_cmd_avail  <= '0';
      last_np_data_avail <= '0';
    elsif rising_edge(clock) then
      if p_cmd_stop = '0' then
        last_p_cmd_avail   <= not posted_cmd_empty;
        last_p_cmd         <= posted_cmd_in_cmd;
        last_p_count       <= unsigned(posted_cmd_in_count);
        last_p_addr        <= posted_cmd_in_addr;
      end if;
      if p_data_stop = '0' then
        last_p_data_avail  <= not posted_data_empty;
        last_p_data        <= posted_data_in;
      end if;

      if np_cmd_stop = '0' then
        last_np_cmd_avail  <= not nonposted_cmd_empty;
        last_np_cmd        <= nonposted_cmd_in_cmd;
        last_np_count      <= unsigned(nonposted_cmd_in_count);
        last_np_tag        <= nonposted_cmd_in_tag;
        last_np_addr       <= nonposted_cmd_in_addr;
      end if;
      if np_data_stop = '0' then
        last_np_data_avail <= not nonposted_data_empty;
        last_np_data       <= nonposted_data_in;
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

  process(clock,reset_n)
  begin
    if reset_n = '0' then
      posted_data_complete <= '0';
      nonposted_data_complete <= '0';
      p_cmd_stop <= '0';
      p_data_stop <= '0';
      np_cmd_stop <= '0';
      np_data_stop <= '0';
      p_done <= (others => '0');
      np_done <= (others => '0');
      new_cmd <= (others => '0');
      new_cmd_needs_reply <= '0';
      new_tag <= (others => '0');
      new_addr <= (others => '0');
      new_data <= (others => '0');
    elsif rising_edge(clock) then
      p_cmd_stop <= p_cmd_avail;
      p_data_stop <= p_data_avail;
      posted_data_complete <= '0';
      np_cmd_stop <= np_cmd_avail;
      np_data_stop <= np_data_avail;
      nonposted_data_complete <= '0';
      if cmd_stop = '0' then
        if p_cmd_avail = '1' and
          (p_data_avail = '1' or not needs_data(p_cmd)) then
          new_cmd <= p_cmd;
          new_cmd_needs_reply <= '0';
          new_tag <= (others => '0');
          new_addr <= std_logic_vector(unsigned(p_addr) + p_done);
          if p_done(0) = '0' then
            new_data <= p_data(31 downto 0);
          else
            new_data <= p_data(63 downto 32);
          end if;
          if needs_data(p_cmd) and p_done = p_count then
            posted_data_complete <= '1';
          end if;
          if needs_data(p_cmd) and (p_done(0) = '1' or p_done = p_count) then
            p_data_stop <= '0';
          end if;
          if not needs_data(p_cmd) or p_done = p_count then
            p_cmd_stop <= '0';
            p_done <= (others => '0');
          else
            p_done <= p_done + 1;
          end if;
        elsif np_cmd_avail = '1' and
             (np_data_avail = '1' or not needs_data(np_cmd)) then
          new_cmd <= np_cmd;
          new_cmd_needs_reply <= '1';
          new_tag <= np_tag;
          new_addr <= std_logic_vector(unsigned(np_addr) + np_done);
          if np_done(0) = '0' then
            new_data <= np_data(31 downto 0);
          else
            new_data <= np_data(63 downto 32);
          end if;
          if needs_data(np_cmd) and np_done = np_count then
            nonposted_data_complete <= '1';
          end if;
          if needs_data(np_cmd) and (np_done(0) = '1' or np_done = np_count) then
            np_data_stop <= '0';
          end if;
          if not needs_data(np_cmd) or np_done = np_count then
            np_cmd_stop <= '0';
            np_done <= (others => '0');
          else
            np_done <= np_done + 1;
          end if;
        else
          new_cmd <= (others => '0');
          new_cmd_needs_reply <= '0';
          new_tag <= (others => '0');
          new_addr <= (others => '0');
          new_data <= (others => '0');
        end if;
      end if;
    end if;
  end process;
end architecture;
