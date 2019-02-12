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
-- Description: sault and pepper noise and adaptive medain filter supervisor
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use ieee.std_logic_unsigned.all;

entity filter_supervisor is
    Port ( 
		clk        : in std_logic;

      hscanline_rd_ask: out std_logic;
      hscanline_rd_ready: in std_logic;
      hscanline_rd_page: out std_logic_vector(3 downto 0);
      hscanline_rd_x: out std_logic_vector(9 downto 0);
      hscanline_rd_y: out std_logic_vector(9 downto 0);
      hscanline_rd_pixel: in std_logic_vector(15 downto 0);
      
      hscanline_wr_ask: out std_logic;
      hscanline_wr_ready: in std_logic;
      hscanline_wr_page: out std_logic_vector(3 downto 0);
      hscanline_wr_x: out std_logic_vector(9 downto 0);
      hscanline_wr_y: out std_logic_vector(9 downto 0);
      hscanline_wr_pixel: out std_logic_vector(15 downto 0);

      hscanline_xmin : out std_logic_vector(9 downto 0);
      hscanline_xmax : out std_logic_vector(9 downto 0);

      vscanline_rd_ask: out std_logic;
      vscanline_rd_ready: in std_logic;
      vscanline_rd_page: out std_logic_vector(3 downto 0);
      vscanline_rd_x: out std_logic_vector(9 downto 0);
      vscanline_rd_y: out std_logic_vector(9 downto 0);
      vscanline_rd_pixel: in std_logic_vector(15 downto 0);
      
      vscanline_wr_ask: out std_logic;
      vscanline_wr_ready: in std_logic;
      vscanline_wr_page: out std_logic_vector(3 downto 0);
      vscanline_wr_x: out std_logic_vector(9 downto 0);
      vscanline_wr_y: out std_logic_vector(9 downto 0);
      vscanline_wr_pixel: out std_logic_vector(15 downto 0);

      vscanline_ymin : out std_logic_vector(9 downto 0);
      vscanline_ymax : out std_logic_vector(9 downto 0);      
      
      noise      : in std_logic_vector(31 downto 0);
      radius     : in std_logic_vector(31 downto 0);
      noise_xmin : in std_logic_vector(9 downto 0);
      noise_ymin : in std_logic_vector(9 downto 0);
      noise_xmax : in std_logic_vector(9 downto 0);
      noise_ymax : in std_logic_vector(9 downto 0);
      
      median_xmin: in std_logic_vector(9 downto 0);
      median_ymin: in std_logic_vector(9 downto 0);
      median_xmax: in std_logic_vector(9 downto 0);
      median_ymax: in std_logic_vector(9 downto 0);

      adaptive_median_xmin: in std_logic_vector(9 downto 0);
      adaptive_median_ymin: in std_logic_vector(9 downto 0);
      adaptive_median_xmax: in std_logic_vector(9 downto 0);
      adaptive_median_ymax: in std_logic_vector(9 downto 0)
	 );
end filter_supervisor;

architecture ax309 of filter_supervisor is
   component filter_module is
   Port ( 
		clk        : in std_logic;
      hscanline_rd_ask: out std_logic;
      hscanline_rd_ready: in std_logic;
      hscanline_rd_x: out std_logic_vector(9 downto 0);
      hscanline_rd_y: out std_logic_vector(9 downto 0);
      hscanline_rd_pixel: in std_logic_vector(15 downto 0);
      
      hscanline_wr_ask: out std_logic;
      hscanline_wr_ready: in std_logic;
      hscanline_wr_x: out std_logic_vector(9 downto 0);
      hscanline_wr_y: out std_logic_vector(9 downto 0);
      hscanline_wr_pixel: out std_logic_vector(15 downto 0);

      vscanline_rd_ask: out std_logic;
      vscanline_rd_ready: in std_logic;
      vscanline_rd_x: out std_logic_vector(9 downto 0);
      vscanline_rd_y: out std_logic_vector(9 downto 0);
      vscanline_rd_pixel: in std_logic_vector(15 downto 0);
      
      vscanline_wr_ask: out std_logic;
      vscanline_wr_ready: in std_logic;
      vscanline_wr_x: out std_logic_vector(9 downto 0);
      vscanline_wr_y: out std_logic_vector(9 downto 0);
      vscanline_wr_pixel: out std_logic_vector(15 downto 0);
      
      -- 000 - clear copy, 001 - CCW rotate, 010 - CW rotate
      -- 100 - noise, 101 - median, 110 - adaptive median
      filter_mode: in std_logic_vector(2 downto 0);
      radius     : in std_logic_vector(3 downto 0);
      noise      : in std_logic_vector(6 downto 0);
      filter_xmin: in std_logic_vector(9 downto 0);
      filter_ymin: in std_logic_vector(9 downto 0);
      filter_xmax: in std_logic_vector(9 downto 0);
      filter_ymax: in std_logic_vector(9 downto 0);
      ask        : in std_logic;
      ready      : out std_logic
	);
   end component;
   
   signal filter_ask,filter_ready : std_logic:='0';
   signal filter_mode: std_logic_vector(2 downto 0);
   
   signal filter_xmin : std_logic_vector(9 downto 0):=(others=>'0');
   signal filter_ymin : std_logic_vector(9 downto 0):=(others=>'0');
   signal filter_xmax : std_logic_vector(9 downto 0):=(others=>'0');
   signal filter_ymax : std_logic_vector(9 downto 0):=(others=>'0');
   
   signal filter_rd_page : std_logic_vector(3 downto 0):=(others=>'0');
   signal filter_wr_page : std_logic_vector(3 downto 0):=(others=>'0');
   
begin
   filter_chip: filter_module port map (
      clk,
      hscanline_rd_ask, hscanline_rd_ready,
      hscanline_rd_x, hscanline_rd_y,
      hscanline_rd_pixel,

      hscanline_wr_ask, hscanline_wr_ready,
      hscanline_wr_x, hscanline_wr_y,
      hscanline_wr_pixel,
      
      vscanline_rd_ask,vscanline_rd_ready,
      vscanline_rd_x,vscanline_rd_y,
      vscanline_rd_pixel,

      vscanline_wr_ask,vscanline_wr_ready,
      vscanline_wr_x,vscanline_wr_y,
      vscanline_wr_pixel,

      filter_mode,
      radius(3 downto 0), noise(6 downto 0),
      filter_xmin,filter_ymin,filter_xmax,filter_ymax,
      
      filter_ask,filter_ready
   );

   hscanline_rd_page<=filter_rd_page;
   vscanline_rd_page<=filter_rd_page;
   
   hscanline_wr_page<=filter_wr_page;
   vscanline_wr_page<=filter_wr_page;
   
   process(clk)
   variable fsm: integer range 0 to 31:=0;
   begin
   if rising_edge(clk) then
   case fsm is
   -- super idle
   when 0=>
      filter_ask<='0'; 
      if filter_ready='0' then fsm:=1; end if;

   -- CCW rotate output buffer and copy to videocontroller page
   when 1=> 
      filter_rd_page<="0101"; filter_wr_page<="0000";
      filter_xmin<=conv_std_logic_vector(208,10); filter_ymin<=conv_std_logic_vector(0,10);
      filter_xmax<=conv_std_logic_vector(480,10); filter_ymax<=conv_std_logic_vector(480,10);
      filter_mode<="001"; -- CCW ROTATE mode
      if filter_ready='0' then filter_ask<='1'; fsm:=2; end if;
   when 2=>
      hscanline_xmin<=filter_xmin; hscanline_xmax<=filter_xmax;
      vscanline_ymin<=filter_ymin; vscanline_ymax<=filter_ymax;
      if filter_ready='1' then filter_ask<='0'; fsm:=3; end if;

   -- "CAMERA page" copy to "Source page"
   when 3=> 
      filter_rd_page<="0001"; filter_wr_page<="0010";
      filter_xmin<=conv_std_logic_vector(208,10); filter_ymin<=conv_std_logic_vector(0,10);
      filter_xmax<=conv_std_logic_vector(480,10); filter_ymax<=conv_std_logic_vector(480,10);
      filter_mode<="000"; -- CLEAR COPY mode
      if filter_ready='0' then filter_ask<='1'; fsm:=4; end if;
   when 4=>
      hscanline_xmin<=filter_xmin; hscanline_xmax<=filter_xmax;
      vscanline_ymin<=(others=>'0'); vscanline_ymax<=(others=>'0');
      if filter_ready='1' then filter_ask<='0'; fsm:=5; end if;
  
   -- put noise to "Source page" and copy to "noise page"
   when 5=>
      filter_rd_page<="0010"; filter_wr_page<="0011";
      filter_xmin<=noise_xmin; filter_ymin<=noise_ymin;
      filter_xmax<=noise_xmax; filter_ymax<=noise_ymax;
      filter_mode<="100"; -- NOISE mode
      if filter_ready='0' then filter_ask<='1'; fsm:=6; end if;
   when 6=>
      hscanline_xmin<=filter_xmin; hscanline_xmax<=filter_xmax;
      vscanline_ymin<=(others=>'0'); vscanline_ymax<=(others=>'0');
      if filter_ready='1' then filter_ask<='0'; fsm:=7; end if; 
   
   -- median filter "noise page" and copy to "filter page"
   when 7=>
      filter_rd_page<="0011"; filter_wr_page<="0100";
      filter_xmin<=median_xmin; filter_ymin<=median_ymin;
      filter_xmax<=median_xmax; filter_ymax<=median_ymax;
      filter_mode<="101"; -- MEDIAN FILTER mode
      if filter_ready='0' then filter_ask<='1'; fsm:=8; end if;
   when 8=>
      hscanline_xmin<=filter_xmin; hscanline_xmax<=filter_xmax;
      vscanline_ymin<=(others=>'0'); vscanline_ymax<=(others=>'0');
      if filter_ready='1' then filter_ask<='0'; fsm:=9; end if; 

   -- adaptive median filter "noise page" and copy to "filter page"
   when 9=>
      filter_rd_page<="0011"; filter_wr_page<="0100";
      filter_xmin<=adaptive_median_xmin; filter_ymin<=adaptive_median_ymin;
      filter_xmax<=adaptive_median_xmax; filter_ymax<=adaptive_median_ymax;
      filter_mode<="110"; -- ADAPTIVE MEDIAN FILTER mode
      if filter_ready='0' then filter_ask<='1'; fsm:=10; end if;
   when 10=>
      hscanline_xmin<=filter_xmin; hscanline_xmax<=filter_xmax;
      vscanline_ymin<=(others=>'0'); vscanline_ymax<=(others=>'0');
      if filter_ready='1' then filter_ask<='0'; fsm:=11; end if;
   
   -- compose all pages
   
   -- "source page" copy to "output buffer"
   when 11=>
      filter_rd_page<="0010"; filter_wr_page<="0101";
      filter_xmin<=conv_std_logic_vector(208,10); filter_ymin<=conv_std_logic_vector(0,10);
      filter_xmax<=conv_std_logic_vector(480,10); filter_ymax<=conv_std_logic_vector(480,10);
      filter_mode<="000"; -- CLEAR COPY mode
      if filter_ready='0' then filter_ask<='1'; fsm:=12; end if;
   when 12=>
      hscanline_xmin<=filter_xmin; hscanline_xmax<=filter_xmax;
      vscanline_ymin<=(others=>'0'); vscanline_ymax<=(others=>'0');
      if filter_ready='1' then filter_ask<='0'; fsm:=13; end if;

   -- "noise page" copy to "output buffer"
   when 13=>
      filter_rd_page<="0011"; filter_wr_page<="0101";
      filter_xmin<=noise_xmin; filter_ymin<=noise_ymin;
      filter_xmax<=noise_xmax; filter_ymax<=noise_ymax;
      filter_mode<="000"; -- CLEAR COPY mode
      if filter_ready='0' then filter_ask<='1'; fsm:=14; end if;
   when 14=>
      hscanline_xmin<=filter_xmin; hscanline_xmax<=filter_xmax;
      vscanline_ymin<=(others=>'0'); vscanline_ymax<=(others=>'0');
      if filter_ready='1' then filter_ask<='0'; fsm:=15; end if;
   
   -- "median filter page" copy to "output buffer"
   when 15=>
      filter_rd_page<="0100"; filter_wr_page<="0101";
      filter_xmin<=median_xmin; filter_ymin<=median_ymin;
      filter_xmax<=median_xmax; filter_ymax<=median_ymax;
      filter_mode<="000"; -- CLEAR COPY mode
      if filter_ready='0' then filter_ask<='1'; fsm:=16; end if;
   when 16=>
      hscanline_xmin<=filter_xmin; hscanline_xmax<=filter_xmax;
      vscanline_ymin<=(others=>'0'); vscanline_ymax<=(others=>'0');
      if filter_ready='1' then filter_ask<='0'; fsm:=17; end if;

   -- "adaptive median filter page" copy to "output buffer"
   when 17=>
      filter_rd_page<="0100"; filter_wr_page<="0101";
      filter_xmin<=adaptive_median_xmin; filter_ymin<=adaptive_median_ymin;
      filter_xmax<=adaptive_median_xmax; filter_ymax<=adaptive_median_ymax;
      filter_mode<="000"; -- CLEAR COPY mode
      if filter_ready='0' then filter_ask<='1'; fsm:=18; end if;
   when 18=>
      hscanline_xmin<=filter_xmin; hscanline_xmax<=filter_xmax;
      vscanline_ymin<=(others=>'0'); vscanline_ymax<=(others=>'0');
      if filter_ready='1' then filter_ask<='0'; fsm:=0; end if;   

   when others=>null;
   end case;
   end if;
   end process;
end ax309;
