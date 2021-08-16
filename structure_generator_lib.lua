-- Include a copy of this file with your mod and rename "my_mod_namespace" below
-- to that of a global table unique to your mod. This is to avoid your mod clashing
-- with any other mod that has included this file.
--
-- Your code can then create a local reference:
--   local structGenLib = my_mod_namespace.get_structure_generator_lib()

local parentModNamespace = 'my_mod_namespace'


-- =========================== --

local structGenLib = {}

-- Inject a get_structure_generator_lib() function into the parent mod's namespace table.
if not minetest.global_exists(parentModNamespace) then _G[parentModNamespace] = {} end -- _G is the global variables table
if type(_G[parentModNamespace]) ~= 'table' then error("The global variable '" .. parentModNamespace .. "' must be a table." , 0) end

_G[parentModNamespace].get_structure_generator_lib = function ()
    return structGenLib
end

local debug = function() end
if minetest.global_exists("structure_generator") then
    debug = structure_generator.debug

    if structure_generator.lib == nil then
        -- make this library available to the structure_templates_tool
        structure_generator.lib = structGenLib
    end
end


-- ===========================
--           Util funcs
-- ===========================
local rngSeed = 1

-- abstract the RNG so we have the option to swap it for a cross-language deterministic one
local function setRngSeed(seed)
    rngSeed = seed or os.time()
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
-- rotation can equal 0, 1, 2, or 3, and is clockwise around the y axis BUT
-- result is translated afterwards to match how schematics rotate without changing their minp
-- i.e. the lower 2 bits in a facedir
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


-- ===========================
--             API
-- ===========================
local defaultRecursionLimit = 7
local modPath = minetest.get_modpath(minetest.get_current_modname())

local placePrefab         -- the placePrefab(prefabName, pos, direction, recursionLimit) function will be assigned to this var

function structGenLib.clear()
    structGenLib.registered_prefabs          = {}
    structGenLib.registrationOrdered_prefabs = {} -- array of prefab tables in order of registration
    structGenLib.registered_deadend_types    = {}
    structGenLib.registered_decoration_types = {}
    structGenLib.deadendPrefabNamesByConnectionType = nil
end
structGenLib.clear() -- initialize the tables

-- table of bounding boxes so prefabs aren't placed on top of each other
structGenLib.collisionTable = {}
structGenLib.connectedPoints = {}

local function clearCollisionTable()
    structGenLib.collisionTable = {}
    structGenLib.connectedPoints = {}
end

local function addToCollisionTable(minp, maxp)
    table.insert(structGenLib.collisionTable, {minp = minp, maxp = maxp})
end

local function testForCollision(minp, maxp)
    -- nothing fancy to see here like oct-trees or BSPs, in this household we use brute force
    for _, box in ipairs(structGenLib.collisionTable) do
        local bminp, bmaxp = box.minp, box.maxp
        local separated = bminp.x > maxp.x or bminp.y > maxp.y or bminp.z > maxp.z or
                          bmaxp.x < minp.x or bmaxp.y < minp.y or bmaxp.z < minp.z
        if not separated then
            return true
        end
    end
    return false
end

local function markPointAsConnected(pos, prefabName)
    structGenLib.connectedPoints[minetest.pos_to_string(pos)] = (prefabName or "name not specified")
end

local function testIfPointAlreadyConnected(pos)
    debug("testIfPointAlreadyConnected found '%s' at %s (tablesize %s)", structGenLib.connectedPoints[minetest.pos_to_string(pos)], pos, tableCount(structGenLib.connectedPoints))
    return structGenLib.connectedPoints[minetest.pos_to_string(pos)] ~= nil
end


-- 'dead-end' prefabs are used to wall-off a connection point, and will be fallen back on if
-- other prefabs that were compatible with the connection point failed their validation check.
-- (i.e. if they intersected with already-placed prefabs)
function structGenLib.register_prefabType_as_deadend(prefab_type_enum)
    structGenLib.registered_deadend_types[prefab_type_enum] = true

    if type(prefab_type_enum) ~= 'string' and type(prefab_type_enum) ~= 'number' then
        error("Argument passed to register_prefab_type_as_deadend() is not a prefab type enum: " .. structure_generator.toString(prefab_type_enum), 0)
    end
end

-- decoration prefabs are allowed to intersect room prefabs
function structGenLib.register_prefabType_as_decoration(prefab_type_enum)
    structGenLib.registered_decoration_types[prefab_type_enum] = true

    if type(prefab_type_enum) ~= 'string' and type(prefab_type_enum) ~= 'number' then
        error("Argument passed to register_prefab_type_as_decoration() is not a prefab type enum" .. structure_generator.toString(prefab_type_enum), 0)
    end
end

function structGenLib.register_prefab(name, prefab_definition_table)

    -- if the first param is the prefab_definition_table and the name is in the table then that's ok too
    if type(name) == 'table' and type(name.name) == 'string' then
        prefab_definition_table = name
        name = prefab_definition_table.name
    end

    if type(prefab_definition_table) ~= 'table' or type(prefab_definition_table.type) ~= 'string' then
        error("Argument passed to register_prefab() is not a prefab definition table: " .. structure_generator.toString(prefab_definition_table), 0)
    end

    prefab_definition_table.name = name
    structGenLib.registered_prefabs[name] = prefab_definition_table
    table.insert(structGenLib.registrationOrdered_prefabs, prefab_definition_table)
end

-- size and pointsList are not changed, a new list is returned
local function rotateConnectionPoints(size, pointsList, direction)
    local result = {}
    for _,connectionPoint in pairs(pointsList or {}) do
        local newPoint = copyTable(connectionPoint)
        rotatePoint(size, newPoint, direction)
        newPoint.facing = (newPoint.facing + direction) % 4
        table.insert(result, newPoint)
    end
    return result
end

-- prefab isn't changed, a new prefab is returned
local function copyAndRotatePrefab(prefab, direction)
    local result = copyTable(prefab)

    result.size = vector.new(prefab.size)
    result.connectionPoints = rotateConnectionPoints(result.size, prefab.connectionPoints, direction)
    result.decorationPoints = rotateConnectionPoints(result.size, prefab.decorationPoints, direction)

    if (direction % 2) == 1 then
        -- x size and z size will have switched
        result.size.x = prefab.size.z
        result.size.z = prefab.size.x
    end

    return result
end



-- returns a probability list of prefabs that have a name or type that matches nameOrType
-- (All items will have the same weighting, which can be limited by specifying totalWeight)
--
-- isForDecorationPoint provides some context in case nameOrType is "all"
local function expandPrefabNameOrType(nameOrType, isForDecorationPoint, totalWeight)

    if nameOrType == "none" then
        return {}
    end

    local result = {}
    local includeAsMemberOfAll = false
    local itemCount = 0

    for _, prefab in pairs(structGenLib.registered_prefabs) do

        if nameOrType == "all" then
            local prefabIsDecoration = structGenLib.registered_decoration_types[prefab.type] == true
            includeAsMemberOfAll = (isForDecorationPoint == prefabIsDecoration) or (isForDecorationPoint == nil)
        end

        if prefab.name == nameOrType or prefab.type == nameOrType or includeAsMemberOfAll then
            result[prefab.name] = 1
            itemCount = itemCount + 1
        end
    end

    if totalWeight ~= nil then
        -- adjust weightings so they sum to totalWeight
        for name, _ in pairs(result) do result[name] = totalWeight / itemCount end
    end

    return result
end

-- validPrefabs might be a name string, a prefab type, or a list of these with probabilities
-- return a new probability list of prefab names
-- isForDecorationPoint provides some context in case validPrefabs contains "all"
local function normalizeValidPrefabs(validPrefabs, isForDecorationPoint)

    local result = {}

    if type(validPrefabs) == 'string' then
        -- return all prefabs with a name or type that match the string
        return expandPrefabNameOrType(validPrefabs, isForDecorationPoint)

    elseif type(validPrefabs) == 'table' then
        -- expand out any prefab types
        for key, value in pairs(validPrefabs) do
            if type(value) == 'string' then
                -- this item in the table is a prefab name or prefab type
                for name, weight in pairs(expandPrefabNameOrType(value, isForDecorationPoint)) do
                    result[name] = (result[name] or 0) + weight
                end
            elseif type(value) == 'number' then
                -- this item in the table is a probability list item, but the key might be either a prefab name or prefab type
                for name, weight in pairs(expandPrefabNameOrType(key, isForDecorationPoint, value)) do
                    result[name] = (result[name] or 0) + weight
                end
            end
        end
        debug("## expanded probability table: %s", result)
    end
    return result;
end


local function connectionPointAllowsPrefab(connectionPoint, prefabName)
    local allValidPrefabs = normalizeValidPrefabs(connectionPoint.validPrefabs) -- get a probability list of valid prefabs
    local result = allValidPrefabs[prefabName] ~= nil
    debug("%s with validPreface[%s]: allows '%s' = %s", connectionPoint.type,  connectionPoint.validPrefabs, prefabName, result)
    return result
end


local function prefabTypeCanCollide(prefabType)
    local isDecoration = structGenLib.registered_decoration_types[prefabType] == true
    local isDeadEnd    = structGenLib.registered_deadend_types[prefabType]    == true
    local canCollide = not (isDecoration or isDeadEnd)

    --debug("prefabType %s canCollide = %s", prefabType, canCollide)
    return canCollide
end

-- returns true if the connectingPrefab was placed, false if it was unsuitable
local function tryPrefab(prefabName, prefabPos, connectionPoint, connectingPrefabName, recursionLimit)

    debug("tryPrefab(\"%s\", %s, %s, \"%s\", %s)", prefabName, prefabPos, connectionPoint, connectingPrefabName, recursionLimit)

    local connectionPos = vector.add(prefabPos, connectionPoint)
    if testIfPointAlreadyConnected(connectionPos) then
        -- this connection point has already been connected to something
        debug("tryPrefab called on point that was already connected - you should have caught this earlier")
        return false
    end

    -- find the points on connectingPrefab that are compatible with connectionPoint
    local connectingPrefab = structGenLib.registered_prefabs[connectingPrefabName]
    local isDecoration = structGenLib.registered_decoration_types[connectingPrefab.type] == true
    local pointsToTry
    if isDecoration then
        pointsToTry = connectingPrefab.decorationPoints or {}
    else
        pointsToTry = connectingPrefab.connectionPoints or {}
    end

    local matchingConnectionPoints = {}
    for _,point in ipairs(pointsToTry) do
        if point.type == connectionPoint.type then
            -- The connection point matches, but is this prefab in the connection point's valid prefab list?
            if connectionPointAllowsPrefab(point, prefabName) then
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
        decorationAnchor.validPrefabs = "all"
        decorationAnchor.type = connectionPoint.type
        table.insert(matchingConnectionPoints, decorationAnchor)
    end


    while #matchingConnectionPoints > 0 do
        local remotePoint = extractRandomElementFromArray(matchingConnectionPoints) -- removes the item from matchingConnectionPoints
        -- rotate and translate prefabPos so that the connectionPoints face each other and have the same coordinate
        -- the connectionPoints face each other if there direction are 180 degrees apart, which is a value of 2
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
        if prefabTypeCanCollide(connectingPrefab.type) then
            collision = testForCollision(p1, p2)
            debug("testForCollision for new '%s' returned %s", connectingPrefab.name, collision)
        end

        if not collision then
            markPointAsConnected(connectionPos, connectingPrefab.name)
            placePrefab(connectingPrefab.name, p1, newDirection, recursionLimit)
            --minetest.set_node(p1, {name="default:mese"}) -- debug marker
            --minetest.set_node(p2, {name="default:meselamp"})


            return true
        else
            debug("tryPrefab() aborting attempt to connect new '%s' to '%s' due to collision (prefab still has %s other connectionPoints to try)", connectingPrefab.name, prefabName, #matchingConnectionPoints)
        end
    end

    return false
end



local function placeDeadEnd(prefabName, prefabPos, connectionPoint)

    if structGenLib.deadendPrefabNamesByConnectionType == nil then
        structGenLib.deadendPrefabNamesByConnectionType = {}

        for _, prefab in pairs(structGenLib.registered_prefabs) do
            if structGenLib.registered_deadend_types[prefab.type] == true then
                -- this prefab is a deadend
                for _, point in pairs(prefab.connectionPoints) do
                    local prefabNames = structGenLib.deadendPrefabNamesByConnectionType[point.type]
                    if prefabNames == nil then prefabNames = {} end
                    table.insert(prefabNames, prefab.name)
                    structGenLib.deadendPrefabNamesByConnectionType[point.type] = prefabNames
                end
                debug("prefabNames for this deadend: %s", prefabNames)
            end
            debug("Checked '%s' for deadend: %s", prefab.type, structGenLib.registered_deadend_types[prefab.type] == true)
        end

        if tableCount(structGenLib.deadendPrefabNamesByConnectionType) then
            minetest.chat_send_all("WARNING: No dead-ends are specified for the structure-generator")
            minetest.log("warn", "WARNING: No dead-ends are specified the structure-generator")
        end
    end

    local validDeadendPrefabNames = structGenLib.deadendPrefabNamesByConnectionType[connectionPoint.type]
    local deadendPrefabName = pickRandomElementFromArray(validDeadendPrefabNames)

    if deadendPrefabName ~= nil then
        debug("Attempting deadend '%s'", deadendPrefabName)
        tryPrefab(prefabName, prefabPos, connectionPoint, deadendPrefabName, 1)
    end
end

local function placeConnections(prefab, pos, isDecorationPoints, recursionLimit)

    local pointList = prefab.connectionPoints
    local avoidCollisions = true
    if isDecorationPoints then
        pointList = prefab.decorationPoints
        avoidCollisions = false -- decoration points work the same as connection points except we don't check for spacial collisions
    end

    for i, point in pairs(pointList) do

        -- One of the entraces is probably already connected to the prefab that spawned this one, so skip that connection point
        if not testIfPointAlreadyConnected(vector.add(pos, point)) then
            local validPrefabs
            if recursionLimit > 0 or (isDecorationPoints and recursionLimit > -2) then -- ensure a room at the recursion limit can still be decorated
                validPrefabs = normalizeValidPrefabs(point.validPrefabs, isDecorationPoints) -- get a probability list of valid prefabs
            else
                validPrefabs = {}
            end

            debug("placeConnections found %s validPrefabs for point %s of %s", tableCount(validPrefabs), i, tableCount(pointList))

            local connectionPlaced = false;
            local nextPrefabName
            repeat
                nextPrefabName = selectFromProbabilityList(validPrefabs)
                if nextPrefabName ~= nil then
                    validPrefabs[nextPrefabName] = nil -- remove it from the probability list so if we fail to place it we can try another
                    connectionPlaced = tryPrefab(prefab.name, pos, point, nextPrefabName, recursionLimit)
                end
            until connectionPlaced or nextPrefabName == nil

            if not connectionPlaced and not isDecorationPoints then
                debug("placeConnections falling back to dead-end on '%s'", prefab.name)
                placeDeadEnd(prefab.name, pos, point)
            end
        end
    end

end


placePrefab = function(prefabName, pos, direction, recursionLimit)

    debug("Placing '%s' at %s facing %s, recursions remaining %s", prefabName, pos, direction, recursionLimit)

    recursionLimit = recursionLimit - 1
    local prefab = copyAndRotatePrefab(structGenLib.registered_prefabs[prefabName], direction)

    minetest.place_schematic(
        pos,
        modPath .. DIR_DELIM .. prefab.schematic,
        direction * 90,
        {},  -- node replacements
        true -- force_placement
    )

    if prefabTypeCanCollide(prefab.type) then
        local pos2 = vector.add(pos, vector.subtract(prefab.size, 1))
        addToCollisionTable(pos, pos2)
        --minetest.set_node(pos,  {name="default:mese"}) -- debug marker
        --minetest.set_node(pos2, {name="default:meselamp"})
    end

    placeConnections(prefab, pos, false, recursionLimit) -- connectionPoints
    placeConnections(prefab, pos, true,  recursionLimit) -- decorationPoints
end


-- direction: nil for random. May be 0, 1, 2, 3
-- seed: nil for random
-- recursionLimit: nil for default
function structGenLib.build_structure(firstPrefabName, pos, direction, seed, recursionLimit)
    debug("build_structure(%s, %s, %s, %s, %s)", firstPrefabName, pos, direction, seed, recursionLimit)

    recursionLimit = recursionLimit or defaultRecursionLimit

    if structGenLib.registered_prefabs[firstPrefabName] == nil then
        error("build_structure() told to build \"" .. firstPrefabName .. "\", but there's no registered prefab with that name")
    end

    setRngSeed(seed)
    if direction == nil then direction = getRngInt(0, 3) end

    clearCollisionTable()
    placePrefab(firstPrefabName, pos, direction, recursionLimit)
end