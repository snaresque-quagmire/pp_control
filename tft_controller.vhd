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
        exec_done           : out   std_logic;
        currentRowNumber    : out   std_logic_vector(3 downto 0);
        keyin               : in    std_logic_vector(4 downto 0)
    );
end entity;

architecture rtl of tft_controller is

    -- states
    constant IDLE               : std_logic_vector(3 downto 0)      := "0000";
    constant WAIT_FOR_READY     : std_logic_vector(3 downto 0)      := "0001";
    constant EXECUTE            : std_logic_vector(3 downto 0)      := "0010";
    constant DONE               : std_logic_vector(3 downto 0)      := "0011";
    constant LOP                : std_logic_vector(3 downto 0)      := "0100";
    constant EXEC_CASET         : std_logic_vector(3 downto 0)      := "0101";
    constant EXEC_PASET         : std_logic_vector(3 downto 0)      := "0110";
    constant EXEC_RAMWR         : std_logic_vector(3 downto 0)      := "0111";
    constant UNDERLINE          : std_logic_vector(3 downto 0)      := "1000";
    constant CHAR_WR            : std_logic_vector(3 downto 0)      := "1001";
    signal state                : std_logic_vector(3 downto 0)      := IDLE;
    signal state_register       : std_logic_vector(3 downto 0)      := IDLE;
  
    -- counter
    constant ROW1               : integer   := 0;
    constant ROW14              : integer   := 13;
    constant LAST_ROW           : integer   := 14;
    constant HACK_TO_FIX        : integer   := 15;
    constant WAIT_FOR_KEYPAD    : integer   := 16;
    constant DRAW_MODE          : integer   := 17;
    constant ENTER_MODE         : integer   := 18;

    -- drawing states
    constant DRAW_INIT        : std_logic_vector(3 downto 0)    := "0001";
    constant DRAW_12        : std_logic_vector(3 downto 0)      := "0010";
    constant DRAW_STATE3        : std_logic_vector(3 downto 0)  := "0011";
    constant DRAW_STATE4        : std_logic_vector(3 downto 0)  := "0100";
    constant DRAW_STATE5        : std_logic_vector(3 downto 0)  := "0101";
    constant DRAW_STATE6        : std_logic_vector(3 downto 0)  := "0110";
    constant DRAW_STATE7        : std_logic_vector(3 downto 0)  := "0111";
    constant DRAW_STATE15       : std_logic_vector(3 downto 0)  := "1111";
    signal draw_state           : std_logic_vector(3 downto 0)  := DRAW_INIT;

    -- key_code
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
    constant ENTER              : std_logic_vector(4 downto 0)  := "00010";

    -- underline position
    type array_of_underline_pos is array(0 to 7) of std_logic_vector(8 downto 0);
    signal underline_pos_row    : array_of_underline_pos;
    signal underline_pos_col    : array_of_underline_pos;
    signal underline_integer    : integer range 0 to 31             := 0;
    signal underline_flag       : std_logic                         := '1';

    -- scanf
    signal scanf_reg            : integer range 0 to 9              := 0;

    -- internal te
    signal not_used         : integer range 0 to 512                := 0;
    signal charPixelData    : std_logic_vector(127 downto 0)        := (others => '0');
    signal char_to_pixel    : std_logic_vector(7 downto 0)          := (others => '0');


    type array_of_commands is array(0 to 5) of std_logic_vector(8 downto 0);
    signal dynamic_commands     : array_of_commands;
    constant NUM_OF_CMD         :  integer                          := 5;
    signal command_index        :  integer range 0 to NUM_OF_CMD    := 0;
    signal oled_request_reg     :   std_logic                       := '0';

    signal counter              :   integer                         := 0;
    signal currentRowNumber_reg :   integer range 0 to 15           := 0;
    signal sendDataIndex        :   integer                         := 0;
    type dynamic_array is array(0 to 9) of std_logic_vector(8 downto 0);
    signal dynamic_data_array   :   dynamic_array;
    signal sendDataBytes        :   integer                         := 4;

    signal pixelCounter         :   integer                         := 0;
    signal wordCounter          :   integer                         := 0;
    signal counterPerPixel      :   integer range 0 to 127          := 0;
    signal frameBufferLowNibble :   std_logic                       := '1';

    signal inPixelData          : std_logic_vector(127 downto 0);

begin
    
    te_for_controller: entity work.textEngine
        port map (
            clk                         => clk,
            wordAddress                 => not_used,
            pixelData                   => charPixelData,
            charOutput                  => char_to_pixel
        );
    
    wordAddress <= wordCounter;
    inPixelData <= pixelData;
    oled_request <= oled_request_reg;

    process(clk)
    begin
        if rising_edge(clk) then
            case state is
            when IDLE =>
                -- 4x PASET, 4x CASET, 2x color
                dynamic_data_array(0) <= '1' & x"00";
                dynamic_data_array(1) <= '1' & x"00";
                dynamic_data_array(2) <= '1' & x"00";
                dynamic_data_array(3) <= '1' & x"00";
                dynamic_data_array(4) <= '1' & x"00";
                dynamic_data_array(5) <= '1' & x"00";
                dynamic_data_array(6) <= '1' & x"00";
                dynamic_data_array(7) <= '1' & x"00";
                dynamic_data_array(8) <= '1' & x"00";
                dynamic_data_array(9) <= '1' & x"00";

                underline_pos_row(0) <= '1' & std_logic_vector(to_unsigned(208,8));
                underline_pos_row(1) <= '1' & std_logic_vector(to_unsigned(215,8));
                underline_pos_row(2) <= '1' & std_logic_vector(to_unsigned(224,8));
                underline_pos_row(3) <= '1' & std_logic_vector(to_unsigned(231,8));
                underline_pos_row(4) <= '1' & std_logic_vector(to_unsigned(240,8));
                underline_pos_row(5) <= '1' & std_logic_vector(to_unsigned(247,8));
                underline_pos_row(6) <= '1' & x"00";                                    -- 256
                underline_pos_row(7) <= '1' & x"07";                                    -- 263

                underline_pos_col(0) <= '1' & std_logic_vector(to_unsigned(79,8));
                underline_pos_col(1) <= '1' & std_logic_vector(to_unsigned(95,8));
                underline_pos_col(2) <= '1' & std_logic_vector(to_unsigned(111,8));
                underline_pos_col(3) <= '1' & std_logic_vector(to_unsigned(128,8));
                underline_pos_col(4) <= '1' & x"01";                                    -- hack to obtain > 255 in row
                underline_pos_col(5) <= '1' & std_logic_vector(to_unsigned(64,8));
                underline_pos_col(6) <= '1' & std_logic_vector(to_unsigned(80,8));
                underline_pos_col(7) <= '1' & std_logic_vector(to_unsigned(96,8));

                underline_integer <= 0;

                oled_request_reg <= '1';
                command_index <= 0;
                exec_done <= '0';
                state        <= WAIT_FOR_READY;

            when WAIT_FOR_READY =>
                if oled_ready = '1' then
                    state        <= LOP;
                end if;

            when EXECUTE =>
                -- Send current command
                cmd_controller <= dynamic_commands(command_index);
                if command_index = NUM_OF_CMD then
                    state <= DONE;
                else
                    command_index <= command_index + 1;
                    state <= WAIT_FOR_READY;
                    oled_request_reg <= '1';
                end if;

            when LOP =>
                case counter is
                when ROW1 to ROW14 =>
                    currentRowNumber <= std_logic_vector(to_unsigned(currentRowNumber_reg,4));
                    dynamic_data_array(0) <= '1' & x"00";
                    dynamic_data_array(1) <= '1' & std_logic_vector(to_unsigned(16*currentRowNumber_reg,8));
                    dynamic_data_array(2) <= '1' & x"00";
                    dynamic_data_array(3) <= '1' & std_logic_vector(to_unsigned(15 + (16*currentRowNumber_reg),8));
                    dynamic_data_array(4) <= '1' & x"00";
                    dynamic_data_array(5) <= '1' & x"00";
                    dynamic_data_array(6) <= '1' & x"01";
                    dynamic_data_array(7) <= '1' & x"40";
                    state <= EXEC_CASET;
                    state_register <= EXEC_RAMWR;
                when LAST_ROW =>
                    currentRowNumber <= std_logic_vector(to_unsigned(currentRowNumber_reg,4));
                    dynamic_data_array(0) <= '1' & x"00";
                    dynamic_data_array(1) <= '1' & x"E0";
                    dynamic_data_array(2) <= '1' & x"00";
                    dynamic_data_array(3) <= '1' & x"EF";
                    dynamic_data_array(4) <= '1' & x"00";
                    dynamic_data_array(5) <= '1' & x"00";
                    dynamic_data_array(6) <= '1' & x"01";
                    dynamic_data_array(7) <= '1' & x"40";
                    state <= EXEC_CASET;
                    state_register <= EXEC_RAMWR;

                when HACK_TO_FIX =>
                    counter <= counter + 1;
                    state <= DONE; -- This is hack, to be fixed. Problem because apparently need to oled_request_reg <= '1';

                when WAIT_FOR_KEYPAD =>
                    case keyin is
                    when ENTER =>
                        draw_state <= DRAW_INIT;
                        counter <= DRAW_MODE;
                    when others =>
                        null;
                    end case;

                when ENTER_MODE =>

                    case keyin is
                    when ENTER =>
                        case underline_integer is
                        when 0 =>
                            draw_state <= DRAW_INIT;
                            counter <= DRAW_MODE;
                        when 1 to 12 =>
                            draw_state <= DRAW_12;
                            counter <= DRAW_MODE;
                        when others =>
                            null;
                        end case;
                    when NUM1 =>
                        char_to_pixel <= "00110001";
                        draw_state <= DRAW_STATE3;
                        counter <= DRAW_MODE;
                    when NUM2 =>
                        char_to_pixel <= "00110010";
                        draw_state <= DRAW_STATE3;
                        counter <= DRAW_MODE;
                    when NUM3 =>
                        char_to_pixel <= "00110011";
                        draw_state <= DRAW_STATE3;
                        counter <= DRAW_MODE;
                    when NUM4 =>
                        char_to_pixel <= "00110100";
                        draw_state <= DRAW_STATE3;
                        counter <= DRAW_MODE;
                    when NUM5 =>
                        char_to_pixel <= "00110101";
                        draw_state <= DRAW_STATE3;
                        counter <= DRAW_MODE;
                    when NUM6 =>
                        char_to_pixel <= "00110110";
                        draw_state <= DRAW_STATE3;
                        counter <= DRAW_MODE;
                    when NUM7 =>
                        char_to_pixel <= "00110111";
                        draw_state <= DRAW_STATE3;
                        counter <= DRAW_MODE;
                    when NUM8 =>
                        char_to_pixel <= "00111000";
                        draw_state <= DRAW_STATE3;
                        counter <= DRAW_MODE;
                    when NUM9 =>
                        char_to_pixel <= "00111001";
                        draw_state <= DRAW_STATE3;
                        counter <= DRAW_MODE;
                    when NUM0 =>
                        char_to_pixel <= "00110000";
                        draw_state <= DRAW_STATE3;
                        counter <= DRAW_MODE;
                    when others =>
                        null;
                    end case;

                when DRAW_MODE =>

                    case draw_state is
                    when DRAW_INIT =>
                        dynamic_data_array(0) <= '1' & x"00";
                        dynamic_data_array(1) <= underline_pos_col(0);
                        dynamic_data_array(2) <= '1' & x"00";
                        dynamic_data_array(3) <= underline_pos_col(0);
                        dynamic_data_array(4) <= '1' & x"00";
                        dynamic_data_array(5) <= underline_pos_row(0);
                        dynamic_data_array(6) <= '1' & x"00";
                        dynamic_data_array(7) <= underline_pos_row(1);
                        dynamic_data_array(8) <= '1' & x"FF";
                        dynamic_data_array(9) <= '1' & x"FF";
                        state <= EXEC_CASET;
                        state_register <= UNDERLINE;

                        underline_integer <= 1;
                        counter <= ENTER_MODE;

                    when DRAW_12 =>
                        
                        -- underline_flag  '1'remove underline  '0'draw underline
                        dynamic_data_array(0) <= '1' & x"00";
                        dynamic_data_array(1) <= underline_pos_col((underline_integer-1) / 4);
                        dynamic_data_array(2) <= '1' & x"00";
                        dynamic_data_array(3) <= underline_pos_col((underline_integer-1) / 4);
                        dynamic_data_array(5) <= underline_pos_row((2*((underline_integer-1) mod 4)));
                        dynamic_data_array(7) <= underline_pos_row((2*((underline_integer-1) mod 4))+1);

                        if underline_flag = '1' then
                            dynamic_data_array(8) <= '1' & x"00";
                            dynamic_data_array(9) <= '1' & x"00";
                        else
                            dynamic_data_array(8) <= '1' & x"FF";
                            dynamic_data_array(9) <= '1' & x"FF";
                        end if;

                        if ((underline_integer-1) mod 4) = 3 then
                            dynamic_data_array(4) <= underline_pos_col(4);
                            dynamic_data_array(6) <= underline_pos_col(4);
                        else
                            dynamic_data_array(4) <= '1' & x"00";
                            dynamic_data_array(6) <= '1' & x"00";
                        end if;

                        state <= EXEC_CASET;
                        state_register <= UNDERLINE;
                        
                        if underline_flag = '0' then
                            counter <= ENTER_MODE;
                            underline_flag <= '1';
                        elsif (underline_integer-1) = 11 then
                            counter <= WAIT_FOR_KEYPAD;
                            underline_integer <= 0;
                        else
                            underline_integer <= underline_integer + 1; 
                            underline_flag <= '0';
                        end if;

                    when DRAW_STATE3 =>
                        if underline_flag = '1' then
                            dynamic_data_array(0) <= '1' & x"00";
                            dynamic_data_array(1) <= underline_pos_col(5 + ((underline_integer-1) / 4));
                            dynamic_data_array(2) <= '1' & x"00";
                            dynamic_data_array(3) <= underline_pos_col((underline_integer-1) / 4);
                            --dynamic_data_array(4) <= '1' & x"00";
                            dynamic_data_array(5) <= underline_pos_row((2*((underline_integer-1) mod 4)));
                            --dynamic_data_array(6) <= '1' & x"00";
                            dynamic_data_array(7) <= underline_pos_row((2*((underline_integer-1) mod 4))+1);
                            dynamic_data_array(8) <= '1' & x"FF";
                            dynamic_data_array(9) <= '1' & x"FF";

                            if ((underline_integer-1) mod 4) = 3 then
                                dynamic_data_array(4) <= underline_pos_col(4);
                                dynamic_data_array(6) <= underline_pos_col(4);
                            else
                                dynamic_data_array(4) <= '1' & x"00";
                                dynamic_data_array(6) <= '1' & x"00";
                            end if;

                            state <= EXEC_CASET;
                            state_register <= CHAR_WR;
                            underline_flag <= '0';
                        else
                            underline_flag <= '1';
                            --underline_integer <= underline_integer - 1;
                            draw_state <= DRAW_12;
                            
                        end if;

                    when DRAW_STATE4 =>

                    when DRAW_STATE5 =>

                    when DRAW_STATE6 =>

                    when DRAW_STATE7 =>

                    when DRAW_STATE15 =>

                    when others =>
                        null;
                    end case;

                when others =>
                    null;
                end case;

            when EXEC_CASET =>
                
                if oled_request_reg = '0' then
                    oled_request_reg <= '1';        
                elsif oled_ready = '1' then
                    oled_request_reg <= '0';
                    if sendDataIndex = 0 then
                        cmd_controller <= '0' & x"2A";
                        sendDataIndex <= sendDataIndex + 1;
                    elsif sendDataIndex <= sendDataBytes then
                        cmd_controller <= dynamic_data_array(sendDataIndex-1);
                        sendDataIndex <= sendDataIndex + 1;

                    else
                        sendDataIndex <= 0;
                        dynamic_data_array(0) <= dynamic_data_array(4);
                        dynamic_data_array(1) <= dynamic_data_array(5);
                        dynamic_data_array(2) <= dynamic_data_array(6);
                        dynamic_data_array(3) <= dynamic_data_array(7);
                        dynamic_data_array(4) <= '1' & x"00";
                        dynamic_data_array(5) <= '1' & x"00";
                        dynamic_data_array(6) <= '1' & x"00";
                        dynamic_data_array(7) <= '1' & x"00";
                        state <= EXEC_PASET;
                    end if;
    
                end if;

            when EXEC_PASET =>

                if oled_request_reg = '0' then
                    oled_request_reg <= '1';        
                elsif oled_ready = '1' then
                    oled_request_reg <= '0';
                    if sendDataIndex = 0 then
                        cmd_controller <= '0' & x"2B";
                        sendDataIndex <= sendDataIndex + 1;
                    elsif sendDataIndex <= sendDataBytes then
                        cmd_controller <= dynamic_data_array(sendDataIndex-1);
                        sendDataIndex <= sendDataIndex + 1;
                    else
                        sendDataIndex <= 0;
                        dynamic_data_array(0) <= '1' & x"00";
                        dynamic_data_array(1) <= '1' & x"00";
                        dynamic_data_array(2) <= '1' & x"00";
                        dynamic_data_array(3) <= '1' & x"00";

                        state <= state_register;
                    end if;

                end if;

            when EXEC_RAMWR =>
            
                if oled_request_reg = '0' then
                    oled_request_reg <= '1';        
                elsif oled_ready = '1' then
                    oled_request_reg <= '0';
                    if sendDataIndex = 0 then
                        cmd_controller <= '0' & x"2C";
                        sendDataIndex <= sendDataIndex + 1;
                        pixelCounter <= 0;
                        wordCounter <= 0;
                        counterPerPixel <= 0;

                    elsif pixelCounter < 5120 then

                        if inPixelData(counterPerPixel) = '1' then

                            if frameBufferLowNibble = '0' then
                                cmd_controller <= '1' & x"FF";
                                pixelCounter <= pixelCounter + 1;
                                if counterPerPixel = 127 then
                                    if wordCounter < 39 then
                                        wordCounter <= wordCounter + 1;
                                    end if;
                                        counterPerPixel <= 0;
                                else
                                    counterPerPixel <= counterPerPixel + 1;
                                end if;
                            else
                                cmd_controller <= '1' & x"FF";
                            end if;

                            frameBufferLowNibble <= not frameBufferLowNibble;
                        
                        elsif inPixelData(counterPerPixel) = '0' then

                            if frameBufferLowNibble = '0' then
                                cmd_controller <= '1' & x"00";
                                pixelCounter <= pixelCounter + 1;

                                if counterPerPixel = 127 then
                                    if wordCounter < 39 then
                                        wordCounter <= wordCounter + 1;
                                    end if;                                        
                                    counterPerPixel <= 0;
                                else
                                    counterPerPixel <= counterPerPixel + 1;
                                end if;

                            else
                                cmd_controller <= '1' & x"00";
                            end if;
                            frameBufferLowNibble <= not frameBufferLowNibble;
                        end if;

                    else
                        sendDataIndex <= 0;
                        wordCounter <= 0;
                        counter <= counter + 1;
                        currentRowNumber_reg <= currentRowNumber_reg + 1;
                        state <= LOP;
                    end if;

                end if;

            when CHAR_WR =>
                
                if oled_request_reg = '0' then
                    oled_request_reg <= '1';        
                elsif oled_ready = '1' then
                    oled_request_reg <= '0';
                    if sendDataIndex = 0 then
                        cmd_controller <= '0' & x"2C";
                        sendDataIndex <= sendDataIndex + 1;
                        pixelCounter <= 0;

                    elsif pixelCounter < 127 then

                        if charPixelData(pixelCounter) = '1' then

                            if frameBufferLowNibble = '0' then
                                cmd_controller <= '1' & x"FF";
                                pixelCounter <= pixelCounter + 1;

                            else
                                cmd_controller <= '1' & x"FF";
                            end if;

                            frameBufferLowNibble <= not frameBufferLowNibble;
                        
                        elsif charPixelData(pixelCounter) = '0' then

                            if frameBufferLowNibble = '0' then
                                cmd_controller <= '1' & x"00";
                                pixelCounter <= pixelCounter + 1;

                            else
                                cmd_controller <= '1' & x"00";
                            end if;
                            frameBufferLowNibble <= not frameBufferLowNibble;
                        end if;

                    else
                        sendDataIndex <= 0;
                        state <= DONE;
                    end if;

                end if;

            when UNDERLINE =>
                
                if oled_request_reg = '0' then
                    oled_request_reg <= '1';        
                elsif oled_ready = '1' then
                    oled_request_reg <= '0';
                    if sendDataIndex = 0 then
                        cmd_controller <= '0' & x"2C";
                        sendDataIndex <= sendDataIndex + 1;
                        pixelCounter <= 0;

                    elsif pixelCounter < 8 then

                        if frameBufferLowNibble = '0' then
                            cmd_controller <= dynamic_data_array(8);
                            pixelCounter <= pixelCounter + 1;
                        else
                            cmd_controller <= dynamic_data_array(9);
                        end if;

                        frameBufferLowNibble <= not frameBufferLowNibble;

                    else
                        sendDataIndex <= 0;
                        dynamic_data_array(8) <= '1' & x"00";
                        dynamic_data_array(9) <= '1' & x"00";
                        state <= DONE;      -- state <= LOP also works, but just in case, put DONE for now
                    end if;

                end if;

            when DONE =>
                oled_request_reg <= '1';
                --exec_done <= '1';
                state     <= LOP;
                --counter <= counter + 1;

            when others =>
                null;
            end case;
        end if;
    end process;

end architecture;