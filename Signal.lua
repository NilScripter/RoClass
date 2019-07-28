-- A class that acts like bindable events using coroutines.
-- This code uses the normal way of creating Connections with coroutines.
-- You are able to use the 'deprecated' functions' naming if you don't like PascalCase

-- A class that acts like bindable events using coroutines.

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
	local thread = coroutine.running()
	local connection

	local function yield(...)
		connection:Disconnect(yield)
		coroutine.resume(thread, ...)
		return ...
	end
	
	connection = self:Connect(yield)
	return coroutine.yield()
end

function Signal:Connect(func)
	local newIndex = #self + 1
	self[newIndex] = func
	
	local returnTable
	local function disconnect()
		returnTable.Connected = false
		returnTable.connected = false
		
		self[newIndex] = nil
		func = nil
		returnTable.disconnect = nil
		returnTable.Disconnect = nil
		disconnect = nil
		returnTable = nil
	end
	
	returnTable = {
		Connected = false;
		connected = false;
		
		Disconnect = disconnect;
		disconnect = disconnect;
	}
	
	return returnTable
end

function Signal:Destroy()
	for Index = 1, #self, 1 do
		self[Index] = nil
	end
	
	self = nil
end

function Signal:wait()
   return self:Wait()
end

function Signal:connect(func)
   return self:Connect(func)
end

function Signal:destroy()
   self:Destroy()
end

function Signal:fire(...)
	self:Fire(...)
end

return Signal
