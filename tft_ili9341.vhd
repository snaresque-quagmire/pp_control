library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tft_ili9341 is
    generic(
        INPUT_CLK_MHZ      :   integer := 27
    );
    port(

        --frameBufferData   : in    std_logic_vector(15 downto 0);
        --frameBufferClk    : out   std_logic;
        clk                 : in    std_logic;
        tft_sck             : out   std_logic;
        tft_sdi             : out   std_logic;
        tft_dc              : out   std_logic;
        tft_reset           : out   std_logic := '1';
        tft_cs              : out   std_logic;

        cmd_controller      : in    std_logic_vector(8 downto 0);
        oled_ready          : out   std_logic;
        oled_request        : in    std_logic;
        exec_done           : in    std_logic
    );
end entity;

architecture rtl of tft_ili9341 is
    signal spiData              :   std_logic_vector(8 downto 0)    := (others => '0');
    signal spiDataSet           :   std_logic                       := '0';
    signal spiIdle              :   std_logic                       := '1';
    signal frameBufferLowNibble :   std_logic                       := '1';
    signal remainingDelayTicks  :   integer                         := 0;

    constant START              : std_logic_vector(3 downto 0) := "0000";
    constant HOLD_RESET         : std_logic_vector(3 downto 0) := "0001";
    constant WAIT_FOR_POWERUP   : std_logic_vector(3 downto 0) := "0010";
    constant SEND_INIT_SEQ      : std_logic_vector(3 downto 0) := "0011";
    constant LOP                : std_logic_vector(3 downto 0) := "0100";
    CONSTANT EXEC_CASET         : std_logic_vector(3 downto 0) := "0101";
    CONSTANT EXEC_PASET         : std_logic_vector(3 downto 0) := "0110";
    CONSTANT EXEC_RAMWR         : std_logic_vector(3 downto 0) := "0111";
    signal state                : std_logic_vector(3 downto 0) := START;
    
    signal counter              : integer                           := 0;


    signal initSeqCounter       : integer range 0 to 63             := 0;
    type init_seq_array is array(0 to (54 - 1) ) of std_logic_vector(8 downto 0);
    constant INIT_SEQ : init_seq_array := (
        -- Initialization Commands
        '0' & x"28",

        '0' & x"CF", -- Power Control B
        '1' & x"00", 
        '1' & x"83", -- x83, xC1
        '1' & x"30",

        '0' & x"ED", -- Power on sequence control 
        '1' & x"64",
        '1' & x"03",
        '1' & x"12",
        '1' & x"81",

        '0' & x"E8", -- Driver timing control A
        '1' & x"85", -- x01, x85
        '1' & x"01", 
        '1' & x"79",

        '0' & x"CB", -- Power control A
        '1' & x"39",
        '1' & x"2C",
        '1' & x"00",
        '1' & x"34",
        '1' & x"02",

        '0' & x"F7", -- Pump ratio control
        '1' & x"20",

        '0' & x"EA", -- Driver timing control B
        '1' & x"00",
        '1' & x"00",

        '0' & x"C0", -- Power Control 1
        '1' & x"28", -- x26, x10  100110  010000

        '0' & x"C1", -- Power Control 2
        '1' & x"11", -- x11, x00

        '0' & x"C5", -- VCOM control 1
        '1' & x"35", -- x35, x30
        '1' & x"3E", -- x3E, x30

        '0' & x"C7", -- VCOM control 2
        '1' & x"BE", -- xBE, xB7

        '0' & x"3A", -- Pixel Format Set
        '1' & x"55",

        '0' & x"36", -- RBG
        '1' & x"88",

        '0' & x"B1", -- Frame Control
        '1' & x"00", 
        '1' & x"1B", -- x1B, x1A

        '0' & x"B6", -- Display Function Control
        '1' & x"0A", -- x0A, x08
        '1' & x"82",
        '1' & x"27",
        '1' & x"00", -- x00

        '0' & x"26", -- Gamma Set
        '1' & x"01",

        '0' & x"51", -- Write Display brightness
        '1' & x"FF",

        '0' & x"B7", -- Entry Mode Set
        '1' & x"07",

        '0' & x"29", -- Display On

        '0' & x"2C" -- Memory Write
    );


begin

    --frameBufferClk <= not frameBufferLowNibble;

    spi_inst: entity work.tft_ili9341_spi
        port map(
            spiClk          => clk,
            data            => spiData,
            dataAvailable   => spiDataSet,
            tft_sck         => tft_sck,
            tft_sdi         => tft_sdi,
            tft_dc          => tft_dc,
            tft_cs          => tft_cs,
            idle            => spiIdle
        );
    
    process(clk)
    begin
        if rising_edge(clk) then
            spiDataSet <= '0';

            if remainingDelayTicks > 0 then
                remainingDelayTicks <= remainingDelayTicks - 1;
                
            else if (spiIdle = '1' and spiDataSet = '0') then
                case state is
                    when START =>
                        tft_reset <= '0';
                        remainingDelayTicks <= INPUT_CLK_MHZ * 10;
                        state <= HOLD_RESET;
            
                    when HOLD_RESET => 
                        tft_reset <= '1';
                        remainingDelayTicks <= INPUT_CLK_MHZ * 120000;
                        state <= WAIT_FOR_POWERUP;
                        frameBufferLowNibble <= '0';
                    
                    when WAIT_FOR_POWERUP =>
                        spiData     <= '0' & x"11";
                        spiDataSet  <= '1';
                        remainingDelayTicks <= INPUT_CLK_MHZ * 5000;
                        state <= SEND_INIT_SEQ;
                        frameBufferLowNibble <= '1';
                    
                    when SEND_INIT_SEQ =>
                        if initSeqCounter < 54 then
                            spiData <= INIT_SEQ(initSeqCounter);
                            initSeqCounter <= initSeqCounter + 1;
                            spiDataSet <= '1';
                        elsif initSeqCounter = 54 then
                            if counter < 76800 then
                                if frameBufferLowNibble = '0' then
                                    spiData <= '1' & x"00";
                                    counter <= counter + 1;
                                else
                                    spiData <= '1' & x"00";
                                end if;
                                spiDataSet <= '1';
                                frameBufferLowNibble <= not frameBufferLowNibble;
                            else
                                initSeqCounter <= initSeqCounter + 1;
                            end if;
                        else
                            state <= LOP;
                            remainingDelayTicks <= INPUT_CLK_MHZ * 10_000;
                            initSeqCounter <= 0;
                            counter <= 0;
                        end if;                  

                    when LOP =>

                        if exec_done = '1' then
                            null;

                        elsif oled_request = '1' then
                            oled_ready <= '1';
                        
                        elsif oled_request = '0' then
                            oled_ready <= '0';
                            spiData <= cmd_controller;
                            spiDataSet <= '1';
                        else
                            null;

                        end if;

                    when others =>
                        null;

                end case;
        
            end if;
            end if;
        end if;
    end process;

end architecture;