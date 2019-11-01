
-- create the module's table
local machXO256 = {}

-- import required modules
local time = require "scripts.app.time"
local dict = require "scripts.app.dict"
local files = require "scripts.app.files"

local pbje = require "scripts.jtag.pbje"

--TODO this should report error/success if matches expected for this device
local function check_idcode(debug)

	local idcode_len = 32 --hex digits

	--first put/verify jtag statemachine is in RESET
	pbje.goto_state("RESET")

	--by default jtag should be in IDCODE or BYPASS if IDCODE not present
	--The TDI pin doesn't even have to be working to scan out IDCODE by this means
	
	--let's just put in IDCODE mode
	---[[
	--Mach XO verify ID code
--	! Check the IDCODE
--
--	! Shift in IDCODE(0x16) instruction
--	SIR     8       TDI  (16);
	pbje.goto_state("SHIFT_IR")
	pbje.scan( 8, 0x16)

	--return to default state after SIR
	--doesn't appear to actually be needed
--	pbje.goto_state("PAUSE_IR")

--	SDR     32      TDI  (FFFFFFFF)
--	                TDO  (01281043)
--	                MASK (FFFFFFFF);
	--pbje.goto_state("SHIFT_DR")
	--rv = pbje.scan( 32, "HIGH", true)
	--print("return data:", string.format(" %X, ",rv))
	--]]



	--change to SCAN-DR state
	pbje.goto_state("SHIFT_DR")

	--scan out 32bit IDCODE while scanning in 1's to TDI
	rv = pbje.scan( 32, "HIGH", true )
	if debug then print("return data:", string.format("%X",rv)) end
	rv =                  string.format("%16.16X",rv)
	if debug then print(rv) end
	rv = string.sub(rv, ((64-idcode_len)/4)+1, 64/4)

	--print("return data:", string.format(" %X, ",rv))
	print("read idcode:", rv)

	--if( rv == 0x1281043 ) then
	if( rv == "01281043" ) then
	-- Mach XO 256   01281043
	-- 4032v	(01805043)
	-- 4064v	(01809043)
	--
	-- 9536xl
	-- //Loading device with 'idcode' instruction.
	-- SIR 8 TDI (fe) SMASK (ff) ;
	-- SDR 32 TDI (00000000) SMASK (ffffffff) TDO (f9602093) MASK (0fffffff) ;
	--
	-- 9572xl
	-- //Loading device with 'idcode' instruction.
	-- SIR 8 TDI (fe) SMASK (ff) ;
	-- SDR 32 TDI (00000000) SMASK (ffffffff) TDO (f9604093) MASK (0fffffff) ;
	-- test read gives 59604093
		print("IDCODE matches MACHXO-256")
	--elseif ( rv==0x01805043 ) then
	elseif ( rv=="01805043" ) then
		print("IDCODE matches LC4032V")
	--elseif ( rv==0x01809043 ) then
	elseif ( rv=="01809043" ) then
		print("IDCODE matches LC4064V")
	else
		print("no match for IDCODE")
	end
	
	--xilinx IDCODE command is different
	--//Loading device with 'idcode' instruction.
	--SIR 8 TDI (fe) SMASK (ff) ;
	--SDR 32 TDI (00000000) SMASK (ffffffff) TDO (f9602093) MASK (0fffffff) ;
--	pbje.goto_state("SHIFT_IR")
--	pbje.scan( 8, 0xfe)
--	pbje.goto_state("SHIFT_DR")
--	rv = pbje.scan( 32, "HIGH", true)
--	print("return data:", string.format(" %X, ",rv))

end


local function done_exit(debug)
	--! Program DONE bit
	--
	--! Shift in ISC PROGRAM DONE(0x2F) instruction
	--SIR	8	TDI  (2F);
	pbje.goto_state("SHIFT_IR") pbje.scan( 8, 0x2F)
	--RUNTEST	IDLE	5 TCK	5.00E-002 SEC;
	pbje.runtest( "IDLE", 5, 0.05 )
	--SDR	1	TDI  (0)
	--		TDO  (1);
	pbje.goto_state("SHIFT_DR") pbje.scan( 1, "LOW")
	--! Shift in BYPASS(0xFF) instruction
	--SIR	8	TDI  (FF)
	--		TDO  (1D);
	pbje.goto_state("SHIFT_IR") pbje.scan( 8, 0xFF)
	--
	--
	--! Exit the programming mode
	--
	--! Shift in ISC DISABLE(0x1E) instruction
	--SIR	8	TDI  (1E);
	pbje.goto_state("SHIFT_IR") pbje.scan( 8, 0x1E)
	--RUNTEST	IDLE	5 TCK	5.00E-002 SEC;
	pbje.runtest( "IDLE", 5, 0.05 )

	--! Shift in BYPASS(0xFF) instruction
	--SIR	8	TDI  (FF);
	pbje.goto_state("SHIFT_IR") pbje.scan( 8, 0xFF)
	--RUNTEST	IDLE	5 TCK	1.00E-003 SEC;
	pbje.runtest( "IDLE", 5, 0.001 )
	--
	--
	--! Verify SRAM DONE Bit
	--
	--! Shift in BYPASS(0xFF) instruction
	--SIR	8	TDI  (FF)
	--		TDO  (1D);
	pbje.goto_state("SHIFT_IR") pbje.scan( 8, 0xFF)

end

local function check_status(debug)
--! Read the status bit
--
--! Shift in READ STATUS(0xB2) instruction
--SIR	8	TDI  (B2);
	pbje.goto_state("SHIFT_IR") pbje.scan( 8, 0xB2)
--RUNTEST	IDLE	5 TCK	1.00E-003 SEC;
	pbje.runtest( "IDLE", 5, 0.7 )
--SDR	1	TDI  (0)
--		TDO  (0);
	pbje.goto_state("SHIFT_DR")
	rv = pbje.scan( 1, 0x0, true) % 2	--mask out all but the last bit
	if( rv == 0) then
		print("MachXO-256 status bit clear as expected")
	else
		print("MachXO-256 status bit WAS NOT clear as expected")
	end

	return rv
end

local function erase(debug)


	--MACH XO 256
	--! Program Bscan register
	--
	--! Shift in Preload(0x1C) instruction
	--SIR     8       TDI  (1C);	
	pbje.goto_state("SHIFT_IR") pbje.scan( 8, 0x1C)
	--SDR     160     TDI  (FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
	pbje.goto_state("SHIFT_DR") pbje.scan( 160, "HIGH")	
	--the HIGHZ instruction seems more fitting...	 0x18


--	! MACH-XO Erase the device
--	! Enable the programming mode
--
--	! Shift in ISC ENABLE(0x15) instruction
--	SIR     8       TDI  (15);
	pbje.goto_state("SHIFT_IR") pbje.scan( 8, 0x15)
--	RUNTEST IDLE    5 TCK   1.00E-003 SEC;
	pbje.runtest( "IDLE", 5) 

--	! Shift in ISC SRAM ENABLE(0x55) instruction
--	SIR     8       TDI  (55);
	pbje.goto_state("SHIFT_IR") pbje.scan( 8, 0x55)
--	RUNTEST IDLE    5 TCK   1.00E-003 SEC;
	pbje.runtest( "IDLE", 5 )

--	! Shift in ISC ERASE(0x03) instruction
--	SIR     8       TDI  (03);
	pbje.goto_state("SHIFT_IR") pbje.scan( 8, 0x03)
--	RUNTEST IDLE    5 TCK   1.00E-003 SEC;
	pbje.runtest( "IDLE", 5 )

--	! Shift in ISC ENABLE(0x15) instruction
--	SIR     8       TDI  (15);
	pbje.goto_state("SHIFT_IR") pbje.scan( 8, 0x15)
--	RUNTEST IDLE    5 TCK   1.00E-003 SEC;
	pbje.runtest( "IDLE", 5 )

--	! Shift in ISC ERASE(0x03) instruction
--	SIR     8       TDI  (03);
	pbje.goto_state("SHIFT_IR") pbje.scan( 8, 0x03)
--	RUNTEST IDLE    5 TCK   1.00E+001 SEC;
	pbje.runtest( "IDLE", 5, 1 ) --seems to fail if under ~0.5sec
	--pbje.runtest( "IDLE", 5, 0.7 )
--	SDR     1       TDI  (0)
--	                TDO  (1);  TDO must be set
	pbje.goto_state("SHIFT_DR")
	rv = pbje.scan( 1, 0x0, true) % 2	--mask out all but the last bit
	if( rv == 1) then
		print("MachXO-256 CPLD erasure success!!!")
	else
		print("failed to erase MachXO-256 CPLD")
	end
	--]]
	
	check_status()
	
end

local function check_usercode(expected, len, debug)

	--first put/verify jtag statemachine is in RESET
	pbje.goto_state("RESET")

	--by default jtag should be in IDCODE or BYPASS if IDCODE not present
	--The TDI pin doesn't even have to be working to scan out IDCODE by this means
	
	--! Verify USERCODE
	--
	--! Shift in READ USERCODE(0x17) instruction
	--SIR	8	TDI  (17);
	pbje.goto_state("SHIFT_IR")
	pbje.scan( 8, 0x17)
	--SDR	32	TDI  (FFFFFFFF)
	--		TDO  (000005DE);
	--change to SCAN-DR state
	pbje.goto_state("SHIFT_DR")

	--scan out 32bit IDCODE while scanning in 1's to TDI
	rv = pbje.scan( len, "HIGH", true )
	if debug then print("return data:", string.format(" %X, ",rv)) end
	rv =                  string.format("%8.8X",rv)

	--rv = string.sub(rv, ((64-len)/4)+1, 64)
	--rv = string.sub(rv, 9, 16)
	rv = string.sub(rv, ((64-len)/4)+1, 64/4)

	if debug then print("read usercode:", rv) end
--	expected = string.format("%8.8X",expected)
	if debug then print("expected usercode:", expected) end

	if rv == expected then
		if debug then print("verified usercode") end
		return true
	else
		if debug then print("usercode didn't match expected") end
		return false
	end

	--return rv
end


--TODO don't think this works
--len in bits
local function prgm_usercode(usercode, len, debug)
	--! Program USERCODE
	--
	--! Shift in READ USERCODE(0x17) instruction
	--SIR	8	TDI  (17);
	pbje.goto_state("SHIFT_IR") pbje.scan( 8, 0x17)
	--SDR	32	TDI  (00000000);
	pbje.goto_state("SHIFT_DR") --pbje.scan( 32, usercode)
	--scan in 16Bytes at a time
	local send_data
	local user_len = len/4 --4bits per hex char
	while user_len > 4 do --4chars * 4bits/hexchar = 16bits will run 10x 16bits = 160bits
		send_data = string.sub(usercode, user_len-3, user_len)
		if debug then print("sending 16bits:", send_data) end
		pbje.scan_hold(16, tonumber(send_data,16) )
		user_len = user_len - 4
	end
	--16bits remain
	send_data = string.sub(usercode, 1, user_len)
	pbje.scan(user_len*4, tonumber(send_data,16))


	--! Shift in ISC PROGRAM USERCODE(0x1A) instruction
	--SIR	8	TDI  (1A);
	pbje.goto_state("SHIFT_IR") pbje.scan( 8, 0x1A)
	--RUNTEST	IDLE	5 TCK	1.00E-002 SEC;
	pbje.runtest("IDLE", 5, 0.01)
	--
	--
	--! Read the status bit
	--
	--! Shift in READ STATUS(0xB2) instruction
	--SIR	8	TDI  (B2);
	--RUNTEST	IDLE	5 TCK	1.00E-003 SEC;
	--SDR	1	TDI  (0)
	--		TDO  (0);
	check_status();


	--first put/verify jtag statemachine is in RESET
--	goto_state("RESET")

	--by default jtag should be in IDCODE or BYPASS if IDCODE not present
	--The TDI pin doesn't even have to be working to scan out IDCODE by this means
	
	--[[
	--! Program USERCODE
	--
	--! Shift in ISC PROGRAM USERCODE(0x1A) instruction
	--SIR	8	TDI  (1A);
	pbje.goto_state("SHIFT_IR")
	pbje.scan( 8, 0x1A)
	--SDR	32	TDI  (000005DE);
	pbje.goto_state("SHIFT_DR")
--	while len > 4 do
--		scan_hold( 16, tonumber(string.sub(usercode,len-3,len),16) )
--		len = len - 4
--	end
--	scan( 16, tonumber(string.sub(usercode,1,len),16) )

	--scan in 16Bytes at a time
	local send_data
	local user_len = len/4 --4bits per hex char
	while user_len > 4 do --4chars * 4bits/hexchar = 16bits will run 10x 16bits = 160bits
		send_data = string.sub(usercode, user_len-3, user_len)
		if debug then print("sending 16bits:", send_data) end
		pbje.scan_hold(16, tonumber(send_data,16) )
		user_len = user_len - 4
	end
	--16bits remain
	send_data = string.sub(usercode, 1, user_len)
	pbje.scan(user_len*4, tonumber(send_data,16))

	--RUNTEST	IDLE	3 TCK	1.30E-002 SEC;
	pbje.runtest( "IDLE", 3, 0.013) 
	--]]
	
end

local function end_row_flash()
	--! Shift in LSCC PROGRAM INCR RTI(0x67) instruction
	--SIR	8	TDI  (67);
	pbje.goto_state("SHIFT_IR") pbje.scan( 8, 0x67)
	--RUNTEST	IDLE	5 TCK	1.00E-002 SEC;
	pbje.runtest( "IDLE", 5, 0.01)
	--STATE	DRPAUSE;
	pbje.goto_state("PAUSE_DR")
	--! Shift in DATA SHIFT(0x02) instruction
	--SIR	8	TDI  (02);
	pbje.goto_state("SHIFT_IR") pbje.scan( 8, 0x02)

end

local function program_fuse_line(jed_file, debug)


	--ispLEVER .jed files have 3 lines per fuse address
	local rowdata = files.jedec_3ln_2hexstr(jed_file, false)
	local fuse_len = string.len(rowdata) --4bits per hex character
	if debug then print(fuse_len*4, "bits total, data:", rowdata) end

--! SHIFT IN DATA ROW = 1
	--pbje.goto_state("SHIFT_DR")
--SDR	172	TDI  (FFFFC1FF83E31FFE118C37805F0FC7FFFFFFF8FE7FD);

	--need to scan in fuse stream now
	--! Shift in Row = 1
	--SDR	192	TDI  (FFF7BFF3DEFFCEEFFF3BBFFCEEFFF3DFFFFDEFFF3BBFFCFF);
	pbje.goto_state("SHIFT_DR")

	
	--Now we need to program 295 lines 192bits/line (machXO-256)
	
	--if the data is all FF we can shift with TDI set to speed up process
	--when testing SNES v2.0P2 prototype, this saved ~1sec of flash time 3.5->2.5sec
	--NES machXO-256 was 10-12sec flash, & 3-6sec verify without any TDI=1 speedup
	--when grouping of 16bit FFFF chunks got ~1sec speedup on NES MachXO-256 down to 9-11sec flash time
	---[[
	if rowdata == "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF" then --48*4 = 192bits all set
		--for MMC3 file this only happens for a single line..
		if debug then print("row is all FF") end
		pbje.scan(fuse_len*4, "HIGH") --4bits per hex char
		--scan(172, "HIGH")
		--RUNTEST	IDLE	3 TCK	1.30E-002 SEC;
		--pbje.runtest( "IDLE", 3, 0.013) --appear to actually need this delay..
		--print("found row all FFFF...")
		end_row_flash()
		return --nothing else needed
	end
	--]]

	--scan in 16Bytes at a time
	local send_data
	local FFFF_count --number of chunks that are 0xFFFF
	local next_data --look ahead for speed up of high FFFF data
	while fuse_len > 4 do --4chars * 4bits/hexchar = 16bits will run 11x 16bits = 176bits
		send_data = string.sub(rowdata, fuse_len-3, fuse_len)
		if debug then print("sending 16bits:", send_data) end
		--if the data is all FF we can shift with TDI set to speed up process
		--this didn't give any speedup probably because it's still a data transfer of same size
		--to get actual speed up would have to look ahead, and see how many FFFF chunks there are and combine
		--this is all working now, and maximizes TDI "HIGH" clockings without transferring data
		--but it didn't give much speed up on the LC4032V SNES board, thinking it might give better speed up on MachXO256
		--LC4032V sometimes got down to 2.1sec from 2.5sec, but not consistent
		---[[
		if send_data == "FFFF" then
			if debug then print("found 0xFFFF block") end
			FFFF_count = 1
			fuse_len = fuse_len - 4

			next_data = string.sub(rowdata, fuse_len-3, fuse_len)
			--look ahead to see if next 16bits are also high
			while next_data == "FFFF" and fuse_len > 4 do 
				if debug then print("found more than 1 0xFFFF block") end
				FFFF_count = FFFF_count + 1
				fuse_len = fuse_len - 4
				next_data = string.sub(rowdata, fuse_len-3, fuse_len)
		--		if next_data ~= "FFFF" then
		--			FFFF_count = FFFF_count - 1
		--		end
			end

			--send total count that was 0xFFFF
			if debug then print("found", FFFF_count, "total FFFF blocks") end
			--REPORTING uncomment to get idea of how much savings there ends up being
			--if FFFF_count > 1 then print(FFFF_count, "total FFFF blocks") end
			--most are only 3-4 not a lot of savings on LC4032V
			--machXO gives a little speed up here, to 9-11sec from 10-12sec
			pbje.scan_hold(16*FFFF_count, "HIGH") --scan 16 bits with TDI forced high
			--fuse_len = fuse_len - 4*FFFF_count
		else
		--]]
			pbje.scan_hold(16, tonumber(send_data,16) )
			fuse_len = fuse_len - 4
		end
	end
	--16bits remain
	send_data = string.sub(rowdata, 1, fuse_len)
	if debug then print("sending", fuse_len*4, "bits:", send_data) end
	pbje.scan(fuse_len*4, tonumber(send_data,16))


	end_row_flash()

end


--erase & program the device
local function program(jed_file, debug)
	--! Program Bscan register
	--
	--! Shift in Preload(0x1C) instruction
	--SIR	8	TDI  (1C);
	--pbje.goto_state("SHIFT_IR") pbje.scan( 8, 0x1C)
	--SDR	160	TDI  (FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
	--pbje.goto_state("SHIFT_DR") pbje.scan( 160, "HIGH")
	--
	--
	--! Enable the programming mode
	--
	--! Shift in ISC ENABLE(0x15) instruction
	--SIR	8	TDI  (15);
	--RUNTEST	IDLE	5 TCK	1.00E-003 SEC;
	--
	--
	--! Erase the device
	--
	--! Shift in ISC SRAM ENABLE(0x55) instruction
	--SIR	8	TDI  (55);
	--RUNTEST	IDLE	5 TCK	1.00E-003 SEC;
	--! Shift in ISC ERASE(0x03) instruction
	--SIR	8	TDI  (03);
	--RUNTEST	IDLE	5 TCK	1.00E-003 SEC;
	--! Shift in ISC ENABLE(0x15) instruction
	--SIR	8	TDI  (15);
	--RUNTEST	IDLE	5 TCK	1.00E-003 SEC;
	--! Shift in ISC ERASE(0x03) instruction
	--SIR	8	TDI  (03);
	--RUNTEST	IDLE	5 TCK	1.00E+001 SEC;
	--SDR	1	TDI  (0)
	--		TDO  (1);
	--
	--
	--! Read the status bit
	--
	--! Shift in READ STATUS(0xB2) instruction
	--SIR	8	TDI  (B2);
	--RUNTEST	IDLE	5 TCK	1.00E-003 SEC;
	--SDR	1	TDI  (0)
	--		TDO  (0);
	--
--all of above done in erase
	--
	--! Program Fuse Map
	--
	--! Shift in INIT ADDRESS(0x21) instruction
	--SIR	8	TDI  (21);
	--RUNTEST	IDLE	5 TCK	1.00E-003 SEC;
	--! Shift in BYPASS(0xFF) instruction
	--SIR	8	TDI  (FF);
	--RUNTEST	IDLE	5 TCK	1.00E-003 SEC;
	--! Shift in DATA SHIFT(0x02) instruction
	--SIR	8	TDI  (02);
	--! Shift in Row = 1
	--SDR	192	TDI  (FFF7BFF3DEFFCDEFFF3BBFFCFCFFF3DFFFFDEFFF37BFFCFF);
	--! Shift in LSCC PROGRAM INCR RTI(0x67) instruction
	--SIR	8	TDI  (67);
	--RUNTEST	IDLE	5 TCK	1.00E-002 SEC;
	--STATE	DRPAUSE;
	--! Shift in DATA SHIFT(0x02) instruction
	--SIR	8	TDI  (02);
	--! Shift in Row = 2
	--SDR	192	TDI  (FFF7BFF3DEFFCDEFFF37BFFCF7FFFF7BFFCDEFFF37BFFCFF);
	--! Shift in LSCC PROGRAM INCR RTI(0x67) instruction
	--SIR	8	TDI  (67);
	--RUNTEST	IDLE	5 TCK	1.00E-002 SEC;
	--STATE	DRPAUSE;
	--! Shift in DATA SHIFT(0x02) instruction
	--SIR	8	TDI  (02);
	--! Shift in Row = 3

	erase()

	--should still be in ISC enable mode
	--! Program Fuse Map
	--
	--! Shift in INIT ADDRESS(0x21) instruction
	--SIR	8	TDI  (21);
	pbje.goto_state("SHIFT_IR") pbje.scan( 8, 0x21)

	--RUNTEST	IDLE	5 TCK	1.00E-003 SEC;
	pbje.runtest( "IDLE", 5, 0.001)
	
	--! Shift in BYPASS(0xFF) instruction
	--SIR	8	TDI  (FF);
	pbje.goto_state("SHIFT_IR") pbje.scan( 8, 0xFF)
	--RUNTEST	IDLE	5 TCK	1.00E-003 SEC;
	pbje.runtest( "IDLE", 5, 0.001)
	
	--! Shift in DATA SHIFT(0x02) instruction
	--SIR	8	TDI  (02);
	pbje.goto_state("SHIFT_IR") pbje.scan( 8, 0x02)
	
	--! Shift in Row = 1
	--SDR	192	TDI  (FFF7BFF3DEFFCEEFFF3BBFFCEEFFF3DFFFFDEFFF3BBFFCFF);
	--! Shift in LSCC PROGRAM INCR RTI(0x67) instruction
	--SIR	8	TDI  (67);
	--RUNTEST	IDLE	5 TCK	1.00E-002 SEC;
	--STATE	DRPAUSE;
	--! Shift in DATA SHIFT(0x02) instruction
	--SIR	8	TDI  (02);
	
	--Now we need to program 295 lines 192bits/line (machXO-256)
	local fuse_lines = 295
	--local fuse_lines = 2
	local errors = 0
	time.start()
	while fuse_lines > 0 do
		program_fuse_line(jed_file, false)
		fuse_lines = fuse_lines-1
	end

	time.report(192*295/8/1024) --192 bits/line, 295 lines, 8bit/byte, 1024byte/KB

--! SHIFT IN DATA ROW = 1
--SDR	172	TDI  (FFFFC1FF83E31FFE118C37805F0FC7FFFFFFF8FE7FD);
--RUNTEST	IDLE	3 TCK	1.30E-002 SEC;

--! Shift in Data Row = 2
--SDR	172	TDI  (FFFFC1FF83E31FFE118C7F807F0FC7FFFFFFF8FE7FF);
--RUNTEST	IDLE	3 TCK	1.30E-002 SEC;


	--! Shift in Row = 2
	--SDR	192	TDI  (FFF7BFF3DEFFCEEFFF37BFFCF7FFFFBBFFCEEFFF37BFFCFF);
	--! Shift in LSCC PROGRAM INCR RTI(0x67) instruction
	--SIR	8	TDI  (67);
	--RUNTEST	IDLE	5 TCK	1.00E-002 SEC;
	--STATE	DRPAUSE;
	--! Shift in DATA SHIFT(0x02) instruction
	--SIR	8	TDI  (02);
	--! Shift in Row = 3




---[[

	--! Shift in LSCC PROGRAM INCR RTI(0x67) instruction
	--SIR	8	TDI  (67);
	pbje.goto_state("SHIFT_IR") pbje.scan( 8, 0x67)
	--RUNTEST	IDLE	5 TCK	1.00E-003 SEC;
	pbje.runtest( "IDLE", 5, 0.001)
	--RUNTEST	IDLE	5 TCK	1.00E-002 SEC;
	pbje.runtest( "IDLE", 5, 0.01)
	--STATE	DRPAUSE;
	pbje.goto_state("PAUSE_DR")
	--
	--
	--! Program USERCODE
	--
	--! Shift in READ USERCODE(0x17) instruction
	--SIR	8	TDI  (17);
	--SDR	32	TDI  (00000000);
	--! Shift in ISC PROGRAM USERCODE(0x1A) instruction
	--SIR	8	TDI  (1A);
	--RUNTEST	IDLE	5 TCK	1.00E-002 SEC;
	--
	--
	--! Read the status bit
	--
	--! Shift in READ STATUS(0xB2) instruction
	--SIR	8	TDI  (B2);
	--RUNTEST	IDLE	5 TCK	1.00E-003 SEC;
	--SDR	1	TDI  (0)
	--		TDO  (0);
	--
	--
	--! Verify Fuse Map


	--need to read expected user code from jedec file
	debug = true
	local filecode = files.readtill_line(jed_file, "U0")
	if debug then print("file usercode line:", filecode) end
	filecode = string.sub(filecode, 3, 10)
	if debug then print("hex usercode:", filecode) end

	prgm_usercode(filecode, 32, true)
	

	--local usercode = check_usercode(0x000005DE, 32)
	if check_usercode(filecode, 32, true) then
		print("SUCCESS! VERIFIED USER CODE")
	else
		print("FAILED! USER CODE VERIFICATION")
	end

	--The svf file leaves CPLD in this state while verifying, but
	--the verify svf proves we should be able to leave this state during verification steps

	--]]
	
	check_status()

	done_exit(debug)

end



--! Secure device
--
--! Shift in ISC PROGRAM SECURITY(0x09) instruction
--SIR	8	TDI  (09);
--RUNTEST	IDLE	5 TCK	5.00E-002 SEC;
--STATE	IDLE;
--
--
--! Read the status bit
--
--! Shift in READ STATUS(0xB2) instruction
--SIR	8	TDI  (B2);
--RUNTEST	IDLE	5 TCK	1.00E-003 SEC;
--SDR	1	TDI  (0)
--		TDO  (0);
--

--TODO this is still just LC4000V version
local function secure(debug)
--! Enable the programming mode
--
--! Shift in ISC ENABLE(0x15) instruction
--SIR	8	TDI  (15);
	pbje.goto_state("SHIFT_IR") pbje.scan( 8, 0x15)
--RUNTEST	IDLE	3 TCK	2.00E-002 SEC;
	pbje.runtest( "IDLE", 3, 0.02)

--! Secure device
--
--! Shift in ISC PROGRAM SECURITY(0x09) instruction
--SIR	8	TDI  (09);
	pbje.goto_state("SHIFT_IR") pbje.scan( 8, 0x09)
--RUNTEST	IDLE	3 TCK	5.00E-002 SEC;
	pbje.runtest( "IDLE", 3, 0.05)
	pbje.goto_state("IDLE")
--STATE	IDLE;
--
	done_exit(debug)
end


local function verify_fuse_line(jed_file, debug)
	--! Shift Out Data Row = 1
	--SDR	192	TDI  (FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
	--		TDO  (FFF7BFF3DEFFCDEFFF3BBFFCFCFFF3DFFFFDEFFF37BFFCFF);
	--RUNTEST	IDLE	5 TCK	1.00E-003 SEC;

	--! Shift Out Data Row = 1
	--SDR	192	TDI  (FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
	--		TDO  (FFF7BFF3DEFFCEEFFF3BBFFCEEFFF3DFFFFDEFFF3BBFFCFF);
	--RUNTEST	IDLE	5 TCK	1.00E-003 SEC;
	--! Shift Out Data Row = 2
	--SDR	192	TDI  (FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
	--		TDO  (FFF7BFF3DEFFCEEFFF37BFFCF7FFFFBBFFCEEFFF37BFFCFF);
	--RUNTEST	IDLE	5 TCK	1.00E-003 SEC;
	--! Shift Out Data Row = 3
	

	pbje.goto_state("SHIFT_DR")
	--192 bits, shift out 64 * 3 = 192

	local read_str
	--first 64bits
	dout = pbje.scan_hold( 64, "HIGH", true)
	read_str =            string.format("%16.16X",dout)
	if debug then print("return data:", string.format(" %16.16X, ",dout)) end

	--second 64bits (now 128total)
	dout = pbje.scan_hold( 64, "HIGH", true)
	read_str =            string.format("%16.16X",dout) .. read_str
	if debug then print("return data:", string.format(" %16.16X, ",dout)) end

	--last 64bits (192 total)
	dout = pbje.scan( 64, "HIGH", true)
	if debug then print("return data:", string.format(" %16.16X, ",dout)) end
	--print("return data:", string.sub(string.format("%16.16X", dout) , 6, 16))
	--if debug then print("return data:", string.sub(string.format("%16.16X", dout) , ((64-44)/4)+1, (64/4))) end
	--read_str =            string.sub(string.format("%16.16X", dout) , ((64-44)/4)+1, (64/4)) .. read_str
	read_str =            string.format("%16.16X",dout) .. read_str
	if debug then print(read_str) end

	--! Shift Out Data Row = 2
	--SDR	192	TDI  (FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
	--		TDO  (FFF7BFF3DEFFCEEFFF37BFFCF7FFFFBBFFCEEFFF37BFFCFF);
	--RUNTEST	IDLE	5 TCK	1.00E-003 SEC;
	pbje.runtest( "IDLE", 5, 0.001)

	--ispLEVER .jed files have 3 lines per fuse address
	local tempdata = files.jedec_3ln_2hexstr(jed_file, false)
	if debug then print (tempdata) end
	if string.match(tempdata, read_str) and (string.len(tempdata) == string.len(read_str)) then
		if debug then print("verified line!") end
		return true
	else
		if debug then print("failed to verify line") end
		return false
	end

--	tempdata = files.jedec_3ln_2hexstr(jed_file, false)
--	print (tempdata)
--	tempdata = files.jedec_3ln_2hexstr(jed_file, false)
--	print (tempdata)
--	tempdata = files.jedec_3ln_2hexstr(jed_file, false)
--	print (tempdata)
	
	--
	--RUNTEST	IDLE	3 TCK	1.00E-003 SEC;
--	runtest( "IDLE", 3, 0.001)
--	goto_state("SHIFT_DR")
--	--! Shift Out Data Row = 2
--	dout = pbje.scan_hold( 64, "LOW", true)
--	print("return data:", string.format(" %X, ",dout))
--	dout = pbje.scan_hold( 64, "LOW", true)
--	print("return data:", string.format(" %X, ",dout))
--	dout = pbje.scan( 44, "LOW", true)
--	print("return data:", string.format(" %X, ",dout))
	--SDR	172	TDI  (0000000000000000000000000000000000000000000)
	--		TDO  (FFFFC1FF83E31FFE118C7F807F0FC7FFFFFFF8FE7FF);
	--RUNTEST	IDLE	3 TCK	1.00E-003 SEC;
	--! Shift Out Data Row = 3
	--SDR	172	TDI  (0000000000000000000000000000000000000000000)
	--		TDO  (BFFFC1FF83E31FFE118C7E807F0FC7FFFFFFF8FE7FF);
	--RUNTEST	IDLE	3 TCK	1.00E-003 SEC;
	--! Shift Out Data Row = 4
	--SDR	172	TDI  (0000000000000000000000000000000000000000000)
	--		TDO  (FFFFC1FF83E31FFE118C6F807F0FC7FFFFFFF8FE7FB);
	--RUNTEST	IDLE	3 TCK	1.00E-003 SEC;
	--! Shift Out Data Row = 5
	--SDR	172	TDI  (0000000000000000000000000000000000000000000)
	--		TDO  (FFFFC1FF83E31FFE118C7F807F0FC7FFFFFFF8FE7FF);
	--RUNTEST	IDLE	3 TCK	1.00E-003 SEC;
	-- ....
end


--TODO finish usercode verification portion
local function verify(jed_file, debug)

	--! Check the IDCODE
	--
	check_idcode()
	--! Shift in IDCODE(0x16) instruction
	--SIR	8	TDI  (16);
	--SDR	32	TDI  (FFFFFFFF)
	--		TDO  (01281043)
	--		MASK (FFFFFFFF);
	--
	--
	--! Program Bscan register
	--
	--! Shift in Preload(0x1C) instruction
	--SIR	8	TDI  (1C);
	pbje.goto_state("SHIFT_IR") pbje.scan( 8, 0x1C)
	--RUNTEST	IDLE	5 TCK	1.00E-003 SEC;
	pbje.runtest( "IDLE", 5, 0.001 )
	--SDR	160	TDI  (FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
	pbje.goto_state("SHIFT_DR") pbje.scan( 160, "HIGH")
	--
	--
	--! Enable the programming mode
	--
	--! Shift in ISC ENABLE(0x15) instruction
	--SIR	8	TDI  (15);
	pbje.goto_state("SHIFT_IR") pbje.scan( 8, 0x15)
	--RUNTEST	IDLE	5 TCK	1.00E-003 SEC;
	pbje.runtest( "IDLE", 5, 0.001 )
	--
	--
	--! Verify Fuse Map
	--
	--! Shift in LSCC RESET ADDRESS(0x21) instruction
	--SIR	8	TDI  (21);
	pbje.goto_state("SHIFT_IR") pbje.scan( 8, 0x21)
	--RUNTEST	IDLE	5 TCK	1.00E-003 SEC;
	pbje.runtest( "IDLE", 5, 0.001 )

	--! Shift in BYPASS(0xFF) instruction
	--SIR	8	TDI  (FF);
	pbje.goto_state("SHIFT_IR") pbje.scan( 8, 0xFF)
	--RUNTEST	IDLE	5 TCK	1.00E-003 SEC;
	pbje.runtest( "IDLE", 5, 0.001 )

	--! Shift in LSCC READ INCR RTI(0x6A) instruction
	--SIR	8	TDI  (6A);
	pbje.goto_state("SHIFT_IR") pbje.scan( 8, 0x6A)
	--RUNTEST	IDLE	5 TCK	1.00E-003 SEC;
	pbje.runtest( "IDLE", 5, 0.001 )

	--! Shift Out Data Row = 1
	--SDR	192	TDI  (FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
	--		TDO  (FFF7BFF3DEFFCDEFFF3BBFFCFCFFF3DFFFFDEFFF37BFFCFF);
	--RUNTEST	IDLE	5 TCK	1.00E-003 SEC;
	--! Shift Out Data Row = 2
	--SDR	192	TDI  (FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
	--		TDO  (FFF7BFF3DEFFCDEFFF37BFFCF7FFFF7BFFCDEFFF37BFFCFF);
	--RUNTEST	IDLE	5 TCK	1.00E-003 SEC;
	--! Shift Out Data Row = 3
	

	--Now we need to read and verify 100 lines 172bits/line (LC4032V)
	--local fuse_lines = 2
	local fuse_lines = 295
	local errors = 0
	time.start()
	while fuse_lines > 0 do
		if not verify_fuse_line(jed_file, false) then
			print("FAILED TO VERIFY LINE", fuse_lines)
			errors = errors+1
		end
		fuse_lines = fuse_lines-1
	end

	if errors == 0 then
		print("SUCCESSFULLY Verified all fuse lines!")
	else
		print(errors, "errors were found when trying to verify all fuse lines. FAILED!")
	end
	time.report(192*295/8/1024) --192 bits/line, 295 lines, 8bit/byte, 1024byte/KB
	

--[[LC4000V
	--! Check the IDCODE
	--
	--! Shift in IDCODE(0x16) instruction
	--SIR	8	TDI  (16);
	--STATE	IDLE;
	--SDR	32	TDI  (FFFFFFFF)
	--		TDO  (01805043)
	--		MASK (0FFFFFFF);
	check_idcode()

	--
	--! Program Bscan register
	--
	--! Shift in Preload(0x1C) instruction
	--SIR	8	TDI  (1C);
	pbje.goto_state("SHIFT_IR")
	pbje.scan( 8, 0x1C)
	--SDR	68	TDI  (00000000000000000);
	pbje.goto_state("SHIFT_DR")
	pbje.scan( 68, "LOW")
--local function scan( numbits, data_in, data_out, debug )
	--
	--
	--! Enable the programming mode
	--
	--! Shift in ISC ENABLE(0x15) instruction
	pbje.goto_state("SHIFT_IR")
	pbje.scan( 8, 0x15)
	--SIR	8	TDI  (15);
	--RUNTEST	IDLE	3 TCK	2.00E-002 SEC;
	pbje.runtest( "IDLE", 3, 0.02 )
	--
	--
	--! Full Address Verify Fuse Map
	--
	--! Shift in ISC ADDRESS SHIFT(0x01) instruction
	--SIR	8	TDI  (01);
	pbje.goto_state("SHIFT_IR")
	pbje.scan( 8, 0x01)
	--SDR	100	TDI  (8000000000000000000000000);
	pbje.goto_state("SHIFT_DR")
--	HERE
	pbje.scan_hold( 84, "LOW")
	pbje.scan( 16, 0x8000)

	--! Shift in ISC READ INCR(0x2A) instruction
	--SIR	8	TDI  (2A);
	pbje.goto_state("SHIFT_IR")
	pbje.scan( 8, 0x2A)
	--RUNTEST	IDLE	3 TCK	1.00E-003 SEC;
	pbje.runtest( "IDLE", 3, 0.001)



	--Now we need to read and verify 100 lines 172bits/line (LC4032V)
	local fuse_lines = 100
	local errors = 0
	time.start()
	while fuse_lines > 0 do
		if not verify_fuse_line(jed_file, false) then
			print("FAILED TO VERIFY LINE", fuse_lines)
			errors = errors+1
		end
		fuse_lines = fuse_lines-1
	end

	if errors == 0 then
		print("SUCCESSFULLY Verified all fuse lines!")
	else
		print(errors, "errors were found when trying to verify all fuse lines. FAILED!")
	end
	time.report(172*100/8/1024) --172 bits/line, 100 lines, 8bit/byte, 1024byte/KB
	
	--! Verify USERCODE
	--
	--! Shift in READ USERCODE(0x17) instruction
	--SIR	8	TDI  (17);
	--SDR	32	TDI  (FFFFFFFF)
	--		TDO  (000005DE);
	--need to read expected user code from jedec file
	local filecode = files.readtill_line(jed_file, "UH")
	if debug then print("file usercode line:", filecode) end
	filecode = string.sub(filecode, 3, 10)
	if debug then print("hex usercode:", filecode) end
	--local usercode = check_USERCODE(0x000005DE, 32)
	if check_usercode(filecode, 32) then
		print("SUCCESS! VERIFIED USER CODE")
	else
		print("FAILED! USER CODE VERIFICATION")
	end

	--]]
	done_exit(debug)

	--
	--
	--! Exit the programming mode
	--
	--! Shift in ISC DISABLE(0x1E) instruction
	--SIR	8	TDI  (1E);
	--RUNTEST	IDLE	3 TCK	2.00E-001 SEC;
	--
	--
	--
	--! Shift in IDCODE(0x16) instruction
	--SIR	8	TDI  (16)
	--		TDO  (1D)
	--		MASK (FF);
	
	check_idcode()
end

-- global variables so other modules can use them


-- call functions desired to run when script is called/imported


-- functions other modules are able to call
machXO256.done_exit = done_exit
machXO256.erase = erase
machXO256.program = program
machXO256.verify = verify
machXO256.secure = secure


-- return the module's table
return machXO256

