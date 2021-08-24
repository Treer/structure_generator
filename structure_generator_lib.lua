-- Include a copy of this file with your mod and rename "my_mod_namespace" below
-- to that of a global table unique to your mod. This is to avoid your mod clashing
-- with any other mod that has included this file.
--
-- Your code can then create a local reference:
--   local structGenLib = my_mod_namespace.get_structure_generator_lib()

local parentModNamespace = 'my_mod_namespace'


-- =========================== --

local structGenLib = {}
local defaultRecursionLimit = 7
local modPath = minetest.get_modpath(minetest.get_current_modname())

-- Inject a get_structure_generator_lib() function into the parent mod's namespace table.
if not minetest.global_exists(parentModNamespace) then _G[parentModNamespace] = {} end -- _G is the global variables table
if type(_G[parentModNamespace]) ~= 'table' then error("The global variable '" .. parentModNamespace .. "' must be a table." , 0) end

_G[parentModNamespace].get_structure_generator_lib = function ()
    return structGenLib
end

local debug           = function() end
local convertToString = tostring
if minetest.global_exists("structure_generator") then
    debug           = structure_generator.debug
    convertToString = structure_generator.toString

    if structure_generator.lib == nil then
        -- make this library available to the structure_templates_tool
        structure_generator.lib = structGenLib
    end
end


-- Don't use the following predefined tags as prefab names
local reservedPrefabTag = {
	none       = "none",
	all        = "all",

    -- 'dead-end' prefabs are used to wall-off a connection point, and will be fallen back on if
    -- other prefabs that were compatible with the connection point failed their validation check.
    -- (i.e. if they intersected with already-placed prefabs), or if the recursion limit is reached.
    deadend    = "deadend",

    -- decoration prefabs are allowed to intersect room prefabs
    decoration = "decoration"
}
structGenLib.reservedPrefabTag = reservedPrefabTag -- so earlier code in this file can reference it


-- ===========================
--           Util funcs
-- ===========================
local rngSeed = 1

-- abstract the RNG so we have the option to swap it for a cross-language deterministic one
local function setRngSeed(seed)
    rngSeed = seed or (os.time() + math.random(-10000, 10000))
    math.randomseed(rngSeed)
end
local function getRngInt(lower, upper)
    return math.random(lower, upper)
end

-- copies values by reference, and doesn't copy the metatable,
local function copyTable(table)
    local result = {}
    for k,v in pairs(table) do result[k] = v end
    return result
end

local function tableCount(tbl)
    local result = 0
    for _ in pairs(tbl) do result = result + 1 end
    return result
end

-- size is not altered
-- rotation can equal 0, 1, 2 or 3 (i.e. the lower 2 bits in a facedir), and is clockwise
-- around the y axis BUT
-- result is translated afterwards to match how schematics rotate without changing their minp
local function rotatePoint(size, point, rotation)
    local xSize, zSize = size.x, size.z
    for _ = 1, rotation % 4 do
        local xOriginal = point.x
        point.x = point.z
        point.z = xSize - xOriginal

        xSize = zSize
        zSize = size.x
    end
end

-- list is a key/value table of with each value being a numeric weight for the key
-- the function returns one of the keys at random, based on their weightings
local function selectFromProbabilityList(list)

    if list == nil then
        return nil
    end
    local weightSum = 0
    for _,weight in pairs(list) do weightSum = weightSum + weight end

    local selection = getRngInt(0, weightSum * 1000) / 1000

    weightSum = 0
    for key, weight in pairs(list) do
        weightSum = weightSum + weight
        if selection <= weightSum then
        return key
      end
    end
    return nil -- list was empty
end

-- returns extractedItem and removes it from the array, assumes a properly indexed array
local function extractRandomElementFromArray(array)

    if #array == 0 then return nil end

    local index = getRngInt(1, #array)
    local result = array[index]
    for i = index + 1, #array do array[i - 1] = array[i] end
    array[#array] = nil

    return result
end

local function pickRandomElementFromArray(array)

    if #array == 0 then return nil end
    local index = getRngInt(1, #array)
    return array[index]
end

local function isNumber(variable)
    return type(variable) == "number"
end

-- returns true if the variable is a vector/position
-- differs from the structure_generator.isVector() in not caring whether the variable
-- contains extra fields.
local function isVectorTable(variable)
    if type(variable) ~= "table" then
        return false
    end
    return isNumber(variable.x) and isNumber(variable.y) and isNumber(variable.z)
end

local function isNonEmptyString(variable)
    return type(variable) == "string" and string.len(variable) > 0
end

local function stringFormat2(message, ...)
	local args = {...}
	local argCount = select("#", ...)

	for i = 1, argCount do
        args[i] = convertToString(args[i])
	end

	return string.format(message, unpack(args))
end

local function toHashset(arrayOrValue)
    local result = {}
    if type(arrayOrValue) == "table" then
        for k,v in pairs(arrayOrValue) do
            if v and type(v) == "boolean" then
                -- this entry is already in a Hashset form
                result[k] = true
            else
                -- this entry is in array form, so use the value rather than the key
                result[v] = true
            end
        end
    elseif arrayOrValue ~= nil then
        result[arrayOrValue] = true
    end
    return result
end

-- ===========================
--             Classes
-- ===========================
-- I'm using classes to provide a authoritative definition of what fields/methods the tables
-- should contain, and matching sanitization functions


--=== ConnectionPoint ===--

local ConnectionPoint = {_classname = "ConnectionPoint"}
ConnectionPoint.__index = ConnectionPoint -- Make ConnectionPoint usable as a metatable by giving it an __index entry, and have that __index point to ConnectionPoint as the default table for any missing key/values
local function _ConnectionPointConstructor(x, y, z, connectionType, facing, validPrefabs)
	return setmetatable(
        {x = x, y = y, z = z, type = connectionType, facing = facing, validPrefabs = validPrefabs},
        ConnectionPoint
    )
end

-- Either
--   ConnectionPoint.new()
--   ConnectionPoint.new(connectionPoint)
--   ConnectionPoint.new(x, y, z, connectionType, facing, validPrefabs)
function ConnectionPoint.new(a, b, c, d, e, f)
    if a == nil then
        return _ConnectionPointConstructor(0, 0, 0, "default", 0, {})
    elseif a == ConnectionPoint then
        error("Call ConnectionPoint.new() with a dot not a colon, i.e. not ConnectionPoint:new()")
	elseif type(a) == "table" then
		assert(
            isNumber(a.x) and isNumber(a.y) and isNumber(a.z) and a.type and isNumber(a.facing) and a.validPrefabs,
            stringFormat2("Invalid ConnectionPoint table passed to ConnectionPoint.new(): %s", a)
        )
		return _ConnectionPointConstructor(a.x, a.y, a.z, a.type, a.facing or 0, a.validPrefabs)
	elseif isNumber(a) then
		assert(
            isNumber(b) and isNumber(c) and d and isNumber(e) and f,
            stringFormat2("Invalid arguments passed to ConnectionPoint.new(%s, %s, %s, %s, %s, %s)", a, b, c, d, e, f)
        )
		return _ConnectionPointConstructor(a, b, c, d, e, f)
    else
        error("Invalid arguments passed to ConnectionPoint.new(?)")
	end
end

function ConnectionPoint:clone()
    assert(self ~= nil, "Call connectionPoint:clone() with a colon not a dot, i.e. not connectionPoint.clone()")
    local result = ConnectionPoint.new(self)
    for k,v in pairs(self) do result[k] = v end -- just in case there were any other entries in the ConnectionPoint table
    return result
end

-- prefabSize is not altered
-- rotation can equal 0, 1, 2 or 3 (i.e. the lower 2 bits in a facedir), and is clockwise
-- around the y axis BUT
-- new location is translated afterwards to match how schematics rotate without changing their minp
-- (thus the need for prefabSize)
function ConnectionPoint:rotate(prefabSize, rotation)
    assert(self ~= nil, "Call connectionPoint:rotate() with a colon not a dot, i.e. not connectionPoint.rotate()")
    rotatePoint(prefabSize, self, rotation)
    self.facing = (self.facing + rotation) % 4
    return self
end


--=== PrefabScaffold ===--

local PrefabScaffold = {_classname = "PrefabScaffold"}
PrefabScaffold.__index = PrefabScaffold -- Make PrefabScaffold usable as a metatable by giving it an __index entry, and have that __index point to PrefabScaffold as the default table for any missing key/values
local function _PrefabScaffoldConstructor(name, size, optional_typeTags)
	return setmetatable({name = name, size = vector.new(size), typeTags = toHashset(optional_typeTags)}, PrefabScaffold)
end

-- Either
--   PrefabScaffold.new(prefabScaffold)
--   PrefabScaffold.new(name, size, optional_typeTags)
function PrefabScaffold.new(a, b, c)
    if a == nil then
        error("No argument passed to PrefabScaffold.new()")
    elseif a == PrefabScaffold then
        error("Call PrefabScaffold.new() with a dot not a colon, i.e. not PrefabScaffold:new()")
	elseif type(a) == "table" then
		assert(
            isNonEmptyString(a.name) and isVectorTable(a.size),
            stringFormat2("Invalid PrefabScaffold table passed to PrefabScaffold.new(): %s", a)
        )
		return _PrefabScaffoldConstructor(a.name, a.size, a.typeTags or a.type) -- PrefabScaffold.type is deprecated and replaced by typeTags
	elseif isNonEmptyString(a) then
		assert(isVectorTable(b), stringFormat2("Invalid size passed to PrefabScaffold.new(%s, %s, %s)", a, b, c)
        )
		return _PrefabScaffoldConstructor(a, b, c)
    else
        error("Invalid arguments passed to PrefabScaffold.new(?)")
	end
end

-- returns true if the prefab is tagged as a deadend
function PrefabScaffold:isDeadEnd()
    assert(self ~= nil, "Call prefab:isDeadEnd() with a colon not a dot, i.e. not prefab.isDeadEnd()")
    return self.typeTags[structGenLib.reservedPrefabTag.deadend] == true
end

-- returns true if the prefab is tagged as a decoration
function PrefabScaffold:isDecoration()
    assert(self ~= nil, "Call prefab:isDecoration() with a colon not a dot, i.e. not prefab.isDecoration()")
    return self.typeTags[structGenLib.reservedPrefabTag.decoration] == true
end

function PrefabScaffold:hasTag(tag)
    assert(self ~= nil, "Call prefab:hasTag() with a colon not a dot, i.e. not prefab.hasTag()")
    if type(tag) ~= "string" then debug("!!!WARNING!!! Non-string tag in use, this might indicate a bug: %s", tag) end
    return self.typeTags[tag] == true
end

-- decoration and deadend prefabs are always placed, and are excluded from the collision table
function PrefabScaffold:canCollide()
    assert(self ~= nil, "Call prefab:canCollide() with a colon not a dot, i.e. not prefab.canCollide()")
    return not (self:isDecoration() or self:isDeadEnd())
end

function PrefabScaffold:clone()
    error("PrefabScaffold:clone() not implemented, perhaps you meant to have instantiated a Prefab for " .. (self.name or "<nil>") .. "? (" .. (self._classname or "") .. ")")
end


--=== Prefab ===--
--
-- Prefab is a subclass of PrefabScaffold, as it has more requirements

local Prefab = {_classname = "Prefab"}
Prefab.__index = Prefab              --  Make Prefab usable as the metatable...
setmetatable(Prefab, PrefabScaffold) --  but have it use PrefabScaffold as its superclass metatable for any key/values Prefab is missing
local function _PrefabConstructor(name, size, optional_typeTags, optional_schematic, connectionPoints, optional_decorationPoints)
    local prefab = _PrefabScaffoldConstructor(name, size, optional_typeTags)
    prefab.schematic = optional_schematic

    -- force the connection points and decoration points to be instances of ConnectionPoint
    prefab.connectionPoints = {}
    for _, connectionPointDef in ipairs(connectionPoints) do
        table.insert(prefab.connectionPoints, ConnectionPoint.new(connectionPointDef))
    end

    prefab.decorationPoints = {}
    for _, connectionPointDef in ipairs(optional_decorationPoints or {}) do
        table.insert(prefab.decorationPoints, ConnectionPoint.new(connectionPointDef))
    end

    return setmetatable(prefab, Prefab)
end

-- Either
--   Prefab.new(prefab)
--   Prefab.new(name, size, optional_typeTags, optional_schematic, connectionPoints, optional_decorationPoints)
function Prefab.new(a, b, c, d, e, f)
    if a == nil then
        error("No argument passed to Prefab.new()")
    elseif a == Prefab then
        error("Call Prefab.new() with a dot not a colon, i.e. not Prefab:new()")
	elseif type(a) == "table" then
		assert(
            isNonEmptyString(a.name) and isVectorTable(a.size) and type(a.connectionPoints) == "table",
            stringFormat2("Invalid Prefab table passed to Prefab.new(), might be missing name, size, or connectionPoints: %s", a)
        )
         -- NB: Prefab.type is deprecated and replaced by typeTags
		return _PrefabConstructor(a.name, a.size, a.typeTags or a.type, a.schematic, a.connectionPoints, a.decorationPoints)
	elseif isNonEmptyString(a) then
		assert(
            isVectorTable(b) and type(e) == "table",
            stringFormat2("Invalid size or connectionPoints table passed to Prefab.new(%s, %s, %s, %s, %s, %s)", a, b, c, d, e, f)
        )
		return _PrefabConstructor(a, b, c, d, e, f)
    else
        error("Invalid arguments passed to Prefab.new(?)")
	end
end


function Prefab:clone()
    assert(self ~= nil, "Call prefab:clone() with a colon not a dot, i.e. not prefab.clone()")

    local result = Prefab.new(self.name, self.size, self.typeTags, self.schematic, {}, {})
    for k,v in pairs(self) do
         -- just in case there were any other entries in the Prefab table, like event callback
        if result[k] == nil then result[k] = v end
    end

    -- clone all the connectionPoints and decorationPoints so they can be altered (e.g. rotated) without affecting the original
    result.connectionPoints = {}
    for _,point in ipairs(self.connectionPoints or {}) do
        table.insert(result.connectionPoints, point:clone())
    end
    result.decorationPoints = {}
    for _,point in ipairs(self.decorationPoints or {}) do
        table.insert(result.decorationPoints, point:clone())
    end

    return result
end


-- rotation can equal 0, 1, 2 or 3 (i.e. the lower 2 bits in a facedir), and is clockwise around the y axis
function Prefab:rotate(rotation)
    assert(self ~= nil, "Call prefab:rotate() with a colon not a dot, i.e. not prefab.rotate()")

    if rotation > 0 then
        for _,point in ipairs(self.connectionPoints or {}) do point:rotate(self.size, rotation) end
        for _,point in ipairs(self.decorationPoints or {}) do point:rotate(self.size, rotation) end

        if (rotation % 2) == 1 then
            -- x size and z size will have switched
            local original_x = self.size.x
            self.size.x = self.size.z
            self.size.z = original_x
        end
    end
    return self
end


--=== StructurePlan ===--

local StructurePlan = {_classname = "StructurePlan"}
StructurePlan.__index = StructurePlan -- Make StructurePlan usable as a metatable by giving it an __index entry, and have that __index point to StructurePlan as the default table for any missing key/values
local function _StructurePlanConstructor(optional_structurePlan)
    local structurePlan = optional_structurePlan or {}
    structurePlan.registered_prefabs          = structurePlan.registered_prefabs          or {}

    -- these will be set whenever plan_structure() is invoked, they are listed here only for reference.
    structurePlan.collisionTable      = {}
    structurePlan.connectedPoints     = {}
    structurePlan.plannedPrefabs      = {}
    structurePlan.deadendPrefabNamesByConnectionType = nil -- will get set if placeDeadEnd() is called
    structurePlan.userParam           = nil

	return setmetatable(structurePlan, StructurePlan)
end

function StructurePlan.new(optional_structurePlan)
    if optional_structurePlan == StructurePlan then
        error("Call StructurePlan.new() with a dot not a colon (i.e. NOT StructurePlan:new())")
	elseif optional_structurePlan ~= nil then
		assert(type(optional_structurePlan) ~= "table", stringFormat2("Invalid StructurePlan passed to StructurePlan.new(): %s", optional_structurePlan))
		return _StructurePlanConstructor(optional_structurePlan)
    else
		return _StructurePlanConstructor()
	end
end

function StructurePlan:addToCollisionTable(minp, maxp)
    assert(self ~= nil, "Call structurePlan:addToCollisionTable() with a colon not a dot")
    table.insert(self.collisionTable, {minp = minp, maxp = maxp})
end

function StructurePlan:testForCollision(minp, maxp)
    assert(self ~= nil, "Call structurePlan:testForCollision() with a colon not a dot")

    -- nothing fancy to see here like oct-trees or BSPs, in this house we use brute force
    for _, box in ipairs(self.collisionTable) do
        local bminp, bmaxp = box.minp, box.maxp
        local separated = bminp.x > maxp.x or bminp.y > maxp.y or bminp.z > maxp.z or
                          bmaxp.x < minp.x or bmaxp.y < minp.y or bmaxp.z < minp.z
        if not separated then
            return true
        end
    end
    return false
end

function StructurePlan:markPointAsConnected(pos, prefabName)
    assert(self ~= nil, "Call structurePlan:markPointAsConnected() with a colon not a dot")
    self.connectedPoints[minetest.pos_to_string(pos)] = (prefabName or "name not specified")
end

function StructurePlan:testIfPointAlreadyConnected(pos)
    assert(self ~= nil, "Call structurePlan:testIfPointAlreadyConnected() with a colon not a dot")
    --debug("testIfPointAlreadyConnected found '%s' at %s (tablesize %s)", structGenLib.connectedPoints[minetest.pos_to_string(pos)], pos, tableCount(structGenLib.connectedPoints))
    return self.connectedPoints[minetest.pos_to_string(pos)] ~= nil
end

function  StructurePlan:register_prefab(prefab_definition_table)
    assert(self ~= nil, "Call structurePlan:register_prefab() with a colon not a dot (i.e. NOT structurePlan.register_prefab())")
    assert(type(prefab_definition_table) == 'table', "Argument passed to structurePlan:register_prefab() is not a prefab definition table: " .. convertToString(prefab_definition_table))
    debug("register_prefab('%s', %s)", prefab_definition_table.name, prefab_definition_table)

    local prefab = Prefab.new(prefab_definition_table)
    self.registered_prefabs[prefab.name] = prefab
end

-- returns a floorplan which can be passed to place_structure()
-- direction:      nil for random. May be 0, 1, 2, 3
-- seed:           nil for random
-- recursionLimit: nil for default, specifies structure size, i.e. how many prefabs away from the first one placed can be the structure sprawl.
-- pos:            only used if minp/maxp are set. Floorplans don't have a location, but you might want to generate them relative to a boundingBox in real world coords. nil for origin
-- minp:           nil for unbounded, otherwise limits the structure to coords greater than minp
-- maxp:           nil for unbounded, otherwise limits the structure to coords less than maxp
-- userParam:      this value is passed to any prefab event callbacks, like on_before_set()
function StructurePlan:generate(firstPrefabName, direction, pos, seed, recursionLimit, minp, maxp, userParam)
    assert(self ~= nil, "Call structurePlan:generate() with a colon not a dot (i.e. NOT structurePlan.plan_structure())")
    local firstPrefab = self.registered_prefabs[firstPrefabName]
    assert(firstPrefab ~= nil, "StructurePlan:generate() told to build from \"" .. firstPrefabName .. "\", but the StructurePlan instance has no registered prefab with that name")
    assert(isVectorTable(pos),  "Invalid 'pos' table passed to  StructurePlan:generate()")
    assert(minp == nil or isVectorTable(minp), "Invalid 'minp' table passed to  StructurePlan:generate()")
    assert(maxp == nil or isVectorTable(maxp), "Invalid 'maxp' table passed to  StructurePlan:generate()")
    debug("StructurePlan:generate(%s, %s, %s, %s, %s, %s, %s, %s)", firstPrefabName, direction, seed, recursionLimit, pos, minp, maxp, userParam)

    self.userParam                          = userParam
    self.originalPos                        = pos

    -- clear the generator state
    self.collisionTable                     = {}
    self.connectedPoints                    = {}
    self.deadendPrefabNamesByConnectionType = nil -- will get set if placeDeadEnd() is called
    self.plan                               = {} -- a list of rotated prefabs with positions

    if minp ~= nil or maxp ~= nil then
        -- the collision detection algorithm used means that switching the minp & maxp inverts the collision area, creating a bounding box
        local boundaryAdj = pos or vector.new()
        local boundaryMin = vector.subtract((minp or vector.new(-32768, -32768, -32768)), boundaryAdj)
        local boundaryMax = vector.subtract((minp or vector.new( 32768,  32768,  32768)), boundaryAdj)
        self:addToCollisionTable(boundaryMax, boundaryMin) -- max and min are swapped
    end

    setRngSeed(seed)
    if direction == nil then direction = getRngInt(0, 3) end

    self:placePrefab(firstPrefabName, pos, direction, recursionLimit or defaultRecursionLimit)

    return self.plan
end



-- returns a probability list of prefabs that have a name or tag that matches nameOrTag
-- (All items will have the same weighting, which can be limited by specifying totalWeightLimit)
--
-- isForDecorationPoint provides some context in case nameOrTag is "all"
function StructurePlan:expandPrefabNameOrTag(nameOrTag, isForDecorationPoint, totalWeightLimit)
    assert(self ~= nil, "Call structurePlan:expandPrefabNameOrTag() with a colon.")

    if nameOrTag == reservedPrefabTag.none then
        return {}
    end

    local result = {}
    local includeAsMemberOfAll = false
    local itemCount = 0

    for _, prefab in pairs(self.registered_prefabs) do

        if nameOrTag == reservedPrefabTag.all then
            includeAsMemberOfAll = (isForDecorationPoint == nil) or (isForDecorationPoint == prefab:isDecoration())
        end

        if prefab.name == nameOrTag or prefab:hasTag(nameOrTag) or includeAsMemberOfAll then
            result[prefab.name] = 1
            itemCount = itemCount + 1
        end
    end

    if totalWeightLimit ~= nil then
        -- adjust weightings so they sum to totalWeightLimit
        for name, _ in pairs(result) do result[name] = totalWeightLimit / itemCount end
    end

    return result
end

-- validPrefabs might be a name string, a prefab type, or a list of these with probabilities
-- return a new probability list of prefab names
-- isForDecorationPoint provides some context in case validPrefabs contains "all"
function StructurePlan:normalizeValidPrefabs(validPrefabs, isForDecorationPoint)
    assert(self ~= nil, "Call structurePlan:normalizeValidPrefabs() with a colon.")
    local result = {}

    if type(validPrefabs) == 'string' then
        -- return all prefabs with a name or type that match the string
        return self:expandPrefabNameOrTag(validPrefabs, isForDecorationPoint)

    elseif type(validPrefabs) == 'table' then
        local excludedPrefabs = {}
        -- expand out any prefab types
        for key, value in pairs(validPrefabs) do
            if type(value) == 'string' then
                -- this item in the table is a prefab name or prefab type
                for name, weight in pairs(self:expandPrefabNameOrTag(value, isForDecorationPoint)) do
                    result[name] = (result[name] or 0) + weight
                end
            elseif type(value) == 'number' then
                -- this item in the table is a probability list item, but the key might be either a prefab name or prefab type
                for name, weight in pairs(self:expandPrefabNameOrTag(key, isForDecorationPoint, value)) do
                    if weight == 0 then table.insert(excludedPrefabs, name) end
                    result[name] = (result[name] or 0) + weight
                end
            end
        end

        for _, name in ipairs(excludedPrefabs) do
            -- specifying a probability of zero excludes the prefab and overrides any weight it
            -- may have gained from membership in otherwise included groups
            result[name] = nil
        end

        debug("## expanded probability table: %s", result)
    end
    return result;
end


function StructurePlan:connectionPointAllowsPrefab(connectionPoint, prefabName)
    assert(self ~= nil, "Call structurePlan:connectionPointAllowsPrefab() with a colon.")
    local allValidPrefabs = self:normalizeValidPrefabs(connectionPoint.validPrefabs) -- get a probability list of valid prefabs
    local result = allValidPrefabs[prefabName] ~= nil
    debug("%s with validPreface[%s]: allows '%s' = %s", connectionPoint.type,  connectionPoint.validPrefabs, prefabName, result)
    return result
end

-- returns true if the connectingPrefab was placed, false if it was unsuitable
function StructurePlan:tryPrefab(prefabName, prefabPos, connectionPoint, connectingPrefabName, recursionLimit)
    assert(self ~= nil, "Call structurePlan:tryPrefab() with a colon.")
    debug("tryPrefab(\"%s\", %s, %s, \"%s\", %s)", prefabName, prefabPos, connectionPoint, connectingPrefabName, recursionLimit)

    local connectionPos = vector.add(prefabPos, connectionPoint)
    if self:testIfPointAlreadyConnected(connectionPos) then
        -- this connection point has already been connected to something
        debug("## tryPrefab called on point that was already connected - you should have caught this earlier")
        return false
    end

    -- find the points on connectingPrefab that are compatible with connectionPoint
    local connectingPrefab = self.registered_prefabs[connectingPrefabName]
    local isDecoration = connectingPrefab:isDecoration()
    local pointsToTry
    if isDecoration then
        pointsToTry = connectingPrefab.decorationPoints or {}
    else
        pointsToTry = connectingPrefab.connectionPoints or {}
    end

    local matchingConnectionPoints = {}
    for _,point in ipairs(pointsToTry) do
        if point.type == connectionPoint.type then
            -- The connection-point type matches, but is this prefab in the connection point's valid prefab list?
            if self:connectionPointAllowsPrefab(point, prefabName) then
                table.insert(matchingConnectionPoints, point)
            end
        end
    end
    if #matchingConnectionPoints == 0 and isDecoration then
        -- don't force decoration prefabs to specify connection points, just use the their middle
        -- if they didn't specified anything.
        local decorationAnchor = vector.divide(connectingPrefab.size, 2)
        decorationAnchor.y = 0
        decorationAnchor.facing = 0
        decorationAnchor.validPrefabs = reservedPrefabTag.all
        decorationAnchor.type = connectionPoint.type
        table.insert(matchingConnectionPoints, decorationAnchor)
    end


    while #matchingConnectionPoints > 0 do
        local remotePoint = extractRandomElementFromArray(matchingConnectionPoints) -- removes the item from matchingConnectionPoints
        -- rotate and translate prefabPos so that the connectionPoints face each other and have the same coordinate
        -- the connectionPoints face each other if their directions are 180 degrees apart, which is a value of 2
        local newDirection = (6 - (remotePoint.facing - connectionPoint.facing)) % 4 -- using 6 instead of 2 to avoid negatives (6 = 540 degrees which is the same as 180 degrees, i.e. 2)

        local rotatedPoint = copyTable(remotePoint)
        rotatePoint(connectingPrefab.size, rotatedPoint, newDirection)
        local translation = vector.subtract(connectionPoint, rotatedPoint)
        translation = vector.apply(translation, math.floor) -- shouldn't be needed, but handle it in case someone tries to connect two points where one has a 0.5 portion and the other doesn't

        local connectingPrefabSize
        if (newDirection % 2) == 1 then
            -- x size and z size of the prefab schematic will switch when it's rotated
            connectingPrefabSize = vector.new(connectingPrefab.size.z, connectingPrefab.size.y, connectingPrefab.size.x)
        else
            connectingPrefabSize = connectingPrefab.size
        end
        local p1 = vector.add(prefabPos, translation)
        local p2 = vector.add(p1, vector.subtract(connectingPrefabSize, 1))

        local collision = false
        if connectingPrefab:canCollide() then
            collision = self:testForCollision(p1, p2)
            debug("testForCollision for new '%s' returned %s", connectingPrefab.name, collision)
        end

        if not collision then
            self:markPointAsConnected(connectionPos, connectingPrefab.name)
            self:placePrefab(connectingPrefab.name, p1, newDirection, recursionLimit)
            --minetest.set_node(p1, {name="default:mese"}) -- debug marker
            --minetest.set_node(p2, {name="default:meselamp"})

            return true
        else
            debug("tryPrefab() aborting attempt to connect new '%s' to '%s' due to collision (prefab still has %s other connectionPoints to try)", connectingPrefab.name, prefabName, #matchingConnectionPoints)
        end
    end

    return false
end


function StructurePlan:placeDeadEnd(prefabName, prefabPos, connectionPoint)
    assert(self ~= nil, "Call structurePlan:placeDeadEnd() with a colon.")

    if self.deadendPrefabNamesByConnectionType == nil then
        self.deadendPrefabNamesByConnectionType = {}

        for _, prefab in pairs(self.registered_prefabs) do
            if prefab:isDeadEnd() then
                for _, point in ipairs(prefab.connectionPoints) do
                    local prefabNames = self.deadendPrefabNamesByConnectionType[point.type]
                    if prefabNames == nil then prefabNames = {} end
                    table.insert(prefabNames, prefab.name)
                    self.deadendPrefabNamesByConnectionType[point.type] = prefabNames
                    --debug("prefabNames for connectionType %s of deadend %s: %s", point.type, prefab.name, prefabNames)
                end
            end
            --debug("Checked '%s' for deadend: %s", prefab.name, prefab:isDeadEnd())
        end

        if tableCount(self.deadendPrefabNamesByConnectionType) == 0 then
            --minetest.chat_send_all("WARNING: No dead-ends are specified for the structure-generator")
            minetest.log("warn", "WARNING: No dead-ends are specified the structure-generator")
        end
    end

    local validDeadendPrefabNames = self.deadendPrefabNamesByConnectionType[connectionPoint.type]
    local deadendPrefabName = pickRandomElementFromArray(validDeadendPrefabNames)

    if deadendPrefabName ~= nil then
        debug("Attempting deadend '%s'", deadendPrefabName)
        self:tryPrefab(prefabName, prefabPos, connectionPoint, deadendPrefabName, 1)
    end
end


function StructurePlan:placeConnections(prefab, pos, isDecorationPoints, recursionLimit)
    assert(self ~= nil, "Call structurePlan:placeConnections() with a colon.")

    local pointList = prefab.connectionPoints
    if isDecorationPoints then pointList = prefab.decorationPoints end

    for i, point in ipairs(pointList) do
        -- One of the entrances is already connected to the prefab that spawned this one, so skip that connection point
        if not self:testIfPointAlreadyConnected(vector.add(pos, point)) then
            local validPrefabs
            if recursionLimit > 0 or (isDecorationPoints and recursionLimit > -2) then -- ensure a room at the recursion limit can still be decorated
                validPrefabs = self:normalizeValidPrefabs(point.validPrefabs, isDecorationPoints) -- get a probability list of valid prefabs
            else
                validPrefabs = {}
            end

            debug("StructurePlan:placeConnections found %s validPrefabs for point %s of %s", tableCount(validPrefabs), i, tableCount(pointList))

            local connectionPlaced = false;
            local nextPrefabName
            repeat
                nextPrefabName = selectFromProbabilityList(validPrefabs)
                if nextPrefabName ~= nil then
                    validPrefabs[nextPrefabName] = nil -- remove it from the probability list so if we fail to place it we can try another
                    connectionPlaced = self:tryPrefab(prefab.name, pos, point, nextPrefabName, recursionLimit)
                end
            until connectionPlaced or nextPrefabName == nil

            if not connectionPlaced and not isDecorationPoints then
                debug("placeConnections falling back to dead-end on '%s'", prefab.name)
                self:placeDeadEnd(prefab.name, pos, point)
            end
        end
    end
end


function StructurePlan:placePrefab(prefabName, pos, direction, recursionLimit)
    assert(self ~= nil, "Call structurePlan:placePrefab() with a colon.")
    debug("Placing '%s' at %s facing %s, recursions remaining %s", prefabName, pos, direction, recursionLimit)

    -- rotate a clone of the prefab
    local prefab = self.registered_prefabs[prefabName]:clone():rotate(direction)

    prefab.schematicpos = pos
    prefab.schematicDirection = direction * 90
    table.insert(self.plan, prefab)

    if prefab.schematic ~= nil then
        minetest.place_schematic(
            pos,
            modPath .. DIR_DELIM .. prefab.schematic,
            direction * 90,
            {},  -- node replacements
            true -- force_placement
        )
    end


    if prefab:canCollide() then
        local pos2 = vector.add(pos, vector.subtract(prefab.size, 1))
        self:addToCollisionTable(pos, pos2)
    end

    recursionLimit = recursionLimit - 1

    self:placeConnections(prefab, pos, false, recursionLimit) -- connectionPoints
    self:placeConnections(prefab, pos, true,  recursionLimit) -- decorationPoints
end





-- Expose prefab definition classes the classes to the public API
structGenLib.ConnectionPoint = ConnectionPoint
structGenLib.PrefabScaffold  = PrefabScaffold
structGenLib.Prefab          = Prefab
structGenLib.StructurePlan   = StructurePlan
