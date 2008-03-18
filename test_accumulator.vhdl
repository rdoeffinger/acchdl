--! \file
--! \brief small testbench for ALU code
--! \author Reimar Döffinger
--! \date 2007,2008
library ieee;
use ieee.std_logic_1164.all;
use work.accumulator_types.all;

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

  constant NUMTESTS : integer := 38;
  type ops_t is array (0 to NUMTESTS - 1) of operation;
  constant ops : ops_t := (
    op_nop, op_floatadd, op_floatadd, op_floatadd, op_readfloat,
    op_writeflags,
    op_floatadd, op_floatadd, op_floatadd, op_readfloat,
    op_writeflags,
    op_floatadd, op_floatadd, op_floatadd, op_readfloat,
    op_writeflags,
    op_floatadd, op_floatadd, op_floatadd, op_readfloat,
    op_writeflags,
    op_floatadd, op_floatadd, op_readfloat,
    op_writeflags,
    op_floatadd, op_readfloat,
    op_writeflags,
    op_floatadd, op_floatadd, op_readfloat, op_readfloat,
    op_writeflags,
    op_add, op_add, op_add, op_readblock, op_readfloat
  );

  type datas_t is array (0 to NUMTESTS - 1) of addblock;
  constant datas : datas_t := (
    (others => '0'), X"000000003f800000", X"0000000040200000", X"00000000c0a00000", (others => '1'),
    X"0000000000040004",
    X"00000000457a0000", X"00000000c3960000", X"00000000c3960000", (others => '1'),
    X"0000000000040004",
    X"0000000000000001", X"0000000000080000", X"0000000000000000", (others => '1'),
    X"0000000000040004",
    X"0000000000000002", X"0000000000400000", X"0000000000400000", (others => '1'),
    X"0000000000040004",
    X"00000000ff000000", X"00000000ff000000", (others => '1'),
    X"0000000000040004",
    X"00000000ff800000", (others => '1'),
    X"0000000000040004",
    X"0000000014800000", X"0000000080000001", (others => '1'), (others => '1'),
    X"0000000000040004",
    X"0123456789abcdef", X"19acdefffffff000", (others => '1'), (others => '0'), (others => '0')
  );

  constant pos0 : position_t := "000000000";
  constant pos1 : position_t := "0"&X"01";
  constant pos3 : position_t := "0"&X"03";
  constant pos_round : position_t := "0"&X"04";

  type poss_t is array (0 to NUMTESTS - 1) of position_t;
  constant poss : poss_t := (
    pos0, pos0, pos0, pos0, pos_round,
    pos0,
    pos0, pos0, pos0, pos_round,
    pos0,
    pos0, pos0, pos0, pos_round,
    pos0,
    pos0, pos0, pos0, pos_round,
    pos0,
    pos0, pos0, pos_round,
    pos0,
    pos0, pos_round,
    pos0,
    pos0, pos0, pos0, pos_round,
    pos0,
    pos1, pos1, pos1, pos3, pos0
  );

  type resets_t is array (0 to NUMTESTS - 1) of std_logic;
  constant resets : resets_t := (
    '1', '0', '0', '0', '0', '0', '0', '0', '0', '0', '0', '0', '0', '0', '0',
    '0', '0', '0', '0', '0', '0', '0', '0', '0', '0', '0', '0', '0', '0', '0',
    '0', '0', '0', '0', '0', '0', '0', '0'
  );

  constant NUMREADS : integer := 8;
  type results_t is array (0 to NUMREADS - 1) of subblock;
  constant results : results_t := (
    X"bfc00000", X"45548000", X"00080001", X"00800002", X"FF800000", X"7F800000", X"147FFFFF", X"14800000"
  );

constant ACC_CLOCK_PERIOD : time := 10ns;

constant RUNTIME : integer := NUMTESTS + 3;

type boolean_vector is array (natural range <>) of boolean;
signal pending_read : boolean_vector(1 downto 0)  := (false, false);

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
    variable testcycle : integer := 0;
    variable readcycle : integer := 0;
  begin
    assert testcycle < RUNTIME report "Test Done";
    if rising_edge(acc_clock) then
      if pending_read(0) and readcycle < NUMREADS then
        assert acc_res = results(readcycle) report "Bad value "&integer'image(readcycle);
        readcycle := readcycle + 1;
      end if;
      if acc_ready = '1' then
        pending_read(0) <= pending_read(1);
        pending_read(1) <= acc_op = op_readfloat or acc_op = op_readblock or acc_op = op_readflags;
      else
        pending_read(0) <= false;
      end if;
      if acc_ready = '1' or acc_reset = '1' then
        testcycle := testcycle + 1;
      end if;
      if testcycle < NUMTESTS then
        acc_reset <= resets(testcycle);
        acc_value <= datas(testcycle);
        acc_pos <= poss(testcycle);
        acc_op <= ops(testcycle);
        acc_sign <= '0';
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
