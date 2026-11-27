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

	var h_bridges: Array[Vector2i] = []
	var all_bridges: Array[Vector2i] = []
	for y in range(1, size.y - 1):
		for x in range(1, size.x - 1):
			var c := Vector2i(x, y)
			if (x + y) % 2 == 1 and not floor_cells.has(c):
				all_bridges.append(c)
				if x % 2 == 0 and y % 2 == 1:
					h_bridges.append(c)

	# Carve loops first so the floor network stays connected even with all Safe Spots blocked.
	var loop_count := ceili(float(all_bridges.size()) * 0.35)
	for _i in range(mini(loop_count, all_bridges.size())):
		var idx := rng.randi_range(0, all_bridges.size() - 1)
		var chosen := all_bridges[idx]
		floor_cells[chosen] = "."
		all_bridges.remove_at(idx)
		h_bridges.erase(chosen)

	# Place Safe Spot bridges strictly on HORIZONTAL corridors (x even, y odd) so safe_bridge.png never rotates 90 deg!
	var placed_safes: Array[Vector2i] = []
	var safe_pool := h_bridges.duplicate()
	while placed_safes.size() < safe_count and not safe_pool.is_empty():
		var idx := rng.randi_range(0, safe_pool.size() - 1)
		var cand: Vector2i = safe_pool[idx]
		safe_pool.remove_at(idx)
		var too_close := false
		for prev in placed_safes:
			if absi(prev.x - cand.x) + absi(prev.y - cand.y) < 3:
				too_close = true
				break
		if not too_close:
			floor_cells[cand] = "o"
			placed_safes.append(cand)
	# Fallback if spacing was too strict
	while placed_safes.size() < safe_count and not h_bridges.is_empty():
		var cand: Vector2i = h_bridges.pop_back()
		if not floor_cells.has(cand):
			floor_cells[cand] = "o"
			placed_safes.append(cand)

	floor_cells[start] = "S"
	floor_cells[exit] = "E"

	# Build preliminary ASCII layout to pick a fair Snatcher Lair (H) that NEVER traps S from reaching E!
	var base_rows := _cells_to_rows(floor_cells, size)
	var base_layouts := [base_rows, base_rows]
	var base_se := Board.shortest_path(0, start, exit, base_layouts).size()

	var lair := Vector2i(3, 5)
	var preferred_lairs: Array[Vector2i] = [
		Vector2i(5, 3) if map_seed % 3 == 0 else Vector2i(3, 5),
		Vector2i(3, 5),
		Vector2i(5, 3),
		Vector2i(1, 5),
		Vector2i(5, 1),
		Vector2i(3, 7),
		Vector2i(7, 3),
		Vector2i(5, 5),
	]
	for cand_h in preferred_lairs:
		if not Rect2i(Vector2i.ONE, size - Vector2i(2, 2)).has_point(cand_h):
			continue
		if not floor_cells.has(cand_h) or cand_h == start or cand_h == exit or String(floor_cells[cand_h]) == "o":
			continue
		var test_cells := floor_cells.duplicate()
		test_cells[cand_h] = "H"
		var test_rows := _cells_to_rows(test_cells, size)
		var test_layouts := [test_rows, test_rows]
		var se_avoid_h := Board.shortest_path(0, start, exit, test_layouts, "H")
		var hs_no_safe := Board.shortest_path(0, cand_h, start, test_layouts, "o")
		if not se_avoid_h.is_empty() and se_avoid_h.size() <= base_se + 2 and not hs_no_safe.is_empty():
			lair = cand_h
			break

	floor_cells[lair] = "H"
	return _cells_to_rows(floor_cells, size)


static func _cells_to_rows(floor_cells: Dictionary, size: Vector2i) -> Array[String]:
	var rows: Array[String] = []
	for y in range(size.y):
		var row := ""
		for x in range(size.x):
			row += String(floor_cells.get(Vector2i(x, y), "#"))
		rows.append(row)
	return rows
