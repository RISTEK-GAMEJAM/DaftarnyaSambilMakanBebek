extends Node2D

const Board = preload("res://scripts/labyrinth.gd")
const BoardOverlayScript = preload("res://scripts/board_overlay.gd")
const ELF_BOY_SCENE: PackedScene = preload("res://scenes/characters/elf_boy.tscn")
const ELF_GIRL_SCENE: PackedScene = preload("res://scenes/characters/elf_girl.tscn")
const TUTORIAL_SCENE: PackedScene = preload("res://scenes/ui/tutorial_overlay.tscn")
const MAIN_MENU_PATH := "res://scenes/ui/main_menu.tscn"
const FONT_TITLE: FontFile = preload("res://assets/fonts/Silkscreen-Bold.ttf")
const FONT_BODY: FontFile = preload("res://assets/fonts/VT323-Regular.ttf")

const ELF_TILE_OFFSET := Vector2(0.0, 4.0)
const SNATCHER_TILE_OFFSET := Vector2(0.0, 5.0)
const SNATCHER_DUEL_LIFT := Vector2(0.0, -14.0)
const STEP_DURATION_ELF := 0.16
const STEP_DURATION_SNATCHER := 0.19

const ACCENT_A := Color(0.54901963, 0.77254903, 1.0, 1.0)
const ACCENT_B := Color(0.6745098, 0.8862745, 0.6392157, 1.0)

@export var randomize_elves_on_start: bool = true
@export var randomize_labyrinths: bool = true
@export var duel_time_limit: float = 25.0

@onready var labirin_a: Node2D = $PanelA/Bidang/LabirinA
@onready var labirin_b: Node2D = $PanelB/Bidang/LabirinB
@onready var label_nama_a: Label = $PanelA/Nama
@onready var label_status_a: Label = $PanelA/JumlahPetak
@onready var label_nama_b: Label = $PanelB/Nama
@onready var label_status_b: Label = $PanelB/JumlahPetak

var _labyrinths: Array[Node2D] = []
var _tilemaps: Array[TileMapLayer] = []
var _overlays: Array[Node2D] = []
var _elves: Array[CharacterBody2D] = [null, null]
var _snatchers: Array[CharacterBody2D] = [null, null]

var _game: TwinLabyrinth = null
var _layouts: Array = []
var _boy_in_a: bool = true
var _die_for_a: int = 0
var _routes: Array = [[], []]
var _turn_started: bool = false
var _is_animating: bool = false
var _captured_lanes: Array[bool] = [false, false]
var _last_banner_key: String = ""
var _last_banner_lane: int = 0

# Runtime HUD controls (no Reset during active play; Play Again appears only on WON / LOST)
var _hud_status: Label
var _btn_roll: Button
var _btn_swap_dice: PixelSwapButton
var _btn_confirm: Button
var _btn_swap_elves: Button
var _btn_play_again: Button
var _btn_lang: PixelButton
var _btn_tutorial: Button
var _btn_menu: Button
var _tutorial_overlay: Control

# Bottom Dice Tray (Die A <- swap -> Die B)
var _die_a: PixelDie
var _die_b: PixelDie
var _die_a_home: Vector2 = Vector2(552.0, 795.0)
var _die_b_home: Vector2 = Vector2(824.0, 795.0)
var _lbl_dice_title_a: Label
var _lbl_dice_title_b: Label
var _lbl_echo_a: Label
var _lbl_echo_b: Label

# Game 24 Duel overlay panel
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
var _op_buttons: Dictionary = {}

# Game 24 active state
var _duel_active: bool = false
var _duel_time_left: float = 0.0
var _duel_initial_items: Array[Dictionary] = []
var _duel_items: Array[Dictionary] = []
var _duel_history: Array = []
var _selected_card_idx: int = -1
var _selected_op: String = ""


func _ready() -> void:
	randomize()
	_labyrinths = [labirin_a, labirin_b]
	_tilemaps = [
		labirin_a.get_node("Lantai") as TileMapLayer,
		labirin_b.get_node("Lantai") as TileMapLayer,
	]
	_snatchers = [
		labirin_a.get_node("Karakter/Snatcher") as CharacterBody2D,
		labirin_b.get_node("Karakter/Snatcher") as CharacterBody2D,
	]
	for s in _snatchers:
		s.set("control_enabled", false)

	if randomize_labyrinths:
		_generate_fresh_labyrinths()

	_layouts = [
		Board.build_layout_from_labyrinth(labirin_a),
		Board.build_layout_from_labyrinth(labirin_b),
	]

	_setup_overlays()
	_align_landmark_sprites()
	_build_hud()
	_build_dice_tray()
	_build_duel_panel()

	_tutorial_overlay = TUTORIAL_SCENE.instantiate() as Control
	_tutorial_overlay.visible = false
	_tutorial_overlay.z_index = 60
	add_child(_tutorial_overlay)

	_boy_in_a = (randi() % 2 == 0) if randomize_elves_on_start else true
	_spawn_elves_for_assignment()
	Lang.language_changed.connect(_on_language_changed)
	_start_new_match()


func _exit_tree() -> void:
	if Lang and Lang.language_changed.is_connected(_on_language_changed):
		Lang.language_changed.disconnect(_on_language_changed)


func _on_language_changed(_code: String) -> void:
	_apply_static_language()
	if _game != null:
		_refresh_ui()
		if _duel_active and _duel_panel.visible:
			var duel := _game.get_duel()
			if not duel.is_empty():
				var lane: int = duel["lane"]
				_duel_title.text = Lang.t("duel_title", [_lane_label(lane)])
			_update_duel_timer_label()


func _lane_label(lane: int) -> String:
	return Lang.t("lane_a" if lane == 0 else "lane_b")


func _apply_static_language() -> void:
	label_nama_a.text = _lane_label(0) + "  •  " + ("Elf Boy" if _boy_in_a else "Elf Girl")
	label_nama_b.text = _lane_label(1) + "  •  " + ("Elf Girl" if _boy_in_a else "Elf Boy")
	_btn_roll.text = Lang.t("btn_roll")
	_btn_swap_elves.text = Lang.t("btn_swap_elves")
	_btn_play_again.text = Lang.t("btn_play_again")
	_btn_lang.text = Lang.button_label()
	_btn_lang.tooltip_text = Lang.t("lang_tooltip")
	_btn_tutorial.tooltip_text = Lang.t("btn_tutorial_tip")
	_btn_menu.text = Lang.t("btn_menu")
	_btn_swap_dice.tooltip_text = Lang.t("btn_swap_dice_tip")
	_lbl_dice_title_a.text = Lang.t("dice_title_a")
	_lbl_dice_title_b.text = Lang.t("dice_title_b")
	_duel_hint_lbl.text = Lang.t("duel_hint")
	_btn_undo_24.text = Lang.t("btn_undo")
	_btn_clear_24.text = Lang.t("btn_reset_cards")
	_btn_giveup_24.text = Lang.t("btn_giveup")


func _process(delta: float) -> void:
	if _duel_active and not _is_animating and not (_tutorial_overlay and _tutorial_overlay.visible):
		_duel_time_left = maxf(0.0, _duel_time_left - delta)
		_update_duel_timer_label()
		if _duel_time_left <= 0.0:
			_conclude_duel_24(false, false, "")


func _generate_fresh_labyrinths() -> void:
	for lane in range(2):
		var data := LabyrinthGenerator.generate()
		LabyrinthGenerator.apply_to_labyrinth(_labyrinths[lane], data)


func _refresh_board_overlays_static() -> void:
	var accents := [ACCENT_A, ACCENT_B]
	for lane in range(2):
		if lane < _overlays.size():
			var safes := Board.find_all_tiles(lane, TwinLabyrinth.SAFE, _layouts)
			var exit_pos := Board.find_tile(lane, TwinLabyrinth.EXIT, _layouts)
			var lair_pos := Board.find_tile(lane, TwinLabyrinth.SPAWN, _layouts)
			_overlays[lane].call("configure_static", accents[lane], safes, exit_pos, lair_pos)


func _setup_overlays() -> void:
	var accents := [ACCENT_A, ACCENT_B]
	for lane in range(2):
		var overlay: Node2D = BoardOverlayScript.new()
		overlay.name = "BoardOverlay"
		overlay.z_index = 1
		_labyrinths[lane].add_child(overlay)
		var safes := Board.find_all_tiles(lane, TwinLabyrinth.SAFE, _layouts)
		var exit_pos := Board.find_tile(lane, TwinLabyrinth.EXIT, _layouts)
		var lair_pos := Board.find_tile(lane, TwinLabyrinth.SPAWN, _layouts)
		overlay.call("configure_static", accents[lane], safes, exit_pos, lair_pos)
		_overlays.append(overlay)


func _align_landmark_sprites() -> void:
	# Center SafeSpot & SpawnSnatcher sprites on junctions (perduaan/pertigaan/perempatan),
	# while keeping them slightly raised on horizontal corridors with a bottom brick lip.
	for lane in range(2):
		var penanda := _labyrinths[lane].get_node_or_null("Penanda")
		if penanda == null:
			continue
		var tm := _tilemaps[lane]
		for child in penanda.get_children():
			if not (child is Marker2D):
				continue
			var m_name := String(child.name)
			if not (m_name.begins_with("SafeSpot") or m_name == "SpawnSnatcher"):
				continue
			var spr := child.get_node_or_null("Sprite2D") as Sprite2D
			if spr == null:
				continue
			var cell := tm.local_to_map(tm.to_local(child.global_position))
			var open_up := Board.tile(lane, cell + Vector2i.UP, _layouts) != "#"
			var open_down := Board.tile(lane, cell + Vector2i.DOWN, _layouts) != "#"
			var open_left := Board.tile(lane, cell + Vector2i.LEFT, _layouts) != "#"
			var open_right := Board.tile(lane, cell + Vector2i.RIGHT, _layouts) != "#"
			var open_count := int(open_up) + int(open_down) + int(open_left) + int(open_right)
			var is_straight_horiz := open_left and open_right and (not open_up) and (not open_down)

			var ox := 0.0
			if open_left and not open_right:
				ox = -1.0
			elif open_right and not open_left:
				ox = 1.0

			var oy := -3.0
			if not is_straight_horiz and (open_down or open_count >= 3 or (open_up and open_down)):
				# Perduaan (terbuka bawah), pertigaan, perempatan, atau vertikal -> center!
				oy = 0.0 if open_down else -2.0
			spr.position = Vector2(ox, oy)


func _make_stylebox(bg: Color, border: Color, _radius: int = 0, border_w: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.border_width_left = border_w
	sb.border_width_top = border_w
	sb.border_width_right = border_w
	sb.border_width_bottom = border_w
	sb.corner_radius_top_left = 0
	sb.corner_radius_top_right = 0
	sb.corner_radius_bottom_right = 0
	sb.corner_radius_bottom_left = 0
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb


func _style_button(btn: Button, bg: Color, hover: Color, border: Color, font_sz: int = 22, border_w: int = 2) -> void:
	btn.add_theme_font_override("font", FONT_BODY)
	btn.add_theme_stylebox_override("normal", _make_stylebox(bg, border, 0, border_w))
	btn.add_theme_stylebox_override("hover", _make_stylebox(hover, border.lightened(0.22), 0, border_w))
	btn.add_theme_stylebox_override("pressed", _make_stylebox(bg.darkened(0.15), border, 0, border_w))
	btn.add_theme_stylebox_override("disabled", _make_stylebox(Color(0.10, 0.13, 0.13, 0.7), Color(0.18, 0.22, 0.22, 0.6), 0, 2))
	btn.add_theme_color_override("font_color", Color(0.96, 0.94, 0.88, 1.0))
	btn.add_theme_color_override("font_disabled_color", Color(0.48, 0.53, 0.52, 0.85))
	btn.add_theme_font_size_override("font_size", font_sz)
	btn.focus_mode = Control.FOCUS_NONE


func _build_hud() -> void:
	var hud := Control.new()
	hud.name = "HudBar"
	hud.z_index = 20
	hud.position = Vector2(615.0, 14.0)
	hud.size = Vector2(793.0, 84.0)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)

	_hud_status = Label.new()
	_hud_status.position = Vector2(0.0, 0.0)
	_hud_status.size = Vector2(793.0, 32.0)
	_hud_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hud_status.add_theme_font_override("font", FONT_BODY)
	_hud_status.add_theme_font_size_override("font_size", 24)
	_hud_status.add_theme_color_override("font_color", Color(0.956, 0.937, 0.875, 1.0))
	hud.add_child(_hud_status)

	var hbox := HBoxContainer.new()
	hbox.position = Vector2(0.0, 34.0)
	hbox.size = Vector2(793.0, 46.0)
	hbox.alignment = BoxContainer.ALIGNMENT_END
	hbox.add_theme_constant_override("separation", 10)
	hud.add_child(hbox)

	_btn_roll = PixelButton.new()
	_btn_roll.text = "Lempar Dadu"
	_btn_roll.custom_minimum_size = Vector2(138.0, 44.0)
	(_btn_roll as PixelButton).configure(PixelButton.Variant.EMERALD, 23, 2.0, true)
	_btn_roll.pressed.connect(_on_roll_pressed)
	hbox.add_child(_btn_roll)

	_btn_confirm = PixelButton.new()
	_btn_confirm.text = "Jalan!"
	_btn_confirm.custom_minimum_size = Vector2(104.0, 44.0)
	(_btn_confirm as PixelButton).configure(PixelButton.Variant.GOLD, 24, 2.0, true)
	_btn_confirm.pressed.connect(_on_confirm_pressed)
	hbox.add_child(_btn_confirm)

	_btn_swap_elves = PixelButton.new()
	_btn_swap_elves.text = "Tukar Elf"
	_btn_swap_elves.custom_minimum_size = Vector2(118.0, 44.0)
	(_btn_swap_elves as PixelButton).configure(PixelButton.Variant.SLATE, 23, 2.0, true)
	_btn_swap_elves.pressed.connect(_on_swap_elves_pressed)
	hbox.add_child(_btn_swap_elves)

	_btn_play_again = PixelButton.new()
	_btn_play_again.text = "Main Lagi"
	_btn_play_again.visible = false
	_btn_play_again.custom_minimum_size = Vector2(132.0, 44.0)
	(_btn_play_again as PixelButton).configure(PixelButton.Variant.GOLD, 24, 2.0, true)
	_btn_play_again.pressed.connect(_on_play_again_pressed)
	hbox.add_child(_btn_play_again)

	_btn_lang = PixelButton.new()
	_btn_lang.text = Lang.button_label()
	_btn_lang.tooltip_text = Lang.t("lang_tooltip")
	_btn_lang.custom_minimum_size = Vector2(64.0, 44.0)
	_btn_lang.configure(PixelButton.Variant.SLATE, 23, 2.0, false)
	_btn_lang.pressed.connect(_on_lang_pressed)
	hbox.add_child(_btn_lang)

	_btn_tutorial = PixelButton.new()
	_btn_tutorial.text = "?"
	_btn_tutorial.tooltip_text = "Cara Main (Tutorial)"
	_btn_tutorial.custom_minimum_size = Vector2(44.0, 44.0)
	(_btn_tutorial as PixelButton).configure(PixelButton.Variant.SLATE, 24, 2.0, false)
	_btn_tutorial.pressed.connect(_on_tutorial_pressed)
	hbox.add_child(_btn_tutorial)

	_btn_menu = PixelButton.new()
	_btn_menu.text = "Menu"
	_btn_menu.custom_minimum_size = Vector2(82.0, 44.0)
	(_btn_menu as PixelButton).configure(PixelButton.Variant.CRIMSON, 23, 2.0, false)
	_btn_menu.pressed.connect(_on_menu_pressed)
	hbox.add_child(_btn_menu)


func _build_dice_tray() -> void:
	var tray := Control.new()
	tray.name = "DiceTray"
	tray.z_index = 18
	tray.position = Vector2.ZERO
	tray.size = Vector2(1440.0, 900.0)
	tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tray)

	# Left Tray Panel (under Labirin A)
	var card_a := Panel.new()
	card_a.position = Vector2(32.0, 776.0)
	card_a.size = Vector2(616.0, 102.0)
	card_a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_a.add_theme_stylebox_override("panel", _make_stylebox(Color(0.11, 0.15, 0.15, 1.0), Color(0.24, 0.30, 0.29, 1.0), 0, 2))
	tray.add_child(card_a)

	_lbl_dice_title_a = Label.new()
	_lbl_dice_title_a.text = "DADU LABIRIN A"
	_lbl_dice_title_a.position = Vector2(24.0, 20.0)
	_lbl_dice_title_a.size = Vector2(460.0, 28.0)
	_lbl_dice_title_a.add_theme_font_override("font", FONT_TITLE)
	_lbl_dice_title_a.add_theme_font_size_override("font_size", 17)
	_lbl_dice_title_a.add_theme_color_override("font_color", ACCENT_A)
	card_a.add_child(_lbl_dice_title_a)

	_lbl_echo_a = Label.new()
	_lbl_echo_a.text = "Belum melempar dadu"
	_lbl_echo_a.position = Vector2(24.0, 52.0)
	_lbl_echo_a.size = Vector2(460.0, 32.0)
	_lbl_echo_a.add_theme_font_override("font", FONT_BODY)
	_lbl_echo_a.add_theme_font_size_override("font_size", 24)
	_lbl_echo_a.add_theme_color_override("font_color", Color(0.76, 0.80, 0.78, 1.0))
	card_a.add_child(_lbl_echo_a)

	# Right Tray Panel (under Labirin B)
	var card_b := Panel.new()
	card_b.position = Vector2(792.0, 776.0)
	card_b.size = Vector2(616.0, 102.0)
	card_b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_b.add_theme_stylebox_override("panel", _make_stylebox(Color(0.11, 0.15, 0.15, 1.0), Color(0.24, 0.30, 0.29, 1.0), 0, 2))
	tray.add_child(card_b)

	_lbl_dice_title_b = Label.new()
	_lbl_dice_title_b.text = "DADU LABIRIN B"
	_lbl_dice_title_b.position = Vector2(132.0, 20.0)
	_lbl_dice_title_b.size = Vector2(460.0, 28.0)
	_lbl_dice_title_b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lbl_dice_title_b.add_theme_font_override("font", FONT_TITLE)
	_lbl_dice_title_b.add_theme_font_size_override("font_size", 17)
	_lbl_dice_title_b.add_theme_color_override("font_color", ACCENT_B)
	card_b.add_child(_lbl_dice_title_b)

	_lbl_echo_b = Label.new()
	_lbl_echo_b.text = "Belum melempar dadu"
	_lbl_echo_b.position = Vector2(132.0, 52.0)
	_lbl_echo_b.size = Vector2(460.0, 32.0)
	_lbl_echo_b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lbl_echo_b.add_theme_font_override("font", FONT_BODY)
	_lbl_echo_b.add_theme_font_size_override("font_size", 24)
	_lbl_echo_b.add_theme_color_override("font_color", Color(0.76, 0.80, 0.78, 1.0))
	card_b.add_child(_lbl_echo_b)

	# Center Swap Arrow Button (<- / ->) right between Die A and Die B!
	_btn_swap_dice = PixelSwapButton.new()
	_btn_swap_dice.position = Vector2(666.0, 795.0)
	_btn_swap_dice.size = Vector2(108.0, 64.0)
	_btn_swap_dice.tooltip_text = "Tukar Dadu Labirin A & B (Tab)"
	_btn_swap_dice.configure(PixelButton.Variant.GOLD, 24, 3.0, false)
	_btn_swap_dice.pressed.connect(_on_swap_dice_pressed)
	tray.add_child(_btn_swap_dice)

	# Die A & Die B placed directly in tray so they can smoothly cross-slide when swapped!
	_die_a = PixelDie.new()
	_die_a.position = _die_a_home
	_die_a.size = Vector2(64.0, 64.0)
	_die_a.accent_color = ACCENT_A
	_die_a.value = 0
	tray.add_child(_die_a)

	_die_b = PixelDie.new()
	_die_b.position = _die_b_home
	_die_b.size = Vector2(64.0, 64.0)
	_die_b.accent_color = ACCENT_B
	_die_b.value = 0
	tray.add_child(_die_b)


func _build_duel_panel() -> void:
	_duel_panel = Panel.new()
	_duel_panel.name = "DuelPanel24"
	_duel_panel.z_index = 40
	_duel_panel.visible = false
	_duel_panel.size = Vector2(580.0, 390.0)
	_duel_panel.add_theme_stylebox_override(
		"panel",
		_make_stylebox(Color(0.08, 0.11, 0.12, 0.97), Color(0.80, 0.26, 0.38, 0.95), 14, 2)
	)
	add_child(_duel_panel)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(24.0, 18.0)
	vbox.size = Vector2(532.0, 354.0)
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


func _spawn_elves_for_assignment() -> void:
	var scenes: Array[PackedScene] = [
		ELF_BOY_SCENE if _boy_in_a else ELF_GIRL_SCENE,
		ELF_GIRL_SCENE if _boy_in_a else ELF_BOY_SCENE,
	]
	for lane in range(2):
		var container := _labyrinths[lane].get_node("Karakter") as Node2D
		var existing := container.get_node_or_null("Elf")
		if existing != null:
			container.remove_child(existing)
			existing.queue_free()

		var elf := scenes[lane].instantiate() as CharacterBody2D
		elf.name = "Elf"
		elf.set("behavior_mode", 4) # BOARD mode
		elf.set("default_facing_left", false)
		container.add_child(elf)
		_elves[lane] = elf

	label_nama_a.text = _lane_label(0) + "  •  " + ("Elf Boy" if _boy_in_a else "Elf Girl")
	label_nama_b.text = _lane_label(1) + "  •  " + ("Elf Girl" if _boy_in_a else "Elf Boy")


func _start_new_match() -> void:
	_is_animating = false
	_duel_active = false
	_turn_started = false
	_die_for_a = 0
	_routes = [[], []]
	_captured_lanes = [false, false]
	_last_banner_key = ""
	_duel_panel.visible = false

	for lane in range(2):
		if _snatchers[lane].has_method("release_target"):
			_snatchers[lane].call("release_target")

	_game = TwinLabyrinth.new(_layouts)
	var state := _game.get_state()
	var runners: Array = state["runners"]
	var snatchers: Array = state["snatchers"]
	for lane in range(2):
		var elf := _elves[lane]
		elf.rotation = 0.0
		elf.position = _cell_to_elf_pos(lane, runners[lane])
		if elf.has_method("set_captured"):
			elf.call("set_captured", false)
		if elf.has_method("set_facing_left"):
			elf.call("set_facing_left", false)

		var snatcher := _snatchers[lane]
		if snatcher.has_method("set_facing_right"):
			snatcher.call("set_facing_right", false)
		if snatcher.has_method("teleport_to_local"):
			snatcher.call("teleport_to_local", _cell_to_snatcher_pos(lane, snatchers[lane]))
		else:
			snatcher.position = _cell_to_snatcher_pos(lane, snatchers[lane])

	_apply_static_language()
	_refresh_ui()


func _cell_to_elf_pos(lane: int, cell: Vector2i) -> Vector2:
	return _tilemaps[lane].map_to_local(cell) + ELF_TILE_OFFSET


func _cell_to_snatcher_pos(lane: int, cell: Vector2i) -> Vector2:
	return _tilemaps[lane].map_to_local(cell) + SNATCHER_TILE_OFFSET


func _get_steps_for_lane(lane: int) -> int:
	var state := _game.get_state()
	var dice: Vector2i = state["dice"]
	if lane == 0:
		return dice[_die_for_a]
	return dice[1 - _die_for_a]


func _is_lane_route_complete(lane: int) -> bool:
	var state := _game.get_state()
	var escaped: Array = state["escaped"]
	var captured: Array = state["captured"]
	if escaped[lane] or captured[lane]:
		return true
	var route: Array = _routes[lane]
	if route.is_empty():
		return false
	var last_cell: Vector2i = route[route.size() - 1]
	if Board.tile(lane, last_cell, _layouts) == TwinLabyrinth.EXIT:
		return true
	return route.size() == _get_steps_for_lane(lane)


func _get_valid_next_cells(lane: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var state := _game.get_state()
	if state["phase"] != TwinLabyrinth.Phase.MOVE or _is_animating:
		return result
	var escaped: Array = state["escaped"]
	var captured: Array = state["captured"]
	if escaped[lane] or captured[lane] or _is_lane_route_complete(lane):
		return result

	var route: Array = _routes[lane]
	var tip: Vector2i = state["runners"][lane] if route.is_empty() else route[route.size() - 1]
	for dir in Board.DIRECTIONS:
		var nxt: Vector2i = tip + dir
		if Board.tile(lane, nxt, _layouts) != "#":
			result.append(nxt)
	return result


func _refresh_ui() -> void:
	var state := _game.get_state()
	var phase: int = state["phase"]
	var echo: Vector2i = state["echo_steps"]
	var runners: Array = state["runners"]
	var stun: Array = state["stun"]
	var escaped: Array = state["escaped"]
	var captured: Array = state["captured"]
	var lost_lane: int = state["lost_lane"]

	var match_over := (phase == TwinLabyrinth.Phase.WON or phase == TwinLabyrinth.Phase.LOST)
	var both_ready := (phase == TwinLabyrinth.Phase.MOVE) and _is_lane_route_complete(0) and _is_lane_route_complete(1)
	var no_free_runner: bool = (bool(escaped[0]) or bool(captured[0])) and (bool(escaped[1]) or bool(captured[1]))

	_btn_roll.visible = not match_over
	_btn_swap_dice.visible = true
	_btn_confirm.visible = not match_over
	_btn_swap_elves.visible = (not _turn_started) and (phase == TwinLabyrinth.Phase.ROLL)
	_btn_play_again.visible = match_over

	_btn_roll.disabled = _is_animating or phase != TwinLabyrinth.Phase.ROLL
	_btn_swap_dice.disabled = _is_animating or phase != TwinLabyrinth.Phase.MOVE or no_free_runner or match_over
	_btn_confirm.disabled = _is_animating or not both_ready
	_btn_confirm.text = Lang.t("btn_start_duel") if (phase == TwinLabyrinth.Phase.MOVE and no_free_runner) else Lang.t("btn_confirm")
	_btn_swap_elves.disabled = _is_animating or _turn_started
	_btn_play_again.disabled = _is_animating

	_sync_dice_tray(state)

	if phase == TwinLabyrinth.Phase.ROLL:
		if _last_banner_key != "":
			var banner_txt := Lang.t(_last_banner_key, [_lane_label(_last_banner_lane)])
			_hud_status.text = Lang.t("hud_roll_banner", [banner_txt])
		elif not _turn_started:
			_hud_status.text = Lang.t("hud_roll_first")
		else:
			_hud_status.text = Lang.t("hud_roll_next")
	elif phase == TwinLabyrinth.Phase.MOVE:
		if no_free_runner:
			_hud_status.text = Lang.t("hud_move_captured")
		else:
			_hud_status.text = Lang.t("hud_move_pick")
	elif phase == TwinLabyrinth.Phase.DUEL:
		var duel := _game.get_duel()
		var lane_name := _lane_label(int(duel.get("lane", 0)))
		_hud_status.text = Lang.t("hud_duel", [lane_name])
	elif phase == TwinLabyrinth.Phase.WON:
		_hud_status.text = Lang.t("hud_won")
	elif phase == TwinLabyrinth.Phase.LOST:
		_hud_status.text = Lang.t("hud_lost", [_lane_label(lost_lane)])

	var status_labels := [label_status_a, label_status_b]
	for lane in range(2):
		var lbl: Label = status_labels[lane]
		if escaped[lane]:
			lbl.text = Lang.t("status_escaped")
		elif captured[lane]:
			lbl.text = Lang.t("status_captured")
		elif phase == TwinLabyrinth.Phase.MOVE:
			var route: Array = _routes[lane]
			var budget := _get_steps_for_lane(lane)
			if _is_lane_route_complete(lane):
				lbl.text = Lang.t("status_ready", [route.size(), budget])
			else:
				lbl.text = Lang.t("status_steps", [route.size(), budget])
		elif stun[lane] > 0:
			lbl.text = Lang.t("status_stun", [int(stun[lane])])
		else:
			var count := _tilemaps[lane].get_used_cells().size()
			lbl.text = Lang.t("status_tiles", [count])

		var typed_route: Array[Vector2i] = []
		for c in _routes[lane]:
			typed_route.append(c)
		var next_valid := _get_valid_next_cells(lane)
		_overlays[lane].call("update_dynamic", runners[lane], typed_route, next_valid, phase == TwinLabyrinth.Phase.MOVE and not _is_animating)


func _unhandled_input(event: InputEvent) -> void:
	if _tutorial_overlay and _tutorial_overlay.visible:
		return
	if _is_animating or _game == null:
		return
	var state := _game.get_state()
	var phase: int = state["phase"]

	if event is InputEventKey and event.pressed and not event.echo:
		var key_ev := event as InputEventKey
		if phase == TwinLabyrinth.Phase.DUEL and _duel_active:
			if key_ev.keycode == KEY_BACKSPACE:
				_on_undo_24_pressed()
			elif key_ev.keycode == KEY_R:
				_on_clear_24_pressed()
			return
		if key_ev.keycode == KEY_SPACE or key_ev.keycode == KEY_ENTER:
			if phase == TwinLabyrinth.Phase.ROLL:
				_on_roll_pressed()
			elif phase == TwinLabyrinth.Phase.MOVE and not _btn_confirm.disabled:
				_on_confirm_pressed()
		elif key_ev.keycode == KEY_TAB and phase == TwinLabyrinth.Phase.MOVE and not _btn_swap_dice.disabled:
			_on_swap_dice_pressed()
		return

	if phase != TwinLabyrinth.Phase.MOVE:
		return

	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT and mb.button_index != MOUSE_BUTTON_RIGHT:
			return
		for lane in range(2):
			var tm := _tilemaps[lane]
			var local_pos := tm.to_local(mb.position)
			var cell := tm.local_to_map(local_pos)
			if Board.tile(lane, cell, _layouts) == "#":
				continue
			if mb.button_index == MOUSE_BUTTON_RIGHT:
				var route_r: Array = _routes[lane]
				if not route_r.is_empty():
					route_r.pop_back()
					_refresh_ui()
			else:
				_handle_tile_click(lane, cell)
			get_viewport().set_input_as_handled()
			return


func _handle_tile_click(lane: int, cell: Vector2i) -> void:
	var state := _game.get_state()
	if state["escaped"][lane] or state["captured"][lane]:
		return

	var route: Array = _routes[lane]
	var budget := _get_steps_for_lane(lane)
	var runner_cell: Vector2i = state["runners"][lane]

	if not route.is_empty() and route[route.size() - 1] == cell:
		route.pop_back()
		_refresh_ui()
		return

	if cell == runner_cell and not route.is_empty():
		route.clear()
		_refresh_ui()
		return

	if _is_lane_route_complete(lane):
		return

	var tip: Vector2i = runner_cell if route.is_empty() else route[route.size() - 1]
	var remaining := budget - route.size()
	if remaining <= 0:
		return

	if tip.distance_squared_to(cell) == 1:
		route.append(cell)
		_refresh_ui()
		return

	var path := Board.shortest_path(lane, tip, cell, _layouts)
	if not path.is_empty() and path.size() <= remaining:
		for step_idx in range(path.size()):
			var step_cell := path[step_idx]
			route.append(step_cell)
			if Board.tile(lane, step_cell, _layouts) == TwinLabyrinth.EXIT:
				break
		_refresh_ui()


func _sync_dice_tray(state: Dictionary) -> void:
	if _die_a == null or _die_b == null:
		return
	var phase: int = state["phase"]
	var dice: Vector2i = state["dice"]
	var echo: Vector2i = state["echo_steps"]
	var stun: Array = state["stun"]
	var escaped: Array = state["escaped"]
	var captured: Array = state["captured"]

	var has_rolled := (dice != Vector2i.ZERO) and (phase != TwinLabyrinth.Phase.ROLL or _turn_started)
	var val_a := dice[_die_for_a] if has_rolled else 0
	var val_b := dice[1 - _die_for_a] if has_rolled else 0

	if not _is_animating:
		_die_a.position = _die_a_home
		_die_b.position = _die_b_home
		_die_a.rotation = 0.0
		_die_b.rotation = 0.0
		_die_a.scale = Vector2.ONE
		_die_b.scale = Vector2.ONE
		_die_a.value = val_a
		_die_b.value = val_b

	var in_move := (phase == TwinLabyrinth.Phase.MOVE)
	_die_a.dimmed = (not in_move) or bool(escaped[0]) or bool(captured[0])
	_die_b.dimmed = (not in_move) or bool(escaped[1]) or bool(captured[1])

	var echo_labels := [_lbl_echo_a, _lbl_echo_b]
	var vals := [val_a, val_b]
	var echoes := [echo.x, echo.y]
	for lane in range(2):
		var lbl: Label = echo_labels[lane]
		var name_short := "A" if lane == 0 else "B"
		if bool(escaped[lane]):
			lbl.text = Lang.t("tray_escaped", [name_short])
		elif bool(captured[lane]):
			lbl.text = Lang.t("tray_captured", [name_short])
		elif not has_rolled or phase == TwinLabyrinth.Phase.ROLL:
			if int(stun[lane]) > 0:
				lbl.text = Lang.t("tray_stun", [name_short, int(stun[lane])])
			else:
				lbl.text = Lang.t("tray_wait_roll")
		else:
			var sn_txt := Lang.t("tray_snatcher_stun", [name_short]) if int(stun[lane]) > 0 else Lang.t("tray_snatcher_echo", [name_short, int(echoes[lane])])
			lbl.text = Lang.t("tray_move_info", [int(vals[lane]), sn_txt])


func _on_roll_pressed() -> void:
	if _is_animating:
		return
	if _game.roll_dice():
		_turn_started = true
		_die_for_a = 0
		_routes = [[], []]
		_last_banner_key = ""
		_animate_dice_roll()


func _animate_dice_roll() -> void:
	_is_animating = true
	_refresh_ui()
	var dice: Vector2i = _game.get_state()["dice"]
	var val_a := dice[_die_for_a]
	var val_b := dice[1 - _die_for_a]
	_die_a.dimmed = false
	_die_b.dimmed = false

	var done := [false, false]
	_run_die_roll_task(_die_a, val_a, done, 0)
	_run_die_roll_task(_die_b, val_b, done, 1)
	while not (done[0] and done[1]):
		await get_tree().process_frame

	_is_animating = false
	_refresh_ui()


func _run_die_roll_task(die: PixelDie, target_val: int, done_flags: Array, idx: int) -> void:
	await die.play_roll_animation(target_val)
	done_flags[idx] = true


func _on_swap_dice_pressed() -> void:
	if _is_animating:
		return
	var state := _game.get_state()
	if state["phase"] != TwinLabyrinth.Phase.MOVE:
		return
	_animate_dice_swap()


func _animate_dice_swap() -> void:
	_is_animating = true
	_routes = [[], []]
	_refresh_ui()

	var tw := create_tween().set_parallel(true)
	tw.tween_property(_die_a, "position:x", _die_b_home.x, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_die_b, "position:x", _die_a_home.x, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	# Subtle opposing vertical arcs while crossing over
	var arc_a := create_tween()
	arc_a.tween_property(_die_a, "position:y", _die_a_home.y - 16.0, 0.11).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	arc_a.tween_property(_die_a, "position:y", _die_a_home.y, 0.11).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	var arc_b := create_tween()
	arc_b.tween_property(_die_b, "position:y", _die_b_home.y + 12.0, 0.11).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	arc_b.tween_property(_die_b, "position:y", _die_b_home.y, 0.11).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw.finished

	_die_for_a = 1 - _die_for_a
	_die_a.position = _die_a_home
	_die_b.position = _die_b_home
	_is_animating = false
	_refresh_ui()


func _on_swap_elves_pressed() -> void:
	if _is_animating or _turn_started:
		return
	_boy_in_a = not _boy_in_a
	_spawn_elves_for_assignment()
	_start_new_match()


func _on_play_again_pressed() -> void:
	if _is_animating:
		return
	if randomize_labyrinths:
		_generate_fresh_labyrinths()
		_layouts = [
			Board.build_layout_from_labyrinth(labirin_a),
			Board.build_layout_from_labyrinth(labirin_b),
		]
		_align_landmark_sprites()
		_refresh_board_overlays_static()
	if randomize_elves_on_start:
		_boy_in_a = (randi() % 2 == 0)
		_spawn_elves_for_assignment()
	_start_new_match()


func _on_tutorial_pressed() -> void:
	if _tutorial_overlay:
		_tutorial_overlay.visible = not _tutorial_overlay.visible


func _on_lang_pressed() -> void:
	Lang.toggle()


func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_PATH)


func _on_confirm_pressed() -> void:
	if _is_animating:
		return
	var route_a: Array[Vector2i] = []
	for c in _routes[0]:
		route_a.append(c)
	var route_b: Array[Vector2i] = []
	for c in _routes[1]:
		route_b.append(c)

	if not _game.move_runners(_die_for_a, route_a, route_b):
		return

	_is_animating = true
	_routes = [[], []]
	_refresh_ui()
	_execute_move_sequence(route_a, route_b)


func _animate_elf_path(lane: int, path: Array[Vector2i]) -> void:
	var elf := _elves[lane]
	for cell in path:
		var target_pos := _cell_to_elf_pos(lane, cell)
		var dx := target_pos.x - elf.position.x
		if elf.has_method("set_board_motion"):
			elf.call("set_board_motion", true, dx)
		var tw := create_tween()
		tw.tween_property(elf, "position", target_pos, STEP_DURATION_ELF).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await tw.finished
	if elf.has_method("set_board_motion"):
		elf.call("set_board_motion", false, 0.0)


func _animate_snatcher_path(lane: int, path: Array[Vector2i], extra_offset: Vector2 = Vector2.ZERO) -> void:
	var snatcher := _snatchers[lane]
	for cell in path:
		var target_pos := _cell_to_snatcher_pos(lane, cell) + extra_offset
		var tw := create_tween()
		tw.tween_property(snatcher, "position", target_pos, STEP_DURATION_SNATCHER).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await tw.finished


func _execute_move_sequence(route_a: Array[Vector2i], route_b: Array[Vector2i]) -> void:
	var state := _game.get_state()
	var snatcher_paths: Array = state["last_snatcher_paths"]

	# 1. Move free Elves step-by-step in parallel
	var elf_done := [false, false]
	_run_elf_lane_task(0, route_a, elf_done)
	_run_elf_lane_task(1, route_b, elf_done)
	while not (elf_done[0] and elf_done[1]):
		await get_tree().process_frame

	# 2. Move Snatchers step-by-step in parallel
	var path_sa: Array[Vector2i] = []
	for c in snatcher_paths[0]:
		path_sa.append(c)
	var path_sb: Array[Vector2i] = []
	for c in snatcher_paths[1]:
		path_sb.append(c)

	var sn_done := [false, false]
	_run_snatcher_lane_task(0, path_sa, sn_done)
	_run_snatcher_lane_task(1, path_sb, sn_done)
	while not (sn_done[0] and sn_done[1]):
		await get_tree().process_frame

	# 3. If a Duel is pending, capture Elf (if not already carried) & open Game 24 UI
	var cur_state := _game.get_state()
	if cur_state["phase"] == TwinLabyrinth.Phase.DUEL:
		await _begin_active_duel()
	else:
		_is_animating = false
		_refresh_ui()


func _run_elf_lane_task(lane: int, path: Array[Vector2i], done_flags: Array) -> void:
	if not path.is_empty():
		await _animate_elf_path(lane, path)
	done_flags[lane] = true


func _run_snatcher_lane_task(lane: int, path: Array[Vector2i], done_flags: Array) -> void:
	if not path.is_empty():
		await _animate_snatcher_path(lane, path)
	done_flags[lane] = true


func _begin_active_duel() -> void:
	var duel := _game.get_duel()
	if duel.is_empty():
		_is_animating = false
		_refresh_ui()
		return

	var lane: int = duel["lane"]
	var snatcher := _snatchers[lane]
	var elf := _elves[lane]
	var state := _game.get_state()
	var tile_cell: Vector2i = state["snatchers"][lane]

	# Only lift & strike if Elf isn't already carried from a previous lost duel!
	if not _captured_lanes[lane]:
		var hover_pos := _cell_to_snatcher_pos(lane, tile_cell) + SNATCHER_DUEL_LIFT
		var lift_tw := create_tween()
		lift_tw.tween_property(snatcher, "position", hover_pos, 0.16).set_trans(Tween.TRANS_SINE)
		await lift_tw.finished

		if snatcher.has_method("grab_target"):
			snatcher.call("grab_target", elf)
		_captured_lanes[lane] = true
		await get_tree().create_timer(0.28).timeout

	_open_game_24(duel)
	_is_animating = false
	_refresh_ui()


# --- Game 24 Interactive Duel UI ---

func _open_game_24(duel: Dictionary) -> void:
	var lane: int = duel["lane"]
	# Show panel on the OPPOSITE labyrinth so the tail-wrapped Elf remains 100% visible!
	_duel_panel.position = Vector2(782.0, 210.0) if lane == 0 else Vector2(78.0, 210.0)
	_duel_panel.visible = true
	_duel_title.text = Lang.t("duel_title", [_lane_label(lane)])

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
	_duel_status_lbl.text = Lang.t("duel_prompt_start")
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
		_duel_status_lbl.text = Lang.t("duel_pick_op", [TwinLabyrinth.rat_format(_duel_items[idx]["rat"])])
		_rebuild_card_buttons()
		return

	if _selected_card_idx == idx:
		_selected_card_idx = -1
		_selected_op = ""
		_duel_status_lbl.text = Lang.t("duel_cancel")
		_rebuild_card_buttons()
		_refresh_op_buttons()
		return

	if _selected_op == "":
		_selected_card_idx = idx
		_duel_status_lbl.text = Lang.t("duel_pick_op", [TwinLabyrinth.rat_format(_duel_items[idx]["rat"])])
		_rebuild_card_buttons()
		return

	# Combine _selected_card_idx (_selected_op) idx!
	var a_item: Dictionary = _duel_items[_selected_card_idx]
	var b_item: Dictionary = _duel_items[idx]
	var a_rat: Vector2i = a_item["rat"]
	var b_rat: Vector2i = b_item["rat"]

	var res_rat := TwinLabyrinth.rat_apply(a_rat, b_rat, _selected_op)
	if res_rat.y == 0:
		_duel_status_lbl.text = Lang.t("duel_div_zero")
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
			_duel_status_lbl.text = Lang.t("duel_not_24", [res_expr, res_str])
	else:
		_duel_status_lbl.text = Lang.t("duel_continue", [res_expr, res_str])


func _on_op_pressed(op: String) -> void:
	if not _duel_active:
		return
	if _selected_card_idx == -1:
		_duel_status_lbl.text = Lang.t("duel_pick_first")
		return
	_selected_op = op
	_duel_status_lbl.text = Lang.t("duel_pick_second", [TwinLabyrinth.rat_format(_duel_items[_selected_card_idx]["rat"]), op])
	_refresh_op_buttons()


func _on_undo_24_pressed() -> void:
	if not _duel_active or _duel_history.is_empty():
		return
	_duel_items = _duel_history.pop_back()
	_selected_card_idx = -1
	_selected_op = ""
	_duel_status_lbl.text = Lang.t("duel_undone")
	_rebuild_card_buttons()
	_refresh_op_buttons()


func _on_clear_24_pressed() -> void:
	if not _duel_active or _duel_history.is_empty():
		return
	_duel_items = _duel_initial_items.duplicate(true)
	_duel_history.clear()
	_selected_card_idx = -1
	_selected_op = ""
	_duel_status_lbl.text = Lang.t("duel_cleared")
	_rebuild_card_buttons()
	_refresh_op_buttons()


func _on_giveup_24_pressed() -> void:
	if not _duel_active:
		return
	_conclude_duel_24(false, false, "")


func _conclude_duel_24(won: bool, fast_bonus: bool, player_expr: String) -> void:
	if not _duel_active:
		return
	_duel_active = false
	_is_animating = true
	_set_duel_controls_enabled(false)
	_rebuild_card_buttons()

	var prev_count: int = _game.get_state()["duel_results"].size()
	if not _game.resolve_duel_24(won, fast_bonus, player_expr):
		_is_animating = false
		return

	var results: Array = _game.get_state()["duel_results"]
	var new_results := results.slice(prev_count)
	_finish_duel_sequence(new_results)


func _finish_duel_sequence(new_results: Array) -> void:
	for res in new_results:
		var lane: int = res["lane"]
		var outcome: String = res["outcome"]
		var hint: String = String(res.get("solution_hint", ""))
		var expr: String = String(res.get("player_expr", ""))
		var is_game_over: bool = bool(res.get("game_over", false))
		_last_banner_lane = lane

		if outcome == "fast_win":
			_duel_status_lbl.text = Lang.t("res_fast_win", [expr])
			_last_banner_key = "banner_fast_win"
		elif outcome == "win":
			_duel_status_lbl.text = Lang.t("res_win", [expr])
			_last_banner_key = "banner_win"
		else:
			if is_game_over:
				_duel_status_lbl.text = Lang.t("res_loss_gameover", [hint])
				_last_banner_key = "banner_gameover"
			else:
				_duel_status_lbl.text = Lang.t("res_loss_drag", [hint])
				_last_banner_key = "banner_loss"

		await get_tree().create_timer(1.35).timeout
		_duel_panel.visible = false
		await _animate_duel_resolution(res)

	var cur_state := _game.get_state()
	if cur_state["phase"] == TwinLabyrinth.Phase.DUEL:
		await _begin_active_duel()
	else:
		_is_animating = false
		_refresh_ui()


func _animate_duel_resolution(res: Dictionary) -> void:
	var lane: int = res["lane"]
	var outcome: String = res["outcome"]
	var snatcher := _snatchers[lane]
	var elf := _elves[lane]
	var state := _game.get_state()

	var runner_path: Array[Vector2i] = []
	for c in res.get("runner_path", []):
		runner_path.append(c)

	if outcome == "loss":
		# LOSS: Elf stays wrapped in Snatcher's tail (NEVER released!) while Snatcher drags them toward SpawnSnatcher!
		if not _captured_lanes[lane] and snatcher.has_method("grab_target"):
			snatcher.call("grab_target", elf)
			_captured_lanes[lane] = true
			await get_tree().create_timer(0.22).timeout

		if not runner_path.is_empty():
			await _animate_snatcher_path(lane, runner_path, SNATCHER_DUEL_LIFT)
	else:
		# WIN / FAST_WIN: Release Elf from Snatcher's tail and dash toward Exit!
		if snatcher.has_method("release_target"):
			snatcher.call("release_target")
		_captured_lanes[lane] = false

		var sn_final := _cell_to_snatcher_pos(lane, state["snatchers"][lane])
		var sn_tw := create_tween()
		sn_tw.tween_property(snatcher, "position", sn_final, 0.18).set_trans(Tween.TRANS_SINE)

		if not runner_path.is_empty():
			await _animate_elf_path(lane, runner_path)
		else:
			var elf_final := _cell_to_elf_pos(lane, state["runners"][lane])
			var e_tw := create_tween()
			e_tw.tween_property(elf, "position", elf_final, 0.16).set_trans(Tween.TRANS_SINE)
			await e_tw.finished
