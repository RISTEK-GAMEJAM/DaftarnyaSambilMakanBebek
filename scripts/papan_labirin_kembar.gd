extends Node2D

const Catalog = preload("res://scripts/stage_catalog.gd")
const UI = preload("res://scripts/maze_ui.gd")
const PovBoard = preload("res://scripts/pov_board.gd")
const Options = preload("res://scripts/options_panel.gd")
const Game24 = preload("res://scripts/game_24_panel.gd")
const Tutorial = preload("res://scripts/stage_intro.gd")
const Jumpscare = preload("res://scripts/snatcher_jumpscare.gd")
const TurnsLeft = preload("res://scripts/turns_left.gd")
const TURNS_LEFT_SCENE := preload("res://scenes/ui/turns_left.tscn")

const BOARD_AREA := Rect2(0, 104, 1440, 680)
const BOARD_ZOOM := 2.3
const CAMERA_MARGIN := Vector2(240, 160)

@export var duel_time_limit := 25.0

var _stage: int
var _game: TwinLabyrinth
var _boards: Array[PovBoard] = []
var _shown_lane := 0
var _busy := false
var _camera: Camera2D
var _interface: CanvasLayer
var _cover: ColorRect
var _options: Options
var _duel: Game24
var _intro: Tutorial
var _jumpscare: Jumpscare
var _stage_label: Label
var _pov_label: Label
var _turns_left: TurnsLeft
var _dice_label: Label
var _language_button: Button
var _options_button: Button
var _stage_button: Button
var _preview_button: Button
var _roll_button: Button
var _end_button: Button
var _dice: Array[PixelDie] = []
var _result: Panel
var _result_title: Label
var _result_detail: Label
var _result_retry: Button
var _result_stages: Button
var _result_next: Button


func _ready() -> void:
	_stage = GameSettings.selected_stage
	var data: Dictionary = Catalog.STAGES[_stage]
	var layouts := Catalog.layouts_for(_stage)
	_game = TwinLabyrinth.new(layouts, data["chase"])
	var background := CanvasLayer.new()
	background.layer = -1
	add_child(background)
	UI.box(background, Rect2(Vector2.ZERO, UI.SCREEN), UI.ABYSS)
	for lane in range(2):
		var board := PovBoard.new()
		add_child(board)
		board.setup(lane, layouts, data["sight"])
		board.visible = lane == 0
		_boards.append(board)

	_camera = Camera2D.new()
	_camera.zoom = Vector2.ONE * BOARD_ZOOM
	_camera.offset = (UI.SCREEN / 2.0 - BOARD_AREA.get_center()) / BOARD_ZOOM
	add_child(_camera)
	_focus_runner(0, _game.get_state()["runners"][0])

	_interface = CanvasLayer.new()
	add_child(_interface)
	_cover = ColorRect.new()
	_cover.color = UI.ABYSS
	_cover.modulate.a = 0.0
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cover.z_index = 5
	_interface.add_child(_cover)
	UI.place(_cover, BOARD_AREA)

	_build_hud()
	_options = Options.new()
	_duel = Game24.new()
	_duel.duel_time_limit = float(data.get("duel_time", duel_time_limit))
	_interface.add_child(_duel)
	_duel.finished_duel.connect(_resolve_duel)
	_duel.options_requested.connect(_open_options)
	if _stage == 0:
		_intro = Tutorial.new()
		_interface.add_child(_intro)
	_build_result()
	_interface.add_child(_options)
	_jumpscare = Jumpscare.new()
	_interface.add_child(_jumpscare)
	_options.visibility_changed.connect(func() -> void: _duel.timer_paused = _options.visible)
	Lang.language_changed.connect(_refresh)
	_refresh()


func _build_hud() -> void:
	var hud := Control.new()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.z_index = 10
	_interface.add_child(hud)
	var top := UI.box(hud, Rect2(0, 0, 1440, 104), UI.PANEL, UI.LINE)
	_stage_label = UI.label(top, "", 16, UI.MUTED, true)
	UI.place(_stage_label, Rect2(32, 18, 400, 22))
	_pov_label = UI.label(top, "", 22, UI.A, true)
	UI.place(_pov_label, Rect2(32, 46, 398, 34))

	_turns_left = TURNS_LEFT_SCENE.instantiate()
	top.add_child(_turns_left)
	_turns_left.position = (top.size - _turns_left.size) / 2.0

	_options_button = UI.button(top, "", _open_options, PixelButton.Variant.SLATE, 23)
	_language_button = UI.button(top, "", Lang.toggle, PixelButton.Variant.SLATE, 23)
	_stage_button = UI.button(top, "", _open_stages, PixelButton.Variant.SLATE, 23)
	UI.place(_stage_button, Rect2(1000, 30, 155, 46))
	UI.place(_options_button, Rect2(1165, 30, 134, 46))
	UI.place(_language_button, Rect2(1309, 30, 99, 46))

	var bottom := UI.box(hud, Rect2(0, 784, 1440, 116), UI.PANEL, UI.LINE)
	_dice_label = UI.label(bottom, "", 14, UI.MUTED, true)
	UI.place(_dice_label, Rect2(32, 15, 258, 20))
	for index in range(2):
		var die := PixelDie.new()
		die.custom_minimum_size = Vector2(49, 49)
		bottom.add_child(die)
		UI.place(die, Rect2(32 + 75 * index, 44, 49, 49))
		_dice.append(die)
	var plus := UI.label(bottom, "+", 22, UI.MUTED)
	UI.place(plus, Rect2(88, 55, 17, 24))

	_preview_button = UI.button(bottom, "", _preview_other, PixelButton.Variant.SLATE, 23)
	UI.place(_preview_button, Rect2(995, 35, 191, 51))
	_roll_button = UI.button(bottom, "", _roll, PixelButton.Variant.GOLD, 27)
	_end_button = UI.button(bottom, "", _end_turn, PixelButton.Variant.GOLD, 27)
	for button in [_roll_button, _end_button]:
		UI.place(button, Rect2(1199, 35, 209, 51))


func _refresh(_code: String = "") -> void:
	var state := _game.get_state()
	var phase: int = state["phase"]
	var lane: int = state["active_lane"]
	var preview := lane != _shown_lane and phase in [TwinLabyrinth.Phase.MOVE, TwinLabyrinth.Phase.ROLL]
	_stage_label.text = Catalog.title(_stage)
	_pov_label.text = Lang.t("pov_character", [_letter(_shown_lane)])
	_pov_label.add_theme_color_override("font_color", UI.A if _shown_lane == 0 else UI.B)
	_turns_left.show_count(state["turns_left"], state["round"], phase == TwinLabyrinth.Phase.ROLL)
	_dice_label.text = Lang.t("shared_dice")
	_language_button.text = Lang.button_label()
	_language_button.tooltip_text = Lang.t("lang_tooltip")
	_options_button.text = Lang.t("menu_options")
	_stage_button.text = Lang.t("action_back")
	_preview_button.text = Lang.t("action_back") if preview else Lang.t("preview_pov", [_letter(1 - _shown_lane)])
	_preview_button.visible = _game.can_preview()
	_preview_button.disabled = _busy
	_roll_button.visible = phase == TwinLabyrinth.Phase.ROLL
	_roll_button.disabled = _busy
	_roll_button.text = Lang.t("btn_roll")
	_end_button.visible = phase == TwinLabyrinth.Phase.MOVE
	_end_button.disabled = _busy or preview or _game.should_end_turn()
	_end_button.text = Lang.t("end_turn")
	_options_button.disabled = _busy
	_stage_button.disabled = _busy
	var steps: Array[Vector2i] = []
	if not _busy and not preview:
		steps = _game.available_steps()
	_boards[_shown_lane].show_steps(steps)
	if is_instance_valid(_result):
		_localize_result(state)


func _letter(lane: int) -> String:
	return "A" if lane == 0 else "B"


func _input_blocked() -> bool:
	return _busy or _options.visible or _duel.visible or (is_instance_valid(_intro) and _intro.visible) or (is_instance_valid(_jumpscare) and _jumpscare.visible) or _result.get_parent().visible


func _unhandled_input(event: InputEvent) -> void:
	if _input_blocked():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if BOARD_AREA.has_point(event.position):
			var position_on_board: Vector2 = get_canvas_transform().affine_inverse() * event.position
			_step(_boards[_shown_lane].cell_at(position_on_board))
	elif event is InputEventKey and event.pressed and not event.echo:
		var kev := event as InputEventKey
		var dir := Vector2i.ZERO
		match kev.keycode:
			KEY_SPACE:
				get_viewport().set_input_as_handled()
				_roll()
				return
			KEY_UP:
				dir = Vector2i.UP
			KEY_DOWN:
				dir = Vector2i.DOWN
			KEY_LEFT:
				dir = Vector2i.LEFT
			KEY_RIGHT:
				dir = Vector2i.RIGHT
		if dir != Vector2i.ZERO:
			var state := _game.get_state()
			var lane: int = state["active_lane"]
			if int(state["phase"]) == TwinLabyrinth.Phase.MOVE and _shown_lane == lane:
				var origin: Vector2i = state["runners"][lane]
				get_viewport().set_input_as_handled()
				_step(origin + dir)


func _preview_other() -> void:
	if _input_blocked() or not _game.can_preview():
		return
	_busy = true
	_refresh()
	await _show_lane(1 - _shown_lane)
	_busy = false
	_refresh()


func _show_lane(lane: int) -> void:
	if lane == _shown_lane:
		return
	_boards[_shown_lane].show_steps([])
	var out := create_tween()
	out.tween_property(_cover, "modulate:a", 1.0, 0.20).set_trans(Tween.TRANS_SINE)
	await out.finished
	_boards[_shown_lane].hide()
	_shown_lane = lane
	_focus_runner(lane, _game.get_state()["runners"][lane])
	_boards[lane].show()
	_refresh()
	GameSettings.play_sound("handoff")
	var fade_in := create_tween()
	fade_in.tween_property(_cover, "modulate:a", 0.0, 0.27).set_trans(Tween.TRANS_SINE)
	await fade_in.finished


func _focus_runner(lane: int, cell: Vector2i, seconds: float = 0.0) -> void:
	var board := _boards[lane]
	var desired := board.center(cell)
	var midpoint := Vector2(board.map_size) * PovBoard.TILE / 2.0
	var slack := (midpoint - (BOARD_AREA.size / 2.0 - CAMERA_MARGIN) / BOARD_ZOOM).max(Vector2.ZERO)
	var target := desired.clamp(midpoint - slack, midpoint + slack)
	if seconds == 0.0:
		_camera.position = target
		_camera.force_update_scroll()
	else:
		var tween := create_tween()
		tween.tween_property(_camera, "position", target, seconds).set_trans(Tween.TRANS_SINE)


func _roll() -> void:
	if _input_blocked() or not _game.roll_dice():
		return
	_busy = true
	_refresh()
	var dice: Vector2i = _game.get_state()["dice"]
	GameSettings.play_sound("roll")
	_dice[0].play_roll_animation(dice.x)
	await _dice[1].play_roll_animation(dice.y)
	await _settle_phase()


func _step(cell: Vector2i) -> void:
	var lane: int = _game.get_state()["active_lane"]
	if _shown_lane != lane or not _game.step_runner(cell):
		return
	_busy = true
	_refresh()
	GameSettings.play_sound("step")
	await _move_elf(lane, cell)
	await _settle_phase()


func _move_elf(lane: int, cell: Vector2i) -> void:
	_focus_runner(lane, cell, PovBoard.ELF_STEP_SECONDS)
	await _boards[lane].move_elf(cell)


func _end_turn() -> void:
	if _input_blocked() or _shown_lane != _game.get_state()["active_lane"]:
		return
	_busy = true
	_refresh()
	await _advance_turn()
	await _settle_phase()


func _advance_turn() -> void:
	var lane: int = _game.get_state()["active_lane"]
	if not _game.end_turn():
		return
	if lane == 0:
		await _show_lane(1)
		return
	var state := _game.get_state()
	for character in range(2):
		var path: Array = state["last_snatcher_paths"][character]
		if character == _shown_lane:
			for cell: Vector2i in path:
				await _boards[character].move_snatcher(cell)
		elif not path.is_empty():
			_boards[character].sync_snatcher(path.back())


func _settle_phase() -> void:
	while _game.should_end_turn():
		await _advance_turn()

	var state := _game.get_state()
	match state["phase"]:
		TwinLabyrinth.Phase.DUEL:
			var duel := _game.get_duel()
			var lane: int = duel["lane"]
			await _show_lane(lane)
			var fresh_capture := not is_instance_valid(_boards[lane].snatcher.get("carried_target"))
			await _boards[lane].catch_elf()
			if fresh_capture and is_instance_valid(_jumpscare):
				await _jumpscare.trigger()
			_duel.open_duel(duel)
		TwinLabyrinth.Phase.WON, TwinLabyrinth.Phase.LOST:
			var won: bool = state["phase"] == TwinLabyrinth.Phase.WON
			_result.get_parent().show()
			GameSettings.play_sound("victory" if won else "defeat")
		TwinLabyrinth.Phase.ROLL:
			# If A already escaped, the next roll stays with B. A's turn is skipped after the roll.
			var lane := 1 if state["escaped"][0] else 0
			await _show_lane(lane)
			for die in _dice:
				die.value = 0
		TwinLabyrinth.Phase.MOVE:
			await _show_lane(state["active_lane"])
	_busy = false
	_refresh()


func _resolve_duel(won: bool, fast_bonus: bool, expression: String) -> void:
	_busy = true
	var before := _game.get_state()
	_game.resolve_duel_24(won, fast_bonus, expression)
	var state := _game.get_state()
	var result: Dictionary = state["duel_results"].back()
	var lane: int = result["lane"]
	var board := _boards[lane]
	_duel.show_result(result)
	await get_tree().create_timer(1.75).timeout
	_duel.hide()
	if won:
		await board.free_elf(before["runners"][lane])
		for cell: Vector2i in result["runner_path"]:
			await _move_elf(lane, cell)
	else:
		for cell: Vector2i in result["snatcher_path"]:
			_focus_runner(lane, cell, PovBoard.SNATCHER_STEP_SECONDS)
			await board.move_snatcher(cell, true)
	await _settle_phase()


func _open_options() -> void:
	if not _busy:
		_options.show()


func _open_stages() -> void:
	get_tree().change_scene_to_file(Catalog.SELECT_SCENE)


func _build_result() -> void:
	var layer := Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.z_index = 70
	_interface.add_child(layer)
	_result = UI.modal(layer, Rect2(367, 290, 706, 320))
	_result.get_parent().hide()
	_result_title = UI.label(_result, "", 36, UI.GOLD, true)
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.place(_result_title, Rect2(32, 30, 642, 65))
	_result_detail = UI.label(_result, "", 28)
	_result_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.place(_result_detail, Rect2(55, 117, 596, 74))
	_result_stages = UI.button(_result, "", _open_stages)
	_result_retry = UI.button(_result, "", get_tree().reload_current_scene)
	_result_next = UI.button(_result, "", _next_stage, PixelButton.Variant.GOLD)
	UI.place(_result_next, Rect2(471, 224, 204, 57))


func _localize_result(state: Dictionary) -> void:
	var won: bool = state["phase"] == TwinLabyrinth.Phase.WON
	_result_title.text = Lang.t("victory" if won else "game_over")
	_result_title.add_theme_color_override("font_color", UI.GOLD if won else UI.DANGER)
	_result_detail.text = Lang.t("victory_detail") if won else Lang.t("defeat_detail", [_letter(state["lost_lane"])])
	_result_stages.text = Lang.t("select_stage")
	_result_retry.text = Lang.t("btn_play_again")
	_result_next.text = Lang.t("next_stage")
	_result_next.visible = won and _stage + 1 < Catalog.STAGES.size()
	var offset := 0 if _result_next.visible else 110
	UI.place(_result_stages, Rect2(31 + offset, 224, 204, 57))
	UI.place(_result_retry, Rect2(251 + offset, 224, 204, 57))


func _next_stage() -> void:
	GameSettings.selected_stage = _stage + 1
	get_tree().reload_current_scene()
