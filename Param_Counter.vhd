----------------------------------------------------------------------------------
-- Company: University of York
-- Engineer: Gianluca Tempesti
-- 
-- Create Date:    12/14/2015 
-- Design Name:    Parameterizable Counter
-- Module Name:    Param_Counter - Behavioral 
-- Project Name:   FDE_Final
-- Target Devices: Any (tested on xc6slx45-3csg324)
-- Tool versions:  Any (tested on ISE 14.2)
-- Description: 
--   A fully parameterizable counter to LIMIT (counts from 0 to LIMIT-1,
--   then cycles back to 0). Synchronous reset and enable.
-- Dependencies: 
--   Requires DigEng.vhd package
-- Revision: 
--   Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.DigEng.all;

entity Param_Counter is
generic (LIMIT : NATURAL := 17);
port ( clk : in  STD_LOGIC;
       rst : in  STD_LOGIC;
       en : in  STD_LOGIC;
       count_out : out UNSIGNED (log2(LIMIT)-1 downto 0));
end Param_Counter;

architecture Behavioral of Param_Counter is

signal count_int : UNSIGNED (log2(LIMIT)-1 downto 0);

begin

-- counter to LIMIT (0 to LIMIT-1) with synchronous reset and enable
counter: process (clk)
begin
  if rising_edge(CLK) then 
     if (rst = '1') then 
	     count_int <= (others => '0');
	  elsif (en = '1') then
	     if (count_int = LIMIT-1) then
           count_int <= (others => '0');
		  else
		     count_int <= count_int + 1;
        end if;
     end if;
  end if;
end process counter;

-- map internal counter value to output
count_out <= count_int;

end Behavioral;

