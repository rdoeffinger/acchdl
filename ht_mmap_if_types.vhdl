library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package ht_mmap_if_types is
component ht_mmap_if is
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
end component;
end ht_mmap_if_types;
