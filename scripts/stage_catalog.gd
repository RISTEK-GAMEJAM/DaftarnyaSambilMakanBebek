extends RefCounted

const Board = preload("res://scripts/labyrinth.gd")
const GAME_SCENE := "res://scenes/levels/papan_labirin_kembar.tscn"
const SELECT_SCENE := "res://scenes/ui/stage_select.tscn"
const MENU_SCENE := "res://scenes/ui/main_menu.tscn"

# # abyss, . floor, S player start, H Snatcher lair, o Safe Spot, E exit.
# Set a stage's layouts to two hand-authored grids to replace its generated maps.
const STAGES := [
	{
		"size": Vector2i(13, 9), "sight": 6, "chase": 1,
		"layouts": [
			[
				"#############",
				"#S...o.....E#",
				"#####.#####.#",
				"#H....#.....#",
				"#.#####.###.#",
				"#...#...#...#",
				"###.#.###.###",
				"#...o.......#",
				"#############",
			],
			[
				"#############",
				"#H....#...E.#",
				"#####.###.#.#",
				"#S...o....#.#",
				"#.###.#####.#",
				"#...#.......#",
				"###.#####.###",
				"#.......o...#",
				"#############",
			],
		],
	},
	{"size": Vector2i(15, 11), "sight": 5, "chase": 2, "seeds": [1741, 4973], "safe": 4},
	{"size": Vector2i(17, 13), "sight": 5, "chase": 3, "seeds": [2783, 5651], "safe": 4},
	{"size": Vector2i(19, 15), "sight": 4, "chase": 4, "seeds": [3329, 6491], "safe": 3},
	{"size": Vector2i(21, 17), "sight": 4, "chase": 5, "seeds": [4409, 7603], "safe": 3},
	{"size": Vector2i(23, 19), "sight": 3, "chase": 6, "seeds": [5081, 8627], "safe": 2},
]


static func title(index: int) -> String:
	return Lang.t("stage_tutorial") if index == 0 else Lang.t("stage_number", [index])


static func layouts_for(index: int) -> Array:
	var stage: Dictionary = STAGES[index]
	if stage.has("layouts"):
		return stage["layouts"]
	return [
		_generate(stage["size"], stage["seeds"][0], stage["safe"]),
		_generate(stage["size"], stage["seeds"][1], stage["safe"]),
	]


static func _generate(size: Vector2i, map_seed: int, safe_count: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed
	var start := Vector2i(1, 1)
	var exit := size - Vector2i(2, 2)
	var floor_cells := {start: "."}
	var stack: Array[Vector2i] = [start]
	while not stack.is_empty():
		var cell: Vector2i = stack.back()
		var neighbors: Array[Vector2i] = []
		for direction in Board.DIRECTIONS:
			var next: Vector2i = cell + direction * 2
			if Rect2i(Vector2i.ONE, size - Vector2i(2, 2)).has_point(next) and not floor_cells.has(next):
				neighbors.append(next)
		if neighbors.is_empty():
			stack.pop_back()
			continue
		var next := neighbors[rng.randi_range(0, neighbors.size() - 1)]
		floor_cells[(cell + next) / 2] = "."
		floor_cells[next] = "."
		stack.append(next)

	var bridges: Array[Vector2i] = []
	for y in range(1, size.y - 1):
		for x in range(1, size.x - 1):
			if (x + y) % 2 == 1 and not floor_cells.has(Vector2i(x, y)):
				bridges.append(Vector2i(x, y))
	# Carve loops before adding optional Safe Spot bridges. The original floor
	# network then stays connected for Snatcher, even with all Safe Spots blocked.
	for i in range(ceili(float(bridges.size()) * 0.35) + safe_count):
		var chosen := rng.randi_range(0, bridges.size() - 1)
		var marker := "o" if i < safe_count else "."
		floor_cells[bridges[chosen]] = marker
		bridges.remove_at(chosen)

	var lair := Vector2i(5, 3) if map_seed % 3 == 0 else Vector2i(3, 5)
	floor_cells[start] = "S"
	floor_cells[lair] = "H"
	floor_cells[exit] = "E"
	var rows: Array[String] = []
	for y in range(size.y):
		var row := ""
		for x in range(size.x):
			row += String(floor_cells.get(Vector2i(x, y), "#"))
		rows.append(row)
	return rows
