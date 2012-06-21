
--ut the number of arguments of a lua function
function num_args(f)
	local ok, t = pcall(string.dump,f)
	if not ok then return nil end
	local o = t:byte(13)+t:byte(14)*0x100+t:byte(15)*0x10000+t:byte(16)*0x1000000
	return t:sub(26+o):byte()
end

local __Gmt = getmetatable(_G) or {}
local __o_index = __Gmt.__index
local func_key = {}

function __Gmt:__index(key)
	if __o_index then
		-- old index over-rules new index, if anything is returned there, immediately return here
		local ret = __o_index(self, key)
		if ret ~= nil then return ret end
	end

	local funcs = func_key[key]
	if funcs then
		-- funcs is an ORDERED list of number of arguments and function
		return function(...)
			local args = {...}
			for _,fstruct in ipairs(funcs) do
				local n,f = unpack(fstruct)
				-- we call the function with the next largest.
				if #args <= n then
					return f(unpack(args))
				end
			end
			-- if we ever reach this point, just use the last function
			funcs[#funcs][2](unpack(args))
		end
	end
end

function __Gmt:__newindex(key, value)
	-- check that the function can actually be overloaded
	local n = num_args(value)
	if not n then
		-- just rawset
		func_key[key] = nil
		return rawset(self, key, value)
	end
	-- we could've rawsetted earlier, so rawset to nil
	rawset(self, key, nil)
	-- check if func_key contains key
	local funcs = func_key[key] or {}
	-- next, append into funcs
	table.insert(funcs, {n, value})
	-- funally, we sort funcs
	table.sort(funcs, function(a,b) return a[1] < b[1] end)
	func_key[key] = funcs
end

setmetatable(_G, __Gmt)

--[[-- Example

function f(x)
	print("in f(x) with",x)
	return x
end

function f(x,y)
	print("in f(x,y) with",x,y)
	return math.sqrt(x^2 + y^2)
end

print(f(), f(1), f(1,2))

f = 10

print(f)

f = nil

print(f)

--]]--
