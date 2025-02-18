library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity keypad_map is
    port(
        row_index       : in    integer range 0 to 3;
        debounced_col   : in    std_logic_vector(3 downto 0);
        decoded_btn     : out   std_logic_vector(4 downto 0)
    );
end entity;


architecture rtl of keypad_map is

begin

    process(row_index, debounced_col)
    begin
        case row_index is
        when 0 =>
            case debounced_col is
                when "0001" => decoded_btn <= "01110"; -- '1'
                when "0010" => decoded_btn <= "01101"; -- '2'
                when "0100" => decoded_btn <= "01100"; -- '3'
                when "1000" => decoded_btn <= "00101"; -- 'A'
                when others => decoded_btn <= "01111";
            end case;
        when 1 =>
            case debounced_col is
                when "0001" => decoded_btn <= "01011"; -- '4'
                when "0010" => decoded_btn <= "01010"; -- '5'
                when "0100" => decoded_btn <= "01001"; -- '6'
                when "1000" => decoded_btn <= "00100"; -- 'B'
                when others => decoded_btn <= "01111";
            end case;
        when 2 =>
            case debounced_col is
                when "0001" => decoded_btn <= "01000"; -- '7'
                when "0010" => decoded_btn <= "00111"; -- '8'
                when "0100" => decoded_btn <= "00110"; -- '9'
                when "1000" => decoded_btn <= "00011"; -- 'C'
                when others => decoded_btn <= "01111";
            end case;
        when 3 =>
            case debounced_col is
                when "0001" => decoded_btn <= "00001"; -- '*'
                when "0010" => decoded_btn <= "10000"; -- '0'
                when "0100" => decoded_btn <= "01111"; -- '#'
                when "1000" => decoded_btn <= "00010"; -- 'D'
                when others => decoded_btn <= "11111";
            end case;
        when others => decoded_btn <= "11111";
        end case;

    end process;

end architecture;