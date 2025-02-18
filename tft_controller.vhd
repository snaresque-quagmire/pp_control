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
    constant IDLE               : std_logic_vector(3 downto 0) := "0000";
    constant WAIT_FOR_READY     : std_logic_vector(3 downto 0) := "0001";
    constant EXECUTE            : std_logic_vector(3 downto 0) := "0010";
    constant DONE               : std_logic_vector(3 downto 0) := "0011";
    constant LOP                : std_logic_vector(3 downto 0) := "0100";
    constant EXEC_CASET         : std_logic_vector(3 downto 0) := "0101";
    constant EXEC_PASET         : std_logic_vector(3 downto 0) := "0110";
    constant EXEC_RAMWR         : std_logic_vector(3 downto 0) := "0111";
    constant UNDERLINE              : std_logic_vector(3 downto 0) := "1000";
    signal state                : std_logic_vector(3 downto 0) := IDLE;
    signal state_register       : std_logic_vector(3 downto 0) := IDLE;
  


    -- counter
    constant ROW1               : integer                       := 0;
    constant ROW14              : integer                       := 13;
    constant LAST_ROW           : integer                       := 14;
    constant HACK_TO_FIX        : integer                       := 15;
    constant WAIT_FOR_KEYPAD    : integer                       := 16;
    constant WRITE_MODE         : integer                       := 17;

    -- drawing states
    constant DRAW_STATE1        : integer                       := 18;
    constant DRAW_STATE2        : integer                       := 19;
    constant DRAW_STATE3        : integer                       := 20;

    -- key_code
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
    signal underline_integer    : integer range 0 to 15             := 0;

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

                underline_pos_row(0) <= '1' & std_logic_vector(to_unsigned(209,8));
                underline_pos_row(1) <= '1' & std_logic_vector(to_unsigned(216,8));
                underline_pos_row(2) <= '1' & std_logic_vector(to_unsigned(223,8));
                underline_pos_row(3) <= '1' & std_logic_vector(to_unsigned(230,8));
                underline_pos_row(4) <= '1' & std_logic_vector(to_unsigned(225,8));
                underline_pos_row(5) <= '1' & std_logic_vector(to_unsigned(232,8));
                underline_pos_row(6) <= '1' & std_logic_vector(to_unsigned(233,8));
                underline_pos_row(7) <= '1' & std_logic_vector(to_unsigned(240,8));

                underline_pos_col(0) <= '1' & std_logic_vector(to_unsigned(80,8));
                underline_pos_col(1) <= '1' & std_logic_vector(to_unsigned(96,8));
                underline_pos_col(2) <= '1' & std_logic_vector(to_unsigned(112,8));
                underline_pos_col(3) <= '1' & std_logic_vector(to_unsigned(128,8));
                underline_pos_col(4) <= '1' & std_logic_vector(to_unsigned(0,8));
                underline_pos_col(5) <= '1' & std_logic_vector(to_unsigned(0,8));
                underline_pos_col(6) <= '1' & std_logic_vector(to_unsigned(0,8));
                underline_pos_col(7) <= '1' & std_logic_vector(to_unsigned(0,8));

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
                    state <= DONE; -- This is hack, to be fixed. Problem because apparently need to oled_request_reg <= '1';

                when WAIT_FOR_KEYPAD =>
                    if keyin = ENTER then
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
                        underline_integer <= 0;
                        counter <= WRITE_MODE;
                    end if;

                when WRITE_MODE =>
                    if keyin = ENTER then
                        counter <= DRAW_STATE1;
                    end if;

                when DRAW_STATE1 =>
                    dynamic_data_array(0) <= '1' & x"00";
                    dynamic_data_array(1) <= underline_pos_col(0);
                    dynamic_data_array(2) <= '1' & x"00";
                    dynamic_data_array(3) <= underline_pos_col(0);
                    dynamic_data_array(4) <= '1' & x"00";
                    dynamic_data_array(5) <= underline_pos_row(0);
                    dynamic_data_array(6) <= '1' & x"00";
                    dynamic_data_array(7) <= underline_pos_row(1);
                    dynamic_data_array(8) <= '1' & x"00";
                    dynamic_data_array(9) <= '1' & x"00";
                    state <= EXEC_CASET;
                    state_register <= UNDERLINE;
                    --if underline_integer = 12 then
                        --counter <= WAIT_FOR_KEYPAD;
                    --    underline_integer <= 0;
                    --else
                        counter <= DRAW_STATE2;
                    --end if;

                when DRAW_STATE2 =>
                    dynamic_data_array(0) <= '1' & x"00";
                    dynamic_data_array(1) <= underline_pos_col(0);
                    dynamic_data_array(2) <= '1' & x"00";
                    dynamic_data_array(3) <= underline_pos_col(0);
                    dynamic_data_array(4) <= '1' & x"00";
                    dynamic_data_array(5) <= underline_pos_row(2);
                    dynamic_data_array(6) <= '1' & x"00";
                    dynamic_data_array(7) <= underline_pos_row(3);
                    dynamic_data_array(8) <= '1' & x"FF";
                    dynamic_data_array(9) <= '1' & x"FF";
                    state <= EXEC_CASET;
                    state_register <= UNDERLINE;
                    --underline_integer <= underline_integer + 1;
                    --if underline_integer = 11 then
                    --    counter <= DRAW_STATE1;
                    --else
                        counter <= WRITE_MODE;
                    --end if;

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

            when UNDERLINE =>
                
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

                    elsif pixelCounter < 8 then

                        if frameBufferLowNibble = '0' then
                            cmd_controller <= dynamic_data_array(8);
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
                            cmd_controller <= dynamic_data_array(9);
                        end if;

                        frameBufferLowNibble <= not frameBufferLowNibble;

                    else
                        sendDataIndex <= 0;
                        wordCounter <= 0;
                        --counter <= counter + 1;
                        --currentRowNumber_reg <= currentRowNumber_reg + 1;
                        dynamic_data_array(8) <= '1' & x"00";
                        dynamic_data_array(9) <= '1' & x"00";
                        state <= LOP;
                    end if;

                end if;

            when DONE =>
                oled_request_reg <= '1';
                --exec_done <= '1';
                state     <= LOP;
                counter <= counter + 1;

            when others =>
                null;
            end case;
        end if;
    end process;

end architecture;