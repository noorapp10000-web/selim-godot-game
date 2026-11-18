extends Control
# v9 dialog box shared by story cutscenes and in-level conversations.
# Ornamented night-glass panel, big framed portrait that rises above the box, a skewed name
# plate (gold for heroes, crimson for villains), a live voice meter and a bouncing "continue"
# chevron. When the line has a voice clip the text is revealed word by word in sync with the
# spoken audio (word timings from forced alignment, see Voice.visible_chars()).

const StoryData = preload("res://scripts/story_data.gd")
const FxDraw = preload("res://scripts/fx_draw.gd")

var panel: PanelContainer
var text_l: Label
var portrait_frame: PanelContainer
var portrait: TextureRect
var plate: PanelContainer
var name_l: Label
var next_ind: Control
var wave: Control
var typing := false
var voiced := false
var type_acc := 0.0
var t := 0.0
var speaker := ""
var last_speaker := ""
var line_text := ""
var scene_id := ""
var bottom := 30.0
var margin := 20.0
var max_w := 640.0
var portrait_h := 128.0
var _base_portrait_y := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame = PanelContainer.new()
	portrait_frame.add_theme_stylebox_override("panel", Game.kit("portrait", Vector4(4, 4, 4, 4)))
	portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(portrait_frame)
	portrait = TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame.add_child(portrait)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Game.kit("panel_dialog", Vector4(26, 18, 26, 14)))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	text_l = Label.new()
	text_l.add_theme_font_override("font", Game.font_body)
	text_l.add_theme_font_size_override("font_size", 17)
	text_l.add_theme_color_override("font_color", Color(1, 0.96, 0.89))
	text_l.add_theme_constant_override("outline_size", 3)
	text_l.add_theme_color_override("font_outline_color", Color(0.04, 0.01, 0.02, 0.85))
	text_l.add_theme_constant_override("line_spacing", 1)
	text_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	text_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_l.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	text_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(text_l)
	plate = PanelContainer.new()
	plate.add_theme_stylebox_override("panel", Game.kit("plate", Vector4(20, 0, 20, 3)))
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(plate)
	var ph := HBoxContainer.new()
	ph.add_theme_constant_override("separation", 7)
	ph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(ph)
	wave = FxDraw.new("wave", Game.UI_INK)
	wave.custom_minimum_size = Vector2(17, 16)
	wave.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ph.add_child(wave)
	name_l = Game.make_label("", 18, Game.UI_INK, false)
	name_l.add_theme_font_override("font", Game.font_callig)
	name_l.add_theme_constant_override("outline_size", 0)
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ph.add_child(name_l)
	next_ind = FxDraw.new("next", Game.UI_ACCENT)
	next_ind.size = Vector2(16, 16)
	add_child(next_ind)

func is_right(spk: String) -> bool:
	return spk == "selim"

func show_line(spk: String, text: String, sid := "") -> void:
	speaker = spk
	line_text = text
	scene_id = sid
	var info: Array = StoryData.SPEAKERS.get(spk, ["", ""])
	var villain: bool = Game.is_villain(spk) or (spk == "refaat" and sid.begins_with("ch12"))
	name_l.text = info[0]
	plate.visible = str(info[0]) != ""
	plate.add_theme_stylebox_override("panel", Game.kit("plate_villain" if villain else "plate", Vector4(20, 0, 20, 3)))
	name_l.add_theme_color_override("font_color", Color(1, 0.93, 0.84) if villain else Game.UI_INK)
	(wave as Object).set("color", Color(1, 0.85, 0.7) if villain else Game.UI_INK)
	portrait_frame.add_theme_stylebox_override("panel", Game.kit("portrait_villain" if villain else "portrait", Vector4(4, 4, 4, 4)))
	text_l.text = text
	text_l.visible_characters = 0
	var has_p: bool = str(info[1]) != ""
	portrait_frame.visible = has_p
	if has_p:
		portrait.texture = load("res://assets/art/%s.png" % StoryData.portrait_for(spk, text, sid))
	layout_box()
	voiced = Voice.play_line(spk, text)
	type_acc = 0.0
	typing = true
	# portrait slides in when the speaker changes, otherwise just a soft nod
	if has_p:
		var right := is_right(spk)
		var bx := portrait_frame.position.x
		if spk != last_speaker:
			portrait_frame.position.x = bx + (46.0 if right else -46.0)
			portrait_frame.modulate.a = 0.0
			var tw := create_tween().set_parallel(true)
			tw.tween_property(portrait_frame, "position:x", bx, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(portrait_frame, "modulate:a", 1.0, 0.22)
		else:
			portrait_frame.modulate.a = 1.0
	if spk != last_speaker:
		plate.modulate.a = 0.0
		plate.scale = Vector2(0.85, 0.85)
		var pt := create_tween().set_parallel(true)
		pt.tween_property(plate, "modulate:a", 1.0, 0.2)
		pt.tween_property(plate, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	last_speaker = spk

func layout_box() -> void:
	var s := get_viewport_rect().size
	var info: Array = StoryData.SPEAKERS.get(speaker, ["", ""])
	var has_p: bool = str(info[1]) != ""
	var right := is_right(speaker)
	var pw := (portrait_h * 0.86 + 10.0) if has_p else 0.0
	var total := minf(s.x - margin * 2.0, max_w)
	var dw := total - pw
	var x0 := (s.x - total) / 2.0
	var fs := 17 if text_l.text.length() < 120 else 16
	text_l.add_theme_font_size_override("font_size", fs)
	var th: float = Game.font_body.get_multiline_string_size(text_l.text, HORIZONTAL_ALIGNMENT_RIGHT, dw - 52.0, fs, -1, TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND).y
	var ph := maxf(86.0, th + 40.0)
	var y0 := s.y - bottom - ph
	text_l.custom_minimum_size = Vector2(dw - 52.0, 0)
	panel.custom_minimum_size = Vector2(dw, ph)
	panel.size = Vector2(dw, ph)
	_fix_size.call_deferred(panel, Vector2(dw, ph))
	var px := 0.0
	if right:
		panel.position = Vector2(x0, y0)
		px = x0 + dw + 10.0
	else:
		px = x0
		panel.position = Vector2(x0 + pw, y0)
	portrait.custom_minimum_size = Vector2(portrait_h * 0.86 - 8.0, portrait_h - 8.0)
	portrait_frame.reset_size()
	portrait_frame.position = Vector2(px, s.y - bottom - portrait_frame.size.y)
	_base_portrait_y = portrait_frame.position.y
	portrait.flip_h = right
	plate.reset_size()
	plate.pivot_offset = plate.size / 2.0
	if right:
		plate.position = Vector2(panel.position.x + 22, y0 - plate.size.y * 0.6)
	else:
		plate.position = Vector2(panel.position.x + dw - plate.size.x - 22, y0 - plate.size.y * 0.6)
	next_ind.position = Vector2(panel.position.x + 12, y0 + ph - 22)

func _fix_size(c: Control, sz: Vector2) -> void:
	c.size = sz

# true while text is still revealing
func skip_typing() -> bool:
	if typing:
		text_l.visible_characters = -1
		typing = false
		return true
	return false

func voice_busy() -> bool:
	return voiced and Voice.is_playing()

func stop() -> void:
	typing = false
	Voice.stop()

func _process(delta: float) -> void:
	t += delta
	if not is_visible_in_tree():
		return
	(next_ind as Object).set("active", not typing)
	(wave as Object).set("active", voice_busy())
	if typing:
		var total := text_l.get_total_character_count()
		if voiced and Voice.is_playing():
			text_l.visible_characters = mini(total, Voice.visible_chars(total))
		else:
			type_acc += delta * 48.0
			var n := int(type_acc)
			if n > 0:
				type_acc -= n
				text_l.visible_characters += n
				if not voiced and text_l.visible_characters % 4 == 0:
					Audio.sfx("blip", 0.2, -14)
		if text_l.visible_characters >= total or (voiced and not Voice.is_playing()):
			text_l.visible_characters = -1
			typing = false
	# speaking portrait: tiny lift while words are being spoken
	if portrait_frame.visible:
		var talk := 0.0
		if voice_busy():
			talk = absf(sin(t * 11.0)) * 1.6
		portrait_frame.position.y = lerpf(portrait_frame.position.y, _base_portrait_y - talk, minf(1.0, delta * 18.0))
