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
-- Description: sdram supervisor.
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity sdram_supervisor is

   Port ( 
      clk : in std_logic;
      en  : in std_logic;
      lcd_en    : in std_logic;
      cam_en    : in std_logic;

      sdram_rd_req   : out std_logic; 
      sdram_rd_valid : in std_logic;
      sdram_wr_req   : out std_logic;
      sdram_rd_addr  : out std_logic_vector(23 downto 0);
      sdram_wr_addr  : out std_logic_vector(23 downto 0);
      sdram_rd_data  : in std_logic_vector(15 downto 0);
      sdram_wr_data  : out std_logic_vector(15 downto 0);
      
      lcd_x_min : in std_logic_vector(9 downto 0);
      lcd_x_max : in std_logic_vector(9 downto 0);
      lcd_x     : out std_logic_vector(9 downto 0);
      lcd_y     : in std_logic_vector(9 downto 0);
      lcd_pixel : out std_logic_vector(15 downto 0);

      cam_x_min : in std_logic_vector(9 downto 0);
      cam_x_max : in std_logic_vector(9 downto 0);
      cam_x     : out std_logic_vector(9 downto 0);
      cam_y     : in std_logic_vector(9 downto 0);
      cam_pixel : in std_logic_vector(15 downto 0);
      
      h_scanline_rd_ask   : in std_logic;
      h_scanline_rd_ready : out std_logic;
      h_scanline_rd_x     : out std_logic_vector(9 downto 0);
      h_scanline_rd_y     : in std_logic_vector(9 downto 0);
      h_scanline_rd_page  : in std_logic_vector(3 downto 0);
      h_scanline_rd_pixel : out std_logic_vector(15 downto 0);

      h_scanline_wr_ask   : in std_logic;
      h_scanline_wr_ready : out std_logic;
      h_scanline_wr_x     : out std_logic_vector(9 downto 0);
      h_scanline_wr_y     : in std_logic_vector(9 downto 0);
      h_scanline_wr_page  : in std_logic_vector(3 downto 0);
      h_scanline_wr_pixel : in std_logic_vector(15 downto 0);
      
      h_scanline_x_min : in std_logic_vector(9 downto 0);
      h_scanline_x_max : in std_logic_vector(9 downto 0);

      v_scanline_rd_ask   : in std_logic;
      v_scanline_rd_ready : out std_logic;
      v_scanline_rd_x     : in std_logic_vector(9 downto 0);
      v_scanline_rd_y     : out std_logic_vector(9 downto 0);
      v_scanline_rd_page  : in std_logic_vector(3 downto 0);
      v_scanline_rd_pixel : out std_logic_vector(15 downto 0);
      
      v_scanline_wr_ask   : in std_logic;
      v_scanline_wr_ready : out std_logic;
      v_scanline_wr_x     : in std_logic_vector(9 downto 0);
      v_scanline_wr_y     : out std_logic_vector(9 downto 0);
      v_scanline_wr_page  : in std_logic_vector(3 downto 0);
      v_scanline_wr_pixel : in std_logic_vector(15 downto 0);
      
      v_scanline_y_min : in std_logic_vector(9 downto 0);
      v_scanline_y_max : in std_logic_vector(9 downto 0);
      
      cpu_mem_ask: in std_logic;
      cpu_mem_ready: out std_logic;
      cpu_mem_wr_en: in std_logic;
      cpu_mem_addr : in std_logic_vector(23 downto 0);
      cpu_mem_wr_data: in std_logic_vector(15 downto 0);
      cpu_mem_rd_data: out std_logic_vector(15 downto 0)
	);
end sdram_supervisor;

architecture ax309 of sdram_supervisor is
   signal fsm: natural range 0 to 63 := 0;
   signal sdram_x : std_logic_vector(9 downto 0) := (others => '0');
   signal sdram_y : std_logic_vector(9 downto 0) := (others => '0');
   signal cam_parity, lcd_parity: std_logic:='0';
   signal cpu_mem_ready_reg: std_logic:='0';
   signal h_scanline_rd_ready_reg: std_logic:='0';
   signal h_scanline_wr_ready_reg: std_logic:='0';
   signal v_scanline_rd_ready_reg: std_logic:='0';
   signal v_scanline_wr_ready_reg: std_logic:='0';
begin
   cpu_mem_ready<=cpu_mem_ready_reg;
   h_scanline_rd_ready<=h_scanline_rd_ready_reg;
   h_scanline_wr_ready<=h_scanline_wr_ready_reg;
   v_scanline_rd_ready<=v_scanline_rd_ready_reg;
   v_scanline_wr_ready<=v_scanline_wr_ready_reg;
   process(clk)
   begin
      if rising_edge(clk) and en='1' then
         case fsm is
         when 0=> fsm<=1; --reserved
         when 1=> fsm<=2; --reserved
         when 2=> fsm<=3; --reserved
         -----------------------------------------
         -- SDRAM to LCD device section
         -----------------------------------------
         when 3 => 
            if lcd_en='1' and lcd_y(0)=lcd_parity
            then
               lcd_parity<=not(lcd_parity);
               sdram_x<=lcd_x_min;
               sdram_y<=lcd_y;
               sdram_rd_req<='1';
               sdram_wr_req<='0';
               fsm<=4;
            else fsm <= 8;
            end if;
         when 4 =>
            if sdram_x=lcd_x_max
            then
               sdram_rd_req<='0';
               sdram_wr_req<='0';
               fsm<=8;
            else
               sdram_rd_addr <= "00" & "00" & sdram_y & sdram_x;
               fsm<=5;
            end if;
         when 5 =>
            if sdram_rd_valid='1' then
               lcd_x<=sdram_x;
               lcd_pixel<=sdram_rd_data;
               fsm<=6;
            end if;
         when 6=> sdram_x<=sdram_x+1; fsm<=4;
         -----------------------------------------
         -- end of SDRAM to LCD section
         -----------------------------------------

         -----------------------------------------
         -- CAMERA to SDRAM device section
         -----------------------------------------
         when 8 => 
            if cam_en='1' and cam_y(0)=cam_parity
            then
               cam_parity<=not(cam_parity);
               sdram_x<=cam_x_min;
               sdram_y<=cam_y;
               sdram_rd_req<='0';
               sdram_wr_req<='1';
               fsm<=9;
            else fsm <= 16;
            end if;
         when 9 =>
            if sdram_x=cam_x_max
            then
               sdram_rd_req<='0';
               sdram_wr_req<='0';
               fsm<=16;
            else
               cam_x<=sdram_x;
               sdram_wr_addr <= "00" & "01" & sdram_y & sdram_x;
               sdram_wr_data <= 
               cam_pixel;
               fsm<=10;
            end if;
         when 10 => fsm<=11;
         when 11 => fsm<=12;
         when 12 => sdram_x<=sdram_x+1; fsm<=9;
         -----------------------------------------
         -- end of CAMERA to SDRAM section
         -----------------------------------------

         -----------------------------------------
         -- h_scanline to SDRAM device section
         -----------------------------------------
         when 16 => 
            if h_scanline_wr_ask='0' then h_scanline_wr_ready_reg<='0'; fsm<=24;
            elsif (h_scanline_wr_ask='1')and(h_scanline_wr_ready_reg='0')
            then fsm<=17;
            else fsm<=24;
            end if;
         when 17 =>
            sdram_x<=h_scanline_x_min;
            sdram_y<=h_scanline_wr_y;
            sdram_rd_req<='0';
            sdram_wr_req<='1';
            fsm<=18;
         when 18 =>
            if sdram_x=h_scanline_x_max
            then
               sdram_rd_req<='0';
               sdram_wr_req<='0';
               h_scanline_wr_ready_reg<='1';
               fsm<=24;
            else
               h_scanline_wr_x<=sdram_x;
               sdram_wr_addr <= h_scanline_wr_page & sdram_y & sdram_x;
               sdram_wr_data <= h_scanline_wr_pixel;
               fsm<=19;
            end if;
         when 19 => fsm<=20;
         when 20 => fsm<=21;
         when 21 => sdram_x<=sdram_x+1; fsm<=18;
         -----------------------------------------
         -- end of h_scanline to SDRAM section
         -----------------------------------------

         -----------------------------------------
         -- SDRAM to h_scanline device section
         -----------------------------------------
         when 24 => 
            if h_scanline_rd_ask='0' then h_scanline_rd_ready_reg<='0'; fsm<=32;
            elsif (h_scanline_rd_ask='1')and(h_scanline_rd_ready_reg='0')
            then fsm<=25;
            else fsm<=32;
            end if;
         when 25 => 
            sdram_x<=h_scanline_x_min;
            sdram_y<=h_scanline_rd_y;
            sdram_rd_req<='1';
            sdram_wr_req<='0';
            fsm<=26;
         when 26 =>
            if sdram_x=h_scanline_x_max
            then
               sdram_rd_req<='0';
               sdram_wr_req<='0';
               h_scanline_rd_ready_reg<='1';
               fsm<=32;
            else
               sdram_rd_addr <= h_scanline_rd_page & sdram_y & sdram_x;
               fsm<=27;
            end if;
         when 27 =>
            if sdram_rd_valid='1' then
               h_scanline_rd_x<=sdram_x;
               h_scanline_rd_pixel<=sdram_rd_data;
               fsm<=28;
            end if;
         when 28 => sdram_x<=sdram_x+1; fsm<=26;
         -----------------------------------------
         -- end of SDRAM to h_scanline section
         -----------------------------------------

         -----------------------------------------
         -- v_scanline to SDRAM device section
         -----------------------------------------
         when 32 => 
            if v_scanline_wr_ask='0' then v_scanline_wr_ready_reg<='0'; fsm<=40;
            elsif (v_scanline_wr_ask='1')and(v_scanline_wr_ready_reg='0')
            then fsm<=33;
            else fsm<=40;
            end if;
         when 33 =>
            sdram_x<=v_scanline_wr_x;
            sdram_y<=v_scanline_y_min;
            sdram_rd_req<='0';
            sdram_wr_req<='1';
            fsm<=34;
         when 34 =>
            if sdram_y=v_scanline_y_max
            then
               sdram_rd_req<='0';
               sdram_wr_req<='0';
               v_scanline_wr_ready_reg<='1';
               fsm<=40;
            else
               v_scanline_wr_y<=sdram_y;
               sdram_wr_addr <= v_scanline_wr_page & sdram_y & sdram_x;
               sdram_wr_data <= v_scanline_wr_pixel;
               fsm<=35;
            end if;
         when 35 => fsm<=36;
         when 36 => fsm<=37;
         when 37 => sdram_y<=sdram_y+1; fsm<=34;
         -----------------------------------------
         -- end of v_scanline to SDRAM section
         -----------------------------------------

         -----------------------------------------
         -- SDRAM to v_scanline device section
         -----------------------------------------
         when 40 => 
            if v_scanline_rd_ask='0' then v_scanline_rd_ready_reg<='0'; fsm<=48;
            elsif (v_scanline_rd_ask='1')and(v_scanline_rd_ready_reg='0')
            then fsm<=41;
            else fsm<=48;
            end if;
         when 41 => 
            sdram_x<=v_scanline_rd_x;
            sdram_y<=v_scanline_y_min;
            sdram_rd_req<='1';
            sdram_wr_req<='0';
            fsm<=42;
         when 42 =>
            if sdram_y=v_scanline_y_max
            then
               sdram_rd_req<='0';
               sdram_wr_req<='0';
               v_scanline_rd_ready_reg<='1';
               fsm<=48;
            else
               sdram_rd_addr <= v_scanline_rd_page & sdram_y & sdram_x;
               fsm<=43;
            end if;
         when 43 =>
            if sdram_rd_valid='1' then
               v_scanline_rd_y<=sdram_y;
               v_scanline_rd_pixel<=sdram_rd_data;
               fsm<=44;
            end if;
         when 44 => sdram_y<=sdram_y+1; fsm<=42;
         -----------------------------------------
         -- end of SDRAM to v_scanline section
         -----------------------------------------
         
         -----------------------------------------
         -- CPU <--> SDRAM section
         -----------------------------------------
         when 48 =>
            if cpu_mem_ask='0' then cpu_mem_ready_reg<='0'; fsm<=0;
            elsif (cpu_mem_ask='1')and(cpu_mem_ready_reg='0')
            then fsm<=49;
            else fsm<=0;
            end if;
         when 49 =>
               if cpu_mem_wr_en='0' then
                  sdram_rd_req<='1';
                  sdram_wr_req<='0';
                  sdram_rd_addr <= cpu_mem_addr;
                  fsm <= 50;
               else 
                  sdram_rd_req<='0';
                  sdram_wr_req<='1';
                  sdram_wr_addr <= cpu_mem_addr;
                  sdram_wr_data <= cpu_mem_wr_data;
                  fsm <= 51;
               end if;
         when 50 =>
            if sdram_rd_valid='1' then 
               cpu_mem_rd_data<=sdram_rd_data;
               fsm<=53;
            end if;
         when 51 => fsm<=52;
         when 52 => fsm<=53;
         when 53 => 
            sdram_rd_req<='0';
            sdram_wr_req<='0';
            cpu_mem_ready_reg<='1';
            fsm<=0;
         -----------------------------------------
         -- end of CPU <--> SDRAM section
         -----------------------------------------

         when others => null;
         end case;
      end if;
   end process;
end;

