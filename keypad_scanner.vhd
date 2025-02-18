library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- scanner will check for button input
-- button input will be sent to keypad_map, return key_code

entity keypad_scanner is
    Port (
        clk         : in  std_logic;
        reset       : in  std_logic;
        row         : out std_logic_vector (3 downto 0);
        col         : in  std_logic_vector (3 downto 0);
        key_code    : out std_logic_vector (4 downto 0)
    );
end;

architecture rtl of keypad_scanner is
    constant IDLE      : std_logic_vector(2 downto 0)   := "000";
    constant SCAN      : std_logic_vector(2 downto 0)   := "001";
    constant DEBOUNCE  : std_logic_vector(2 downto 0)   := "010";
    constant CALC      : std_logic_vector(2 downto 0)   := "011";
    constant CALC2     : std_logic_vector(2 downto 0)   := "100";
    signal state       : std_logic_vector(2 downto 0)   := IDLE;
    signal row_index   : integer range 0 to 3           := 0;

    signal slow_clk_enable      : std_logic                 := '0';
    signal Q0_col           : std_logic_vector(3 downto 0);
    signal Q1_col           : std_logic_vector(3 downto 0);
    signal Q2_col           : std_logic_vector(3 downto 0);
    signal Q2_bar_col       : std_logic_vector(3 downto 0);
    signal debounced_col    : std_logic_vector(3 downto 0);

    signal col_reg          : std_logic_vector(3 downto 0)  := (others => '0');
    signal btn_out          : std_logic_vector(3 downto 0)  := (others => '0');
    signal btn_out_prev     : std_logic_vector(3 downto 0)  := (others => '0');

    signal key_reg          : std_logic_vector(4 downto 0)  := "11111";
    signal key_pressed      : std_logic                     := '0';     -- does nothing, but i leave it here for future use.

    constant row1 : std_logic_vector(3 downto 0) := "0001";
    constant row2 : std_logic_vector(3 downto 0) := "0010";
    constant row3 : std_logic_vector(3 downto 0) := "0100";
    constant row4 : std_logic_vector(3 downto 0) := "1000";
    
    type row_pattern_array is array (0 to 3) of std_logic_vector(3 downto 0);
    constant row_pattern : row_pattern_array := (
        0 => "0001",
        1 => "0010",
        2 => "0100",
        3 => "1000"
    );

begin

    clk_enable_generator : entity work.clk_enable_debounce
        port map(
            clk             => clk,
            slow_clk_enable => slow_clk_enable
        );

    debounce_ff0 : entity work.debounce_module
        port map(
            clk             => clk,
            clk_enable      => slow_clk_enable,
            D               => col,
            Q               => Q0_col
        );

    debounce_ff1 : entity work.debounce_module
        port map(
            clk             => clk,
            clk_enable      => slow_clk_enable,
            D               => Q0_col,
            Q               => Q1_col
        );

    debounce_ff2 : entity work.debounce_module
        port map(
            clk             => clk,
            clk_enable      => slow_clk_enable,
            D               => Q1_col,
            Q               => Q2_col
        );

    key_mapping : entity work.keypad_map
        port map(
            row_index       => row_index,
            debounced_col   => btn_out,
            decoded_btn     => key_reg
        );

    Q2_bar_col <= not Q2_col;
    debounced_col <= Q1_col and Q2_bar_col;

    process(clk, reset)
    begin
        if reset = '0' then
            state        <= IDLE;
            row_index    <= 0;
            key_code     <= "11111";
            row          <= row_pattern(0);
            key_pressed  <= '0';
            col_reg      <= (others => '0');
            btn_out      <= (others => '0');

        elsif rising_edge(clk) then

            btn_out_prev <= btn_out;

            case state is

                when IDLE =>
                    row             <= row_pattern(0);
                    row_index       <= 0;
                    col_reg         <= (others => '0');
                    key_pressed     <= '0';
                    btn_out         <= (others => '0');
                    state           <= SCAN;

                when SCAN =>

                    if col /= "0000" then
                        col_reg <= col;
                        state <= CALC;
                    elsif row_index = 3 then
                        row_index <= 0;
                        row <= row_pattern(0);
                    else
                        row_index <= row_index + 1;
                        row <= row_pattern(row_index + 1);
                    end if;

                when CALC =>
                    state <= CALC2;

                when CALC2 =>
                    btn_out <= debounced_col;
                    state <= DEBOUNCE;

                when DEBOUNCE =>

                    if btn_out /= "0000" and btn_out_prev = "0000" then
                        key_code <= key_reg;
                        key_pressed <= '1';
                    else
                        key_code <= "11111";
                        key_pressed <= '0';
                    end if;
                    state <= SCAN;

                when others =>
                    state <= IDLE;
            end case;
        end if;
    end process;
end architecture;
