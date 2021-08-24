-- Auto-generated
local structGenLib = my_mod_namespace.get_structure_generator_lib()

-- connection points will only attach to connection points of the same type
local connectionType = {
    doorway1x2  = "doorway1x2",
    doorway3x3  = "doorway3x3",
    vent1x1     = "vent1x1",
    openRoom5x3 = "openRoom5x3",
    stairwell   = "stairwell",
    anyDeco     = "anyDeco"
}

local prefabTag = {
    -- "none", "all", "deadend" and "decoration" are reserved tags that the engine
    -- ascribes meaning to, the other tag name can be anything you like.
    none            = "none",
    all             = "all",
    deadend         = "deadend",    -- marks the prefab as being a way to cover-over a connection-point
    decoration      = "decoration", -- marks the prefab as being a decoration

    -- rooms
    hallway         = "hallway",
    hallwayJunction = "hallwayJunction",
    corner          = "corner",
    room            = "room", -- more than one connection-point, unlike a chamber
    chamberSmall    = "chamberSmall",
    chamberMedium   = "chamberMedium",
    chamberLarge    = "chamberLarge",
    stairwell       = "stairwell",

    -- decorations
    furniture       = "furniture",
    centerpiece     = "centerpiece",
    pillar          = "pillar",
    treasure1       = "treasure1",
    treasure2       = "treasure2"
}


local desertDungeon = structGenLib.StructurePlan.new()
structure_generator.desertDungeon = desertDungeon -- so it can be used by the wand in init.lua

desertDungeon:register_prefab({
    name             = "walled-off hallway",
    size             = vector.new(1,5,5),
    typeTags         = prefabTag.deadend,
    schematic        = "example_schematics/walled-off_hallway.mts",
    connectionPoints = {{
            x = 0, y = 0, z = 2.5,
            type         = connectionType.doorway3x3,
            facing       = 1,
            validPrefabs = prefabTag.all
        }
    }
});

desertDungeon:register_prefab({
    name             = "long hallway",
    size             = vector.new(7,5,5),
    typeTags         = prefabTag.hallway,
    schematic        = "example_schematics/long_hallway.mts",
    connectionPoints = {{
            x = 0, y = 0, z = 2.5,
            type         = connectionType.doorway3x3,
            facing       = 3,
            validPrefabs = {
                [prefabTag.hallwayJunction] = 2.5,  -- this is a weighted list, so hallwayJunction are most likely to occur at the end of a hallway
                [prefabTag.corner]          = 2,
                ["hallway stairs"]           = 2,  -- prefab names can also be used in validPrefabs lists
                [prefabTag.hallway]         = 1,
                [prefabTag.room]            = 2,
                [prefabTag.chamberSmall]    = 1,
                [prefabTag.chamberMedium]   = 1,
                [prefabTag.chamberLarge]    = 1
            }
        },{
            x = 7, y = 0, z = 2.5,
            type         = connectionType.doorway3x3,
            facing       = 1,
            validPrefabs = {
                [prefabTag.hallwayJunction] = 2.5,
                [prefabTag.corner]          = 2,
                ["hallway stairs"]           = 2,
                [prefabTag.hallway]         = 1,
                [prefabTag.room]            = 2,
                [prefabTag.chamberSmall]    = 1,
                [prefabTag.chamberMedium]   = 1,
                [prefabTag.chamberLarge]    = 1
            }
        }
    }
});

desertDungeon:register_prefab({
    name             = "half hallway",
    size             = vector.new(3,5,5),
    typeTags         = prefabTag.hallway,
    schematic        = "example_schematics/half_hallway.mts",
    connectionPoints = {{
            x = 0, y = 0, z = 2.5,
            type         = connectionType.doorway3x3,
            facing       = 3,
            validPrefabs = { [prefabTag.all] = 1,  [prefabTag.deadend] = 0 } -- allow anything except dead-ends
        },{
            x = 3, y = 0, z = 2.5,
            type         = connectionType.doorway3x3,
            facing       = 1,
            validPrefabs = { [prefabTag.all] = 1,  [prefabTag.deadend] = 0 } -- allow anything except dead-ends
        }
    }
});

desertDungeon:register_prefab({
    name             = "hallway t-junction",
    size             = vector.new(5,5,5),
    typeTags         = prefabTag.hallwayJunction,
    schematic        = "example_schematics/hallway_t-junction.mts",
    connectionPoints = {{
            x = 0, y = 0, z = 2.5,
            type         = connectionType.doorway3x3,
            facing       = 3,
            validPrefabs = { [prefabTag.all] = 1,  [prefabTag.deadend] = 0 } -- allow anything except dead-ends
        },{
            x = 2.5, y = 0, z = 0,
            type         = connectionType.doorway3x3,
            facing       = 2,
            validPrefabs = { [prefabTag.all] = 1,  [prefabTag.deadend] = 0 } -- allow anything except dead-ends
        },{
            x = 2.5, y = 0, z = 5,
            type         = connectionType.doorway3x3,
            facing       = 0,
            validPrefabs = { [prefabTag.all] = 1,  [prefabTag.deadend] = 0 } -- allow anything except dead-ends
        }
    }
});

desertDungeon:register_prefab({
    name             = "hallway intersection",
    size             = vector.new(5,5,5),
    typeTags         = prefabTag.hallwayJunction,
    schematic        = "example_schematics/hallway_intersection.mts",
    connectionPoints = {{
            x = 0, y = 0, z = 2.5,
            type         = connectionType.doorway3x3,
            facing       = 3,
            validPrefabs = { [prefabTag.all] = 1,  [prefabTag.deadend] = 0 } -- allow anything except dead-ends
        },{
            x = 2.5, y = 0, z = 0,
            type         = connectionType.doorway3x3,
            facing       = 2,
            validPrefabs = { [prefabTag.all] = 1,  [prefabTag.deadend] = 0 } -- allow anything except dead-ends
        },{
            x = 2.5, y = 0, z = 5,
            type         = connectionType.doorway3x3,
            facing       = 0,
            validPrefabs = { [prefabTag.all] = 1,  [prefabTag.deadend] = 0 } -- allow anything except dead-ends
        },{
            x = 5, y = 0, z = 2.5,
            type         = connectionType.doorway3x3,
            facing       = 1,
            validPrefabs = { [prefabTag.all] = 1,  [prefabTag.deadend] = 0 } -- allow anything except dead-ends
        }
    }
});

desertDungeon:register_prefab({
    name             = "hallway corner",
    size             = vector.new(5,5,5),
    typeTags         = prefabTag.corner,
    schematic        = "example_schematics/hallway_corner.mts",
    connectionPoints = {{
            x = 0, y = 0, z = 2.5,
            type         = connectionType.doorway3x3,
            facing       = 3,
            validPrefabs = prefabTag.hallway
        },{
            x = 2.5, y = 0, z = 5,
            type         = connectionType.doorway3x3,
            facing       = 0,
            validPrefabs = prefabTag.hallway
        }
    }
});

desertDungeon:register_prefab({
    name             = "small room1",
    size             = vector.new(10,7,10),
    typeTags         = prefabTag.room,
    schematic        = "example_schematics/small_room1.mts",
    connectionPoints = {{
            x = 0, y = 0, z = 7.5,
            type         = connectionType.doorway3x3,
            facing       = 3,
            validPrefabs = prefabTag.hallway
        },{
            x = 2.5, y = 0, z = 10,
            type         = connectionType.doorway3x3,
            facing       = 0,
            validPrefabs = prefabTag.hallway
        }
    },
    decorationPoints = {{
            x = 2.5, y = 1, z = 2.5,
            type         = connectionType.anyDeco,
            facing       = 0,
            validPrefabs = prefabTag.pillar
        },{
            x = 7.5, y = 1, z = 2.5,
            type         = connectionType.anyDeco,
            facing       = 0,
            validPrefabs = prefabTag.pillar
        }
    }
});

desertDungeon:register_prefab({
    name             = "small room2",
    size             = vector.new(10,7,10),
    typeTags         = prefabTag.room,
    schematic        = "example_schematics/small_room2.mts",
    connectionPoints = {{
            x = 0, y = 0, z = 2.5,
            type         = connectionType.doorway3x3,
            facing       = 3,
            validPrefabs = prefabTag.hallway
        },{
            x = 0, y = 0, z = 7.5,
            type         = connectionType.doorway3x3,
            facing       = 3,
            validPrefabs = prefabTag.hallway
        }
    },
    decorationPoints = {{
            x = 5.5, y = 1, z = 3.5,
            type         = connectionType.anyDeco,
            facing       = 0,
            validPrefabs = prefabTag.pillar
        },{
            x = 5.5, y = 1, z = 6.5,
            type         = connectionType.anyDeco,
            facing       = 2,
            validPrefabs = prefabTag.pillar
        }
    }
});

desertDungeon:register_prefab({
    name             = "medium room1",
    size             = vector.new(15,7,10),
    typeTags         = prefabTag.room,
    schematic        = "example_schematics/medium_room1.mts",
    connectionPoints = {{
            x = 0, y = 0, z = 5.5,
            type         = connectionType.doorway3x3,
            facing       = 3,
            validPrefabs = prefabTag.hallway
        },{
            x = 12.5, y = 0, z = 0,
            type         = connectionType.doorway3x3,
            facing       = 2,
            validPrefabs = prefabTag.hallway
        },{
            x = 12.5, y = 0, z = 10,
            type         = connectionType.doorway3x3,
            facing       = 0,
            validPrefabs = prefabTag.hallway
        }
    },
    decorationPoints = {{
            x = 3.5, y = 1, z = 1.5,
            type         = connectionType.anyDeco,
            facing       = 0,
            validPrefabs = prefabTag.treasure1
        },{
            x = 6.5, y = 1, z = 1.5,
            type         = connectionType.anyDeco,
            facing       = 0,
            validPrefabs = prefabTag.treasure1
        },{
            x = 10.5, y = 1, z = 3.5,
            type         = connectionType.anyDeco,
            facing       = 0,
            validPrefabs = prefabTag.pillar
        },{
            x = 10.5, y = 1, z = 6.5,
            type         = connectionType.anyDeco,
            facing       = 0,
            validPrefabs = prefabTag.pillar
        }
    }
});

desertDungeon:register_prefab({
    name             = "small chamber1",
    size             = vector.new(5,7,5),
    typeTags         = prefabTag.chamberSmall,
    schematic        = "example_schematics/small_chamber1.mts",
    connectionPoints = {{
            x = 0, y = 0, z = 2.5,
            type         = connectionType.doorway3x3,
            facing       = 3,
            validPrefabs = prefabTag.all,
        }
    },
    decorationPoints = {{
            x = 3.5, y = 1, z = 2.5,
            type         = connectionType.anyDeco,
            facing       = 3,
            validPrefabs = prefabTag.treasure1
        }
    }
});

desertDungeon:register_prefab({
    name             = "medium chamber1",
    size             = vector.new(10,7,10),
    typeTags         = prefabTag.chamberMedium,
    schematic        = "example_schematics/medium_chamber1.mts",
    connectionPoints = {{
            x = 0, y = 0, z = 3.5,
            type         = connectionType.doorway3x3,
            facing       = 3,
            validPrefabs = prefabTag.all
        }
    },
    decorationPoints = {{
            x = 4.5, y = 1, z = 5.5,
            type         = connectionType.anyDeco,
            facing       = 2,
            validPrefabs = prefabTag.pillar
        },{
            x = 8.5, y = 1, z = 3.5,
            type         = connectionType.anyDeco,
            facing       = 3,
            validPrefabs = prefabTag.treasure1
        },{
            x = 8.5, y = 1, z = 6.5,
            type         = connectionType.anyDeco,
            facing       = 3,
            validPrefabs = prefabTag.treasure1
        }
    }
});

desertDungeon:register_prefab({
    name             = "hallway stairs",
    size             = vector.new(9,14,5),
    typeTags         = prefabTag.hallway,
    schematic        = "example_schematics/hallway_stairs.mts",
    connectionPoints = {{
            x = 0, y = 0, z = 2.5,
            type         = connectionType.doorway3x3,
            facing       = 3,
            validPrefabs = {
                ["hallway stairs"]           = 0.7,
                [prefabTag.hallway]         = 1.5,
                [prefabTag.hallwayJunction] = 1,
                [prefabTag.corner]          = 1,
                [prefabTag.room]            = 2,
                [prefabTag.chamberSmall]    = 1,
                [prefabTag.chamberMedium]   = 1,
                [prefabTag.chamberLarge]    = 1
            }
        },{
            x = 9, y = 9, z = 2.5,
            type         = connectionType.doorway3x3,
            facing       = 1,
            validPrefabs = {
                ["hallway stairs"]           = 0.7,
                [prefabTag.hallway]         = 1.5,
                [prefabTag.hallwayJunction] = 1,
                [prefabTag.corner]          = 1,
                [prefabTag.room]            = 2,
                [prefabTag.chamberSmall]    = 1,
                [prefabTag.chamberMedium]   = 1,
                [prefabTag.chamberLarge]    = 1
            }
        }
    }
});

desertDungeon:register_prefab({
    name             = "pillar1x1",
    size             = vector.new(1,5,1),
    typeTags         = { prefabTag.decoration, prefabTag.pillar },
    schematic        = "example_schematics/pillar1x1.mts",
    connectionPoints = {}
});

desertDungeon:register_prefab({
    name             = "treasure chest",
    size             = vector.new(1,2,1),
    typeTags         = { prefabTag.decoration, prefabTag.treasure1 },
    schematic        = "example_schematics/treasure_chest.mts",
    connectionPoints = {}
});

desertDungeon:register_prefab({
    name             = "covered way",
    size             = vector.new(9,10,5),
    typeTags         = prefabTag.hallway,
    schematic        = "example_schematics/covered_way.mts",
    connectionPoints = {{
            x = 0, y = 5, z = 2.5,
            type         = connectionType.doorway3x3,
            facing       = 3,
            validPrefabs = {
                ["half hallway"]     = 10,  -- this is a weighted list, so half-hallway's are most likely to connect to covered ways
                ["covered way"]      = 3,
                ["hallway stairs"]   = 2,
                [prefabTag.room]    = 2,   -- prefab types can also be used in validPrefabs lists
                [prefabTag.chamberMedium] = 1,
                [prefabTag.hallway] = 1
            }
        },{
            x = 9, y = 5, z = 2.5,
            type         = connectionType.doorway3x3,
            facing       = 1,
            validPrefabs = {
                ["half hallway"]     = 10,  -- this is a weighted list, so half-hallway's are most likely to connect to covered ways
                ["covered way"]      = 3,
                ["hallway stairs"]   = 2,
                [prefabTag.room]    = 2,   -- prefab types can also be used in validPrefabs lists
                [prefabTag.chamberMedium] = 1,
                [prefabTag.hallway] = 1
            }
        }
    }
});
