library ieee;
use ieee.std_logic_1164.all;
use accumulator_types.all;

entity test_accumulator is
end test_accumulator;

architecture behaviour of test_accumulator is
  signal acc_reset : std_logic := '0';
  signal acc_clock : std_logic := '0';
  signal acc_op : operation := op_nop;
  signal acc_value : addblock := (others => 'Z');
  signal acc_pos : position := 0;
  signal acc_read : std_logic := '0';
begin
  acc : accumulator port map (
    reset => acc_reset,
    clock => acc_clock,
    read => acc_read,
    data => acc_value,
    pos => acc_pos,
    op => acc_op
  );
  process
    procedure exec(op : in operation) is
    begin
      acc_op <= op;
      wait for 100 ns;
      acc_clock <= '1';
      wait for 100 ns;
      acc_clock <= '0';
    end exec;
  begin
    acc_clock <= '0';
    acc_read  <= '0';
    acc_reset <= '1';
    wait for 100 ns;
    acc_reset <= '0';
    acc_pos   <= 5;
    acc_value <= (others => '1');
    exec(op_add);
    exec(op_add);
    exec(op_add);
    exec(op_add);
    acc_value <= (others => 'Z');
    acc_pos   <= 7;
    exec(op_output);
    acc_read  <= '1';
    exec(op_nop);
    exec(op_nop);
  end process;
end behaviour;

