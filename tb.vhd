library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb is
end entity;

architecture rtl of tb is

    constant freq_clk        : time := 37 ns;
    signal clk         : std_logic;
    signal tft_sck         : std_logic;
    signal tft_sdi         : std_logic;
    signal tft_cs          : std_logic;
    signal tft_dc          : std_logic;
    signal tft_reset       : std_logic;

    signal wordAddress      : integer range 0 to 512                         := 0;
    signal pixelData        : std_logic_vector(127 downto 0)    := (others => '0');
    signal currentRowNumber : std_logic_vector(3 downto 0)      := (others => '0');

    signal charOutput_toBeSent  : std_logic_vector(7 downto 0)  := (others => '0');

    type charArray is array (0 to 14) of std_logic_vector(7 downto 0); -- Array for char outputs
    signal charOutputArray : charArray;
    
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

    signal cmd_controller      : std_logic_vector(8 downto 0) := (others => '0');
    signal oled_ready          : std_logic  := '0';
    signal oled_request        : std_logic  := '0';
    signal exec_done           : std_logic  := '0';


begin

    -- Text engine instantiation
    te: entity work.textEngine
        port map (
            clk          => clk,
            wordAddress  => wordAddress,
            pixelData    => pixelData,
            charOutput   => charOutput_toBeSent
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
            currentRowNumber    => currentRowNumber
        );

    -- wordAddress is counter for which letter out of the 40 letters in the sentence.
    -- the hex data of that letter will be stored in outByte, which is charOutput.
    -- charOutput is sent to textEngine to output 128 (16*8) bit pixel data.


    -- string is not synthesizable (cannot be input), can be work by using brute force generic.

    t1: entity work.textRow
        generic map (
            ADDRESS_OFFSET  => 0,
            INIT_STRING     => page1_STRINGS(0)
            )
        port map (
            clk         => clk,
            readAddress => wordAddress,
            outByte     => charOutputArray(0)
        );

    t2: entity work.textRow
        generic map (
            ADDRESS_OFFSET  => 0,
            INIT_STRING     => page1_STRINGS(1)
            )
        port map (
            clk         => clk,
            readAddress => wordAddress,
            outByte     => charOutputArray(1)
        );
    t3: entity work.textRow
        generic map (
            ADDRESS_OFFSET  => 0,
            INIT_STRING     => page1_STRINGS(2)
            )
        port map (
            clk         => clk,
            readAddress => wordAddress,
            outByte     => charOutputArray(2)
        );
    t4: entity work.textRow
        generic map (
            ADDRESS_OFFSET  => 0,
            INIT_STRING     => page1_STRINGS(3)
            )
        port map (
            clk         => clk,
            readAddress => wordAddress,
            outByte     => charOutputArray(3)
        );
    t5: entity work.textRow
        generic map (
            ADDRESS_OFFSET  => 0,
            INIT_STRING     => page1_STRINGS(4)
            )
        port map (
            clk         => clk,
            readAddress => wordAddress,
            outByte     => charOutputArray(4)
        );
    t6: entity work.textRow
        generic map (
            ADDRESS_OFFSET  => 0,
            INIT_STRING     => page1_STRINGS(5)
            )
        port map (
            clk         => clk,
            readAddress => wordAddress,
            outByte     => charOutputArray(5)
        );
    t7: entity work.textRow
        generic map (
            ADDRESS_OFFSET  => 0,
            INIT_STRING     => page1_STRINGS(6)
            )
        port map (
            clk         => clk,
            readAddress => wordAddress,
            outByte     => charOutputArray(6)
        );
    t8: entity work.textRow
        generic map (
            ADDRESS_OFFSET  => 0,
            INIT_STRING     => page1_STRINGS(7)
            )
        port map (
            clk         => clk,
            readAddress => wordAddress,
            outByte     => charOutputArray(7)
        );
    t9: entity work.textRow
        generic map (
            ADDRESS_OFFSET  => 0,
            INIT_STRING     => page1_STRINGS(8)
            )
        port map (
            clk         => clk,
            readAddress => wordAddress,
            outByte     => charOutputArray(8)
        );
    t10: entity work.textRow
        generic map (
            ADDRESS_OFFSET  => 0,
            INIT_STRING     => page1_STRINGS(9)
            )
        port map (
            clk         => clk,
            readAddress => wordAddress,
            outByte     => charOutputArray(9)
        );
    t11: entity work.textRow
        generic map (
            ADDRESS_OFFSET  => 0,
            INIT_STRING     => page1_STRINGS(10)
            )
        port map (
            clk         => clk,
            readAddress => wordAddress,
            outByte     => charOutputArray(10)
        );
    t12: entity work.textRow
        generic map (
            ADDRESS_OFFSET  => 0,
            INIT_STRING     => page1_STRINGS(11)
            )
        port map (
            clk         => clk,
            readAddress => wordAddress,
            outByte     => charOutputArray(11)
        );
    t13: entity work.textRow
        generic map (
            ADDRESS_OFFSET  => 0,
            INIT_STRING     => page1_STRINGS(12)
            )
        port map (
            clk         => clk,
            readAddress => wordAddress,
            outByte     => charOutputArray(12)
        );
    t14: entity work.textRow
        generic map (
            ADDRESS_OFFSET  => 0,
            INIT_STRING     => page1_STRINGS(13)
            )
        port map (
            clk         => clk,
            readAddress => wordAddress,
            outByte     => charOutputArray(13)
        );
    t15: entity work.textRow
        generic map (
            ADDRESS_OFFSET  => 0,
            INIT_STRING     => page1_STRINGS(14)
            )
        port map (
            clk         => clk,
            readAddress => wordAddress,
            outByte     => charOutputArray(14)
        );

    process(currentRowNumber, charOutputArray)
    variable rowIndex : integer := 0;
    begin
        rowIndex := to_integer(unsigned(currentRowNumber)); -- Convert currentRowNumber to integer
        if rowIndex >= 0 and rowIndex < 15 then
            charOutput_toBeSent <= charOutputArray(rowIndex);
        else
            charOutput_toBeSent <= charOutputArray(0); -- Default to first charOutput
        end if;
    end process;

    clk_gen : process
    begin
        clk <= '0';
        wait for (freq_clk/2);
        clk <= '1';
        wait for (freq_clk/2);
    end process;

end architecture;



