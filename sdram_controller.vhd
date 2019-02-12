------------------------------------------------------------------
--Copyright 2019 Andrey S. Ionisyan (anserion@gmail.com)
--Licensed under the Apache License, Version 2.0 (the "License");
--you may not use this file except in compliance with the License.
--You may obtain a copy of the License at
--    http://www.apache.org/licenses/LICENSE-2.0
--Unless required by applicable law or agreed to in writing, software
--distributed under the License is distributed on an "AS IS" BASIS,
--WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--See the License for the specific language governing permissions and
--limitations under the License.
------------------------------------------------------------------

----------------------------------------------------------------------------------
-- Engineer: Andrey S. Ionisyan <anserion@gmail.com>
-- 
-- Description: low level SDRAM HY57V2562GTR controller (256 MBit, 16M*16bit)
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity sdram_controller is
   generic (sdram_frequency: integer:=100); -- SDRAM frequency in MHz
   port (
      clk  : in std_logic;
      sdram_ready : out std_logic;
      
      sdram_precharge_latency: in std_logic_vector(1 downto 0);
      sdram_activate_row_latency: in std_logic_vector(1 downto 0);
      
      sdram_clk: out std_logic;
      sdram_cke: out std_logic;
      sdram_ncs: out std_logic;
      sdram_nwe   : out std_logic;
      sdram_ncas  : out std_logic;
      sdram_nras  : out std_logic;
      sdram_a     : out std_logic_vector(12 downto 0);
      sdram_ba    : out std_logic_vector(1 downto 0);
      sdram_dqm   : out std_logic_vector(1 downto 0);
      sdram_dq    : inout std_logic_vector(15 downto 0);
     
      mem_ask    : in std_logic;
      mem_ready  : out std_logic;
      mem_wr_en  : in std_logic;
      mem_addr   : in std_logic_vector(23 downto 0);
      mem_wr_data: in std_logic_vector(15 downto 0);
      mem_rd_data: out std_logic_vector(15 downto 0);

      scanline_ask   : in std_logic;
      scanline_addr  : out std_logic_vector(23 downto 0);
      
      scanline_addr_start: in std_logic_vector(23 downto 0);
      scanline_addr_nums : in std_logic_vector(23 downto 0);
      scanline_addr_delta: in std_logic_vector(23 downto 0)
   );
end entity;

architecture ax309 of sdram_controller is
   constant cmd_mode_reg_set: std_logic_vector(2 downto 0):= "000";
   constant cmd_refresh	   : std_logic_vector(2 downto 0) := "001";
   constant cmd_precharge  : std_logic_vector(2 downto 0) := "010";
   constant cmd_active     : std_logic_vector(2 downto 0) := "011";
   constant cmd_write      : std_logic_vector(2 downto 0) := "100";
   constant cmd_read       : std_logic_vector(2 downto 0) := "101";
   constant cmd_burst_stop : std_logic_vector(2 downto 0) := "110";
   constant cmd_nop        : std_logic_vector(2 downto 0) := "111";
   
   constant init_delay_cnt_max: integer:= sdram_frequency*100;
   
   signal sdram_cmd : std_logic_vector(2 downto 0):=(others=>'1'); -- NOP by default
   signal active_burst_idx : std_logic_vector(14 downto 0):=(others=>'0');
   signal mem_addr_reg: std_logic_vector(23 downto 0):=(others=>'0');
   signal mem_ready_reg: std_logic:='0';
   signal scanline_addr_reg: std_logic_vector(23 downto 0):=(others=>'0');
   signal scanline_addr_nums_reg: std_logic_vector(23 downto 0):=(others=>'0');

begin
   sdram_clk<=clk;

   sdram_cke<='1';    -- clock is always enabled
   sdram_ncs<='0';    -- "chip select" low - is active
   
   sdram_nras<=sdram_cmd(2);
   sdram_ncas<=sdram_cmd(1);
   sdram_nwe <=sdram_cmd(0);

   mem_rd_data <= sdram_dq when mem_wr_en='0' else (others => '0');
   sdram_dq <= mem_wr_data when mem_wr_en='1' else (others => 'Z');
   
   mem_ready<=mem_ready_reg;
   mem_addr_reg<=mem_addr when mem_ask='1' else scanline_addr_reg when scanline_ask='1' else (others=>'0');
   scanline_addr<=scanline_addr_reg when scanline_ask='1' else (others=>'0');
   
   process(clk)
   variable fsm: integer range 0 to 15:=0;
   variable init_delay_cnt: integer range 0 to init_delay_cnt_max+1:=0;
   variable init_cnt: integer range 0 to 31:=0;
   begin
   if rising_edge(clk) then
      case fsm is
      -- init sdram
      when 0=>
         sdram_ready<='0';
         init_delay_cnt:=0;
         fsm:=1;
      when 1=>
         if init_delay_cnt=init_delay_cnt_max
         then init_cnt:=0; fsm:=2;
         else sdram_cmd<=cmd_nop; init_delay_cnt:=init_delay_cnt+1;
         end if;
      when 2=>
         if init_cnt=5 then fsm:=3;
         else
            sdram_a(10)<='1';
            sdram_cmd<=cmd_precharge;
            init_cnt:=init_cnt+1;
         end if;
      when 3=>
         if init_cnt=15 then fsm:=4;
         else
            sdram_cmd<=cmd_refresh;
            init_cnt:=init_cnt+1;
         end if;
      when 4=>
         if init_cnt=20
         then
            sdram_dqm <= "11"; -- suppress data I/O
            active_burst_idx<=(others=>'0');
            sdram_ba <= (others => '0');
            sdram_a  <= (others => '0');
            sdram_cmd<=cmd_nop;
            sdram_ready<='1';
            mem_ready_reg<='1';
            fsm:=5;
         else
            sdram_ba(1 downto 0) <= "00";   -- always zero
            sdram_a(12 downto 10) <= "000"; -- always zero
            sdram_a(9) <= '0'; -- write mode (0 - burst read and burst write, 1 - burst read and single write)
            sdram_a(8 downto 7) <= "00";  -- always zero
            sdram_a(6 downto 4) <= "010"; -- CAS Latency ("010" - 2, "011" - 3, others - reserved)
            sdram_a(3) <= '0'; -- burst type (0 - sequential, 1 - interleave)
            sdram_a(2 downto 0) <= "111"; -- burst length ("000" - 1, "001" - 2, "010" - 4, "011" - 8, "111" and a3=0 - full page, others - reserved)
            sdram_cmd<=cmd_mode_reg_set;
            init_cnt:=init_cnt+1;
         end if;
      
      -- idle
      when 5=>
         if ((mem_ask='1') or (scanline_ask='1')) and (mem_ready_reg='0')
         then
            if mem_addr_reg(23 downto 9) = active_burst_idx
            then 
               if scanline_ask='1'
               then scanline_addr_nums_reg<=scanline_addr_nums_reg+1;
               end if;
               -- read/write inside active row
               sdram_dqm <= "00"; -- allow data I/O
               sdram_a(10) <= '0'; -- auto precharge control bit (0 - disable AP, 1 - enable AP)
               sdram_a(9 downto 0) <= "0" & mem_addr_reg(8 downto 0);
               if mem_wr_en='0'
               then sdram_cmd <= cmd_read;
               else sdram_cmd <= cmd_write;
               end if;
               fsm:=6; -- go to read/write latency            
            else
               -- close active row
               sdram_dqm <= "11"; -- suppress data I/O
               sdram_a(10)<='0'; -- precharge (1 - all banks, 0 - current bank)
               sdram_cmd <= cmd_precharge;
               case sdram_precharge_latency is
               when "00"=> fsm:=11; -- no latency (go to activate new row)
               when "01"=> fsm:=10; -- 1 cycle latency
               when "10"=> fsm:=9;  -- 2 cycle latency
               when "11"=> fsm:=8;  -- 3 cycle latency
               when others=> null;
               end case;
            end if;
         else
            sdram_dqm <= "11"; -- suppress data I/O
            sdram_cmd<=cmd_nop; -- autorefresh
            if (scanline_ask='0')and(mem_ask='0')
            then
               scanline_addr_reg<=scanline_addr_start;
               scanline_addr_nums_reg<=(others=>'0');
               mem_ready_reg<='0';
            end if;
         end if;
      
      -- read/write latency
      when 6=> fsm:=7;
      when 7=> fsm:=15; -- go to ready and autorefresh state
      
      -- precharge latency
      when 8=> fsm:=9;
      when 9=> fsm:=10;
      when 10=> fsm:=11; -- go to activate new row
      
      -- activate new row
      when 11=>
         active_burst_idx<=mem_addr_reg(23 downto 9);
         sdram_ba  <= mem_addr_reg(23 downto 22); 
         sdram_a   <= mem_addr_reg(21 downto 9);
         sdram_cmd <= cmd_active;
         case sdram_activate_row_latency is
         when "00"=> fsm:=5;  -- no latency (go to read/write process inside active row)
         when "01"=> fsm:=14; -- 1 cycle latency
         when "10"=> fsm:=13; -- 2 cycle latency
         when "11"=> fsm:=12; -- 3 cycle latency
         when others=> null;
         end case;
      
      -- activate new row latency
      when 12=> fsm:=13;
      when 13=> fsm:=14;
      when 14=> fsm:=5; -- go to read/write process inside active row

      -- success finish of read/write process
      when 15=>
         sdram_cmd<=cmd_nop; -- stop read/write and autorefresh
         if scanline_ask='1'
         then scanline_addr_reg<=scanline_addr_reg+scanline_addr_delta;
         end if;
         if (mem_ask='1') or ((scanline_ask='1') and (scanline_addr_nums_reg=scanline_addr_nums))
         then mem_ready_reg<='1';
         end if;
         fsm:=5; -- go to idle
      
      when others=>null;
      end case;
   end if;
   end process;
end;
