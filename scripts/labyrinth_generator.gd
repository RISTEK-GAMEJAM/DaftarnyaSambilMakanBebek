class_name LabyrinthGenerator
extends RefCounted

const WIDTH := 10
const HEIGHT := 9
const DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

# Verified 16-tile 4-bit bitmask (1=UP, 2=RIGHT, 4=DOWN, 8=LEFT) -> lantai.png atlas coords
const MASK_TO_ATLAS: Dictionary = {
	0: Vector2i(0, 0),
	1: Vector2i(1, 1),
	2: Vector2i(2, 1),
	3: Vector2i(3, 0),
	4: Vector2i(0, 1),
	5: Vector2i(2, 0),
	6: Vector2i(0, 2),
	7: Vector2i(0, 3),
	8: Vector2i(3, 1),
	9: Vector2i(3, 3),
	10: Vector2i(1, 0),
	11: Vector2i(2, 3),
	12: Vector2i(2, 2),
	13: Vector2i(3, 2),
	14: Vector2i(1, 2),
	15: Vector2i(1, 3),
}


static func generate(rng: RandomNumberGenerator = null) -> Dictionary:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()

	for _attempt in range(80):
		var candidate := _try_generate_once(rng)
		if not candidate.is_empty():
			return candidate

	# Guaranteed fallback (should virtually never trigger)
	return _try_generate_once(rng, true)


static func _try_generate_once(rng: RandomNumberGenerator, relaxed: bool = false) -> Dictionary:
	var floor_set := {}
	var x_shift := rng.randi_range(0, 1) # alternates 0,2,4,6,8 vs 1,3,5,7,9 for full 10-wide variety

	# 1. Randomized DFS spanning tree on a 5x5 coarse node lattice inside 10x9
	var nodes_visited := {}
	var start_node := Vector2i(rng.randi_range(0, 4), rng.randi_range(0, 4))
	var stack: Array[Vector2i] = [start_node]
	nodes_visited[start_node] = true
	floor_set[_node_to_cell(start_node, x_shift)] = true

	while not stack.is_empty():
		var cur: Vector2i = stack[stack.size() - 1]
		var neighbors: Array[Vector2i] = []
		for d in DIRS:
			var nxt := cur + d
			if nxt.x >= 0 and nxt.x < 5 and nxt.y >= 0 and nxt.y < 5 and not nodes_visited.has(nxt):
				neighbors.append(nxt)
		if neighbors.is_empty():
			stack.pop_back()
			continue
		var chosen := neighbors[rng.randi_range(0, neighbors.size() - 1)]
		nodes_visited[chosen] = true
		var c_a := _node_to_cell(cur, x_shift)
		var c_b := _node_to_cell(chosen, x_shift)
		floor_set[c_b] = true
		floor_set[(c_a + c_b) / 2] = true
		stack.append(chosen)

	# 2. Eliminate ALL dead-ends in the 5x5 lattice (pair adjacent dead-ends first to stay twisty!)
	var lattice_nodes: Array[Vector2i] = []
	for ny in range(5):
		for nx in range(5):
			lattice_nodes.append(Vector2i(nx, ny))
	_shuffle_array(lattice_nodes, rng)

	for node in lattice_nodes:
		var c_a := _node_to_cell(node, x_shift)
		if _cell_degree(floor_set, c_a) >= 2:
			continue
		var deadend_walls: Array[Vector2i] = []
		var other_walls: Array[Vector2i] = []
		for d in DIRS:
			var nb_node := node + d
			if nb_node.x < 0 or nb_node.x >= 5 or nb_node.y < 0 or nb_node.y >= 5:
				continue
			var mid := c_a + d
			if floor_set.has(mid):
				continue
			var c_b := _node_to_cell(nb_node, x_shift)
			if _cell_degree(floor_set, c_b) == 1:
				deadend_walls.append(mid)
			else:
				other_walls.append(mid)
		var wall_pool := deadend_walls if not deadend_walls.is_empty() else other_walls
		if not wall_pool.is_empty():
			var chosen_wall := wall_pool[rng.randi_range(0, wall_pool.size() - 1)]
			floor_set[chosen_wall] = true

	# 3. Carve EXACTLY ONE 1-tile dead-end alcove on the outer free column for SpawnPemain (S)!
	# Its single neighbor (entry) is on the dead-end-free lattice, so entry is guaranteed a junction (deg >= 3)
	var free_col := 9 if x_shift == 0 else 0
	var inner_col := 8 if x_shift == 0 else 1
	var alcove_rows: Array[int] = [2, 4, 6]
	_shuffle_array(alcove_rows, rng)
	var spawn_row := alcove_rows[0]
	var spawn_player := Vector2i(free_col, spawn_row)
	var spawn_entry := Vector2i(inner_col, spawn_row)
	floor_set[spawn_player] = true

	var floor_cells: Array[Vector2i] = []
	for c in floor_set.keys():
		floor_cells.append(c)

	# 4. Pick ExitGate (E) on an edge cell (degree >= 2, far from S: 12..20 steps)
	var exit_candidates: Array[Vector2i] = []
	for c in floor_cells:
		if c == spawn_player or c == spawn_entry:
			continue
		var is_edge := (c.x == 0 or c.x == WIDTH - 1 or c.y == 0 or c.y == HEIGHT - 1)
		if is_edge and _cell_degree(floor_set, c) >= 2:
			exit_candidates.append(c)
	_shuffle_array(exit_candidates, rng)

	var dist_from_s := _bfs_distances(floor_set, spawn_player)
	var exit_gate := Vector2i(-1, -1)
	var min_dist := 12 if not relaxed else 8
	var good_exits: Array[Vector2i] = []
	for b in exit_candidates:
		var d: int = int(dist_from_s.get(b, -1))
		if d >= min_dist and d <= 20:
			good_exits.append(b)
	if good_exits.is_empty():
		return {}
	exit_gate = good_exits[rng.randi_range(0, good_exits.size() - 1)]

	# 5. Pick SpawnSnatcher (H): 4..6 steps from S (so >= 3 steps from spawn_entry!),
	# NEVER blocking S's exit alcove or the shortest path to ExitGate!
	var dist_from_e := _bfs_distances(floor_set, exit_gate)
	var dist_s_to_e: int = int(dist_from_s.get(exit_gate, 999))
	var dist_entry_to_e: int = int(dist_from_e.get(spawn_entry, 999))
	var ideal_snatchers: Array[Vector2i] = []
	var good_snatchers: Array[Vector2i] = []

	for c in floor_cells:
		if c == spawn_player or c == spawn_entry or c == exit_gate:
			continue
		if not relaxed and c.y == 0:
			continue # keep Snatcher's horns cleanly inside top frame
		var ds: int = int(dist_from_s.get(c, -1))
		var de: int = int(dist_from_e.get(c, -1))
		if ds < 4 or ds > 6 or de < 7:
			continue

		# ANTI-TRAP CHECK: Removing H must STILL leave a clean, unobstructed path from S to E!
		var dist_avoid_h := _bfs_distances_avoiding(floor_set, spawn_player, c)
		if not dist_avoid_h.has(exit_gate):
			continue
		var d_se_no_h: int = int(dist_avoid_h[exit_gate])
		if d_se_no_h > dist_s_to_e + 1:
			continue

		# Check that from spawn_entry (1 step out of S), Elf has a clear branch toward E staying >= 3 steps from H
		var dist_from_c := _bfs_distances(floor_set, c)
		if int(dist_from_c.get(spawn_entry, 0)) < 3:
			continue
		var has_clear_escape := false
		for dir in DIRS:
			var nb := spawn_entry + dir
			if not floor_set.has(nb) or nb == spawn_player or nb == c:
				continue
			var nb_to_h: int = int(dist_from_c.get(nb, 0))
			var nb_to_e: int = int(dist_from_e.get(nb, 999))
			if nb_to_h >= 3 and nb_to_e < dist_entry_to_e:
				has_clear_escape = true
				break
		if not has_clear_escape:
			continue

		if d_se_no_h == dist_s_to_e:
			ideal_snatchers.append(c) # Completely off the shortest S->E route!
		else:
			good_snatchers.append(c)

	var snatcher_pool := ideal_snatchers if not ideal_snatchers.is_empty() else good_snatchers
	if snatcher_pool.is_empty() and relaxed:
		for c in floor_cells:
			var ds: int = int(dist_from_s.get(c, -1))
			if c != spawn_player and c != spawn_entry and c != exit_gate and ds >= 4 and ds <= 7:
				var dist_avoid_h := _bfs_distances_avoiding(floor_set, spawn_player, c)
				if dist_avoid_h.has(exit_gate):
					snatcher_pool.append(c)
	if snatcher_pool.is_empty():
		return {}
	var spawn_snatcher := snatcher_pool[rng.randi_range(0, snatcher_pool.size() - 1)]

	# 6. Pick 3 Safe Spots — STRONGLY prioritizing horizontal 1-tile bridges (mask == 10)
	# flanked by water/chasm on UP & DOWN so safe_bridge.png renders cleanly on every Safe Spot!
	var strict_h_bridges: Array[Vector2i] = []
	var edge_h_bridges: Array[Vector2i] = []
	var strict_v_bridges: Array[Vector2i] = []
	var fallback_corridors: Array[Vector2i] = []
	var dist_from_h := _bfs_distances(floor_set, spawn_snatcher)

	for c in floor_cells:
		if c == spawn_player or c == spawn_snatcher or c == exit_gate:
			continue
		if int(dist_from_s.get(c, 99)) < 2 or int(dist_from_h.get(c, 99)) < 2 or int(dist_from_e.get(c, 99)) < 2:
			continue
		var m := _cell_mask(floor_set, c)
		if m == 10:
			if _in_bounds(c + Vector2i.UP) and _in_bounds(c + Vector2i.DOWN):
				strict_h_bridges.append(c)
			else:
				edge_h_bridges.append(c)
		elif m == 5:
			if _in_bounds(c + Vector2i.LEFT) and _in_bounds(c + Vector2i.RIGHT):
				strict_v_bridges.append(c)
			else:
				fallback_corridors.append(c)

	_shuffle_array(strict_h_bridges, rng)
	_shuffle_array(edge_h_bridges, rng)
	_shuffle_array(strict_v_bridges, rng)
	_shuffle_array(fallback_corridors, rng)

	var safe_spots: Array[Vector2i] = []
	for pool in [strict_h_bridges, edge_h_bridges, strict_v_bridges, fallback_corridors]:
		for c in pool:
			if safe_spots.size() >= 3:
				break
			var far_enough := true
			for existing in safe_spots:
				if absi(existing.x - c.x) + absi(existing.y - c.y) < 3:
					far_enough = false
					break
			if far_enough:
				safe_spots.append(c)

	if safe_spots.size() < 3:
		if not relaxed:
			return {}
		for c in floor_cells:
			if safe_spots.size() >= 3:
				break
			if c != spawn_player and c != spawn_snatcher and c != exit_gate and not safe_spots.has(c):
				safe_spots.append(c)

	# Require all 3 Safe Spots to be horizontal bridges (at least 2 interior with chasm on both UP & DOWN)
	if not relaxed:
		var strict_h_count := 0
		var total_h_count := 0
		for s in safe_spots:
			if strict_h_bridges.has(s):
				strict_h_count += 1
				total_h_count += 1
			elif edge_h_bridges.has(s):
				total_h_count += 1
		if strict_h_count < 2 or total_h_count < 3:
			return {}

	return {
		"floor_set": floor_set,
		"spawn_player": spawn_player,
		"spawn_snatcher": spawn_snatcher,
		"exit_gate": exit_gate,
		"safe_spots": safe_spots,
	}


static func apply_to_labyrinth(labirin: Node2D, data: Dictionary) -> void:
	if labirin == null or data.is_empty():
		return
	var tilemap := labirin.get_node_or_null("Lantai") as TileMapLayer
	if tilemap == null:
		return

	var floor_set: Dictionary = data["floor_set"]
	tilemap.clear()
	for c in floor_set.keys():
		var cell: Vector2i = c
		var mask := _cell_mask(floor_set, cell)
		var atlas: Vector2i = MASK_TO_ATLAS.get(mask, Vector2i(0, 0))
		tilemap.set_cell(cell, 0, atlas, 0)

	var penanda := labirin.get_node_or_null("Penanda")
	if penanda != null:
		_place_marker(penanda, "SpawnPemain", tilemap, data["spawn_player"])
		_place_marker(penanda, "SpawnSnatcher", tilemap, data["spawn_snatcher"])
		_place_marker(penanda, "ExitGate", tilemap, data["exit_gate"])
		var safes: Array = data["safe_spots"]
		for i in range(mini(3, safes.size())):
			_place_marker(penanda, "SafeSpot%d" % (i + 1), tilemap, safes[i])

	var env := labirin.get_node_or_null("Lingkungan")
	if env != null and env.has_method("rebuild_environment"):
		env.call("rebuild_environment")


static func _place_marker(penanda: Node, marker_name: String, tilemap: TileMapLayer, cell: Vector2i) -> void:
	var m := penanda.get_node_or_null(marker_name) as Marker2D
	if m != null:
		m.position = tilemap.map_to_local(cell)


static func _node_to_cell(node: Vector2i, x_shift: int) -> Vector2i:
	return Vector2i(node.x * 2 + x_shift, node.y * 2)


static func _in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.x < WIDTH and c.y >= 0 and c.y < HEIGHT


static func _cell_mask(floor_set: Dictionary, c: Vector2i) -> int:
	var m := 0
	if floor_set.has(c + Vector2i.UP): m |= 1
	if floor_set.has(c + Vector2i.RIGHT): m |= 2
	if floor_set.has(c + Vector2i.DOWN): m |= 4
	if floor_set.has(c + Vector2i.LEFT): m |= 8
	return m


static func _cell_degree(floor_set: Dictionary, c: Vector2i) -> int:
	var deg := 0
	for dir in DIRS:
		if floor_set.has(c + dir):
			deg += 1
	return deg


static func _bfs_distances(floor_set: Dictionary, start: Vector2i) -> Dictionary:
	return _bfs_distances_avoiding(floor_set, start, Vector2i(-999, -999))


static func _bfs_distances_avoiding(floor_set: Dictionary, start: Vector2i, blocked: Vector2i) -> Dictionary:
	if start == blocked:
		return {}
	var dist := {start: 0}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		var d: int = int(dist[cur])
		for dir in DIRS:
			var nxt := cur + dir
			if nxt != blocked and floor_set.has(nxt) and not dist.has(nxt):
				dist[nxt] = d + 1
				queue.append(nxt)
	return dist


static func _shuffle_array(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
