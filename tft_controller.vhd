library ieee;
use ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;

entity tft_controller is
    Port (
        clk                 : in    std_logic;
        pixelData           : in    std_logic_vector(127 downto 0);
        wordAddress         : out   integer range 0 to 512;
        oled_ready          : in    std_logic;
        oled_request        : out   std_logic;
        cmd_controller      : out   std_logic_vector(8 downto 0);
        exec_done           : in    std_logic;
        currentRowNumber    : out   integer range 0 to 16;
        keyin               : in    std_logic_vector(4 downto 0);
        freq_buffer         : out   unsigned(13 downto 0);
        delay_timer_buffer  : out   unsigned(13 downto 0);
        pulse_num_buffer    : out   unsigned(13 downto 0);
        operation_input     : out   std_logic;
        operation_feedback  : in    std_logic;
        char_to_pixel       : out   std_logic_vector(7 downto 0);
        currentPage         : out   std_logic;
        voltageCh1          : in    std_logic_vector(11 downto 0);
        voltageCh2          : in    std_logic_vector(11 downto 0);
        adcEnable           : in    std_logic;
        adcEnable_reg       : out   std_logic
    );
end entity;

architecture rtl of tft_controller is

    -- states
    constant IDLE               : std_logic_vector(3 downto 0)      := "0000";
    constant WAIT_FOR_READY     : std_logic_vector(3 downto 0)      := "0001";
    constant LOAD_PAGE          : std_logic_vector(3 downto 0)      := "0010";
    constant WR_FROM_BUF        : std_logic_vector(3 downto 0)      := "0011";
    constant INPUT_TO_BUF       : std_logic_vector(3 downto 0)      := "0100";
    constant PREP               : std_logic_vector(3 downto 0)      := "0101";
    constant COMMAND_MODE       : std_logic_vector(3 downto 0)      := "0110";
    constant DRAW_MODE          : std_logic_vector(3 downto 0)      := "0111";
    constant INSERT_MODE        : std_logic_vector(3 downto 0)      := "1000";
    constant VISUAL_MODE        : std_logic_vector(3 downto 0)      := "1001";
    constant READ_ADC           : std_logic_vector(3 downto 0)      := "1010";
    signal state                : std_logic_vector(3 downto 0)      := IDLE;
    signal state_return         : std_logic_vector(3 downto 0)      := IDLE;

    constant ADC1               : unsigned(1 downto 0)              := "00";
    constant ADC2               : unsigned(1 downto 0)              := "01";
    signal adc_poll             : unsigned(1 downto 0)              := ADC1;

    -- buffer for user input digits
    type buffer_array is array(0 to 11) of unsigned(3 downto 0);
    signal input_buffer         : buffer_array;
    
    -- buffer to store pre-calculated pixel mapping
    type loc_array is array(0 to 25) of integer;
    signal char_loc_array            : loc_array;

    -- buffer to write multiple letters in one button press
    type dynamic_word_array is array(0 to 5) of std_logic_vector(7 downto 0);
    signal word_array               : dynamic_word_array;

    -- key_code states
    constant NUM0               : std_logic_vector(4 downto 0)  := "10000";
    constant NUM1               : std_logic_vector(4 downto 0)  := "01110";
    constant NUM2               : std_logic_vector(4 downto 0)  := "01101";
    constant NUM3               : std_logic_vector(4 downto 0)  := "01100";
    constant NUM4               : std_logic_vector(4 downto 0)  := "01011";
    constant NUM5               : std_logic_vector(4 downto 0)  := "01010";
    constant NUM6               : std_logic_vector(4 downto 0)  := "01001";
    constant NUM7               : std_logic_vector(4 downto 0)  := "01000";
    constant NUM8               : std_logic_vector(4 downto 0)  := "00111";
    constant NUM9               : std_logic_vector(4 downto 0)  := "00110";
    constant NUMA               : std_logic_vector(4 downto 0)  := "00101";
    constant NUMB               : std_logic_vector(4 downto 0)  := "00100";
    constant NUMC               : std_logic_vector(4 downto 0)  := "00011";
    constant NUM_STAR           : std_logic_vector(4 downto 0)  := "00001";
    constant NUM_HASH           : std_logic_vector(4 downto 0)  := "01111";
    constant ENTER              : std_logic_vector(4 downto 0)  := "00010";

    -- underline_flag for draw and delete condition
    -- underline integer to check how many digits passed
    signal underline_integer    : integer range 0 to 31             := 0;
    signal underline_flag       : std_logic                         := '1';

    -- Indicator status
    signal psu_status       : std_logic_vector(13 downto 0)          := "00000000000000";

    -- counter to check how many commands are sent
    signal sendDataIndex        :   integer                         := 0;

    -- pixel handling, scr handling related signals
    signal oled_request_reg     :   std_logic                       := '0';
    signal pixelCounter         :   integer                         := 0;
    signal char_pos_count       :   integer                         := 0;
    signal pixel_in_char_count  :   integer range 0 to 127          := 0;
    signal cont_num             :   integer range 0 to 6            := 0;
    signal pixel_col            :   integer range 0 to 320          := 0;
    signal frameBufferLowNibble :   std_logic                       := '1';
    signal inPixelData          : std_logic_vector(127 downto 0);
    
    -- signals to read 'out' signals
    signal currentRowNumber_reg :   integer range 0 to 15           := 0;
    signal freq_buffer_reg      :   unsigned(13 downto 0)           := (others => '0');
    signal pulse_num_buffer_reg :   unsigned(13 downto 0)           := (others => '0');
    signal delay_timer_buffer_reg  : unsigned(13 downto 0)          := (others => '0');

    -- scr_rom signals
    signal scr_wea              : std_logic_vector(0 downto 0)      := (others => '0');
    signal scr_addr             : std_logic_vector(16 downto 0)     := (others => '0');
    signal scr_din              : std_logic_vector(15 downto 0)     := (others => '0');
    signal scr_dout             : std_logic_vector(15 downto 0)     := (others => '0');
    
    -- pixel handling
    signal char_loc             : integer range 0 to 74880          := 0;
    signal input_overwrite      : std_logic                         := '0';
    signal letterColor          : std_logic_vector(15 downto 0)     := x"FFFF";
    signal backgroundColor      : std_logic_vector(15 downto 0)     := x"0000";

    signal thousandsCh1, hundredsCh1, tensCh1, unitsCh1 : std_logic_vector(7 downto 0) := (others => '0');
    signal thousandsCh2, hundredsCh2, tensCh2, unitsCh2 : std_logic_vector(7 downto 0) := (others => '0');
    signal delayCounter                                 : unsigned(27 downto 0)         := (others => '0');

    -- exec_caset, exec_paset sequence. This is same for all cases as whole screen is rewritten every time.
    type caset_paset_seq is array(0 to 9) of std_logic_vector(8 downto 0);
    constant exec_seq : caset_paset_seq := (
        -- Initialization Commands
        '0' & x"2A",
        '0' & x"00", -- Power Control B
        '1' & x"00", 
        '1' & x"00", -- x83, xC1
        '1' & x"F0",
        '0' & x"2B",
        '1' & x"00",
        '1' & x"00",
        '1' & x"01",
        '1' & x"3F"
    );

    -- store the scr buffer, 320*240 pixels
    COMPONENT scr_buf
    PORT (
        clka : IN STD_LOGIC;
        wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
        addra : IN STD_LOGIC_VECTOR(16 DOWNTO 0);
        dina : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
        douta : OUT STD_LOGIC_VECTOR(15 DOWNTO 0) 
    );
    END COMPONENT;


begin
    
    scr_rom : scr_buf
    PORT MAP (
        clka    => clk,
        wea     => scr_wea,
        addra   => scr_addr,
        dina    => scr_din,
        douta   => scr_dout
    );
    
    dec1 : entity work.toDec
        port map(
            clk         => clk,
            value       => voltageCh1,
            thousands   => thousandsCh1,
            hundreds    => hundredsCh1,
            tens        => tensCh1,
            unit        => unitsCh1
        );

    dec2 : entity work.toDec
        port map(
            clk         => clk,
            value       => voltageCh2,
            thousands   => thousandsCh2,
            hundreds    => hundredsCh2,
            tens        => tensCh2,
            unit        => unitsCh2
        );
    
    -- signals that are specified to be "out", cannot be read directly, need a register.
    wordAddress         <= char_pos_count;
    inPixelData         <= pixelData;
    oled_request        <= oled_request_reg;
    pulse_num_buffer    <= pulse_num_buffer_reg;
    freq_buffer         <= freq_buffer_reg;
    delay_timer_buffer  <= delay_timer_buffer_reg;    
    
    process(clk)
    begin
        if rising_edge(clk) then
            case state is
            when IDLE =>

                -- initialize input_buffer
                input_buffer(0) <= (others => '0');
                input_buffer(1) <= (others => '0');
                input_buffer(2) <= (others => '0');
                input_buffer(3) <= (others => '0');
                input_buffer(4) <= (others => '0');
                input_buffer(5) <= (others => '0');
                input_buffer(6) <= (others => '0');
                input_buffer(7) <= (others => '0');
                input_buffer(8) <= (others => '0');
                input_buffer(9) <= (others => '0');
                input_buffer(10) <= (others => '0');
                input_buffer(11) <= (others => '0');

--              char_row * 16 , char_col * 8 * 240
                -- initialize char_loc_array, can be transferred into a rom ip in the future.
                char_loc_array(0) <= 49984;
                char_loc_array(1) <= 53824;
                char_loc_array(2) <= 57664;
                char_loc_array(3) <= 61504;
                char_loc_array(4) <= 50000;
                char_loc_array(5) <= 53840;
                char_loc_array(6) <= 57680;
                char_loc_array(7) <= 61520;
                char_loc_array(8) <= 50016;
                char_loc_array(9) <= 53856;
                char_loc_array(10) <= 57696;
                char_loc_array(11) <= 61536;
                char_loc_array(12) <= 50032;
                char_loc_array(13) <= 53872;
                char_loc_array(14) <= 57712;
                char_loc_array(15) <= 61552;
                char_loc_array(16) <= 65392;
                char_loc_array(17) <= 69232;
                char_loc_array(18) <= 53920;
                char_loc_array(19) <= 53936;
                char_loc_array(20) <= 53952;
                char_loc_array(21) <= 63520;
                char_loc_array(22) <= 63536;
                char_loc_array(23) <= 63552;
                char_loc_array(24) <= 19264;
                char_loc_array(25) <= 19280;

                -- initialize word_array
                word_array(0)           <= (others => '0');
                word_array(1)           <= (others => '0');
                word_array(2)           <= (others => '0');
                word_array(3)           <= (others => '0');
                word_array(4)           <= (others => '0');

                -- initialize registers
                freq_buffer_reg         <= (others => '0');
                delay_timer_buffer_reg  <= (others => '0');
                pulse_num_buffer_reg    <= (others => '0');
                underline_integer <= 0;

                currentPage <= '0';
                -- wait for tft_ili9341.vhd to finish INIT_SEQ
                oled_request_reg <= '1';
                state        <= WAIT_FOR_READY;

            when WAIT_FOR_READY =>
            
            -- wait for tft_ili9341.vhd to finish INIT_SEQ
                if oled_ready = '1' then
                    state        <= LOAD_PAGE;
                    state_return <= COMMAND_MODE;
                end if;

            when LOAD_PAGE =>
                -- iteratively (row by row) load the page1_rom (containing ascii), into 320*240 pixels
                -- then state => WR_FROM_BUF to write the page
                -- then return to LOP, COMMAND_MODE

                if sendDataIndex = 0 then
                    sendDataIndex <= sendDataIndex + 1;
                    pixelCounter <= 0;
                    char_pos_count <= 0;
                    pixel_in_char_count <= 0;
                    pixel_col           <= 0;
                    currentRowNumber <= currentRowNumber_reg;

                elsif pixelCounter < 5120 then

--                    Pixel mapping example
--                    00 240 420 ... ... 1920 ...  (row 1 2nd letter)
--                    01 241 421 ... ... ...  
--                    02 242 422 ... ... ...  
--                    03 243 423 ... ... ...  
--                    04 244 424 ... ... ...  
--                    05 245 425 ... ... ...  
--                    06 246 426 ... ... ...  
--                    07 247 427 ... ... ...  
--                    08 248 428 ... ... ...  
--                    09 249 429 ... ... ...  
--                    10 250 430 ... ... ...  
--                    11 251 431 ... ... ...  
--                    12 252 432 ... ... ...  
--                    13 253 433 ... ... ...  
--                    14 254 434 ... ... ...  
--                    15 255 435 ... ... ...  
--                    16 ... ... ... (row 2 first letter) 

                    -- 1. Pixels have size 16*8, are loaded vertically, totalling to 128 pixels
                    -- this complicated equation is convert pixel position, because we load character by character, thus need to map pixels individually

                    scr_wea     <= "1";
                    scr_addr    <= std_logic_vector(to_unsigned( currentRowNumber_reg * 16 + pixel_col*240 + pixelCounter mod 16  ,17));                    
                    if inPixelData(pixel_in_char_count) = '1' then
                        scr_din <= x"FFFF";
                    else
                        scr_din <= x"0000";
                    end if;

                    pixelCounter <= pixelCounter + 1;

                    if pixelCounter mod 16 = 15 then
                        pixel_col <= pixel_col + 1;
                    end if;

                    if pixel_in_char_count = 127 then
                        if char_pos_count < 39 then
                            char_pos_count <= char_pos_count + 1;
                        end if;
                        pixel_in_char_count <= 0;
                    else
                        pixel_in_char_count <= pixel_in_char_count + 1;
                    end if;

                elsif currentRowNumber_reg < 14 then
                    sendDataIndex <= 0;
                    currentRowNumber_reg <= currentRowNumber_reg + 1;
                else
                    scr_wea       <= "0";
                    currentRowNumber_reg <= currentRowNumber_reg + 1;
                    currentRowNumber <= currentRowNumber_reg;
                    sendDataIndex <= 0;
                    char_pos_count <= 0;
                    state <= WR_FROM_BUF;
                end if;


            -- 3 A 6 B 9 C are used to light up HV power status 1 2 3 4 5 6 respectively
            -- 1 2 4 5 7 8 are used to light up EN DIS ON OFF
            -- STAR is used to fire
            -- 0 is as estop
            -- HASH is used  to change page
            -- background color and letterColor sets corresponding color, following BGR 565, little endian 

            when COMMAND_MODE =>
            
                state_return <= COMMAND_MODE;
            
                case keyin is
                when ENTER =>
                    state <= DRAW_MODE;
                    if operation_feedback = '1' then
                        operation_input <= '0';
                    end if;
                when NUM3 =>
                    char_to_pixel <= "00110001";
                    char_loc <= char_loc_array(12);
                    
                    input_overwrite <= '1';
                    state <= INPUT_TO_BUF;
                    
                    if psu_status(1) = '0' then
                        backgroundColor <= x"F800";
                        psu_status(1) <= '1';
                    else
                        backgroundColor <= x"0000";   
                        psu_status(1) <= '0';                        
                    end if;
                    
                when NUMA =>
                    char_to_pixel <= "00110010";
                    char_loc <= char_loc_array(13);
                    
                    input_overwrite <= '1';
                    state <= INPUT_TO_BUF;

                    if psu_status(2) = '0' then
                        backgroundColor <= x"F800";
                        psu_status(2) <= '1';
                    else
                        backgroundColor <= x"0000";  
                        psu_status(2) <= '0';                        
                    end if;

                when NUM6 =>
                    char_to_pixel <= "00110011";
                    char_loc <= char_loc_array(14);
                    
                    input_overwrite <= '1';
                    state <= INPUT_TO_BUF;

                    if psu_status(3) = '0' then
                        backgroundColor <= x"F800";
                        psu_status(3) <= '1';
                    else
                        backgroundColor <= x"0000";  
                        psu_status(3) <= '0';                        
                    end if;
                    
                when NUMB =>
                    char_to_pixel <= "00110100";
                    char_loc <= char_loc_array(15);
                    
                    input_overwrite <= '1';
                    state <= INPUT_TO_BUF;

                    if psu_status(4) = '0' then
                        backgroundColor <= x"F800";
                        psu_status(4) <= '1';
                    else
                        backgroundColor <= x"0000";  
                        psu_status(4) <= '0';                        
                    end if;
                    
               when NUM9 =>
                    char_to_pixel <= "00110101";
                    char_loc <= char_loc_array(16);
                    
                    input_overwrite <= '1';
                    state <= INPUT_TO_BUF;

                    if psu_status(5) = '0' then
                        backgroundColor <= x"F800";
                        psu_status(5) <= '1';
                    else
                        backgroundColor <= x"0000";  
                        psu_status(5) <= '0';                        
                    end if;
               when NUMC =>
                    char_to_pixel <= "00110110";
                    char_loc <= char_loc_array(17);
                    
                    input_overwrite <= '1';
                    state <= INPUT_TO_BUF;

                    if psu_status(6) = '0' then
                        backgroundColor <= x"F800";
                        psu_status(6) <= '1';
                    else
                        backgroundColor <= x"0000";  
                        psu_status(6) <= '0';                        
                    end if;

                when NUM1 =>
                
                    char_to_pixel <= "00100000";
                    char_loc     <= char_loc_array(18);
                    
                    input_overwrite <= '1';
                    state <= INPUT_TO_BUF;
                    
                    word_array(0) <= x"45";
                    word_array(1) <= x"4E";
                    word_array(2) <= "00100000";
                    cont_num <= 3;
                    if psu_status(7) = '0' then
                        backgroundColor <= x"5022";
                        psu_status(7) <= '1';
                    else
                        backgroundColor <= x"0000";  
                        psu_status(7) <= '0';                        
                    end if;                    

                when NUM2 =>
                    char_to_pixel <= "00100000";
                    char_loc     <= char_loc_array(21);
                    
                    input_overwrite <= '1';
                    state <= INPUT_TO_BUF;
                    
                    word_array(0) <= x"44";
                    word_array(1) <= x"49";
                    word_array(2) <= x"53";
                    word_array(3) <= "00100000";
                    cont_num <= 4;
                    if psu_status(8) = '0' then
                        backgroundColor <= x"5022";
                        psu_status(8) <= '1';
                    else
                        backgroundColor <= x"0000";  
                        psu_status(8) <= '0';                        
                    end if;  
                    
                when NUM4 =>
                    char_to_pixel <= "00100000";
                    char_loc     <= char_loc_array(19);
                    
                    input_overwrite <= '1';
                    state <= INPUT_TO_BUF;
                    
                    word_array(0) <= x"4F";
                    word_array(1) <= x"4E";
                    word_array(2) <= "00100000";
                    cont_num <= 3;
                    if psu_status(9) = '0' then
                        backgroundColor <= x"5022";
                        psu_status(9) <= '1';
                    else
                        backgroundColor <= x"0000";  
                        psu_status(9) <= '0';                        
                    end if;   

                when NUM5 =>
                    char_to_pixel <= "00100000";
                    char_loc     <= char_loc_array(22);
                    
                    input_overwrite <= '1';
                    state <= INPUT_TO_BUF;
                    
                    word_array(0) <= x"4F";
                    word_array(1) <= x"46";
                    word_array(2) <= x"46";
                    word_array(3) <= "00100000";
                    cont_num <= 4;
                    if psu_status(10) = '0' then
                        backgroundColor <= x"5022";
                        psu_status(10) <= '1';
                    else
                        backgroundColor <= x"0000";  
                        psu_status(10) <= '0';                        
                    end if;  

                when NUM7 =>
                    char_to_pixel <= "00100000";
                    char_loc     <= char_loc_array(20);
                    
                    input_overwrite <= '1';
                    state <= INPUT_TO_BUF;
                    
                    word_array(0) <= x"4F";
                    word_array(1) <= x"4E";
                    word_array(2) <= "00100000";
                    cont_num <= 3;
                    if psu_status(11) = '0' then
                        backgroundColor <= x"5022";
                        psu_status(11) <= '1';
                    else
                        backgroundColor <= x"0000";  
                        psu_status(11) <= '0';                        
                    end if;  
                    
                when NUM8 =>

                    char_to_pixel <= "00100000";
                    char_loc     <= char_loc_array(23);
                    
                    input_overwrite <= '1';
                    state <= INPUT_TO_BUF;
                    
                    word_array(0) <= x"4F";
                    word_array(1) <= x"46";
                    word_array(2) <= x"46";
                    word_array(3) <= "00100000";
                    cont_num <= 4;
                    if psu_status(12) = '0' then
                        backgroundColor <= x"5022";
                        psu_status(12) <= '1';
                    else
                        backgroundColor <= x"0000";  
                        psu_status(12) <= '0';                        
                    end if;  

                when NUM_STAR =>
                    -- firing
                    freq_buffer_reg         <=  (input_buffer(0) & "0000000000") - ((input_buffer(0) & "0000") + (input_buffer(0) & "000")) +  -- 1000x
                                                (input_buffer(1) & "0000000")    - ((input_buffer(1) & "0000") + (input_buffer(1) & "000") + (input_buffer(1) & "00")) +  -- 100x
                                                (input_buffer(2) & "000")        + (input_buffer(2) & "0") +                                                              -- 10x
                                                input_buffer(3);                                                                                                         -- 1x
                                        
                    delay_timer_buffer_reg  <=  (input_buffer(4) & "0000000000") - ((input_buffer(4) & "0000") + (input_buffer(4) & "000")) +  -- 1000x
                                                (input_buffer(5) & "0000000")    - ((input_buffer(5) & "0000") + (input_buffer(5) & "000") + (input_buffer(5) & "00")) +  -- 100x
                                                (input_buffer(6) & "000")        + (input_buffer(6) & "0") +                                                              -- 10x
                                                input_buffer(7);                                                                                                         -- 1x
                                            
                    pulse_num_buffer_reg    <=  (input_buffer(8) & "0000000000") - ((input_buffer(8) & "0000") + (input_buffer(8) & "000")) +  -- 1000x
                                                (input_buffer(9) & "0000000")    - ((input_buffer(9) & "0000") + (input_buffer(9) & "000") + (input_buffer(5) & "00")) +  -- 100x
                                                (input_buffer(10) & "000")        + (input_buffer(10) & "0") +                                                              -- 10x
                                                input_buffer(11);                                                                                                         -- 1x
                    if operation_feedback = '0' then
                        operation_input <= '1';
                    else
                        operation_input <= '0';
                    end if;
                    
                when NUM_HASH =>
                    currentRowNumber_reg <= 0;
                    currentPage <= '1';
                    psu_status(6) <= '1';
                    state <= LOAD_PAGE;
                    state_return <= VISUAL_MODE;

                when others =>
                    null;
                end case;

            -- see voltage status
            when VISUAL_MODE =>
            
                if delayCounter = x"2FAF080" then
                    adcEnable_reg <= '1';       
                    state <= READ_ADC;
                    delayCounter <= (others => '0');
                else
                    delayCounter <= delayCounter + 1;
                end if;
                
                case keyin is
                when ENTER =>

                when NUM3 =>
                    
                when NUMA =>

                when NUM6 =>
                    
                when NUMB =>
                    
                when NUM9 =>

                when NUMC =>

                when NUM1 =>

                when NUM2 =>
                    
                when NUM4 =>

                when NUM5 =>

                when NUM7 =>

                when NUM8 =>

                when NUM_STAR =>
                    
                when NUM_HASH =>
                    psu_status <= (others => '0');
                    currentRowNumber_reg <= 0;
                    currentPage <= '0';
                    psu_status(6) <= '0';                        
                    state <= LOAD_PAGE;
                    state_return <= COMMAND_MODE;
                    delayCounter <= (others => '0');
                when others =>
                    null;
                end case;

            when READ_ADC =>

                case adc_poll is
                
                when ADC1 =>                
                    if adcEnable = '0' then
                        adcEnable_reg <= '0';
                        char_to_pixel <= thousandsCh1;
                        char_loc     <= char_loc_array(24);
                        
                        input_overwrite <= '1';
                        state <= INPUT_TO_BUF;
                        
                        backgroundColor <= x"0000";
                        word_array(0) <= "00100000";
                        word_array(1) <= hundredsCh1;
                        word_array(2) <= "00100000";
                        word_array(3) <= tensCh1;
                        word_array(4) <= "00100000";
                        word_array(5) <= unitsCh1;
                        cont_num <= 6;
                        state_return <= READ_ADC;
                        adc_poll <= adc_poll + 1;
                    end if;
                when ADC2 =>
                
                    if adcEnable = '0' then
                        char_to_pixel <= thousandsCh2;
                        char_loc     <= char_loc_array(25);
                        
                        input_overwrite <= '1';
                        state <= INPUT_TO_BUF;
                        
                         backgroundColor <= x"0000";

                        word_array(0) <= "00100000";
                        word_array(1) <= hundredsCh2;
                        word_array(2) <= "00100000";
                        word_array(3) <= tensCh2;
                        word_array(4) <= "00100000";
                        word_array(5) <= unitsCh2;
                        cont_num <= 6;
                        state_return <= VISUAL_MODE;
                        adc_poll <= (others => '0');
                    end if;
                    
                when others =>
                    null;                
                end case;
                
            -- INSERT MODE is similar to how lab power supply work, will iterate through all digits and allow user to edit
            when INSERT_MODE =>
            
                case keyin is
                when ENTER =>
                    state <= DRAW_MODE;
                when NUM1 =>
                    char_to_pixel <= "00110001";
                    input_buffer(underline_integer-1) <= "0001";
                    state <= DRAW_MODE;
                when NUM2 =>
                    char_to_pixel <= "00110010";
                    input_buffer(underline_integer-1) <= "0010";
                    state <= DRAW_MODE;
                when NUM3 =>
                    char_to_pixel <= "00110011";
                    input_buffer(underline_integer-1) <= "0011";
                    state <= DRAW_MODE;
                when NUM4 =>
                    char_to_pixel <= "00110100";
                    input_buffer(underline_integer-1) <= "0100";
                    state <= DRAW_MODE;
                when NUM5 =>
                    char_to_pixel <= "00110101";
                    input_buffer(underline_integer-1) <= "0101";
                    state <= DRAW_MODE;
                when NUM6 =>
                    char_to_pixel <= "00110110";
                    input_buffer(underline_integer-1) <= "0110";
                    state <= DRAW_MODE;
                when NUM7 =>
                    char_to_pixel <= "00110111";
                    input_buffer(underline_integer-1) <= "0111";
                    state <= DRAW_MODE;
                when NUM8 =>
                    char_to_pixel <= "00111000";
                    input_buffer(underline_integer-1) <= "1000";
                    state <= DRAW_MODE;
                when NUM9 =>
                    char_to_pixel <= "00111001";
                    input_buffer(underline_integer-1) <= "1001";
                    state <= DRAW_MODE;
                when NUM0 =>
                    char_to_pixel <= "00110000";
                    input_buffer(underline_integer-1) <= "0000";
                    state <= DRAW_MODE;
                when others =>
                    null;
                end case;

            -- DRAW_MODE checks if underline is drawn, otherwise just shift the underline.
            when DRAW_MODE =>

                if(underline_integer = 0) then
                    char_to_pixel <= "01011111";
--                         char_row * 16 , char_col * 8 * 240
                    char_loc        <= char_loc_array(0);
                    state           <= INPUT_TO_BUF;

                    underline_integer <= 1;
                    state_return <= INSERT_MODE;
                else
                    char_loc    <= char_loc_array(underline_integer-1);
                    backgroundColor     <= x"0000";

                    if underline_flag = '1' then
                        case input_buffer(underline_integer-1) is
                        when "0000" => char_to_pixel <= x"30";
                        when "0001" => char_to_pixel <= x"31";
                        when "0010" => char_to_pixel <= x"32";
                        when "0011" => char_to_pixel <= x"33";
                        when "0100" => char_to_pixel <= x"34";
                        when "0101" => char_to_pixel <= x"35";
                        when "0110" => char_to_pixel <= x"36";
                        when "0111" => char_to_pixel <= x"37";
                        when "1000" => char_to_pixel <= x"38";
                        when "1001" => char_to_pixel <= x"39";
                        when others => char_to_pixel <= x"30";
                        end case;
                        
                        input_overwrite <= '1';
                    else
                        char_to_pixel <= "01011111";
                    end if;

                    state <= INPUT_TO_BUF;
                    
                    if underline_flag = '0' then
                        -- 2nd iteration will draw underline, then return to INSERT_MODE.
                        state_return <= INSERT_MODE;
                        underline_flag <= '1';
                    elsif (underline_integer-1) = 11 then
                        state_return <= COMMAND_MODE;
                        underline_integer <= 0;
                    else
                        -- 1st iteration will erase underline, then increment underline_integer += 1 
                        underline_integer <= underline_integer + 1; 
                        underline_flag <= '0';
                        state_return <= DRAW_MODE;
                    end if;

               end if;

            -- writes to the buffer, the pixels with '1'. 
            -- to redraw background, input_overwrite needs to be set to '1'
            -- color palette is set based on 2 signals.
            when INPUT_TO_BUF => 
            if sendDataIndex = 0 then
                sendDataIndex       <= sendDataIndex + 1;
                pixelCounter        <= 0;
                pixel_col           <= 0;
                char_pos_count      <= 0;

            elsif pixelCounter <= 127 then

                    if frameBufferLowNibble = '0' then
                        if inPixelData(pixelCounter) = '1' then
                            scr_addr    <= std_logic_vector(to_unsigned(char_loc + pixel_col*240 + char_pos_count*1920 + pixelCounter mod 16  ,17));
                            scr_wea     <= "1";
                            scr_din     <= letterColor;
                        elsif input_overwrite = '1' then
                            scr_addr    <= std_logic_vector(to_unsigned(char_loc + pixel_col*240 + char_pos_count*1920 + pixelCounter mod 16  ,17));
                            scr_wea     <= "1";
                            scr_din     <= backgroundColor;
                        end if;
                        
                        if pixelCounter mod 16 = 15 then
                            pixel_col <= pixel_col + 1;
                        end if;
                        
                        if pixelCounter = 127 and char_pos_count < cont_num then
                            char_pos_count <= char_pos_count + 1;
                            char_to_pixel <= word_array(char_pos_count);
                            pixelCounter <= 0;
                            pixel_col <= 0;
                        else
                            pixelCounter <= pixelCounter + 1;
                        end if;
                    end if;
                    frameBufferLowNibble <= not frameBufferLowNibble;
                else
                    scr_wea         <= "0";
                    input_overwrite <= '0';
                    cont_num        <= 0;
                    sendDataIndex   <= 0;
                    state           <= PREP;
                end if;

            -- PREP executes the exec_caset, exec_paset before going into WR_FROM_BUF
            when PREP =>

                if oled_request_reg = '0' then
                    oled_request_reg <= '1';        
                elsif oled_ready = '1' then
                    oled_request_reg <= '0';
                    if sendDataIndex < 10 then
                        cmd_controller <= exec_seq(sendDataIndex);
                        sendDataIndex <= sendDataIndex + 1;
                    else
                        sendDataIndex <= 0;
                        state <= WR_FROM_BUF;
                    end if;
                end if;
                 
            -- WR_FROM_BUF executes exec_ramwr and writes full screen from buffer
            -- currentRowNumber is set to 16, so the char_to_pixel can be accessed by other states (see top.vhd)       
            when WR_FROM_BUF =>
                
                if oled_request_reg = '0' then
                    oled_request_reg <= '1';        
                elsif oled_ready = '1' then
                    oled_request_reg <= '0';
                    if sendDataIndex = 0 then
                        cmd_controller <= '0' & x"2C";
                        sendDataIndex <= sendDataIndex + 1;
                        pixelCounter <= 0;
                        scr_addr <= (others => '0');

                    elsif pixelCounter < 76800 then

                        scr_addr <= std_logic_vector(to_unsigned(pixelCounter, 17));

                        if frameBufferLowNibble = '0' then
                            cmd_controller  <= '1' & scr_dout(15 downto 8);
                            pixelCounter    <= pixelCounter + 1;
                        else
                            cmd_controller  <= '1' & scr_dout(7 downto 0);
                        end if;
                        frameBufferLowNibble <= not frameBufferLowNibble;

                    else
                        sendDataIndex <= 0;
                        
                        -- DONE --
                        currentRowNumber <= 16;
                        oled_request_reg <= '1';
                        state     <= state_return;

                    end if;
                end if;

                
            when others =>
                null;
            end case;
        end if;
    end process;

end architecture;