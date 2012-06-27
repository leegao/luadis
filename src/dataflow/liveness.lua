local opcode = require "opcode"
local utils  = require "utils"
local ir     = require "ir"

local liveness = {}

local function r(x)
	return type(x) == "table" and x.r
end

-- Live variable analysis
-- Basic Equation: LIVE_IN[x] = GEN(x) U (LIVE_OUT[x] - KILL(x))
--                 LIVE_OUT[x] = \Union_{p \in succ(x)} LIVE_IN[p]


function liveness.gen(cfg, tos)
	local op = cfg.ir
	if op.op == "MOVE" then
		-- OP_MOVE,/*	    A B		R(A) := R(B)					*/
		return {op.B}
	elseif op.op == "GETTABLE" then
		-- OP_GETTABLE,/*	A B C	R(A) := R(B)[RK(C)]				*/
		return utils.filter({op.B, op.C}, r)
	elseif op.op == "SETGLOBAL" or op.op == "SETUPVAL" then
		-- OP_SETGLOBAL,/*	A Bx	Gbl[Kst(Bx)] := R(A)				*/
		return {op.A}
	elseif op.op == "SETTABLE" then
		-- OP_SETTABLE,/*	A B C	R(A)[RK(B)] := RK(C)				*/
		return utils.filter({op.A, op.B, op.C}, r)
	elseif op.op == "SELF" then
		-- OP_SELF,/*	    A B C	R(A+1) := R(B); R(A) := R(B)[RK(C)]		*/
		return utils.filter({op.B, op.C}, r)
	elseif utils.find({'ADD','SUB','MUL','DIV','MOD','POW'}, op.op) then
		-- OP_ADD,/*	    A B C	R(A) := RK(B) + RK(C)				*/
		return utils.filter({op.B, op.C}, r)
	elseif utils.find({'UNM', 'NOT', 'LEN'}, op.op) then
		-- OP_UNM,/*	    A B		R(A) := -R(B)					*/
		return {op.B}
	elseif op.op == "CONCAT" then
		-- OP_CONCAT,/*	A B C	R(A) := R(B).. ... ..R(C)			*/
		local ret = {}
		for i=op.B.r,op.C.r do
			table.insert(ret, ir.R(i))
		end
		return ret
	elseif utils.find({'EQ', 'LT', 'LE', 'TESTSET'}, op.op) then
		-- OP_EQ,/*	    A B C	if ((RK(B) == RK(C)) ~= A) then pc++		*/
		return utils.filter({op.B, op.C}, r)
	elseif op.op == "TEST" then
		-- OP_TEST,/*	    A C		if not (R(A) <=> C) then pc++			*/
		return {op.A}
	elseif op.op == "CALL" or op.op == "TAILCALL" then
		-- OP_CALL,/*	    A B C	R(A), ... ,R(A+C-2) := R(A)(R(A+1), ... ,R(A+B-1)) */
		local ret = {}
		for i=op.A.r,op.A.r+op.B.v-1 do
			table.insert(ret, ir.R(i))
		end
		
		if op.B.v == 0 then
			for i=op.A.r,tos do
				table.insert(ret, ir.R(i))
			end
		end
		
		return ret
	elseif op.op == "RETURN" then
		-- OP_RETURN,/*	A B		return R(A), ... ,R(A+B-2)	(see note)	*/
		local ret = {}
		for i=op.A.r,op.A.r+op.B.v-2 do
			table.insert(ret, ir.R(i))
		end
		
		if op.B.v == 0 then
			for i=op.A.r,tos do
				table.insert(ret, ir.R(i))
			end
		end
		
		return ret
	elseif op.op == "FORLOOP" then
		-- OP_FORLOOP,/*	A sBx	R(A)+=R(A+2);
		--				if R(A) <?= R(A+1) then { pc+=sBx; R(A+3)=R(A) }*/
		return {op.A, ir.R(op.A.r+1), ir.R(op.A.r+2)}
	elseif op.op == "FORPREP" then
		-- OP_FORPREP,/*	A sBx	R(A)-=R(A+2); pc+=sBx				*/
		return {op.A, ir.R(op.A.r+2)} 
	elseif op.op == "TFORLOOP" then
		-- OP_TFORLOOP,/*	A C		R(A+3), ... ,R(A+2+C) := R(A)(R(A+1), R(A+2));
		return {op.A, ir.R(op.A.r+1), ir.R(op.A.r+2)}
	elseif op.op == "SETLIST" then
		-- OP_SETLIST,/*	A B C	R(A)[(C-1)*FPF+i] := R(A+i), 1 <= i <= B	*/
		local ret = {}
		for i=op.A.r,op.A.r+op.B.v do
			table.insert(ret, ir.R(i))
		end
		return ret
	end
	
	return {}
end

function liveness.kill(cfg, tos)
	local op = cfg.ir
	if op.op == "LOADNIL" then
		local ret = {}
		for i=op.A.r,op.B.r do
			table.insert(ret, ir.R(i))
		end
		return ret
	elseif op.op == "SELF" then
		return {op.A, ir.R(op.A.r+1)}
	elseif op.op == "CALL" then
		local ret = {}
		for i=op.A.r,op.A.r+op.C.v-2 do
			table.insert(ret, ir.R(i))
		end
		
		if op.C.v == 0 then
			for i=op.A.r,tos do
				table.insert(ret, ir.R(i))
			end
		end
		
		return ret
	elseif op.op == "FORLOOP" then
		return {op.A, ir.R(op.A.r+3)}
	elseif op.op == "TFORLOOP" then
		local ret = {}
		for i=op.A.r,op.A.r+op.C.v+2 do
			table.insert(ret, ir.R(i))
		end
		
		return ret
	elseif op.op == "VARARG" then
		local ret = {}
		for i=op.A.r,op.A.r+op.B.v-1 do
			table.insert(ret, ir.R(i))
		end
		
		return ret
	elseif utils.find({'SETGLOBAL', 'SETUPVAL', 'SETTABLE','JMP', 'EQ', 'LT', 'LE', 'TEST', 'CLOSE', 'TAILCALL', 'RETURN', 'SETLIST'}, op.op) then
		return {}
	end
	return {op.A}
end

function liveness.analyze(cfg, func_env)
	local tos = (func_env and func_env.stack_size) or 256
	local queue, seen = {}, {}
	local function build_queue(node)
		if seen[node] then return end
		seen[node] = true
		table.insert(queue, node)
		node.annotations.gen = liveness.gen(node, tos)
		
		node.annotations.kill = liveness.kill(node, tos)
		-- print(node.ir, unpack(node.annotations.gen))
		-- print("\tkill", unpack(node.annotations.kill))
		node.annotations.live_in = {}
		if node.child1 then
			build_queue(node.child1)
		end
		
		if node.child2 then
			build_queue(node.child2)
		end
	end
	build_queue(cfg)
	while #queue > 0 do
		local node = queue[1]
		table.remove(queue, 1)
		
		local live_in = node.annotations.live_in
		local card = #live_in
		
		local live_out = {}
		for _,p in ipairs(node:succ()) do
			live_out = utils.union(live_out, p.annotations.live_in)
		end
		
		local rhs = utils.difference(live_out, node.annotations.kill)
		live_in = utils.union(rhs, node.annotations.gen)
		
		-- print(node.ir, #live_in, card, unpack(live_in))
		-- print("\tgen:  ",unpack(node.annotations.gen))
		-- print("\tout:  ",unpack(live_out))
		-- print("\tkill: ",unpack(node.annotations.kill))
		
		-- check for changes
		if #live_in ~= card then
			node.annotations.live_in = live_in
			for _,parent in ipairs(node:pred()) do
				if not utils.find(queue, parent) then
					table.insert(queue, parent)
				end
			end
		end
	end
	
	seen = {}
	local function postprocess(cfg)
		if seen[cfg] then return end
		seen[cfg] = true
		local live_out = {}
		for _,p in ipairs(cfg:succ()) do
			live_out = utils.union(live_out, p.annotations.live_in)
		end
		cfg.annotations.live_out = live_out
		if cfg.child1 then
			postprocess(cfg.child1)
		end
		
		if cfg.child2 then
			postprocess(cfg.child2)
		end
	end
	postprocess(cfg)
end

return liveness