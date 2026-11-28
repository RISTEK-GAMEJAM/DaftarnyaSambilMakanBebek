extends Node2D

const UI = preload("res://scripts/maze_ui.gd")
const Catalog = preload("res://scripts/stage_catalog.gd")
const Preview = preload("res://scripts/stage_preview.gd")

var _selected: int
var _run_seed: int
var _layouts: Array
var _preview_lane := 0
var _rows: Array[PixelButton] = []
var _header: Label
var _back: Button
var _language: Button
var _name: Label
var _description: Label
var _dimensions: Label
var _difficulty: Label
var _begin: Button
var _preview: Preview
var _preview_note: Label
var _preview_buttons: Array[PixelButton] = []


func _ready() -> void:
	_selected = GameSettings.selected_stage
	_prepare_preview()
	UI.box(self, Rect2(Vector2.ZERO, UI.SCREEN), UI.ABYSS)
	_back = UI.button(self, "", func() -> void: get_tree().change_scene_to_file(Catalog.MENU_SCENE))
	_language = UI.button(self, "", Lang.toggle)
	UI.place(_back, Rect2(48, 37, 162, 51))
	UI.place(_language, Rect2(1278, 37, 114, 51))
	_header = UI.label(self, "", 34, UI.GOLD, true)
	_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.place(_header, Rect2(242, 34, 956, 54))
	UI.box(self, Rect2(48, 107, 1344, 1), UI.LINE)

	var list := UI.box(self, Rect2(48, 130, 378, 722), UI.PANEL, UI.LINE)
	for index in range(Catalog.STAGES.size()):
		var button := UI.button(list, "", _select.bind(index), PixelButton.Variant.SLATE, 29)
		UI.place(button, Rect2(18, 25 + 112 * index, 342, 112 - 14))
		_rows.append(button)

	var detail := UI.box(self, Rect2(448, 130, 944, 722), UI.PANEL, UI.LINE)
	_name = UI.label(detail, "", 31, UI.INK, true)
	UI.place(_name, Rect2(32, 25, 650, 44))
	_description = UI.label(detail, "", 26, UI.MUTED)
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.place(_description, Rect2(32, 79, 880, 62))
	var preview_box := UI.box(detail, Rect2(32, 158, 880, 438), UI.ABYSS, UI.LINE)
	_preview = Preview.new()
	preview_box.add_child(_preview)
	_preview_note = UI.label(preview_box, "", 22, UI.MUTED)
	_preview_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UI.place(_preview_note, Rect2(365, 16, 495, 40))
	for lane in range(2):
		var button := UI.button(preview_box, "", _set_preview.bind(lane), PixelButton.Variant.SLATE, 24)
		UI.place(button, Rect2(18 + lane * 139, 16, 130, 40))
		_preview_buttons.append(button)

	_dimensions = UI.label(detail, "", 24, UI.MUTED)
	UI.place(_dimensions, Rect2(32, 612, 515, 32))
	_difficulty = UI.label(detail, "", 24, UI.GOLD)
	UI.place(_difficulty, Rect2(32, 648, 515, 32))
	_begin = UI.button(detail, "", _begin_stage, PixelButton.Variant.GOLD, 28)
	UI.place(_begin, Rect2(650, 620, 262, 59))
	Lang.language_changed.connect(_refresh)
	_refresh()


func _select(index: int) -> void:
	if index == _selected:
		return
	_selected = index
	_preview_lane = 0
	_prepare_preview()
	_refresh()


func _prepare_preview() -> void:
	_run_seed = randi()
	_layouts = Catalog.layouts_for(_selected, _run_seed)


func _set_preview(lane: int) -> void:
	_preview_lane = lane
	_refresh()


func _refresh(_code: String = "") -> void:
	_header.text = Lang.t("select_stage")
	_back.text = Lang.t("action_back")
	_language.text = Lang.button_label()
	_language.tooltip_text = Lang.t("lang_tooltip")
	_name.text = Catalog.title(_selected)
	_description.text = Lang.t("stage_description_%d" % _selected)
	_begin.text = Lang.t("stage_begin")
	_preview_note.text = Lang.t("stage_preview_hidden_exit")
	for index in range(_rows.size()):
		_rows[index].text = Catalog.title(index)
		_rows[index].variant = PixelButton.Variant.GOLD if index == _selected else PixelButton.Variant.SLATE
	for lane in range(2):
		_preview_buttons[lane].text = Lang.t("lane_a" if lane == 0 else "lane_b")
		_preview_buttons[lane].variant = PixelButton.Variant.EMERALD if lane == _preview_lane else PixelButton.Variant.SLATE
	var rows := _full_preview()
	var width := 0
	for row in rows:
		width = maxi(width, row.length())
	_dimensions.text = Lang.t("stage_dimensions", [width, rows.size()])
	_difficulty.text = Lang.t("stage_difficulty", [_selected, Catalog.STAGES.size() - 1]) if _selected > 0 else Lang.t("stage_training")
	_preview.setup(rows, Rect2(14, 62, 852, 356), UI.A if _preview_lane == 0 else UI.B)


func _full_preview() -> Array[String]:
	var rows: Array[String] = []
	for row: String in _layouts[_preview_lane]:
		var silhouette := ""
		for marker in row:
			silhouette += "#" if marker == "#" else "."
		rows.append(silhouette)
	return rows


func _begin_stage() -> void:
	GameSettings.selected_stage = _selected
	GameSettings.pending_run_seed = _run_seed
	get_tree().change_scene_to_file(Catalog.GAME_SCENE)
