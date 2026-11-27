extends Control

const UI = preload("res://scripts/maze_ui.gd")
const SPEAKERS := ["A", "B", "A", "B"]

var _page := 0
var _title: Label
var _speaker: Label
var _body: Label
var _counter: Label
var _previous: Button
var _next: Button


func _ready() -> void:
	z_index = 50
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := UI.modal(self, Rect2(340, 267, 760, 366))
	_title = UI.label(panel, "", 15, UI.GOLD, true)
	UI.place(_title, Rect2(35, 24, 600, 24))
	_speaker = UI.label(panel, "", 26, UI.A, true)
	UI.place(_speaker, Rect2(35, 57, 690, 39))
	UI.box(panel, Rect2(35, 108, 690, 1), UI.LINE)
	_body = UI.label(panel, "", 29)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	UI.place(_body, Rect2(35, 129, 690, 130))
	_counter = UI.label(panel, "", 22, UI.MUTED)
	UI.place(_counter, Rect2(35, 292, 96, 46))
	_previous = UI.button(panel, "", _previous_page)
	_next = UI.button(panel, "", _next_page, PixelButton.Variant.GOLD)
	UI.place(_previous, Rect2(374, 292, 164, 46))
	UI.place(_next, Rect2(550, 292, 175, 46))
	Lang.language_changed.connect(_refresh)
	_refresh()


func _refresh(_code: String = "") -> void:
	_title.text = Lang.t("stage_tutorial")
	_speaker.text = Lang.t("intro_speaker", [SPEAKERS[_page]])
	_speaker.add_theme_color_override("font_color", UI.A if _page % 2 == 0 else UI.B)
	_body.text = Lang.t("intro_%d" % _page)
	_counter.text = "%d / %d" % [_page + 1, SPEAKERS.size()]
	_previous.visible = _page > 0
	_previous.text = Lang.t("action_back")
	_next.text = Lang.t("stage_begin" if _page == SPEAKERS.size() - 1 else "intro_next")


func _previous_page() -> void:
	_page -= 1
	_refresh()


func _next_page() -> void:
	if _page == SPEAKERS.size() - 1:
		hide()
	else:
		_page += 1
		_refresh()
