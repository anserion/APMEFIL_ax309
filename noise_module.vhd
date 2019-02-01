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
-- Description: sault and pepper noise generator
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use ieee.std_logic_unsigned.all;

entity noise_module is
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

      source_vpage  : in std_logic_vector(3 downto 0);
      target_vpage  : in std_logic_vector(3 downto 0);
      
      noise      : in std_logic_vector(6 downto 0);
      noise_xmin : in std_logic_vector(9 downto 0);
      noise_ymin : in std_logic_vector(9 downto 0);
      noise_xmax : in std_logic_vector(9 downto 0);
      noise_ymax : in std_logic_vector(9 downto 0);
      ask        : in std_logic;
      ready      : out std_logic
	 );
end noise_module;

architecture ax309 of noise_module is
   component rnd16_module is
   Port ( 
      clk: in  STD_LOGIC;
      seed : in STD_LOGIC_VECTOR(31 downto 0);
      rnd16: out STD_LOGIC_VECTOR(15 downto 0)
	);
   end component;

   signal fsm: natural range 0 to 15 := 0;
   signal seed: std_logic_vector(31 downto 0):=conv_std_logic_vector(26535,32);
   signal rnd16: std_logic_vector(15 downto 0):=(others=>'0');
   signal noise_level_17bit:std_logic_vector(16 downto 0):=(others=>'0');
   signal x,y: std_logic_vector(9 downto 0):=(others=>'0');
  
begin
   scanline_rd_page<=source_vpage; scanline_wr_page<=target_vpage;
   scanline_xmin<=noise_xmin; scanline_xmax<=noise_xmax;
   
   rnd16_chip: rnd16_module port map(clk,seed,rnd16);
   
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
      noise_level_17bit<=noise * conv_std_logic_vector(655,10);
      y<=noise_ymin;
      scanline_rd_ask<='0'; scanline_wr_ask<='0';
      if (scanline_rd_ready='0')and(scanline_wr_ready='0') then fsm<=2; end if;

   -- for y=noise_ymin to noise_ymax
   when 2=>
      if y=noise_ymax then fsm<=15; else x<=noise_xmin; fsm<=3; end if;
   -- read scanline(y) from SDRAM
   when 3=>
      scanline_rd_y<=y; scanline_rd_ask<='1'; fsm<=4;
   when 4=>
      if scanline_rd_ready='1' then scanline_rd_ask<='0'; fsm<=5; end if;

   -- for x=noise_xmin to noise_xmax
   when 5=> if x=noise_xmax then fsm<=8; else scanline_rd_x<=x; fsm<=6; end if;
   -- if rnd<noise_level then write pixel(x)=sault or pepper to scanline(y)
   when 6=>
      scanline_wr_x<=x;
      if rnd16<noise_level_17bit(15 downto 0)
      then scanline_wr_pixel<="00000000"&
                rnd16(0)&rnd16(0)&rnd16(0)&rnd16(0)&
                rnd16(0)&rnd16(0)&rnd16(0)&rnd16(0);
      else scanline_wr_pixel<="00000000"&scanline_rd_pixel(7 downto 0);
      end if;
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
