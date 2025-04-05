library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity clk_enable_debounce is
    port(
        clk             : in    std_logic;
        slow_clk_enable : out   std_logic;
        delay_time      : in    std_logic_vector(19 downto 0)     := x"3D08F"
    );
end entity;

architecture rtl of clk_enable_debounce is
    signal counter          : integer range 0 to 250000 := 0;
    signal int_delay        : integer range 0 to 250000 := 0;
begin

    int_delay <= to_integer(unsigned(delay_time)-1);

    process(clk)
    begin
        if (rising_edge(clk)) then
                
            if (counter = int_delay) then
                counter         <= 0;
                slow_clk_enable <= '1';
            else
                slow_clk_enable <= '0';
                counter <= counter + 1;
            end if;
        end if;
    end process;

end architecture;
