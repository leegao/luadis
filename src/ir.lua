local ir = {}

function ir.label(name)
	return setmetatable({op="LABEL", name = name, ir=true},{
		__tostring = function(self) 
			return "."..tostring(self.name) 
		end, 
		__eq = function (self, other) 
			return type(other) == "table" and other.name == self.name 
		end})
end

return ir