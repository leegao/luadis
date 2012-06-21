local dot = require "dot"

local CFG = {id = 0}
local cfg_mt = {__index=cfg_mt}

function CFG.new(ir, env)
	local cfg = setmetatable({}, cfg_mt)
	cfg.parents = {}
	cfg.child1 = nil
	cfg.child2 = nil
	cfg.ir = ir
	cfg.id = CFG.id
	CFG.id = CFG.id + 1
	return cfg
end

function cfg_mt:__eq(other)
	return type(other) == "table" and other.id == self.id
end

function cfg_mt:succ()
	local succ = {}
	if self.child1 then
		table.insert(succ, self.child1)
	end
	if self.child2 then
		table.insert(succ, self.child1)
	end
	return succ
end

function cfg_mt:pred()
	return {unpack(self.parents)}
end

function cfg_mt:insert_before(prev)
	prev.parents = parents
	for _,	last in ipairs(self:pred()) do
		if last.child1 == self then
			last.child1 = prev
		else
			last.child2 = prev
		end
	end
	prev.child1 = self
	self.parents = {prev}
end

function CFG.first_pass(func, jumps)
	-- annotate instructions that are jumped to
	for _,inst in ipairs(func.instructions) do
		
	end
end

local function create_cfg(func)
	
end

-- a few transformation rules

-- LT/EQ/LE/TEST