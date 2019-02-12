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
-- Description: 16 bit pseudo random numbers generator
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use ieee.std_logic_unsigned.all;

entity rnd16_module is
    Generic (seed:STD_LOGIC_VECTOR(31 downto 0));
    Port ( 
      clk: in  STD_LOGIC;
      rnd16: out STD_LOGIC_VECTOR(15 downto 0)
	 );
end rnd16_module;

architecture ax309 of rnd16_module is
   signal fsm: natural range 0 to 1 := 0;
   signal rnd_reg: std_logic_vector(31 downto 0):=seed;
   signal new_bit: std_logic:='0';
begin
   rnd16<=rnd_reg(15 downto 0);
   new_bit<=rnd_reg(31) xor
            rnd_reg(30) xor
            rnd_reg(29) xor
            rnd_reg(27) xor
            rnd_reg(25) xor
            rnd_reg(0);
   process(clk)
   begin
		if rising_edge(clk) then
         rnd_reg<=new_bit & rnd_reg(31 downto 1);
		end if;
	end process;
end ax309;
