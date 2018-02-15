
-- create the module's table
local bnrom = {}

-- import required modules
local dict = require "scripts.app.dict"
local dump = require "scripts.app.dump"
local flash = require "scripts.app.flash"

-- file constants

-- local functions


--Cart should be in reset state upon calling this function 
--this function processes all user requests for this specific board/mapper
local function process( read, erase, program, verify, dumpfile, flashfile, verifyfile)

	local rv = nil
	local file 

--initialize device i/o for NES
	dict.io("IO_RESET")
	dict.io("NES_INIT")


--dump the cart to dumpfile
	if read then
		file = assert(io.open(dumpfile, "wb"))

		--dump cart into file
		dump.dumptofile( file, 32, "BNROM", "PRGROM", true )
	--	dump.dumptofile( file, 512, "BNROM", "PRGROM", true )

		--close file
		assert(file:close())
	end


--erase the cart
	if erase then

		print("erasing BNROM");

		print("erasing PRG-ROM");
		dict.nes("DISCRETE_EXP0_PRGROM_WR", 0x5555, 0xAA)
		dict.nes("DISCRETE_EXP0_PRGROM_WR", 0x2AAA, 0x55)
		dict.nes("DISCRETE_EXP0_PRGROM_WR", 0x5555, 0x80)
		dict.nes("DISCRETE_EXP0_PRGROM_WR", 0x5555, 0xAA)
		dict.nes("DISCRETE_EXP0_PRGROM_WR", 0x2AAA, 0x55)
		dict.nes("DISCRETE_EXP0_PRGROM_WR", 0x5555, 0x10)
		rv = dict.nes("NES_CPU_RD", 0x8000)

		local i = 0

		--TODO create some function to pass the read value 
		--that's smart enough to figure out if the board is actually erasing or not
		while ( rv ~= 0xFF ) do
			rv = dict.nes("NES_CPU_RD", 0x8000)
			i = i + 1
		end
		print(i, "naks, done erasing prg.");

	end


--program flashfile to the cart
	if program then
		--open file
		file = assert(io.open(flashfile, "rb"))
		--determine if auto-doubling, deinterleaving, etc, 
		--needs done to make board compatible with rom
		--flash cart
		flash.write_file( file, 32, "BNROM", "PRGROM", true )
		--close file
		assert(file:close())

	end

--verify flashfile is on the cart
	if verify then
		--for now let's just dump the file and verify manually

		file = assert(io.open(verifyfile, "wb"))

		--dump cart into file
		dump.dumptofile( file, 32, "BNROM", "PRGROM", true )

		--close file
		assert(file:close())
	end

	dict.io("IO_RESET")
end


-- global variables so other modules can use them


-- call functions desired to run when script is called/imported


-- functions other modules are able to call
bnrom.process = process

-- return the module's table
return bnrom
