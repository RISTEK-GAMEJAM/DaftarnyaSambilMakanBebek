extends Control

signal finished_duel(won: bool, fast_bonus: bool, expression: String)
signal options_requested

const UI = preload("res://scripts/maze_ui.gd")
const FONT_TITLE = UI.TITLE_FONT
const FONT_BODY = UI.BODY_FONT

var duel_time_limit := 25.0
var timer_paused := false
var _duel_panel: Panel
var _duel_title: Label
var _duel_timer_lbl: Label
var _duel_hint_lbl: Label
var _duel_cards_row: HBoxContainer
var _duel_ops_row: HBoxContainer
var _duel_status_lbl: Label
var _btn_undo_24: Button
var _btn_clear_24: Button
var _btn_giveup_24: Button
var _options: Button
var _op_buttons: Dictionary = {}
var _duel_active := false
var _duel_time_left := 0.0
var _duel_initial_items: Array[Dictionary] = []
var _duel_items: Array[Dictionary] = []
var _duel_history: Array = []
var _selected_card_idx := -1
var _selected_op := ""
var _lane: int
var _status_key := "duel_prompt_start"
var _status_args: Array = []


func _ready() -> void:
	z_index = 60
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_duel_panel()
	Lang.language_changed.connect(_localize)
	_localize()
	hide()


func _process(delta: float) -> void:
	if _duel_active and not timer_paused:
		_duel_time_left = maxf(0.0, _duel_time_left - delta)
		_update_duel_timer_label()
		if _duel_time_left == 0.0:
			_conclude_duel_24(false, false, "")


func _localize(_code: String = "") -> void:
	_duel_title.text = Lang.t("duel_title", [Lang.t("lane_a" if _lane == 0 else "lane_b")])
	_duel_hint_lbl.text = Lang.t("duel_hint")
	_btn_undo_24.text = Lang.t("btn_undo")
	_btn_clear_24.text = Lang.t("btn_reset_cards")
	_btn_giveup_24.text = Lang.t("btn_giveup")
	_options.text = Lang.t("menu_options")
	_update_duel_timer_label()
	_set_status(_status_key, _status_args)


func _set_status(key: String, args: Array = []) -> void:
	_status_key = key
	_status_args = args
	_duel_status_lbl.text = Lang.t(key, args)


func _build_duel_panel() -> void:
	_duel_panel = UI.modal(self, Rect2(382, 227, 676, 446), UI.DANGER)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(24.0, 24.0)
	vbox.size = Vector2(628.0, 372.0)
	vbox.add_theme_constant_override("separation", 12)
	_duel_panel.add_child(vbox)

	_duel_title = Label.new()
	_duel_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_duel_title.add_theme_font_override("font", FONT_TITLE)
	_duel_title.add_theme_font_size_override("font_size", 22)
	_duel_title.add_theme_color_override("font_color", Color(0.98, 0.62, 0.68, 1.0))
	vbox.add_child(_duel_title)

	_duel_timer_lbl = Label.new()
	_duel_timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_duel_timer_lbl.add_theme_font_override("font", FONT_BODY)
	_duel_timer_lbl.add_theme_font_size_override("font_size", 26)
	_duel_timer_lbl.add_theme_color_override("font_color", Color(0.96, 0.90, 0.60, 1.0))
	vbox.add_child(_duel_timer_lbl)

	_duel_hint_lbl = Label.new()
	_duel_hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_duel_hint_lbl.add_theme_font_override("font", FONT_BODY)
	_duel_hint_lbl.add_theme_font_size_override("font_size", 20)
	_duel_hint_lbl.add_theme_color_override("font_color", Color(0.72, 0.78, 0.77, 1.0))
	_duel_hint_lbl.text = "Gabungkan semua 4 kartu pakai  +  -  ×  :  hingga hasilnya tepat 24!"
	vbox.add_child(_duel_hint_lbl)

	_duel_cards_row = HBoxContainer.new()
	_duel_cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_duel_cards_row.custom_minimum_size = Vector2(0.0, 82.0)
	_duel_cards_row.add_theme_constant_override("separation", 14)
	vbox.add_child(_duel_cards_row)

	_duel_ops_row = HBoxContainer.new()
	_duel_ops_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_duel_ops_row.custom_minimum_size = Vector2(0.0, 48.0)
	_duel_ops_row.add_theme_constant_override("separation", 14)
	vbox.add_child(_duel_ops_row)

	for op in ["+", "-", "×", ":"]:
		var op_btn := PixelButton.new()
		op_btn.text = op
		op_btn.custom_minimum_size = Vector2(68.0, 48.0)
		op_btn.configure(PixelButton.Variant.SLATE, 30, 2.0, false)
		op_btn.pressed.connect(_on_op_pressed.bind(op))
		_duel_ops_row.add_child(op_btn)
		_op_buttons[op] = op_btn

	_duel_status_lbl = Label.new()
	_duel_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_duel_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_duel_status_lbl.custom_minimum_size = Vector2(0.0, 44.0)
	_duel_status_lbl.add_theme_font_override("font", FONT_BODY)
	_duel_status_lbl.add_theme_font_size_override("font_size", 22)
	_duel_status_lbl.add_theme_color_override("font_color", Color(0.98, 0.85, 0.44, 1.0))
	vbox.add_child(_duel_status_lbl)

	var util_row := HBoxContainer.new()
	util_row.alignment = BoxContainer.ALIGNMENT_CENTER
	util_row.add_theme_constant_override("separation", 12)
	vbox.add_child(util_row)

	_btn_undo_24 = PixelButton.new()
	_btn_undo_24.text = "Undo"
	_btn_undo_24.custom_minimum_size = Vector2(114.0, 42.0)
	(_btn_undo_24 as PixelButton).configure(PixelButton.Variant.SLATE, 23, 2.0, true)
	_btn_undo_24.pressed.connect(_on_undo_24_pressed)
	util_row.add_child(_btn_undo_24)

	_btn_clear_24 = PixelButton.new()
	_btn_clear_24.text = "Ulang Kartu"
	_btn_clear_24.custom_minimum_size = Vector2(138.0, 42.0)
	(_btn_clear_24 as PixelButton).configure(PixelButton.Variant.SLATE, 23, 2.0, true)
	_btn_clear_24.pressed.connect(_on_clear_24_pressed)
	util_row.add_child(_btn_clear_24)

	_btn_giveup_24 = PixelButton.new()
	_btn_giveup_24.text = "Menyerah"
	_btn_giveup_24.custom_minimum_size = Vector2(126.0, 42.0)
	(_btn_giveup_24 as PixelButton).configure(PixelButton.Variant.CRIMSON, 23, 2.0, true)
	_btn_giveup_24.pressed.connect(_on_giveup_24_pressed)
	util_row.add_child(_btn_giveup_24)


	_options = UI.button(_duel_panel, "", func() -> void: options_requested.emit(), PixelButton.Variant.SLATE, 19)
	UI.place(_options, Rect2(530, 21, 124, 34))

func open_duel(duel: Dictionary) -> void:
	_lane = duel["lane"]
	show()
	_localize()
	_duel_initial_items.clear()
	var cards: Array = duel["cards"]
	for c in cards:
		var val: int = int(c["value"])
		var card_lbl: String = String(c["label"])
		var display_lbl := "%s\n(%d)" % [card_lbl, val] if card_lbl.begins_with("A") else card_lbl
		_duel_initial_items.append({
			"rat": TwinLabyrinth.rat_make(val, 1),
			"display": display_lbl,
			"expr": str(val),
		})

	_duel_items = _duel_initial_items.duplicate(true)
	_duel_history.clear()
	_selected_card_idx = -1
	_selected_op = ""
	_duel_time_left = duel_time_limit
	_duel_active = true
	_options.disabled = false
	_set_status("duel_prompt_start")
	_set_duel_controls_enabled(true)
	_update_duel_timer_label()
	_rebuild_card_buttons()
	_refresh_op_buttons()


func _update_duel_timer_label() -> void:
	_duel_timer_lbl.text = Lang.t("duel_timer", [_duel_time_left])
	if _duel_time_left <= 7.0:
		_duel_timer_lbl.add_theme_color_override("font_color", Color(1.0, 0.38, 0.42, 1.0))
	elif _duel_time_left <= duel_time_limit * 0.5:
		_duel_timer_lbl.add_theme_color_override("font_color", Color(0.98, 0.80, 0.36, 1.0))
	else:
		_duel_timer_lbl.add_theme_color_override("font_color", Color(0.62, 0.94, 0.72, 1.0))


func _set_duel_controls_enabled(enabled: bool) -> void:
	for op in _op_buttons:
		(_op_buttons[op] as Button).disabled = not enabled
	_btn_undo_24.disabled = (not enabled) or _duel_history.is_empty()
	_btn_clear_24.disabled = (not enabled) or _duel_history.is_empty()
	_btn_giveup_24.disabled = not enabled


func _rebuild_card_buttons() -> void:
	for child in _duel_cards_row.get_children():
		_duel_cards_row.remove_child(child)
		child.queue_free()

	for i in range(_duel_items.size()):
		var item: Dictionary = _duel_items[i]
		var btn := PixelButton.new()
		btn.text = String(item["display"])
		btn.custom_minimum_size = Vector2(108.0, 78.0)
		var is_sel := (i == _selected_card_idx)
		btn.configure(PixelButton.Variant.CARD_SELECTED if is_sel else PixelButton.Variant.CARD, 30, 3.0, true)
		btn.disabled = not _duel_active
		btn.pressed.connect(_on_card_24_pressed.bind(i))
		_duel_cards_row.add_child(btn)

	_btn_undo_24.disabled = (not _duel_active) or _duel_history.is_empty()
	_btn_clear_24.disabled = (not _duel_active) or _duel_history.is_empty()


func _refresh_op_buttons() -> void:
	for op in _op_buttons:
		var btn: PixelButton = _op_buttons[op]
		btn.variant = PixelButton.Variant.GOLD if (op == _selected_op) else PixelButton.Variant.SLATE
		btn.disabled = not _duel_active


func _on_card_24_pressed(idx: int) -> void:
	if not _duel_active or idx < 0 or idx >= _duel_items.size():
		return

	if _selected_card_idx == -1:
		_selected_card_idx = idx
		_set_status("duel_pick_op", [TwinLabyrinth.rat_format(_duel_items[idx]["rat"])])
		_rebuild_card_buttons()
		return

	if _selected_card_idx == idx:
		_selected_card_idx = -1
		_selected_op = ""
		_set_status("duel_cancel")
		_rebuild_card_buttons()
		_refresh_op_buttons()
		return

	if _selected_op == "":
		_selected_card_idx = idx
		_set_status("duel_pick_op", [TwinLabyrinth.rat_format(_duel_items[idx]["rat"])])
		_rebuild_card_buttons()
		return

	# Combine _selected_card_idx (_selected_op) idx!
	var a_item: Dictionary = _duel_items[_selected_card_idx]
	var b_item: Dictionary = _duel_items[idx]
	var a_rat: Vector2i = a_item["rat"]
	var b_rat: Vector2i = b_item["rat"]

	var res_rat := TwinLabyrinth.rat_apply(a_rat, b_rat, _selected_op)
	if res_rat.y == 0:
		_set_status("duel_div_zero")
		_selected_op = ""
		_refresh_op_buttons()
		return

	_duel_history.append(_duel_items.duplicate(true))
	var res_expr := "(%s %s %s)" % [String(a_item["expr"]), _selected_op, String(b_item["expr"])]
	var res_str := TwinLabyrinth.rat_format(res_rat)

	var next_items: Array[Dictionary] = []
	for k in range(_duel_items.size()):
		if k != _selected_card_idx and k != idx:
			next_items.append(_duel_items[k])
	next_items.append({
		"rat": res_rat,
		"display": res_str,
		"expr": res_expr,
	})

	_duel_items = next_items
	_selected_card_idx = -1
	_selected_op = ""
	_rebuild_card_buttons()
	_refresh_op_buttons()

	if _duel_items.size() == 1:
		if TwinLabyrinth.rat_is_24(res_rat):
			var fast_bonus := _duel_time_left >= duel_time_limit * 0.5
			_conclude_duel_24(true, fast_bonus, res_expr)
		else:
			_set_status("duel_not_24", [res_expr, res_str])
	else:
		_set_status("duel_continue", [res_expr, res_str])


func _on_op_pressed(op: String) -> void:
	if not _duel_active:
		return
	if _selected_card_idx == -1:
		_set_status("duel_pick_first")
		return
	_selected_op = op
	_set_status("duel_pick_second", [TwinLabyrinth.rat_format(_duel_items[_selected_card_idx]["rat"]), op])
	_refresh_op_buttons()


func _on_undo_24_pressed() -> void:
	if not _duel_active or _duel_history.is_empty():
		return
	_duel_items = _duel_history.pop_back()
	_selected_card_idx = -1
	_selected_op = ""
	_set_status("duel_undone")
	_rebuild_card_buttons()
	_refresh_op_buttons()


func _on_clear_24_pressed() -> void:
	if not _duel_active or _duel_history.is_empty():
		return
	_duel_items = _duel_initial_items.duplicate(true)
	_duel_history.clear()
	_selected_card_idx = -1
	_selected_op = ""
	_set_status("duel_cleared")
	_rebuild_card_buttons()
	_refresh_op_buttons()


func _on_giveup_24_pressed() -> void:
	if not _duel_active:
		return
	_conclude_duel_24(false, false, "")



func _conclude_duel_24(won: bool, fast_bonus: bool, expression: String) -> void:
	if not _duel_active:
		return
	_duel_active = false
	_set_duel_controls_enabled(false)
	_rebuild_card_buttons()
	_options.disabled = true
	finished_duel.emit(won, fast_bonus, expression)


func show_result(result: Dictionary) -> void:
	match result["outcome"]:
		"fast_win":
			_set_status("res_fast_win", [result["player_expr"]])
		"win":
			_set_status("res_win", [result["player_expr"]])
		_:
			var key := "res_loss_gameover" if result["game_over"] else "res_loss_drag"
			_set_status(key, [result["solution_hint"]])
