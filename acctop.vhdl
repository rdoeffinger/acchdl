--! \file
--! \brief toplevel module, contains no real funtionality besides connecting components
--! \author Reimar Döffinger
--! \date 2007,2008

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ht_simplify_types.all;
use work.ht_mmap_if_types.all;
use work.ht_constants.all;

--! toplevel module, ports are the actual HyperTransport signal links
entity acctop is
--! \name Ports corresponding to HyperTransport signals
--! \brief HyperTransport signal links as described in the specification
--! \{
  port(
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
--! \}
end entity;

--! implementation of toplevel connections between modules
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
--! \name HyperTransport core signals
--! \brief signals connected to the application-side of the HyperTransport core
--! \{
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
attribute clock_signal : string;
attribute clock_signal of clock : signal is "yes";
signal reset_n : std_logic;
signal UnitID : std_logic_vector(4 downto 0);
--! \}

--! \name HyperTransport simplifier signals
--! \brief signals providing the simplified HyperTransport interface of ht_simplify
--! \{
signal cmd_stop : std_logic;
signal cmd : std_logic_vector(CMD_LEN - 1 downto 0);
signal cmd_needs_reply : std_logic;
signal cmd_final : std_logic;
signal tag : std_logic_vector(TAG_LEN - 1 downto 0);
signal addr : std_logic_vector(ADDR_LEN - 1 downto 0);
signal data : std_logic_vector(31 downto 0);
--! \}

begin
  --! simplification layer for HyperTransport posted-/nonposted queues
  simplify : ht_simplify port map (
    reset_n => reset_n,
    clock => clock,

    nonposted_cmd_in => nonposted_cmd_in,
    nonposted_data_in => nonposted_data_in,
    nonposted_cmd_empty => nonposted_cmd_empty,
    nonposted_data_empty => nonposted_data_empty,
    nonposted_cmd_get => nonposted_cmd_get,
    nonposted_data_get => nonposted_data_get,
    nonposted_data_complete => nonposted_data_complete,

    posted_cmd_in => posted_cmd_in,
    posted_data_in => posted_data_in,
    posted_cmd_empty => posted_cmd_empty,
    posted_data_empty => posted_data_empty,
    posted_cmd_get => posted_cmd_get,
    posted_data_get => posted_data_get,
    posted_data_complete => posted_data_complete,

    cmd_stop => cmd_stop,
    cmd => cmd,
    cmd_needs_reply => cmd_needs_reply,
    cmd_final => cmd_final,
    tag => tag,
    addr => addr,
    data => data
  );
  --! memory-mapping interface containing the ALUs
  interface : ht_mmap_if port map (
    reset_n => reset_n,
    clock => clock,
    UnitID => UnitID,

    cmd_stop => cmd_stop,
    cmd => cmd,
    cmd_needs_reply => cmd_needs_reply,
    cmd_final => cmd_final,
    tag => tag,
    addr => addr,
    data => data,

    response_cmd_out => response_cmd_out,
    response_data_out => response_data_out,
    response_cmd_full => response_cmd_full,
    response_data_full => response_data_full,
    response_cmd_put => response_cmd_put,
    response_data_put => response_data_put
  );
  --! the HyperTransport core
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
  nonposted_cmd_out <= (others => '0');
  nonposted_data_out <= (others => '0');
  nonposted_cmd_put <= '0';
  nonposted_data_put <= '0';
  posted_cmd_out <= (others => '0');
  posted_data_out <= (others => '0');
  posted_cmd_put <= '0';
  posted_data_put <= '0';

  -- no idea why...
  response_data_complete <= '0';
end architecture;
