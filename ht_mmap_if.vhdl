--! \file
--! \brief maps memory access to ALUs operations
--! \author Reimar Döffinger
--! \date 2007,2008
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.accumulator_types.all;
use work.ht_constants.all;

--! the HyperTransport memory-mapped interface for the core ALUs
entity ht_mmap_if is
  port(
    reset_n : in std_logic;
    clock : in std_logic;
    UnitID : in std_logic_vector(4 downto 0); --! HyperTransport unit ID for read responses

    cmd_stop : out std_logic;
    cmd : in std_logic_vector(CMD_LEN - 1 downto 0);
    cmd_needs_reply : in std_logic;
    cmd_final : in std_logic;
    tag : in std_logic_vector(TAG_LEN - 1 downto 0);
    addr : in std_logic_vector(ADDR_LEN - 1 downto 0);
    data : in std_logic_vector(31 downto 0);

    response_cmd_out : out std_logic_vector(95 downto 0);
    response_data_out : out std_logic_vector(63 downto 0);
    response_cmd_full : in std_logic;
    response_data_full : in std_logic;
    response_cmd_put : out std_logic;
    response_data_put : out std_logic
  );
end entity;

--! implementation of the HyperTransport memory-mapped interface
architecture behaviour of ht_mmap_if is
alias response_cmd_out_cmd    : std_logic_vector(CMD_LEN  - 1 downto 0) is response_cmd_out(CMD_OFFSET  + CMD_LEN  - 1 downto CMD_OFFSET);
alias response_cmd_out_unitid : std_logic_vector(5        - 1 downto 0) is response_cmd_out(12 downto 8);
alias response_cmd_out_tag    : std_logic_vector(TAG_LEN  - 1 downto 0) is response_cmd_out(TAG_OFFSET  + TAG_LEN  - 1 downto TAG_OFFSET);
alias response_cmd_out_count  : std_logic_vector(COUNT_LEN- 1 downto 0) is response_cmd_out(COUNT_OFFSET  + COUNT_LEN  - 1 downto COUNT_OFFSET);
alias response_cmd_out_format : std_logic_vector(3        - 1 downto 0) is response_cmd_out(95 downto 93);

--! the number of bits for the ALU number, i.e. log2(number of ALUs)
constant REGBITS : integer := 1;
--! the number of ALUs calculated from REGBITS
constant NUMREGS : integer := 2**REGBITS;
type data_array_t is array(0 to NUMREGS-1) of addblock;
--! \brief array of accumulator::data_in signals to ALUs
--! \sa #set_simplestuff
signal data_in : data_array_t;
type short_data_array_t is array(0 to NUMREGS-1) of subblock;
--! array of accumulator::data_out signals from ALUs
signal data_out : short_data_array_t;
--! array of accumulator::ready signals from ALUs
signal ready : std_logic_vector(NUMREGS-1 downto 0);
type operation_array_t is array(0 to NUMREGS-1) of operation;
--! \brief array of accumulator::op signals for ALUs
--! \sa #set_op
signal op : operation_array_t;
--! common reset signal for all ALUs, active high
signal accreset : std_logic;
--! \brief array of accumulator::sign signals of ALUs
--! \sa #set_simplestuff
signal sign : std_logic_vector(NUMREGS-1 downto 0);
type position_array_t is array(0 to NUMREGS-1) of position_t;
--! \brief array of accumulator::pos signals of ALUs
--! \sa #set_simplestuff
signal pos : position_array_t;
--! \brief states for read processing
--!
--! START: no read active
--! READ_WAIT : wait for ALU to start processing of read, signalled by ready = '1'
--! READ_WAIT2: wait for processing of read by ALU to finish, signalled by ready = '1'
--! READ_WAIT3: read result from data_out
--! READ_WAIT4: wait for space in response queue
type state_t is (START, READ_WAIT, READ_WAIT2, READ_WAIT3, READ_WAIT4);
--! \brief state machine for handling reads
--! \sa #set_state
signal state : state_t;
--! \brief ALU on which the read is pending if state /= START
--! \sa #set_read_reg
signal read_reg : natural range 0 to NUMREGS - 1;
--! ALU number part of command address (starting from addr(10)) as integer
signal cmd_reg : integer range 0 to NUMREGS - 1;
--! set if read is the final one of a multi-dword read
signal read_final : std_logic;
--! number of dwords proccessed in current read - 1
signal read_count : std_logic_vector(COUNT_LEN - 1 downto 0);

  --! determine if the given command has data attached
  function needs_data(cmd : in std_logic_vector(CMD_LEN - 1 downto 0)) return boolean is
    variable res : boolean;
  begin
    res := cmd(4 downto 3) = "01"; -- write request
    res := res or cmd = "110000"; -- read response
    res := res or cmd = "111101"; -- atomic read-modify-write
    return res;
  end;
  --! determine if the response to this command needs data, otherwise it only needs a target done
  function respond_data(cmd : in std_logic_vector(CMD_LEN - 1 downto 0)) return boolean is
    variable res : boolean;
  begin
    res := cmd(5 downto 4) = "01"; -- read request
    res := res or cmd = "111101"; -- atomic read-modify-write
    return res;
  end;

begin
  ALUs : for I in 0 to NUMREGS-1 generate
  ALUinst : accumulator port map (
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
  response_cmd_out(7 downto 6) <= "00";
  response_cmd_out(15 downto 13) <= "000";
  response_cmd_out(21) <= '0';
  response_cmd_out(92 downto 26) <= X"0000000000000000"&"000";
  response_cmd_out_unitid <= UnitID;

  cmd_reg <= to_integer(unsigned(addr(10 + REGBITS - 1 downto 10)));

  --! \retval #read_final
  get_final : process(clock,reset_n)
  begin
    if reset_n = '0' then
      read_final <= '1';
    elsif rising_edge(clock) then
      if state = START then
        read_final <= cmd_final;
      end if;
    end if;
  end process;

  --! \retval #read_count
  update_read_count : process(clock,reset_n)
  begin
    if reset_n = '0' then
      read_count <= (others => '0');
    elsif rising_edge(clock) then
      if state = READ_WAIT4 and response_cmd_full = '0' and response_data_full = '0' then
        if read_final = '1' then
          read_count <= (others => '0');
        else
          read_count <= std_logic_vector(unsigned(read_count) + 1);
        end if;
      end if;
    end if;
  end process;

  --! \retval #response_cmd_out
  --! \retval #response_cmd_put
  --! \retval #response_data_out
  --! \retval #response_data_put
  handle_reply : process(clock,reset_n)
    variable put_data : std_logic;
  begin
    if reset_n = '0' then
      response_cmd_put <= '0';
      response_data_put <= '0';
    elsif rising_edge(clock) then
      if state = START then
        if respond_data(cmd) then
          response_cmd_out_cmd <= "110000"; -- read response
          response_cmd_out_format <= "011"; -- 32 bit, data attached
          put_data := '1';
        else
          response_cmd_out_cmd <= "110011"; -- target done
          response_cmd_out_format <= "010"; -- 32 bit, no data attached
          put_data := '0';
        end if;
        response_cmd_out_tag <= tag;
      elsif state = READ_WAIT3 then
        if read_count(0) = '0' then
          response_data_out <= X"00000000"&data_out(read_reg);
        else
          response_data_out(63 downto 32) <= data_out(read_reg);
        end if;
      end if;
      if state = READ_WAIT4 and response_cmd_full = '0' and response_data_full = '0' then
        response_cmd_out_count <= read_count;
        response_cmd_put <= read_final;
        response_data_put <= put_data and (read_count(0) or read_final);
      else
        response_cmd_put <= '0';
        response_data_put <= '0';
      end if;
    end if;
  end process;

  --! handling of simple state machine, START -> READ_WAIT -> READ_WAIT2 -> READ_WAIT3 -> READ_WAIT4 -> START
  --! for reads (requiring read_response with data) and START -> READ_WAIT4 -> START if a simple target_done
  --! response is sufficient
  --! \retval #state
  set_state : process(clock,reset_n)
  begin
    if reset_n = '0' then
      state <= START;
    elsif rising_edge(clock) then
      if state = START and cmd_needs_reply = '1' and not respond_data(cmd) then
        state <= READ_WAIT4;
      elsif state = START and cmd_needs_reply = '1' and ready(cmd_reg) = '1' then
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

  --! if we start a read, copy the ALU number where this read happens to #read_reg
  --! \retval #read_reg
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

  --! set cmd_stop to 1 if the ALU addressed by the current command has not
  --! yet finished processing the previous command or if we are waiting for
  --! a read to finish (the later is unnecessary in most cases though, so this
  --! could be optimized)
  --! \retval #cmd_stop
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

  --! sets the ALU inputs that need (almost) no processing
  --! \retval #data_in
  --! \retval #pos
  --! \retval #sign
  set_simplestuff : process(clock,reset_n)
  begin
    if reset_n = '0' then
      null;
    elsif rising_edge(clock) then
      if ready(cmd_reg) = '1' then
        data_in(cmd_reg) <= X"00000000"&data;
        pos(cmd_reg) <= not addr(8) & addr(7 downto 0);
        sign(cmd_reg) <= addr(6);
      end if;
    end if;
  end process;

  --! set ALU operation based on command and address.
  --! if an ALU finished a command and there is no new command available to it, set it to op_nop.
  --! \retval #op
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
              if    addr(9 downto 0) = "1000000000" then
                op(regnum) <= op_writeflags;
              elsif addr(9 downto 0) = "1000000001" then
                op(regnum) <= op_writeoffsets;
              elsif addr(9) = '1' then
                op(regnum) <= op_writeblock;
              else
                op(regnum) <= op_floatadd;
              end if;
            elsif cmd(5 downto 4) = "01" then
              if    addr(9 downto 0) = "1000000000" then
                op(regnum) <= op_readflags;
              elsif addr(9 downto 0) = "1000000001" then
                op(regnum) <= op_readoffsets;
              elsif addr(9) = '1' then
                op(regnum) <= op_readblock;
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

end architecture;
