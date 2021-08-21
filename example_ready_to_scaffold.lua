local structGenLib = my_mod_namespace.get_structure_generator_lib()


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


structGenLib.register_prefab({
	name     = "walled-off hallway",
	size     = vector.new(1, 5, 5),
	typeTags = prefabTag.deadend
});

structGenLib.register_prefab({
	name     = "long hallway", -- calling it "long hallway" since there's already a prefabTag using "hallway", and keeping the two distinct is handy later as we can refer to either one in validPrefabs tables.
	size     = vector.new(7, 5, 5),
	typeTags = prefabTag.hallway
});

structGenLib.register_prefab({
	name     = "half hallway",
	size     = vector.new(3, 5, 5),
	typeTags = prefabTag.hallway
});

structGenLib.register_prefab({
	name     = "hallway t-junction",
	size     = vector.new(5, 5, 5),
	typeTags = prefabTag.hallwayJunction
});

structGenLib.register_prefab({
	name     = "hallway intersection",
	size     = vector.new(5, 5, 5),
	typeTags = prefabTag.hallwayJunction
});

structGenLib.register_prefab({
	name     = "hallway corner",
	size     = vector.new(5, 5, 5),
	typeTags = prefabTag.corner
});

structGenLib.register_prefab({
	name     = "small room1",
	size     = vector.new(10, 7, 10),
	typeTags = prefabTag.room
});

structGenLib.register_prefab({
	name     = "small room2",
	size     = vector.new(10, 7, 10),
	typeTags = prefabTag.room
});

structGenLib.register_prefab({
	name     = "medium room1",
	size     = vector.new(15, 7, 10),
	typeTags = prefabTag.room
});

structGenLib.register_prefab({
	name     = "small chamber1",
	size     = vector.new(5, 7, 5),
	typeTags = prefabTag.chamberSmall
});

structGenLib.register_prefab({
	name     = "medium chamber1",
	size     = vector.new(10, 7, 10),
	typeTags = prefabTag.chamberMedium
});

structGenLib.register_prefab({
	name     = "hallway stairs",
	size     = vector.new(9, 14, 5),
	typeTags = prefabTag.hallway
});

structGenLib.register_prefab({
	name     = "pillar1x1",
	size     = vector.new(1, 5, 1),
	typeTags = { prefabTag.decoration, prefabTag.pillar }
});

structGenLib.register_prefab({
	name     = "treasure chest",
	size     = vector.new(1, 2, 1),
	typeTags = { prefabTag.decoration, prefabTag.treasure1 }
});

structGenLib.register_prefab({
	name     = "covered way",
	size     = vector.new(9, 10, 5),
	typeTags = prefabTag.hallway
});
