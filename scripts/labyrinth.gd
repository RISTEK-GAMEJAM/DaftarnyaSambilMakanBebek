extends RefCounted

# Default 10x9 layouts synced with scenes/levels/labirin_a.tscn and labirin_b.tscn.
const LAYOUTS := [
	[
		"....o.....",
		".#.#.####E",
		".#.#.#####",
		".#.#......",
		"..o##.###.",
		".####.###.",
		"S.H##..##.",
		".#####.##.",
		"....o.....",
	],
	[
		"#.S.H.....",
		"#.####.##.",
		"#...o#.##.",
		"####.#.##.",
		"..##...o..",
		".###.####.",
		".#...#....",
		".#.###.###",
		"...o...E##",
	],
]
const DIRECTIONS := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]


static func build_layout_from_labyrinth(labirin: Node2D) -> Array[String]:
	var result: Array[String] = []
	if labirin == null:
		return result
	var tilemap := labirin.get_node_or_null("Lantai") as TileMapLayer
	if tilemap == null:
		return result

	var used_rect := tilemap.get_used_rect()
	if used_rect.size.x <= 0 or used_rect.size.y <= 0:
		return result

	var width := used_rect.end.x
	var height := used_rect.end.y
	var grid := {}
	for cell in tilemap.get_used_cells():
		grid[cell] = "."

	var penanda := labirin.get_node_or_null("Penanda")
	if penanda != null:
		for child in penanda.get_children():
			if child is Marker2D:
				var cell := tilemap.local_to_map(tilemap.to_local(child.global_position))
				if child.name == "SpawnPemain":
					grid[cell] = "S"
				elif child.name == "SpawnSnatcher":
					grid[cell] = "H"
				elif child.name == "ExitGate":
					grid[cell] = "E"
				elif child.name.begins_with("SafeSpot"):
					grid[cell] = "o"

	for y in range(height):
		var row := ""
		for x in range(width):
			row += String(grid.get(Vector2i(x, y), "#"))
		result.append(row)
	return result


static func tile(lane: int, cell: Vector2i, layouts: Array = LAYOUTS) -> String:
	var layout: Array = layouts[lane]
	if cell.y < 0 or cell.y >= layout.size():
		return "#"
	var row: String = layout[cell.y]
	if cell.x < 0 or cell.x >= row.length():
		return "#"
	return row[cell.x]


static func find_tile(lane: int, marker: String, layouts: Array = LAYOUTS) -> Vector2i:
	var layout: Array = layouts[lane]
	for y in range(layout.size()):
		var x: int = layout[y].find(marker)
		if x >= 0:
			return Vector2i(x, y)
	return Vector2i(-1, -1)


static func find_all_tiles(lane: int, marker: String, layouts: Array = LAYOUTS) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var layout: Array = layouts[lane]
	for y in range(layout.size()):
		var row: String = layout[y]
		for x in range(row.length()):
			if row[x] == marker:
				cells.append(Vector2i(x, y))
	return cells


# Return the steps after start, including destination. Adjacent tiles use four directions.
static func shortest_path(lane: int, start: Vector2i, destination: Vector2i, layouts: Array = LAYOUTS) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var frontier: Array[Vector2i] = [start]
	var previous := {start: start}

	while not frontier.is_empty():
		var cell: Vector2i = frontier.pop_front()
		if cell == destination:
			while cell != start:
				path.push_front(cell)
				cell = previous[cell]
			return path
		for direction in DIRECTIONS:
			var neighbor: Vector2i = cell + direction
			if tile(lane, neighbor, layouts) != "#" and not previous.has(neighbor):
				previous[neighbor] = cell
				frontier.append(neighbor)
	return path
