extends TextureRect

@export var high_texture: Texture2D
@export var medium_texture: Texture2D
@export var low_texture: Texture2D

@onready var _caption: Label = $Caption
@onready var _value: Label = $Value
@onready var _round: Label = $Round


func show_count(turns_left: int, round_number: int, waiting_for_roll: bool) -> void:
	_caption.text = Lang.t("turns_left")
	_round.text = Lang.t("round_number", [round_number])
	_value.text = "—" if waiting_for_roll else str(turns_left)
	if waiting_for_roll:
		texture = medium_texture
	elif turns_left >= 9:
		texture = high_texture
	elif turns_left >= 5:
		texture = medium_texture
	else:
		texture = low_texture
