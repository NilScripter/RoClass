local RoClass = {}
RoClass.Signal = require(script.Signal)
RoClass.Getter = "get"
RoClass.Setter = "set"

RoClass.__index = RoClass

function RoClass.new(internal)
	local gettersBlacklist = {}
	local settersBlackList = {}
	
	local function copyTable(tbl)
		local newTable = {}
		for key, value in pairs(tbl) do
			newTable[key] = value
		end
				
		return newTable
	end
	
	local function safeRetrieve(self, property, shouldError)
		local value 
		local success, err = pcall(function()
			value = rawget(self, property)
		end)
						
		if not success then
			success, err = pcall(function()
				value = internal[property]
			end)
		end
			
		if not success then
			success, err = pcall(function()
				value = internal._classBehavior.inheritClass[property]
			end)
		end
					
		if not value and shouldError then
			error("[ROCLASS ERROR] Cannot lock property from " .. cachedInternal._classBehavior.className)
		end
						
		return value
	end
	
	local function setupGettersSetters(self, cachedInternal)
		local function get(property)
			return cachedInternal[property]
		end
		
		local function set(property, newValue)
			cachedInternal[property] = newValue
		end
		
		for index, value in pairs(cachedInternal) do
			-- We need to make sure we are
			-- not getting or setting _classBehavior
								
			if index ~= "_classBehavior" then
				self[RoClass.Getter .. index] = function()				
					if gettersBlacklist[index] then
						print(index, ":", "getters blacklist!")
						return nil
					end
					
					local shouldPass = true
					if cachedInternal._classBehavior.beforeGet then
						shouldPass = cachedInternal._classBehavior.beforeGet(index)
					end
					
					if not shouldPass then
						return
					end
						
					return get(index)
				end
					
				self[RoClass.Setter .. index] = function(newValue)				
					if settersBlackList[index] then
						print(index, ":", "setters blacklist!")
						return nil
					end
					
					if cachedInternal._classBehavior.strictValidation then
						warn("[ROCLASS DEPRECATION] strictValidation classBehavior may be superseded by roblox's future typechecking system or beforeSet")
							
						if typeof(newValue) ~= typeof(get(index)) then
							error("Cannot set value since the type you are setting to is not the same type as the original value")
						end
					end
					
					local shouldPass = true
					if cachedInternal._classBehavior.beforeSet then
						shouldPass = cachedInternal._classBehavior.beforeSet(
							index, 
							get(index), 
							newValue
						)
						
					end	
					
					if not shouldPass then
						return
					end
						
					set(index, newValue)
				end
			end
		end
	end
		
	local mainClass = {}
	mainClass.__index = mainClass	
		
	function mainClass:__newindex(key, value)
		-- We need to use rawset since 
		-- __newindex will fire infinetly without
		-- it
		
		rawset(self, key, value)
	end
	
	function mainClass.new(...)
		local self = {}
		local cachedInternal = copyTable(internal)
		
		if not cachedInternal._classBehavior then
			cachedInternal._classBehavior = {}
		end
				
		if cachedInternal._classBehavior.init then
			cachedInternal._classBehavior.init(cachedInternal)
		end
		
		if cachedInternal._classBehavior.new then
			cachedInternal._classBehavior.new(cachedInternal, ...)	
		end
					
		setupGettersSetters(mainClass, cachedInternal)
		
		setmetatable(self, mainClass)
		return self
	end
	
	function mainClass:Lock(property)
		-- We need to check if we can 
		-- retrive the property passed
		-- to the Lock method
				
		safeRetrieve(nil, property, true)

		gettersBlacklist[property] = true
		settersBlackList[property] = true
	end
		
	function mainClass:ReadOnly(property)
		safeRetrieve(nil, property, true)
		settersBlackList[property] = true
	end
		
	return mainClass
end

return RoClass
