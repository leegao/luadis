local utils = require "utils"
local ir = require "ir"

local cir_transforms = {}

-- replace instances of lt/le/eq/testset with cjumps
-- first need to replace all tests with testsets

function cir_transforms.replace_tests(func)
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
		func_copy.funcs[i] = cir_transforms.replace_tests(f)
	end
	
	return func_copy
end

-- next, we need to augment the instruction set with ir.labels

function cir_transforms.add_label(func)
	local func_copy = utils.copy(func)
	local jump_target = {}
	for pc,op in ipairs(func_copy.instructions) do
		-- if conditional, add pc+2 into the list of targets
		if utils.find({"LT","LE","EQ","TESTSET"},op.op) then
			table.insert(jump_target, pc+2)
			op.to = pc+2
		elseif utils.find({"JMP", "FORLOOP"}, op.op) then
			table.insert(jump_target, pc+1+op.sBx)
			op.to = pc+1+op.sBx
		elseif op.op == "LOADBOOL" and op.C ~= 0 then
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
		func_copy.funcs[_] = cir_transforms.add_label(f)
	end
	
	return func_copy
end


chunk = require "chunk"
reader = require "reader"

local ctx = reader.new_ctx(string.dump(loadfile 'test.lua'))
chunk.header(ctx)
local func = chunk.func(ctx)

func = cir_transforms.replace_tests(func)
func = cir_transforms.add_label(func)

for i,v in ipairs(func.instructions) do print(i,v) end

return cir_transforms