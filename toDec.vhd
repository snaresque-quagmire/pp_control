library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity toDec is
    port(
        clk         : in    std_logic;
        value       : in    std_logic_vector(11 downto 0);
        thousands   : out   std_logic_vector(7 downto 0);
        hundreds    : out   std_logic_vector(7 downto 0);
        tens        : out   std_logic_vector(7 downto 0);
        unit        : out   std_logic_vector(7 downto 0)
    );
    
end entity;

architecture rtl of toDec is
    signal digits       : std_logic_vector(15 downto 0) := (others => '0');
    signal cachedValue  : std_logic_vector(11 downto 0) := (others => '0');
    signal stepCounter  : unsigned(3 downto 0)          := (others => '0');
    signal state        : std_logic_vector(1 downto 0)  := (others => '0');

    constant START_STATE    : std_logic_vector(1 downto 0) := "00";
    constant ADD3_STATE     : std_logic_vector(1 downto 0) := "01";
    constant SHIFT_STATE    : std_logic_vector(1 downto 0) := "10";
    constant DONE_STATE     : std_logic_vector(1 downto 0) := "11";

begin

    process(clk)
    begin
        if rising_edge(clk) then
        case state is
        when START_STATE =>
            cachedValue <= value;
            stepCounter <= (others => '0');
            digits <= (others => '0');
            state <= ADD3_STATE;

        when ADD3_STATE =>
            if(unsigned(digits(3 downto 0)) >= 5) then
                digits(3 downto 0) <= std_logic_vector(unsigned(digits(3 downto 0)) + 3);
            end if;
            
            if(unsigned(digits(7 downto 4)) >= 5) then
                digits(7 downto 4) <= std_logic_vector(unsigned(digits(7 downto 4)) + 3);
            end if;

            if(unsigned(digits(11 downto 8)) >= 5) then
                digits(11 downto 8) <= std_logic_vector(unsigned(digits(11 downto 8)) + 3);
            end if;

            if(unsigned(digits(15 downto 12)) >= 5) then
                digits(15 downto 12) <= std_logic_vector(unsigned(digits(15 downto 12)) + 3);
            end if;

            state <= SHIFT_STATE;
        
        when SHIFT_STATE =>
            digits <= digits(14 downto 0) & cachedValue(11);
            cachedValue <= cachedValue(10 downto 0) & '0';
            if stepCounter = "1011" then
                state <= DONE_STATE;
            else
                state <= ADD3_STATE;
                stepCounter <= stepCounter + 1;
            end if;

           when DONE_STATE =>
                thousands    <= std_logic_vector(to_unsigned(48 + to_integer(unsigned(digits(15 downto 12))), 8));
                hundreds    <= std_logic_vector(to_unsigned(48 + to_integer(unsigned(digits(11 downto 8))), 8));
                tens        <= std_logic_vector(to_unsigned(48 + to_integer(unsigned(digits(7 downto 4))), 8));
                unit        <= std_logic_vector(to_unsigned(48 + to_integer(unsigned(digits(3 downto 0))), 8));
                state       <= START_STATE;

        when others =>
             state <= START_STATE; -- Reset to START_STATE if any invalid state
        
        end case;

        end if;
    end process;

end architecture;