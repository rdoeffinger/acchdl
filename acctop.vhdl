library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use accumulator_types.all;

entity acctop is
  port(
    clock_output : out std_logic;
    HTX_PWROK : in std_logic;
    HTX_RES_N : in std_logic;
    HTX_LDTSTOP_N : in std_logic;
    HTX_CADINH : in std_logic_vector(15 downto 0);
    HTX_CADINL : in std_logic_vector(15 downto 0);
    HTX_CTLINH : in std_logic;
    HTX_CTLINL : in std_logic;
    HTX_REFCLK_H : in std_logic;
    HTX_REFCLK_L : in std_logic;
    HTX_CLKIN0H : in std_logic;
    HTX_CLKIN0L : in std_logic;
    HTX_CLKIN1H : in std_logic;
    HTX_CLKIN1L : in std_logic;
    HTX_CADOUTH : out std_logic_vector(15 downto 0);
    HTX_CADOUTL : out std_logic_vector(15 downto 0);
    HTX_CTLOUTH : out std_logic;
    HTX_CTLOUTL : out std_logic;
    HTX_CLKOUT0H : out std_logic;
    HTX_CLKOUT0L : out std_logic;
    HTX_CLKOUT1H : out std_logic;
    HTX_CLKOUT1L : out std_logic
  );
end entity;

architecture behaviour of acctop is
  component htxtop is
    port (
      PWROK : in std_logic;
      RESET_N : in std_logic;
      LDTSTOP_N : in std_logic;
      REFCLK_H : in std_logic;
      REFCLK_L : in std_logic;
      CLK0_LINK2CORE_H : in std_logic;
      CLK0_LINK2CORE_L : in std_logic;
      CLK1_LINK2CORE_H : in std_logic;
      CLK1_LINK2CORE_L : in std_logic;
      CTL_LINK2CORE_H : in std_logic;
      CTL_LINK2CORE_L : in std_logic;
      CAD_LINK2CORE_H : in std_logic_vector(15 downto 0);
      CAD_LINK2CORE_L : in std_logic_vector(15 downto 0);
      CLK0_CORE2LINK_H : out std_logic;
      CLK0_CORE2LINK_L : out std_logic;
      CLK1_CORE2LINK_H : out std_logic;
      CLK1_CORE2LINK_L : out std_logic;
      CTL_CORE2LINK_H : out std_logic;
      CTL_CORE2LINK_L : out std_logic;
      CAD_CORE2LINK_H : out std_logic_vector(15 downto 0);
      CAD_CORE2LINK_L : out std_logic_vector(15 downto 0);

      NP_DATA_CORE2APP : out std_logic_vector(63 downto 0);
      NP_CTRL_CORE2APP : out std_logic_vector(95 downto 0);
      NP_C_EMPTY_CORE2APP : out std_logic;
      NP_D_EMPTY_CORE2APP : out std_logic;
      NP_C_SHIFTOUT_APP2CORE : in std_logic;
      NP_D_SHIFTOUT_APP2CORE : in std_logic;
      NP_DATA_APP2CORE : in std_logic_vector(63 downto 0);
      NP_CTRL_APP2CORE : in std_logic_vector(95 downto 0);
      NP_C_FULL_CORE2APP : out std_logic;
      NP_D_FULL_CORE2APP : out std_logic;
      NP_C_SHIFTIN_APP2CORE : in std_logic;
      NP_D_SHIFTIN_APP2CORE : in std_logic;
      NP_D_PC_APP2CORE : in std_logic;

      P_DATA_CORE2APP : out std_logic_vector(63 downto 0);
      P_CTRL_CORE2APP : out std_logic_vector(95 downto 0);
      P_C_EMPTY_CORE2APP : out std_logic;
      P_D_EMPTY_CORE2APP : out std_logic;
      P_C_SHIFTOUT_APP2CORE : in std_logic;
      P_D_SHIFTOUT_APP2CORE : in std_logic;
      P_DATA_APP2CORE : in std_logic_vector(63 downto 0);
      P_CTRL_APP2CORE : in std_logic_vector(95 downto 0);
      P_C_FULL_CORE2APP : out std_logic;
      P_D_FULL_CORE2APP : out std_logic;
      P_C_SHIFTIN_APP2CORE : in std_logic;
      P_D_SHIFTIN_APP2CORE : in std_logic;
      P_D_PC_APP2CORE : in std_logic;

      R_DATA_CORE2APP : out std_logic_vector(63 downto 0);
      R_CTRL_CORE2APP : out std_logic_vector(95 downto 0);
      R_C_EMPTY_CORE2APP : out std_logic;
      R_D_EMPTY_CORE2APP : out std_logic;
      R_C_SHIFTOUT_APP2CORE : in std_logic;
      R_D_SHIFTOUT_APP2CORE : in std_logic;
      R_DATA_APP2CORE : in std_logic_vector(63 downto 0);
      R_CTRL_APP2CORE : in std_logic_vector(95 downto 0);
      R_C_FULL_CORE2APP : out std_logic;
      R_D_FULL_CORE2APP : out std_logic;
      R_C_SHIFTIN_APP2CORE : in std_logic;
      R_D_SHIFTIN_APP2CORE : in std_logic;
      R_D_PC_APP2CORE : in std_logic;

      ext_clk : in std_logic;
      ref_clk : out std_logic;
      reset_n_out : out std_logic;
      UnitID : out std_logic_vector(4 downto 0);

      -- unused internal stuff
      int_masked : out std_logic;
      int_intrinfo : out std_logic_vector(53 downto 0);
      internal_reset : out std_logic_vector(31 downto 0)
    );
  end component;
signal nonposted_cmd_in : std_logic_vector(95 downto 0);
signal nonposted_data_in : std_logic_vector(63 downto 0);
signal nonposted_cmd_empty : std_logic;
signal nonposted_data_empty : std_logic;
signal nonposted_cmd_get : std_logic;
signal nonposted_data_get : std_logic;
signal nonposted_cmd_out : std_logic_vector(95 downto 0);
signal nonposted_data_out : std_logic_vector(63 downto 0);
signal nonposted_cmd_full : std_logic;
signal nonposted_data_full : std_logic;
signal nonposted_cmd_put : std_logic;
signal nonposted_data_put : std_logic;
signal nonposted_data_complete : std_logic;

signal posted_cmd_in : std_logic_vector(95 downto 0);
signal posted_data_in : std_logic_vector(63 downto 0);
signal posted_cmd_empty : std_logic;
signal posted_data_empty : std_logic;
signal posted_cmd_get : std_logic;
signal posted_data_get : std_logic;
signal posted_cmd_out : std_logic_vector(95 downto 0);
signal posted_data_out : std_logic_vector(63 downto 0);
signal posted_cmd_full : std_logic;
signal posted_data_full : std_logic;
signal posted_cmd_put : std_logic;
signal posted_data_put : std_logic;
signal posted_data_complete : std_logic;

signal response_cmd_in : std_logic_vector(95 downto 0);
signal response_data_in : std_logic_vector(63 downto 0);
signal response_cmd_empty : std_logic;
signal response_data_empty : std_logic;
signal response_cmd_get : std_logic;
signal response_data_get : std_logic;
signal response_cmd_out : std_logic_vector(95 downto 0);
signal response_data_out : std_logic_vector(63 downto 0);
signal response_cmd_full : std_logic;
signal response_data_full : std_logic;
signal response_cmd_put : std_logic;
signal response_data_put : std_logic;
signal response_data_complete : std_logic;

signal clock : std_logic;
signal clock2 : std_logic;
attribute clock_signal : string;
attribute clock_signal of clock : signal is "yes";
attribute clock_signal of clock2 : signal is "yes";
signal reset_n : std_logic;
signal UnitID : std_logic_vector(4 downto 0);

constant CMD_OFFSET  : integer :=  0;
constant CMD_LEN     : integer :=  6;
constant TAG_OFFSET  : integer := 16;
constant TAG_LEN     : integer :=  5;
constant ADDR_OFFSET : integer := 26;
constant ADDR_LEN    : integer := 62;

alias posted_cmd_in_cmd       : std_logic_vector(CMD_LEN  - 1 downto 0) is posted_cmd_in(   CMD_OFFSET  + CMD_LEN  - 1 downto CMD_OFFSET);
alias posted_cmd_in_tag       : std_logic_vector(TAG_LEN  - 1 downto 0) is posted_cmd_in(   TAG_OFFSET  + TAG_LEN  - 1 downto TAG_OFFSET);
alias posted_cmd_in_addr      : std_logic_vector(ADDR_LEN - 1 downto 0) is posted_cmd_in(   ADDR_OFFSET + ADDR_LEN - 1 downto ADDR_OFFSET);
alias nonposted_cmd_in_cmd    : std_logic_vector(CMD_LEN  - 1 downto 0) is nonposted_cmd_in(CMD_OFFSET  + CMD_LEN  - 1 downto CMD_OFFSET);
alias nonposted_cmd_in_tag    : std_logic_vector(TAG_LEN  - 1 downto 0) is nonposted_cmd_in(TAG_OFFSET  + TAG_LEN  - 1 downto TAG_OFFSET);
alias nonposted_cmd_in_addr   : std_logic_vector(ADDR_LEN - 1 downto 0) is nonposted_cmd_in(ADDR_OFFSET + ADDR_LEN - 1 downto ADDR_OFFSET);

alias response_cmd_out_cmd    : std_logic_vector(CMD_LEN  - 1 downto 0) is response_cmd_out(CMD_OFFSET  + CMD_LEN  - 1 downto CMD_OFFSET);
alias response_cmd_out_unitid : std_logic_vector(5        - 1 downto 0) is response_cmd_out(12 downto 8);
alias response_cmd_out_tag    : std_logic_vector(TAG_LEN  - 1 downto 0) is response_cmd_out(TAG_OFFSET  + TAG_LEN  - 1 downto TAG_OFFSET);
alias response_cmd_out_format : std_logic_vector(3        - 1 downto 0) is response_cmd_out(95 downto 93);

constant NUMREGS : integer := 2;
constant REGBITS : integer := 1;
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
type state_array_t is array(0 to NUMREGS-1) of state_t;
signal state : state_array_t;

begin
  regs : for I in 0 to NUMREGS-1 generate
  reg0 : accumulator port map (
    ready => ready(I),
    reset => accreset,
    clock => clock2,
    data_in => data_in(I),
    data_out => data_out(I),
    sign => sign(I),
    pos => pos(I),
    op => op(I)
  );
  end generate;
  core : htxtop port map (
    PWROK            => HTX_PWROK     ,
    RESET_N          => HTX_RES_N     ,
    LDTSTOP_N        => HTX_LDTSTOP_N ,
    REFCLK_H         => HTX_REFCLK_H  ,
    REFCLK_L         => HTX_REFCLK_L  ,
    CLK0_LINK2CORE_H => HTX_CLKIN0H   ,
    CLK0_LINK2CORE_L => HTX_CLKIN0L   ,
    CLK1_LINK2CORE_H => HTX_CLKIN1H   ,
    CLK1_LINK2CORE_L => HTX_CLKIN1L   ,
    CTL_LINK2CORE_H  => HTX_CTLINH    ,
    CTL_LINK2CORE_L  => HTX_CTLINL    ,
    CAD_LINK2CORE_H  => HTX_CADINH    ,
    CAD_LINK2CORE_L  => HTX_CADINL    ,
    CLK0_CORE2LINK_H => HTX_CLKOUT0H  ,
    CLK0_CORE2LINK_L => HTX_CLKOUT0L  ,
    CLK1_CORE2LINK_H => HTX_CLKOUT1H  ,
    CLK1_CORE2LINK_L => HTX_CLKOUT1L  ,
    CTL_CORE2LINK_H  => HTX_CTLOUTH   ,
    CTL_CORE2LINK_L  => HTX_CTLOUTL   ,
    CAD_CORE2LINK_H  => HTX_CADOUTH   ,
    CAD_CORE2LINK_L  => HTX_CADOUTL   ,

    NP_CTRL_CORE2APP       => nonposted_cmd_in,
    NP_DATA_CORE2APP       => nonposted_data_in,
    NP_C_EMPTY_CORE2APP    => nonposted_cmd_empty,
    NP_D_EMPTY_CORE2APP    => nonposted_data_empty,
    NP_C_SHIFTOUT_APP2CORE => nonposted_cmd_get,
    NP_D_SHIFTOUT_APP2CORE => nonposted_data_get,
    NP_CTRL_APP2CORE       => nonposted_cmd_out,
    NP_DATA_APP2CORE       => nonposted_data_out,
    NP_C_FULL_CORE2APP     => nonposted_cmd_full,
    NP_D_FULL_CORE2APP     => nonposted_data_full,
    NP_C_SHIFTIN_APP2CORE  => nonposted_cmd_put,
    NP_D_SHIFTIN_APP2CORE  => nonposted_data_put,
    NP_D_PC_APP2CORE       => nonposted_data_complete,

    P_CTRL_CORE2APP       => posted_cmd_in,
    P_DATA_CORE2APP       => posted_data_in,
    P_C_EMPTY_CORE2APP    => posted_cmd_empty,
    P_D_EMPTY_CORE2APP    => posted_data_empty,
    P_C_SHIFTOUT_APP2CORE => posted_cmd_get,
    P_D_SHIFTOUT_APP2CORE => posted_data_get,
    P_CTRL_APP2CORE       => posted_cmd_out,
    P_DATA_APP2CORE       => posted_data_out,
    P_C_FULL_CORE2APP     => posted_cmd_full,
    P_D_FULL_CORE2APP     => posted_data_full,
    P_C_SHIFTIN_APP2CORE  => posted_cmd_put,
    P_D_SHIFTIN_APP2CORE  => posted_data_put,
    P_D_PC_APP2CORE       => posted_data_complete,

    R_CTRL_CORE2APP       => response_cmd_in,
    R_DATA_CORE2APP       => response_data_in,
    R_C_EMPTY_CORE2APP    => response_cmd_empty,
    R_D_EMPTY_CORE2APP    => response_data_empty,
    R_C_SHIFTOUT_APP2CORE => response_cmd_get,
    R_D_SHIFTOUT_APP2CORE => response_data_get,
    R_CTRL_APP2CORE       => response_cmd_out,
    R_DATA_APP2CORE       => response_data_out,
    R_C_FULL_CORE2APP     => response_cmd_full,
    R_D_FULL_CORE2APP     => response_data_full,
    R_C_SHIFTIN_APP2CORE  => response_cmd_put,
    R_D_SHIFTIN_APP2CORE  => response_data_put,
    R_D_PC_APP2CORE       => response_data_complete,

    ext_clk => clock,
    ref_clk => clock,
    reset_n_out => reset_n,
    UnitID => UnitID
  );

  -- drop incoming packets on response queue
  response_cmd_get <= '1';
  response_data_get <= '1';

  -- we do not have outgoing posted or nonposted messages
  nonposted_cmd_put <= '0';
  nonposted_data_put <= '0';
  posted_cmd_put <= '0';
  posted_data_put <= '0';

  -- no idea why...
  response_data_complete <= '0';

  accreset <= not reset_n;

  clock_output <= clock;

  process (clock, reset_n)
  variable regnum : integer range 0 to NUMREGS-1;
  variable block_response : std_logic;
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
  begin
    if reset_n = '0' then
      clock2 <= '0';
      state <= (others => START);
      op <= (others => op_nop);
      buffered_posted_cmd_avail := '0';
      buffered_posted_data_avail := '0';
      buffered_nonposted_cmd_avail := '0';
      buffered_nonposted_data_avail := '0';
    elsif rising_edge(clock) then
      posted_data_complete <= '0';
      nonposted_data_complete <= '0';
      if posted_cmd_empty = '0' and
         buffered_posted_cmd_avail = '0' then
        buffered_posted_cmd_avail := '1';
        buffered_posted_cmd := posted_cmd_in_cmd;
        buffered_posted_addr := posted_cmd_in_addr;
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
        buffered_nonposted_addr := nonposted_cmd_in_addr;
      end if;
      if nonposted_data_empty = '0' and
         buffered_nonposted_data_avail = '0' then
        nonposted_data_complete <= '1';
        buffered_nonposted_data_avail := '1';
        buffered_nonposted_data := posted_data_in;
      end if;

      clock2 <= not clock2;
      response_cmd_put <= '0';
      response_data_put <= '0';
      block_response := response_cmd_full;

      for regnum in 0 to NUMREGS-1 loop
      if clock2 = '1' and ready(regnum) = '1' then
        if state(regnum) = START then
          op(regnum) <= op_nop;
        end if;
        if state(regnum) = READ_WAIT then
          state(regnum) <= READ_WAIT2;
        end if;
        if state(regnum) = READ_WAIT2 and
           block_response = '0' and
           response_data_full = '0' then
          block_response := '1';
          buffered_nonposted_cmd_avail := '0';
          response_cmd_out <= (others => '0');
          response_cmd_out_cmd <= "110000"; -- read response
          response_cmd_out_unitid <= UnitID;
          response_cmd_out_tag <= buffered_nonposted_tag;
          response_cmd_out_format <= "011"; -- 32 bit, data attached
          response_data_out <= data_out(regnum);
          response_cmd_put <= '1';
          response_data_put <= '1';
          state(regnum) <= START;
        end if;
      end if;
      end loop;

      if buffered_posted_cmd_avail = '1' then
        if buffered_posted_cmd(5 downto 2) = "1011" then
          regnum := to_integer(unsigned(buffered_posted_addr(10+REGBITS-1 downto 10)));
          -- handle only posted doubleword writes
          if buffered_posted_data_avail = '1' and
             state(regnum) = START and
             clock2 = '1' and
             ready(regnum) = '1' then
            buffered_posted_cmd_avail := '0';
            data_in(regnum) <= std_logic_vector(unsigned(std_logic_vector'(X"0000000000"&"1"&buffered_posted_data(22 downto 0))) sll to_integer(unsigned(buffered_posted_data(27 downto 23))));
            sign(regnum) <= buffered_posted_data(31);
            pos(regnum) <= to_integer(unsigned(buffered_posted_data(30 downto 28)));
            op(regnum) <= op_add;
          end if;
        else
          buffered_posted_cmd_avail := '0';
        end if;
      end if;
      if buffered_posted_cmd_avail = '0' then
        buffered_posted_data_avail := '0';
      end if;
      if buffered_nonposted_cmd_avail = '1' then
        if buffered_nonposted_cmd(5 downto 4) = "01" then
          regnum := to_integer(unsigned(buffered_nonposted_addr(10+REGBITS-1 downto 10)));
          -- check for read request
          if state(regnum) = START and
             clock2 = '1' and
             ready(regnum) = '1' then
            pos(regnum) <= to_integer(unsigned(buffered_nonposted_addr(5 downto 0)));
            op(regnum) <= op_output;
            state(regnum) <= READ_WAIT;
          end if;
        else
          if block_response = '0' then
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
