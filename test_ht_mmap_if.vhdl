library ieee;
use ieee.std_logic_1164.all;
use work.ht_constants.all;
use work.ht_mmap_if_types.all;

entity test_ht_mmap_if is
end test_ht_mmap_if;

architecture behaviour of test_ht_mmap_if is
  constant NUMTESTS : integer := 10;

  constant nopcmd   : std_logic_vector(CMD_LEN - 1 downto 0) := "000000";
  constant writecmd : std_logic_vector(CMD_LEN - 1 downto 0) := "001100";
  constant readcmd  : std_logic_vector(CMD_LEN - 1 downto 0) := "010100";

  type cmds_t is array (0 to NUMTESTS - 1) of std_logic_vector(CMD_LEN - 1 downto 0);
  constant cmds : cmds_t := (
    writecmd, writecmd, writecmd, writecmd, readcmd, readcmd, nopcmd, nopcmd,
    writecmd, readcmd
  );

  type addrs_t is array (0 to NUMTESTS - 1) of std_logic_vector(15 downto 0);
  constant addrs : addrs_t := (
    X"0000", X"0000", X"0000", X"0001", X"0001", X"0001", X"0400", X"0400",
    X"0400", X"0400"
  );

  type datas_t is array (0 to NUMTESTS - 1) of std_logic_vector(31 downto 0);
  constant datas : datas_t := (
    X"ca000000", X"ca000000", X"ca000000", X"ca000800",
    X"ca000800", X"ca000800", X"ca000000", X"ca000000",
    X"ca000000", X"ca000000"
  );

constant ACC_CLOCK_PERIOD : time := 10ns;

constant RUNTIME : integer := 10;

  signal if_reset_n : std_logic := '0';
  signal if_clock : std_logic;

  signal if_cmd : std_logic_vector(CMD_LEN - 1 downto 0);
  signal if_cmd_stop : std_logic;
  signal if_needs_reply : std_logic;
  signal if_final : std_logic;
  signal if_tag : std_logic_vector(TAG_LEN - 1 downto 0);
  signal if_addr : std_logic_vector(ADDR_LEN - 1 downto 0);
  signal if_data : std_logic_vector(31 downto 0);

  signal if_rcmd : std_logic_vector(95 downto 0);
  signal if_rdata : std_logic_vector(63 downto 0);
  signal if_rcfull : std_logic;
  signal if_rdfull : std_logic;
  signal if_rcput : std_logic;
  signal if_rdput : std_logic;

  signal testcycle : integer := 0;
begin
  iface : ht_mmap_if port map (
    reset_n => if_reset_n,
    clock => if_clock,
    UnitID => "10101",

    cmd_stop => if_cmd_stop,
    cmd => if_cmd,
    cmd_needs_reply => if_needs_reply,
    cmd_final => if_final,
    addr => if_addr,
    tag => if_tag,
    data => if_data,

    response_cmd_out => if_rcmd,
    response_data_out => if_rdata,
    response_cmd_full => if_rcfull,
    response_data_full => if_rdfull,
    response_cmd_put => if_rcput,
    response_data_put => if_rdput
  );

  if_addr(if_addr'left downto addrs(0)'length) <= (others => '0');

  if_rcfull <= '0';
  if_rdfull <= '0';
  if_tag <= "0"&X"b";
  if_needs_reply <= '1' when if_cmd = readcmd else '0';

  async : process(testcycle,if_cmd_stop)
    variable idx : integer;
  begin
    idx := testcycle;
    if if_cmd_stop = '1' then
      idx := idx - 1;
    end if;
    if idx = NUMTESTS - 1 then
      if_final <= '1';
    else
      if_final <= '0';
    end if;
    if idx < 0 then
      if_cmd <= (others => '0');
      if_addr(addrs(0)'left downto 0) <= (others => '0');
      if_data <= (others => '0');
    elsif idx < NUMTESTS then
      if_cmd <= cmds(idx);
      if_addr(addrs(0)'left downto 0) <= addrs(idx);
      if_data <= datas(idx);
    else
      if_cmd <= (others => '0');
      if_addr(addrs(0)'left downto 0) <= (others => '0');
      if_data <= X"ca000000";
    end if;
  end process;

  process(if_clock)
  begin
    assert testcycle < RUNTIME report "Test Done";
    if rising_edge(if_clock) then
      if_reset_n <= '1';
      if if_cmd_stop = '0' then
        testcycle <= testcycle + 1;
      end if;
    end if;
  end process;

  clk: process
  begin
    if_clock <= '1';
    wait for ACC_CLOCK_PERIOD/2;
    if_clock <= '0';
    wait for ACC_CLOCK_PERIOD/2;
  end process;

end behaviour;
