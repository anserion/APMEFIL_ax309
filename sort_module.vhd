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
-- Description: hardware sort O(n) design
--              n - is odd !!!!
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use ieee.std_logic_unsigned.all;

entity cmp_module is
   port(
      clk: std_logic;
      a,b: in std_logic_vector(15 downto 0);
      min,max: out std_logic_vector(15 downto 0)
   );
end cmp_module;

architecture ax309 of cmp_module is
begin
   process(clk)
   begin
      if rising_edge(clk) then
         if a<b
         then min<=a; max<=b;
         else min<=b; max<=a;
         end if;
      end if;
   end process;
end ax309;
-----------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use ieee.std_logic_unsigned.all;

entity sort_module is
    Generic (n: integer:=25);
    Port ( 
		clk          : in std_logic;
      ask          : in std_logic;
      ready        : out std_logic;
      array_in     : in std_logic_vector(n*16-1 downto 0);
      array_sorted : out std_logic_vector(n*16-1 downto 0)
	 );
end sort_module;

architecture ax309 of sort_module is
	type buffer_array_type is array (0 to n-1) of std_logic_vector(15 downto 0);
	signal buf_in,buf_mid,buf_out: buffer_array_type:=(others=>(others=>'0'));

   component cmp_module is
   port(
      clk: std_logic;
      a,b: in std_logic_vector(15 downto 0);
      min,max: out std_logic_vector(15 downto 0)
   );
   end component;
begin

   gen_cmp_line1:
   for k in 0 to n/2-1 generate
      cmp1_chips: cmp_module port map (
         clk=>clk,
         a=>buf_in(k*2),
         b=>buf_in(k*2+1),
         min=>buf_mid(k*2),
         max=>buf_mid(k*2+1)
      );
   end generate;
   buf_mid(n-1)<=buf_in(n-1);

   gen_cmp_line2:
   for k in 0 to n/2-2 generate
      cmp2_chips: cmp_module port map (
         clk=>clk,
         a=>buf_mid(k*2+1),
         b=>buf_mid(k*2+2),
         min=>buf_out(k*2+1),
         max=>buf_out(k*2+2)
      );
   end generate;
   buf_out(0)<=buf_mid(0);
   
   cmp2_last_chip: cmp_module port map (
         clk=>clk,
         a=>buf_mid(n-1),
         b=>buf_mid(n-2),
         min=>buf_out(n-2),
         max=>buf_out(n-1)
   );
   
   process(clk)
   variable i: integer range 0 to 255:=0;
   variable fsm: integer range 0 to 15:=0;
   begin
   if rising_edge(clk) then
   case fsm is
   --idle
   when 0=> 
      ready<='0';
      if ask='1' then fsm:=1; end if;
   when 1=>
      for k in 0 to n-1 loop
         buf_in(k)<=array_in(k*16+15 downto k*16);
      end loop;
      fsm:=2;
      
   when 2=> i:=0; fsm:=3;
   when 3=> if i=(n/2+1) then fsm:=14; else fsm:=4; end if;
   when 4=> fsm:=5;
   when 5=> fsm:=6;
   when 6=> fsm:=7;
   when 7=> fsm:=8;
   when 8=> for k in 0 to n-1 loop buf_in(k)<=buf_out(k); end loop; fsm:=9;
   when 9=> i:=i+1; fsm:=3;
   
   when 14=>
      for k in 0 to n-1 loop
         array_sorted(k*16+15 downto k*16)<=buf_out(k);
      end loop;
      fsm:=15;
      
   -- next idle
   when 15=>
      ready<='1';
      if ask='0' then fsm:=0; end if;
   when others=>null;
   end case;
   end if;
   end process;
end ax309;
