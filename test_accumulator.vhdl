library ieee;
use ieee.std_logic_1164.all;
use accumulator_types.all;

entity test_accumulator is
end test_accumulator;

architecture behaviour of test_accumulator is
  signal acc_ready : std_logic;
  signal acc_reset : std_logic;
  signal acc_clock : std_logic := '0';
  signal acc_op : operation;
  signal acc_value : addblock;
  signal acc_pos : position_t;
  signal acc_sign : std_logic;
  signal acc_res : subblock;
  signal testcycle : integer := 0;

  constant NUMTESTS : integer := 10;
  type ops_t is array (0 to NUMTESTS - 1) of operation;
  constant ops : ops_t := (
    op_nop, op_floatadd, op_floatadd, op_floatadd, op_readfloat,
    op_add, op_add, op_add, op_readblock, op_readfloat
  );

  type datas_t is array (0 to NUMTESTS - 1) of addblock;
  constant datas : datas_t := (
    (others => 'Z'), X"000000003f800000", X"0000000040000000", X"00000000c0a00000", (others => '1'),
    X"0123456789abcdef", X"19acdefffffff000", (others => '1'), (others => 'Z'), (others => 'Z')
  );

  constant pos0 : position_t := "000000000";
  constant pos1 : position_t := "0"&X"01";
  constant pos3 : position_t := "0"&X"03";

  type poss_t is array (0 to NUMTESTS - 1) of position_t;
  constant poss : poss_t := (
    pos0, pos0, pos0, pos0, pos0,
    pos1, pos1, pos1, pos3, pos0
  );

  type resets_t is array (0 to NUMTESTS - 1) of std_logic;
  constant resets : resets_t := (
    '1', '0', '0', '0', '0', '0', '0', '0', '0', '0'
  );

constant ACC_CLOCK_PERIOD : time := 10ns;

constant RUNTIME : integer := 10;

begin
  acc : accumulator port map (
    ready => acc_ready,
    reset => acc_reset,
    clock => acc_clock,
    sign => acc_sign,
    data_in => acc_value,
    data_out => acc_res,
    pos => acc_pos,
    op => acc_op
  );

  process(acc_clock)
  begin
    assert testcycle < RUNTIME report "Test Done";
    if (rising_edge(acc_clock) and testcycle < NUMTESTS) then
      acc_reset <= resets(testcycle);
      acc_value <= datas(testcycle);
      acc_pos <= poss(testcycle);
      acc_op <= ops(testcycle);
      acc_sign <= '0';
      if acc_ready = '1' or resets(testcycle) = '1' then
        testcycle <= testcycle + 1;
      end if;
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
