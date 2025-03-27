library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity keypad_map is
    port(
        row_index       : in    integer range 0 to 3;
        debounced_col   : in    std_logic_vector(15 downto 0);
        decoded_btn     : out   std_logic_vector(4 downto 0)
    );
end entity;


architecture rtl of keypad_map is

begin

    process(debounced_col)
    begin
        case debounced_col is
            when "0000000000000001" => decoded_btn <= "01110"; -- '1'
            when "0000000000000010" => decoded_btn <= "01101"; -- '2'
            when "0000000000000100" => decoded_btn <= "01100"; -- '3'
            when "0000000000001000" => decoded_btn <= "00101"; -- 'A'
            when "0000000000010000" => decoded_btn <= "01011"; -- '4'
            when "0000000000100000" => decoded_btn <= "01010"; -- '5'
            when "0000000001000000" => decoded_btn <= "01001"; -- '6'
            when "0000000010000000" => decoded_btn <= "00100"; -- 'B'
            when "0000000100000000" => decoded_btn <= "01000"; -- '7'
            when "0000001000000000" => decoded_btn <= "00111"; -- '8'
            when "0000010000000000" => decoded_btn <= "00110"; -- '9'
            when "0000100000000000" => decoded_btn <= "00011"; -- 'C'
            when "0001000000000000" => decoded_btn <= "00001"; -- '*'
            when "0010000000000000" => decoded_btn <= "10000"; -- '0'
            when "0100000000000000" => decoded_btn <= "01111"; -- '#'
            when "1000000000000000" => decoded_btn <= "00010"; -- 'D'
            when others => decoded_btn <= (others => '1');
        end case;

    end process;

end architecture;