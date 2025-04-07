library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity i2c is 
    port(
        clk             : in    std_logic;
        sdaIn           : in    std_logic;
        sdaOut          : out   std_logic;
        isSending       : out   std_logic;
        scl             : out   std_logic;
        instruction     : in    std_logic_vector(1 downto 0);
        enable          : in    std_logic;
        byteToSend      : in    std_logic_vector(7 downto 0);
        byteReceived    : out   std_logic_vector(7 downto 0);
        complete        : out   std_logic
    );
end entity;


architecture rtl of i2c is

    constant INST_START_TX  : std_logic_vector(2 downto 0)      := "000";
    constant INST_STOP_TX   : std_logic_vector(2 downto 0)      := "001";
    constant INST_READ_BYTE : std_logic_vector(2 downto 0)      := "010";
    constant INST_WRITE_BYTE: std_logic_vector(2 downto 0)      := "011";
    constant STATE_IDLE     : std_logic_vector(2 downto 0)      := "100";
    constant STATE_DONE     : std_logic_vector(2 downto 0)      := "101";
    constant STATE_SEND_ACK : std_logic_vector(2 downto 0)      := "110";
    constant STATE_RCV_ACK  : std_logic_vector(2 downto 0)      := "111";
    signal state            : std_logic_vector(2 downto 0)      := STATE_IDLE;

    signal byteReceived_reg : std_logic_vector(7 downto 0)      := (others => '0');

    signal clockDivider     : unsigned(6 downto 0)              := (others => '0');
    signal bitToSend        : unsigned(2 downto 0)              := (others => '0');
    
begin

    byteReceived <= byteReceived_reg;

    process(clk)
    begin
        if rising_edge(clk) then
            case state is
            when STATE_IDLE =>
                if enable = '1' then
                    complete        <= '0';
                    clockDivider    <= (others => '0');
                    bitToSend       <= (others => '0');
                    state           <= "0" & instruction;
                end if;

            when INST_START_TX =>
                isSending <= '1';
                if clockDivider = "1111111" then
                    clockDivider <= (others => '0');
                else
                    clockDivider <= clockDivider + 1;
                end if;

                if(clockDivider(6 downto 5) = "00") then
                    scl <= '1';
                    sdaOut  <= '1';
                elsif(clockDivider(6 downto 5) = "01") then
                    sdaOut <= '0';
                elsif(clockDivider(6 downto 5) = "10") then
                    scl <= '0';

                elsif(clockDivider(6 downto 5) = "11") then
                    state <= STATE_DONE;
                end if;
    
            when INST_STOP_TX =>
                isSending <= '1';
                if clockDivider = "1111111" then
                    clockDivider <= (others => '0');
                else
                    clockDivider <= clockDivider + 1;
                end if;

                if(clockDivider(6 downto 5) = "00") then
                    scl     <= '0';
                    sdaOut  <= '0';
                elsif(clockDivider(6 downto 5) = "01") then
                    scl <= '1';
                elsif(clockDivider(6 downto 5) = "10") then
                    sdaOut <= '1';
                elsif(clockDivider(6 downto 5) = "11") then
                    state <= STATE_DONE;
                end if;

            when INST_READ_BYTE =>
                isSending <= '0';
                if clockDivider = "1111111" then
                    clockDivider <= (others => '0');
                else
                    clockDivider <= clockDivider + 1;
                end if;

                if(clockDivider(6 downto 5) = "00") then
                    scl     <= '0';
                elsif(clockDivider(6 downto 5) = "01") then
                    scl <= '1';
                elsif(clockDivider = "1000000") then
                    byteReceived_reg <= byteReceived_reg(6 downto 0) & sdaIn;
                elsif(clockDivider = "1111111") then
                    bitToSend <= bitToSend + 1;
                    if bitToSend = "111" then
                        state <= STATE_SEND_ACK;
                    end if;
                elsif(clockDivider(6 downto 5) = "11") then
                    scl     <= '0';
                end if;

            when STATE_SEND_ACK =>
                isSending   <= '1';
                sdaOut      <= '0';
                if clockDivider = "1111111" then
                    clockDivider <= (others => '0');
                else
                    clockDivider <= clockDivider + 1;
                end if;

                if(clockDivider(6 downto 5) = "01") then
                    scl     <= '1';
                elsif(clockDivider = "1111111") then
                    state <= STATE_DONE;
                elsif(clockDivider(6 downto 5) = "11") then
                    scl     <= '0';
                end if;

            when INST_WRITE_BYTE =>
                isSending <= '1';
                if clockDivider = "1111111" then
                    clockDivider <= (others => '0');
                else
                    clockDivider <= clockDivider + 1;
                end if;
                
                sdaOut <= byteToSend(7 - to_integer(bitToSend)); 
    

                if(clockDivider(6 downto 5) = "00") then
                    scl     <= '0';
                elsif(clockDivider(6 downto 5) = "01") then
                    scl <= '1';
                elsif(clockDivider = "1111111") then
                    bitToSend <= bitToSend + 1;
                    if bitToSend = "111" then
                        state <= STATE_RCV_ACK;
                    end if;
                elsif(clockDivider(6 downto 5) = "11") then
                    scl     <= '0';
                end if;

            when STATE_RCV_ACK =>
                isSending <= '0';
                if clockDivider = "1111111" then
                    clockDivider <= (others => '0');
                else
                    clockDivider <= clockDivider + 1;
                end if;

                if(clockDivider(6 downto 5) = "01") then
                    scl <= '1';
                elsif (clockDivider = "1111111") then
                    state <= STATE_DONE;
                elsif(clockDivider(6 downto 5) = "11") then
                    scl <= '0';
                end if;

            when STATE_DONE =>
                complete <= '1';
                if(enable = '0') then
                    state <= STATE_IDLE;
                end if;

            end case;
        end if;

    end process;


end architecture;