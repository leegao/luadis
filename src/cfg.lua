local dot = require "dot"

local CFG = {id = 0}
local cfg_mt = {__index=cfg_mt}

function CFG.new(ir, closure)
	local cfg = setmetatable({}, cfg_mt)
	cfg.parents = {}
	cfg.child1 = nil
	cfg.child2 = nil
	cfg.ir = ir
	cfg.id = CFG.id
	CFG.id = CFG.id + 1
	cfg.closure = closure
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
	local prev, current, root
	for _,stmt in ipairs(func.instructions) do
		if not root then
			root = CFG.new(stmt, func)
			current = root
		else
			current = CFG.new(stmt)
		end
		
		if prev then
			table.insert(current.parents, prev)
			prev.child1 = current
		end
		
		if stmt.op == "LABEL" then
			jumps[stmt.name] = current
		end
		
		prev = current
	end
	
	return root
end

local function create_cfg(func)
	
end

-- a few transformation rules

-- LT/EQ/LE/TEST

return CFG