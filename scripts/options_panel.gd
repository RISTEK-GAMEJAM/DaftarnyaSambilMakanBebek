extends Control

const UI = preload("res://scripts/maze_ui.gd")

var _title: Label
var _labels: Array[Label] = []
var _mute: CheckButton
var _close: Button


func _ready() -> void:
	z_index = 80
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := UI.modal(self, Rect2(420, 220, 600, 460))
	_title = UI.label(panel, "", 30, UI.GOLD, true)
	UI.place(_title, Rect2(38, 26, 520, 45))
	UI.box(panel, Rect2(38, 83, 524, 1), UI.LINE)
	for index in range(3):
		var y := 108.0 + 64.0 * index
		var label := UI.label(panel, "", 26)
		UI.place(label, Rect2(38, y, 162, 38))
		_labels.append(label)
		var slider := HSlider.new()
		slider.max_value = 1.0
		slider.step = 0.01
		slider.value = GameSettings.volumes[index]
		panel.add_child(slider)
		UI.place(slider, Rect2(204, y + 7, 278, 32))
		var value := UI.label(panel, "%d%%" % roundi(slider.value * 100), 23, UI.MUTED)
		UI.place(value, Rect2(500, y, 66, 38))
		slider.value_changed.connect(_volume_changed.bind(index, value))
		if index == 2:
			slider.drag_ended.connect(_preview_sfx)
	_mute = CheckButton.new()
	_mute.add_theme_font_size_override("font_size", 26)
	_mute.button_pressed = GameSettings.muted
	_mute.toggled.connect(GameSettings.set_mute)
	panel.add_child(_mute)
	UI.place(_mute, Rect2(38, 302, 524, 44))
	_close = UI.button(panel, "", close, PixelButton.Variant.GOLD)
	UI.place(_close, Rect2(358, 372, 204, 52))
	Lang.language_changed.connect(_localize)
	_localize()
	hide()


func _localize(_code: String = "") -> void:
	_title.text = Lang.t("menu_options")
	var keys := ["audio_master", "audio_music", "audio_sfx"]
	for index in range(keys.size()):
		_labels[index].text = Lang.t(keys[index])
	_mute.text = Lang.t("audio_mute")
	_close.text = Lang.t("action_close")


func _volume_changed(volume: float, index: int, label: Label) -> void:
	GameSettings.set_volume(index, volume)
	label.text = "%d%%" % roundi(volume * 100)


func _preview_sfx(changed: bool) -> void:
	if changed:
		GameSettings.play_sound("step")


func close() -> void:
	GameSettings.save_audio()
	hide()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
