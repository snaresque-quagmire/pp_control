library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity debounce_module is
    port(
        clk         : in    std_logic;
        clk_enable  : in    std_logic;
        D           : in    std_logic_vector(3 downto 0);
        Q           : out   std_logic_vector(3 downto 0) := "0000"
    );

end entity;


architecture rtl of debounce_module is

begin

    process(clk)
    begin

        if (rising_edge(clk)) then
            if(clk_enable = '1') then
                Q <= D;
            end if;
        end if;

    end process;

end architecture;

