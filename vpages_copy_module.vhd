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
-- Description: copy part of one vpage to another vpage
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use ieee.std_logic_unsigned.all;

entity vpage_copy_module is
    Port ( 
		clk        : in std_logic;
      scanline_rd_ask: out std_logic;
      scanline_rd_ready: in std_logic;
      scanline_rd_page: out std_logic_vector(3 downto 0);
      scanline_rd_x: out std_logic_vector(9 downto 0);
      scanline_rd_y: out std_logic_vector(9 downto 0);
      scanline_rd_pixel: in std_logic_vector(15 downto 0);
      
      scanline_wr_ask: out std_logic;
      scanline_wr_ready: in std_logic;
      scanline_wr_page: out std_logic_vector(3 downto 0);
      scanline_wr_x: out std_logic_vector(9 downto 0);
      scanline_wr_y: out std_logic_vector(9 downto 0);
      scanline_wr_pixel: out std_logic_vector(15 downto 0);

      scanline_xmin : out std_logic_vector(9 downto 0);
      scanline_xmax : out std_logic_vector(9 downto 0);
      
      source_xmin : in std_logic_vector(9 downto 0);
      source_ymin : in std_logic_vector(9 downto 0);
      source_xmax : in std_logic_vector(9 downto 0);
      source_ymax : in std_logic_vector(9 downto 0);
      
      source_vpage  : in std_logic_vector(3 downto 0);
      target_vpage  : in std_logic_vector(3 downto 0);
      
      ask        : in std_logic;
      ready      : out std_logic
	 );
end vpage_copy_module;

architecture ax309 of vpage_copy_module is

   signal fsm: natural range 0 to 15 := 0;
   signal x,y: std_logic_vector(9 downto 0):=(others=>'0');
  
begin
   scanline_rd_page<=source_vpage; scanline_wr_page<=target_vpage;
   scanline_xmin<=source_xmin; scanline_xmax<=source_xmax;   
   
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
      scanline_rd_ask<='0'; scanline_wr_ask<='0';
      if (scanline_rd_ready='0')and(scanline_wr_ready='0') then fsm<=2; end if;

   -- for y=scanline_ymin to scanline_ymax
   when 2=>
      if y=source_ymax then fsm<=15; else x<=source_xmin; fsm<=3; end if;
   -- read scanline(y) from SDRAM
   when 3=>
      scanline_rd_y<=y; scanline_rd_ask<='1'; fsm<=4;
   when 4=>
      if scanline_rd_ready='1' then scanline_rd_ask<='0'; fsm<=5; end if;

   -- for x=scanline_xmin to scanline_xmax
   when 5=> if x=source_xmax then fsm<=8; else scanline_rd_x<=x; fsm<=6; end if;
   when 6=>
      scanline_wr_x<=x;
      scanline_wr_pixel<="00000000"&scanline_rd_pixel(7 downto 0);
      fsm<=7;
   -- x increment
   when 7=> x<=x+1; fsm<=5;
   
   -- write scanline(y) to SDRAM
   when 8=>
      scanline_wr_y<=y; scanline_wr_ask<='1'; fsm<=9;
   when 9=>
      if scanline_wr_ready='1' then scanline_wr_ask<='0'; fsm<=14; end if;
      
   -- y increment
   when 14=> y<=y+1; fsm<=2;

   -- next idle
   when 15=>
      scanline_wr_x<=(others=>'1');
      ready<='1';
      if ask='0' then fsm<=0; end if;

   when others=>null;
   end case;
   end if;
   end process;
end ax309;
