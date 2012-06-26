local utils = require "utils"

local CFG = {id = 0}
local cfg_mt = {}
cfg_mt.__index = cfg_mt

function CFG.new(ir, closure)
	local cfg = setmetatable({}, cfg_mt)
	cfg.parents = {}
	cfg.child1 = nil
	cfg.child2 = nil
	cfg.ir = ir
	cfg.id = CFG.id
	CFG.id = CFG.id + 1
	cfg.closure = closure
	cfg.annotations = {}
	return cfg
end

function cfg_mt:dot()
	return 'digraph G{\n'..self:_dot({}).."}"
end

function cfg_mt:_dot(seen)
	if seen[self.id] then
		return ""
	else
		seen[self.id] = self
	end
	
	local str = ""
	
	if #self:pred() == 0 then
		str = str .. "\tstart -> n" .. self.id .. "\n"
	end
	
	local out = "["
	
	str = str .. "\t" .. "n"..self.id.." [label=\"" .. tostring(self.ir) .. "\"]\n"
	
	for _,child in ipairs(self:succ())  do
		str = str .. "\tn"..self.id.." -> n"..child.id.."\n"
	end
	
	if #self:succ() == 0 then
		str = str .. "\tn" .. self.id .. " -> return\n"
	end
	
	if self.child1 then
		str = str .. self.child1:_dot(seen)
	end
	
	if self.child2 then
		str = str .. self.child2:_dot(seen)
	end
	
	return str
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
		table.insert(succ, self.child2)
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

function CFG.traverse(node, jumps, memoize)
	if not node then
		return
	end
	
	if memoize[node.id] then
		return node
	else
		memoize[node.id] = node
	end
	
	if node.ir.op == "JMP" then
		local to = node.ir.to
		local next = jumps[to]
		table.remove(node.child1.parents, utils.find(node.child1.parents, node))
		
		table.insert(next.parents, node)
		node.child1 = CFG.traverse(next, jumps, memoize)
	elseif utils.find({"CJMP", "FORLOOP", "TFORLOOP"}, node.ir.op) then
		local to = node.ir.to
		local next = jumps[to]
		if next then
			table.insert(next.parents, node)
			node.child2 = CFG.traverse(next, jumps, memoize)
		end
		
		CFG.traverse(node.child1, jumps, memoize)
	else
		CFG.traverse(node.child1, jumps, memoize)
	end
	
	return node
end

function CFG.cfg(func)
	local jumps = {}
	local memoize = {}
	
	local first_pass = CFG.first_pass(func, jumps)
	local second_pass = CFG.traverse(first_pass, jumps, memoize)
	
	return second_pass
end

-- a few transformation rules

-- LT/EQ/LE/TEST

return CFG