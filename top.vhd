library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top is
    port (
        clk             : in  std_logic;
        tft_sck         : out std_logic;
        tft_sdi         : out std_logic;
        tft_cs          : out std_logic;
        tft_dc          : out std_logic;
        tft_reset       : out std_logic;
        reset           : in  std_logic;
        row             : out std_logic_vector (3 downto 0);
        col             : in  std_logic_vector (3 downto 0);
        key_code        : out std_logic_vector (4 downto 0)
    );
end entity top;

architecture rtl of top is
    signal wordAddress      : integer range 0 to 512                         := 0;
    signal pixelData        : std_logic_vector(127 downto 0)    := (others => '0');
    signal currentRowNumber : std_logic_vector(3 downto 0)      := (others => '0');

    signal charOutput_toBeSent  : std_logic_vector(7 downto 0)  := (others => '0');

    type charArray is array (0 to 14) of std_logic_vector(7 downto 0); -- Array for char outputs
    signal charOutputArray1 : charArray;
    signal charOutputArray2 : charArray;
    
    type string_array is array (0 to 14) of string(1 to 40);
    constant page1_STRINGS : string_array := (
        "                                        ",  -- Row 1
        "          Nanopulse Controller          ",  -- Row 2
        "- - - - - - - - - -- - - - - - - - - - -",  -- Row 3
        "|                                      |",  -- Row 4
        "|  Frequency              0 0 0 0 kHz  |",  -- Row 5
        "|  Charge Delay Time      0 0 0 0  ns  |",  -- Row 6
        "|  Pulse(s) per burst     0 0 0 0      |",  -- Row 7
        "|  Pulse HV Supply Status 1 2 3 4 5 6  |",  -- Row 8
        "|                                      |",  -- Row 9
        "|                                      |",  -- Row 10
        "|  Edit Signal Parameters    EN   DIS  |",  -- Row 11
        "|  Signal Output             ON   OFF  |",  -- Row 12
        "|  Pulse HV DC Supply        ON   OFF  |",  -- Row 13
        "|                                      |",  -- Row 14
        "- - - - - - - - - -- - - - - - - - - - -"   -- Row 15
    );

    constant page2_STRINGS : string_array := (
        "                                        ",  -- Row 1
        "          Nanopulse Controller          ",  -- Row 2
        "- - - - - - - - - -- - - - - - - - - - -",  -- Row 3
        "|  Power  voltage  status              |",  -- Row 4
        "|    1    0 0 0 0   0 0 0              |",  -- Row 5
        "|    2    0 0 0 0   0 0 0              |",  -- Row 6
        "|    3    0 0 0 0   0 0 0     FIRE     |",  -- Row 7
        "|    4    0 0 0 0   0 0 0              |",  -- Row 8
        "|    5    0 0 0 0   0 0 0              |",  -- Row 9
        "|    6    0 0 0 0   0 0 0              |",  -- Row 10
        "|                                      |",  -- Row 11
        "|                                      |",  -- Row 12
        "|                                      |",  -- Row 13
        "|                                      |",  -- Row 14
        "- - - - - - - - - -- - - - - - - - - - -"   -- Row 15
    );

    signal cmd_controller      : std_logic_vector(8 downto 0) := (others => '0');
    signal oled_ready          : std_logic := '0';
    signal oled_request        : std_logic := '0';
    signal exec_done           : std_logic := '0';
    signal currentPage         : std_logic := '0';
    signal key_reg             : std_logic_vector(4 downto 0) := "00000";

begin

    -- Text engine instantiation
    te: entity work.textEngine
        port map (
            clk                         => clk,
            wordAddress                 => wordAddress,
            pixelData                   => pixelData,
            charOutput                  => charOutput_toBeSent
        );

    -- Screen instantiation
    scr: entity work.tft_ili9341
        port map (
            clk                 => clk,
            tft_sck             => tft_sck,
            tft_sdi             => tft_sdi,
            tft_dc              => tft_dc,
            tft_reset           => tft_reset,
            tft_cs              => tft_cs,
            cmd_controller      => cmd_controller,
            oled_ready          => oled_ready,
            oled_request        => oled_request,
            exec_done           => exec_done
        );

    controller: entity work.tft_controller
        port map(
            clk                 => clk,
            pixelData           => pixelData,
            wordAddress         => wordAddress,
            cmd_controller      => cmd_controller,
            oled_ready          => oled_ready,
            oled_request        => oled_request,
            exec_done           => exec_done,
            currentRowNumber    => currentRowNumber,
            keyin               => key_reg
        );

    scanner : entity work.keypad_scanner
        port map(
            clk         => clk,
            reset       => reset,
            row         => row,
            col         => col,
            key_code    => key_reg
        );

    -- wordAddress is counter for which letter out of the 40 letters in the sentence.
    -- the hex data of that letter will be stored in outByte, which is charOutput.
    -- charOutput is sent to textEngine to output 128 (16*8) bit pixel data.


    -- string is not synthesizable (cannot be input), can be work by using brute force generic.

    -- pixelCounter counts 5120 in the row

    -- wordCounter --> wordAddress --> textRow --> charOutputArray --> charOutput_toBeSent --> pixelData(textEngine)(16x8) --> pixelData(screen)

    -- wordCounter counts the 40 letter sentence --> wordAddress --> textRow points to that letter, store that letter in charOutputArray
    -- Based on currentRowNumber, charOutput_toBeSent will point to letter from that row.

    -- NOTE: basically all 15 instances of textRow, will have pointer move from 0 to 39 words, but currentRowNumber picks the row.
    -- NOTE: tried to summarize into 1 instance, not possible because string is not synthesizable

    -- Goal 2 : move EXEC out of oled_impl          -- complete
    -- Goal 3 : background color for each char      -- abandoned
    -- Goal 4 : individual char modify              -- ongoing

    gen_page1: for i in 0 to 14 generate
    t1: entity work.textRow
        generic map (
            ADDRESS_OFFSET  => 0,
            INIT_STRING     => page1_STRINGS(i) -- Use strings from page1
        )
        port map (
            clk                         => clk,
            which_letter_in_sentence    => wordAddress,
            outByte                     => charOutputArray1(i) -- Output to charOutputArray1
        );
    end generate;

    gen_page2: for i in 0 to 14 generate
    t2: entity work.textRow
        generic map (
            ADDRESS_OFFSET  => 0,
            INIT_STRING     => page2_STRINGS(i) -- Use strings from page2
        )
        port map (
            clk                         => clk,
            which_letter_in_sentence    => wordAddress,
            outByte                     => charOutputArray2(i) -- Output to charOutputArray1
        );
    end generate;

    process(currentRowNumber, charOutputArray1,charOutputArray2, currentPage)
    variable rowIndex : integer := 0;
    begin
        rowIndex := to_integer(unsigned(currentRowNumber)); -- Convert currentRowNumber to integer
        if rowIndex >= 0 and rowIndex < 15 then
            if currentPage = '0' then
                charOutput_toBeSent <= charOutputArray1(rowIndex);
            elsif currentPage = '1' then
                charOutput_toBeSent <= charOutputArray2(rowIndex);
            else
                charOutput_toBeSent <= charOutputArray1(rowIndex);
            end if;
        else
            charOutput_toBeSent <= charOutputArray1(rowIndex); -- Default to first charOutput
        end if;
    end process;

    key_code <= key_reg;

end architecture;

