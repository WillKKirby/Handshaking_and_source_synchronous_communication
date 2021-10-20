LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
 
 
ENTITY TOP_LEVEL_tb IS
END TOP_LEVEL_tb;
 
 ARCHITECTURE behavior OF TOP_LEVEL_tb IS 
 
-- Testing Stratagy -- 
-- My testing stratagy is first to input all fore different combinations
--  of data from the switches, with the help of the switch_values array. 
-- I will then check this against known good values, from the other array.
-- After the fore combinations have been checked, I will then try and input 
--  more data than the circuit wants to take. (I try input 16 when the max is 15)
-- This will check the circuit does indeed ignore the extra inputted data.

--Inputs
signal GCLK : std_logic;
signal BTN : std_logic_vector(3 downto 0);
signal SW : std_logic_vector(1 downto 0);

--Outputs
signal LED : std_logic_vector(3 downto 0);

-- Internal SPI signals
signal SPI_MISO: STD_LOGIC;
signal SPI_MOSI: STD_LOGIC;
signal SPI_CS_INV: STD_LOGIC;
signal SPI_HOLD_INV: STD_LOGIC;
signal SPI_SCK: STD_LOGIC;

-- Clock period definitions
constant GCLK_period : time := 10 ns;

-- Switch Signals 
-- Used to cycle around the inputs.
type value_Array is array (natural range<>) of std_logic_vector(1 downto 0);
constant switch_values : value_Array := ("00","01","10","11","00","01","10","11","00","01","10","11","00","01","10","11") ;

-- Known Good Values -- 
-- Used to check the values from the output LEDs of the circuit. 
-- The data is stored in couples, the known good values are:
-- "24", "5a", "a5" and "f1".
type hex_vals is array (natural range<>) of unsigned(3 downto 0);
constant known_good_values : hex_vals := (("0010"), ("0100"), ("0101"), ("1010"), ("1010"),("0101"), ("1111"), ("0001")); 
 
BEGIN
 
-- Instantiate the Unit Under Test (UUT)
uut: entity work.TOP_LEVEL 
GENERIC MAP (disp_delay => 50)
PORT MAP (
      GCLK => GCLK,
      BTN => BTN,
      SW => SW,
      LED => LED,
      SPI_MISO => SPI_MISO,
      SPI_SCK => SPI_SCK,
      SPI_CS_INV => SPI_CS_INV,
      SPI_HOLD_INV => SPI_HOLD_INV,
      SPI_MOSI => SPI_MOSI
    );

-- Clock process definitions
GCLK_process : process
begin
    GCLK <= '0';
    wait for GCLK_period/2;
    GCLK <= '1';
    wait for GCLK_period/2;
end process;
 
SRAM : entity work.SRAM_Model
PORT MAP (
          SPI_MISO => SPI_MISO,
          SPI_SCK => SPI_SCK,
          SPI_CS_INV => SPI_CS_INV,
          SPI_HOLD_INV => SPI_HOLD_INV,
          SPI_MOSI => SPI_MOSI
        );

-- Stimulus process
stim_proc : process
begin		
    -- hold reset state for 1000 ns.
    wait for 1000 ns;	
    wait until falling_edge(GCLK);
    -------------------
    -- Inital Values --
    ------------------- 
    
    BTN <= "0000";
    SW <= "00";
    wait for GCLK_period*10;
    
    ------------------
    -- Inital Reset --
    ------------------ 
    
    BTN <= "0001";
    wait for GCLK_period*15;
    BTN <= "0000";
    wait for GCLK_period*15;
    
    ------------------------------
    -- Entering into Write Mode --
    ------------------------------  
   
    BTN <= "0010";
    wait for GCLK_period*15;
    BTN <= "0000";
    wait for GCLK_period*15;  
    
    wait for GCLK_period*500;
    
    -----------------------------------
    -- Sending Data in from Switches --
    -----------------------------------
    
    -- This loop will loop through the 4 base conbinations. 
    
    for i in 0 to 3 loop
    
        SW <= switch_values(i);
        wait for GCLK_period*2;
        BTN <= "0100";
        wait for GCLK_PERIOD*15;
        BTN <= "0000";
        
        -- Wait for the handshake to be over. 
        wait for GCLK_period*115; 
    
    end loop;
    
    wait for GCLK_period*150;
    
    ------------------------
    -- Exiting Write Mode --
    ------------------------
    
    BTN <= "0010";
    wait for GCLK_period*15;
    BTN <= "0000";
    wait for GCLK_period*15;

    ------------------------
    -- Entering Read Mode --
    ------------------------ 

    BTN <= "1000";
    wait for GCLK_period*15;
    BTN <= "0000";
    wait for GCLK_period*15;
    
    -- Waiting for all the reading to be done -- 
    wait for GCLK_period*1500;
    
    -------------------------------------
    -- Test to check for maximum input --
    -------------------------------------  
    
    -- This point is after the self-checking so timing is less important -- 
    
    -- Reset to check the circuit starts again after a reset -- 
    BTN <= "0001";
    wait for GCLK_period*15;
    BTN <= "0000";
    wait for GCLK_period*15;    
    
    -- Wait after the reset -- 
    wait for 1000ns;
    
    -- Putting the circuit back into write mode -- 
    BTN <= "0010";
    wait for GCLK_period*15;
    BTN <= "0000";
    wait for GCLK_period*15;  
    
    wait for GCLK_period*500;
    
    -- Run 1 more than 15 to check -- 
    for i in 0 to 15 loop
    
        SW <= switch_values(i);
        wait for GCLK_period*2;
        BTN <= "0100";
        wait for GCLK_PERIOD*15;
        BTN <= "0000";
        
        -- Wait for the handshake to be over. 
        wait for GCLK_period*115; 
    
    end loop;
    
    wait for GCLK_period*150;

    wait;
end process;



Test_Process : process 
begin
    -- The same inital wait -- 
    wait for 1000 ns;
    wait until falling_edge(GCLK);
    -- I found it hard to find the correct timing, 
    -- So, I wait until this signal goes high.
    wait until SPI_MISO = '1';
    
    wait for GCLK_period*80;
    
    for i in known_good_values'range loop
        
        assert (unsigned(LED) = known_good_values(i))
        report "Test Failed! : Test ID: " & integer'image(i) & ". Known good value: " & integer'image(to_integer((known_good_values(i)))) & ". Test Value: " & integer'image(to_integer(unsigned(LED)))
        severity error;
        
        assert (unsigned(LED) /= known_good_values(i))
        report "Test Passed! : Test ID: " & integer'image(i) & ". Known good value: " & integer'image(to_integer((known_good_values(i)))) & ". Test Value: " & integer'image(to_integer(unsigned(LED)))
        severity note;
        
        -- This if statement checks if the current loop needs to jump only a short time, 
        --  or a longer time since there is a gap between the outputs. 
        if (i = 0 or i = 2 or i = 4 or i = 6 or i = 8) then
            wait for GCLK_period*50;
        else
            wait for GCLK_period*170;
        end if;
    
    end loop;
    
    wait;
    
end process Test_Process;

END;
