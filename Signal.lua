-- A class that acts like bindable events using coroutines.
-- This code was created by somebody else, however I changed it.

-- One example, the Disconnect method doesn't iterate through the whole class, but is what is returned by the Connect method, like it
-- has always been with events.

-- Another example: You are now able to use the 'deprecated' functions' naming if you don't like PascalCase

local Signal = {}
Signal.__index = Signal

function Signal.new() 
	return setmetatable({}, Signal) 
end

function Signal:Fire(...)
	for index = 1, #self, 1 do
		coroutine.wrap(self[index])(...)
	end
end

function Signal:Wait()
	local Thread = coroutine.running()

	local function Yield(...)
		self:Disconnect(Yield)
		coroutine.resume(Thread, ...)
	end

	self[#self + 1] = Yield
	return coroutine.yield()
end

function Signal:Connect(Function)
	local newIndex = #self + 1
	self[newIndex] = Function
	
	return {
		Disconnect = function(_)
			self[newIndex]	= nil
			Function = nil
		end
	}
end

function Signal:Destroy()
	for Index = 1, #self, 1 do
		self[Index] = nil
	end
	
	self = nil
end

function Signal:wait()
   self:Wait()
end

function Signal:connect(Function)
   self:Connect(Function)
end

function Signal:destroy()
   self:Destroy()
end

return Signal
