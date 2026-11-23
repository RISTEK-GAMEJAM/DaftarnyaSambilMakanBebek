extends Node2D

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

@export_group("Flight Physics")
@export var wind_drag: float = 2.6

@onready var outline_line: Line2D = $OutlineLine
@onready var inner_line: Line2D = $InnerLine
@onready var heart_pivot: Node2D = $HeartPivot

var anchor: Node2D
var points: PackedVector2Array = PackedVector2Array()
var prev_points: PackedVector2Array = PackedVector2Array()
var facing_right: bool = true
var owner_velocity: Vector2 = Vector2.ZERO
var _time: float = 0.0
var _initialized: bool = false


func _ready() -> void:
	top_level = true
	if anchor_path != NodePath(""):
		anchor = get_node_or_null(anchor_path)
	_init_chain()


func _init_chain() -> void:
	var start_pos := anchor.global_position if anchor else global_position
	var back_x := -1.0 if facing_right else 1.0
	points.resize(segment_count + 1)
	prev_points.resize(segment_count + 1)
	for i in range(segment_count + 1):
		var t := float(i) / float(segment_count)
		# Start in a graceful S-curve behind the character
		var offset := Vector2(
			back_x * float(i) * segment_length * 0.92,
			sin(t * PI * 1.4) * 5.0 + t * 2.0
		)
		points[i] = start_pos + offset
		prev_points[i] = points[i]
	_initialized = true
	_sync_visuals()


func set_motion_state(is_facing_right: bool, vel: Vector2) -> void:
	facing_right = is_facing_right
	owner_velocity = vel


func _physics_process(delta: float) -> void:
	if not anchor:
		return
	if not _initialized:
		_init_chain()

	var dt := minf(delta, 0.033)
	_time += dt

	var root_pos := anchor.global_position
	var back_x := -1.0 if facing_right else 1.0
	var speed := owner_velocity.length()
	var flight_ratio := clampf(speed / 120.0, 0.0, 1.0)

	# 1. Pin root to hip anchor
	points[0] = root_pos
	prev_points[0] = root_pos

	# 2. Verlet integration with gravity, wind drag, and cat-like traveling wave
	for i in range(1, segment_count + 1):
		var t := float(i) / float(segment_count)
		var vel := (points[i] - prev_points[i]) * damping
		prev_points[i] = points[i]

		var accel := Vector2.ZERO

		# Gravity gives natural downward weight (tail droops when flying up!)
		accel.y += gravity * (0.4 + 0.6 * t)

		# Aerodynamic wind drag opposing flight velocity (tail streams behind flight path!)
		accel += -owner_velocity * wind_drag * (0.35 + 0.65 * t)

		# Gentle rearward posture bias (stronger when idle, lighter when fast-flying)
		var idle_weight := 1.0 - flight_ratio * 0.72
		accel.x += back_x * idle_back_force * idle_weight * (0.45 + 0.55 * t)

		# Cat-tail traveling sine wave from root to tip (organic & alive!)
		var phase := _time * (wave_speed + flight_ratio * 2.0) - t * wave_frequency
		var sway_amp := wave_strength * (0.25 + 0.75 * t) * (1.0 - flight_ratio * 0.45)
		accel.y += sin(phase) * sway_amp

		# Subtle upward lift near the tip when idle so it curls gracefully instead of hanging dead
		accel.y -= curl_up_tip_strength * idle_weight * pow(t, 2.0)

		points[i] += vel + accel * dt * dt

	# 3. Distance constraints (keeps exact constant length, zero stretching/shrinking!)
	for _iter in range(constraint_iterations):
		points[0] = root_pos
		# Keep first segment gently emerging rearward so it never kinks sharply into the skirt
		var root_guide := root_pos + Vector2(back_x * segment_length, 0.35 * segment_length)
		if flight_ratio < 0.4:
			points[1] = points[1].lerp(root_guide, 0.08 * (1.0 - flight_ratio))

		for i in range(segment_count):
			var p1 := points[i]
			var p2 := points[i + 1]
			var diff := p2 - p1
			var dist := diff.length()
			if dist < 0.0001:
				diff = Vector2(back_x, 0.1)
				dist = diff.length()
			var err := (dist - segment_length) / dist
			if i == 0:
				points[i + 1] = p2 - diff * err
			else:
				points[i] = p1 + diff * (err * 0.5)
				points[i + 1] = p2 - diff * (err * 0.5)

	_sync_visuals()


func _sync_visuals() -> void:
	var local_pts := PackedVector2Array()
	local_pts.resize(points.size())
	for i in range(points.size()):
		local_pts[i] = to_local(points[i])

	outline_line.points = local_pts
	inner_line.points = local_pts

	# Align the intact original heart sprite to the tail tip tangent
	var tip_pos := points[points.size() - 1]
	var prev_pos := points[maxi(0, points.size() - 3)]
	var tip_dir := tip_pos - prev_pos
	heart_pivot.global_position = tip_pos
	if tip_dir.length_squared() > 0.001:
		# Original heart_tip.png points downward (+Y = +PI/2), so subtract PI/2
		heart_pivot.rotation = tip_dir.angle() - PI * 0.5
