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
-- Description: multiple filter's design
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use ieee.std_logic_unsigned.all;

entity filter_module is
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
end filter_module;

architecture ax309 of filter_module is
   constant filter_mode_COPY: std_logic_vector(2 downto 0):="000";
   constant filter_mode_CCW: std_logic_vector(2 downto 0):="001";
   constant filter_mode_CW: std_logic_vector(2 downto 0):="010";
   constant filter_mode_NOISE: std_logic_vector(2 downto 0):="100";
   constant filter_mode_SMF: std_logic_vector(2 downto 0):="101";
   constant filter_mode_AMF: std_logic_vector(2 downto 0):="110";
   
   component vram_scanline
   port (
    clka : IN STD_LOGIC;
    wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    addra : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
    dina : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    clkb : IN STD_LOGIC;
    addrb : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
    doutb : OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
   );
   end component;
   signal scanline0_wr_x,scanline0_rd_x: std_logic_vector(9 downto 0):=(others=>'0');
   signal scanline1_wr_x,scanline1_rd_x: std_logic_vector(9 downto 0):=(others=>'0');
   signal scanline2_wr_x,scanline2_rd_x: std_logic_vector(9 downto 0):=(others=>'0');
   signal scanline3_wr_x,scanline3_rd_x: std_logic_vector(9 downto 0):=(others=>'0');
   signal scanline4_wr_x,scanline4_rd_x: std_logic_vector(9 downto 0):=(others=>'0');
   
   signal scanline0_wr_pixel,scanline0_rd_pixel: std_logic_vector(15 downto 0):=(others=>'0');
   signal scanline1_wr_pixel,scanline1_rd_pixel: std_logic_vector(15 downto 0):=(others=>'0');
   signal scanline2_wr_pixel,scanline2_rd_pixel: std_logic_vector(15 downto 0):=(others=>'0');
   signal scanline3_wr_pixel,scanline3_rd_pixel: std_logic_vector(15 downto 0):=(others=>'0');
   signal scanline4_wr_pixel,scanline4_rd_pixel: std_logic_vector(15 downto 0):=(others=>'0');

   component sort_module is
    Generic (n: integer:=25);
    Port ( 
		clk          : in std_logic;
      ask          : in std_logic;
      ready        : out std_logic;
      array_in     : in std_logic_vector(n*16-1 downto 0);
      array_sorted : out std_logic_vector(n*16-1 downto 0)
	 );
   end component;
   signal array9_in,array9_sorted: std_logic_vector(9*16-1 downto 0):=(others=>'0');
   signal array25_in,array25_sorted: std_logic_vector(25*16-1 downto 0):=(others=>'0');
   signal sort9_ask,sort9_ready: std_logic:='0';
   signal sort25_ask,sort25_ready: std_logic:='0';

   component rnd16_module is
   Generic (seed:STD_LOGIC_VECTOR(31 downto 0));
   Port (clk: in  STD_LOGIC; rnd16: out STD_LOGIC_VECTOR(15 downto 0) );
   end component;
   signal rnd16: std_logic_vector(15 downto 0):=(others=>'0');
   signal noise_level_17bit:std_logic_vector(16 downto 0):=(others=>'0');
   
   type pixel_array_type is array (0 to 24) of std_logic_vector(15 downto 0);
	signal p,p_sorted,pp: pixel_array_type:=(others=>(others=>'0'));
begin
   rnd16_chip: rnd16_module generic map (conv_std_logic_vector(26535,32)) port map(clk,rnd16);
   
   scanline0: vram_scanline PORT MAP (clk,(0=>'1'),scanline0_wr_x,scanline0_wr_pixel,clk,scanline0_rd_x,scanline0_rd_pixel);
   scanline1: vram_scanline PORT MAP (clk,(0=>'1'),scanline1_wr_x,scanline1_wr_pixel,clk,scanline1_rd_x,scanline1_rd_pixel);
   scanline2: vram_scanline PORT MAP (clk,(0=>'1'),scanline2_wr_x,scanline2_wr_pixel,clk,scanline2_rd_x,scanline2_rd_pixel);
   scanline3: vram_scanline PORT MAP (clk,(0=>'1'),scanline3_wr_x,scanline3_wr_pixel,clk,scanline3_rd_x,scanline3_rd_pixel);
   scanline4: vram_scanline PORT MAP (clk,(0=>'1'),scanline4_wr_x,scanline4_wr_pixel,clk,scanline4_rd_x,scanline4_rd_pixel);
   
   gen_array9_links:
   for k in 0 to 8 generate array9_in(k*16+15 downto k*16)<=p(k); end generate;

   sort9_chip: sort_module generic map (n=>9)
      port map (
         clk=>clk,
         ask=>sort9_ask,
         ready=>sort9_ready,
         array_in=>array9_in,
         array_sorted=>array9_sorted
      );

   gen_array25_links:
   for k in 0 to 24 generate array25_in(k*16+15 downto k*16)<=p(k); end generate;

   sort25_chip: sort_module generic map (n=>25)
      port map (
         clk=>clk,
         ask=>sort25_ask,
         ready=>sort25_ready,
         array_in=>array25_in,
         array_sorted=>array25_sorted
      );

   process(clk)
   variable fsm: natural range 0 to 255 := 0;
   variable x,y: std_logic_vector(9 downto 0):=(others=>'0');
	variable i,n,nn,nn_div_2: integer range 0 to 25:=0;
   variable x_minus_2,x_minus_1,x_plus_1,x_plus_2: std_logic_vector(9 downto 0):=(others=>'0');
   variable pixel: std_logic_vector(15 downto 0):=(others=>'0');
  
   begin
   if rising_edge(clk) then
   case fsm is
   --idle
   when 0=> 
      hscanline_rd_ask<='0'; hscanline_wr_ask<='0';
      vscanline_rd_ask<='0'; vscanline_wr_ask<='0';
      noise_level_17bit<=noise * conv_std_logic_vector(655,10);
      ready<='0';
      if (ask='1')and
         (hscanline_rd_ready='0')and(hscanline_wr_ready='0')and
         (vscanline_rd_ready='0')and(vscanline_wr_ready='0')
      then fsm:=1;
      end if;

   -- for y=filter_ymin to filter_ymax
   when 1=> y:=filter_ymin; fsm:=2;
   
   --read hscanline(y) from sdram
   when 2=>
      hscanline_rd_y<=y;
      if hscanline_rd_ready='0' then hscanline_rd_ask<='1'; fsm:=3; end if;
   when 3=> if hscanline_rd_ready='1' then hscanline_rd_ask<='0'; fsm:=4; end if;
   
   -- check for a COPY filter mode
   when 4=> if filter_mode=filter_mode_COPY then x:=filter_xmin; fsm:=5; else fsm:=8; end if;
   when 5=> hscanline_rd_x<=x; fsm:=6;
   when 6=>
      hscanline_wr_x<=x;
      hscanline_wr_pixel<=hscanline_rd_pixel;
      fsm:=7;
   when 7=> if x=filter_xmax then fsm:=250; else x:=x+1; fsm:=5; end if;
   
   -- check for a CCW filter mode
   when 8=> if filter_mode=filter_mode_CCW then x:=filter_xmax; fsm:=9; else fsm:=12; end if;
   when 9=> hscanline_rd_x<=x; fsm:=10;
   when 10=>
      vscanline_wr_y<=filter_xmax-x;
      vscanline_wr_pixel<=hscanline_rd_pixel;
      fsm:=11;
   when 11=> if x=filter_xmin then x:=y; fsm:=252; else x:=x-1; fsm:=9; end if;

   -- check for a CW filter mode
   when 12=> if filter_mode=filter_mode_CW then x:=filter_xmin; fsm:=13; else fsm:=16; end if;
   when 13=> hscanline_rd_x<=x; fsm:=14;
   when 14=>
      vscanline_wr_y<=x;
      vscanline_wr_pixel<=hscanline_rd_pixel;
      fsm:=15;
   when 15=> if x=filter_xmax then x:=filter_xmax-y; fsm:=252; else x:=x+1; fsm:=13; end if;
   
   -- check for a NOISE filter mode
   when 16=> if filter_mode=filter_mode_NOISE then x:=filter_xmin; fsm:=17; else fsm:=20; end if;
   when 17=> hscanline_rd_x<=x; fsm:=18;
   when 18=> 
      hscanline_wr_x<=x;
      if rnd16<noise_level_17bit(15 downto 0)
      then hscanline_wr_pixel<="00000000"&
                rnd16(0)&rnd16(0)&rnd16(0)&rnd16(0)&
                rnd16(0)&rnd16(0)&rnd16(0)&rnd16(0);
      else hscanline_wr_pixel<=hscanline_rd_pixel;
      end if;
      fsm:=19;
   when 19=> if x=filter_xmax then fsm:=250; else x:=x+1; fsm:=17; end if;
   
   --check for STANDARD MEDIAN FILTER (SMF) or ADAPTIVE MEDIAN FILTER (AMF) modes
   when 20=>
      if (filter_mode=filter_mode_SMF)or(filter_mode=filter_mode_AMF)
      then if radius=0 then x:=filter_xmin; fsm:=5; else fsm:=32; end if;
      else fsm:=254;
      end if;
   
   ---------------------------------------------
   -- MEDIAN and ADAPTIVE MEDIAN filters section
   ---------------------------------------------
   -- scanline3 - y-2
   -- scanline1 - y-1
   -- scanline0 - y
   -- scanline2 - y+1
   -- scanline4 - y+2
   
   -- shift up content of all scanlines, scanline4 fill from hscanline(y)
   when 32=>x:=filter_xmin; fsm:=33;
   when 33=>
      scanline0_rd_x<=x;
      scanline1_rd_x<=x;
      scanline2_rd_x<=x;
      scanline3_rd_x<=x;
      scanline4_rd_x<=x;
      hscanline_rd_x<=x;
      fsm:=34;
   when 34=> scanline3_wr_x<=x; scanline3_wr_pixel<=scanline1_rd_pixel; fsm:=35;
   when 35=> scanline1_wr_x<=x; scanline1_wr_pixel<=scanline0_rd_pixel; fsm:=36;
   when 36=> scanline0_wr_x<=x; scanline0_wr_pixel<=scanline2_rd_pixel; fsm:=37;
   when 37=> scanline2_wr_x<=x; scanline2_wr_pixel<=scanline4_rd_pixel; fsm:=38;
   when 38=> scanline4_wr_x<=x; scanline4_wr_pixel<=hscanline_rd_pixel; fsm:=39;
   when 39=>if x=filter_xmax then fsm:=40; else x:=x+1; fsm:=33; end if;
   when 40=>
      fsm:=64;
      if radius=1 then n:=9;
      elsif radius=2 then n:=25;
      else n:=25;
      end if;
   
   --filter pixels from line(y)
   when 64=> x:=filter_xmin; fsm:=65;
   when 65=>
      x_minus_2:=x-2; x_minus_1:=x-1;
      x_plus_2:=x+2; x_plus_1:=x+1; 
      fsm:=66;

   --collect filter's points
   when 66=>
      scanline0_rd_x<=x;
      scanline1_rd_x<=x;
      scanline2_rd_x<=x;
      scanline3_rd_x<=x;
      scanline4_rd_x<=x;
      fsm:=67;
   when 67=>
      p(0)<=scanline0_rd_pixel;
      p(7)<=scanline1_rd_pixel;
      p(3)<=scanline2_rd_pixel;
      p(22)<=scanline3_rd_pixel;
      p(14)<=scanline4_rd_pixel;
      fsm:=68;
   when 68=> 
      scanline0_rd_x<=x_minus_1;
      scanline1_rd_x<=x_minus_1;
      scanline2_rd_x<=x_minus_1;
      scanline3_rd_x<=x_minus_1;
      scanline4_rd_x<=x_minus_1;
      fsm:=69;
   when 69=>
      p(5)<=scanline0_rd_pixel;
      p(6)<=scanline1_rd_pixel;
      p(4)<=scanline2_rd_pixel;
      p(21)<=scanline3_rd_pixel;
      p(15)<=scanline4_rd_pixel;
      fsm:=70;
   when 70=> 
      scanline0_rd_x<=x_plus_1;
      scanline1_rd_x<=x_plus_1;
      scanline2_rd_x<=x_plus_1;
      scanline3_rd_x<=x_plus_1;
      scanline4_rd_x<=x_plus_1;
      fsm:=71;
   when 71=>
      p(1)<=scanline0_rd_pixel;
      p(8)<=scanline1_rd_pixel;
      p(2)<=scanline2_rd_pixel;
      p(23)<=scanline3_rd_pixel;
      p(13)<=scanline4_rd_pixel;
      fsm:=72;
   when 72=> 
      scanline0_rd_x<=x_minus_2;
      scanline1_rd_x<=x_minus_2;
      scanline2_rd_x<=x_minus_2;
      scanline3_rd_x<=x_minus_2;
      scanline4_rd_x<=x_minus_2;
      fsm:=73;
   when 73=>
      p(18)<=scanline0_rd_pixel;
      p(19)<=scanline1_rd_pixel;
      p(17)<=scanline2_rd_pixel;
      p(20)<=scanline3_rd_pixel;
      p(16)<=scanline4_rd_pixel;
      fsm:=74;
   when 74=> 
      scanline0_rd_x<=x_plus_2;
      scanline1_rd_x<=x_plus_2;
      scanline2_rd_x<=x_plus_2;
      scanline3_rd_x<=x_plus_2;
      scanline4_rd_x<=x_plus_2;
      fsm:=75;
   when 75=>
      p(10)<=scanline0_rd_pixel;
      p(9)<=scanline1_rd_pixel;
      p(11)<=scanline2_rd_pixel;
      p(24)<=scanline3_rd_pixel;
      p(12)<=scanline4_rd_pixel;
      fsm:=80;   

   ---------------------------------------
	--median filter's math section
	---------------------------------------
   when 80=>
      if filter_mode=filter_mode_SMF
      then fsm:=81;
      else
         if (p(0)=0)or(p(0)=255) then fsm:=81; else pixel:=p(0); fsm:=126; end if;
      end if;

   -- sort pixels
   when 81=>
      if (n=9) and (sort9_ready='0') then sort9_ask<='1'; fsm:=82;
      elsif (n=25) and (sort25_ready='0') then sort25_ask<='1'; fsm:=82;
      end if;
   when 82=>
      if (n=9) and (sort9_ready='1') then sort9_ask<='0'; fsm:=83;
      elsif (n=25) and (sort25_ready='1') then sort25_ask<='0'; fsm:=83;
      end if;
   when 83=>
      if n=9 then
         for k in 0 to 8 loop p_sorted(k)<=array9_sorted(k*16+15 downto k*16); end loop;
         fsm:=90;
      elsif n=25 then
         for k in 0 to 24 loop p_sorted(k)<=array25_sorted(k*16+15 downto k*16); end loop;
         fsm:=90;
      end if;

   when 88=> if filter_mode=filter_mode_SMF then nn:=n; fsm:=96; else fsm:=90; end if;
   
	-- exclude sault and pepper from p_sorted()
   when 90=> i:=0; nn:=0; fsm:=91;
	when 91=> if i=n then fsm:=95; else fsm:=92; end if;
	when 92=> if (p_sorted(i)=0)or(p_sorted(i)=255) then fsm:=94; else pp(nn)<=p_sorted(i); fsm:=93; end if;
	when 93=> nn:=nn+1; fsm:=94;
	when 94=> i:=i+1; fsm:=91;
	--trivial cases
	when 95=> if (nn=0)or(nn=1)or(nn=2) then pixel:=pp(0); fsm:=126; else fsm:=96; end if;

	-- select median element
	when 96=> nn_div_2:=conv_integer('0'&(conv_std_logic_vector(nn,7)(6 downto 1))); fsm:=97;
	when 97=>
      if filter_mode=filter_mode_SMF
      then pixel:=p_sorted(nn_div_2);
      else pixel:=pp(nn_div_2);
      end if;
      fsm:=126;
   ---------------------------------------
	--end of median filter's math section
	---------------------------------------

   -- write pixel to output scanline
   when 126=> hscanline_wr_x<=x; hscanline_wr_pixel<="00000000"&pixel(7 downto 0); fsm:=127;
   -- end of x loop
   when 127=> if x=filter_xmax then fsm:=250; else x:=x+1; fsm:=65; end if;
   ----------------------------------------------------
   -- end of MEDIAN and ADAPTIVE MEDIAN filters section
   ----------------------------------------------------
      
   -- write hscanline(y) to SDRAM
   when 250=>
      hscanline_wr_y<=y;
      if hscanline_wr_ready='0' then hscanline_wr_ask<='1'; fsm:=251; end if;
   when 251=> if hscanline_wr_ready='1' then hscanline_wr_ask<='0'; fsm:=254; end if;

   -- write vscanline(x) to SDRAM
   when 252=>
      vscanline_wr_x<=x;
      if vscanline_wr_ready='0' then vscanline_wr_ask<='1'; fsm:=253; end if;
   when 253=> if vscanline_wr_ready='1' then vscanline_wr_ask<='0'; fsm:=254; end if;
      
   -- end of y loop
   when 254=> if y=filter_ymax then fsm:=255; else y:=y+1; fsm:=2; end if;
   
   -- next idle
   when 255=>
      ready<='1';
      if ask='0' then fsm:=0; end if;
   when others=>null;
   end case;
   end if;
   end process;
end ax309;
