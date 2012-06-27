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

return utils