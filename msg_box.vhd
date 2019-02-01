------------------------------------------------------------------
--Copyright 2017 Andrey S. Ionisyan (anserion@gmail.com)
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
-- Description: generate 8-char text box for a VGA controller
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use ieee.std_logic_unsigned.all;

entity msg_box is
    Port ( 
		clk   : in  STD_LOGIC;
      x         : in  STD_LOGIC_VECTOR(7 downto 0);
      y         : in  STD_LOGIC_VECTOR(7 downto 0);
		msg       : in  STD_LOGIC_VECTOR(63 downto 0);
		char_x    : out STD_LOGIC_VECTOR(7 downto 0);
		char_y	 : out STD_LOGIC_VECTOR(7 downto 0);
		char_code : out STD_LOGIC_VECTOR(7 downto 0)
	 );
end msg_box;

architecture Behavioral of msg_box is
   signal cnt   : natural range 0 to 8 :=0;
   signal reg_x : STD_LOGIC_VECTOR(7 downto 0):=(others=>'0');
begin
   char_x<=reg_x;
	char_y <=y;
   process(clk)
   begin
		if rising_edge(clk) then
         case cnt is
            when 0 => reg_x<=x;
            when 1 => char_code<=msg(63 downto 56); reg_x<=x;
            when 2 => char_code<=msg(55 downto 48); reg_x<=reg_x+1;
            when 3 => char_code<=msg(47 downto 40); reg_x<=reg_x+1;
            when 4 => char_code<=msg(39 downto 32); reg_x<=reg_x+1;
            when 5 => char_code<=msg(31 downto 24); reg_x<=reg_x+1;
            when 6 => char_code<=msg(23 downto 16); reg_x<=reg_x+1;
            when 7 => char_code<=msg(15 downto 8); reg_x<=reg_x+1;
            when 8 => char_code<=msg(7 downto 0); reg_x<=reg_x+1;
            when others => null;
         end case;
         if cnt=8 then cnt<=1; else cnt<=cnt+1; end if;
		end if;
	end process;
end Behavioral;