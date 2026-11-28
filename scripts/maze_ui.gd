extends RefCounted

const SCREEN := Vector2(1440, 900)
const TITLE_FONT := preload("res://assets/fonts/Silkscreen-Bold.ttf")
const BODY_FONT := preload("res://assets/fonts/VT323-Regular.ttf")
const ABYSS := Color("#0a0d17")
const PANEL := Color("#171e2e")
const LINE := Color("#354359")
const INK := Color("#f5e9d3")
const MUTED := Color("#aab9cb")
const GOLD := Color("#f4bf70")
const A := Color("#8bddff")
const B := Color("#bce88f")
const DANGER := Color("#ff9b9f")


static func label(parent: Node, value: String, font_size: int, color: Color = INK, title: bool = false) -> Label:
	var node := Label.new()
	node.text = value
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_override("font", TITLE_FONT if title else BODY_FONT)
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	parent.add_child(node)
	return node


static func place(node: Control, rect: Rect2) -> void:
	node.position = rect.position
	node.size = rect.size


static func box(parent: Node, rect: Rect2, color: Color, border: Color = Color.TRANSPARENT) -> Panel:
	var node := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	node.add_theme_stylebox_override("panel", style)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	place(node, rect)
	return node


static func button(parent: Node, value: String, action: Callable, variant: int = PixelButton.Variant.SLATE, font_size: int = 25) -> PixelButton:
	var node := PixelButton.new()
	node.text = value
	node.configure(variant, font_size, 2.0, false)
	node.pressed.connect(action)
	parent.add_child(node)
	return node


static func modal(parent: Node, rect: Rect2, border: Color = GOLD) -> Panel:
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.035, 0.058, 0.82)
	shade.size = SCREEN
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(shade)
	return box(shade, rect, PANEL, border)
