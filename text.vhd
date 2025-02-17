library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity textRow is
    generic (
        ADDRESS_OFFSET  : integer := 0;
        INIT_STRING     : string(1 to 40) := (others => '0')
    );
    port (
        clk                         : in  std_logic;
        which_letter_in_sentence    : in  integer range 0 to 512 := 0;
        outByte                     : out std_logic_vector(7 downto 0) := (others => '0')
    );
end entity;

architecture rtl of textRow is

    type textBuffer_t is array (0 to 39) of std_logic_vector(7 downto 0);

    function init_textBuffer(str : string(1 to 40)) return textBuffer_t is
        variable temp : textBuffer_t := (others => (others => '0'));
    begin
        for i in 1 to 40 loop       -- seems like string is 1-indexed
            temp(i-1) := std_logic_vector(to_unsigned(character'pos(str(i)), 8));
        end loop;
        return temp;
    end function;

    signal textBuffer : textBuffer_t := init_textBuffer(INIT_STRING);

begin

    process(clk)
        variable computedAddress : integer := 0;
    begin
        if rising_edge(clk) then
            --computedAddress     := to_integer(unsigned(which_letter_in_sentence)) - ADDRESS_OFFSET;
            outByte             <= textBuffer(which_letter_in_sentence);
        end if;
    end process;

end architecture;



library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity textEngine is
    port (
        clk             : in    std_logic;
        wordAddress     : in    integer range 0 to 512; -- comes from screen
        pixelData       : out   std_logic_vector(127 downto 0);  -- goes into screen
        charOutput      : in    std_logic_vector(7 downto 0)  := (others => '0') 
    );
end entity;

architecture rtl of textEngine is
    type fontBuffer_t is array (0 to 1519) of std_logic_vector(7 downto 0);
    constant fontBuffer : fontBuffer_t := (
  x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", -- space
  x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"e0", x"0b", x"00", x"00", x"00", x"00", x"00", x"00", -- !
  x"00", x"00", x"00", x"00", x"00", x"00", x"e0", x"00", x"00", x"00", x"e0", x"00", x"00", x"00", x"00", x"00", -- "
  x"00", x"00", x"00", x"00", x"80", x"04", x"c0", x"0f", x"80", x"04", x"c0", x"0f", x"80", x"04", x"00", x"00", -- #
  x"00", x"00", x"00", x"00", x"80", x"04", x"40", x"05", x"e0", x"0f", x"40", x"05", x"40", x"02", x"00", x"00", -- $
  x"00", x"00", x"00", x"00", x"60", x"0c", x"00", x"02", x"00", x"01", x"80", x"00", x"60", x"0c", x"00", x"00", -- %
  x"00", x"00", x"00", x"00", x"c0", x"06", x"20", x"09", x"20", x"09", x"c0", x"07", x"00", x"09", x"00", x"00", -- &
  x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"e0", x"00", x"00", x"00", x"00", x"00", x"00", x"00", -- ;
  x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"c0", x"07", x"20", x"08", x"00", x"00", x"00", x"00", -- (
  x"00", x"00", x"00", x"00", x"00", x"00", x"20", x"08", x"c0", x"07", x"00", x"00", x"00", x"00", x"00", x"00", -- )
  x"00", x"00", x"00", x"00", x"80", x"02", x"00", x"01", x"c0", x"07", x"00", x"01", x"80", x"02", x"00", x"00", -- *
  x"00", x"00", x"00", x"00", x"00", x"01", x"00", x"01", x"c0", x"07", x"00", x"01", x"00", x"01", x"00", x"00", -- +
  x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"10", x"00", x"0c", x"00", x"00", x"00", x"00", x"00", x"00", -- ,
  x"00", x"00", x"00", x"00", x"00", x"01", x"00", x"01", x"00", x"01", x"00", x"01", x"00", x"01", x"00", x"00", -- -
  x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"0c", x"00", x"00", x"00", x"00", x"00", x"00", -- .
  x"00", x"00", x"00", x"00", x"00", x"0c", x"00", x"02", x"00", x"01", x"80", x"00", x"60", x"00", x"00", x"00", -- /
  x"00", x"00", x"00", x"00", x"c0", x"07", x"20", x"0a", x"20", x"09", x"a0", x"08", x"c0", x"07", x"00", x"00", -- 0
  x"00", x"00", x"00", x"00", x"00", x"08", x"40", x"08", x"e0", x"0f", x"00", x"08", x"00", x"08", x"00", x"00", -- 1
  x"00", x"00", x"00", x"00", x"40", x"08", x"20", x"0c", x"20", x"0a", x"20", x"09", x"c0", x"08", x"00", x"00", -- 2
  x"00", x"00", x"00", x"00", x"40", x"04", x"20", x"08", x"20", x"09", x"20", x"09", x"c0", x"06", x"00", x"00", -- 3
  x"00", x"00", x"00", x"00", x"80", x"01", x"60", x"01", x"00", x"01", x"00", x"01", x"e0", x"0f", x"00", x"00", -- 4
  x"00", x"00", x"00", x"00", x"e0", x"04", x"a0", x"08", x"a0", x"08", x"a0", x"08", x"20", x"07", x"00", x"00", -- 5
  x"00", x"00", x"00", x"00", x"c0", x"07", x"20", x"09", x"20", x"09", x"20", x"09", x"00", x"06", x"00", x"00", -- 6
  x"00", x"00", x"00", x"00", x"20", x"00", x"20", x"00", x"20", x"0e", x"20", x"01", x"e0", x"00", x"00", x"00", -- 7
  x"00", x"00", x"00", x"00", x"c0", x"06", x"20", x"09", x"20", x"09", x"20", x"09", x"c0", x"06", x"00", x"00", -- 8
  x"00", x"00", x"00", x"00", x"c0", x"04", x"20", x"09", x"20", x"09", x"20", x"09", x"c0", x"07", x"00", x"00", -- 9
  x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"c0", x"0c", x"00", x"00", x"00", x"00", x"00", x"00", -- :
  x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"10", x"c0", x"0c", x"00", x"00", x"00", x"00", x"00", x"00", -- ;
  x"00", x"00", x"00", x"00", x"00", x"01", x"80", x"02", x"80", x"02", x"40", x"04", x"40", x"04", x"00", x"00", -- <
  x"00", x"00", x"00", x"00", x"80", x"02", x"80", x"02", x"80", x"02", x"80", x"02", x"80", x"02", x"00", x"00", -- =
  x"00", x"00", x"00", x"00", x"40", x"04", x"40", x"04", x"80", x"02", x"80", x"02", x"00", x"01", x"00", x"00", -- >
  x"00", x"00", x"00", x"00", x"40", x"00", x"20", x"00", x"20", x"0a", x"20", x"01", x"c0", x"00", x"00", x"00", -- ?
  x"00", x"00", x"00", x"00", x"c0", x"07", x"20", x"08", x"a0", x"09", x"60", x"0a", x"c0", x"03", x"00", x"00", -- @
  x"00", x"00", x"00", x"00", x"c0", x"0f", x"20", x"02", x"20", x"02", x"20", x"02", x"c0", x"0f", x"00", x"00", -- A
  x"00", x"00", x"00", x"00", x"e0", x"0f", x"20", x"09", x"20", x"09", x"20", x"09", x"c0", x"06", x"00", x"00", -- B
  x"00", x"00", x"00", x"00", x"c0", x"07", x"20", x"08", x"20", x"08", x"20", x"08", x"40", x"04", x"00", x"00", -- C
  x"00", x"00", x"00", x"00", x"e0", x"0f", x"20", x"08", x"20", x"08", x"20", x"08", x"c0", x"07", x"00", x"00", -- D
  x"00", x"00", x"00", x"00", x"e0", x"0f", x"20", x"09", x"20", x"09", x"20", x"09", x"20", x"08", x"00", x"00", -- E
  x"00", x"00", x"00", x"00", x"e0", x"0f", x"20", x"01", x"20", x"01", x"20", x"01", x"20", x"00", x"00", x"00", -- F
  x"00", x"00", x"00", x"00", x"c0", x"07", x"20", x"08", x"20", x"09", x"20", x"09", x"40", x"07", x"00", x"00", -- G
  x"00", x"00", x"00", x"00", x"e0", x"0f", x"00", x"01", x"00", x"01", x"00", x"01", x"e0", x"0f", x"00", x"00", -- H
  x"00", x"00", x"00", x"00", x"20", x"08", x"20", x"08", x"e0", x"0f", x"20", x"08", x"20", x"08", x"00", x"00", -- I
  x"00", x"00", x"00", x"00", x"00", x"06", x"00", x"08", x"00", x"08", x"00", x"08", x"e0", x"07", x"00", x"00", -- J
  x"00", x"00", x"00", x"00", x"e0", x"0f", x"00", x"01", x"80", x"02", x"40", x"04", x"20", x"08", x"00", x"00", -- K
  x"00", x"00", x"00", x"00", x"e0", x"0f", x"00", x"08", x"00", x"08", x"00", x"08", x"00", x"08", x"00", x"00", -- L
  x"00", x"00", x"00", x"00", x"e0", x"0f", x"40", x"00", x"80", x"00", x"40", x"00", x"e0", x"0f", x"00", x"00", -- M
  x"00", x"00", x"00", x"00", x"e0", x"0f", x"80", x"00", x"00", x"01", x"00", x"02", x"e0", x"0f", x"00", x"00", -- N
  x"00", x"00", x"00", x"00", x"c0", x"07", x"20", x"08", x"20", x"08", x"20", x"08", x"c0", x"07", x"00", x"00", -- O
  x"00", x"00", x"00", x"00", x"e0", x"0f", x"20", x"01", x"20", x"01", x"20", x"01", x"c0", x"00", x"00", x"00", -- P
  x"00", x"00", x"00", x"00", x"c0", x"07", x"20", x"08", x"20", x"08", x"20", x"18", x"c0", x"17", x"00", x"00", -- Q
  x"00", x"00", x"00", x"00", x"e0", x"0f", x"20", x"01", x"20", x"01", x"20", x"01", x"c0", x"0e", x"00", x"00", -- R
  x"00", x"00", x"00", x"00", x"c0", x"04", x"20", x"09", x"20", x"09", x"20", x"09", x"40", x"06", x"00", x"00", -- S
  x"00", x"00", x"00", x"00", x"20", x"00", x"20", x"00", x"e0", x"0f", x"20", x"00", x"20", x"00", x"00", x"00", -- T
  x"00", x"00", x"00", x"00", x"e0", x"07", x"00", x"08", x"00", x"08", x"00", x"08", x"e0", x"07", x"00", x"00", -- U
  x"00", x"00", x"00", x"00", x"e0", x"01", x"00", x"06", x"00", x"08", x"00", x"06", x"e0", x"01", x"00", x"00", -- V
  x"00", x"00", x"00", x"00", x"e0", x"0f", x"00", x"04", x"00", x"02", x"00", x"04", x"e0", x"0f", x"00", x"00", -- W
  x"00", x"00", x"00", x"00", x"60", x"0c", x"80", x"02", x"00", x"01", x"80", x"02", x"60", x"0c", x"00", x"00", -- X
  x"00", x"00", x"00", x"00", x"60", x"00", x"80", x"00", x"00", x"0f", x"80", x"00", x"60", x"00", x"00", x"00", -- Y
  x"00", x"00", x"00", x"00", x"20", x"0c", x"20", x"0a", x"20", x"09", x"a0", x"08", x"60", x"08", x"00", x"00", -- Z
  x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"e0", x"0f", x"20", x"08", x"00", x"00", x"00", x"00", -- [
  x"00", x"00", x"00", x"00", x"60", x"00", x"80", x"00", x"00", x"01", x"00", x"02", x"00", x"0c", x"00", x"00", -- \
  x"00", x"00", x"00", x"00", x"00", x"00", x"20", x"08", x"e0", x"0f", x"00", x"00", x"00", x"00", x"00", x"00", -- ]
  x"00", x"00", x"00", x"00", x"80", x"00", x"40", x"00", x"20", x"00", x"40", x"00", x"80", x"00", x"00", x"00", -- ^
  x"00", x"00", x"00", x"00", x"00", x"08", x"00", x"08", x"00", x"08", x"00", x"08", x"00", x"08", x"00", x"00", -- _
  x"00", x"00", x"00", x"00", x"00", x"00", x"20", x"00", x"40", x"00", x"00", x"00", x"00", x"00", x"00", x"00", -- `
  x"00", x"00", x"00", x"00", x"00", x"07", x"80", x"08", x"80", x"08", x"80", x"08", x"80", x"0f", x"00", x"00", -- a
  x"00", x"00", x"00", x"00", x"e0", x"0f", x"80", x"08", x"80", x"08", x"80", x"08", x"00", x"07", x"00", x"00", -- b
  x"00", x"00", x"00", x"00", x"00", x"07", x"80", x"08", x"80", x"08", x"80", x"08", x"00", x"05", x"00", x"00", -- c
  x"00", x"00", x"00", x"00", x"00", x"07", x"80", x"08", x"80", x"08", x"80", x"08", x"e0", x"0f", x"00", x"00", -- d
  x"00", x"00", x"00", x"00", x"00", x"07", x"80", x"0a", x"80", x"0a", x"80", x"0a", x"00", x"03", x"00", x"00", -- e
  x"00", x"00", x"00", x"00", x"00", x"01", x"c0", x"0f", x"20", x"01", x"20", x"01", x"40", x"00", x"00", x"00", -- f
  x"00", x"00", x"00", x"00", x"00", x"07", x"80", x"28", x"80", x"28", x"80", x"28", x"80", x"1f", x"00", x"00", -- g
  x"00", x"00", x"00", x"00", x"e0", x"0f", x"80", x"00", x"80", x"00", x"80", x"00", x"00", x"0f", x"00", x"00", -- h
  x"00", x"00", x"00", x"00", x"00", x"08", x"80", x"08", x"a0", x"0f", x"00", x"08", x"00", x"08", x"00", x"00", -- i
  x"00", x"00", x"00", x"00", x"00", x"10", x"00", x"20", x"00", x"20", x"80", x"20", x"a0", x"1f", x"00", x"00", -- j
  x"00", x"00", x"00", x"00", x"e0", x"0f", x"00", x"02", x"00", x"02", x"00", x"05", x"80", x"08", x"00", x"00", -- k
  x"00", x"00", x"00", x"00", x"20", x"00", x"e0", x"07", x"00", x"08", x"00", x"08", x"00", x"08", x"00", x"00", -- l
  x"00", x"00", x"00", x"00", x"80", x"0f", x"80", x"00", x"80", x"0f", x"80", x"00", x"00", x"0f", x"00", x"00", -- m
  x"00", x"00", x"00", x"00", x"80", x"0f", x"80", x"00", x"80", x"00", x"80", x"00", x"00", x"0f", x"00", x"00", -- n
  x"00", x"00", x"00", x"00", x"00", x"07", x"80", x"08", x"80", x"08", x"80", x"08", x"00", x"07", x"00", x"00", -- o
  x"00", x"00", x"00", x"00", x"80", x"3f", x"80", x"08", x"80", x"08", x"80", x"08", x"00", x"07", x"00", x"00", -- p
  x"00", x"00", x"00", x"00", x"00", x"07", x"80", x"08", x"80", x"08", x"80", x"08", x"80", x"3f", x"00", x"00", -- q
  x"00", x"00", x"00", x"00", x"80", x"0f", x"00", x"01", x"80", x"00", x"80", x"00", x"00", x"01", x"00", x"00", -- r
  x"00", x"00", x"00", x"00", x"00", x"09", x"80", x"0a", x"80", x"0a", x"80", x"0a", x"80", x"04", x"00", x"00", -- s
  x"00", x"00", x"00", x"00", x"80", x"00", x"e0", x"07", x"80", x"08", x"80", x"08", x"00", x"08", x"00", x"00", -- t
  x"00", x"00", x"00", x"00", x"80", x"07", x"00", x"08", x"00", x"08", x"00", x"08", x"80", x"0f", x"00", x"00", -- u
  x"00", x"00", x"00", x"00", x"80", x"03", x"00", x"04", x"00", x"08", x"00", x"04", x"80", x"03", x"00", x"00", -- v
  x"00", x"00", x"00", x"00", x"80", x"07", x"00", x"08", x"00", x"06", x"00", x"08", x"80", x"07", x"00", x"00", -- w
  x"00", x"00", x"00", x"00", x"80", x"08", x"00", x"05", x"00", x"02", x"00", x"05", x"80", x"08", x"00", x"00", -- x
  x"00", x"00", x"00", x"00", x"80", x"07", x"00", x"28", x"00", x"28", x"00", x"28", x"80", x"1f", x"00", x"00", -- y
  x"00", x"00", x"00", x"00", x"80", x"08", x"80", x"0c", x"80", x"0a", x"80", x"09", x"80", x"08", x"00", x"00", -- z
  x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"01", x"c0", x"06", x"20", x"08", x"00", x"00", x"00", x"00", -- {
  x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"e0", x"0f", x"00", x"00", x"00", x"00", x"00", x"00", -- |
  x"00", x"00", x"00", x"00", x"00", x"00", x"20", x"08", x"c0", x"06", x"00", x"01", x"00", x"00", x"00", x"00", -- }
  x"00", x"00", x"00", x"00", x"00", x"01", x"80", x"00", x"00", x"01", x"00", x"01", x"80", x"00", x"00", x"00"  -- ~
);


    signal outputBuffer     : std_logic_vector(127 downto 0)    := (others => '0');
    signal chosenChar       : std_logic_vector(7 downto 0)      := (others => '0');
    signal wordAddress_vec  : std_logic_vector(7 downto 0)      := (others => '0');

    signal char_index           : integer := 0;

                    --function std_logic_vector_to_binary_string(v : std_logic_vector) return string is
                    --    variable result : string(v'range);
                    --begin
                    --    for i in v'range loop
                    --        if v(i) = '1' then
                    --            result(i) := '1';
                    --        else
                    --            result(i) := '0';
                    --       end if;
                    --    end loop;
                    --    return result;
                    --end function;

                    --function reverse_bits(data : std_logic_vector(7 downto 0)) return std_logic_vector is
                    --    variable reversed : std_logic_vector(7 downto 0);
                    --begin
                    --    for i in 0 to 7 loop
                    --        reversed(i) := data(7 - i);
                    --    end loop;
                    --    return reversed;
                    --end function;

begin

    process(charOutput)
    begin

        -- Validating the character is within range (32 to 126) 
        if (to_integer(unsigned(charOutput)) >= 32 and to_integer(unsigned(charOutput)) <= 126) then
            chosenChar <= charOutput;
        else
            chosenChar <= std_logic_vector(to_unsigned(32, 8));
        end if;
    end process;

    process (clk)
    begin
        if rising_edge(clk) then    

                char_index <= to_integer(unsigned(chosenChar)) - 32;
           
                for j in 0 to 15 loop
                    outputBuffer( (127 - 8*(j)) downto (120-8*(j)) ) <= fontBuffer(char_index * 16 + (15-j));
                end loop;

        end if;
    end process;

    -- Output the selected pixel data
    pixelData <= outputBuffer;

end architecture;
