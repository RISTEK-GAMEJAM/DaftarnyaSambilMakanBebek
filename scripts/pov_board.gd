extends Node2D

const Board = preload("res://scripts/labyrinth.gd")
const UI = preload("res://scripts/maze_ui.gd")
const CrossGate = preload("res://scripts/cross_gate.gd")
const PressurePlate = preload("res://scripts/pressure_plate.gd")
const ELF_SCENES := [
	preload("res://scenes/characters/elf_boy.tscn"),
	preload("res://scenes/characters/elf_girl.tscn"),
]
const SNATCHER_SCENE := preload("res://scenes/characters/snatcher.tscn")
const FLOOR := preload("res://assets/sprites/tiles/lantai/lantai.tres")
const SAFE := preload("res://assets/sprites/tiles/landmarks/safe_spot.png")
const BRIDGE := preload("res://assets/sprites/tiles/landmarks/safe_bridge.png")
const EXIT_PORTAL := preload("res://assets/sprites/tiles/landmarks/exit_gate.png")
const LAIR := preload("res://assets/sprites/tiles/landmarks/snatcher_lair.png")
const TILE := 32.0
const ELF_STEP_SECONDS := 0.16
const SNATCHER_STEP_SECONDS := 0.14
const ELF_OFFSET := Vector2(0, 4)
const SNATCHER_OFFSET := Vector2(0, 5)
const DUEL_LIFT := Vector2(0, -14)
const MASK_DIRECTIONS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

var map_size: Vector2i
var elf: CharacterBody2D
var snatcher: CharacterBody2D

var _lane: int
var _layouts: Array
var _sight: int
var _snatcher_cell: Vector2i
var _floor_cells: Array[Vector2i] = []
var _discovered: Dictionary = {}
var _valid_steps: Array[Vector2i] = []
var _fog: Node2D
var _floor: TileMapLayer
var _plates: Dictionary = {}
var _gates: Dictionary = {}
var _safe_landmarks: Dictionary = {}


func setup(lane: int, layouts: Array, sight: int) -> void:
	_lane = lane
	_layouts = layouts
	_sight = sight
	var rows: Array = layouts[lane]
	var width := 0
	for row: String in rows:
		width = maxi(row.length(), width)
	map_size = Vector2i(width, rows.size())
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	_floor = TileMapLayer.new()
	_floor.tile_set = FLOOR
	add_child(_floor)
	for y in range(map_size.y):
		for x in range(map_size.x):
			var cell := Vector2i(x, y)
			var marker := Board.tile(lane, cell, layouts)
			if marker == "#":
				continue
			_floor_cells.append(cell)
			var mask := _floor_mask(cell)
			if marker == "o" and mask in [5, 10]:
				var bridge := _landmark(BRIDGE, cell, Vector2.ZERO, 1.0)
				bridge.rotation = PI / 2.0 if mask == 5 else 0.0
				_safe_landmarks[cell] = bridge
			else:
				_floor.set_cell(cell, 0, LabyrinthGenerator.MASK_TO_ATLAS[mask])
				if marker == "o":
					_safe_landmarks[cell] = _landmark(SAFE, cell, Vector2(0, -3), 0.72)
			if marker == "E":
				_landmark(EXIT_PORTAL, cell, Vector2(0, -4), 0.85)
			elif marker == "H":
				_landmark(LAIR, cell, Vector2(0, -3), 0.85)
			elif marker in Board.GATE_MARKERS:
				var gate := CrossGate.new()
				gate.position = Vector2(cell) * TILE
				gate.setup(marker, UI.A if lane == 0 else UI.B)
				add_child(gate)
				_gates[cell] = gate
			elif marker in Board.PLATE_MARKERS:
				var plate := PressurePlate.new()
				plate.position = Vector2(cell) * TILE
				plate.setup(str(Board.PLATE_MARKERS.find(marker) + 1), UI.B if lane == 0 else UI.A)
				add_child(plate)
				_plates[cell] = plate

	_fog = Node2D.new()
	_fog.z_index = 2
	_fog.draw.connect(_draw_fog)
	add_child(_fog)

	elf = ELF_SCENES[lane].instantiate()
	elf.set("behavior_mode", 4)
	elf.z_index = 3
	var start := Board.find_tile(lane, "S", layouts)
	elf.position = center(start) + ELF_OFFSET
	add_child(elf)
	snatcher = SNATCHER_SCENE.instantiate()
	snatcher.set("control_enabled", false)
	snatcher.z_index = 4
	_snatcher_cell = Board.find_tile(lane, "H", layouts)
	snatcher.position = center(_snatcher_cell) + SNATCHER_OFFSET
	add_child(snatcher)
	discover(start, true)


func _floor_mask(cell: Vector2i) -> int:
	var mask := 0
	for index in range(MASK_DIRECTIONS.size()):
		if Board.tile(_lane, cell + MASK_DIRECTIONS[index], _layouts) != "#":
			mask |= 1 << index
	return mask


func update_landmarks(state: Dictionary) -> Tween:
	var locked: Dictionary = state["locked_gates"][_lane]
	var gate_animation: Tween
	for cell: Vector2i in _gates:
		var started: Tween = _gates[cell].set_open(not locked.has(cell))
		if started:
			gate_animation = started

	var safe: Dictionary = state["safe_spots"][_lane]
	for cell: Vector2i in _safe_landmarks.keys():
		if not safe.has(cell):
			_safe_landmarks[cell].queue_free()
			_safe_landmarks.erase(cell)
			_floor.set_cell(cell, 0, LabyrinthGenerator.MASK_TO_ATLAS[_floor_mask(cell)])

	var active_plates: Dictionary = state["active_plates"][_lane]
	for cell: Vector2i in _plates:
		_plates[cell].pressed = active_plates.has(cell)
	return gate_animation


func _landmark(texture: Texture2D, cell: Vector2i, offset: Vector2, magnification: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.position = center(cell) + offset
	sprite.scale = Vector2.ONE * magnification
	sprite.z_index = 1
	add_child(sprite)
	return sprite


func center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * TILE


func cell_at(screen_position: Vector2) -> Vector2i:
	return Vector2i((to_local(screen_position) / TILE).floor())


func show_steps(cells: Array[Vector2i]) -> void:
	_valid_steps = cells
	_fog.queue_redraw()


func discover(origin: Vector2i, instant: bool = false) -> void:
	var newly_seen: Array[Vector2i] = []
	for cell in Board.visible_cells(_lane, origin, _sight, _layouts):
		if not _discovered.has(cell):
			newly_seen.append(cell)
			_discovered[cell] = 1.0 if instant else 0.0
	if not newly_seen.is_empty() and not instant:
		var tween := create_tween()
		tween.tween_method(_fade_cells.bind(newly_seen), 0.0, 1.0, 0.34).set_trans(Tween.TRANS_SINE)
	_fog.queue_redraw()
	_update_snatcher_visibility()


func _fade_cells(amount: float, cells: Array[Vector2i]) -> void:
	for cell in cells:
		_discovered[cell] = amount
	_fog.queue_redraw()


func _draw_fog() -> void:
	for cell in _floor_cells:
		var opacity := 1.0 - float(_discovered.get(cell, 0.0))
		if opacity > 0.0:
			var color := UI.ABYSS
			color.a = opacity
			_fog.draw_rect(Rect2(Vector2(cell) * TILE, Vector2.ONE * TILE), color)
	var accent := UI.A if _lane == 0 else UI.B
	for cell in _valid_steps:
		var bounds := Rect2(Vector2(cell) * TILE + Vector2(3, 3), Vector2(26, 26))
		_fog.draw_rect(bounds, Color(accent, 0.14))
		_fog.draw_rect(bounds, Color(accent, 0.86), false, 1.0)


func move_elf(cell: Vector2i) -> void:
	var target := center(cell) + ELF_OFFSET
	elf.call("set_board_motion", true, target.x - elf.position.x)
	discover(cell)
	await _slide(elf, target, ELF_STEP_SECONDS)
	elf.call("set_board_motion", false)


func move_snatcher(cell: Vector2i, carrying: bool = false) -> void:
	var from_discovered := _discovered.has(_snatcher_cell)
	_snatcher_cell = cell
	var target := center(cell) + SNATCHER_OFFSET
	if carrying:
		target += DUEL_LIFT
		discover(cell)
	snatcher.visible = from_discovered or _discovered.has(cell)
	await _slide(snatcher, target, SNATCHER_STEP_SECONDS)
	_update_snatcher_visibility()


func catch_elf() -> void:
	if is_instance_valid(snatcher.get("carried_target")):
		return
	snatcher.show()
	await _slide(snatcher, center(_snatcher_cell) + SNATCHER_OFFSET + DUEL_LIFT, 0.16)
	snatcher.call("grab_target", elf)
	await Signal(snatcher, "captured_target")


func free_elf(origin: Vector2i) -> void:
	snatcher.call("release_target")
	elf.position = center(origin) + ELF_OFFSET
	await _slide(snatcher, center(_snatcher_cell) + SNATCHER_OFFSET, 0.14)


func _update_snatcher_visibility() -> void:
	snatcher.visible = _discovered.has(_snatcher_cell)


func _slide(node: Node2D, target: Vector2, duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(node, "position", target, duration).set_trans(Tween.TRANS_SINE)
	await tween.finished
