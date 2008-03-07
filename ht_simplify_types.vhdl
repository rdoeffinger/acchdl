library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ht_constants.all;

package ht_simplify_types is
component ht_simplify is
  port(
    reset_n : in std_logic;
    clock : in std_logic;

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

    cmd_stop : in std_logic;
    cmd : out std_logic_vector(CMD_LEN - 1 downto 0);
    cmd_needs_reply : out std_logic;
    tag : out std_logic_vector(TAG_LEN - 1 downto 0);
    addr : out std_logic_vector(ADDR_LEN - 1 downto 0);
    data : out std_logic_vector(31 downto 0)
  );
end component;
end ht_simplify_types;
