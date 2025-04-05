
-- Adapted from https://www.fpga4student.com/2017/09/vhdl-code-for-seven-segment-display.html

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
entity seven_segment_display_VHDL is
    Port (  
        clock_100Mhz        : in std_logic;-- 100Mhz clock on Basys 3 FPGA board
        reset               : in std_logic; -- reset
        Anode_Activate      : out std_logic_vector (3 downto 0);-- 4 Anode signals
        LED_out             : out std_logic_vector (6 downto 0);-- Cathode patterns of 7-segment display 
        freq_buffer         : in   unsigned(13 downto 0);
        delay_timer_buffer  : in   unsigned(13 downto 0);
        pulse_num_buffer    : in   unsigned(13 downto 0)
        );
end seven_segment_display_VHDL;

architecture Behavioral of seven_segment_display_VHDL is

signal one_second_counter       : unsigned (27 downto 0);
-- counter for generating 1-second clock enable
signal one_second_enable        : std_logic;
-- one second enable for counting numbers
signal displayed_number         : std_logic_vector (15 downto 0);
-- counting decimal number to be displayed on 4-digit 7-segment display
signal LED_BCD                  : std_logic_vector (3 downto 0);
signal refresh_counter          : unsigned (19 downto 0);
-- creating 10.5ms refresh period
signal LED_activating_counter   : std_logic_vector(1 downto 0);
-- the other 2-bit for creating 4 LED-activating signals
-- count         0    ->  1  ->  2  ->  3
-- activates    LED1    LED2   LED3   LED4
-- and repeat

type led_array is array (0 to 2) of integer range 0 to 9999;
signal output_array     : led_array;
signal output_integer   : integer range 0 to 2  := 0;
signal thousands    : std_logic_vector(3 downto 0);
signal hundreds     : std_logic_vector(3 downto 0);
signal tens         : std_logic_vector(3 downto 0);
signal ones         : std_logic_vector(3 downto 0);

begin
-- VHDL code for BCD to 7-segment decoder
-- Cathode patterns of the 7-segment LED display 
process(LED_BCD)
begin
    case LED_BCD is
    when "0000" => LED_out <= "0000001"; -- "0"     
    when "0001" => LED_out <= "1001111"; -- "1" 
    when "0010" => LED_out <= "0010010"; -- "2" 
    when "0011" => LED_out <= "0000110"; -- "3" 
    when "0100" => LED_out <= "1001100"; -- "4" 
    when "0101" => LED_out <= "0100100"; -- "5" 
    when "0110" => LED_out <= "0100000"; -- "6" 
    when "0111" => LED_out <= "0001111"; -- "7" 
    when "1000" => LED_out <= "0000000"; -- "8"     
    when "1001" => LED_out <= "0000100"; -- "9" 
    when "1010" => LED_out <= "0000010"; -- a

    when "1011" => LED_out <= "1100000"; -- b
    when "1100" => LED_out <= "0110001"; -- C
    when "1101" => LED_out <= "1000010"; -- d
    when "1110" => LED_out <= "0110000"; -- E
    when "1111" => LED_out <= "0111000"; -- F
    end case;
end process;

process(displayed_number)
variable number_int : integer range 0 to 9999;
begin
    number_int := to_integer(unsigned(displayed_number));
    
    -- Extract each digit
    thousands   <= std_logic_vector(to_unsigned(number_int / 1000, 4));
    hundreds    <= std_logic_vector(to_unsigned((number_int mod 1000) / 100, 4));
    tens        <= std_logic_vector(to_unsigned((number_int mod 100) / 10, 4));
    ones        <= std_logic_vector(to_unsigned(number_int mod 10, 4));
end process;

-- 7-segment display controller
-- generate refresh period of 10.5ms
process(clock_100Mhz,reset)
begin 
    if(reset='1') then
        refresh_counter <= (others => '0');
    elsif(rising_edge(clock_100Mhz)) then
        refresh_counter <= refresh_counter + x"00001";
    end if;
end process;
 LED_activating_counter <= std_logic_vector(refresh_counter(19 downto 18));
-- 4-to-1 MUX to generate anode activating signals for 4 LEDs 
process(LED_activating_counter, thousands, hundreds, tens, ones)
begin
    case LED_activating_counter is
    when "00" =>
        Anode_Activate <= "0111"; 
        -- activate LED1 and Deactivate LED2, LED3, LED4
        LED_BCD <= thousands;
        -- the first hex digit of the 16-bit number
    when "01" =>
        Anode_Activate <= "1011"; 
        -- activate LED2 and Deactivate LED1, LED3, LED4
        LED_BCD <= hundreds;
        -- the second hex digit of the 16-bit number
    when "10" =>
        Anode_Activate <= "1101"; 
        -- activate LED3 and Deactivate LED2, LED1, LED4
        LED_BCD <= tens;
        -- the third hex digit of the 16-bit number
    when "11" =>
        Anode_Activate <= "1110"; 
        -- activate LED4 and Deactivate LED2, LED3, LED1
        LED_BCD <= ones;
        -- the fourth hex digit of the 16-bit number    
    end case;
end process;

-- Counting the number to be displayed on 4-digit 7-segment Display 
-- on Basys 3 FPGA board
process(clock_100Mhz, reset)
begin
        if(reset='1') then
            one_second_counter <= (others => '0');
        elsif(rising_edge(clock_100Mhz)) then
            if(one_second_counter>=x"5F5E0FF") then
                one_second_counter <= (others => '0');
            else
                one_second_counter <= one_second_counter + x"0000001";
            end if;
        end if;
end process;
one_second_enable <= '1' when one_second_counter=x"5F5E0FF" else '0';

output_array(0) <= to_integer(freq_buffer);
output_array(1) <= to_integer(delay_timer_buffer);
output_array(2) <= to_integer(pulse_num_buffer);

process(clock_100Mhz, reset)
begin
        if(reset='1') then
            displayed_number <= (others => '0');
        elsif(rising_edge(clock_100Mhz)) then
             if(one_second_enable='1') then
                displayed_number <= std_logic_vector(to_unsigned(output_array(output_integer),16));
                if output_integer = 2 then
                    output_integer <= 0;
                else
                    output_integer <= output_integer + 1;
                end if;
             end if;
        end if;
end process;


end Behavioral;

