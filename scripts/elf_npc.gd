extends CharacterBody2D

enum BehaviorMode { IDLE, PATROL, PLAYER_TEST, CAPTURED }

@export var behavior_mode: BehaviorMode = BehaviorMode.IDLE
@export var move_speed: float = 60.0
@export var patrol_distance: float = 44.0
@export var patrol_wait_time: float = 1.0
@export var default_facing_left: bool = true

@onready var visuals: Node2D = $Visuals
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var facing_left: bool = true
var _origin_x: float = 0.0
var _patrol_dir: float = -1.0
var _wait_timer: float = 0.0


func _ready() -> void:
	add_to_group("capturable")
	_origin_x = global_position.x
	facing_left = default_facing_left
	_patrol_dir = -1.0 if facing_left else 1.0
	_apply_facing()
	_sync_initial_anim()


func _sync_initial_anim() -> void:
	match behavior_mode:
		BehaviorMode.CAPTURED:
			play_state("captured")
		BehaviorMode.PATROL:
			play_state("walk")
		_:
			play_state("idle")


func _apply_facing() -> void:
	# Original art faces left, so scale.x = 1 faces left, -1 faces right.
	visuals.scale.x = 1.0 if facing_left else -1.0


func is_captured() -> bool:
	return behavior_mode == BehaviorMode.CAPTURED


func set_captured(captured: bool) -> void:
	if captured:
		behavior_mode = BehaviorMode.CAPTURED
		velocity = Vector2.ZERO
		if collision_shape:
			collision_shape.set_deferred("disabled", true)
		play_state("captured")
	else:
		behavior_mode = BehaviorMode.IDLE
		rotation = 0.0
		_origin_x = global_position.x
		if collision_shape:
			collision_shape.set_deferred("disabled", false)
		play_state("idle")


func play_state(anim_name: String) -> void:
	if anim_player and anim_player.has_animation(anim_name):
		if anim_player.current_animation != anim_name:
			anim_player.play(anim_name, 0.1)


func _physics_process(delta: float) -> void:
	match behavior_mode:
		BehaviorMode.IDLE:
			velocity = Vector2.ZERO
			play_state("idle")

		BehaviorMode.CAPTURED:
			velocity = Vector2.ZERO
			play_state("captured")

		BehaviorMode.PATROL:
			if _wait_timer > 0.0:
				_wait_timer -= delta
				velocity = Vector2.ZERO
				play_state("idle")
			else:
				velocity = Vector2(_patrol_dir * move_speed * 0.75, 0.0)
				facing_left = _patrol_dir < 0.0
				_apply_facing()
				play_state("walk")
				move_and_slide()

				if absf(global_position.x - _origin_x) >= patrol_distance:
					global_position.x = _origin_x + signf(global_position.x - _origin_x) * patrol_distance
					_patrol_dir *= -1.0
					_wait_timer = patrol_wait_time

		BehaviorMode.PLAYER_TEST:
			var dir := Vector2(
				Input.get_axis("ui_left", "ui_right"),
				Input.get_axis("ui_up", "ui_down")
			)
			if dir == Vector2.ZERO:
				dir.x = float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
				dir.y = float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
			if dir.length() > 1.0:
				dir = dir.normalized()

			velocity = dir * move_speed
			move_and_slide()

			if dir.x < -0.05:
				facing_left = true
				_apply_facing()
			elif dir.x > 0.05:
				facing_left = false
				_apply_facing()

			if dir.length() > 0.05:
				play_state("walk")
			else:
				play_state("idle")
