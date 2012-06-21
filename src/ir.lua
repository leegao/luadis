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

function ir.cjmp(op, A, B, C, to)
	return setmetatable({op="CJMP", cond = op, A = A, B = B, C = C, to = to, ir=true},{
		__tostring = function(self) 
			return string.format("CJMP(op=%s, %s, %s, %s, to = %s)", self.cond, self.A, self.B or '', self.C, self.to)
		end})
end

return ir