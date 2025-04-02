library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pp_gen is

    port(
        clk                 : in    std_logic;
        clk_10mhz           : in    std_logic;
        operation_input     : in    std_logic;
        operation_feedback  : out   std_logic;
        a4_vtrig            : out   std_logic;
        --a5_vchg             : out   std_logic;
        logic_shift_en      : out   std_logic;
        master_key_0        : out   std_logic;
        freq_buffer         : in    integer range 0 to 9999;
        delay_timer_buffer  : in    integer range 0 to 9999;
        pulse_num_buffer    : in    integer range 0 to 9999
    );

end entity;

architecture rtl of pp_gen is

    constant IDLE           : std_logic_vector(1 downto 0)  := "00";
    constant FIRE           : std_logic_vector(1 downto 0)  := "01";
    constant FINISH         : std_logic_vector(1 downto 0)  := "10";
    constant ABORT          : std_logic_vector(1 downto 0)  := "11";
    signal state            : std_logic_vector(1 downto 0)  := IDLE;
    signal div1             : std_logic                     := '0';
    signal pulse_num_count  : integer range 0 to 9999       := 0;
    signal pulse_reg        : std_logic                     := '0';
    signal addr_freq_buffer : std_logic_vector(13 downto 0) := (others => '0');
    signal hex_dout         : std_logic_vector(19 downto 0) := x"3D08F";

    COMPONENT bram_div
      PORT (
        clka : IN STD_LOGIC;
        addra : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
        douta : OUT STD_LOGIC_VECTOR(19 DOWNTO 0) 
      );
    END COMPONENT;


begin
      
    div_lut : bram_div
      PORT MAP (
        clka => clk,
        addra => addr_freq_buffer,
        douta => hex_dout
      );

    clk_div_1 : entity work.clk_enable_debounce
        port map(
            clk => clk_10mhz,
            slow_clk_enable => div1,
            delay_time => hex_dout
        );

    process(clk)
    begin
    
        if rising_edge(clk) then
                        
            case state is
            when IDLE =>
                if operation_input = '1' then
                    if freq_buffer > 0 and pulse_num_buffer > 0 then
                        logic_shift_en      <= '1';
                        operation_feedback  <= '1';
                        addr_freq_buffer    <= std_logic_vector(to_unsigned((freq_buffer-1),14));
                        pulse_num_count     <= 0;
                        state               <= FIRE;
                    end if;
                end if;
                
            when FIRE =>

                a4_vtrig                    <= div1;
                pulse_reg                   <= div1;
                master_key_0                <= '1';
                
--                if div1 = '0' and pulse_reg = '1' then
--                    pulse_num_count         <= pulse_num_count + 1;
--                end if;
                
                if operation_input = '0' then
                    logic_shift_en          <= '0';
                    operation_feedback      <= '0';
                    a4_vtrig                <= '0';
                    master_key_0            <= '0';
                    state                   <= FINISH;
                end if;
                
            when FINISH =>
                state <= IDLE;
             
            when ABORT =>
                
             end case;
        end if;
        
    end process;
    
end architecture;