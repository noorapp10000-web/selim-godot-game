extends Control
# Multi-touch phone controls.
#  * Fixed left/right arrows with independent multitouch actions.
#  * Right side: big JUMP / ATTACK / DASH buttons; you can slide your thumb from one button to another.
#  * Top-right row: weapon / potion / smoke-bomb (tap only, with item counts), then pause.
#    They sit far from the thumb zone so sliding between JUMP / ATTACK / DASH never fires an item.
# Drives the regular input actions (move_left / move_right / jump / attack / dash) so gameplay code
# stays the same for keyboard, gamepad and touch.

var hud: Node = null
var buttons := {}
var held := {}
var pause_rect := Rect2()
var pause_icon: TextureRect
const UTILITY := ["weapon", "potion", "bomb"]
const UTIL_SIZE := 46.0
const UTIL_GAP := 12.0
# v10: bigger left / right arrows with a clear gap between them (and a touch area a bit larger than the art)
const ARROW_SIZE := 88.0
const ARROW_GAP := 18.0
var badges := {}
var weapon_icon: TextureRect

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = Game.touch_enabled()
	for d in [["move_left", "btn_left", ARROW_SIZE], ["move_right", "btn_right", ARROW_SIZE], ["jump", "btn_jump", 82.0], ["attack", "btn_attack", 76.0], ["dash", "btn_dash", 60.0], ["potion", "btn_potion", UTIL_SIZE], ["bomb", "btn_bomb", UTIL_SIZE], ["weapon", "btn_weapon", UTIL_SIZE]]:
		var n := _tex(d[1], Vector2(d[2], d[2]))
		var r: float = d[2] / 2.0
		if d[0] in ["move_left", "move_right"]:
			r = (ARROW_SIZE + ARROW_GAP) / 2.0
		buttons[d[0]] = {"node": n, "center": Vector2.ZERO, "radius": r}
	pause_icon = _tex("btn_pause", Vector2(40, 40))
	for a in ["potion", "bomb"]:
		var l := Game.make_label("0", 11, Color(1, 0.95, 0.8), true)
		l.add_theme_constant_override("outline_size", 4)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size = Vector2(20, 14)
		l.position = Vector2(UTIL_SIZE - 18, UTIL_SIZE - 14)
		(buttons[a]["node"] as TextureRect).add_child(l)
		badges[a] = l
	weapon_icon = TextureRect.new()
	weapon_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	weapon_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	weapon_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	weapon_icon.size = Vector2(22, 22)
	weapon_icon.position = Vector2(UTIL_SIZE - 20, -4)
	weapon_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	(buttons["weapon"]["node"] as TextureRect).add_child(weapon_icon)
	update_counts()

# Item counts on the potion / bomb buttons; empty ones dim. Weapon button shows the equipped weapon.
func update_counts() -> void:
	for a in badges:
		var n := int(Game.inventory.get(a, 0))
		(badges[a] as Label).text = str(n)
		var node: TextureRect = buttons[a]["node"]
		if not held.values().has(a):
			node.modulate = Color(1, 1, 1, 0.85) if n > 0 else Color(0.6, 0.6, 0.6, 0.5)
	var at := AtlasTexture.new()
	at.atlas = load("res://assets/ui/shop_icons_v2.png")
	at.region = Rect2(int(Game.Catalog.ITEMS[Game.equipped]["icon"]) * 128, 0, 128, 128)
	weapon_icon.texture = at
	var wnode: TextureRect = buttons["weapon"]["node"]
	wnode.visible = Game.can_switch()

func _tex(name: String, sz: Vector2) -> TextureRect:
	var tr := TextureRect.new()
	# v7 hi-res enamel + gold buttons (256px source, drawn smoothly with mipmaps on any screen)
	# v8: flat dark glass circles with a cream glyph (one calm set for every button)
	var v8 := "res://assets/ui/v8/tb_%s.png" % name.trim_prefix("btn_")
	var v7 := "res://assets/ui/v7/tb_%s.png" % name.trim_prefix("btn_")
	if ResourceLoader.exists(v8):
		tr.texture = load(v8)
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	elif ResourceLoader.exists(v7):
		tr.texture = load(v7)
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	else:
		tr.texture = load(("res://assets/sprites/%s.png" if name in ["btn_left", "btn_right"] else "res://assets/ui/%s.png") % name)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.size = sz
	tr.custom_minimum_size = sz
	tr.pivot_offset = sz / 2.0
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.modulate = Color(1, 1, 1, 0.85)
	add_child(tr)
	return tr

func layout(s: Vector2, m: float) -> void:
	var ay := s.y - ARROW_SIZE / 2.0 - 14.0 - Game.safe_inset().w
	_set_btn("move_left", Vector2(m + 8.0 + ARROW_SIZE / 2.0, ay))
	_set_btn("move_right", Vector2(m + 8.0 + ARROW_SIZE * 1.5 + ARROW_GAP, ay))
	_set_btn("jump", Vector2(s.x - m - 44.0, s.y - 100.0))
	_set_btn("attack", Vector2(s.x - m - 128.0, s.y - 49.0))
	_set_btn("dash", Vector2(s.x - m - 132.0, s.y - 130.0))
	var top := 8.0 + Game.safe_inset().y
	pause_icon.position = Vector2(s.x - m - 44.0, top)
	pause_rect = Rect2(pause_icon.position - Vector2(12, 8), Vector2(64, 56))
	# utility row, right-to-left from the pause button
	var cy := top + 20.0
	var x := pause_rect.position.x - UTIL_GAP - UTIL_SIZE / 2.0
	for a in UTILITY:
		_set_btn(a, Vector2(x, cy))
		x -= UTIL_SIZE + UTIL_GAP

func _set_btn(a: String, c: Vector2) -> void:
	var b: Dictionary = buttons[a]
	b["center"] = c
	(b["node"] as TextureRect).position = c - (b["node"] as TextureRect).size / 2.0

func _blocked() -> bool:
	if not visible or get_tree().paused:
		return true
	if hud != null and hud.dialog_active:
		return true
	return false

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var pos: Vector2 = event.position
		if event.pressed:
			if pause_rect.has_point(pos):
				if hud != null and not hud.dialog_active:
					hud.toggle_pause()
				get_viewport().set_input_as_handled()
				return
			if _blocked():
				return
			var a := _button_at(pos)
			if a != "":
				_press(event.index, a)
				get_viewport().set_input_as_handled()
		else:
			if held.has(event.index):
				_release(event.index)
	elif event is InputEventScreenDrag:
		if held.has(event.index):
			var a := _button_at(event.position)
			if a in UTILITY:
				a = ""
			if held[event.index] in UTILITY:
				return
			if a != held[event.index]:
				_release(event.index)
				if a != "":
					_press(event.index, a)

func _button_at(p: Vector2) -> String:
	var best := ""
	var bd := 1e9
	for a in buttons:
		var b: Dictionary = buttons[a]
		if not (b["node"] as TextureRect).visible:
			continue
		var d: float = p.distance_to(b["center"])
		if d < b["radius"] and d < bd:
			bd = d
			best = a
	return best

func _press(idx: int, a: String) -> void:
	held[idx] = a
	Input.action_press(a)
	var n: TextureRect = buttons[a]["node"]
	n.scale = Vector2(0.9, 0.9)
	n.modulate = Color(1.15, 1.1, 1.0, 1.0)

func _release(idx: int) -> void:
	var a: String = held[idx]
	held.erase(idx)
	if not a in held.values():
		Input.action_release(a)
		var n: TextureRect = buttons[a]["node"]
		n.scale = Vector2.ONE
		n.modulate = Color(1, 1, 1, 0.85)
		if a in badges:
			update_counts()

func release_all() -> void:
	for idx in held.keys():
		_release(idx)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		release_all()
