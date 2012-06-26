local opcode = require "opcode"

local liveness = {}

-- Live variable analysis
-- Basic Equation: LIVE_IN[x] = GEN(x) U (LIVE_OUT[x] - KILL(x))
--                 LIVE_OUT[x] = \Union_{p \in succ(x)} LIVE_IN[p]
-- GEN (use) and KILL (def) should be simple, but the addition of escaped variables (upvalues) and CLOSE makes this a tad bit more difficult

function gen(cfg)
	
end

return liveness