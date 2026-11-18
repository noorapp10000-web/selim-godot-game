extends Node2D
# Friendly people of Egypt who give hints with speech bubbles.

var level: Node = null
var npc_name := ""
var sheet := "npc"
var lines: Array = []
var idx := 0
var timer := 0.0
var bubble: PanelContainer
var label: Label
var sprite: AnimatedSprite2D
var near := false
var hold := 4.2

func _ready() -> void:
	sprite = Game.char_sprite(self, sheet, Game.NPC_ANIMS, Game.NPC_GRID)
	sprite.flip_h = true
	sprite.play("idle")
	sprite.frame = randi() % 4
	z_index = -1
	bubble = Game.make_bubble(false)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", -2)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.add_child(vb)
	var nm := Label.new()
	nm.text = npc_name
	nm.add_theme_font_size_override("font_size", 8)
	nm.add_theme_font_override("font", Game.font_callig)
	nm.add_theme_color_override("font_color", Color(0.62, 0.2, 0.06))
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vb.add_child(nm)
	label = Label.new()
	label.add_theme_font_override("font", Game.font_body)
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", Color(0.17, 0.08, 0.04))
	label.add_theme_constant_override("line_spacing", -2)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(118, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vb.add_child(label)
	bubble.visible = false
	bubble.z_index = 40
	add_child(bubble)

func _process(delta: float) -> void:
	if level == null or level.player == null:
		return
	var p = level.player
	var d: float = p.global_position.x - global_position.x
	sprite.flip_h = d < 0
	var is_near := absf(d) < 70 and absf(p.global_position.y - global_position.y) < 60
	if is_near and not near:
		near = true
		timer = 0.0
		_show()
	elif not is_near and near:
		near = false
		bubble.visible = false
		idx = (idx + 1) % maxi(1, lines.size())
		if Voice.world_owner == self:
			Voice.stop_world()
	if near and Game.dialog_open:
		bubble.visible = false
		timer = 0.0
		return
	if near:
		if not bubble.visible and not lines.is_empty():
			_show()
		var camera: Camera2D = p.camera
		var half_width := get_viewport_rect().size.x / camera.zoom.x / 2.0
		var left := camera.get_screen_center_position().x - half_width + 8.0
		var right := camera.get_screen_center_position().x + half_width - 8.0
		bubble.position.x = clampf(global_position.x - bubble.size.x / 2.0, left, right - bubble.size.x) - global_position.x
		var top := camera.get_screen_center_position().y - get_viewport_rect().size.y / camera.zoom.y / 2.0 + 34.0
		bubble.position.y = maxf(-50.0 - bubble.size.y, top - global_position.y)
		Game.bubble_tail(bubble, -bubble.position.x)
		timer += delta
		if timer > hold and lines.size() > 1:
			timer = 0.0
			idx = (idx + 1) % lines.size()
			_show()

func _show() -> void:
	if lines.is_empty() or Game.dialog_open:
		return
	label.text = lines[idx]
	bubble.visible = true
	# spoken hint: the bubble stays up until the line has been said
	var vl := Voice.play_world("npc:" + npc_name, lines[idx])
	if vl > 0.0:
		Voice.world_owner = self
	hold = maxf(4.2, vl + 1.0)
	bubble.reset_size()
	await get_tree().process_frame
	if is_instance_valid(bubble):
		bubble.position = Vector2(-bubble.size.x / 2.0, -50 - bubble.size.y)
		Game.bubble_tail(bubble, -bubble.position.x)
		bubble.pivot_offset = Vector2(bubble.size.x / 2.0, bubble.size.y)
		bubble.scale = Vector2(0.6, 0.6)
		bubble.create_tween().tween_property(bubble, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		Audio.sfx("blip", 0.1, -6)
