local PREFIX = "ROCLASS"

local RoClass = {}
RoClass.Signal = require(script.Signal)
RoClass.Getter = "get"
RoClass.Setter = "set"

RoClass.__index = RoClass

--[[**
	A custom error function that helps with errors.
	This function is useful because I'd like to do
	[ROCLASS ERROR] and it becomes repetitive to 
	type that all the time.  It also types the 
	second parameter of error for you.  The value
	of it is 2.
		
	@param [t:string] tag This is the tag you input ('ERROR', 'DEPRECATION', 'BETA', 'WARNING')
	@param [t:err] err This is what is being errored in your console
**--]]

local function tagError(tag, err)
	error("[" .. PREFIX .. " " .. tag .. "] " .. err, 2)
end

--[[**
	A function used for error handling.  Used in a function
	(hence 'functionName').  Helps with concatenation and
	DRY (don't repeat yourself).
	
	@param [t:string] functionName The name of the function you are erroring in
	@returns [t:function] function that you can error with.  Same arguments as tagError
**--]]

local function functionError(functionName)
	return function(tag, errorMessage)
		tagError(tag, "[" .. functionName .. "] " .. errorMessage)	
	end
end

--[[**
	Checks whether the property passed exists and
	if the property is a string.  Useful whenever
	calling :SetLocked, :SetReadOnly, :SetStatic
	and :EnableStrictChecking since those methods
	need to make sure the value exists in our
	class
		
	@param [t:string] tag the function it is calling from
	@param [t:string] property the property we are checking
**--]]

local function checkProperty(tag, property)
	local errorFunction = functionError(tag)
	
	if not property then
		errorFunction("ERROR", "property must exist")
	end
		
	if type(property) ~= "string" then
		errorFunction("ERROR", "property must be a string")
	end
end

--[[**
	A method of RoClass which creates a class and
	returns it.  The internal variable for the class is called 'mainClass'.  
	There are many internal tables that help with class creation.
	
	internal - a table that stores private values
	inheritClass - the class you are inheriting from
	className - class's name
	constructorName - constructorName
	gettersBlacklist - getters you cannot access
	settersBlacklist - setters you cannot access
	strictCheckBlacklist - values that have RoClass's custom typechecking
	blacklist - values you cannot access (metamethods, methods)
	staticMembers - values that are static
	
	@returns [t:RoClass] A RoClass with multiple methods
**--]]

function RoClass:Extend()	
	local internal = {}
	local inheritClass = nil
	local className = "a class"
	local constructorName = "new"
	
	local gettersBlacklist = {}
	local settersBlackList = {}
	local strictCheckBlackList = {}	
	local staticMembers = {}
	local blacklist = {
		__index = true;
		__tostring = true;
		BeforeSet = true;
		BeforeGet = true;
		SetPrivateProperties = true;
		SetClassName = true;
		SetClassBehavior = true;
		ReadOnly = true;
		Lock = true;
		StrictCheck = true;
		Init = true;
		AfterClassCreated = true;
		InheritClass = true;
	}
		
	--[[**
		Iterates over the passed tbl parameter
		and creates another table with identical
		elements.  This is used to not have two 
		tables with the same memory address
		
		@param [t:table] tbl The tbl that will be copied
		@returns [t:table] The copied table	
	**--]]
	
	local function copyTable(tbl)
		if not tbl then
			tagError("ERROR", "tbl passed to copyTable does not exist")
		end
		
		if type(tbl) ~= "table" then
			tagError("ERROR", "tbl passed to copyTable is not a table")
		end
		
		local newTable = {}
		for key, value in pairs(tbl) do
			newTable[key] = value
		end
				
		return newTable
	end
	
	--[[**
		Retrieves a property from the self parameter
		or from internal.  Utilizes pcall since
		table[key] errors if the value does not exist.
		Errors whenever shouldError is true.
		
		@param [t:RoClass/table] self Value retrieving from
		@param [t:string] property Value name
		@param [t:bool] shouldError Determines whether safeRetrieve should error or not
	
		@returns [t:variant] the value retrieved
	**--]]
	
	local function safeRetrieve(self, property, shouldError)
		if not property then
			tagError("ERROR", "property passed to safeRetrieve does not exist")
		end
		
		if type(property) ~= "string" then
			tagError("ERROR", "property passed to safeRetrieve is not a string")
		end
		
		if shouldError == nil then
			tagError("ERROR", "shouldError passed to safeRetrieve is nil")
		end
		
		if type(shouldError) ~= "boolean" then
			tagError("ERROR", "shouldError passed to safeRetrieve must be a boolean")
		end
		
		local value 
		local success, err = pcall(function()
			value = rawget(self, property)
		end)
						
		if not success then
			success, err = pcall(function()
				value = internal[property]
			end)
		end
		
		if not value and shouldError then
			tagError("ERROR", "Cannot access property from " .. className)
		end
						
		return value
	end
		
	local mainClass = {}
	
	-- Retrieves value from itself whenever value doesn't
	-- exist (might be obsolete?)
	
	function mainClass:__index(index)
		local errorFunction = functionError("mainClass:__index")
		
		if not index then
			errorFunction("ERROR", "index passed must exist")
		end
		
		if type(index) ~= "string" then
			errorFunction("ERROR", "index passed must be a string")
		end
		
		local value = safeRetrieve(self, index, false)
		if value then
			return value
		end
	end	
		
	-- Whenever you call tostring on the class, it will
	-- return its className	
		
	function mainClass:__tostring()
		return className
	end

	--[[**
		Called before mainClass:AfterClassCreated.
		Does not have any parameters. Able to be overrided. 
		
		This can be useful to do any calculations before
		you are setting the properties of the class.
		@
	**--]]

	function mainClass:Init()
		
	end
	
	--[[**
		Called after mainClass:Init. Parameter is a tuple.
		Method can be overrided. As long as you pass the arguments required
		from 'class.new', it will be inputted to mainClass:AfterClassCreated
		
		@param [t:variant] tuple These arguments are passed from 'class.new'.
	**--]]
	
	function mainClass:AfterClassCreated(...)
		
	end

	--[[**
		Constructor of the class (usually mainClass.new).
		Creates an object (again) with multiple methods you can use.
		Uses metatable OOP. Caches the internal table so each
		class has their own values.  Caching internal is important
		because if one class changed their value, the other classes
		would have that change. Iterates through mainClass and
		adds its values if it is not in the blacklist table.  Also
		creates getters and setters. Finally, it will call
		mainClass:Init and mainClass:AfterClassCreated, overriding
		the implicit self parameter with the cached internal.
		
		@
	**--]]

	mainClass[constructorName] = function(...) -- constructor
		local cachedInternal = copyTable(internal)
		
		local self = {}
		
		for key, value in pairs(mainClass) do
			if not blacklist[key] then
				self[key] = value
			end
		end
		
		--[[**
			A function that doesn't call the :BeforeGet
			method (this is similar to rawget, which doesn't
			fire any metamethods).  Takes a property parameter,
			which helps this function retrieve the value.
			
			@param [t:string] property Property you want to retrieve
			@returns [t:variant] Value from cachedInternal
		**--]]
		local function get(property)
			return cachedInternal[property]
		end
		
		--[[**
			A function that doesn't call the :BeforeSet
			method and strictChecking (this is similar to rawset, which doesn't
			fire any metamethods).  Takes a property parameter,
			the name of the value we want to change.  It also
			takes a newValue parameter, the value that we will set to.
			
			@param [t:string] property Property you want to retrieve
			@param [t:variant] newValue The newValue of the property 
		**--]]
		
		local function set(property, newValue)
			cachedInternal[property] = newValue
		end
		
		for index, value in pairs(cachedInternal) do
			self[RoClass.Getter .. index] = function()				
				-- Is it in our gettersBlacklist?
				if gettersBlacklist[index] then
					return
				end
				
				-- Is our value static?
				if staticMembers[index] then
					return staticMembers[index]
				end
				
				-- Can we pass :BeforeGet() ?
				local shouldPass = mainClass:BeforeGet(index)	
				if not shouldPass then
					return
				end
						
				return get(index)
			end
					
			self[RoClass.Setter .. index] = function(newValue)				
				if settersBlackList[index] then
					return nil
				end
				
				--[[**
					Unlike set, setValue takes into account
					strictChecking and :BeforeSet. Has a property
					parameter, the property we want to set, and
					the value parameter, the value we are setting
					to.
					
					@param [t:string] property Property we are changing
					@param [t:varaint] value The value we are setting to
				**--]]
				
				local function setValue(property, value)	
					if strictCheckBlackList[property] then
						if typeof(newValue) ~= typeof(value) then
							tagError("ERROR", "Cannot set value to a different type than the original")
						end
					end
						
					local shouldPass = mainClass:BeforeSet(
						property, 
						value, 
						newValue
					)
						
					if not shouldPass then
						return
					end
							
					set(property, newValue)
				end
				
				-- If our member is static, set the universal
				-- value shared with all objects.  If not,
				-- the value retrieved from get (the old value)
				if staticMembers[index] then
					setValue(index, staticMembers[index])
				else
					setValue(index, get(index))
				end
			end
		end	
		
		setmetatable(self, mainClass)
		
		mainClass.Init(cachedInternal)
		mainClass.AfterClassCreated(cachedInternal, ...)
		
		return self
	end
	
	--[[**
		<IN PROGRESS>
		Takes our value from the real internal and places
		that value in a universal table, shared between
		all our objects.  Whenever getting/setting a static
		value, it will reference the staticMembers table.
		
		@param [t:string] property The property we want to set static
	**--]]
	
	function mainClass:SetStatic(property)
		checkProperty("[mainClass:SetStatic]", property)
		safeRetrieve(nil, property, true)
		
		-- Here, we are not going to check whether a member
		-- exists since there may be two properties with the 
		-- same name.
		
		staticMembers[property] = internal[property]
	end
	
	--[[**
		Takes the property parameter passed (the property we want to lock)
		and uses it to create values in our gettersBlacklist and settersBlacklist
		dictionaries. Whenever a value is added to a getters/setters blacklist,
		it is ignored whenever trying to use a getter or setter. 
		
		WARNING: DOES NOT THROW ERRORS WHENEVER TRYING TO ACCESS A LOCKED
				 VALUE
		
		@param [t:string] property Property we want to lock
	**--]]
	
	function mainClass:SetLocked(property)
		checkProperty("mainClass:SetLocked", property)
		
		-- We need to check if we can retrive the 
		-- property passed
				
		safeRetrieve(nil, property, true)
		
		-- We need to make sure that our getter is not
		-- blacklisted
		
		if not gettersBlacklist[property] then
			gettersBlacklist[property] = true
		end
		
		-- We need to make sure that our setter is not
		-- blacklisted
		
		if not settersBlackList[property] then
			settersBlackList[property] = true
		end
	end
	
	--[[**
		Takes the property parameter passed (the property we want to make readonly)
		and uses it to create a value in our settersBlacklist dictionary. 
		Whenever a value is added to a setters blacklist, it is ignored whenever 
		trying to use a etter. 
		
		WARNING: DOES NOT THROW ERRORS WHENEVER TRYING TO SET A READONLY
				 VALUE
		
		@param [t:string] property Property we want to make readonly
	**--]]
		
	function mainClass:SetReadOnly(property)
		checkProperty("mainClass:SetReadOnly", property)
		safeRetrieve(nil, property, true)
		
		-- We need to make sure that our setter is not
		-- blacklisted
		
		if not settersBlackList[property] then
			settersBlackList[property] = true
		end
	end
	
	--[[**
		Takes the property parameter passed (the property we want to enable strict checking)
		and uses it to create values in our strictCheckingBlacklist
		dictionary. Whenever a value is added to the strictChecking blacklist,
		it will check if the newValue's type corresponds with the
		oldValue's type.
		
		WARNING: DOES THROW ERRORS WHENEVER YOU ARE TRYING
				 TO USE DIFFERENT TYPES.
		
		@param [t:string] property Property we want to enable strict checking
	**--]]
		
	function mainClass:EnableStrictChecking(property)
		checkProperty("[mainClass:EnableStrictChecking]", property)
		safeRetrieve(nil, property, true)
		
		-- We need to make sure that our property has
		-- not had strict check enabled yet
		
		if not strictCheckBlackList[property] then
			strictCheckBlackList[property] = true
		end
	end

	--[[**
		A setter of mainClass.  Sets the 'internal' table
		to the newInternal dictionary.  newInternal holds
		private values.  Calls copyTable on newInternal
		
		@param [t:dictionary] newInternal The dictionary which stores private values
	**--]]

	function mainClass:SetPrivateProperties(newInternal)
		local errorFunction = functionError("mainClass:SetPrivateProperties")
		if not newInternal then
			errorFunction("ERROR", "newInternal must exist")
		end
		
		if type(newInternal) ~= "table" then
			errorFunction("ERROR", "newInternal must be a table")
		end
		
		internal = copyTable(newInternal)
	end
	
	--[[**
		A setter of mainClass.  Sets the 'className' string
		to the newClassName string.
		
		@param [t:string] newClassName The string which stores the new class name
	**--]]
	
	function mainClass:SetClassName(newClassName)
		local errorFunction = functionError("mainClass:SetClassName")
		
		if not newClassName then
			errorFunction("ERROR", "newClass name must exist")
		end
		
		if type(newClassName) ~= "string" then
			errorFunction("ERROR", "newClass must be a string")
		end
		
		className = newClassName
	end
	
	--[[**
		A setter of mainClass.  Sets the 'constructorName' string
		to the newConstructorName string.  Replaces the old
		constructor with the new constructor.
		
		@param [t:string] newConstructorName The string which stores the new class name
	**--]]
	
	function mainClass:SetConstructorName(newConstructorName)
		local errorFunction = "mainClass:SetConstructorName"
		
		if not newConstructorName then
			errorFunction("ERROR", "newClass name must exist")
		end
		
		if type(newConstructorName) ~= "string" then
			errorFunction("ERROR", "newClass must be a string")
		end
				
		local cachedConstructor = self[constructorName]
		self[newConstructorName] = cachedConstructor
		self[constructorName] = nil
		
		cachedConstructor = nil
				
		constructorName = newConstructorName
	end
	
	--[[**
		Inherits from the superClass argument.  Iterates
		through superClass and retrieves all public values
		from it (Soon, there will be protected values).
		
		@param [t:RoClass] superClass The class you are inheriting from
	**--]]
	
	function mainClass:InheritClass(superClass)
		local errorFunction = functionError("mainClass:InheritClass")
		
		if not superClass then
			errorFunction("ERROR", "the class you are inheriting from must exist")
		end
		
		if type(superClass) ~= "table" then
			errorFunction("ERROR", "the class you are inheriting from must be a RoClass")
		end
		
		for key, value in pairs(superClass) do
			if not blacklist[key] then
				self[key] = value
			end
		end
	end
	
	--[[**
		
	**--]]
	
	function mainClass:BeforeGet(property)
		return true
	end
	
	function mainClass:BeforeSet(property, oldValue, newValue)
		return true
	end
		
	setmetatable(mainClass, mainClass)		
	return mainClass
end

return RoClass
