library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity adc is 
    generic(
        address         : std_logic_vector(6 downto 0)
    );
    port(
        clk             : in    std_logic;
        channel         : in    std_logic_vector(1 downto 0);
        outputData      : out   std_logic_vector(15 downto 0);
        dataReady       : out   std_logic;
        enable          : in    std_logic;
        instructionI2C  : out   std_logic_vector(1 downto 0);
        enableI2C       : out   std_logic;
        byteToSendI2C   : out   std_logic_vector(7 downto 0);
        byteReceivedI2C : in    std_logic_vector(7 downto 0);
        completeI2C     : in    std_logic
    );
end entity;


architecture rtl of adc is

    -- 1        start conversion
    -- 100      channel 0 single ended
    -- 001      FSR +- 4.096
    -- 1        single shot mode
    -- 100      128 SPS
    -- 0        Traditional Comparator
    -- 0        Active low alert
    -- 0        Non latching
    -- 11       Disable comparator

    signal  setupRegister           : std_logic_vector(15 downto 0) := "1100001110000011";
    constant CONFIG_REGISTER        : std_logic_vector(7 downto 0)  := "00000001";
    constant CONVERSION_REGISTER    : std_logic_vector(7 downto 0)  := "00000000";

    constant TASK_SETUP             : unsigned(1 downto 0)  := "00";
    constant TASK_CHECK_DONE        : unsigned(1 downto 0)  := "01";
    constant TASK_CHANGE_REG        : unsigned(1 downto 0)  := "10";
    constant TASK_READ_VALUE        : unsigned(1 downto 0)  := "11";

    constant INST_START_TX          : std_logic_vector(1 downto 0)  := "00";
    constant INST_STOP_TX           : std_logic_vector(1 downto 0)  := "01";
    constant INST_READ_BYTE         : std_logic_vector(1 downto 0)  := "10";
    constant INST_WRITE_BYTE        : std_logic_vector(1 downto 0)  := "11";
   
    constant STATE_IDLE             : std_logic_vector(2 downto 0)  := "000";
    constant STATE_RUN_TASK         : std_logic_vector(2 downto 0)  := "001";
    constant STATE_WAIT_FOR_I2C     : std_logic_vector(2 downto 0)  := "010";
    constant STATE_INC_SUB_TASK     : std_logic_vector(2 downto 0)  := "011";
    constant STATE_DONE             : std_logic_vector(2 downto 0)  := "100";
    constant STATE_DELAY            : std_logic_vector(2 downto 0)  := "101";

    signal taskIndex                : unsigned(1 downto 0)  := (others => '0');
    signal subTaskIndex             : unsigned(2 downto 0)  := (others => '0');
    signal state                    : std_logic_vector(2 downto 0)  := STATE_IDLE;
    signal counter                  : unsigned(7 downto 0)          := (others => '0');
    signal processStarted           : std_logic                     := '0';

    signal outputData_reg           : std_logic_vector(15 downto 0) := (others => '0');

begin

    outputData <= outputData_reg;

    process(clk)
    begin
        if rising_edge(clk) then
            case state is
            when STATE_IDLE =>
                if enable = '1' then
                    state           <= STATE_RUN_TASK;
                    taskIndex       <= (others => '0');
                    subTaskIndex    <= (others => '0');
                    dataReady       <= '0';
                    counter         <= (others => '0');
                end if;

            when STATE_RUN_TASK =>
                case (taskIndex & subTaskIndex) is
                when (TASK_SETUP & "000") | (TASK_CHECK_DONE & "001") | (TASK_CHANGE_REG & "001") | (TASK_READ_VALUE & "000")  =>
                    instructionI2C <= INST_START_TX;
                    enableI2C <= '1';
                    state <= STATE_WAIT_FOR_I2C;

                when (TASK_SETUP & "001") | (TASK_CHECK_DONE & "010") | (TASK_CHANGE_REG & "010") | (TASK_READ_VALUE & "001")  =>
                    instructionI2C <= INST_WRITE_BYTE;
                    if((taskIndex = TASK_CHECK_DONE) or (taskIndex = TASK_READ_VALUE)) then
                        byteToSendI2C <= address & '1';
                    else
                        byteToSendI2C <= address & '0';
                    end if;
                    enableI2C <= '1';
                    state <= STATE_WAIT_FOR_I2C;

                when (TASK_SETUP & "101") | (TASK_CHECK_DONE & "101") | (TASK_CHANGE_REG & "100") | (TASK_READ_VALUE & "101")  =>
                    instructionI2C <= INST_STOP_TX;
                    enableI2C <= '1';
                    state <= STATE_WAIT_FOR_I2C;


                when (TASK_SETUP & "010") | (TASK_CHANGE_REG & "011") =>
                    instructionI2C <= INST_WRITE_BYTE;
                    if(taskIndex = TASK_SETUP) then
                        byteToSendI2C <= CONFIG_REGISTER;
                    else
                        byteToSendI2C <= CONVERSION_REGISTER;
                    end if;
                    enableI2C <= '1';
                    state <= STATE_WAIT_FOR_I2C;

                when (TASK_SETUP & "011") =>
                    instructionI2C <= INST_WRITE_BYTE;
                    byteToSendI2C <= setupRegister(15) & "1" & channel & setupRegister(11 downto 8);
                    enableI2C <= '1';
                    state <= STATE_WAIT_FOR_I2C;

                when (TASK_SETUP & "100") =>
                    instructionI2C <= INST_WRITE_BYTE;
                    byteToSendI2C <= setupRegister(7 downto 0);
                    enableI2C <= '1';
                    state <= STATE_WAIT_FOR_I2C;

                when (TASK_CHECK_DONE & "000") =>
                    state <= STATE_DELAY;
  
                when (TASK_CHECK_DONE & "011") | (TASK_READ_VALUE & "010") =>
                    instructionI2C <= INST_READ_BYTE;
                    enableI2C <= '1';
                    state <= STATE_WAIT_FOR_I2C;

                when (TASK_CHECK_DONE & "100") | (TASK_READ_VALUE & "011") =>
                    instructionI2C <= INST_READ_BYTE;
                    outputData_reg(15 downto 8) <= byteReceivedI2C;
                    enableI2C <= '1';
                    state <= STATE_WAIT_FOR_I2C;

                when (TASK_CHANGE_REG & "000") =>
                    if(outputData_reg(15) = '1') then
                        state <= STATE_INC_SUB_TASK;
                    else
                        subTaskIndex <= (others => '0');
                        taskIndex   <= TASK_CHECK_DONE;
                    end if;

                when (TASK_READ_VALUE & "100") =>
                    state <= STATE_INC_SUB_TASK;
                    outputData_reg(7 downto 0) <= byteReceivedI2C;

                when others => 
                    state <= STATE_INC_SUB_TASK;
                end case;

            when STATE_WAIT_FOR_I2C =>
                if( processStarted = '0' and completeI2C = '0') then
                    processStarted <= '1';
                elsif (completeI2C = '1' and processStarted = '1') then
                    state <= STATE_INC_SUB_TASK;
                    processStarted <= '0';
                    enableI2C <= '0';
                end if;

            when STATE_INC_SUB_TASK =>
                state <= STATE_RUN_TASK;
                if(subTaskIndex = "101") then
                    subTaskIndex <= "000";
                    if(taskIndex = TASK_READ_VALUE) then
                        state <= STATE_DONE;
                    else
                        taskIndex <= taskIndex + 1;
                    end if;
                else
                    subTaskIndex <= subTaskIndex + 1;
                end if;

            when STATE_DELAY =>
                counter <= counter + 1;
                if (counter = "11111111") then
                    state <= STATE_INC_SUB_TASK;
                    counter <= (others => '0');
                end if;

            when STATE_DONE =>
                dataReady <= '1';
                if (enable = '0') then
                    state <= STATE_IDLE;
                end if;

            when others =>
                null;
            end case;
        end if;

    end process;


end architecture;