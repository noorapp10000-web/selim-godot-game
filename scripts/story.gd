extends Control
# Cinematic story player: full-screen illustrations with slow camera moves and cross-fades,
# letterbox bars, chapter title cards, narrator subtitles and visual-novel style dialogue
# (big framed portraits, name ribbons, typewriter text). Tap anywhere to continue.

const StoryData = preload("res://scripts/story_data.gd")
const DialogBox = preload("res://scripts/dialog_box.gd")
const FxDraw = preload("res://scripts/fx_draw.gd")

var lines: Array = []
var panels: Array = []
var idx := 0
var typing := false
var type_acc := 0.0
var t := 0.0
var done := false
var auto_mode := false
var auto_t := 0.0
var img_a: TextureRect
var img_b: TextureRect
var cur_img := ""
var front: TextureRect
var bar_top: ColorRect
var bar_bot: ColorRect
var narr_box: Control
var narr: Label
var card: VBoxContainer
var card_num: Label
var card_name: Label
var card_place: Label
var dlg: Control
var narr_voiced := false
var narr_next: Control
var skip_btn: Button
var auto_btn: Button
var dots: HBoxContainer
var cam_tw: Tween
var last_speaker := ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var data: Dictionary = StoryData.SCENES.get(Game.story_id, {"bg": "title", "lines": [["narrator", "..."]]})
	lines = data["lines"]
	panels = StoryData.PANELS.get(Game.story_id, [[data["bg"], 0]])
	var black := ColorRect.new()
	black.color = Color(0, 0, 0)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)
	img_a = _make_img()
	img_b = _make_img()
	var vig := TextureRect.new()
	vig.texture = load("res://assets/ui/vignette.png")
	vig.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vig)
	# bottom gradient so text always reads
	var grad := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(0, 0, 0, 0.82))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	grad.texture = gt
	grad.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	grad.set_anchors_preset(Control.PRESET_FULL_RECT)
	grad.anchor_top = 0.5
	grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(grad)
	bar_top = _bar(true)
	bar_bot = _bar(false)
	_build_narration()
	_build_card()
	_build_dialog()
	_build_top()
	var music := "story"
	if Game.story_id in ["ch6_outro", "ch12_outro", "credits"]:
		music = "ending"
	Audio.play_music(music)
	get_viewport().size_changed.connect(_layout)
	_layout()
	# letterbox slides in
	bar_top.offset_bottom = 0
	bar_bot.offset_top = 0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(bar_top, "offset_bottom", 26.0, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(bar_bot, "offset_top", -26.0, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_show()
	if Game.autotest.begins_with("demo"):
		# recording mode (movie maker): play the scene hands-free with voices, then quit
		auto_mode = true
		auto_btn.button_pressed = true
	elif Game.autotest != "":
		_autotest()

func _make_img() -> TextureRect:
	var r := TextureRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.modulate.a = 0.0
	add_child(r)
	return r

func _bar(top: bool) -> ColorRect:
	var b := ColorRect.new()
	b.color = Color(0, 0, 0)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if top:
		b.set_anchors_preset(Control.PRESET_TOP_WIDE)
		b.offset_bottom = 26
	else:
		b.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		b.offset_top = -26
	add_child(b)
	return b

func _build_narration() -> void:
	narr_box = Control.new()
	narr_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	narr_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(narr_box)
	narr = Game.make_label("", 21, Color(1, 0.95, 0.84), true)
	narr.add_theme_font_override("font", Game.font_callig)
	narr.add_theme_constant_override("outline_size", 8)
	narr.add_theme_color_override("font_outline_color", Color(0.06, 0.02, 0.02, 0.95))
	narr.add_theme_constant_override("line_spacing", 0)
	narr.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	narr.offset_left = 60
	narr.offset_right = -60
	narr.offset_top = -104
	narr.offset_bottom = -34
	narr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	narr.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	narr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	narr.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	narr_box.add_child(narr)

func _build_card() -> void:
	card = VBoxContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_theme_constant_override("separation", 2)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.visible = false
	add_child(card)
	var rib := PanelContainer.new()
	rib.add_theme_stylebox_override("panel", Game.ui_box("ribbon", Vector4(58, 6, 58, 12)))
	rib.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rib.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(rib)
	card_num = Game.make_label("", 22, Game.UI_ACCENT, true)
	card_num.add_theme_font_override("font", Game.font_callig)
	card_num.add_theme_constant_override("outline_size", 0)
	card_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rib.add_child(card_num)
	card_name = Game.make_label("", 58, Color(1, 0.96, 0.86), true)
	card_name.add_theme_constant_override("outline_size", 14)
	card_name.add_theme_color_override("font_outline_color", Color(0.28, 0.05, 0.03))
	card_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(card_name)
	var div := FxDraw.new("divider", Game.UI_ACCENT)
	div.custom_minimum_size = Vector2(260, 12)
	div.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.add_child(div)
	card_place = Game.make_label("", 18, Color(1, 0.88, 0.62), false)
	card_place.add_theme_font_override("font", Game.font_callig)
	card_place.add_theme_constant_override("outline_size", 6)
	card_place.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.02, 0.9))
	card_place.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(card_place)

func _build_dialog() -> void:
	dlg = DialogBox.new()
	add_child(dlg)
	dlg.visible = false
	narr_next = FxDraw.new("next", Game.UI_ACCENT)
	narr_next.size = Vector2(16, 16)
	narr_box.add_child(narr_next)

func _build_top() -> void:
	skip_btn = Game.make_button("تخطّي  ◀◀", 13, "blue")
	skip_btn.custom_minimum_size = Vector2(0, 30)
	_pill(skip_btn)
	skip_btn.pressed.connect(_finish)
	add_child(skip_btn)
	auto_btn = Game.make_button("تلقائي", 13, "blue")
	auto_btn.custom_minimum_size = Vector2(0, 30)
	_pill(auto_btn)
	auto_btn.toggle_mode = true
	auto_btn.button_pressed = Game.story_auto
	auto_mode = Game.story_auto
	auto_btn.toggled.connect(func(on): auto_mode = on; auto_t = 0.0; Game.story_auto = on; Game.save_game())
	add_child(auto_btn)
	dots = HBoxContainer.new()
	dots.add_theme_constant_override("separation", 3)
	dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dots)
	for i in range(lines.size()):
		var d := Panel.new()
		d.custom_minimum_size = Vector2(9, 4)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dots.add_child(d)

func _pill(b: Button) -> void:
	var pad := Vector4(14, 2, 14, 4)
	b.add_theme_stylebox_override("normal", Game.kit("pill", pad))
	var hi := Game.kit("pill", pad) as StyleBoxFlat
	hi.border_color = Color(Game.UI_ACCENT, 0.9)
	hi.bg_color = Color(0.16, 0.11, 0.09, 0.85)
	for st in ["hover", "focus", "pressed"]:
		b.add_theme_stylebox_override(st, hi)
	b.add_theme_color_override("font_pressed_color", Game.UI_ACCENT)

func _layout() -> void:
	var s := get_viewport_rect().size
	var m := 12.0 + maxf(0.0, (s.x - 640.0) * 0.06)
	skip_btn.reset_size()
	skip_btn.position = Vector2(m, 30)
	auto_btn.reset_size()
	auto_btn.position = Vector2(m + skip_btn.size.x + 8, 30)
	dots.reset_size()
	dots.position = Vector2(s.x - m - dots.size.x, 43)
	dlg.margin = m + 8.0
	if idx < lines.size() and dlg.visible:
		dlg.layout_box()
	narr_next.position = Vector2(s.x / 2.0 - 8.0, s.y - 46.0)

func _panel_for(i: int) -> String:
	var nm: String = panels[0][0]
	for p in panels:
		if i >= int(p[1]):
			nm = p[0]
	return nm

func _set_image(nm: String) -> void:
	if nm == cur_img:
		return
	cur_img = nm
	var path := "res://assets/story/%s.jpg" % nm
	if not ResourceLoader.exists(path):
		path = "res://assets/art/%s.png" % nm
	var next_img := img_b if front == img_a else img_a
	var prev := front
	next_img.texture = load(path)
	move_child(next_img, 2)
	if prev != null:
		move_child(prev, 1)
	front = next_img
	# Ken Burns: slow zoom + drift; direction alternates per panel
	var s := get_viewport_rect().size
	next_img.pivot_offset = s / 2.0
	var dir := -1.0 if (panels.size() > 0 and hash(nm) % 2 == 0) else 1.0
	next_img.scale = Vector2(1.14, 1.14)
	next_img.position = Vector2(dir * 16.0, 5.0)
	next_img.modulate.a = 0.0
	if cam_tw != null and cam_tw.is_valid():
		cam_tw.kill()
	cam_tw = create_tween().set_parallel(true)
	cam_tw.tween_property(next_img, "modulate:a", 1.0, 0.9)
	# end scale 1.06 leaves >= 3% overscan per side, more than the 10px drift on any aspect ratio
	cam_tw.tween_property(next_img, "scale", Vector2(1.06, 1.06), 16.0).set_trans(Tween.TRANS_SINE)
	cam_tw.tween_property(next_img, "position", Vector2(-dir * 10.0, -3.0), 16.0).set_trans(Tween.TRANS_SINE)
	if prev != null:
		cam_tw.tween_property(prev, "modulate:a", 0.0, 0.9)

func _show() -> void:
	var line: Array = lines[idx]
	_set_image(_panel_for(idx))
	for i in range(dots.get_child_count()):
		var dc: Color = Game.UI_ACCENT if i == idx else (Color(1, 1, 1, 0.5) if i < idx else Color(1, 1, 1, 0.16))
		var sb := StyleBoxFlat.new()
		sb.bg_color = dc
		sb.set_corner_radius_all(2)
		(dots.get_child(i) as Panel).add_theme_stylebox_override("panel", sb)
		(dots.get_child(i) as Panel).custom_minimum_size = Vector2(16 if i == idx else 9, 4)
	auto_t = 0.0
	narr_voiced = false
	if line[0] == "narrator":
		dlg.visible = false
		dlg.stop()
		var txt: String = line[1]
		if txt.begins_with("الفصل") and ":" in txt:
			# chapter title card (the narrator announces it)
			var parts := txt.split(":", true, 1)
			card_num.text = parts[0].strip_edges()
			card_name.text = parts[1].strip_edges()
			var chn := int(Game.story_id.trim_prefix("ch").split("_")[0]) if Game.story_id.begins_with("ch") else 0
			card_place.text = ("— %s —" % Game.CHAPTERS[chn]["place"]) if Game.CHAPTERS.has(chn) else ""
			card.visible = true
			narr.visible = false
			card.reset_size()
			card.position = (get_viewport_rect().size - card.size) / 2.0
			card.modulate.a = 0.0
			card.scale = Vector2(1.15, 1.15)
			card.pivot_offset = card.size / 2.0
			var tw := create_tween().set_parallel(true)
			tw.tween_property(card, "modulate:a", 1.0, 0.6)
			tw.tween_property(card, "scale", Vector2.ONE, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			Audio.sfx("slam", 0.0, -8)
			Audio.sfx("chapter_hit", 0.0, -4)
			narr_voiced = Voice.play_line("narrator", txt)
			typing = false
			return
		card.visible = false
		narr.visible = true
		narr.text = txt
		narr.visible_characters = 0
		narr.modulate.a = 0.0
		var tw2 := create_tween()
		tw2.tween_property(narr, "modulate:a", 1.0, 0.25)
		narr_voiced = Voice.play_line("narrator", txt)
	else:
		card.visible = false
		narr.visible = false
		dlg.visible = true
		dlg.show_line(line[0], line[1], Game.story_id)
		Audio.sfx("page", 0.05, -12)
	type_acc = 0.0
	typing = true

func _cur() -> Label:
	return narr if narr.visible else dlg.text_l

func _voice_busy() -> bool:
	return (narr_voiced and Voice.is_playing()) or (dlg.visible and dlg.voice_busy())

func _process(delta: float) -> void:
	t += delta
	(narr_next as Object).set("active", narr.visible and not typing)
	if typing:
		if dlg.visible:
			typing = dlg.typing
		else:
			var l := narr
			var total := l.get_total_character_count()
			if narr_voiced and Voice.is_playing():
				l.visible_characters = mini(total, Voice.visible_chars(total))
			else:
				type_acc += delta * 40.0
				var n := int(type_acc)
				if n > 0:
					type_acc -= n
					l.visible_characters += n
			if l.visible_characters >= total or (narr_voiced and not Voice.is_playing()):
				l.visible_characters = -1
				typing = false
	elif auto_mode and not done:
		if _voice_busy():
			auto_t = 0.0
		else:
			auto_t += delta
			var wait := 0.7 if (narr_voiced or dlg.voiced) else 1.6 + _cur().text.length() * 0.035
			if auto_t > wait:
				_next()

func _next() -> void:
	if done:
		return
	if typing:
		if dlg.visible:
			dlg.skip_typing()
		else:
			narr.visible_characters = -1
		typing = false
		return
	Voice.stop()
	Audio.sfx("select", 0.05, -8)
	idx += 1
	if idx >= lines.size():
		_finish()
	else:
		_show()

func _finish() -> void:
	if done:
		return
	done = true
	Voice.stop()
	if Game.autotest.begins_with("demo"):
		await get_tree().create_timer(1.0).timeout
		get_tree().quit()
		return
	Game.story_finished()

func _over_button(p: Vector2) -> bool:
	for b in [skip_btn, auto_btn]:
		if b.get_global_rect().grow(4).has_point(p):
			return true
	return false

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		if not _over_button(event.position):
			_next()
	elif event.is_action_pressed("accept") or event.is_action_pressed("jump") or event.is_action_pressed("attack"):
		_next()

func _autotest() -> void:
	await get_tree().create_timer(1.6).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("user://shots")
	img.save_png("user://shots/story_%s_a.png" % Game.story_id)
	for k in range(3):
		_next()
		_next()
	await get_tree().create_timer(1.4).timeout
	await RenderingServer.frame_post_draw
	img = get_viewport().get_texture().get_image()
	img.save_png("user://shots/story_%s_b.png" % Game.story_id)
	print("AUTOTEST story shots ", Game.story_id)
	if Game.autotest == "story":
		get_tree().quit()
	else:
		_finish()
