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
        btn_led         : out std_logic_vector (15 downto 0);
        Anode_Activate  : out std_logic_vector (3 downto 0);
        LED_out         : out std_logic_vector (6 downto 0);
        a4_vtrig        : out std_logic;
        --a5_vchg         : out std_logic;
        logic_shift_en  : out std_logic
    );
end entity top;

architecture rtl of top is

    signal wordAddress      : integer range 0 to 512            := 0;
    signal pixelData        : std_logic_vector(127 downto 0)    := (others => '0');
    signal currentRowNumber : integer range 0 to 16             := 0;
    signal charOutput_toBeSent  : std_logic_vector(7 downto 0)  := (others => '0');
    
--  page1_STRINGS
--        "                                        ",  -- Row 1
--        "          Nanopulse Controller          ",  -- Row 2
--        "- - - - - - - - - -- - - - - - - - - - -",  -- Row 3
--        "|                                      |",  -- Row 4
--        "|  Frequency              0 0 0 0 kHz  |",  -- Row 5
--        "|  Charge Delay Time      0 0 0 0  ns  |",  -- Row 6
--        "|  Pulse(s) per burst     0 0 0 0      |",  -- Row 7
--        "|  Pulse HV Supply Status 1 2 3 4 5 6  |",  -- Row 8
--        "|                                      |",  -- Row 9
--        "|                                      |",  -- Row 10
--        "|  Edit Signal Parameters    EN   DIS  |",  -- Row 11
--        "|  Signal Output             ON   OFF  |",  -- Row 12
--        "|  Pulse HV DC Supply        ON   OFF  |",  -- Row 13
--        "|                                      |",  -- Row 14
--        "- - - - - - - - - -- - - - - - - - - - -"   -- Row 15

--   page2_STRINGS
--        "                                        ",  -- Row 1
--        "          Nanopulse Controller          ",  -- Row 2
--        "- - - - - - - - - -- - - - - - - - - - -",  -- Row 3
--        "|  Power  voltage  status              |",  -- Row 4
--        "|    1    0 0 0 0   0 0 0              |",  -- Row 5
--        "|    2    0 0 0 0   0 0 0              |",  -- Row 6
--        "|    3    0 0 0 0   0 0 0     FIRE     |",  -- Row 7
--        "|    4    0 0 0 0   0 0 0              |",  -- Row 8
--        "|    5    0 0 0 0   0 0 0              |",  -- Row 9
--        "|    6    0 0 0 0   0 0 0              |",  -- Row 10
--        "|                                      |",  -- Row 11
--        "|                                      |",  -- Row 12
--        "|                                      |",  -- Row 13
--        "|                                      |",  -- Row 14
--        "- - - - - - - - - -- - - - - - - - - - -"   -- Row 15

    signal cmd_controller           :   std_logic_vector(8 downto 0)    := (others => '0');
    signal oled_ready               :   std_logic                       := '0';
    signal oled_request             :   std_logic                       := '0';
    signal exec_done                :   std_logic                       := '0';
    signal currentPage              :   std_logic                       := '0';
    signal key_reg                  :   std_logic_vector(4 downto 0)    := "00000";
    signal freq_buffer              :   integer range 0 to 9999         := 0000;
    signal delay_timer_buffer       :   integer range 0 to 9999         := 0000;
    signal pulse_num_buffer         :   integer range 0 to 9999         := 0000;
    signal clk_10mhz                :   std_logic                       := '0';
    signal clk_50mhz                :   std_logic                       := '0';
    signal operation_input          :   std_logic                       := '0';
    signal operation_feedback       :   std_logic                       := '0';
    signal char_to_pixel            :   std_logic_vector(7 downto 0)    := (others => '0');
    signal page1_char_pos           :   std_logic_vector(9 downto 0)    := (others => '0');
    signal load_page1_hex           :   std_logic_vector(7 downto 0)    := (others => '0');
    signal page2_char_pos           :   std_logic_vector(9 downto 0)    := (others => '0');
    signal load_page2_hex           :   std_logic_vector(7 downto 0)    := (others => '0');
    signal row_times_40             :   unsigned(9 downto 0)            := (others => '0');
    signal row_plus_addr            :   unsigned(9 downto 0)            := (others => '0');

    component clk_wiz_0
    port
     (-- Clock in ports
      -- Clock out ports
      clk_10mhz          : out    std_logic;
      clk_50mhz          : out    std_logic;
      clk_in1           : in     std_logic
     );
    end component;
    
    COMPONENT page1_rom
    PORT (
    clka : IN STD_LOGIC;
    addra : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
    douta : OUT STD_LOGIC_VECTOR(7 DOWNTO 0) 
    );
    END COMPONENT;
    
    COMPONENT page2_rom
    PORT (
    clka : IN STD_LOGIC;
    addra : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
    douta : OUT STD_LOGIC_VECTOR(7 DOWNTO 0) 
    );
    END COMPONENT;
    
begin

    pll_1 : clk_wiz_0
       port map ( 
      -- Clock out ports  
       clk_10mhz => clk_10mhz,
       clk_50mhz => clk_50mhz,
       -- Clock in ports
       clk_in1 => clk
     );
    
    page1_string : page1_rom
      PORT MAP (
        clka => clk,
        addra => page1_char_pos,
        douta => load_page1_hex
      );
    
    page2_string : page2_rom
    PORT MAP (
    clka => clk,
    addra => page2_char_pos,
    douta => load_page2_hex
    );
    -- Text engine instantiation
    te: entity work.textEngine
        port map (
            clk                         => clk,
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
            oled_request        => oled_request
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
            keyin               => key_reg,
            freq_buffer         => freq_buffer,
            delay_timer_buffer  => delay_timer_buffer,
            pulse_num_buffer    => pulse_num_buffer,
            operation_input     => operation_input,
            operation_feedback  => operation_feedback,           
            char_to_pixel       => char_to_pixel
        );

    scanner : entity work.keypad_scanner
        port map(
            clk         => clk,
            clk_10mhz   => clk_10mhz,
            reset       => reset,
            row         => row,
            col         => col,
            key_code    => key_reg,
            master_key  => btn_led(15 downto 1)
        );
    
    seg7    : entity work.seven_segment_display_VHDL
        port map(
            clock_100Mhz        => clk,
            reset               => reset,
            Anode_Activate      => Anode_Activate,
            LED_out             => LED_out,
            freq_buffer         => freq_buffer,
            delay_timer_buffer  => delay_timer_buffer,
            pulse_num_buffer    => pulse_num_buffer
        );

    pp_gen  : entity work.pp_gen
        port map(
            clk                 => clk,
            clk_10mhz           => clk_10mhz,
            operation_input     => operation_input,
            operation_feedback  => operation_feedback,
            a4_vtrig            => a4_vtrig,
            --a5_vchg             => a5_vchg,
            logic_shift_en      => logic_shift_en,
            master_key_0        => btn_led(0),
            freq_buffer         => freq_buffer,
            delay_timer_buffer  => delay_timer_buffer,
            pulse_num_buffer    => pulse_num_buffer
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

    -- Goal 2 : move EXEC out of oled_impl              -- complete
    -- Goal 3 : background color for each char          -- complete
    -- Goal 4 : individual char modify                  -- complete
    -- Goal 5 : multiplexer to reuse te instantiation   -- future-works

row_times_40 <= to_unsigned((currentRowNumber * 32) + (currentRowNumber * 8), 10);
row_plus_addr <= row_times_40 + wordAddress;

    process(char_to_pixel, currentPage, currentRowNumber,row_plus_addr,load_page1_hex,load_page2_hex)
    begin
        if currentRowNumber >= 0 and currentRowNumber < 15 then
            page1_char_pos <= std_logic_vector(row_plus_addr);   
            page2_char_pos <= std_logic_vector(row_plus_addr);
            if currentPage = '0' then
                charOutput_toBeSent <= load_page1_hex;
            elsif currentPage = '1' then
                charOutput_toBeSent <= load_page2_hex;
            else
                charOutput_toBeSent <= "00100000";
            end if;
        else
            charOutput_toBeSent <= char_to_pixel; -- Default to first charOutput
        end if;
    end process;

end architecture;
