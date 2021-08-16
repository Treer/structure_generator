local structGenLib = my_mod_namespace.get_structure_generator_lib()


local prefabType = {
	-- "none" and "all" are special strings that the engine understands
	-- the other enums can be anything you like.
	none            = "none",
	all             = "all",

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


local connectionType = {
	doorway1x2  = "doorway1x2",
	doorway2x3  = "doorway2x3",
	vent1x1     = "vent1x1",
	openRoom5x3 = "openRoom5x3",
	stairwell   = "stairwell"
}

structGenLib.register_prefab({
	name = "walled-off hallway",
	size = vector.new(1, 5, 5),
	type = prefabType.deadend
});

structGenLib.register_prefab({
	name = "long hallway", -- calling it "long hallway" since there's already a prefabType using "hallway", and keeping the two distinct is handy later as we can refer to either one in validPrefabs tables.
	size = vector.new(7, 5, 5),
	type = prefabType.hallway
});

structGenLib.register_prefab({
	name = "half hallway",
	size = vector.new(3, 5, 5),
	type = prefabType.hallway
});

structGenLib.register_prefab({
	name = "hallway t-junction",
	size = vector.new(5, 5, 5),
	type = prefabType.hallwayJunction
});

structGenLib.register_prefab({
	name = "hallway intersection",
	size = vector.new(5, 5, 5),
	type = prefabType.hallwayJunction
});

structGenLib.register_prefab({
	name = "hallway corner",
	size = vector.new(5, 5, 5),
	type = prefabType.corner
});

structGenLib.register_prefab({
	name = "small room1",
	size = vector.new(10, 7, 10),
	type = prefabType.room
});

structGenLib.register_prefab({
	name = "small room2",
	size = vector.new(10, 7, 10),
	type = prefabType.room
});

structGenLib.register_prefab({
	name = "medium room1",
	size = vector.new(15, 7, 10),
	type = prefabType.room
});

structGenLib.register_prefab({
	name = "small chamber1",
	size = vector.new(5, 7, 5),
	type = prefabType.chamberSmall
});

structGenLib.register_prefab({
	name = "medium chamber1",
	size = vector.new(10, 7, 10),
	type = prefabType.chamberMedium
});

structGenLib.register_prefab({
	name = "hallway stairs",
	size = vector.new(9, 14, 5),
	type = prefabType.hallway
});

structGenLib.register_prefab({
	name = "pillar1x1",
	size = vector.new(1, 5, 1),
	type = prefabType.pillar
});

structGenLib.register_prefab({
	name = "treasure chest",
	size = vector.new(1, 2, 1),
	type = prefabType.treasure1
});

structGenLib.register_prefab({
	name = "covered way",
	size = vector.new(9, 10, 5),
	type = prefabType.hallway
});
