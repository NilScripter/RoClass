local classBehavior = {}
classBehavior.__index = classBehavior

function classBehavior.new(overrideSelf)
	local self = overrideSelf or {}

	if not self.strictValidation then
		self.strictValidation = false
	end
	
	if not self.beforeGet then
		self.beforeGet = function(propertyName)
			-- We need to check if we are getting a 
			-- behavior-changing properties so we are
			-- not getting the property
							
			if propertyName == "_classBehavior" then
				return false
			end
			
			-- We should allow our get function to pass
			return true
		end
	end
	
	if not self.beforeSet then		
		self.beforeSet = function(property, oldValue, newValue)
			if property == "_classBehavior" then
				return
			end
			
			-- With default values and strictValidation checking,
			-- we can safely assume that our newValue is correct
					
			-- A really useful usecase for beforeSet could
			-- be using server-sanity checks in this function
						
			--For Example:
			-- Client: 
				-- requestSetCoins:InvokeServer(100)
						
			-- Server
					--{
						--beforeSet = function(property, oldValue, newValue)
							-- did you touch coins?
							--hasTouchedCoins(player, oldValue, newValue)
						--end
					--}
						
					--requestSetCoins.OnServerEvent = function(player, newCoins)
						-- before we set the coins we
						-- will need to call beforeSet,
						-- which will validate our changes
							
						--playerStats.setCoins(newCoins)
					--end					
			return true
		end
	end
		
	if not self.init then
		self.init = function()
			-- Empty
		end
	end	
	
	if not self.new then
		self.new = function(self, ...)
			-- Empty
		end
	end
	
	if not self.className then
		self.className = ""
	end
	
	setmetatable(self, classBehavior)
	
	return self
end

local RoClass = {}
RoClass.__index = RoClass

function RoClass.new(internal)
	internal._classBehavior = classBehavior.new(internal._classBehavior)
	
	local self = newproxy(true)
	local external = {}
	
	local proxyMeta = getmetatable(self)
	proxyMeta.__index = function(self, index)
		local function get(property)
			return internal[property]
		end
		
		local function set(property, newValue)
			internal[property] = newValue
		end
		
		local first = index:sub(1, 3):lower()
		if first == "get" then
			return function()
				local shouldPass = internal._classBehavior.beforeGet(index:sub(4, #index))
				if not shouldPass then
					return
				end	
				
				return get(index:sub(4, #index))
			end
		elseif first == "set" then
			return function(newValue)
				if internal._classBehavior.strictValidation then
					warn("[ROCLASS DEPRECATION] strictValidation classBehavior may be superseded by roblox's future typechecking system")
					
					if typeof(newValue) ~= typeof(get(index:sub(4, #index))) then
						error("Cannot set value since the type you are setting to is not the same type as the original value")
					end
				end
				
				local shouldPass = internal._classBehavior.beforeSet(newValue)
				if not shouldPass then
					return
				end
				
				set(index:sub(4, #index), newValue)
			end
		elseif first == "new" then
			return function(...)		
				internal._classBehavior.init(internal)
				internal._classBehavior.new(internal, ...)
			
				setmetatable(external, proxyMeta)
		
				return external
			end
		else
			local publicObject
			local success, err = pcall(function()
				publicObject = external[index]
			end)
			
			if internal._classBehavior.inheritClass then
				success, err = pcall(function()
					publicObject = internal._classBehavior.inheritClass[index]
				end)
			end
			
			if not publicObject then
				error("[ROCLASS ERROR]" .. index .. " does not exist" .. " in class " .. internal._classBehavior.className)
			end
			
			if err then
				error("[ROCLASS ERROR] Cannot access " .. index .. ", a private value of a class")
			end
			
			return publicObject
		end
	end
	
	proxyMeta.__newindex = function(self, key, value)
		external[key] = value
		return {}
	end
	
	if internal.init then
		if typeof(internal.init) == "function" then
			warn("[ROCLASS DEPRECATION] having init outside of _classBehavior has been deprecated")
		end
	end	
	
	setmetatable(proxyMeta, RoClass)
	
	return self
end

return RoClass
