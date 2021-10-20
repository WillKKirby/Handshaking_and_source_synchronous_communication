library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.DigEng.all;

-- This is where your work goes. Of course, you will have to put
--   your own comments in, to describe your work.

entity STUDENT_AREA is
  Generic (disp_delay : natural := 62500000);
  Port ( 
    CLK : in  STD_LOGIC;
    RST : in  STD_LOGIC;
    USER_PB : in  STD_LOGIC_VECTOR (3 downto 0);
    SWITCHES : in  STD_LOGIC_VECTOR (7 downto 0);
    LEDS : out  STD_LOGIC_VECTOR (3 downto 0);
    DATA_FROM_SPI : in  STD_LOGIC_VECTOR (7 downto 0);
    DATA_TO_SPI : out  STD_LOGIC_VECTOR (7 downto 0);
    EN_SPI : out  STD_LOGIC;
    SPI_WR_REQ : out STD_LOGIC;
    SPI_WR_ACK : in STD_LOGIC;
    SPI_RD_REQ : out STD_LOGIC;
    SPI_RD_ACK : in STD_LOGIC;
    SRAM_ADDRESS : in STD_LOGIC_VECTOR(23 downto 0)
  );
end STUDENT_AREA;

architecture Behavioral of STUDENT_AREA is

-- Max counter limit for the up/down counter 
constant input_counter_limit : integer := 15;

-- Button Assignment -- 
-- Button 0 already assigned to reset. 
-- Button 1 - Write Mode, Button 2 - Enter Switch Value
-- Button 3 - Enter Read Mode.
signal Write, Enter_Val, Read : std_logic;

-- States for the FSM -- 
type fsm_states is (idle, instr_S1, instr_S2, Address1_S1, Address1_S2, Address2_S1, Address2_S2, Address3_S1, Address3_S2, prime, increment_state, switch_S1, switch_S2, 
    wait_read, instr2_S1, instr2_S2, Address2_1_S1, Address2_1_S2, Address2_2_S1, Address2_2_S2, Address2_3_S1, Address2_3_S2, output, wait_state_1, wait_state_2,
    read_s1, read_s2 );
signal state, next_state : fsm_states;

-- Counter Signals -- 
signal input_count_val : unsigned(3 downto 0);
signal input_count_en, input_count_rst, input_count_dir : std_logic;
signal disp_count_val : unsigned(log2(disp_delay)-1 downto 0);
signal disp_count_en, disp_count_rst : std_logic;

begin 

---------
-- FSM -- 
---------
-- Process for changing the states on the clock edges
-- State change process
fsm_state_change : process (CLK) is
begin
    if rising_edge(CLK) then
        if RST = '1' then
            state <= idle;
        else 
            state <= next_state;
        end if;
    end if;
end process fsm_state_change;

-- FSM State Conditions -- 
FSM : process (state, Write, Enter_Val, Read, SPI_WR_ACK, SPI_RD_ACK, input_count_val, disp_count_val) is
begin
    case state is
    
        -- Inital Idle State -- 
        
        when idle => 
            if (Write = '1') then 
                next_state <= instr_S1;
            else 
                next_state <= state;
            end if;
        
        -- Start of write transaction -- 
        
        -- Sending the instruction to write -- 
        
        when instr_S1 => 
            if (SPI_WR_ACK = '1') then
                next_state <= instr_S2;
            else 
                next_state <= state;
            end if;
            
        when instr_S2 =>
            if (SPI_WR_ACK = '0') then
                next_state <= Address1_S1;
            else 
                next_state <= state;
            end if;
        
        -- Sending the Address to write too --   
          
        -- Byte 1 -- 
        
        when Address1_S1 => 
            if (SPI_WR_ACK = '1') then
                next_state <= Address1_S2;
            else 
                next_state <= state;
            end if;
        when Address1_S2 =>
            if (SPI_WR_ACK = '0') then
                next_state <= Address2_S1;
            else 
                next_state <= state;
            end if;
            
        -- Byte 2 --
        
        when Address2_S1 => 
            if (SPI_WR_ACK = '1') then
                next_state <= Address2_S2;
            else 
                next_state <= state;
            end if;
        when Address2_S2 =>
            if (SPI_WR_ACK = '0') then
                next_state <= Address3_S1;
            else 
                next_state <= state;
            end if;
            
        -- Byte 3 --
        
        when Address3_S1 => 
            if (SPI_WR_ACK = '1') then
                next_state <= Address3_S2;
            else 
                next_state <= state;
            end if;
        when Address3_S2 =>
            if (SPI_WR_ACK = '0') then
                next_state <= prime;
            else 
                next_state <= state;
            end if;
            
        -- Now waiting for the inputs or to begin the output -- 
        
        when prime =>
            if (Enter_Val = '1' and input_count_val <= input_counter_limit) then 
                next_state <= increment_state;
            elsif (Write = '1') then 
                next_state <= wait_read;
            else 
                next_state <= state;
            end if;
            
        -- States for inputting the switch data -- 
        
        -- State for incrementing the input counter -- 
        
        when increment_state => 
            next_state <= switch_S1;
        
        when switch_S1 =>
            if (SPI_WR_ACK = '1') then 
                next_state <= switch_S2;
            else 
                next_state <= state;
            end if;
            
        when switch_S2 => 
            if (SPI_WR_ACK = '0') then
                next_state <= prime;
            else 
                next_state <= state;
            end if;
            
       -- Start of the read transaction -- 
       
        when wait_read =>
            if (Read = '1') then
                next_state <= instr2_S1; 
            else 
                next_state <= state;
            end if;
            
        -- Sending the read instruction -- 
        
        when instr2_S1 =>
            if (SPI_WR_ACK = '1') then 
                next_state <= instr2_S2;
            else 
                next_state <= state;
            end if;
        when instr2_S2 => 
            if (SPI_WR_ACK = '0') then
                next_state <= Address2_1_S1;
            else 
                next_state <= state;
            end if;
            
        -- Sending the Memory Address -- 
        
        -- Byte 1 --
        
        when Address2_1_S1 =>
            if (SPI_WR_ACK = '1') then 
                next_state <= Address2_1_S2;
            else 
                next_state <= state;
            end if;
        when Address2_1_S2 => 
            if (SPI_WR_ACK = '0') then
                next_state <= Address2_2_S1;
            else 
                next_state <= state;
            end if;
            
        -- Byte 2 -- 
        
        when Address2_2_S1 =>
            if (SPI_WR_ACK = '1') then 
                next_state <= Address2_2_S2;
            else 
                next_state <= state;
            end if;
        when Address2_2_S2 => 
            if (SPI_WR_ACK = '0') then
                next_state <= Address2_3_S1;
            else 
                next_state <= state;
            end if;
            
        -- Byte 3 --  
        
        when Address2_3_S1 =>
            if (SPI_WR_ACK = '1') then 
                next_state <= Address2_3_S2;
            else 
                next_state <= state;
            end if;
        when Address2_3_S2 => 
            if (SPI_WR_ACK = '0') then
                next_state <= output;
            else 
                next_state <= state;
            end if;
            
        -- Output state, start to output all the stored values -- 
        
        when output => 
            if (input_count_val /= 0) then
                next_state <= read_s1;
            else 
                next_state <= idle;
            end if;
        
        -- Sending read request -- 
        
        when read_s1 =>
            if (SPI_RD_ACK = '1') then
                next_state <= read_s2;
            else
                next_state <= state;
            end if;
            
        when read_s2 =>
            if (SPI_RD_ACK = '0') then
                next_state <= wait_state_1;
            else
                next_state <= state;
            end if;
        
        -- Wait states for the output time -- 
        
        when wait_state_1 =>
            if (disp_count_val = disp_delay-1) then
                next_state <= wait_state_2;
            else 
                next_state <= state;
            end if;
        
        when wait_state_2 => 
            if (disp_count_val = disp_delay-1) then
                next_state <= output;
            else
                next_state <= state;
            end if;    
       
    end case;
end process FSM;    
                 
-------------------------
-- Combinational Logic -- 
-------------------------

-- Assigning Buttons -- 
-- Reset is already set to Button 0
Write <= USER_PB(1);
Enter_Val <= USER_PB(2);
READ <= USER_PB(3);

-- Read and Write Requests -- 

-- All the states where the SPI_WR_REQ should be high -- 
SPI_WR_REQ <= '1' when state = instr_S1 or state = Address1_S1 or state = Address2_S1 or state = Address3_S1 or 
                       state = switch_s1 or state = instr2_s1 or state = Address2_1_S1 or state = Address2_2_S1 or 
                       state = Address2_3_S1 else '0';
-- The state where the SPI_RD_REQ should be high --                        
SPI_RD_REQ <= '1' when state = read_s1 else '0';

-- The enable is high when the state is not in one of the two idle/wait states. 
EN_SPI <= '0' when state = idle or state = wait_read else '1';

-- Options for the data to the SRAM, either the instructions for the functions, 
--  the bytes for the address in the SRAM or the switch data that is inputted. 
DATA_TO_SPI <= "00000010" when state = instr_S1 else  -- Write Instruction
               "00000011" when state = instr2_S1 else -- Read Instruction
               SRAM_ADDRESS(23 downto 16) when state = Address1_S1 or state = Address2_1_S1 else
               SRAM_ADDRESS(15 downto 8) when state = Address2_S1 or state = Address2_2_S1 else               
               SRAM_ADDRESS(7 downto 0) when state = Address3_S1 or state = Address2_3_S1 else
               SWITCHES when state = switch_S1 else 
               (others => '0');

-- Output options, either from the counter while the data is being inputted, 
--  or the data from the SRAM while it is being read back.                
LEDS <= std_logic_vector(input_count_val) when state = prime or state = switch_s1 or state = switch_s2 or state = increment_state else
        DATA_FROM_SPI(7 downto 4) when state = wait_state_1 else
        DATA_FROM_SPI(3 downto 0) when state = wait_state_2 else
        (others => '0');

-- Display Counter Logic -- 
disp_count_en <= '1' when state = wait_state_1 or state = wait_state_2 else '0'; 
disp_count_rst <= not disp_count_en;

-- Input Counter Logid -- 
input_count_en <= '1' when state = increment_state or state = output else '0';
input_count_dir <= '1' when state = output else '0';
input_count_rst <= '1' when RST = '1' or state = idle else '0';

--------------
-- Counters -- 
--------------

-- Display counter -- 
-- This counter counts up to a (very) larger number, 
--  so the data can be shown on the output LEDs, 
--  for the right amount of time. 
disp_counter : entity work.Param_Counter
Generic Map (LIMIT => disp_delay)
Port Map ( clk => CLK,
           rst => disp_count_rst,
           en => disp_count_en,
           count_out => disp_count_val );
           
-- Up-Down Counter -- 
-- This counter counts how much data has been inputted, 
-- as well as how much is still left to be outputted. 
UDCounter : process (clk) is
begin
    if rising_edge(clk) then
        if input_count_rst = '1' then 
            input_count_val <= (others => '0');
		elsif input_count_en = '1' then
			if input_count_dir = '0' then	
				if input_count_val < input_counter_limit then
					input_count_val <= (input_count_val + 1);
				end if;
			elsif input_count_dir = '1' then	
				if input_count_val > 0 then	
					input_count_val <= (input_count_val - 1);
				end if;
			end if;
		end if;
	end if;
end process UDCounter;
     
end Behavioral;




