local utils = require "utils"
local ir = require "ir"
local opcode = require "opcode"

local cir = {}

-- replace instances of lt/le/eq/testset with cjumps
-- first need to replace all tests with testsets

function cir.replace_tests(func)
	-- for now let's create a new copy of func
	local func_copy = utils.copy(func)
	
	-- Rule: TEST A C -> TESTSET A A C
	for pc,ir in ipairs(func_copy.instructions) do
		if ir.op == "TEST" then
			ir.op = "TESTSET"
			ir.B = ir.A
		end
	end
	
	for i,f in ipairs(func.funcs) do
		func_copy.funcs[i] = cir.replace_tests(f)
	end
	
	return func_copy
end

-- next, we need to augment the instruction set with ir.labels

function cir.add_label(func)
	local func_copy = utils.copy(func)
	local jump_target = {}
	for pc,op in ipairs(func_copy.instructions) do
		-- if conditional, add pc+2 into the list of targets
		if utils.find({"LT","LE","EQ","TESTSET"},op.op) then
			table.insert(jump_target, pc+2)
			op.to = pc+2
		elseif utils.find({"JMP", "FORLOOP"}, op.op) then
			table.insert(jump_target, pc+1+op.sBx.v)
			op.to = pc+1+op.sBx.v
		elseif op.op == "LOADBOOL" and op.C.v ~= 0 then
			table.insert(jump_target, pc+2)
			op.to = pc+2
		elseif op.op == "TFORLOOP" then
			table.insert(jump_target, pc+2)
			op.to = pc+2
		end
	end
	
	-- next we sort the labels based on PC and remove duplicates
	table.sort(jump_target)
	local jump_target2, targets = {},{}
	for i,v in ipairs(jump_target) do
		if not targets[v] then
			table.insert(jump_target2, v)
			targets[v] = ir.label("L"..tostring(#jump_target2))
		end
	end
	
	local instructions = func_copy.instructions
	func_copy.instructions = {}
	-- now, insert these instructions in
	local j = 1
	for  i,ir in ipairs(instructions) do
		if i == jump_target2[j] then
			table.insert(func_copy.instructions, targets[i])
			j = j + 1
			--if j > #jump_target2 then break end
		end
		
		if ir.to then
			ir.to = targets[ir.to].name
		end
		table.insert(func_copy.instructions, ir)
	end
	
	for _,f in ipairs(func.funcs) do
		func_copy.funcs[_] = cir.add_label(f)
	end
	
	return func_copy
end

-- used after adding labels
function cir.add_cjumps(funcs)
	-- transform all sequences of the form cond; jmp into a single cjmp
	local cfuncs = utils.copy(funcs)
	local instructions = {}
	local skip = false
	for pc,op in ipairs(cfuncs.instructions) do
		-- check if cond;jmp
		if skip then
			skip = false
		else
			if utils.find({'EQ', 'LT', 'LE', 'TEST', 'TESTSET'}, op.op) and cfuncs.instructions[pc+1].op == "JMP" then
				table.insert(instructions, ir.cjmp(op.op, op.A, op.B, op.C, cfuncs.instructions[pc+1].to))
				skip = true
			else
				table.insert(instructions, op)
			end
		end
	end
	cfuncs.instructions = instructions
	for _,f in ipairs(funcs.funcs) do
		cfuncs.funcs[_] = cir.add_cjumps(f)
	end
	
	return cfuncs
end

function cir.replace_loadbool(funcs)
	-- transform all sequences of the form loadbool(... C = 1) by adding a jmp afterwards
	local cfuncs = utils.copy(funcs)
	local instructions = {}
	for pc,op in ipairs(cfuncs.instructions) do
		table.insert(instructions, op)
		if op.op == "LOADBOOL" and op.C.v ~= 0 then
			local jmp = setmetatable({op = "JMP"}, opcode.OPMT)
			jmp.to = op.to
			op.to = nil
			op.C = nil
			table.insert(instructions, jmp)
		elseif op.op == "LOADBOOL" then
			op.C = nil
		end
	end
	cfuncs.instructions = instructions
	for _,f in ipairs(funcs.funcs) do
		cfuncs.funcs[_] = cir.replace_loadbool(f)
	end
	
	return cfuncs
end

function cir.replace_arith(func)
	-- for now let's create a new copy of func
	local func_copy = utils.copy(func)
	
	-- Rule: OP A B C -> OP A B C ARITH=true
	for pc,ir in ipairs(func_copy.instructions) do
		if utils.find({"ADD",          --R(A) := RK(B) + RK(C)
			"SUB",          --R(A) := RK(B) - RK(C)
			"MUL",          --R(A) := RK(B) * RK(C)
			"DIV",          --R(A) := RK(B) / RK(C)
			"MOD",          --R(A) := RK(B) % RK(C)
			"POW"          --R(A) := RK(B) ^ RK(C)
		}, ir.op) then
			ir.arith = true
		end
	end
	
	for i,f in ipairs(func.funcs) do
		func_copy.funcs[i] = cir.replace_arith(f)
	end
	
	return func_copy
end

function cir.closure(func)
	local func_copy = utils.copy(func)
	func_copy.closed_locals = {}

	local instructions = {}

	-- Rule: Closure R(A) Bx:n; (move/setup){n} -> Closure R(A) Bx:n (move/setup){n}
	local nbreaks = 0
	for pc,op in ipairs(func_copy.instructions) do
		if nbreaks > 0 then
			nbreaks = nbreaks - 1
		else
			if op.op == 'CLOSURE' then
				local child = func_copy.funcs[op.Bx.v+1]
				local n = child.nups
				nbreaks = n
				op.up_ops = {}
				for i=pc+1,pc+n do
					local up_op = func_copy.instructions[i]
					table.insert(op.up_ops, up_op)
					if up_op.op == "MOVE" then
						table.insert(func_copy.closed_locals, up_op.B)
					end
				end
			end
			table.insert(instructions, op)
		end
		
	end

	func_copy.instructions = instructions

	for i,v in ipairs(func_copy.funcs) do
		func_copy.funcs = cir.closure(v)
	end

	return func_copy
end

chunk = require "chunk"
reader = require "reader"
local liveness = require "dataflow.liveness"
local cfg = require "cfg"

local ctx = reader.new_ctx(string.dump(loadfile "test.lua"))
chunk.header(ctx)
local func = chunk.func(ctx)

func = cir.replace_tests(func)
func = cir.add_label(func)
func = cir.add_cjumps(func)
func = cir.replace_loadbool(func)
func = cir.replace_arith(func)
func = cir.closure(func)
ir.func = func

for pc,op in ipairs(func.instructions) do
	print(pc, op)
end



local root = cfg.cfg(func)



liveness.analyze(root)

print('\n'..root:dot())


return cir