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

entity filter_cpu is
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
      median_ymax: in std_logic_vector(9 downto 0)
	 );
end filter_cpu;

architecture ax309 of filter_cpu is
   component noise_module is
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
   end component;

   component median_module is
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
      
      radius     : in std_logic_vector(3 downto 0);
      median_xmin: in std_logic_vector(9 downto 0);
      median_ymin: in std_logic_vector(9 downto 0);
      median_xmax: in std_logic_vector(9 downto 0);
      median_ymax: in std_logic_vector(9 downto 0);
      ask        : in std_logic;
      ready      : out std_logic
	);
   end component;

   component vpage_copy_module is
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
   end component;

   component vpage_ccw_module is
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
   end component;
    
   signal fsm: natural range 0 to 15 := 0;
   
   signal noise_ask,noise_ready : std_logic:='0';
   signal noise_scanline_rd_ask : std_logic:='0';
   signal noise_scanline_rd_page: std_logic_vector(3 downto 0):=(others=>'0');
   signal noise_scanline_rd_x   : std_logic_vector(9 downto 0):=(others=>'0');
   signal noise_scanline_rd_y   : std_logic_vector(9 downto 0):=(others=>'0');
   
   signal noise_scanline_wr_ask : std_logic:='0';
   signal noise_scanline_wr_page: std_logic_vector(3 downto 0):=(others=>'0');
   signal noise_scanline_wr_x   : std_logic_vector(9 downto 0):=(others=>'0');
   signal noise_scanline_wr_y   : std_logic_vector(9 downto 0):=(others=>'0');
   signal noise_scanline_wr_pixel: std_logic_vector(15 downto 0):=(others=>'0');

   signal noise_scanline_xmin   : std_logic_vector(9 downto 0):=(others=>'0');
   signal noise_scanline_xmax   : std_logic_vector(9 downto 0):=(others=>'0');

   signal noise_rd_page: std_logic_vector(3 downto 0):=(others=>'0');
   signal noise_wr_page: std_logic_vector(3 downto 0):=(others=>'0');
   
   signal median_ask,median_ready : std_logic:='0';
   signal median_scanline_rd_ask : std_logic:='0';
   signal median_scanline_rd_page: std_logic_vector(3 downto 0):=(others=>'0');
   signal median_scanline_rd_x   : std_logic_vector(9 downto 0):=(others=>'0');
   signal median_scanline_rd_y   : std_logic_vector(9 downto 0):=(others=>'0');
   
   signal median_scanline_wr_ask : std_logic:='0';
   signal median_scanline_wr_page: std_logic_vector(3 downto 0):=(others=>'0');
   signal median_scanline_wr_x   : std_logic_vector(9 downto 0):=(others=>'0');
   signal median_scanline_wr_y   : std_logic_vector(9 downto 0):=(others=>'0');
   signal median_scanline_wr_pixel: std_logic_vector(15 downto 0):=(others=>'0');

   signal median_scanline_xmin   : std_logic_vector(9 downto 0):=(others=>'0');
   signal median_scanline_xmax   : std_logic_vector(9 downto 0):=(others=>'0');

   signal median_rd_page: std_logic_vector(3 downto 0):=(others=>'0');
   signal median_wr_page: std_logic_vector(3 downto 0):=(others=>'0');

   signal vpage_copy_ask,vpage_copy_ready : std_logic:='0';
   signal vpage_copy_scanline_rd_ask : std_logic:='0';
   signal vpage_copy_scanline_rd_page: std_logic_vector(3 downto 0):=(others=>'0');
   signal vpage_copy_scanline_rd_x   : std_logic_vector(9 downto 0):=(others=>'0');
   signal vpage_copy_scanline_rd_y   : std_logic_vector(9 downto 0):=(others=>'0');
   
   signal vpage_copy_scanline_wr_ask : std_logic:='0';
   signal vpage_copy_scanline_wr_page: std_logic_vector(3 downto 0):=(others=>'0');
   signal vpage_copy_scanline_wr_x   : std_logic_vector(9 downto 0):=(others=>'0');
   signal vpage_copy_scanline_wr_y   : std_logic_vector(9 downto 0):=(others=>'0');
   signal vpage_copy_scanline_wr_pixel: std_logic_vector(15 downto 0):=(others=>'0');
   
   signal vpage_copy_scanline_xmin   : std_logic_vector(9 downto 0):=(others=>'0');
   signal vpage_copy_scanline_xmax   : std_logic_vector(9 downto 0):=(others=>'0');
   
   signal vpage_copy_xmin : std_logic_vector(9 downto 0):=(others=>'0');
   signal vpage_copy_ymin : std_logic_vector(9 downto 0):=(others=>'0');
   signal vpage_copy_xmax : std_logic_vector(9 downto 0):=(others=>'0');
   signal vpage_copy_ymax : std_logic_vector(9 downto 0):=(others=>'0');
   
   signal vpage_copy_rd_page: std_logic_vector(3 downto 0):=(others=>'0');
   signal vpage_copy_wr_page: std_logic_vector(3 downto 0):=(others=>'0');
   
   signal vpage_ccw_ask,vpage_ccw_ready : std_logic:='0';
   signal vpage_ccw_hscanline_rd_ask : std_logic:='0';
   signal vpage_ccw_hscanline_rd_page: std_logic_vector(3 downto 0):=(others=>'0');
   signal vpage_ccw_hscanline_rd_x   : std_logic_vector(9 downto 0):=(others=>'0');
   signal vpage_ccw_hscanline_rd_y   : std_logic_vector(9 downto 0):=(others=>'0');
   
   signal vpage_ccw_vscanline_wr_ask : std_logic:='0';
   signal vpage_ccw_vscanline_wr_page: std_logic_vector(3 downto 0):=(others=>'0');
   signal vpage_ccw_vscanline_wr_x   : std_logic_vector(9 downto 0):=(others=>'0');
   signal vpage_ccw_vscanline_wr_y   : std_logic_vector(9 downto 0):=(others=>'0');
   signal vpage_ccw_vscanline_wr_pixel: std_logic_vector(15 downto 0):=(others=>'0');
   
   signal vpage_ccw_hscanline_xmin   : std_logic_vector(9 downto 0):=(others=>'0');
   signal vpage_ccw_hscanline_xmax   : std_logic_vector(9 downto 0):=(others=>'0');
   signal vpage_ccw_vscanline_ymin   : std_logic_vector(9 downto 0):=(others=>'0');
   signal vpage_ccw_vscanline_ymax   : std_logic_vector(9 downto 0):=(others=>'0');
   
   signal vpage_ccw_xmin : std_logic_vector(9 downto 0):=(others=>'0');
   signal vpage_ccw_ymin : std_logic_vector(9 downto 0):=(others=>'0');
   signal vpage_ccw_xmax : std_logic_vector(9 downto 0):=(others=>'0');
   signal vpage_ccw_ymax : std_logic_vector(9 downto 0):=(others=>'0');
   
   signal vpage_ccw_rd_page: std_logic_vector(3 downto 0):=(others=>'0');
   signal vpage_ccw_wr_page: std_logic_vector(3 downto 0):=(others=>'0');   
begin

   vpage_ccw_chip: vpage_ccw_module port map (
      clk,      
      vpage_ccw_hscanline_rd_ask,hscanline_rd_ready,vpage_ccw_hscanline_rd_page,
      vpage_ccw_hscanline_rd_x,vpage_ccw_hscanline_rd_y,hscanline_rd_pixel,

      vpage_ccw_vscanline_wr_ask,vscanline_wr_ready,vpage_ccw_vscanline_wr_page,
      vpage_ccw_vscanline_wr_x,vpage_ccw_vscanline_wr_y,vpage_ccw_vscanline_wr_pixel,
      
      vpage_ccw_hscanline_xmin, vpage_ccw_hscanline_xmax,
      vpage_ccw_vscanline_ymin, vpage_ccw_vscanline_ymax,
      
      vpage_ccw_xmin,vpage_ccw_ymin,vpage_ccw_xmax,vpage_ccw_ymax,
      
      vpage_ccw_rd_page, vpage_ccw_wr_page,

      vpage_ccw_ask,vpage_ccw_ready );
   
   vpage_copy_chip: vpage_copy_module port map (
      clk,
      vpage_copy_scanline_rd_ask,hscanline_rd_ready,vpage_copy_scanline_rd_page,
      vpage_copy_scanline_rd_x,vpage_copy_scanline_rd_y,hscanline_rd_pixel,

      vpage_copy_scanline_wr_ask,hscanline_wr_ready,vpage_copy_scanline_wr_page,
      vpage_copy_scanline_wr_x,vpage_copy_scanline_wr_y,vpage_copy_scanline_wr_pixel,
      
      vpage_copy_scanline_xmin, vpage_copy_scanline_xmax,
      
      vpage_copy_xmin,vpage_copy_ymin,vpage_copy_xmax,vpage_copy_ymax,
      
      vpage_copy_rd_page, vpage_copy_wr_page,

      vpage_copy_ask,vpage_copy_ready );

   noise_chip: noise_module port map (
      clk,
      noise_scanline_rd_ask,hscanline_rd_ready,noise_scanline_rd_page,
      noise_scanline_rd_x,noise_scanline_rd_y,hscanline_rd_pixel,

      noise_scanline_wr_ask,hscanline_wr_ready,noise_scanline_wr_page,
      noise_scanline_wr_x,noise_scanline_wr_y,noise_scanline_wr_pixel,
      
      noise_scanline_xmin,noise_scanline_xmax,

      noise_rd_page, noise_wr_page,

      noise(6 downto 0),noise_xmin,noise_ymin,noise_xmax,noise_ymax,
      noise_ask,noise_ready);

   median_chip: median_module port map (
      clk,
      median_scanline_rd_ask,hscanline_rd_ready,median_scanline_rd_page,
      median_scanline_rd_x,median_scanline_rd_y,hscanline_rd_pixel,

      median_scanline_wr_ask,hscanline_wr_ready,median_scanline_wr_page,
      median_scanline_wr_x,median_scanline_wr_y,median_scanline_wr_pixel,
      
      median_scanline_xmin,median_scanline_xmax,
      
      median_rd_page, median_wr_page,
      
      radius(3 downto 0),median_xmin,median_ymin,median_xmax,median_ymax,
      median_ask,median_ready);

      hscanline_rd_ask<=noise_scanline_rd_ask when noise_ask='1' else median_scanline_rd_ask when median_ask='1' else vpage_copy_scanline_rd_ask when vpage_copy_ask='1' else vpage_ccw_hscanline_rd_ask when vpage_ccw_ask='1' else '0';
      hscanline_rd_page<=noise_scanline_rd_page when noise_ask='1' else median_scanline_rd_page when median_ask='1' else vpage_copy_scanline_rd_page when vpage_copy_ask='1' else vpage_ccw_hscanline_rd_page when vpage_ccw_ask='1' else (others=>'0');
      hscanline_rd_x<=noise_scanline_rd_x when noise_ask='1' else median_scanline_rd_x when median_ask='1' else vpage_copy_scanline_rd_x when vpage_copy_ask='1' else vpage_ccw_hscanline_rd_x when vpage_ccw_ask='1' else (others=>'0');
      hscanline_rd_y<=noise_scanline_rd_y when noise_ask='1' else median_scanline_rd_y when median_ask='1' else vpage_copy_scanline_rd_y when vpage_copy_ask='1' else vpage_ccw_hscanline_rd_y when vpage_ccw_ask='1' else (others=>'0');

      hscanline_wr_ask<=noise_scanline_wr_ask when noise_ask='1' else median_scanline_wr_ask when median_ask='1' else vpage_copy_scanline_wr_ask when vpage_copy_ask='1' else '0';
      hscanline_wr_page<=noise_scanline_wr_page when noise_ask='1' else median_scanline_wr_page when median_ask='1' else vpage_copy_scanline_wr_page when vpage_copy_ask='1' else (others=>'0');
      hscanline_wr_x<=noise_scanline_wr_x when noise_ask='1' else median_scanline_wr_x when median_ask='1' else vpage_copy_scanline_wr_x when vpage_copy_ask='1' else (others=>'0');
      hscanline_wr_y<=noise_scanline_wr_y when noise_ask='1' else median_scanline_wr_y when median_ask='1' else vpage_copy_scanline_wr_y when vpage_copy_ask='1' else (others=>'0');
      hscanline_wr_pixel<=noise_scanline_wr_pixel when noise_ask='1' else median_scanline_wr_pixel when median_ask='1' else vpage_copy_scanline_wr_pixel when vpage_copy_ask='1' else (others=>'0');
      
      hscanline_xmin<=noise_scanline_xmin when noise_ask='1' else median_scanline_xmin when median_ask='1' else vpage_copy_scanline_xmin when vpage_copy_ask='1' else vpage_ccw_hscanline_xmin when vpage_ccw_ask='1' else (others=>'0');
      hscanline_xmax<=noise_scanline_xmax when noise_ask='1' else median_scanline_xmax when median_ask='1' else vpage_copy_scanline_xmax when vpage_copy_ask='1' else vpage_ccw_hscanline_xmax when vpage_ccw_ask='1' else (others=>'0');

      vscanline_wr_ask<=vpage_ccw_vscanline_wr_ask when vpage_ccw_ask='1' else '0';
      vscanline_wr_page<=vpage_ccw_vscanline_wr_page when vpage_ccw_ask='1' else (others=>'0');
      vscanline_wr_x<=vpage_ccw_vscanline_wr_x when vpage_ccw_ask='1' else (others=>'0');
      vscanline_wr_y<=vpage_ccw_vscanline_wr_y when vpage_ccw_ask='1' else (others=>'0');
      vscanline_wr_pixel<=vpage_ccw_vscanline_wr_pixel when vpage_ccw_ask='1' else (others=>'0');

      vscanline_ymin<=vpage_ccw_vscanline_ymin when vpage_ccw_ask='1' else (others=>'0');
      vscanline_ymax<=vpage_ccw_vscanline_ymax when vpage_ccw_ask='1' else (others=>'0');
      
   process(clk)
   begin
   if rising_edge(clk) then
   case fsm is
   when 0=>
      vpage_ccw_ask<='0';
      vpage_copy_ask<='0';
      noise_ask<='0';
      median_ask<='0';
      fsm<=1;
   when 1=> 
      vpage_ccw_rd_page<="0101"; vpage_ccw_wr_page<="0000";
      vpage_ccw_xmin<=conv_std_logic_vector(0,10);
      vpage_ccw_ymin<=conv_std_logic_vector(0,10);
      vpage_ccw_xmax<=conv_std_logic_vector(480,10);
      vpage_ccw_ymax<=conv_std_logic_vector(480,10);
      if vpage_ccw_ready='0' then vpage_ccw_ask<='1'; fsm<=2; end if;
   when 2=> if vpage_ccw_ready='1' then vpage_ccw_ask<='0'; fsm<=3; end if;

   when 3=> 
      vpage_copy_rd_page<="0001"; vpage_copy_wr_page<="0010";
      vpage_copy_xmin<=conv_std_logic_vector(0,10);
      vpage_copy_ymin<=conv_std_logic_vector(0,10);
      vpage_copy_xmax<=conv_std_logic_vector(480,10);
      vpage_copy_ymax<=conv_std_logic_vector(480,10);
      if vpage_copy_ready='0' then vpage_copy_ask<='1'; fsm<=4; end if;
   when 4=> if vpage_copy_ready='1' then vpage_copy_ask<='0'; fsm<=5; end if;
  
   when 5=>
      noise_rd_page<="0010"; noise_wr_page<="0011";
      if noise_ready='0' then noise_ask<='1'; fsm<=6; end if;
   when 6=> if noise_ready='1' then noise_ask<='0'; fsm<=7; end if; 
   
   when 7=>
      median_rd_page<="0011"; median_wr_page<="0100"; 
      if median_ready='0' then median_ask<='1'; fsm<=8; end if;
   when 8=> if median_ready='1' then median_ask<='0'; fsm<=9; end if;

   when 9=> 
      vpage_copy_rd_page<="0010"; vpage_copy_wr_page<="0101";
      vpage_copy_xmin<=conv_std_logic_vector(0,10);
      vpage_copy_ymin<=conv_std_logic_vector(0,10);
      vpage_copy_xmax<=conv_std_logic_vector(480,10);
      vpage_copy_ymax<=conv_std_logic_vector(480,10);
      if vpage_copy_ready='0' then vpage_copy_ask<='1'; fsm<=10; end if;
   when 10=> if vpage_copy_ready='1' then vpage_copy_ask<='0'; fsm<=11; end if;

   when 11=> 
      vpage_copy_rd_page<="0011"; vpage_copy_wr_page<="0101";
      vpage_copy_xmin<=noise_xmin;
      vpage_copy_ymin<=noise_ymin;
      vpage_copy_xmax<=noise_xmax;
      vpage_copy_ymax<=noise_ymax;
      if vpage_copy_ready='0' then vpage_copy_ask<='1'; fsm<=12; end if;
   when 12=> if vpage_copy_ready='1' then vpage_copy_ask<='0'; fsm<=13; end if;   

   when 13=> 
      vpage_copy_rd_page<="0100"; vpage_copy_wr_page<="0101";
      vpage_copy_xmin<=median_xmin;
      vpage_copy_ymin<=median_ymin;
      vpage_copy_xmax<=median_xmax;
      vpage_copy_ymax<=median_ymax;
      if vpage_copy_ready='0' then vpage_copy_ask<='1'; fsm<=14; end if;
   when 14=> if vpage_copy_ready='1' then vpage_copy_ask<='0'; fsm<=0; end if;
   
   when others=>null;
   end case;
   end if;
   end process;
end ax309;
