--[[-- 
	CFG specifying tiling rules
	
	ARITH(OP, A, B, C) -> tile(A = B op C)
	tile(B = C op1 D); ARITH(OP2, A, B, E) -> tile(A = (C op1 D) op2 E) if B is not live out of the second
	
--]]--

local tile = {}
