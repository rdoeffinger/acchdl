library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ht_constants.all;

package ht_mmap_if_types is
component ht_mmap_if is
  port(
    reset_n : in std_logic;
    clock : in std_logic;
    UnitID : in std_logic_vector(4 downto 0);

    cmd_stop : out std_logic;
    cmd : in std_logic_vector(CMD_LEN - 1 downto 0);
    cmd_needs_reply : in std_logic;
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
end component;
end ht_mmap_if_types;
