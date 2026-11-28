extends Node2D

enum TailMode { FREE, STRIKING, CARRYING }

@export var anchor_path: NodePath
@export var segment_count: int = 10
@export var segment_length: float = 2.6
@export var damping: float = 0.86
@export var gravity: float = 85.0
@export var constraint_iterations: int = 10

@export_group("Cat-Tail Sway")
@export var idle_back_force: float = 170.0
@export var wave_speed: float = 3.6
@export var wave_frequency: float = 3.2
@export var wave_strength: float = 210.0
@export var curl_up_tip_strength: float = 95.0

@export_group("Flight & Carry Physics")
@export var wind_drag: float = 2.6
@export var carry_gravity: float = 210.0
@export var carry_damping: float = 0.88
@export var strike_duration: float = 0.13
@export var wrap_width: float = 5.5
@export var wrap_height: float = 2.2

@onready var outline_line: Line2D = $OutlineLine
@onready var inner_line: Line2D = $InnerLine
@onready var wrap_front: Node2D = $WrapFront
@onready var wrap_outline_line: Line2D = $WrapFront/WrapOutlineLine
@onready var wrap_inner_line: Line2D = $WrapFront/WrapInnerLine
@onready var heart_pivot: Node2D = $HeartPivot

var anchor: Node2D
var points: PackedVector2Array = PackedVector2Array()
var prev_points: PackedVector2Array = PackedVector2Array()
var facing_right: bool = true
var owner_velocity: Vector2 = Vector2.ZERO

var mode: TailMode = TailMode.FREE
var _strike_target: Node2D = null
var _carried_target: Node2D = null
var _strike_timer: float = 0.0
var _strike_callback: Callable = Callable()
var _carry_waist_offset: Vector2 = Vector2(0.0, -10.0)

var _time: float = 0.0
var _initialized: bool = false


func _ready() -> void:
	top_level = true
	if anchor_path != NodePath(""):
		anchor = get_node_or_null(anchor_path)
	if wrap_front:
		wrap_front.visible = false
	_sync_transform_from_owner()
	_init_chain()


func _get_owner_scale() -> float:
	var parent_node := get_parent() as Node2D
	if parent_node:
		var gs := parent_node.global_scale.abs()
		return maxf((gs.x + gs.y) * 0.5, 0.05)
	return 1.0


func _get_target_scale(target: Node2D) -> float:
	if is_instance_valid(target):
		var gs := target.global_scale.abs()
		return maxf((gs.x + gs.y) * 0.5, 0.05)
	return _get_owner_scale()


func _sync_transform_from_owner() -> void:
	var s := _get_owner_scale()
	scale = Vector2(s, s)
	var parent_node := get_parent() as Node2D
	if parent_node:
		var abs_z := _get_absolute_z_index(parent_node)
		z_as_relative = false
		z_index = abs_z - 1


func _get_absolute_z_index(node: Node) -> int:
	var total := 0
	var current: Node = node
	while current is CanvasItem:
		var ci := current as CanvasItem
		total += ci.z_index
		if not ci.z_as_relative:
			break
		current = current.get_parent()
	return total


func reset_chain() -> void:
	_sync_transform_from_owner()
	_init_chain()


func _init_chain() -> void:
	var s := _get_owner_scale()
	var start_pos := anchor.global_position if anchor else global_position
	var back_x := -1.0 if facing_right else 1.0
	points.resize(segment_count + 1)
	prev_points.resize(segment_count + 1)
	for i in range(segment_count + 1):
		var t := float(i) / float(segment_count)
		var offset := Vector2(
			back_x * float(i) * segment_length * s * 0.92,
			(sin(t * PI * 1.4) * 5.0 + t * 2.0) * s
		)
		points[i] = start_pos + offset
		prev_points[i] = points[i]
	_initialized = true
	_sync_visuals()


func set_motion_state(is_facing_right: bool, vel: Vector2) -> void:
	facing_right = is_facing_right
	owner_velocity = vel


func start_strike(target: Node2D, waist_offset: Vector2, on_hit: Callable) -> void:
	_strike_target = target
	_carried_target = target
	_carry_waist_offset = waist_offset
	_strike_callback = on_hit
	_strike_timer = 0.0
	mode = TailMode.STRIKING


func start_carry(waist_offset: Vector2) -> void:
	_carry_waist_offset = waist_offset
	mode = TailMode.CARRYING
	if wrap_front:
		wrap_front.visible = true
	heart_pivot.z_index = 6


func release_carry() -> void:
	mode = TailMode.FREE
	_strike_target = null
	_carried_target = null
	_strike_callback = Callable()
	if wrap_front:
		wrap_front.visible = false
	heart_pivot.z_index = 0


func get_tip_position() -> Vector2:
	if points.is_empty():
		return global_position
	return points[points.size() - 1]


func get_carry_sway_angle() -> float:
	if points.size() < 4:
		return 0.0
	var tip := points[points.size() - 1]
	var upper := points[points.size() - 4]
	var hang_vec := tip - upper
	# Vertical down is +PI/2; measure horizontal sway deviation around vertical
	var sway := wrapf(hang_vec.angle() - PI * 0.5, -PI, PI)
	return clampf(sway * 0.45, -0.32, 0.32)


func _physics_process(delta: float) -> void:
	if not anchor:
		return
	_sync_transform_from_owner()
	if not _initialized:
		_init_chain()

	var dt := minf(delta, 0.033)
	_time += dt

	var s := _get_owner_scale()
	var root_pos := anchor.global_position
	var back_x := -1.0 if facing_right else 1.0
	var speed := owner_velocity.length() / s
	var flight_ratio := clampf(speed / 120.0, 0.0, 1.0)

	points[0] = root_pos
	prev_points[0] = root_pos

	if mode == TailMode.STRIKING:
		_update_strike(dt, root_pos, s)
	elif mode == TailMode.CARRYING:
		_update_carrying(dt, root_pos, back_x, flight_ratio, s)
	else:
		_update_free(dt, root_pos, back_x, flight_ratio, s)

	_sync_visuals()


func _update_free(dt: float, root_pos: Vector2, back_x: float, flight_ratio: float, s: float) -> void:
	for i in range(1, segment_count + 1):
		var t := float(i) / float(segment_count)
		var vel := (points[i] - prev_points[i]) * damping
		prev_points[i] = points[i]

		var accel := Vector2.ZERO
		accel.y += gravity * s * (0.4 + 0.6 * t)
		accel += -owner_velocity * wind_drag * (0.35 + 0.65 * t)

		var idle_weight := 1.0 - flight_ratio * 0.72
		accel.x += back_x * idle_back_force * s * idle_weight * (0.45 + 0.55 * t)

		var phase := _time * (wave_speed + flight_ratio * 2.0) - t * wave_frequency
		var sway_amp := wave_strength * s * (0.25 + 0.75 * t) * (1.0 - flight_ratio * 0.45)
		accel.y += sin(phase) * sway_amp
		accel.y -= curl_up_tip_strength * s * idle_weight * pow(t, 2.0)

		points[i] += vel + accel * dt * dt

	_solve_constraints(root_pos, back_x, flight_ratio, segment_length * s)


func _update_strike(dt: float, root_pos: Vector2, s: float) -> void:
	if not is_instance_valid(_strike_target):
		release_carry()
		return

	_strike_timer += dt
	var progress := clampf(_strike_timer / maxf(strike_duration, 0.02), 0.0, 1.0)
	# Snappy ease-out lash toward target waist
	var ease_p := 1.0 - pow(1.0 - progress, 3.0)
	var target_scale := _get_target_scale(_strike_target)
	var target_waist := _strike_target.global_position + _carry_waist_offset * target_scale

	for i in range(1, segment_count + 1):
		var t := float(i) / float(segment_count)
		# Whip curve shoots directly to target waist with a slight dramatic arc
		var direct := root_pos.lerp(target_waist, t * ease_p)
		var arc := Vector2(0.0, -sin(t * PI) * 8.0 * s * (1.0 - ease_p * 0.5))
		prev_points[i] = points[i]
		points[i] = points[i].lerp(direct + arc, 0.65)

	if progress >= 1.0:
		mode = TailMode.CARRYING
		if wrap_front:
			wrap_front.visible = true
		heart_pivot.z_index = 6
		if _strike_callback.is_valid():
			_strike_callback.call()


func _update_carrying(dt: float, root_pos: Vector2, back_x: float, flight_ratio: float, s: float) -> void:
	# Heavier rope simulation: target hangs from the tail tip and trails behind flight
	for i in range(1, segment_count + 1):
		var t := float(i) / float(segment_count)
		var vel := (points[i] - prev_points[i]) * carry_damping
		prev_points[i] = points[i]

		var accel := Vector2.ZERO
		# Stronger downward pull because an Elf is tied at the tip!
		accel.y += carry_gravity * s * (0.3 + 1.2 * pow(t, 1.3))
		# Trail smoothly behind movement direction
		accel += -owner_velocity * (wind_drag * 1.15) * (0.3 + 0.7 * t)
		# Keep slightly behind & below Snatcher when hovering idle so Elf is clearly visible
		var idle_weight := 1.0 - flight_ratio * 0.7
		accel.x += back_x * 95.0 * s * idle_weight * (0.4 + 0.6 * t)
		# Small struggle jiggle from the captured Elf at the tip
		accel.x += sin(_time * 16.0) * 35.0 * s * pow(t, 2.0)

		points[i] += vel + accel * dt * dt

	# Slightly shorter/taut carry length so Elf hangs nicely near Snatcher
	_solve_constraints(root_pos, back_x, 1.0, segment_length * s * 0.92)


func _solve_constraints(root_pos: Vector2, back_x: float, flight_ratio: float, seg_len: float) -> void:
	for _iter in range(constraint_iterations):
		points[0] = root_pos
		if flight_ratio < 0.4:
			var root_guide := root_pos + Vector2(back_x * seg_len, 0.35 * seg_len)
			points[1] = points[1].lerp(root_guide, 0.08 * (1.0 - flight_ratio))

		for i in range(segment_count):
			var p1 := points[i]
			var p2 := points[i + 1]
			var diff := p2 - p1
			var dist := diff.length()
			if dist < 0.0001:
				diff = Vector2(back_x, 0.1)
				dist = diff.length()
			var err := (dist - seg_len) / dist
			if i == 0:
				points[i + 1] = p2 - diff * err
			else:
				points[i] = p1 + diff * (err * 0.5)
				points[i + 1] = p2 - diff * (err * 0.5)


func _sync_visuals() -> void:
	var local_pts := PackedVector2Array()
	local_pts.resize(points.size())
	for i in range(points.size()):
		local_pts[i] = to_local(points[i])

	outline_line.points = local_pts
	inner_line.points = local_pts

	var tip_pos := points[points.size() - 1]
	var prev_pos := points[maxi(0, points.size() - 3)]
	var tip_dir := tip_pos - prev_pos

	if mode == TailMode.CARRYING and wrap_front:
		# Draw a snug two-turn tail coil wrapping IN FRONT of the captured Elf's waist!
		var back_x := -1.0 if facing_right else 1.0
		var sway := get_carry_sway_angle()
		var wrap_center := to_local(tip_pos)
		var wrap_ratio := _get_target_scale(_carried_target) / maxf(_get_owner_scale(), 0.05)
		var coil_pts := PackedVector2Array()
		var steps := 10
		for s_idx in range(steps + 1):
			var u := float(s_idx) / float(steps)
			# Wraps from back side across front of waist (slight diagonal double-coil feel)
			var angle := lerpf(-PI * 0.15, PI * 1.15, u)
			var px := cos(angle) * wrap_width * wrap_ratio * (-back_x)
			var py := sin(angle) * wrap_height * wrap_ratio + (u - 0.5) * 2.8 * wrap_ratio
			var pt := Vector2(px, py).rotated(sway)
			coil_pts.append(wrap_center + pt)

		wrap_outline_line.points = coil_pts
		wrap_inner_line.points = coil_pts

		# Place the heart tip neatly knotted at the side end of the waist wrap!
		var knot_local := coil_pts[coil_pts.size() - 1]
		var knot_prev := coil_pts[coil_pts.size() - 3]
		heart_pivot.global_position = to_global(knot_local)
		heart_pivot.rotation = (knot_local - knot_prev).angle() - PI * 0.5
	else:
		heart_pivot.global_position = tip_pos
		if tip_dir.length_squared() > 0.001:
			heart_pivot.rotation = tip_dir.angle() - PI * 0.5
