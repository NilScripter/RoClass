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
	internal._classBehavior = classBehavior.new(internal._classBehavior or {})
		
	local external = {}
	
	local metatable = {}	
	metatable.__index = function(self, index)
		local publicValue
		local success, err = pcall(function()
			publicValue = external[index]
		end)
		
		if internal._classBehavior.inheritClass then
			success, err = pcall(function()
				publicValue = internal._classBehavior.inheritClass[index]
			end)
		end
		
		local className = internal._classBehavior.className
		if className == "" then
			className = "a class"
		end
		
		if not success then
			error("[ROCLASS ERROR] Cannot access " .. index .. " from " .. className)
		end
	end
	
	metatable.__newindex = function(self, key, value)
		-- We need to use rawset since 
		-- __newindex will fire infinetly without
		-- it
		
		rawset(external, key, value)
		return {}
	end
	
	for index, value in pairs(internal) do
		local function get(property)
			return internal[property]
		end
		
		local function set(property, newValue)
			internal[property] = newValue
		end
		
		-- We need to make sure we are
		-- not getting or setting _classBehavior
		
		if index ~= "_classBehavior" then
			external["get" .. index] = function()
				local shouldPass = internal._classBehavior.beforeGet(index:sub(4, #index))
				if not shouldPass then
					return
				end	
				
				return get(index)
			end
			
			external["set" .. index] = function(newValue)				
				if internal._classBehavior.strictValidation then
					warn("[ROCLASS DEPRECATION] strictValidation classBehavior may be superseded by roblox's future typechecking system or beforeSet")
					
					if typeof(newValue) ~= typeof(get(index)) then
						error("Cannot set value since the type you are setting to is not the same type as the original value")
					end
				end
				
				local shouldPass = internal._classBehavior.beforeSet(index, get(index), newValue)
				if not shouldPass then
					return
				end
				
				set(index, newValue)
			end
		end
		
		function external.new(...)					
			internal._classBehavior.init(internal)
			internal._classBehavior.new(internal, ...)
			
			setmetatable(external, metatable)
		
			return external
		end
	end
	
	setmetatable(external, metatable)
	
	return external
end

return RoClass
