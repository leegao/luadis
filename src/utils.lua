local utils = {}

function utils.copy(t)
	if type(t) ~= "table" then return t end
	local seen = {} -- for circular references
	local function _copy(t, tab)
		for k,v in pairs(t) do
			if type(v) == "table" and not v.r and not v.k and not v.v then
				if not seen[v] then 
					seen[v] = {}
					_copy(v, seen[v])
					tab[k] = seen[v]
				end
			else
				tab[k] = v
			end
		end
		
		setmetatable(tab, getmetatable(t) or {})
	end
	local tab = {}
	_copy(t, tab)
	return tab
end

function utils.find(t, v)
	for _,k in pairs(t) do
		if k == v then return _ end
	end
end

function utils.filter(t, f)
	local t2 = {}
	for i,v in ipairs(t) do
		if f(v) then
			table.insert(t2, v)
		end
	end
	return t2
end

function utils.set(t)
	local s = {}
	for _,v in ipairs(t) do s[v] = true end
	t = {}
	for k,_ in pairs(s) do table.insert(t, k) end
	return t
end

function utils.union(a, b)
	a = {unpack(a)}
	for _,b_ in ipairs(b) do
		if not utils.find(a, b_) then table.insert(a, b_) end
	end
	return utils.set(a)
end

function utils.intersection(a, b)
	local ret = {}
	for _,b_ in ipairs(b) do
		if utils.find(a, b_) then table.insert(ret, b_) end
	end
	return utils.set(ret)
end

function utils.difference(a, b)
	local ret = {}
	for _,a_ in ipairs(a) do
		if not utils.find(b, a_) then table.insert(ret, a_) end
	end
	return utils.set(ret)
end

return utils