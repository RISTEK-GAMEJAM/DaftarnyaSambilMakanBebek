extends RefCounted

const Board = preload("res://scripts/labyrinth.gd")
const GAME_SCENE := "res://scenes/levels/papan_labirin_kembar.tscn"
const SELECT_SCENE := "res://scenes/ui/stage_select.tscn"
const MENU_SCENE := "res://scenes/ui/main_menu.tscn"

# # abyss, . floor, S player start, H Snatcher lair, o Safe Spot, E exit.
# 1 and 2 are gates. Plates a and b open the corresponding gate across the maze.
# Set a stage's layouts to two hand-authored grids to replace its generated maps.
const STAGES := [
	{
		"size": Vector2i(14, 9), "sight": 6, "chase": 1, "duel_time": 60.0,
		"exit_options": [Vector2i(11, 1), Vector2i(12, 1), Vector2i(11, 2), Vector2i(12, 2)],
		"layouts": [
			[
				"##############",
				"#S..o...a.1..#",
				"#####.#.#.#..#",
				"#H....#....###",
				"#.#####.###.##",
				"#...#...#...##",
				"###.#.###.####",
				"#...o.......##",
				"##############",
			],
			[
				"##############",
				"#H....#.a.1..#",
				"#####.#.#.#..#",
				"#S..o......###",
				"#.###.#####.##",
				"#...#.......##",
				"###.#####.####",
				"#.......o...##",
				"##############",
			],
		],
	},
	{"size": Vector2i(16, 16), "sight": 5, "chase": 2, "duel_time": 60.0, "seeds": [1741, 4973], "safe": 4},
	{"size": Vector2i(18, 18), "sight": 5, "chase": 3, "duel_time": 50.0, "seeds": [2783, 5651], "safe": 4},
	{"size": Vector2i(20, 20), "sight": 4, "chase": 4, "duel_time": 40.0, "seeds": [3329, 6491], "safe": 3},
	{"size": Vector2i(22, 22), "sight": 4, "chase": 5, "duel_time": 30.0, "seeds": [4409, 7603], "safe": 3},
	{"size": Vector2i(24, 24), "sight": 3, "chase": 6, "duel_time": 25.0, "seeds": [5081, 8627], "safe": 2},
]


static func title(index: int) -> String:
	return Lang.t("stage_tutorial") if index == 0 else Lang.t("stage_number", [index])


static func layouts_for(index: int, run_seed: int = 0) -> Array:
	var stage: Dictionary = STAGES[index]
	var landmarks := RandomNumberGenerator.new()
	landmarks.seed = run_seed ^ 0x34a2d79b
	if stage.has("layouts"):
		if not stage.has("exit_options"):
			return stage["layouts"]
		var options: Array = stage["exit_options"]
		var layouts: Array = stage["layouts"].duplicate(true)
		for rows: Array in layouts:
			var cell: Vector2i = options[landmarks.randi_range(0, options.size() - 1)]
			var row: String = rows[cell.y]
			rows[cell.y] = row.left(cell.x) + "E" + row.substr(cell.x + 1)
		return layouts
	var placement := RandomNumberGenerator.new()
	placement.seed = run_seed
	return [
		_generate(stage, stage["seeds"][0], placement, landmarks),
		_generate(stage, stage["seeds"][1], placement, landmarks),
	]


static func _generate(stage: Dictionary, map_seed: int, placement: RandomNumberGenerator, landmarks: RandomNumberGenerator) -> Array[String]:
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed
	var size: Vector2i = stage["size"]
	var safe_count: int = stage["safe"]
	var start := Vector2i(1, 1)
	var pockets := _reserve_pockets(size, placement)
	var core := Rect2i(Vector2i.ONE, size - Vector2i(2, 2))
	var floor_cells := {start: "."}
	var stack: Array[Vector2i] = [start]
	while not stack.is_empty():
		var cell: Vector2i = stack.back()
		var neighbors: Array[Vector2i] = []
		for direction in Board.DIRECTIONS:
			var next: Vector2i = cell + direction * 2
			if core.has_point(next) and not floor_cells.has(next) and not pockets.has(next):
				neighbors.append(next)
		if neighbors.is_empty():
			stack.pop_back()
			continue
		var next := neighbors[rng.randi_range(0, neighbors.size() - 1)]
		floor_cells[(cell + next) / 2] = "."
		floor_cells[next] = "."
		stack.append(next)

	_attach_pocket_loops(floor_cells, pockets)
	var h_bridges: Array[Vector2i] = []
	var all_bridges: Array[Vector2i] = []
	for y in range(1, size.y - 1):
		for x in range(1, size.x - 1):
			var c := Vector2i(x, y)
			if (x + y) % 2 == 1 and not floor_cells.has(c):
				var axis := Vector2i.RIGHT if x % 2 == 0 else Vector2i.DOWN
				if not floor_cells.has(c - axis) or not floor_cells.has(c + axis):
					continue
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
	for end: Vector2i in pockets:
		var gate: Vector2i = end - pockets[end]
		floor_cells[end] = "."
		floor_cells[gate] = "."

	# Pick the landmarks after the floor is final. All pockets look like
	# ordinary blind alleys on the preview, whichever pair is chosen.
	var base_layouts := [_cells_to_rows(floor_cells, size)]
	var initial_sight := Board.visible_cells(0, start, stage["sight"], base_layouts)
	var exit_candidates := pockets.keys().filter(func(cell: Vector2i) -> bool: return cell not in initial_sight)
	var exit: Vector2i = exit_candidates[landmarks.randi_range(0, exit_candidates.size() - 1)]
	var plate_candidates := pockets.keys()
	plate_candidates.erase(exit)
	var second_plate: Vector2i = plate_candidates[landmarks.randi_range(0, plate_candidates.size() - 1)]
	var plate_gate: Vector2i = second_plate - pockets[second_plate]
	var exit_gate: Vector2i = exit - pockets[exit]
	var approach_path := Board.shortest_path(0, start, plate_gate, base_layouts)
	var exit_path := Board.shortest_path(0, start, exit_gate, base_layouts)

	var lair := Vector2i(-1, -1)
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
		if floor_cells.get(cand_h) != "." or pockets.has(cand_h):
			continue
		var path_around_lair := Board.shortest_path(0, start, plate_gate, base_layouts, "", {cand_h: true})
		var path_to_exit_gate := Board.shortest_path(0, start, exit_gate, base_layouts, "", {cand_h: true})
		if not path_around_lair.is_empty() and path_around_lair.size() <= approach_path.size() + 2 and not path_to_exit_gate.is_empty():
			lair = cand_h
			break

	if lair.x < 0:
		# Floor outside both paths leaves both routes open.
		for cell: Vector2i in floor_cells:
			if floor_cells[cell] == "." and not pockets.has(cell) and cell not in approach_path and cell not in exit_path:
				lair = cell
				break
	floor_cells[lair] = "H"
	for index in range(approach_path.size() / 2, approach_path.size() - 1):
		var cell := approach_path[index]
		if floor_cells[cell] == ".":
			floor_cells[cell] = "a"
			break
	floor_cells[plate_gate] = "1"
	floor_cells[second_plate] = "b"
	floor_cells[exit_gate] = "2"
	floor_cells[exit] = "E"
	return _cells_to_rows(floor_cells, size)


static func _reserve_pockets(size: Vector2i, rng: RandomNumberGenerator) -> Dictionary:
	# In each full 3x3 block of lattice nodes, reserve one edge midpoint.
	# Leaving the corners in the main maze keeps neighboring blocks connected.
	var pockets := {}
	for y in range(3, size.y - 3, 6):
		for x in range(3, size.x - 3, 6):
			var direction: Vector2i = Board.DIRECTIONS[rng.randi_range(0, Board.DIRECTIONS.size() - 1)]
			pockets[Vector2i(x, y) + direction * 2] = direction
	return pockets


static func _attach_pocket_loops(floor_cells: Dictionary, pockets: Dictionary) -> void:
	for end: Vector2i in pockets:
		var direction: Vector2i = pockets[end]
		var center := end - direction * 2
		var side := Vector2i(-direction.y, direction.x)
		# The near side of a possible gate has a square loop to retreat into.
		floor_cells[center + side] = "."
		floor_cells[center + side * 2 - direction] = "."
		floor_cells[center + side - direction * 2] = "."
		floor_cells[center - direction] = "."


static func _cells_to_rows(floor_cells: Dictionary, size: Vector2i) -> Array[String]:
	var rows: Array[String] = []
	for y in range(size.y):
		var row := ""
		for x in range(size.x):
			row += String(floor_cells.get(Vector2i(x, y), "#"))
		rows.append(row)
	return rows
