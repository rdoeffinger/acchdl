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

constant REGBITS : integer := 0;
constant NUMREGS : integer := 2**REGBITS;
type data_array_t is array(0 to NUMREGS-1) of addblock;
signal data_in : data_array_t;
signal data_out : data_array_t;
signal ready : std_logic_vector(NUMREGS-1 downto 0);
type operation_array_t is array(0 to NUMREGS-1) of operation;
signal op : operation_array_t;
signal accreset : std_logic;
signal sign : std_logic_vector(NUMREGS-1 downto 0);
type position_array_t is array(0 to NUMREGS-1) of position;
signal pos : position_array_t;
type state_t is (START, READ_WAIT, READ_WAIT2);
signal state : state_t;
signal readreg : natural range 0 to NUMREGS - 1;

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
  sign(0) <= '0';

  process (clock, reset_n)
  variable regnum : integer range 0 to NUMREGS-1;
  variable buffered_posted_cmd_avail : std_logic;
  variable buffered_posted_cmd : std_logic_vector(CMD_LEN - 1 downto 0);
  variable buffered_posted_data_avail : std_logic;
  variable buffered_posted_data : std_logic_vector(63 downto 0);
  variable buffered_nonposted_cmd_avail : std_logic;
  variable buffered_nonposted_cmd : std_logic_vector(CMD_LEN - 1 downto 0);
  variable buffered_nonposted_tag : std_logic_vector(TAG_LEN - 1 downto 0);
  variable buffered_nonposted_data_avail : std_logic;
  variable buffered_nonposted_data : std_logic_vector(63 downto 0);
  begin
    if reset_n = '0' then
      state <= START;
      for regnum in 0 to NUMREGS-1 loop
        op(regnum) <= op_nop;
      end loop;
      posted_data_complete <= '0';
      response_cmd_put <= '0';
      response_data_put <= '0';
      posted_cmd_get <= '1';
      posted_data_get <= '1';
      nonposted_cmd_get <= '1';
      nonposted_data_get <= '1';
      buffered_posted_cmd_avail := '0';
      buffered_posted_data_avail := '0';
      buffered_nonposted_cmd_avail := '0';
      buffered_nonposted_data_avail := '0';
    elsif rising_edge(clock) then
      posted_data_complete <= '0';
      if posted_cmd_empty = '0' and
         buffered_posted_cmd_avail = '0' then
        buffered_posted_cmd_avail := '1';
        buffered_posted_cmd := posted_cmd_in_cmd;
      end if;
      if posted_data_empty = '0' and
         buffered_posted_data_avail = '0' then
        posted_data_complete <= '1';
        buffered_posted_data_avail := '1';
        buffered_posted_data := posted_data_in;
      end if;
      if nonposted_cmd_empty = '0' and
         buffered_nonposted_cmd_avail = '0' then
        buffered_nonposted_cmd_avail := '1';
        buffered_nonposted_cmd := nonposted_cmd_in_cmd;
        buffered_nonposted_tag := nonposted_cmd_in_tag;
      end if;
      if nonposted_data_empty = '0' and
         buffered_nonposted_data_avail = '0' then
        buffered_nonposted_data_avail := '1';
        buffered_nonposted_data := posted_data_in;
      end if;

      response_cmd_put <= '0';
      response_data_put <= '0';

      if ready(readreg) = '1' then
        if state = READ_WAIT then
          state <= READ_WAIT2;
        elsif state = READ_WAIT2 and
              response_cmd_full = '0' and
              response_data_full = '0' then
          buffered_nonposted_cmd_avail := '0';
          response_cmd_out <= (others => '0');
          response_cmd_out_cmd <= "110000"; -- read response
          response_cmd_out_unitid <= UnitID;
          response_cmd_out_tag <= buffered_nonposted_tag;
          response_cmd_out_format <= "011"; -- 32 bit, data attached
          response_data_out <= data_out(readreg);
          response_cmd_put <= '1';
          response_data_put <= '1';
          op(readreg) <= op_nop;
          state <= START;
        end if;
      end if;
      for regnum in 0 to NUMREGS-1 loop
        if ready(regnum) = '1' and
           (state = START or regnum /= readreg) then
          op(regnum) <= op_nop;
        end if;
      end loop;

      if buffered_posted_cmd_avail = '1' then
        if buffered_posted_cmd(5 downto 2) = "1011" then
          regnum := 0;
          -- handle only posted doubleword writes
          if buffered_posted_data_avail = '1' and
             (state = START or regnum /= readreg) and
             ready(regnum) = '1' then
            buffered_posted_cmd_avail := '0';
            buffered_posted_data_avail := '0';
            data_in(regnum) <= buffered_posted_data;
            op(regnum) <= op_floatadd;
          end if;
        else
          buffered_posted_cmd_avail := '0';
          buffered_posted_data_avail := '0';
        end if;
      end if;
      if buffered_nonposted_cmd_avail = '1' then
        if buffered_nonposted_cmd(5 downto 4) = "01" then
          regnum := 0;
          -- check for read request
          if state = START and
             ready(regnum) = '1' then
            op(regnum) <= op_readfloat;
            state <= READ_WAIT;
            readreg <= regnum;
          end if;
        else
          if state /= READ_WAIT2 and response_cmd_full = '0' then
            buffered_nonposted_cmd_avail := '0';
            response_cmd_out <= (others => '0');
            response_cmd_out_cmd <= "110011"; -- target done
            response_cmd_out_unitid <= UnitID;
            response_cmd_out_tag <= buffered_nonposted_tag;
            response_cmd_out_format <= "010"; -- 32 bit, no data attached
            response_cmd_put <= '1';
          end if;
        end if;
      end if;
      buffered_nonposted_data_avail := '0';
      posted_cmd_get <= not buffered_posted_cmd_avail;
      posted_data_get <= not buffered_posted_data_avail;
      nonposted_cmd_get <= not buffered_nonposted_cmd_avail;
      nonposted_data_get <= not buffered_nonposted_data_avail;
    end if;
  end process;
end architecture;
