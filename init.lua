-- Set DEBUG_FLAGS to determine the behavior of nether.debug():
--   0 = off
--   1 = print(...)
--   2 = minetest.chat_send_all(...)
--   4 = minetest.log("info", ...)
local DEBUG_FLAGS = 6



-- Global structure_generator namespace
structure_generator         = {}
structure_generator.modName = minetest.get_current_modname()
structure_generator.modPath = minetest.get_modpath(structure_generator.modName)

-- Set up translator
if minetest.get_translator == nil then
	error("The " .. structure_generator.modName .. " mod requires Minetest 5", 0)
end
local S = minetest.get_translator(structure_generator.modName)
structure_generator.get_translator = S


-- ===================
--   Debug functions
-- ===================
-- (Used by both structure_scaffolding_commands.lua and structure_generator_lib.lua)

-- returns true if the variable is a vector/position
function structure_generator.isVector(variable)
    if type(variable) ~= "table" then
        return false
    end
    local tableCount = 0
    for _,_ in pairs(variable) do tableCount = tableCount + 1 end
    return tableCount == 3 and variable.x ~= nil and variable.y ~= nil and variable.z ~= nil
end

-- returns a string representation of a lua variable, handling nils, tables, and vectors.
function structure_generator.toString(arg)
    if arg == nil then
        -- convert nils to strings
        return '<nil>'
    elseif type(arg) == "table" then
        if structure_generator.isVector(arg) then
            -- convert vectors to strings
            return minetest.pos_to_string(arg)
        else
            local prefix = arg._className or ""
            -- convert tables to strings
            -- (calling function can use dump() if a multi-line listing is desired)
            return prefix .. string.gsub(dump(arg, ""), "\n", " ")
        end
    else
        return tostring(arg)
    end
end

-- A debug-print function that understands vectors etc. and does not
-- evaluate when debugging is turned off.
-- It works like string.format(), treating the message as a format string.
-- nils, tables, and vectors passed as arguments to structure_generator.debug() are
-- converted to strings and can be included inside the message with %s
function structure_generator.debug(message, ...)

	local args = {...}
	local argCount = select("#", ...)

	for i = 1, argCount do
        args[i] = structure_generator.toString(args[i])
	end

	local composed_message = structure_generator.modName .. ": " .. string.format(message, unpack(args))
	if math.floor(DEBUG_FLAGS / 1) % 2 == 1 then print(composed_message) end
	if math.floor(DEBUG_FLAGS / 2) % 2 == 1 then minetest.chat_send_all(composed_message) end
	if math.floor(DEBUG_FLAGS / 4) % 2 == 1 then minetest.log("info", composed_message) end
end
if DEBUG_FLAGS == 0 then
	-- do as little evaluation as possible
	structure_generator.debug = function() end
end




-- Load files
dofile(structure_generator.modPath .. DIR_DELIM .. "structure_generator_lib.lua")
dofile(structure_generator.modPath .. DIR_DELIM .. "structure_scaffolding_commands.lua")

-- Load the demo file so the scaffolding_commands have something to work with
dofile(structure_generator.modPath .. DIR_DELIM .. "example_ready_to_scaffold.lua")



-- ====================================
--  Demo tool - magic constructor wand
-- ====================================
minetest.register_tool(structure_generator.modName .. ":magic_wand", {
	description = "Magic wand that builds a random structure",
	inventory_image = "structure_generator_wand.png",
	wield_image = "structure_generator_wand.png^[transformR90",

    on_use = function(itemstack, user, pointed_thing)
        -- unload example_ready_to_scaffold, and load the example that's ready to build structures
        structure_generator.lib.clear()
        dofile(structure_generator.modPath .. DIR_DELIM .. "example_ready_to_build.lua")

        -- invoke the build
        local pos = minetest.get_pointed_thing_position(pointed_thing)
        if pos == nil then
            structure_generator.debug("spell failed, no position found")
        else
            structure_generator.lib.build_structure("medium room1", {x = pos.x - 3, y = pos.y, z = pos.z - 3})
        end

        -- unload the working example and reload the scaffold example
        structure_generator.lib.clear()
        dofile(structure_generator.modPath .. DIR_DELIM .. "example_ready_to_scaffold.lua")

        return nil -- prevent wand being removed from inventory
    end
})