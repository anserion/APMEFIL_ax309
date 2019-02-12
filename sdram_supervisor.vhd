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
      low_priority_en: in std_logic;
      
      sdram_precharge_latency: out std_logic_vector(1 downto 0);
      sdram_activate_row_latency: out std_logic_vector(1 downto 0);     

      sdram_ask    : out std_logic;
      sdram_ready  : in std_logic;
      sdram_wr_en  : out std_logic;
      sdram_addr   : out std_logic_vector(23 downto 0);
      sdram_wr_data: out std_logic_vector(15 downto 0);
      sdram_rd_data: in std_logic_vector(15 downto 0);

      sdram_scanline_ask   : out std_logic;
      sdram_scanline_addr  : in std_logic_vector(23 downto 0);
      
      sdram_scanline_addr_start: out std_logic_vector(23 downto 0);
      sdram_scanline_addr_nums : out std_logic_vector(23 downto 0);
      sdram_scanline_addr_delta: out std_logic_vector(23 downto 0);
      
      video_ask   : in std_logic;
      video_ready : out std_logic;
      video_x_min : in std_logic_vector(9 downto 0);
      video_x_max : in std_logic_vector(9 downto 0);
      video_x     : out std_logic_vector(9 downto 0);
      video_y     : in std_logic_vector(9 downto 0);
      video_pixel : out std_logic_vector(15 downto 0);

      cam_ask   : in std_logic;
      cam_ready : out std_logic;
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
      h_scanline_rd_pixel  : out std_logic_vector(15 downto 0);

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
   signal video_ready_reg: std_logic:='0';
   signal cam_ready_reg: std_logic:='0';
   signal cpu_mem_ready_reg: std_logic:='0';
   signal h_scanline_rd_ready_reg: std_logic:='0';
   signal h_scanline_wr_ready_reg: std_logic:='0';
   signal v_scanline_rd_ready_reg: std_logic:='0';
   signal v_scanline_wr_ready_reg: std_logic:='0';
begin
   sdram_precharge_latency<="11";
   sdram_activate_row_latency<="11";

   video_ready<=video_ready_reg;
   cam_ready<=cam_ready_reg;
   cpu_mem_ready<=cpu_mem_ready_reg;
   h_scanline_rd_ready<=h_scanline_rd_ready_reg;
   h_scanline_wr_ready<=h_scanline_wr_ready_reg;
   v_scanline_rd_ready<=v_scanline_rd_ready_reg;
   v_scanline_wr_ready<=v_scanline_wr_ready_reg;
   process(clk)
   begin
      if rising_edge(clk) then
         case fsm is
         when 0=> if en='1' then fsm<=1; end if;
         when 1=>
            sdram_ask<='0'; sdram_scanline_ask<='0'; sdram_wr_en<='0';
            if sdram_ready='0' then fsm<=2; end if;
         when 2=> fsm<=3; --reserved
         -----------------------------------------
         -- SDRAM to VIDEO device section
         -----------------------------------------
         when 3 => 
            if video_ask='0'
            then video_ready_reg<='0'; fsm<=8;
            elsif (video_ask='1')and(video_ready_reg='0')
            then
               sdram_ask<='0'; sdram_scanline_ask<='0'; sdram_wr_en<='0';
               sdram_scanline_addr_start<="00" & "00" & video_y & video_x_min;
               sdram_scanline_addr_delta<=conv_std_logic_vector(1,24);
               sdram_scanline_addr_nums<=conv_std_logic_vector(conv_integer(video_x_max-video_x_min),24);
               fsm<=4;
            else fsm <= 8;
            end if;
         when 4 => if sdram_ready='0' then sdram_scanline_ask<='1'; fsm<=5; end if;
         when 5 =>
            video_x <= sdram_scanline_addr(9 downto 0);
            video_pixel <= sdram_rd_data;
            if sdram_ready='1' then
               sdram_scanline_ask<='0';
               video_ready_reg<='1';
               video_x<=(others=>'1');
               fsm<=8;
            end if;
         -----------------------------------------
         -- end of SDRAM to VIDEO section
         -----------------------------------------

         -----------------------------------------
         -- CAMERA to SDRAM device section
         -----------------------------------------
         when 8 => 
            if cam_ask='0'
            then cam_ready_reg<='0'; if low_priority_en='1' then fsm<=16; else fsm<=0; end if;
            elsif (cam_ask='1')and(cam_ready_reg='0')
            then
               sdram_ask<='0'; sdram_scanline_ask<='0'; sdram_wr_en<='1';
               sdram_scanline_addr_start<="00" & "01" & cam_y & cam_x_min;
               sdram_scanline_addr_delta<=conv_std_logic_vector(1,24);
               sdram_scanline_addr_nums<=conv_std_logic_vector(conv_integer(cam_x_max-cam_x_min),24);
               fsm<=9;
            else if low_priority_en='1' then fsm<=16; else fsm<=0; end if;
            end if;
         when 9 => if sdram_ready='0' then sdram_scanline_ask<='1'; fsm<=10; end if;
         when 10 =>
            cam_x <= sdram_scanline_addr(9 downto 0);
            sdram_wr_data<=cam_pixel;
            if sdram_ready='1' then
               sdram_scanline_ask<='0';
               cam_ready_reg<='1';
               cam_x<=(others=>'1');
               if low_priority_en='1' then fsm<=16; else fsm<=0; end if;
            end if;
         -----------------------------------------
         -- end of CAMERA to SDRAM section
         -----------------------------------------

         --=======================================
         -- LOW PRIORITY operations
         --=======================================
         
         -----------------------------------------
         -- h_scanline to SDRAM device section
         -----------------------------------------
         when 16 => 
            if h_scanline_wr_ask='0' then h_scanline_wr_ready_reg<='0'; fsm<=24;
            elsif (h_scanline_wr_ask='1')and(h_scanline_wr_ready_reg='0')
            then
               sdram_ask<='0'; sdram_scanline_ask<='0'; sdram_wr_en<='1';
               sdram_scanline_addr_start <= h_scanline_wr_page & h_scanline_wr_y & h_scanline_x_min;
               sdram_scanline_addr_delta<=conv_std_logic_vector(1,24);
               sdram_scanline_addr_nums<=conv_std_logic_vector(conv_integer(h_scanline_x_max-h_scanline_x_min),24);
               fsm<=17;
            else fsm<=24;
            end if;
         when 17 => if sdram_ready='0' then sdram_scanline_ask<='1'; fsm<=18; end if;
         when 18 =>
            h_scanline_wr_x<=sdram_scanline_addr(9 downto 0);
            sdram_wr_data <= h_scanline_wr_pixel;
            if sdram_ready='1' then sdram_scanline_ask<='0'; h_scanline_wr_ready_reg<='1'; h_scanline_wr_x<=(others=>'1'); fsm<=24; end if;
         -----------------------------------------
         -- end of h_scanline to SDRAM section
         -----------------------------------------

         -----------------------------------------
         -- SDRAM to h_scanline device section
         -----------------------------------------
         when 24 => 
            if h_scanline_rd_ask='0' then h_scanline_rd_ready_reg<='0'; fsm<=32;
            elsif (h_scanline_rd_ask='1')and(h_scanline_rd_ready_reg='0')
            then
               sdram_ask<='0'; sdram_scanline_ask<='0'; sdram_wr_en<='0';
               sdram_scanline_addr_start <= h_scanline_rd_page & h_scanline_rd_y & h_scanline_x_min;
               sdram_scanline_addr_delta<=conv_std_logic_vector(1,24);
               sdram_scanline_addr_nums<=conv_std_logic_vector(conv_integer(h_scanline_x_max-h_scanline_x_min),24);
               fsm<=25;
            else fsm<=32;
            end if;
         when 25 => if sdram_ready='0' then sdram_scanline_ask<='1'; fsm<=26; end if;
         when 26 =>
            h_scanline_rd_x<=sdram_scanline_addr(9 downto 0);
            h_scanline_rd_pixel<=sdram_rd_data;
            if sdram_ready='1' then sdram_scanline_ask<='0'; h_scanline_rd_ready_reg<='1'; h_scanline_rd_x<=(others=>'1'); fsm<=32; end if;
         -----------------------------------------
         -- end of SDRAM to h_scanline section
         -----------------------------------------

         -----------------------------------------
         -- v_scanline to SDRAM device section
         -----------------------------------------
         when 32 => 
            if v_scanline_wr_ask='0' then v_scanline_wr_ready_reg<='0'; fsm<=40;
            elsif (v_scanline_wr_ask='1')and(v_scanline_wr_ready_reg='0')
            then
               sdram_ask<='0'; sdram_scanline_ask<='0'; sdram_wr_en<='1';
               sdram_scanline_addr_start <= v_scanline_wr_page & v_scanline_y_min & v_scanline_wr_x;
               sdram_scanline_addr_delta<=conv_std_logic_vector(1024,24);
               sdram_scanline_addr_nums<=conv_std_logic_vector(conv_integer(v_scanline_y_max-v_scanline_y_min),24);
               fsm<=33;
            else fsm<=40;
            end if;
         when 33 => if sdram_ready='0' then sdram_scanline_ask<='1'; fsm<=34; end if;
         when 34 =>
            v_scanline_wr_y<=sdram_scanline_addr(19 downto 10);
            sdram_wr_data <= v_scanline_wr_pixel;
            if sdram_ready='1' then sdram_scanline_ask<='0'; v_scanline_wr_ready_reg<='1'; v_scanline_wr_y<=(others=>'1'); fsm<=40; end if;
         -----------------------------------------
         -- end of v_scanline to SDRAM section
         -----------------------------------------

         -----------------------------------------
         -- SDRAM to v_scanline device section
         -----------------------------------------
         when 40 => 
            if v_scanline_rd_ask='0' then v_scanline_rd_ready_reg<='0'; fsm<=48;
            elsif (v_scanline_rd_ask='1')and(v_scanline_rd_ready_reg='0')
            then
               sdram_ask<='0'; sdram_scanline_ask<='0'; sdram_wr_en<='0';
               sdram_scanline_addr_start <= v_scanline_rd_page & v_scanline_y_min & v_scanline_rd_x;
               sdram_scanline_addr_delta<=conv_std_logic_vector(1024,24);
               sdram_scanline_addr_nums<=conv_std_logic_vector(conv_integer(v_scanline_y_max-v_scanline_y_min),24);               
               fsm<=41;
            else fsm<=48;
            end if;
         when 41 => if sdram_ready='0' then sdram_scanline_ask<='1'; fsm<=42; end if;
         when 42 =>
            v_scanline_rd_y<=sdram_scanline_addr(19 downto 10);
            v_scanline_rd_pixel<=sdram_rd_data;
            if sdram_ready='1' then sdram_scanline_ask<='0'; v_scanline_rd_ready_reg<='1'; v_scanline_rd_y<=(others=>'1'); fsm<=48; end if;
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
            if sdram_ready='0' then
               sdram_addr<=cpu_mem_addr;
               if cpu_mem_wr_en='1' then sdram_wr_data<=cpu_mem_wr_data; end if;
               sdram_wr_en<=cpu_mem_wr_en; sdram_ask<='1';
               fsm<=50;
            end if;
         when 50 =>
            if sdram_ready='1' then 
               if cpu_mem_wr_en='0' then cpu_mem_rd_data<=sdram_rd_data; end if;
               fsm<=51;
            end if;
         when 51 =>
               sdram_wr_en<='0'; sdram_ask<='0';
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
