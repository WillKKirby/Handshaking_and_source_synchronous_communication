library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

--The entity is a SERDES (SERializer/DESerializer) circuit
-- that implements a very simplified 8-bit SPI (Serial 
-- Peripheral Interface) interface with only two instructions:
-- read and write. On the circuit side, it operates using a
-- simple handshaking protocol based on REQest and ACKnowledge
-- signals. On the SPI side, the entity operates in full-duplex
-- mode, controlling the SPI clock (SPI_SCK), an active-low chip 
-- select (SPI_S_INV), and two data lines (Master In Slave Out 
-- for reading and Master Out Slave In for writing).
--To operate, the interface must be activated through the 
-- (active-high) EN_SPI signal. When activated, the interface 
-- asserts (sets to '0') the active-low SPI_S_INV line and holds
-- it to '0' until the EN_SPI signal is released. Both read and
-- write requests are accepted as long as the EN_SPI signal 
-- remains asserted, allowing streaming operation. No error checking
-- is performed on the handshaking signals and if an incorrect
-- sequence of control signals is sent the circuit can enter an
-- unknown state and require a hard reset to recover.

--If a write request is received (SPI_WR_REQ = '1'), the interface
-- loads the data on the PDATA_TO_SPI input into an internal shift
-- register. It then generates 8 clock pulses on the SPI_C line and 
-- shifts out the data on the SPI_MOSI line. Shifting is synchronous 
-- to the falling edge of the clock (i.e. the assumption is that 
-- the slave will latch the data on the rising edge). On the 8th 
-- pulse, the interface asserts ('1') the SPI_WR_ACK line and holds 
-- it until the SPI_WR_REQ is released ('0'), at which point it 
-- releases the SPI_WR_ACK line ('0') and is ready to handle the next 
-- request.

--If a read request is received (SPI_RD_REQ = '1'), the interface
-- generates 8 clock pulses on the SPI_C line and shifts in the 
-- data arriving on the SPI_MISO line. Shifting is synchronous to 
-- the falling edge of the clock (i.e. the assumption is that 
-- incoming data will be stable on the falling edge). On the 8th 
-- pulse, the data is latched in the PDATA_TO_SPI register and 
-- is ready for retrieval. The interface then asserts ('1') the 
-- SPI_RD_ACK line and holds it until the SPI_RD_REQ is released
-- ('0'), at which point it releases the SPI_RD_ACK line ('0') and
-- is ready to handle the next request.

entity SPI_MASTER is
  Port ( 
    CLK : in  STD_LOGIC;
    RST : in  STD_LOGIC;
    -- Active-high interface enable. The signal should be 
    --  asserted bevore the first request is sent and should
    --  not be released until the last request has been acknowledged.
    EN_SPI : in  STD_LOGIC;
    -- 8-bit data to be sent to the SPI slave (WRITE)
    -- This data will be latched in and sent to the SPI slave
    --  when a write request is received (must be stable when
    --  SPI_WR_REQ is asserted)
    PDATA_TO_SPI : in  STD_LOGIC_VECTOR (7 downto 0);
    -- 8-bit data received from the SPI slave (READ)
    -- This data can be retrieved when the SPI_RD_ACK signal
    --  is asserted and will remain stable until the following
    --  request is received.
    PDATA_FROM_SPI : out  STD_LOGIC_VECTOR (7 downto 0);
    -- Control and data lines for the SPI interface
    SPI_SCK : out STD_LOGIC;    -- Clock
    SPI_S_INV : out STD_LOGIC;	-- Chip select (active low)
    SPI_MOSI : out  STD_LOGIC;	-- Serial data (master to slave)
    SPI_MISO : in  STD_LOGIC;	-- Serial data (slave to master)
    -- Handshaking protocol signals
    SPI_WR_REQ : in  STD_LOGIC;  -- write request
    SPI_WR_ACK : out STD_LOGIC;  -- write done acknowledgment
    SPI_RD_REQ : in  STD_LOGIC;  -- read request
    SPI_RD_ACK : out STD_LOGIC   -- read done acknowledgment
    );
end SPI_MASTER;

architecture Behavioral of SPI_MASTER is

-- FSM states:
--  IDLE when the interface has finished handling a request
--   and is ready to receive the next one (as long as the
--   EN_SPI input is '1')
--  SENDING when the interface is sending a byte to the 
--   slave. The FSM will return to IDLE when all data has been
--   sent.
--  RECEIVING when the interface is receiving a byte from the
--   slave. The FSM will return to idle when the full byte has
--   been received and latched in the PDATA_FROM_SPI register.
type spi_state_type is (idle, sending, receiving);
signal spi_state, spi_next_state: spi_state_type;

-- SERDES registers
signal spi_MOSI_reg  : STD_LOGIC_VECTOR(7 downto 0);
signal spi_MISO_reg  : STD_LOGIC_VECTOR(7 downto 0);
signal pdata_in_reg  : STD_LOGIC_VECTOR(7 downto 0);

-- Signals for the control of the SERDES registers
signal byte_done : STD_LOGIC;
signal count : UNSIGNED(2 downto 0);
signal load_en, spi_active : STD_LOGIC;

-- Internal signals because VHDL is really annoying
signal SPI_SCK_int : STD_LOGIC;
signal SPI_RD_ACK_int, SPI_WR_ACK_int: STD_LOGIC;

begin

------------- Handshaking Protocol ------------- 

-- The write acknowledgment is asserted when a write request has 
--  been received (state=sending) and the byte has been sent 
--  (byte_done='1'). It is released when the request is released.
SPI_WR_ACK_proc: process (CLK) is
begin
	if rising_edge(CLK) then
		if RST='1' or (SPI_WR_ACK_int='1' and SPI_WR_REQ='0') then 
			SPI_WR_ACK_int <= '0';
		elsif (spi_state=sending and byte_done='1') then
			SPI_WR_ACK_int <= '1';
		end if;
	end if;
end process;
SPI_WR_ACK <= SPI_WR_ACK_int;

-- The write acknowledgment is asserted when a read request has 
--  been received (state=receiving) and the received byte has been 
--  latched into the output register and is ready for retrieval 
--  (byte_done='1'). It is released when the request is released.
SPI_RD_ACK_proc: process (CLK) is
begin
	if rising_edge(CLK) then
		if RST = '1' or (SPI_RD_ACK_int = '1' and SPI_RD_REQ = '0') then 
			SPI_RD_ACK_int <= '0';
		elsif (spi_state = receiving and byte_done = '1') then
			SPI_RD_ACK_int <= '1';
		end if;
	end if;
end process;
SPI_RD_ACK <= SPI_RD_ACK_int;


------------- Control logic (FSM) ------------- 

-- FSM (see declaration area for state descriptions)
spi_state_assignment: process (CLK) is
begin
  if rising_edge(CLK) then
     if (RST = '1') then 
        spi_state <= idle;  -- synchronous reset to IDLE
     else 
        spi_state <= spi_next_state;
     end if;
  end if;
end process spi_state_assignment;


fsm_process: process (spi_state, EN_SPI, byte_done, 
                      SPI_WR_REQ, SPI_RD_REQ, 
                      SPI_WR_ACK_int, SPI_RD_ACK_int) is
begin
  case spi_state is
    when idle =>
	  -- Ignore any requests if the interface is not enabled or
	  --  if the handshaking for the previous request is not complete,
	  --  otherwise advance to the appropriate state when a request
	  --  is received. Note that write requests have precedence over
	  --  read requests.
      if EN_SPI='1' and SPI_WR_REQ='1' and SPI_WR_ACK_int='0' then
         spi_next_state <= sending; 
      elsif EN_SPI='1' and SPI_RD_REQ='1' and SPI_RD_ACK_int='0' then
         spi_next_state <= receiving;
      else
         spi_next_state <= spi_state; 
      end if;

    when sending =>
      -- Go back to idle when full byte has been sent
      if byte_done = '1' then     
         spi_next_state <= idle;
      else
         spi_next_state <= spi_state; 
      end if;
  
    when receiving =>
      -- Go back to idle when full byte has been received
      if byte_done = '1' then 
         spi_next_state <= idle;
      else
         spi_next_state <= spi_state; 
      end if;
      
  end case;
end process;		


------------- SPI Interface ------------- 

-- The slave is selected as long as the interface is enabled
SPI_S_INV <= not EN_SPI;

-- Signal to enable the shift and clock generation processes
spi_active <= '1' when (spi_state=sending or spi_state=receiving) and 
                        byte_done='0' else '0';
                       
-- The SCK is generated by a Toggle FF. This effectively means that
--   the SCK will toggle at half the frequency of the input clock CLK.
-- The clock is only generated when the SPI is sending or receiving
--   and will generate sequences of exactly 8 clock pulses for each
--   read/write operation.
SCK_proc: process (CLK) is
begin
  if rising_edge(CLK) then
    if (RST = '1' or spi_state = idle) then  
      SPI_SCK_int <= '0';
    elsif spi_active = '1' then
      SPI_SCK_int <= not SPI_SCK_int;
    end if;
  end if;
end process;

SPI_SCK <= SPI_SCK_int;

-- Load SERDES MOSI register when a write request has been received
load_en <= '1' when (spi_state=idle and spi_next_state=sending) else '0';

-- SERDES MOSI shift register, used for writing to the memory
-- NOTE: the register operates on the FALLING edge of the SPI clock
--  to minimise propagation delay effects on the SPI lines.
spi_MOSI_reg_proc: process (CLK) is
begin
  if rising_edge(CLK) then
    if (RST = '1') then
      spi_MOSI_reg <= (others => '0');
    elsif load_en = '1' then  -- load register (write request)
      spi_MOSI_reg <= PDATA_TO_SPI;
    -- shift when active (synced to the falling edge of the SPI clock)
    elsif spi_state = sending and SPI_SCK_int = '1' then  
      spi_MOSI_reg <= spi_MOSI_reg(6 downto 0) & '0';
    end if;
  end if;
end process;

-- The most significant bit of the SERDES register is sent out
--  through the MOSI line.
SPI_MOSI <= spi_MOSI_reg(7);

-- SERDES MISO shift register, used for writing to the memory
-- NOTE: the register operates on the RISING edge of the SPI clock
--  to minimise propagation delay effects on the SPI lines.
spi_MISO_reg_proc: process (CLK) is
begin
  if rising_edge(CLK) then
    if (RST = '1') then
      spi_MISO_reg <= (others => '0');
    -- shift when active (synced to the rising edge of the SPI clock)
    elsif spi_state = receiving and SPI_SCK_int = '0'and spi_active = '1' then  
      spi_MISO_reg <= spi_MISO_reg(6 downto 0) & SPI_MISO;
    end if;
  end if;
end process;

-- This register latches and preserves the byte received from the SRAM
--  once the MISO shift is complete. Note that this register is not strictly
--  necessary and could be removed to optimise area.
Latch_data_from_SPI: process (CLK) is
begin
	if (rising_edge(CLK)) then
		if (RST = '1' or spi_state = sending) then
			pdata_in_reg <= (others => '0');
		elsif (spi_state = receiving and spi_active = '0') then
			pdata_in_reg <= spi_MISO_reg;
		end if;
	end if;
end process;

PDATA_FROM_SPI <= pdata_in_reg;

-- Counter to 8 to keep track of the number of SPI_SCK pulses
byte_count_proc: process (CLK) is
begin
  if rising_edge(CLK) then
    if (RST = '1') then
       count <= (others => '0');
    elsif spi_active = '1' and SPI_SCK_int = '1' then
       count <= count + 1;
    end if;
  end if;
end process byte_count_proc;

-- Add one CLK period delay to the end of the SPI_SCK count,
--  allowing the SCK to complete the last period, then signal 
--  that the byte read/write is complete.
byte_done_proc: process (CLK) is
begin
  if rising_edge(CLK) then
    if (RST = '1' or spi_state = idle) then 
       byte_done <= '0';
    elsif count = 7 and SPI_SCK_int = '1' then
       byte_done <= '1';
    end if;
  end if;
end process byte_done_proc;


end Behavioral;

