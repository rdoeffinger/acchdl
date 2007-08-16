library ieee;
use ieee.std_logic_1164.all;
use accumulator_types.all;

entity test_accumulator is
end test_accumulator;

architecture behaviour of test_accumulator is
  signal acc_reset : std_logic;
  signal acc_clock : std_logic := '0';
  signal acc_op : operation;
  signal acc_value : addblock := (others => 'Z');
  signal acc_pos : position;
  signal acc_read : std_logic;
  signal acc_sign : std_logic;
  signal testcycle : integer := 0;

  constant NUMTESTS : integer := 5;
  type ops_t is array (0 to NUMTESTS - 1) of operation;
  constant ops : ops_t := (
    op_nop, op_add, op_add, op_add, op_output
  );

  type datas_t is array (0 to NUMTESTS - 1) of addblock;
  constant datas : datas_t := (
    (others => 'Z'), (others => '1'), (others => '1'), (others => '1'),
    (others => 'Z')
  );

  type poss_t is array (0 to NUMTESTS - 1) of position;
  constant poss : poss_t := (
    0, 5, 5, 5, 7
  );

  type reads_t is array (0 to NUMTESTS - 1) of std_logic;
  constant reads : reads_t := (
    '0', '0', '0', '0', '1'
  );

  type resets_t is array (0 to NUMTESTS - 1) of std_logic;
  constant resets : resets_t := (
    '1', '0', '0', '0', '0'
  );

constant ACC_CLOCK_PERIOD : time := 100ns;

constant RUNTIME : integer := 10;

begin
  acc : accumulator port map (
    reset => acc_reset,
    clock => acc_clock,
    read => acc_read,
    sign => acc_sign,
    data => acc_value,
    pos => acc_pos,
    op => acc_op
  );

  process(acc_clock)
  begin
    assert testcycle < RUNTIME report "Test Done";
    if (rising_edge(acc_clock) and testcycle < NUMTESTS) then
      acc_read  <= reads(testcycle);
      acc_reset <= resets(testcycle);
      acc_value <= datas(testcycle);
      acc_pos <= poss(testcycle);
      acc_op <= ops(testcycle);
      acc_sign <= '0';
      testcycle <= testcycle + 1;
    end if;
  end process;

  clk: process
  begin
    acc_clock <= '1';
    wait for ACC_CLOCK_PERIOD/2;
    acc_clock <= '0';
    wait for ACC_CLOCK_PERIOD/2;
  end process;

end behaviour;
