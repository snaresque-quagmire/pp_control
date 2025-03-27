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
        key_code    : out std_logic_vector (4 downto 0);
        master_key  : out std_logic_vector (15 downto 0)
    );
end;

architecture rtl of keypad_scanner is
    constant IDLE       : std_logic_vector(2 downto 0)   := "000";
    constant BLANK      : std_logic_vector(2 downto 0)   := "001";
    constant DEBOUNCE   : std_logic_vector(2 downto 0)   := "010";
    constant SCAN0      : std_logic_vector(2 downto 0)   := "011";
    constant SCAN1      : std_logic_vector(2 downto 0)   := "100";
    constant SCAN2      : std_logic_vector(2 downto 0)   := "101";
    constant SCAN3      : std_logic_vector(2 downto 0)   := "111";
    signal state        : std_logic_vector(2 downto 0)   := IDLE;
    signal next_state   : std_logic_vector(2 downto 0)   := IDLE;
    signal scan_delay   : std_logic_vector(1 downto 0)  := (others => '0');

    signal slow_clk_enable  : std_logic                         := '0';
    signal Q0_col           : std_logic_vector(15 downto 0)     := (others => '0');
    signal Q1_col           : std_logic_vector(15 downto 0)     := (others => '0');
    signal Q2_col           : std_logic_vector(15 downto 0)     := (others => '0');
    signal Q2_bar_col       : std_logic_vector(15 downto 0)     := (others => '0');
    signal debounced_col    : std_logic_vector(15 downto 0)     := (others => '0');
    signal debounced_prev   : std_logic_vector(15 downto 0)     := (others => '0');

    signal col_reg          : std_logic_vector(15 downto 0)  := (others => '0');
    signal col_rdy          : std_logic_vector(15 downto 0)  := (others => '0');

    signal key_reg          : std_logic_vector(4 downto 0)  := "11111";

    constant row1 : std_logic_vector(3 downto 0) := "0001";
    constant row2 : std_logic_vector(3 downto 0) := "0010";
    constant row3 : std_logic_vector(3 downto 0) := "0100";
    constant row4 : std_logic_vector(3 downto 0) := "1000";
    
begin

    -- source: https://www.fpga4student.com/2017/08/vhdl-code-for-debouncing-buttons-on-fpga.html --

    clk_enable_generator : entity work.clk_enable_debounce
        port map(
            clk             => clk,
            slow_clk_enable => slow_clk_enable
        );

    debounce_ff0 : entity work.debounce_module
        port map(
            clk             => clk,
            clk_enable      => slow_clk_enable,
            D               => col_rdy,
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
            debounced_col   => debounced_col,
            decoded_btn     => key_reg
        );

    -- comparator with hysterisis
    -- debounced_col is updated every 250,000 ticks, equivalent to 2.5ms delay
    -- when debounced_col is updated, keypad_map converts it to corresponding output, return as key_reg
    Q2_bar_col <= not Q2_col;
    debounced_col <= Q1_col and Q2_bar_col;
    
    -- end of source -- 
    
    process(clk, reset)
    begin
        if reset = '1' then
            state        <= IDLE;
            key_code     <= "11111";
            row          <= "0000";
            col_reg      <= (others => '0');

        elsif rising_edge(clk) then
            
            case state is
                when IDLE =>
                    row             <= "0001";
                    scan_delay      <= "00";
                    col_reg         <= (others => '0');
                    state           <= SCAN0;

                when SCAN0 =>
                    row <= "0010";
                    col_reg(3 downto 0) <= col;
                    state <= BLANK;
                    next_state <= SCAN1;

                when SCAN1 =>
                    row <= "0100";
                    col_reg(7 downto 4) <= col;
                    state <= BLANK;
                    next_state <= SCAN2;

                when SCAN2 =>
                    row <= "1000";
                    col_reg(11 downto 8) <= col;
                    state <= BLANK;
                    next_state <= SCAN3;
                
                when SCAN3 =>
                    row <= "0001";
                    col_reg(15 downto 12) <= col;
                    state <= BLANK;
                    next_state <= DEBOUNCE;

                -- 10ns switching speed is too fast
                -- problem arise due to 10ns not sufficient for col input to discharge (pulled to gnd), before scanning next row
                --      causing next row to read the col from prev row
                -- testing shows that we need a minumum of 37ns delay between scans (27Mhz clock works)
                -- BLANK occurs after every SCAN, waiting 40ns ( "00" -> "01" -> "10" -> next state )
                when BLANK =>
                    if scan_delay = "10" then
                        state <= next_state;
                        if next_state = DEBOUNCE then
                            col_rdy <= col_reg;
                            state <= DEBOUNCE;
                        end if;
                        scan_delay <= "00";
                    elsif scan_delay = "00" then
                        scan_delay <= "01";
                    else
                        scan_delay <= "10";
                    end if;


                when DEBOUNCE =>
                    -- by having debounced_prev which stores the previous debounced_col value
                    -- button hold will only result in one input.
                    if debounced_prev = x"0000" then
                        key_code <= key_reg;
                    else
                        key_code <= "11111";
                    end if;
                    state <= SCAN0;
                    debounced_prev <= debounced_col;
                    -- master key is used to output to the 16-bit LED
                    master_key <= col_rdy;


                when others =>
                    state <= IDLE;
            end case;
        end if;
    end process;
end architecture;
