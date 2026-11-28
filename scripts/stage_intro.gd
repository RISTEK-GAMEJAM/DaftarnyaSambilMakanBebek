extends Control

const UI = preload("res://scripts/maze_ui.gd")
const SPEAKERS := ["A", "B", "A", "B", "B"]
const CHARS_PER_SECOND := 52.0

var _page := 0
var _typing := false
var _type_tween: Tween
var _title: Label
var _speaker: Label
var _body: Label
var _counter: Label
var _previous: Button
var _next: Button


func _ready() -> void:
	# Bottom dialogue box keeps the labyrinth and Elf visible above it.
	z_index = 50
	position = Vector2.ZERO
	size = UI.SCREEN
	mouse_filter = Control.MOUSE_FILTER_STOP

	var panel := UI.box(self, Rect2(160, 586, 1120, 186), Color(0.055, 0.080, 0.112, 0.96), UI.GOLD)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.080, 0.112, 0.96)
	style.border_color = UI.GOLD
	style.set_border_width_all(3)
	panel.add_theme_stylebox_override("panel", style)

	_title = UI.label(panel, "", 13, UI.GOLD, true)
	UI.place(_title, Rect2(26, 14, 300, 20))
	_speaker = UI.label(panel, "", 20, UI.A, true)
	UI.place(_speaker, Rect2(26, 36, 400, 28))
	_counter = UI.label(panel, "", 20, UI.MUTED)
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UI.place(_counter, Rect2(960, 16, 134, 28))
	UI.box(panel, Rect2(26, 68, 1068, 1), UI.LINE)

	_body = UI.label(panel, "", 26)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	UI.place(_body, Rect2(26, 78, 724, 96))

	_previous = UI.button(panel, "", _previous_page, PixelButton.Variant.SLATE, 22)
	_next = UI.button(panel, "", _next_page, PixelButton.Variant.BRIGHT_GOLD, 22)
	UI.place(_previous, Rect2(768, 122, 148, 46))
	UI.place(_next, Rect2(928, 122, 166, 46))

	Lang.language_changed.connect(_on_language_changed)
	_refresh(true)


func _on_language_changed(_code: String = "") -> void:
	_refresh(_typing)


func _refresh(animate: bool = true) -> void:
	_title.text = Lang.t("stage_tutorial")
	_speaker.text = Lang.t("intro_speaker", [SPEAKERS[_page]])
	_speaker.add_theme_color_override("font_color", UI.A if SPEAKERS[_page] == "A" else UI.B)
	_body.text = Lang.t("intro_%d" % _page)
	_counter.text = "%d / %d" % [_page + 1, SPEAKERS.size()]
	_previous.visible = _page > 0
	_previous.text = Lang.t("action_back")
	_next.text = Lang.t("stage_begin" if _page == SPEAKERS.size() - 1 else "intro_next")
	if animate:
		_start_typing()
	else:
		_finish_typing()


func _start_typing() -> void:
	if _type_tween and _type_tween.is_valid():
		_type_tween.kill()
	var total := _body.get_total_character_count()
	if total <= 0:
		_finish_typing()
		return
	_typing = true
	_next.disabled = true
	_body.visible_characters = 0
	var duration := clampf(float(total) / CHARS_PER_SECOND, 0.4, 3.6)
	_type_tween = create_tween()
	_type_tween.tween_property(_body, "visible_characters", total, duration)
	_type_tween.finished.connect(_finish_typing)


func _finish_typing() -> void:
	_typing = false
	_body.visible_characters = -1
	_next.disabled = false


func _previous_page() -> void:
	_page -= 1
	_refresh(true)


func _next_page() -> void:
	if _typing:
		return
	if _page == SPEAKERS.size() - 1:
		hide()
	else:
		_page += 1
		_refresh(true)


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var kev := event as InputEventKey
		if kev.keycode == KEY_SPACE or kev.keycode == KEY_ENTER:
			get_viewport().set_input_as_handled()
			_next_page()
