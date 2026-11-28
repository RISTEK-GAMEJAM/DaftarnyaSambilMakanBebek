extends Node2D

@onready var elf_boy: CharacterBody2D = $ElfBoy
@onready var elf_girl: CharacterBody2D = $ElfGirl


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_1:
			elf_boy.behavior_mode = 0
			elf_girl.behavior_mode = 0
		KEY_2:
			elf_boy.behavior_mode = 1
			elf_girl.behavior_mode = 1
		KEY_3:
			elf_boy.behavior_mode = 3
			elf_girl.behavior_mode = 3
