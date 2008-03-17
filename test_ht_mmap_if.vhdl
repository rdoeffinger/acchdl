library ieee;
use ieee.std_logic_1164.all;
use work.ht_mmap_if_types.all;

entity test_ht_mmap_if is
end test_ht_mmap_if;

architecture behaviour of test_ht_mmap_if is
  constant NUMTESTS : integer := 10;

  constant pcemptys : std_logic_vector(0 to NUMTESTS - 1) := (
    '1', '0', '1', '1', '0', '0', '0', '1', '1', '1'
  );

  constant pdemptys : std_logic_vector(0 to NUMTESTS - 1) := (
    '1', '0', '1', '1', '0', '0', '0', '1', '1', '1'
  );

  constant resets : std_logic_vector(0 to NUMTESTS - 1) := (
    '1', '0', '0', '0', '0', '0', '0', '0', '0', '0'
  );

  type addrs_t is array (0 to NUMTESTS - 1) of std_logic_vector(15 downto 0);
  constant p_addrs : addrs_t := (
    X"0000", X"0000", X"0000", X"0001", X"0001", X"0001", X"0400", X"0400",
    X"0400", X"0400"
  );

  type datas_t is array (0 to NUMTESTS - 1) of std_logic_vector(63 downto 0);
  constant p_datas : datas_t := (
    X"00000000ca000000", X"00000000ca000000", X"00000000ca000000", X"00000000ca000800",
    X"00000000ca000800", X"00000000ca000800", X"00000000ca000000", X"00000000ca000000",
    X"00000000ca000000", X"00000000ca000000"
  );

constant ACC_CLOCK_PERIOD : time := 10ns;

constant RUNTIME : integer := 10;

  signal if_reset_n : std_logic := '0';
  signal if_clock : std_logic;

  signal if_npcmd : std_logic_vector(95 downto 0);
  signal if_npdata : std_logic_vector(63 downto 0);
  signal if_npcempty : std_logic := '0';
  signal if_npdempty : std_logic := '0';
  signal if_npcget : std_logic;
  signal if_npdget : std_logic;
  signal if_npdc : std_logic;

  signal if_pcmd : std_logic_vector(95 downto 0);
  signal if_pdata : std_logic_vector(63 downto 0);
  signal if_pcempty : std_logic := '0';
  signal if_pdempty : std_logic := '0';
  signal if_pcget : std_logic;
  signal if_pdget : std_logic;
  signal if_pdc : std_logic;

  signal if_rcmd : std_logic_vector(95 downto 0);
  signal if_rdata : std_logic_vector(63 downto 0);
  signal if_rcfull : std_logic;
  signal if_rdfull : std_logic;
  signal if_rcput : std_logic;
  signal if_rdput : std_logic;
begin
  iface : ht_mmap_if port map (
    reset_n => if_reset_n,
    clock => if_clock,
    UnitID => "10101",

    nonposted_cmd_in => if_npcmd,
    nonposted_data_in => if_npdata,
    nonposted_cmd_empty => if_npcempty,
    nonposted_data_empty => if_npdempty,
    nonposted_cmd_get => if_npcget,
    nonposted_data_get => if_npdget,
    nonposted_data_complete => if_npdc,

    posted_cmd_in => if_pcmd,
    posted_data_in => if_pdata,
    posted_cmd_empty => if_pcempty,
    posted_data_empty => if_pdempty,
    posted_cmd_get => if_pcget,
    posted_data_get => if_pdget,
    posted_data_complete => if_pdc,

    response_cmd_out => if_rcmd,
    response_data_out => if_rdata,
    response_cmd_full => if_rcfull,
    response_data_full => if_rdfull,
    response_cmd_put => if_rcput,
    response_data_put => if_rdput
  );

  if_npcmd(95 downto 42) <= (others => '0');
  if_npcmd(41 downto 26) <= (others => '0');
  if_npcmd(25 downto 0)  <= "00"&X"000014";
  if_npdata <= X"0000000000000000";
  if_pcmd(95 downto 42) <= (others => '0');
  if_pcmd(25 downto 0)  <= "00"&X"00002c";
  if_rcfull <= '0';
  if_rdfull <= '0';

  process(if_clock)
    variable testcycle : integer := 0;
  begin
    assert testcycle < RUNTIME report "Test Done";
    if rising_edge(if_clock) then
      if_reset_n <= '1';
      if testcycle < NUMTESTS then
        if_npcempty <= '0';
        if_npdempty <= '0';
        if_pcempty <= pcemptys(testcycle);
        if_pdempty <= pdemptys(testcycle);
        if_pcmd(41 downto 26) <= p_addrs(testcycle);
        if_pdata <= p_datas(testcycle);
      else
        if_npcempty <= '1';
        if_npdempty <= '1';
        if_pcempty <= '1';
        if_pdempty <= '1';
        if_pcmd(41 downto 26) <= (others => '0');
        if_pdata <= X"00000000ca000000";
      end if;
      testcycle := testcycle + 1;
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
