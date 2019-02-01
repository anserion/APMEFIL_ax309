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
-- Description: rotate vpage content CCW to another vpage
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use ieee.std_logic_unsigned.all;

entity vpage_ccw_module is
    Port ( 
		clk        : in std_logic;
      hscanline_rd_ask: out std_logic;
      hscanline_rd_ready: in std_logic;
      hscanline_rd_page: out std_logic_vector(3 downto 0);
      hscanline_rd_x: out std_logic_vector(9 downto 0);
      hscanline_rd_y: out std_logic_vector(9 downto 0);
      hscanline_rd_pixel: in std_logic_vector(15 downto 0);
      
      vscanline_wr_ask: out std_logic;
      vscanline_wr_ready: in std_logic;
      vscanline_wr_page: out std_logic_vector(3 downto 0);
      vscanline_wr_x: out std_logic_vector(9 downto 0);
      vscanline_wr_y: out std_logic_vector(9 downto 0);
      vscanline_wr_pixel: out std_logic_vector(15 downto 0);

      hscanline_xmin : out std_logic_vector(9 downto 0);
      hscanline_xmax : out std_logic_vector(9 downto 0);

      vscanline_ymin : out std_logic_vector(9 downto 0);
      vscanline_ymax : out std_logic_vector(9 downto 0);
      
      source_xmin : in std_logic_vector(9 downto 0);
      source_ymin : in std_logic_vector(9 downto 0);
      source_xmax : in std_logic_vector(9 downto 0);
      source_ymax : in std_logic_vector(9 downto 0);
      
      source_vpage  : in std_logic_vector(3 downto 0);
      target_vpage  : in std_logic_vector(3 downto 0);
      
      ask        : in std_logic;
      ready      : out std_logic
	 );
end vpage_ccw_module;

architecture ax309 of vpage_ccw_module is

   signal fsm: natural range 0 to 15 := 0;
   signal x,y: std_logic_vector(9 downto 0):=(others=>'0');
  
begin
   hscanline_rd_page<=source_vpage; vscanline_wr_page<=target_vpage;
   hscanline_xmin<=source_xmin; hscanline_xmax<=source_xmax;   
   vscanline_ymin<=source_xmin; vscanline_ymax<=source_xmax;   
   
   process(clk)
   begin
   if rising_edge(clk) then
   case fsm is
   --idle
   when 0=> 
      ready<='0';
      if ask='1' then fsm<=1; end if; 
      
   when 1=>
      -- some init manipulations
      y<=source_ymin;
      hscanline_rd_ask<='0'; vscanline_wr_ask<='0';
      if (hscanline_rd_ready='0')and(vscanline_wr_ready='0') then fsm<=2; end if;

   -- for y=source_ymin to source_ymax
   when 2=>
      if y=source_ymax then fsm<=15; else fsm<=3; end if;
   -- read hscanline(y) from SDRAM
   when 3=>
      hscanline_rd_y<=y; hscanline_rd_ask<='1'; fsm<=4;
   when 4=>
      if hscanline_rd_ready='1' then hscanline_rd_ask<='0'; x<=source_xmax; fsm<=5; end if;

   -- for x=source_xmin to source_xmax (copy hscanline to vscanline)
   when 5=> if x=source_xmin then fsm<=8; else hscanline_rd_x<=x; fsm<=6; end if;
   when 6=>
      vscanline_wr_y<=source_xmax-x;
      vscanline_wr_pixel<="00000000"&hscanline_rd_pixel(7 downto 0);
      fsm<=7;
   -- x increment
   when 7=> x<=x-1; fsm<=5;
   
   -- write vscanline(y) to SDRAM
   when 8=>
      vscanline_wr_x<=y; vscanline_wr_ask<='1'; fsm<=9;
   when 9=>
      if vscanline_wr_ready='1' then vscanline_wr_ask<='0'; fsm<=14; end if;
      
   -- y increment
   when 14=> y<=y+1; fsm<=2;

   -- next idle
   when 15=>
      vscanline_wr_y<=(others=>'1');
      ready<='1';
      if ask='0' then fsm<=0; end if;

   when others=>null;
   end case;
   end if;
   end process;
end ax309;
