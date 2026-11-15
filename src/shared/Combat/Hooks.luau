--[[
	Hooks (ModuleScript)
	Location: ReplicatedStorage > Shared > Combat > Hooks

	A tiny event dispatcher. The combat simulation fires named hooks at key
	moments and passes a mutable context table. Seasonal mechanics (elements,
	relics, curses, partner bonds) register handlers that read or change that
	context, so combat code never needs rewriting for a new season.

	  local hooks = Hooks.new()
	  local disconnect = hooks:On("OnCalculateDamage", function(ctx)
	      ctx.Amount *= 1.2
	  end)
	  hooks:Fire("OnCalculateDamage", ctx)
	  disconnect()
]]

local Hooks = {}
Hooks.__index = Hooks

function Hooks.new()
	return setmetatable({ _handlers = {} }, Hooks)
end

-- Registers a handler. Returns a function that removes it again.
function Hooks:On(eventName, handler)
	local list = self._handlers[eventName]
	if list == nil then
		list = {}
		self._handlers[eventName] = list
	end
	table.insert(list, handler)

	return function()
		local index = table.find(list, handler)
		if index then
			table.remove(list, index)
		end
	end
end

-- Calls every handler for the event, in registration order, and returns ctx.
function Hooks:Fire(eventName, ctx)
	local list = self._handlers[eventName]
	if list then
		-- Iterate a copy so handlers may disconnect themselves while firing.
		for _, handler in ipairs(table.clone(list)) do
			handler(ctx)
		end
	end
	return ctx
end

return Hooks
