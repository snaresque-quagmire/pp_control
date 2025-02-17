library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tft_ili9341_spi is
    port(
        spiClk          : in    std_logic;
        data            : in    std_logic_vector(8 downto 0);
        dataAvailable   : in    std_logic;
        tft_sck         : out   std_logic;
        tft_sdi         : out   std_logic;
        tft_dc          : out   std_logic;
        tft_cs          : out   std_logic;
        idle            : out   std_logic
    );
end entity;

architecture rtl of tft_ili9341_spi is

    signal counter       : integer range 0 to 7         := 0;               
    signal internalData  : std_logic_vector(8 downto 0) := (others => '0'); 
    signal internalSck   : std_logic                    := '1';             
    signal cs            : std_logic                    := '0';             
    signal idle_flag     : std_logic                    := '1';
                 
    --signal dataDc        : std_logic;                                       
    signal dataShift     : std_logic_vector(7 downto 0); 
    signal tft_sck_reg   : std_logic                    := '1';

begin

    tft_sck <= internalSck and cs;             
    tft_cs  <= not cs;                       
    idle    <= idle_flag;  

    process(spiClk)
    begin
        if rising_edge(spiClk) then
            if dataAvailable = '1' then
                internalData <= data;
                idle_flag <= '0';
            end if;
            if idle_flag = '0' then
                internalSck <= not internalSck;

                if internalSck = '1' then
                    tft_dc  <= internalData(8);
                    dataShift(counter) <= internalData(7 - counter);
                    tft_sdi <= internalData(7 - counter);
                    cs <= '1';

                    if counter = 7 then
                        counter <= 0;
                        idle_flag <= '1';
                    else
                        counter <= counter + 1;
                    end if;
                end if;
            else
                internalSck <= '1';
                if internalSck = '1' then
                    cs <= '0';
                end if;
            end if;
        end if;
    end process;
end architecture;