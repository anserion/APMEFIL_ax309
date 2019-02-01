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
-- Description: adaptive medain filter supervisor
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use ieee.std_logic_unsigned.all;

entity median_module is
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
end median_module;

architecture ax309 of median_module is
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
   
   signal fsm: natural range 0 to 255 := 0;
   signal x,y: std_logic_vector(9 downto 0):=(others=>'0');
   signal x_minus_2,x_minus_1,x_plus_1,x_plus_2: std_logic_vector(9 downto 0):=(others=>'0');
   
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
   
   signal pixel: std_logic_vector(15 downto 0):=(others=>'0');
	
	type pixel_array_type is array (0 to 24) of std_logic_vector(15 downto 0);
	signal i,n,nn,nn_div_2: integer range 0 to 25:=0;
	signal p,p_sorted,pp: pixel_array_type:=(others=>(others=>'0'));

   signal array9_in,array9_sorted: std_logic_vector(9*16-1 downto 0):=(others=>'0');
   signal array25_in,array25_sorted: std_logic_vector(25*16-1 downto 0):=(others=>'0');
   signal sort9_ask,sort9_ready: std_logic:='0';
   signal sort25_ask,sort25_ready: std_logic:='0';

	--signal tmp_pixel: std_logic_vector(15 downto 0):=(others=>'0');
   --signal j,nn_minus_1: integer range 0 to 127:=0;
begin
   scanline_rd_page<=source_vpage; scanline_wr_page<=target_vpage;
   scanline_xmin<=median_xmin; scanline_xmax<=median_xmax;
   
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
   begin
   if rising_edge(clk) then
   case fsm is
   --idle
   when 0=> 
      ready<='0';
      if ask='1' then fsm<=1; end if;
      
   -- some init manipulations
   when 1=>
      y<=median_ymin;      
      scanline_rd_ask<='0'; scanline_wr_ask<='0';
      if (scanline_rd_ready='0')and(scanline_wr_ready='0') then fsm<=2; end if;

   -- for y=noise_ymin to noise_ymax
   when 2=>
      if y=median_ymax then fsm<=255; else fsm<=3; end if;   
   
   --read scanline(y) from sdram
   when 3=> scanline_rd_y<=y; scanline_rd_ask<='1'; fsm<=4;
   when 4=> if scanline_rd_ready='1' then scanline_rd_ask<='0'; x<=median_xmin; fsm<=5; end if;
   --copy scanline(y) to scanline0
   when 5=> if x=median_xmax then
            if radius>0 then n<=5; fsm<=8; else n<=0; fsm<=32; end if;
            else scanline_rd_x<=x; fsm<=6;
            end if;
   when 6=> scanline0_wr_x<=x; scanline0_wr_pixel<=scanline_rd_pixel; fsm<=7;
   when 7=> x<=x+1; fsm<=5;

   --read scanline(y-1) from sdram
   when 8=> scanline_rd_y<=y-1; scanline_rd_ask<='1'; fsm<=9;
   when 9=> if scanline_rd_ready='1' then scanline_rd_ask<='0'; x<=median_xmin; fsm<=10; end if;
   --copy scanline(y-1) to scanline1
   when 10=> if x=median_xmax then fsm<=13;
             else scanline_rd_x<=x; fsm<=11;
             end if;
   when 11=> scanline1_wr_x<=x; scanline1_wr_pixel<=scanline_rd_pixel; fsm<=12;
   when 12=> x<=x+1; fsm<=10;

   --read scanline(y+1) from sdram
   when 13=> scanline_rd_y<=y+1; scanline_rd_ask<='1'; fsm<=14;
   when 14=> if scanline_rd_ready='1' then scanline_rd_ask<='0'; x<=median_xmin; fsm<=15; end if;
   --copy scanline(y+1) to scanline2
   when 15=> if x=median_xmax then
             if radius>1 then n<=25; fsm<=18; else n<=9; fsm<=32; end if;
             else scanline_rd_x<=x; fsm<=16;
             end if;
   when 16=> scanline2_wr_x<=x; scanline2_wr_pixel<=scanline_rd_pixel; fsm<=17;
   when 17=> x<=x+1; fsm<=15;

   --read scanline(y-2) from sdram
   when 18=> scanline_rd_y<=y-2; scanline_rd_ask<='1'; fsm<=19;
   when 19=> if scanline_rd_ready='1' then scanline_rd_ask<='0'; x<=median_xmin; fsm<=20; end if;
   --copy scanline(y-2) to scanline3
   when 20=> if x=median_xmax then fsm<=23;
             else scanline_rd_x<=x; fsm<=21;
             end if;
   when 21=> scanline3_wr_x<=x; scanline3_wr_pixel<=scanline_rd_pixel; fsm<=22;
   when 22=> x<=x+1; fsm<=20;

   --read scanline(y+2) from sdram
   when 23=> scanline_rd_y<=y+2; scanline_rd_ask<='1'; fsm<=24;
   when 24=> if scanline_rd_ready='1' then scanline_rd_ask<='0'; x<=median_xmin; fsm<=25; end if;
   --copy scanline(y+2) to scanline4
   when 25=> if x=median_xmax then n<=25; fsm<=32;
             else scanline_rd_x<=x; fsm<=26;
             end if;
   when 26=> scanline4_wr_x<=x; scanline4_wr_pixel<=scanline_rd_pixel; fsm<=27;
   when 27=> x<=x+1; fsm<=25;
   
   --filter pixels line(y)
   when 32=> x<=median_xmin; fsm<=33;
   when 33=>
      if x=median_xmax
      then fsm<=250;
      else
         x_minus_2<=x-2; x_minus_1<=x-1; 
         x_plus_2<=x+2; x_plus_1<=x+1; 
         fsm<=34;
      end if;
   --collect filter's points
   when 34=>
      scanline0_rd_x<=x;
      scanline1_rd_x<=x;
      scanline2_rd_x<=x;
      scanline3_rd_x<=x;
      scanline4_rd_x<=x;
      fsm<=35;
   when 35=>
      p(0)<=scanline0_rd_pixel;
      p(7)<=scanline1_rd_pixel;
      p(3)<=scanline2_rd_pixel;
      p(22)<=scanline3_rd_pixel;
      p(14)<=scanline4_rd_pixel;
      fsm<=36;
   when 36=> 
      scanline0_rd_x<=x_minus_1;
      scanline1_rd_x<=x_minus_1;
      scanline2_rd_x<=x_minus_1;
      scanline3_rd_x<=x_minus_1;
      scanline4_rd_x<=x_minus_1;
      fsm<=37;
   when 37=>
      p(5)<=scanline0_rd_pixel;
      p(6)<=scanline1_rd_pixel;
      p(4)<=scanline2_rd_pixel;
      p(21)<=scanline3_rd_pixel;
      p(15)<=scanline4_rd_pixel;
      fsm<=38;
   when 38=> 
      scanline0_rd_x<=x_plus_1;
      scanline1_rd_x<=x_plus_1;
      scanline2_rd_x<=x_plus_1;
      scanline3_rd_x<=x_plus_1;
      scanline4_rd_x<=x_plus_1;
      fsm<=39;
   when 39=>
      p(1)<=scanline0_rd_pixel;
      p(8)<=scanline1_rd_pixel;
      p(2)<=scanline2_rd_pixel;
      p(23)<=scanline3_rd_pixel;
      p(13)<=scanline4_rd_pixel;
      fsm<=40;

   when 40=> 
      scanline0_rd_x<=x_minus_2;
      scanline1_rd_x<=x_minus_2;
      scanline2_rd_x<=x_minus_2;
      scanline3_rd_x<=x_minus_2;
      scanline4_rd_x<=x_minus_2;
      fsm<=41;
   when 41=>
      p(18)<=scanline0_rd_pixel;
      p(19)<=scanline1_rd_pixel;
      p(17)<=scanline2_rd_pixel;
      p(20)<=scanline3_rd_pixel;
      p(16)<=scanline4_rd_pixel;
      fsm<=42;
   when 42=> 
      scanline0_rd_x<=x_plus_2;
      scanline1_rd_x<=x_plus_2;
      scanline2_rd_x<=x_plus_2;
      scanline3_rd_x<=x_plus_2;
      scanline4_rd_x<=x_plus_2;
      fsm<=43;
   when 43=>
      p(10)<=scanline0_rd_pixel;
      p(9)<=scanline1_rd_pixel;
      p(11)<=scanline2_rd_pixel;
      p(24)<=scanline3_rd_pixel;
      p(12)<=scanline4_rd_pixel;
      fsm<=48;

   ---------------------------------------
	--adaptive mediam filter's math section
	---------------------------------------
   when 48=> if (n/=0)and((p(0)=0)or(p(0)=255)) then fsm<=49; else pixel<=p(0); fsm<=126; end if;

   ------------------------
   -- quick method section
   ------------------------
   -- sort pixels
   when 49=>
      if (n=9) and (sort9_ready='0') then sort9_ask<='1'; fsm<=50;
      elsif (n=25) and (sort25_ready='0') then sort25_ask<='1'; fsm<=50;
      end if;
   when 50=>
      if (n=9) and (sort9_ready='1') then sort9_ask<='0'; fsm<=51;
      elsif (n=25) and (sort25_ready='1') then sort25_ask<='0'; fsm<=51;
      end if;
   when 51=>
      if n=9 then
         for k in 0 to 8 loop p_sorted(k)<=array9_sorted(k*16+15 downto k*16); end loop;
         fsm<=64;
      elsif n=25 then
         for k in 0 to 24 loop p_sorted(k)<=array25_sorted(k*16+15 downto k*16); end loop;
         fsm<=64;
      end if;
   
   -- exclude sault and pepper from p_sorted()
	when 64=> i<=0; nn<=0; fsm<=65;
	when 65=> if i=n then fsm<=69; else fsm<=66; end if;
	when 66=> if (p_sorted(i)=0)or(p_sorted(i)=255) then fsm<=68; else pp(nn)<=p_sorted(i); fsm<=67; end if;
	when 67=> nn<=nn+1; fsm<=68;
	when 68=> i<=i+1; fsm<=65;
	--trivial cases
	when 69=> if (nn=0)or(nn=1)or(nn=2) then pixel<=pp(0); fsm<=126; else fsm<=96; end if;
   -------------------------------
   -- end of quick method section
   -------------------------------

   ------------------------
   -- slow method section
   ------------------------
--	-- exclude sault and pepper from p()
--	when 49=> i<=0; nn<=0; fsm<=50;
--	when 50=> if i=n then fsm<=54; else fsm<=51; end if;
--	when 51=> if (p(i)=0)or(p(i)=255) then fsm<=53; else pp(nn)<=p(i); fsm<=52; end if;
--	when 52=> nn<=nn+1; fsm<=53;
--	when 53=> i<=i+1; fsm<=50;
--	--trivial cases
--	when 54=> if (nn=0)or(nn=1)or(nn=2) then pixel<=pp(0); fsm<=126; else fsm<=64; end if;
--	
--	-- very slow insert sort (fix it!!!)
--   when 64=> i<=0; nn_minus_1<=nn-1; fsm<=65;
--	when 65=> if i=nn_minus_1 then fsm<=96; else fsm<=66; end if;
--	when 66=> j<=i+1; fsm<=67;
--	when 67=> if j=nn then fsm<=73; else fsm<=68; end if;
--	when 68=> if pp(i)<pp(j) then fsm<=69; else fsm<=72; end if;
--	when 69=> tmp_pixel<=pp(i); fsm<=70;
--	when 70=> pp(i)<=pp(j); fsm<=71;
--	when 71=> pp(j)<=tmp_pixel; fsm<=72;
--	when 72=> j<=j+1; fsm<=67;
--	when 73=> i<=i+1; fsm<=65;
   -----------------------------
   -- end of slow method section
   -----------------------------
	
	-- select median element
	when 96=> nn_div_2<=conv_integer('0'&(conv_std_logic_vector(nn,7)(6 downto 1))); fsm<=97;
	when 97=> pixel<=pp(nn_div_2); fsm<=126;

   ----------------------------------------------
	--end of adaptive mediam filter's math section
	----------------------------------------------
	
   -- write pixel to output scanline
   when 126=> scanline_wr_x<=x; scanline_wr_pixel<="00000000"&pixel(7 downto 0); fsm<=127;
   -- x increment
   when 127=> x<=x+1; fsm<=33;
   
   -- write scanline(y) to SDRAM
   when 250=>
      scanline_wr_y<=y; scanline_wr_ask<='1'; fsm<=251;
   when 251=>
      if scanline_wr_ready='1' then scanline_wr_ask<='0'; fsm<=254; end if;
      
   -- y increment
   when 254=> y<=y+1; fsm<=2;

   -- next idle
   when 255=>
      scanline_wr_x<=(others=>'1');
      ready<='1';
      if ask='0' then fsm<=0; end if;
   when others=>null;
   end case;
   end if;
   end process;
end ax309;
