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

local prefabType = {
    none = "none", -- built-in enum
    all  = "all",  -- built-in enum

    -- rooms
    deadend         = "deadend",
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


structGenLib.register_prefabType_as_deadend(prefabType.deadend)
structGenLib.register_prefabType_as_decoration(prefabType.furniture)
structGenLib.register_prefabType_as_decoration(prefabType.centerpiece)
structGenLib.register_prefabType_as_decoration(prefabType.pillar)
structGenLib.register_prefabType_as_decoration(prefabType.treasure1)
structGenLib.register_prefabType_as_decoration(prefabType.treasure2)


structGenLib.register_prefab({
    name             = "walled-off hallway",
    size             = vector.new(1,5,5),
    type             = prefabType.deadend,
    schematic        = "example_schematics/walled-off_hallway.mts",
    connectionPoints = {{
            x = 0, y = 0, z = 2.5,
            type         = connectionType.doorway3x3,
            facing       = 1,
            validPrefabs = prefabType.all
        }
    }
});

structGenLib.register_prefab({
    name             = "hallway",
    size             = vector.new(7,5,5),
    type             = prefabType.hallway,
    schematic        = "example_schematics/hallway.mts",
    connectionPoints = {{
            x = 0, y = 0, z = 2.5,
            type         = connectionType.doorway3x3,
            facing       = 3,
            validPrefabs = prefabType.all -- this allow lists with probabilities, but "all" is easier for now
        },{
            x = 7, y = 0, z = 2.5,
            type         = connectionType.doorway3x3,
            facing       = 1,
            validPrefabs = prefabType.all
        }
    }
});

structGenLib.register_prefab({
    name             = "half hallway",
    size             = vector.new(3,5,5),
    type             = prefabType.hallway,
    schematic        = "example_schematics/half_hallway.mts",
    connectionPoints = {{
            x = 0, y = 0, z = 2.5,
            type         = connectionType.doorway3x3,
            facing       = 3,
            validPrefabs = prefabType.all
        },{
            x = 3, y = 0, z = 2.5,
            type         = connectionType.doorway3x3,
            facing       = 1,
            validPrefabs = prefabType.all
        }
    }
});

structGenLib.register_prefab({
    name             = "hallway t-junction",
    size             = vector.new(5,5,5),
    type             = prefabType.hallwayJunction,
    schematic        = "example_schematics/hallway_t-junction.mts",
    connectionPoints = {{
            x = 0, y = 0, z = 2.5,
            type         = connectionType.doorway3x3,
            facing       = 3,
            validPrefabs = prefabType.all
        },{
            x = 2.5, y = 0, z = 0,
            type         = connectionType.doorway3x3,
            facing       = 2,
            validPrefabs = prefabType.all
        },{
            x = 2.5, y = 0, z = 5,
            type         = connectionType.doorway3x3,
            facing       = 0,
            validPrefabs = prefabType.all
        }
    }
});

structGenLib.register_prefab({
    name             = "hallway intersection",
    size             = vector.new(5,5,5),
    type             = prefabType.hallwayJunction,
    schematic        = "example_schematics/hallway_intersection.mts",
    connectionPoints = {{
            x = 0, y = 0, z = 2.5,
            type         = connectionType.doorway3x3,
            facing       = 3,
            validPrefabs = prefabType.all
        },{
            x = 2.5, y = 0, z = 0,
            type         = connectionType.doorway3x3,
            facing       = 2,
            validPrefabs = prefabType.all
        },{
            x = 2.5, y = 0, z = 5,
            type         = connectionType.doorway3x3,
            facing       = 0,
            validPrefabs = prefabType.all
        },{
            x = 5, y = 0, z = 2.5,
            type         = connectionType.doorway3x3,
            facing       = 1,
            validPrefabs = prefabType.all
        }
    }
});

structGenLib.register_prefab({
    name             = "hallway corner",
    size             = vector.new(5,5,5),
    type             = prefabType.corner,
    schematic        = "example_schematics/hallway_corner.mts",
    connectionPoints = {{
            x = 0, y = 0, z = 2.5,
            type         = connectionType.doorway3x3,
            facing       = 3,
            validPrefabs = prefabType.hallway
        },{
            x = 2.5, y = 0, z = 5,
            type         = connectionType.doorway3x3,
            facing       = 0,
            validPrefabs = prefabType.hallway
        }
    }
});

structGenLib.register_prefab({
    name             = "small room1",
    size             = vector.new(10,7,10),
    type             = prefabType.room,
    schematic        = "example_schematics/small_room1.mts",
    connectionPoints = {{
            x = 0, y = 0, z = 7.5,
            type         = connectionType.doorway3x3,
            facing       = 3,
            validPrefabs = prefabType.hallway
        },{
            x = 2.5, y = 0, z = 10,
            type         = connectionType.doorway3x3,
            facing       = 0,
            validPrefabs = prefabType.hallway
        }
    },
    decorationPoints = {{
            x = 2.5, y = 1, z = 2.5,
            type         = connectionType.anyDeco,
            facing       = 0,
            validPrefabs = prefabType.pillar
        },{
            x = 7.5, y = 1, z = 2.5,
            type         = connectionType.anyDeco,
            facing       = 0,
            validPrefabs = prefabType.pillar
        }
    }
});

structGenLib.register_prefab({
    name             = "small room2",
    size             = vector.new(10,7,10),
    type             = prefabType.room,
    schematic        = "example_schematics/small_room2.mts",
    connectionPoints = {{
            x = 0, y = 0, z = 2.5,
            type         = connectionType.doorway3x3,
            facing       = 3,
            validPrefabs = prefabType.hallway
        },{
            x = 0, y = 0, z = 7.5,
            type         = connectionType.doorway3x3,
            facing       = 3,
            validPrefabs = prefabType.hallway
        }
    },
    decorationPoints = {{
            x = 5.5, y = 1, z = 3.5,
            type         = connectionType.anyDeco,
            facing       = 0,
            validPrefabs = prefabType.pillar
        },{
            x = 5.5, y = 1, z = 6.5,
            type         = connectionType.anyDeco,
            facing       = 2,
            validPrefabs = prefabType.pillar
        }
    }
});

structGenLib.register_prefab({
    name             = "medium room1",
    size             = vector.new(15,7,10),
    type             = prefabType.room,
    schematic        = "example_schematics/medium_room1.mts",
    connectionPoints = {{
            x = 0, y = 0, z = 5.5,
            type         = connectionType.doorway3x3,
            facing       = 3,
            validPrefabs = prefabType.hallway
        },{
            x = 12.5, y = 0, z = 0,
            type         = connectionType.doorway3x3,
            facing       = 2,
            validPrefabs = prefabType.hallway
        },{
            x = 12.5, y = 0, z = 10,
            type         = connectionType.doorway3x3,
            facing       = 0,
            validPrefabs = prefabType.hallway
        }
    },
    decorationPoints = {{
            x = 3.5, y = 1, z = 1.5,
            type         = connectionType.anyDeco,
            facing       = 0,
            validPrefabs = prefabType.treasure1
        },{
            x = 6.5, y = 1, z = 1.5,
            type         = connectionType.anyDeco,
            facing       = 0,
            validPrefabs = prefabType.treasure1
        },{
            x = 10.5, y = 1, z = 3.5,
            type         = connectionType.anyDeco,
            facing       = 0,
            validPrefabs = prefabType.pillar
        },{
            x = 10.5, y = 1, z = 6.5,
            type         = connectionType.anyDeco,
            facing       = 0,
            validPrefabs = prefabType.pillar
        }
    }
});

structGenLib.register_prefab({
    name             = "small chamber1",
    size             = vector.new(5,7,5),
    type             = prefabType.chamberSmall,
    schematic        = "example_schematics/small_chamber1.mts",
    connectionPoints = {{
            x = 0, y = 0, z = 2.5,
            type         = connectionType.doorway3x3,
            facing       = 3,
            validPrefabs = prefabType.all,
        }
    },
    decorationPoints = {{
            x = 3.5, y = 1, z = 2.5,
            type         = connectionType.anyDeco,
            facing       = 3,
            validPrefabs = prefabType.treasure1
        }
    }
});

structGenLib.register_prefab({
    name             = "medium chamber1",
    size             = vector.new(10,7,10),
    type             = prefabType.chamberMedium,
    schematic        = "example_schematics/medium_chamber1.mts",
    connectionPoints = {{
            x = 0, y = 0, z = 3.5,
            type         = connectionType.doorway3x3,
            facing       = 3,
            validPrefabs = prefabType.all
        }
    },
    decorationPoints = {{
            x = 4.5, y = 1, z = 5.5,
            type         = connectionType.anyDeco,
            facing       = 2,
            validPrefabs = prefabType.pillar
        },{
            x = 8.5, y = 1, z = 3.5,
            type         = connectionType.anyDeco,
            facing       = 3,
            validPrefabs = prefabType.treasure1
        },{
            x = 8.5, y = 1, z = 6.5,
            type         = connectionType.anyDeco,
            facing       = 3,
            validPrefabs = prefabType.treasure1
        }
    }
});

structGenLib.register_prefab({
    name             = "hallway stairs",
    size             = vector.new(9,14,5),
    type             = prefabType.hallway,
    schematic        = "example_schematics/hallway_stairs.mts",
    connectionPoints = {{
            x = 0, y = 0, z = 2.5,
            type         = connectionType.doorway3x3,
            facing       = 3,
            validPrefabs = prefabType.all
        },{
            x = 9, y = 9, z = 2.5,
            type         = connectionType.doorway3x3,
            facing       = 1,
            validPrefabs = prefabType.all
        }
    }
});

structGenLib.register_prefab({
    name             = "pillar1x1",
    size             = vector.new(1,5,1),
    type             = prefabType.pillar,
    schematic        = "example_schematics/pillar1x1.mts",
    connectionPoints = {}
});

structGenLib.register_prefab({
    name             = "treasure chest",
    size             = vector.new(1,2,1),
    type             = prefabType.treasure1,
    schematic        = "example_schematics/treasure_chest.mts",
    connectionPoints = {}
});
