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
static func shortest_path(lane: int, start: Vector2i, destination: Vector2i, layouts: Array = LAYOUTS, blocked_marker: String = "") -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var frontier: Array[Vector2i] = [start]
	var previous := {start: start}
	var head := 0

	while head < frontier.size():
		var cell := frontier[head]
		head += 1
		if cell == destination:
			while cell != start:
				path.push_front(cell)
				cell = previous[cell]
			return path
		for direction in DIRECTIONS:
			var neighbor: Vector2i = cell + direction
			var marker := tile(lane, neighbor, layouts)
			if marker != "#" and marker != blocked_marker and not previous.has(neighbor):
				previous[neighbor] = cell
				frontier.append(neighbor)
	return path


static func visible_cells(lane: int, origin: Vector2i, radius: int, layouts: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(-radius, radius + 1):
		for x in range(-radius, radius + 1):
			var offset := Vector2i(x, y)
			var target := origin + offset
			if offset.length_squared() <= radius * radius and tile(lane, target, layouts) != "#":
				if _has_line_of_sight(lane, origin, target, layouts):
					result.append(target)
	return result


static func _has_line_of_sight(lane: int, origin: Vector2i, target: Vector2i, layouts: Array) -> bool:
	# Walk the grid boundaries crossed by a ray between the two cell centers.
	var delta := target - origin
	var size := delta.abs()
	var direction := delta.sign()
	var crossed := Vector2i.ZERO
	var cell := origin
	while cell != target:
		var x_boundary := (crossed.x * 2 + 1) * size.y
		var y_boundary := (crossed.y * 2 + 1) * size.x
		if x_boundary == y_boundary:
			# A ray cannot pass through the corner between two empty abyss tiles.
			if tile(lane, cell + Vector2i(direction.x, 0), layouts) == "#" and tile(lane, cell + Vector2i(0, direction.y), layouts) == "#":
				return false
			cell += direction
			crossed += Vector2i.ONE
		elif x_boundary < y_boundary:
			cell.x += direction.x
			crossed.x += 1
		else:
			cell.y += direction.y
			crossed.y += 1
		if tile(lane, cell, layouts) == "#":
			return false
	return true
