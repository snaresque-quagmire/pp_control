library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity clk_enable_debounce is

    port(
        clk             : in    std_logic;
        slow_clk_enable : out   std_logic
    );

end entity;


architecture rtl of clk_enable_debounce is

    signal counter : integer range 0 to 300_000 := 0;

begin

    process(clk)
    begin
        if (rising_edge(clk)) then
            counter <= counter + 1;
            if (counter >= 249_000) then
                counter         <= 0;
                slow_clk_enable <= '1';
            else
                slow_clk_enable <= '0';
            end if;
        end if;
    end process;

end architecture;
