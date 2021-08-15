
if not (minetest.global_exists("structure_generator") and structure_generator.lib ~= nil) then
    error("structure_scaffolding_tool.lua depends on structure_generator_lib.lua")
end
local S = structure_generator.get_translator



-- ==========================
--           Nodes
-- ==========================

local nodeName_replaceable = structure_generator.modName .. ":replaceable_node"
minetest.register_node(nodeName_replaceable, {
    description = S("Replacable air@nWhen a schematic is placed, this node is replaced with what was already in the map at that location"),
    drawtype = "glasslike",
    paramtype = "light",
    inventory_image = "[inventorycube{structure_generator_replaceable.png{structure_generator_replaceable.png{structure_generator_replaceable.png",
    tiles = {
        "structure_generator_replaceable.png^[opacity:70",
    },
    use_texture_alpha = "blend",
    groups = { dig_immediate = 3 },
})

-- An indestructible sign/label node to hold metadata.
-- Indestructible so you don't accidentally mine it and make your prefabs unexportable
local nodeName_indestructibleTag = structure_generator.modName .. ":sign"
minetest.register_node(nodeName_indestructibleTag, {
    description = S("An indestructible info tag"),
    drawtype = "nodebox",
    tiles = {"structure_generator_label.png", "structure_generator_sides.png"},
    inventory_image = "structure_generator_label.png",
    paramtype = "light",
    paramtype2 = "facedir",
    sunlight_propagates = true,
    is_ground_content = false,
    walkable = false,
    node_box = {
        type = "fixed",
        fixed = {-0.5, -0.5, -0.5, 0.5, -0.4375, 0.5}
    },
    groups = { not_in_creative_inventory = 1 },
    on_blast = function() end,
    on_destruct = function () end,
    can_dig = function() return false end,
    diggable = false,
    drop = ""
})

local nodeName_extrusionSwitch = structure_generator.modName .. ":switch_extrusion"
minetest.register_node(nodeName_extrusionSwitch, {
    description = S("Place next to a prefab to indicate the bottom layer should be used to create foundations reaching the ground"),
    drawtype = "nodebox",
    tiles = {"structure_generator_switch_extrusion.png", "structure_generator_sides.png"},
    inventory_image = "structure_generator_switch_extrusion.png",
    paramtype = "light",
    paramtype2 = "facedir",
    sunlight_propagates = true,
    is_ground_content = false,
    walkable = false,
    node_box = {
        type = "fixed",
        fixed = {-0.5, -0.5, -0.5, 0.5, -0.4375, 0.5}
    },
    groups = { dig_immediate = 3 },
})

local function registerPointMarkerNode(markerType, pointLocation)

    local localizedType     = S(markerType)
    local localizedLocation = S(pointLocation)
    local location_short = pointLocation:gsub("-", "")
    local tileImage = "structure_generator_" .. markerType .. "_point_" .. location_short .. ".png"
    local nodeName = structure_generator.modName .. ":" .. markerType .. "_marker_" .. location_short

    minetest.register_node(nodeName, {
        description = S("Mark @1-point at @2@nIndicates to the templates tool to export the @3 co-ordinates as a @4-point of the nearest prefab", localizedType, localizedLocation, localizedLocation, localizedType),
        drawtype = "nodebox",
        tiles = {tileImage, "structure_generator_sides.png"},
        inventory_image = tileImage,
        paramtype = "light",
        paramtype2 = "facedir",
        sunlight_propagates = true,
        is_ground_content = false,
        walkable = false,
        node_box = {
            type = "fixed",
            fixed = {-0.5, -0.5, -0.5, 0.5, -0.4375, 0.5}
        },
        groups = { dig_immediate = 3 },
    })
    return nodeName
end

local nodeName_connection_topLeft = registerPointMarkerNode("connection", "top-left")
local nodeName_connection_top     = registerPointMarkerNode("connection", "top")
local nodeName_connection_center  = registerPointMarkerNode("connection", "center")
local nodeName_decoration_topLeft = registerPointMarkerNode("decoration", "top-left")
local nodeName_decoration_top     = registerPointMarkerNode("decoration", "top")
local nodeName_decoration_center  = registerPointMarkerNode("decoration", "center")

local nodelist_connection  = {nodeName_connection_topLeft, nodeName_connection_top, nodeName_connection_center}
local nodelist_decoration  = {nodeName_decoration_topLeft, nodeName_decoration_top, nodeName_decoration_center}
local nodelist_topLeft     = {nodeName_decoration_topLeft, nodeName_connection_topLeft}
local nodelist_top         = {nodeName_decoration_top, nodeName_connection_top}
local nodelist_center      = {nodeName_decoration_center, nodeName_connection_center}
local nodelist_flags       = {nodeName_extrusionSwitch}

local nodelist_connection_and_decoration = {}
for _,v in pairs(nodelist_connection) do table.insert(nodelist_connection_and_decoration, v) end
for _,v in pairs(nodelist_decoration) do table.insert(nodelist_connection_and_decoration, v) end



-- ==================================
--         Import and Export
-- ==================================

local templateDistance     = 6
local signDistance         = 2
local nodeSearchDist       = 2
local startPosSearchRadius = 10
local boundingBoxNode      = {name = nodeName_replaceable}
local exportDirectory      = "schems"
local codeTemplateFile     = "example_ready_to_build.lua"


function sanitizeFilename(name)
    return name:gsub("[%s<>~:\"/\\\\|?*]", "_")
end

function getSchematicFilename(prefabName)
    local filename = sanitizeFilename(prefabName) .. ".mts"
    return minetest.get_worldpath() .. DIR_DELIM .. exportDirectory .. DIR_DELIM .. filename
end

function getCodeTemplateFilename()
    return minetest.get_worldpath() .. DIR_DELIM .. exportDirectory .. DIR_DELIM .. codeTemplateFile
end


function fileExists(filename)
    local f = io.open(filename, "r")
    if f == nil then
        return false
    else
        f:close()
        return true
    end
end

function tableContains(table, element)
    for _, value in pairs(table) do
        if element == value then
            return true
        end
    end
    return false
end


-- only place sign in air nodes or over existing signs, to avoid damaging prefabs already on the map
function placeSign(pos, text)
    local existingNode = minetest.get_node_or_nil(pos)
    if existingNode ~= nil and (existingNode.name == 'air' or existingNode.name == nodeName_indestructibleTag) then
        minetest.set_node(pos, {name=nodeName_indestructibleTag})

        local meta = minetest.get_meta(pos)
        meta:set_string("text", text)
        meta:set_string("infotext", text)--S('"@1"', text))
    end
    if existingNode == nil then structure_generator.debug("Sign not placed at %s because existingNode was nil", pos) end
end

-- only place scaffold/boundingbox nodes in air, to avoid damaging prefabs already on the map
-- returns false if the map wasn't loaded at pos, so the function couldn't run
function setScaffoldNode(pos)
    return setFillNode(pos, boundingBoxNode)
end

-- only place nodes in air/boundingboxs, to avoid damaging prefabs already on the map
-- returns false if the map wasn't loaded at pos, so the function couldn't run
function setFillNode(pos, node)
    local existingNode = minetest.get_node_or_nil(pos)

    if existingNode ~= nil and (existingNode.name == "air" or existingNode.name == boundingBoxNode.name) then
        minetest.set_node(pos, node)
    end

    if existingNode == nil then
        --structure_generator.debug("node not placed at %s because existingNode was nil - did emerge fail?", pos)
        return false
    end
    return true
end



local function createBoundingBoxes(playerName, startPos)
    local prefabsScaffolded = 0
    local emergeFailures = 0
    local xMax = 0
    local yMax = 0
    local zMax = 0

    local scaffolds = {}
    local startPos_scaffold = vector.add(startPos, vector.new(signDistance, 0, signDistance))
    local pos = vector.new(startPos_scaffold)

    for _,prefab in pairs(structure_generator.lib.registrationOrdered_prefabs) do

        if type(prefab.name) ~= 'string' then
            minetest.chat_send_player(playerName, "skipping prefab as it has no .name property (templates tool can only work with named prefabs)")
        elseif not structure_generator.isVector(prefab.size) then
            minetest.chat_send_player(playerName, "skipping prefab '" .. prefab.name .. "' as it has no .template_size vector")
        elseif prefab.type == 'none' then
            minetest.chat_send_player(playerName, "skipping prefab of .type 'none', you don't need to define a prefab of that type")
        else
            table.insert(scaffolds, {
                prefab = prefab,
                pos =  vector.new(pos)
            })

            local xSize = prefab.size.x - 1
            local ySize = prefab.size.y - 1
            local zSize = prefab.size.z - 1

            if xSize > xMax then xMax = xSize end
            if ySize > yMax then yMax = ySize end
            zMax = pos.z + zSize

            pos.z = pos.z + prefab.size.z + templateDistance
            prefabsScaffolded = prefabsScaffolded + 1
        end
    end

    --structure_generator.debug("Scaffolds list %s", scaffolds)

    local minp = startPos
    local maxp = {x = startPos_scaffold.x + xMax, y = startPos_scaffold.y + yMax, z = startPos_scaffold.z + zMax}
    minetest.emerge_area(
        minp, maxp,
        function(blockpos, action, calls_remaining, param)
            --structure_generator.debug("emerge_area callbacks remaining %s, action %s", calls_remaining, action)
            if calls_remaining == 0 then
                -- area should now be fully emerged and loaded, so we can add scaffolding while
                -- also checking to ovoid overwriting any existing work.

                for i,scaffold in ipairs(scaffolds) do
                    local prefab = scaffold.prefab
                    local pos    = scaffold.pos

                    local xSize  = prefab.size.x - 1
                    local ySize  = prefab.size.y - 1
                    local zSize  = prefab.size.z - 1
                    local signlocation = {x = pos.x - signDistance, y = pos.y, z = pos.z}
                    local schematicFile = getSchematicFilename(prefab.name)

                    placeSign(
                        signlocation,
                        i .. ") " .. prefab.name .. "\n" .. S("Type: @1, size @2", structure_generator.toString(prefab.type), minetest.pos_to_string(prefab.size)  .. "\n" .. schematicFile)
                    )
                    -- store the template data in the indestructible-sign's location's metadata
                    local meta = minetest.get_meta(signlocation)
                    meta:set_string("template_name", prefab.name)
                    meta:set_string("template_size", minetest.pos_to_string(prefab.size))
                    meta:set_string("template_type", prefab.type)


                    local success = true
                    for z = 0, zSize do
                        success = success and setScaffoldNode({x = pos.x,         y = pos.y,         z = pos.z + z})
                        success = success and setScaffoldNode({x = pos.x + xSize, y = pos.y,         z = pos.z + z})
                        success = success and setScaffoldNode({x = pos.x,         y = pos.y + ySize, z = pos.z + z})
                        success = success and setScaffoldNode({x = pos.x + xSize, y = pos.y + ySize, z = pos.z + z})
                    end
                    for x = 1, xSize - 1 do
                        success = success and setScaffoldNode({x = pos.x + x, y = pos.y,         z = pos.z        })
                        success = success and setScaffoldNode({x = pos.x + x, y = pos.y,         z = pos.z + zSize})
                        success = success and setScaffoldNode({x = pos.x + x, y = pos.y + ySize, z = pos.z        })
                        success = success and setScaffoldNode({x = pos.x + x, y = pos.y + ySize, z = pos.z + zSize})
                    end
                    for y = 1, ySize - 1 do
                        success = success and setScaffoldNode({x = pos.x        , y = pos.y + y, z = pos.z        })
                        success = success and setScaffoldNode({x = pos.x        , y = pos.y + y, z = pos.z + zSize})
                        success = success and setScaffoldNode({x = pos.x + xSize, y = pos.y + y, z = pos.z        })
                        success = success and setScaffoldNode({x = pos.x + xSize, y = pos.y + y, z = pos.z + zSize})
                    end

                    if fileExists(schematicFile) then
                        -- load the schematic with write_yslice_prob set to 'none' before placing the schematic,
                        -- so that any prefabs with a "foundation" layer will have all their layers imported.
                        -- (the foundation layers have a layer-probability of 0)
                        local schematic = minetest.read_schematic(schematicFile, {write_yslice_prob = "none"})
                        minetest.place_schematic(
                            pos,
                            schematic,
                            0,   -- orientation
                            {},  -- node replacements
                            true -- force_placement
                        )
                    end

                    if not success then
                        -- area wasn't fully loaded
                        emergeFailures = emergeFailures + 1
                        structure_generator.debug("Failed to scaffold %s at %s (map not loaded, so could not check the area was empty)", prefab.name, pos)
                    else
                        structure_generator.debug("Scaffolded %s at %s", prefab.name, pos)
                    end
                end

                if emergeFailures > 0 then
                    minetest.chat_send_player(playerName, "WARNING: " .. emergeFailures .. " scaffolds failed because the map wasn't loaded in that area and I don't want to overwrite prefabs. Run the command again after visiting the area.")
                end

                if prefabsScaffolded > 0 then
                    -- store in metadata that this is the start of the templates
                    -- and the minp/maxp so an export function can ensure all chunks are loaded
                    placeSign(
                        startPos,
                        S("The origin of these prefabs is @1, so to export them:@n  /export_prefabs @2",  minetest.pos_to_string(startPos),  minetest.pos_to_string(startPos))
                    )
                    local meta = minetest.get_meta(startPos)
                    meta:set_string("template_minp", minetest.pos_to_string(minp))
                    meta:set_string("template_maxp", minetest.pos_to_string(maxp))

                    minetest.chat_send_player(playerName, S("To erase the scaffolded area, use: /cleararea @1 @2   or   /deleteblocks @3 @4", minetest.pos_to_string(minp), minetest.pos_to_string(maxp), minetest.pos_to_string(minp), minetest.pos_to_string(maxp)))
                end

            end
        end
    )

    return true, prefabsScaffolded .. " prefabs are being scaffolded at " .. minetest.pos_to_string(startPos)
end


-- rotation can equal 0, 1, 2, or 3, and is clockwise around the y axis at (0.5, 0.5)
-- i.e. the lower 2 bits in a facedir
local function rotatePoint(normalizedVec, rotation)
    for _ = 1, rotation do
        local xOriginal = normalizedVec.x
        normalizedVec.x = normalizedVec.z
        normalizedVec.z = 1 - xOriginal
    end
end


-- returns (connectionPointList, decorationPointList)
local function findConnectionPoints(prefab)

    local connectionPoints = {}
    local decorationPoints = {}

    local pointNodesPositions = minetest.find_nodes_in_area(
        vector.add(prefab.p1, -nodeSearchDist),
        vector.add(prefab.p2,  nodeSearchDist),
        nodelist_connection_and_decoration
    )

    structure_generator.debug("found %s connection point(s) on \"%s\" from %s to %s", #pointNodesPositions, prefab.name, vector.add(prefab.p1, -2), vector.add(prefab.p2, 2))
    for _, pos in ipairs(pointNodesPositions) do
        local pointNode = minetest.get_node(pos)
        local point = {x = pos.x - prefab.p1.x, y = pos.y - prefab.p1.y, z = pos.z - prefab.p1.z}

        local cornerOffset
        if tableContains(nodelist_topLeft, pointNode.name) then
            cornerOffset = vector.new(0, 0, 1)
        elseif tableContains(nodelist_top, pointNode.name) then
            cornerOffset = vector.new(0.5, 0, 1)
        else
            cornerOffset = vector.new(0.5, 0, 0.5)
        end

        if pointNode.param2 > 3 then
            -- someone's been naughty with a screwdriver, fix it, since we only support facings 0 to 3 (compass directions)
            pointNode.param2 = pointNode.param2 - (math.floor(pointNode.param2 / 4) * 4)
            minetest.set_node(pos, pointNode)
        end
        rotatePoint(cornerOffset, pointNode.param2)
        point = vector.add(point, cornerOffset)

        if point.z >= prefab.size.z then point.facing = 0 end -- connection is probably facing North
        if point.x >= prefab.size.x then point.facing = 1 end -- connection is probably facing East
        if point.z <= 0 then point.facing = 2 end             -- connection is probably facing South
        if point.x <= 0 then point.facing = 3 end             -- connection is probably facing west

        if tableContains(nodelist_center, pointNode.name) then
            -- With center markers we can use their direction, since they are not constrained in orientation.
            -- This is very convenient with decoration markers
            point.facing = (pointNode.param2 + 2) % 4 -- add 2 (180 degrees) because when I place a marker down such that I can read it, I'm expecting the decoration to be facing back at me
        end
        point.facing = point.facing or 0

        if tableContains(nodelist_connection, pointNode.name) then
            table.insert(connectionPoints, point)
        elseif tableContains(nodelist_decoration, pointNode.name) then
            table.insert(decorationPoints, point)
        end
    end
    return connectionPoints, decorationPoints
end


local function savePrefabSchematic(prefab)

    -- find all the replacable-air nodes so we can set their probability to zero
    local nodeNamesToIgnore = {nodeName_replaceable}
    for _,v in pairs(nodelist_connection_and_decoration) do table.insert(nodeNamesToIgnore, v) end -- ignore any connection-point nodes inside the schematic
    for _,v in pairs(nodelist_flags)                     do table.insert(nodeNamesToIgnore, v) end -- ignore any flag/switch nodes inside the schematic

    local nodesToIgnore = minetest.find_nodes_in_area(
        prefab.p1,
        prefab.p2,
        nodeNamesToIgnore
    )
    local nodeProbabilityList = {}
    for _, pos in ipairs(nodesToIgnore) do
        table.insert(nodeProbabilityList, {pos = pos, prob = 0})
    end

    local _, flagNodeCounts = minetest.find_nodes_in_area(
        vector.add(prefab.p1, -nodeSearchDist),
        vector.add(prefab.p2,  nodeSearchDist),
        nodelist_flags
    )
    local layerProbabilityList = {}
    if flagNodeCounts[nodeName_extrusionSwitch] > 0 then
        -- A "Foundation" switch has been placed next to this prefab.
        -- Prevent the bottom layer from being drawn, it instead holds the foundation
        -- nodes to extrude to the ground if the prefab is placed in the air.
        layerProbabilityList = {{ypos=0, prob=0}}
    end

    local filename = getSchematicFilename(prefab.name)
    local ret = minetest.create_schematic(
        prefab.p1,
        prefab.p2,
        nodeProbabilityList,
        filename,
        layerProbabilityList
    )
    if ret == nil then
        return nil
    end

    -- save the lua version of the schematic as well
    local lua = minetest.serialize_schematic(filename, "lua", {lua_use_comments = true})
    local file = io.open(filename:gsub(".mts", ".lua"), "w")
    if file == nil then
        structure_generator.debug("Could not open file for writing: %s", file)
    else
        file:write(lua)
        file:close()
    end

    return filename
end

local function writeBoilerplate(file, prefabList)
    file:write("-- Auto-generated\n")
    file:write("local structGenLib = my_mod_namespace.get_structure_generator_lib()\n\n")

    file:write("-- connection points will only attach to connection points of the same type\n")
    file:write("local connectionType = {\n")
    file:write("    doorway2x3                = \"doorway2x3\", -- make something up\n")
    file:write("    inventSomeConnectionTypes = \"inventSomeConnectionTypes\"\n")
    file:write("}\n\n")

    local prefabEnums = {}
    for _, prefab in pairs(prefabList) do
        if prefabEnums[prefab.type] == nil then
            prefabEnums[prefab.type] = true
        end
    end

    file:write("local prefabType = {\n")
    file:write("    none = \"none\", -- built-in enum\n")
    file:write("    all  = \"all\",  -- built-in enum\n\n")

    for typeName,_ in pairs(prefabEnums) do
        file:write("    " .. typeName .. " = \"" .. typeName .. "\",\n")
    end
    file:write("}\n\n")
end

local function writeConnectionPoints(file, connectionPoints, isDecorations)

    local adj = "connection"
    if isDecorations then adj = "decoration" end

    file:write("    " .. adj .. "Points = {")

    if #connectionPoints == 0 then
        file:write("}")
    else
        local first = true
        for _, point in pairs(connectionPoints) do
            if not first then file:write(",") end
            first = false

            file:write("{\n")
            file:write("            x = " .. point.x .. ", y = " .. point.y.. ", z = " .. point.z .. ",\n")
            file:write("            type         = connectionType.inventSomeConnectionTypes," .. "\n")
            file:write("            facing       = " .. point.facing .. ",\n")
            file:write("            validPrefabs = prefabType.all" .. "\n")
            --file:write("        verticalFacing = \"none\"," .. "\n")
            --file:write("        symmetry       = \"none\"," .. "\n") use registerSymmetricalConnectionType() instead
            file:write("        }")
        end
        file:write("\n")
        file:write("    }")
    end
end


local function savePrefabCodeTemplate(prefabList)

    local filename = getCodeTemplateFilename()
    local file = io.open(filename, "w")

    writeBoilerplate(file, prefabList)

    for _, prefab in pairs(prefabList) do
        local connectionPoints, decorationPoints = findConnectionPoints(prefab)

        file:write("\n")
        file:write("structGenLib.register_prefab({" .. "\n")
        file:write("    name             = \"" .. prefab.name .. "\",\n")
        file:write("    size             = vector.new" .. minetest.pos_to_string(prefab.size) .. ",\n")
        file:write("    type             = prefabType." .. prefab.type .. ",\n")
        file:write("    schematic        = \"" .. sanitizeFilename(prefab.name) .. ".mts\",\n")

        writeConnectionPoints(file, connectionPoints, false)
        if #decorationPoints > 0 then
            file:write(",\n")
            writeConnectionPoints(file, decorationPoints, true)
        end
        file:write("\n")
        file:write("});" .. "\n")
    end
    file:close()
end


-- Loads the map and invokes callback(prefabList, callbackParam)
-- startpos should be the sign/tag at the start of the row of prefabs
-- returns (success, errorstring) where success is a boolean, and errorString is only set if success is false
function findPrefabsOnMap(startPos, callback, callbackParam)

    local startPos_scaffold = vector.add(startPos, vector.new(signDistance, 0, signDistance))

    local meta = minetest.get_meta(startPos)
    local minp = minetest.string_to_pos(meta:get_string("template_minp"))
    local maxp = minetest.string_to_pos(meta:get_string("template_maxp"))

    if minp == nil or maxp == nil then
        return false, S("The position @1 is not the start of a prefab set. Look for an info tag that says 'The origin of these prefabs is...'", minetest.pos_to_string(startPos))
    end

    -- this scanPrefabs() function will be invoked after all the map area is emerged/loaded
    local scanPrefabs = function()
        local prefabList = {}
        local pos = vector.new(startPos_scaffold)

        local prefabFound
        repeat
            local signlocation = {x = pos.x - signDistance, y = pos.y, z = pos.z}
            local meta = minetest.get_meta(signlocation)
            local template_name = meta:get_string("template_name")
            local template_size = minetest.string_to_pos(meta:get_string("template_size"))
            local template_type = meta:get_string("template_type")
            prefabFound = template_name ~= "" and template_size ~= nil

            if prefabFound then
                local prefab =  {
                    name = template_name,
                    type = template_type,
                    size = template_size,
                    p1 = vector.new(pos),
                    p2 = vector.add(pos, vector.add(template_size, -1))
                }
                table.insert(prefabList, prefab)
                pos.z = pos.z + template_size.z + templateDistance
            end
        until not prefabFound

        callback(prefabList, callbackParam)
    end

    -- Ensure all the map is loaded first so we won't miss any prefabs
    minetest.emerge_area(
        vector.add(minp, -nodeSearchDist),
        vector.add(maxp,  nodeSearchDist),
        function(blockpos, action, calls_remaining, param)
            if calls_remaining == 0 then
                -- area should now be fully emerged and loaded, so we can add scaffolding while
                -- also checking to ovoid overwriting any existing work.

                -- get out of the emerge thread before doing it, as file exports etc. coming
                -- from the emerge thread looks odd in the logs.
                minetest.after(0.001, scanPrefabs)
            end
        end
    )

    return true
end


local function handle_exportPrefabs(playerName, startPos)

    local callback_exportPrefabs = function(prefabList)

        local path = minetest.get_worldpath() .. DIR_DELIM .. exportDirectory
		minetest.mkdir(path) -- Create dir if it doesn't already exist

        for _, prefab in pairs(prefabList) do
            local fileName = savePrefabSchematic(prefab)

            if fileName ~= nil then
                minetest.chat_send_player(playerName, S("Saved prefab '@1' to '@2'", prefab.name, fileName))
            else
                minetest.chat_send_player(playerName, S("Failed to saved prefab '@1' to '@2'",  prefab.name, fileName))
            end
        end

        savePrefabCodeTemplate(prefabList)
        minetest.chat_send_player(playerName, S("@1 prefabs found and saved",  #prefabList))
    end


    local success, errorString = findPrefabsOnMap(startPos, callback_exportPrefabs)
    return success, errorString
end

-- returns nil if no nearby startpos could be found
function findNearbyStartPos(playerName)

    local result = nil

    local player = minetest.get_player_by_name(playerName)
    if player == nil then
        minetest.chat_send_player(playerName, S("Unknown player position"))
    else
        local playerPos = vector.round(player:get_pos())
        local p1 = vector.add(playerPos, -startPosSearchRadius)
        local p2 = vector.add(playerPos,  startPosSearchRadius)

        local tagPositions = minetest.find_nodes_in_area(p1, p2, nodeName_indestructibleTag)
        for _, pos in ipairs(tagPositions) do
            local meta = minetest.get_meta(pos)
            local minp = minetest.string_to_pos(meta:get_string("template_minp"))
            local maxp = minetest.string_to_pos(meta:get_string("template_maxp"))

            if minp ~= nil and maxp ~= nil then
                result = minp
                break
            end
        end
    end
    return result
end



-- =======================================
--        Rudimentary edit functions
-- =======================================

function handle_fillFloors(startPos, nodeName, height, measureHeightFromCeiling)
    --structure_generator.debug("handle_fillFloors(%s, %s, %s, %s)", startPos, nodeName, height, measureHeightFromCeiling)

    local callback_fillFloors = function(prefabList)
        for _, prefab in pairs(prefabList) do
            local pos    = prefab.p1
            local xSize  = prefab.size.x - 1
            local ySize  = prefab.size.y - 1
            local zSize  = prefab.size.z - 1
            local node = {name = nodeName}

            local y = height
            if measureHeightFromCeiling then y = ySize - height end
            y = y + pos.y

            for z = 0, zSize do
                for x = 0, xSize do
                    setFillNode({x = pos.x + x, y = y, z = pos.z + z}, node)
                    setFillNode({x = pos.x + x, y = y, z = pos.z + z}, node)
                end
            end
        end

        if measureHeightFromCeiling then
            minetest.chat_send_all(S("Ceailings filled on @1 prefabs",  #prefabList))
        else
            minetest.chat_send_all(S("Floors filled on @1 prefabs",  #prefabList))
        end
        minetest.chat_send_all(S("Existing blocks were not touched, to erase the existing area use /deleteblocks and re-scaffold with /scaffold_prefabs"))
    end

    local success, errorString = findPrefabsOnMap(startPos, callback_fillFloors)
    return success, errorString
end


function handle_fillWalls(startPos, nodeName, startHeight, wallHeight)
    --structure_generator.debug("handle_fillWalls(%s, %s, %s, %s)", startPos, nodeName, startHeight, wallHeight)

    local callback_fillWalls = function(prefabList)
        for _, prefab in pairs(prefabList) do
            local pos    = prefab.p1
            local xSize  = prefab.size.x - 1
            local ySize  = prefab.size.y - 1
            local zSize  = prefab.size.z - 1

            local top = ySize - (wallHeight or 0)
            local node = {name = nodeName}

            for y = startHeight, top do
                for z = 0, zSize do
                    setFillNode({x = pos.x,         y = pos.y + y, z = pos.z + z}, node)
                    setFillNode({x = pos.x + xSize, y = pos.y + y, z = pos.z + z}, node)
                end
                for x = 1, xSize - 1 do
                    setFillNode({x = pos.x + x,     y = pos.y + y, z = pos.z        }, node)
                    setFillNode({x = pos.x + x,     y = pos.y + y, z = pos.z + zSize}, node)
                end
            end
        end
        minetest.chat_send_all(S("Walls filled on @1 prefabs",  #prefabList))
        minetest.chat_send_all(S("Existing blocks were not touched, to erase the existing area use /deleteblocks and re-scaffold with /scaffold_prefabs"))
    end

    local success, errorString = findPrefabsOnMap(startPos, callback_fillWalls)
    return success, errorString
end


function handle_clearArea(p1, p2)

    -- Ensure all the map is loaded first so we won't miss any prefabs
    minetest.emerge_area(
        p1, p2,
        function(blockpos, action, calls_remaining, param)
            if calls_remaining == 0 then
                -- area should now be fully emerged and loaded, so we can add scaffolding while
                -- also checking to ovoid overwriting any existing work.

                local namePrefix =  structure_generator.modName .. ":"
                local namePrefixLength = string.len(namePrefix)
                local airNode = {name = "air"}
                local pos = vector.new()
                for y = p1.y, p2.y do
                    pos.y = y
                    for z = p1.z, p2.z do
                        pos.z = z
                        for x = p1.x, p2.x do
                            pos.x = x
                            local existingNode = minetest.get_node_or_nil(pos)

                            if existingNode ~= nil then
                                local deleteNode = true
                                if string.sub(existingNode.name,1,namePrefixLength) == namePrefix then
                                    -- it's a structure_generator node, only delete the replaceable air
                                    deleteNode = existingNode.name == nodeName_replaceable
                                end

                                if deleteNode then
                                    minetest.set_node(pos, airNode)
                                end
                            end
                        end
                    end
                end


            end
        end
    )
end


-- ==================================
--         Chat commands
-- ==================================

minetest.register_chatcommand(
    "scaffold_prefabs",
	{
		description = S("Creates a bounding box for each structure schematic that has been registered"),
		privs = {debug = true}, -- you shouldn't run this mod on a real server, it's a tool for developing mods. Requiring debug to be safe.
        params = "[<X>,<Y>,<Z>]",
		func = function(playerName, param)

            local p = {}
            local origin = vector.new(0, 9, 0)
            p.x, p.y, p.z = param:match("^([%d.-]+)[, ] *([%d.-]+)[, ] *([%d.-]+)$")
            p = vector.apply(p, tonumber)

            if param == "" then
                p = findNearbyStartPos(playerName) or origin -- no position was specified, use the default
            end

            if p.x and p.y and p.z then
                return createBoundingBoxes(playerName, p)
            end

            return false, S("Invalid Argument. Specify either <x>, <y>, <z> or nothing. If nothing is specified then the origin will be assumed @1.", minetest.pos_to_string(origin))
		end
	}
)

minetest.register_chatcommand(
    "export_prefabs",
	{
		description = S("Saves the contents of bounding boxes in .mts files and creates template lua code to register them as prefabs with their connection points"),
		privs = {debug = true}, -- you shouldn't run this mod on a real server, it's a tool for developing mods. Requiring debug to be safe.
        params = "[<X>,<Y>,<Z>]",
		func = function(playerName, param)

            local p = {}
            local origin = vector.new(0, 9, 0)
            p.x, p.y, p.z = param:match("^([%d.-]+)[, ] *([%d.-]+)[, ] *([%d.-]+)$")
            p = vector.apply(p, tonumber)

            if param == "" then
                p = findNearbyStartPos(playerName) or origin -- no position was specified, use the default
            end

            if p.x and p.y and p.z then
                return handle_exportPrefabs(playerName, p)
            end

            return false, S("Invalid Argument. Specify either <x>, <y>, <z> or nothing. If nothing is specified then the origin will be assumed @1.", minetest.pos_to_string(origin))
		end
	}
)

minetest.register_chatcommand(
    "fill_floors",
	{
		description = S("Non-destructively fills a layer in each prefab, optionally at a height measured from the bottom of the prefab."),
		privs = {debug = true}, -- you shouldn't run this mod on a real server, it's a tool for developing mods. Requiring debug to be safe.
        params = S("<nodeName> [<height>]"),
		func = function(playerName, param)
            local nodeName, height = string.match(param, "^([^ ]+) +(%d+) *$")
            if nodeName == nil then nodeName = string.match(param, "^([^ ]+) *$") end -- perhaps a height wasn't specified

            if nodeName == nil then
                return false, S("The node type you wish to fill the floor with must be specified.")
            elseif minetest.registered_nodes[nodeName] == nil then
                return false, S("Node type \"@1\" not known", nodeName)
            end

            local startPos = findNearbyStartPos(playerName)
            if startPos == nil then
                return false, S("Stand near the start tag/sign of the set of the prefabs you want to fill.")
            end

            return handle_fillFloors(startPos, nodeName, height or 0)
		end
	}
)

minetest.register_chatcommand(
    "fill_ceilings",
	{
		description = S("Non-destructively fills a layer in each prefab, at a height measured from the top of the prefab."),
		privs = {debug = true}, -- you shouldn't run this mod on a real server, it's a tool for developing mods. Requiring debug to be safe.
        params = S("<nodeName> [<height>]"),
		func = function(playerName, param)
            local nodeName, height = string.match(param, "^([^ ]+) +(%d+) *$")
            if nodeName == nil then nodeName = string.match(param, "^([^ ]+) *$") end -- perhaps a height wasn't specified

            if nodeName == nil then
                return false, S("The node type you wish to fill the floor with must be specified.")
            elseif minetest.registered_nodes[nodeName] == nil then
                return false, S("Node type \"@1\" not known", nodeName)
            end

            local startPos = findNearbyStartPos(playerName)
            if startPos == nil then
                return false, S("Stand near the start-tag/sign of the set of the prefabs you want to fill.")
            end

            return handle_fillFloors(startPos, nodeName, height or 0, true)
		end
	}
)

minetest.register_chatcommand(
    "fill_walls",
	{
		description = S("Non-destructively fills a layer in each prefab, at a height measured from the top of the prefab."),
		privs = {debug = true}, -- you shouldn't run this mod on a real server, it's a tool for developing mods. Requiring debug to be safe.
        params = S("<nodeName> [<startHeight> [<wallHeight>]]"),
		func = function(playerName, param)
            local nodeName, startHeight, wallHeight = string.match(param, "^([^ ]+) +(%d+) +(%d+) *$")
            structure_generator.debug("1) %s: %s %s %s", param, nodeName, startHeight, wallHeight)
            if nodeName == nil then
                nodeName, startHeight = string.match(param, "^([^ ]+) +(%d+) *$") -- perhaps wallHeight wasn't specified
                --structure_generator.debug("2) %s: %s %s %s", param, nodeName, startHeight, wallHeight)
            end
            if nodeName == nil then
                nodeName = string.match(param, "^([^ ]+) *$") -- perhaps startHeight and wallHeight wasn't specified
                --structure_generator.debug("3) %s: %s %s %s", param, nodeName, startHeight, wallHeight)
            end

            if nodeName == nil then
                return false, S("The node type you wish to fill the floor with must be specified.")
            elseif minetest.registered_nodes[nodeName] == nil then
                return false, S("Node type \"@1\" not known", nodeName)
            end

            local startPos = findNearbyStartPos(playerName)
            if startPos == nil then
                return false, S("Stand near the start-tag/sign of the set of the prefabs you want to fill.")
            end

            return handle_fillWalls(startPos, nodeName, startHeight or 0, wallHeight)
		end
	}
)

-- Parses a "range" string in the format of "here (number)" or
-- "(x1, y1, z1) (x2, y2, z2)", returning two position vectors
local function parse_range_str(player_name, str)
	local p1, p2
	local args = str:split(" ")

	if args[1] == "here" then
		p1, p2 = minetest.get_player_radius_area(player_name, tonumber(args[2]))
		if p1 == nil then
			return false, S("Unable to get position of player @1.", player_name)
		end
	else
		p1, p2 = minetest.string_to_area(str)
		if p1 == nil then
			return false, S("Incorrect area format. "
				.. "Expected: (x1,y1,z1) (x2,y2,z2)")
		end
	end

	return p1, p2
end

minetest.register_chatcommand(
    "cleararea",
    {
        params = S("(here [<radius>]) | (<pos1> <pos2>)"),
        description = S("Delete nodes contained in area pos1 to pos2, but leaves connection and decoration markers "
            .. "(<pos1> and <pos2> must be in parentheses)."
            .. " Differs from /deleteblocks in that a precise rect is cleared, any landscape in that rect will "
            .. "not be regenerated, and structure markers are preserved. Use /deleteblocks to clear structure markers."),
        privs = {debug = true}, -- you shouldn't run this mod on a real server, it's a tool for developing mods. Requiring debug to be safe.
        func = function(name, param)
            local p1, p2 = parse_range_str(name, param)
            if p1 == false then
                return false, p2
            end

            if handle_clearArea(p1, p2) then
                return true, S("Successfully cleared area "
                    .. "ranging from @1 to @2.",
                    minetest.pos_to_string(p1, 1), minetest.pos_to_string(p2, 1))
            else
                return false, S("Failed to clear one or more "
                    .. "blocks in area.")
            end
        end,
    }
)
