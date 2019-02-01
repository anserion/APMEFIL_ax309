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

------------------------------------------------------------------------------
-- Engineer: Andrey S. Ionisyan <anserion@gmail.com>
-- 
-- Description:
-- Top level for the simple adaptive median filter device (Alinx AX309 board).
-- signal input - OV7670 video camera
-- graphics output - 480x272 24bpp LCD display (Alinx AN430 board)
------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity apmefil_top is
   Port (
      clk50_ucf: in STD_LOGIC;
      
      led      : out  STD_LOGIC_VECTOR(3 downto 0);
      key      : in  STD_LOGIC_VECTOR(3 downto 0);
      key_RESET: in  STD_LOGIC;

      OV7670_SIOC  : out   STD_LOGIC;
      OV7670_SIOD  : inout STD_LOGIC;
      OV7670_RESET : out   STD_LOGIC;
      OV7670_PWDN  : out   STD_LOGIC;
      OV7670_VSYNC : in    STD_LOGIC;
      OV7670_HREF  : in    STD_LOGIC;
      OV7670_PCLK  : in    STD_LOGIC;
      OV7670_XCLK  : out   STD_LOGIC;
      OV7670_D     : in    STD_LOGIC_VECTOR(7 downto 0);
      
      lcd_red      : out   STD_LOGIC_VECTOR(7 downto 0);
      lcd_green    : out   STD_LOGIC_VECTOR(7 downto 0);
      lcd_blue     : out   STD_LOGIC_VECTOR(7 downto 0);
      lcd_hsync    : out   STD_LOGIC;
      lcd_vsync    : out   STD_LOGIC;
      lcd_dclk     : out   STD_LOGIC;

      Sdram_CLK_ucf: out STD_LOGIC; 
      Sdram_CKE_ucf: out STD_LOGIC;
      Sdram_NCS_ucf: out STD_LOGIC;
      Sdram_NWE_ucf: out STD_LOGIC;
      Sdram_NCAS_ucf: out STD_LOGIC;
      Sdram_NRAS_ucf: out STD_LOGIC;
      Sdram_DQM_ucf: out STD_LOGIC_VECTOR(1 downto 0);
      Sdram_BA_ucf: out STD_LOGIC_VECTOR(1 downto 0);
      Sdram_A_ucf: out STD_LOGIC_VECTOR(12 downto 0);
      Sdram_DB_ucf: inout STD_LOGIC_VECTOR(15 downto 0)
	);
end apmefil_top;

architecture ax309 of apmefil_top is
   component vram_128x32_8bit
   port (
    clka : IN STD_LOGIC;
    wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    addra : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
    dina : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    clkb : IN STD_LOGIC;
    addrb : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
    doutb : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
   );
   end component;
   
   component keys_supervisor is
   Port ( 
      clk : in std_logic;
      en  : in std_logic;
      key : in std_logic_vector(3 downto 0);
      key_rst: in std_logic;
      noise  : out std_logic_vector(31 downto 0);
      radius : out std_logic_vector(31 downto 0)
	);
   end component;

   component msg_center is
    Port ( 
		clk        : in  STD_LOGIC;
      en         : in std_logic;
      noise      : in std_logic_vector(31 downto 0);
      radius     : in std_logic_vector(31 downto 0);
		msg_char_x : out STD_LOGIC_VECTOR(6 downto 0);
		msg_char_y : out STD_LOGIC_VECTOR(4 downto 0);
		msg_char   : out STD_LOGIC_VECTOR(7 downto 0)
	 );
   end component;
   signal msg_char_x: std_logic_vector(6 downto 0);
   signal msg_char_y: std_logic_vector(4 downto 0);
   signal msg_char: std_logic_vector(7 downto 0);
   
   component clk_core
   port(
      CLK50_ucf: in std_logic;
      CLK100: out std_logic;
      CLK16: out std_logic;      
      CLK4: out std_logic;
      CLK25: out std_logic;
      CLK12_5: out std_logic
   );
   end component;
   signal clk25: std_logic:='0';
   signal clk12_5: std_logic:='0';
   signal clk16: std_logic:='0';
   signal clk4: std_logic:='0';
   signal clk100: std_logic:='0';
   
   component freq_div_module is
    Port ( 
		clk   : in  STD_LOGIC;
      en    : in  STD_LOGIC;
      value : in  STD_LOGIC_VECTOR(31 downto 0);
      result: out STD_LOGIC
	 );
   end component;
--   signal clk_1Mhz: std_logic:='0';
   signal clk_10Khz: std_logic:='0';
--   signal clk_200hz: std_logic:='0';
--   signal clk_100hz: std_logic:='0';
--   signal clk_50hz: std_logic:='0';
--   signal clk_1hz: std_logic:='0';
   
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
   signal cpu_hscanline_rd_ask   : std_logic:='0';
   signal cpu_hscanline_rd_ready : std_logic:='0';
   signal cpu_hscanline_rd_x     : std_logic_vector(9 downto 0):=(others=>'0');
   signal cpu_hscanline_rd_y     : std_logic_vector(9 downto 0):=(others=>'0');
   signal cpu_hscanline_rd_page  : std_logic_vector(3 downto 0):=(others=>'0');
   signal cpu_hscanline_rd_pixel : std_logic_vector(15 downto 0):=(others=>'0');

   signal cpu_hscanline_wr_ask   : std_logic:='0';
   signal cpu_hscanline_wr_ready : std_logic:='0';
   signal cpu_hscanline_wr_x     : std_logic_vector(9 downto 0):=(others=>'0');
   signal cpu_hscanline_wr_y     : std_logic_vector(9 downto 0):=(others=>'0');
   signal cpu_hscanline_wr_page  : std_logic_vector(3 downto 0):=(others=>'0');
   signal cpu_hscanline_wr_pixel : std_logic_vector(15 downto 0):=(others=>'0');

   signal cpu_vscanline_rd_ask   : std_logic:='0';
   signal cpu_vscanline_rd_ready : std_logic:='0';
   signal cpu_vscanline_rd_x     : std_logic_vector(9 downto 0):=(others=>'0');
   signal cpu_vscanline_rd_y     : std_logic_vector(9 downto 0):=(others=>'0');
   signal cpu_vscanline_rd_page  : std_logic_vector(3 downto 0):=(others=>'0');
   signal cpu_vscanline_rd_pixel : std_logic_vector(15 downto 0):=(others=>'0');
   
   signal cpu_vscanline_wr_ask   : std_logic:='0';
   signal cpu_vscanline_wr_ready : std_logic:='0';
   signal cpu_vscanline_wr_x     : std_logic_vector(9 downto 0):=(others=>'0');
   signal cpu_vscanline_wr_y     : std_logic_vector(9 downto 0):=(others=>'0');
   signal cpu_vscanline_wr_page  : std_logic_vector(3 downto 0):=(others=>'0');
   signal cpu_vscanline_wr_pixel : std_logic_vector(15 downto 0):=(others=>'0');
   
   signal cpu_hscanline_xmin : std_logic_vector(9 downto 0):=(others=>'0');
   signal cpu_hscanline_xmax : std_logic_vector(9 downto 0):=(others=>'0');
   
   signal cpu_vscanline_ymin : std_logic_vector(9 downto 0):=(others=>'0');
   signal cpu_vscanline_ymax : std_logic_vector(9 downto 0):=(others=>'0');

   signal sdram_hscanline_rd_x     : std_logic_vector(9 downto 0):=(others=>'0');
   signal sdram_hscanline_rd_pixel : std_logic_vector(15 downto 0):=(others=>'0');

   signal sdram_hscanline_wr_x     : std_logic_vector(9 downto 0):=(others=>'0');
   signal sdram_hscanline_wr_pixel : std_logic_vector(15 downto 0):=(others=>'0');

   signal sdram_vscanline_rd_y     : std_logic_vector(9 downto 0):=(others=>'0');
   signal sdram_vscanline_rd_pixel : std_logic_vector(15 downto 0):=(others=>'0');

   signal sdram_vscanline_wr_y     : std_logic_vector(9 downto 0):=(others=>'0');
   signal sdram_vscanline_wr_pixel : std_logic_vector(15 downto 0):=(others=>'0');

   component sdram_controller
	generic (
				--memory frequency in MHz
				sdram_frequency	: integer := 100
				);
	port (
			--ready operation
			ready						: out std_logic;
			--clk
			clk						: in std_logic;
			--read interface
			rd_req					: in std_logic;
			rd_adr					: in std_logic_vector(23 downto 0);
			rd_data					: out std_logic_vector(15 downto 0);
			rd_valid					: out std_logic;
			--write interface
			wr_req					: in std_logic;
			wr_adr					: in std_logic_vector(23 downto 0);
			wr_data					: in std_logic_vector(15 downto 0);
			--SDRAM interface
			sdram_wren_n			: out std_logic := '1';
			sdram_cas_n				: out std_logic := '1';
			sdram_ras_n				: out std_logic := '1';
			sdram_a					: out std_logic_vector(12 downto 0);
			sdram_ba					: out std_logic_vector(1 downto 0);
			sdram_dqm				: out std_logic_vector(1 downto 0);
			sdram_dq					: inout std_logic_vector(15 downto 0);
			sdram_clk_n				: out std_logic
			);
   end component;
   signal sdram_clk : std_logic;
   signal sdram_ready,sdram_rd_req,sdram_rd_valid,sdram_wr_req:std_logic:='0';
   signal sdram_rd_addr,sdram_wr_addr:std_logic_vector(23 downto 0);
   signal sdram_rd_data,sdram_wr_data:std_logic_vector(15 downto 0);

   component sdram_supervisor is
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
   end component;

   component lcd_AN430
    Port ( 
      en      : in std_logic;
      clk     : in  STD_LOGIC;
      red     : out STD_LOGIC_VECTOR(7 downto 0);
      green   : out STD_LOGIC_VECTOR(7 downto 0);
      blue    : out STD_LOGIC_VECTOR(7 downto 0);
      hsync   : out STD_LOGIC;
      vsync   : out STD_LOGIC;
      de	     : out STD_LOGIC;
      x       : out STD_LOGIC_VECTOR(9 downto 0);
      y       : out STD_LOGIC_VECTOR(9 downto 0);
      dirty_x : out STD_LOGIC_VECTOR(9 downto 0);
      dirty_y : out STD_LOGIC_VECTOR(9 downto 0);
      pixel   : in STD_LOGIC_VECTOR(23 downto 0);
      char_x    : out STD_LOGIC_VECTOR(6 downto 0);
      char_y	 : out STD_LOGIC_VECTOR(4 downto 0);
      char_code : in  STD_LOGIC_VECTOR(7 downto 0)
    );
   end component;
   signal lcd_clk   : std_logic;
   signal lcd_en    : std_logic := '1';
   signal lcd_rd_en : std_logic := '1';
   signal lcd_de    : std_logic :='0';
   signal lcd_reg_hsync: STD_LOGIC :='1';
   signal lcd_reg_vsync: STD_LOGIC :='1';
   signal lcd_x     : std_logic_vector(9 downto 0) := (others => '0');
   signal lcd_y     : std_logic_vector(9 downto 0) := (others => '0');
   signal lcd_dirty_x: std_logic_vector(9 downto 0) := (others => '0');
   signal lcd_dirty_y: std_logic_vector(9 downto 0) := (others => '0');	
   signal lcd_pixel : std_logic_vector(23 downto 0) := (others => '0');	
   signal lcd_char_x: std_logic_vector(6 downto 0) := (others => '0');
   signal lcd_char_y: std_logic_vector(4 downto 0) := (others => '0');
   signal lcd_char  : std_logic_vector(7 downto 0);
   signal lcd_scanline_wea   : std_logic_vector(0 downto 0);
   signal lcd_scanline_x     : std_logic_vector(9 downto 0);
   signal lcd_scanline_pixel : std_logic_vector(15 downto 0);
   signal pixel_16bpp : std_logic_vector(15 downto 0) := (others => '0');
   signal pixel_gray : std_logic_vector(7 downto 0) := (others => '0');
   
   component ov7670_capture is
   Port (
      en    : in std_logic;
      clk   : in std_logic;
      vsync : in std_logic;
      href  : in std_logic;
      din   : in std_logic_vector(7 downto 0);
      cam_x : out std_logic_vector(9 downto 0);
      cam_y : out std_logic_vector(9 downto 0);
      pixel : out std_logic_vector(15 downto 0);
      ready : out std_logic
      );
   end component;
   signal cam_clk : std_logic;
   signal cam_en       : std_logic := '1';
   signal cam_wr_en    : std_logic := '1';
   signal cam_pixel_ready: std_logic := '0';
   signal cam_y        : std_logic_vector(9 downto 0):=(others=>'0');
   signal cam_x        : std_logic_vector(9 downto 0):=(others=>'0');
   signal cam_pixel    : std_logic_vector(15 downto 0):=(others=>'0');
   signal cam_scanline_x : std_logic_vector(9 downto 0):=(others=>'0');
   signal cam_scanline_pixel : std_logic_vector(15 downto 0):=(others=>'0');

   component filter_cpu is
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
   end component;
   signal cpu_clk: std_logic:='0';
   signal cpu_mem_ask: std_logic:='0';
   signal cpu_mem_ready: std_logic:='0';
   signal cpu_mem_wr_en: std_logic:='0';
   signal cpu_mem_addr: std_logic_vector(23 downto 0):=(others=>'0');
   signal cpu_mem_wr_data: std_logic_vector(15 downto 0):=(others=>'0');
   signal cpu_mem_rd_data: std_logic_vector(15 downto 0):=(others=>'0');
   
   signal noise_xmin: std_logic_vector(9 downto 0) := conv_std_logic_vector(480-272+16,10);
   signal noise_ymin: std_logic_vector(9 downto 0) := conv_std_logic_vector(32,10);
   signal noise_xmax: std_logic_vector(9 downto 0) := conv_std_logic_vector(480-16,10);
   signal noise_ymax: std_logic_vector(9 downto 0) := conv_std_logic_vector(480-32,10);
   
   signal median_xmin: std_logic_vector(9 downto 0):= conv_std_logic_vector(480-272+16+32,10);
   signal median_ymin: std_logic_vector(9 downto 0):= conv_std_logic_vector(32+96,10);
   signal median_xmax: std_logic_vector(9 downto 0):= conv_std_logic_vector(480-16-32,10);
   signal median_ymax: std_logic_vector(9 downto 0):= conv_std_logic_vector(480-32-96,10);
   
   signal noise_reg: std_logic_vector(31 downto 0):=(others=>'0');
   signal radius_reg: std_logic_vector(31 downto 0):=(others=>'0');
   
begin
   --------------------------------
   -- CLOCK section
   --------------------------------
   clocking_chip: clk_core port map (CLK50_ucf, clk100, clk16, clk4, clk25, clk12_5);
   sdram_clk<=clk100;
   lcd_clk<=clk4;
   lcd_dclk<=lcd_clk;
   cam_clk<=clk25;

   freq_10Khz_chip: freq_div_module port map(clk16,'1',conv_std_logic_vector(800,32),clk_10Khz);

   --------------------------------
   -- Text messages supervisor section
   --------------------------------
   ch_lcd_chip : vram_128x32_8bit
   PORT MAP (
    clka => clk4,
    wea => (others=>'1'),
    addra => msg_char_y & msg_char_x,
    dina => msg_char,
    clkb => lcd_clk,
    addrb => lcd_char_y & lcd_char_x,
    doutb => lcd_char
   );
   
   msg_center_chip: msg_center port map (clk_10Khz,'1',
         noise_reg,radius_reg,
         msg_char_x,msg_char_y,msg_char);
                                          
   --------------------------------
   -- SDRAM supervisor section
   --------------------------------
   sdram_CKE_ucf<='1'; --sdram chip clock always turn on
   sdram_NCS_ucf<='0'; --sdram chip always selected (zero active level)
   SDRAM_chip: sdram_controller generic map (100)
                   port map (
                             sdram_ready, sdram_clk,
                             sdram_rd_req, sdram_rd_addr, sdram_rd_data, sdram_rd_valid,
                             sdram_wr_req, sdram_wr_addr, sdram_wr_data,
                             sdram_nwe_ucf, sdram_ncas_ucf, sdram_nras_ucf,
                             sdram_a_ucf, sdram_ba_ucf, sdram_dqm_ucf, sdram_db_ucf,
                             sdram_clk_ucf
                             );

   sdram_supervisor_chip: sdram_supervisor
   Port map( 
      clk => sdram_clk,
      en  => sdram_ready,
      lcd_en => lcd_rd_en,
      cam_en => cam_wr_en,

      sdram_rd_req   => sdram_rd_req,
      sdram_rd_valid => sdram_rd_valid,
      sdram_wr_req   => sdram_wr_req,
      sdram_rd_addr  => sdram_rd_addr,
      sdram_wr_addr  => sdram_wr_addr,
      sdram_rd_data  => sdram_rd_data,
      sdram_wr_data  => sdram_wr_data,

      lcd_x_min   => conv_std_logic_vector(0,10),
      lcd_x_max   => conv_std_logic_vector(480,10),
      lcd_x       => lcd_scanline_x,
      lcd_y       => lcd_y,
      lcd_pixel   => lcd_scanline_pixel,

      cam_x_min   => conv_std_logic_vector(0,10), 
      cam_x_max   => conv_std_logic_vector(480,10), --conv_std_logic_vector(640,10),
      cam_x       => cam_scanline_x,
      cam_y       => cam_y,
      cam_pixel   => cam_scanline_pixel,

      h_scanline_rd_ask   => cpu_hscanline_rd_ask,
      h_scanline_rd_ready => cpu_hscanline_rd_ready,
      h_scanline_rd_x     => sdram_hscanline_rd_x,
      h_scanline_rd_y     => cpu_hscanline_rd_y,
      h_scanline_rd_page  => cpu_hscanline_rd_page,
      h_scanline_rd_pixel => sdram_hscanline_rd_pixel,

      h_scanline_wr_ask   => cpu_hscanline_wr_ask,
      h_scanline_wr_ready => cpu_hscanline_wr_ready,
      h_scanline_wr_x     => sdram_hscanline_wr_x,
      h_scanline_wr_y     => cpu_hscanline_wr_y,
      h_scanline_wr_page  => cpu_hscanline_wr_page,
      h_scanline_wr_pixel => sdram_hscanline_wr_pixel,
      
      h_scanline_x_min => cpu_hscanline_xmin,
      h_scanline_x_max => cpu_hscanline_xmax,

      v_scanline_rd_ask   => cpu_vscanline_rd_ask,
      v_scanline_rd_ready => cpu_vscanline_rd_ready,
      v_scanline_rd_x     => cpu_vscanline_rd_x,
      v_scanline_rd_y     => sdram_vscanline_rd_y,
      v_scanline_rd_page  => cpu_vscanline_rd_page,
      v_scanline_rd_pixel => sdram_vscanline_rd_pixel,
      
      v_scanline_wr_ask   => cpu_vscanline_wr_ask,
      v_scanline_wr_ready => cpu_vscanline_wr_ready,
      v_scanline_wr_x     => cpu_vscanline_wr_x,
      v_scanline_wr_y     => sdram_vscanline_wr_y,
      v_scanline_wr_page  => cpu_vscanline_wr_page,
      v_scanline_wr_pixel => sdram_vscanline_wr_pixel,
      
      v_scanline_y_min => cpu_vscanline_ymin,
      v_scanline_y_max => cpu_vscanline_ymax,
      
      cpu_mem_ask => cpu_mem_ask,
      cpu_mem_ready => cpu_mem_ready,
      cpu_mem_wr_en => cpu_mem_wr_en,
      cpu_mem_addr  => cpu_mem_addr,
      cpu_mem_wr_data => cpu_mem_wr_data,
      cpu_mem_rd_data => cpu_mem_rd_data
	);

   --------------------------------
   -- LCD device section
   --------------------------------
   lcd_en<='1';
   lcd_rd_en<=not(lcd_reg_vsync);
   
   lcd_scanline : vram_scanline
   PORT MAP (
    clka  => sdram_clk,
    wea   => (0=>'1'),
    addra => lcd_scanline_x,
    dina  => lcd_scanline_pixel,
    clkb  => lcd_clk,
    addrb => lcd_x,
    doutb => pixel_16bpp(15 downto 0)
   );

   pixel_gray<=pixel_16bpp(7 downto 0);
   
   lcd_pixel(7 downto 0)<=pixel_gray;
   lcd_pixel(15 downto 8)<=pixel_gray;
   lcd_pixel(23 downto 16)<=pixel_gray;
   lcd_hsync<=lcd_reg_hsync;
   lcd_vsync<=lcd_reg_vsync;
   lcd_AN430_chip: lcd_AN430 PORT MAP(
      en    => lcd_en,
		clk   => lcd_clk,
		red   => lcd_red,
		green => lcd_green,
		blue  => lcd_blue,
		hsync => lcd_reg_hsync,
		vsync => lcd_reg_vsync,
		de	   => lcd_de,
		x     => lcd_x,
		y     => lcd_y,
      dirty_x=>lcd_dirty_x,
      dirty_y=>lcd_dirty_y,
      pixel => lcd_pixel,
		char_x=> lcd_char_x,
		char_y=> lcd_char_y,
		char_code  => lcd_char
      );

   --------------------------------
   -- OV7670 camera section
   --------------------------------
   cam_en<='1';
   cam_wr_en <= key_RESET when cam_y<480 else '0';
   
   cam_scanline : vram_scanline
   PORT MAP (
    clka  => cam_clk,
    wea   => (0=>cam_pixel_ready),
    addra => cam_x,
    dina  => cam_pixel,
    clkb  => sdram_clk,
    addrb => cam_scanline_x,
    doutb => cam_scanline_pixel
   );
   
   --minimal OV7670 grayscale mode
   OV7670_PWDN  <= '0'; --0 - power on
   OV7670_RESET <= '1'; --0 - activate reset
   OV7670_XCLK  <= cam_clk;
   ov7670_siod  <= 'Z';
   ov7670_sioc  <= '0';
   
   capture: ov7670_capture PORT MAP(
      en    => cam_en,
		clk   => OV7670_PCLK,
		vsync => OV7670_VSYNC,
		href  => OV7670_HREF,
		din   => OV7670_D,
      cam_x =>cam_x,
      cam_y =>cam_y,
      pixel =>cam_pixel,
		ready =>cam_pixel_ready
      );
      
   --------------------------------
   -- LEDs and KEYs section
   --------------------------------
   led<=not(key);
   keys_chip: keys_supervisor port map(clk_10Khz,'1',key,key_RESET,noise_reg,radius_reg);
   
   --------------------------------
   -- MEDIAN filter CPU section
   --------------------------------
   cpu_clk<=clk100;
   
   filter_cpu_chip: filter_cpu port map(
      cpu_clk,

      cpu_hscanline_rd_ask,cpu_hscanline_rd_ready,cpu_hscanline_rd_page,
      cpu_hscanline_rd_x,cpu_hscanline_rd_y,cpu_hscanline_rd_pixel,

      cpu_hscanline_wr_ask,cpu_hscanline_wr_ready,cpu_hscanline_wr_page,
      cpu_hscanline_wr_x,cpu_hscanline_wr_y,cpu_hscanline_wr_pixel,
      
      cpu_hscanline_xmin, cpu_hscanline_xmax,

      cpu_vscanline_rd_ask,cpu_vscanline_rd_ready,cpu_vscanline_rd_page,
      cpu_vscanline_rd_x,cpu_vscanline_rd_y,cpu_vscanline_rd_pixel,

      cpu_vscanline_wr_ask,cpu_vscanline_wr_ready,cpu_vscanline_wr_page,
      cpu_vscanline_wr_x,cpu_vscanline_wr_y,cpu_vscanline_wr_pixel,
      
      cpu_vscanline_ymin, cpu_vscanline_ymax,
      
      noise_reg,radius_reg,
      noise_xmin,noise_ymin,noise_xmax,noise_ymax,
      median_xmin,median_ymin,median_xmax,median_ymax );

   cpu_rd_hscanline : vram_scanline
   PORT MAP (
    clka  => sdram_clk,
    wea   => (0=>'1'),
    addra => sdram_hscanline_rd_x,
    dina  => sdram_hscanline_rd_pixel,
    clkb  => cpu_clk,
    addrb => cpu_hscanline_rd_x,
    doutb => cpu_hscanline_rd_pixel
   );

   cpu_wr_hscanline : vram_scanline
   PORT MAP (
    clka  => cpu_clk,
    wea   => (0=>'1'),
    addra => cpu_hscanline_wr_x,
    dina  => cpu_hscanline_wr_pixel,
    clkb  => sdram_clk,
    addrb => sdram_hscanline_wr_x,
    doutb => sdram_hscanline_wr_pixel
   );

   cpu_rd_vscanline : vram_scanline
   PORT MAP (
    clka  => sdram_clk,
    wea   => (0=>'1'),
    addra => sdram_vscanline_rd_y,
    dina  => sdram_vscanline_rd_pixel,
    clkb  => cpu_clk,
    addrb => cpu_vscanline_rd_y,
    doutb => cpu_vscanline_rd_pixel
   );
   
   cpu_wr_vscanline : vram_scanline
   PORT MAP (
    clka  => cpu_clk,
    wea   => (0=>'1'),
    addra => cpu_vscanline_wr_y,
    dina  => cpu_vscanline_wr_pixel,
    clkb  => sdram_clk,
    addrb => sdram_vscanline_wr_y,
    doutb => sdram_vscanline_wr_pixel
   );
   
end ax309;
