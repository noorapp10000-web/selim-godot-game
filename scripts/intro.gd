extends Control
# Opening cinematic shown on every launch (tap / any key skips to the title screen).
#  0  black, calligraphic tagline
#  1  map of Egypt      – slow push-in
#  2  the golden watch  – zoom + gold flash
#  3  the gang          – red pulse, shake, slam
#  4  Selim on the roof – slow rise
#  5  white flash -> logo slams in with shockwave, embers, light sweep, ribbon subtitle
# Everything is code-driven tweens on top of four AI-painted key-art frames (assets/intro).

const SHOTS := [
	["map", "مصر.. أرض الحكايات اللي مبتخلصش", Vector2(1.04, 1.18), Vector2(0, 0)],
	["watch", "ساعة قديمة.. شايلة سرّ الزمن", Vector2(1.10, 1.30), Vector2(0, -6)],
	["gang", "وعصابة مستعدة تعمل أي حاجة عشان تاخدها", Vector2(1.22, 1.06), Vector2(10, 0)],
	["hero", "بس فيه واحد.. مش هيستسلم", Vector2(1.16, 1.04), Vector2(0, 14)],
]
const SHOT_LEN := 3.6

var t := 0.0
var done := false
var root: Control
var img_a: TextureRect
var img_b: TextureRect
var front: TextureRect
var tint: ColorRect
var flash: ColorRect
var caption: Label
var tagline: Label
var bar_top: ColorRect
var bar_bot: ColorRect
var logo_box: Control
var logo: Label
var logo_glow: Label
var ribbon: PanelContainer
var sweep: ColorRect
var press: Label
var skip_l: Label
var embers: CPUParticles2D
var burst: CPUParticles2D
var shake := 0.0
var phase := 0
var skipped := false
var shot_tw: Tween
var cap_tw: Tween
var cap_voiced := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if Game.autotest != "" and Game.autotest != "intro" and Game.autotest != "demointro":
		get_tree().change_scene_to_file.call_deferred("res://scenes/Title.tscn")
		return
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var black := ColorRect.new()
	black.color = Color(0, 0, 0)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(black)
	img_a = _img()
	img_b = _img()
	tint = ColorRect.new()
	tint.color = Color(0.7, 0.04, 0.02, 0.0)
	tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tint)
	var vig := TextureRect.new()
	vig.texture = load("res://assets/ui/vignette.png")
	vig.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(vig)
	embers = _embers(46, Color(1, 0.72, 0.3, 0.9))
	root.add_child(embers)
	bar_top = _bar()
	bar_bot = _bar()
	caption = Game.make_label("", 28, Color(1, 0.93, 0.78), true)
	caption.add_theme_font_override("font", Game.font_callig)
	caption.add_theme_constant_override("outline_size", 9)
	caption.add_theme_color_override("font_outline_color", Color(0.05, 0.01, 0.01, 0.95))
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	root.add_child(caption)
	tagline = Game.make_label("حكاية من قلب شوارع مصر", 26, Color(1, 0.86, 0.5), true)
	tagline.add_theme_font_override("font", Game.font_callig)
	tagline.add_theme_constant_override("outline_size", 0)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.modulate.a = 0.0
	root.add_child(tagline)
	_build_logo()
	flash = ColorRect.new()
	flash.color = Color(1, 0.97, 0.88, 0.0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	skip_l = Game.make_label("اضغط للتخطّي ◀◀", 12, Color(1, 1, 1, 0.55), true)
	skip_l.add_theme_font_override("font", Game.font_button)
	skip_l.add_theme_constant_override("outline_size", 3)
	add_child(skip_l)
	get_viewport().size_changed.connect(_layout)
	_layout()
	Audio.play_music("title")
	_run()
	if Game.autotest == "intro":
		_autotest()

func _img() -> TextureRect:
	var r := TextureRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.modulate.a = 0.0
	root.add_child(r)
	return r

func _bar() -> ColorRect:
	var b := ColorRect.new()
	b.color = Color(0, 0, 0)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(b)
	return b

func _embers(n: int, c: Color) -> CPUParticles2D:
	var e := CPUParticles2D.new()
	e.amount = n
	e.lifetime = 5.0
	e.preprocess = 5.0
	e.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	e.direction = Vector2(0.25, -1)
	e.spread = 30.0
	e.gravity = Vector2(0, -8)
	e.initial_velocity_min = 10.0
	e.initial_velocity_max = 30.0
	e.scale_amount_min = 1.0
	e.scale_amount_max = 2.6
	e.color = c
	var g := Gradient.new()
	g.set_color(0, Color(1, 0.85, 0.45, 0.0))
	g.add_point(0.2, Color(1, 0.75, 0.35, 1.0))
	g.set_color(g.get_point_count() - 1, Color(1, 0.4, 0.15, 0.0))
	e.color_ramp = g
	return e

func _build_logo() -> void:
	logo_box = Control.new()
	logo_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo_box.modulate.a = 0.0
	root.add_child(logo_box)
	burst = CPUParticles2D.new()
	burst.emitting = false
	burst.one_shot = true
	burst.amount = 90
	burst.lifetime = 1.4
	burst.explosiveness = 1.0
	burst.direction = Vector2(0, -1)
	burst.spread = 180.0
	burst.gravity = Vector2(0, 60)
	burst.initial_velocity_min = 80.0
	burst.initial_velocity_max = 260.0
	burst.damping_min = 60.0
	burst.damping_max = 120.0
	burst.scale_amount_min = 1.5
	burst.scale_amount_max = 3.5
	var g := Gradient.new()
	g.set_color(0, Color(1, 0.95, 0.7, 1))
	g.set_color(g.get_point_count() - 1, Color(1, 0.45, 0.1, 0))
	burst.color_ramp = g
	logo_box.add_child(burst)
	logo_glow = Game.make_label("سليم", 104, Color(1, 0.7, 0.2, 0.0), true)
	logo_glow.add_theme_constant_override("outline_size", 40)
	logo_glow.add_theme_color_override("font_outline_color", Color(1, 0.78, 0.3, 0.22))
	logo_glow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo_box.add_child(logo_glow)
	logo = Game.make_label("سليم", 104, Color(1, 0.84, 0.32), true)
	logo.add_theme_constant_override("outline_size", 20)
	logo.add_theme_color_override("font_outline_color", Color(0.32, 0.05, 0.02))
	logo.add_theme_constant_override("shadow_offset_y", 7)
	logo.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.clip_contents = true
	logo_box.add_child(logo)
	# diagonal light sweep, clipped to the logo label
	sweep = ColorRect.new()
	sweep.color = Color(1, 1, 0.92, 0.55)
	sweep.size = Vector2(26, 260)
	sweep.rotation = 0.35
	sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sweep.material = CanvasItemMaterial.new()
	(sweep.material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	logo.add_child(sweep)
	ribbon = PanelContainer.new()
	ribbon.add_theme_stylebox_override("panel", Game.ui_box("ribbon", Vector4(66, 5, 66, 12)))
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ribbon.modulate.a = 0.0
	logo_box.add_child(ribbon)
	var sub := Game.make_label("ساعة أبويا", 26, Game.UI_ACCENT, true)
	sub.add_theme_font_override("font", Game.font_callig)
	sub.add_theme_constant_override("outline_size", 0)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ribbon.add_child(sub)
	press = Game.make_label("اضغط في أي حتة للبدء", 17, Color(1, 0.95, 0.85), true)
	press.add_theme_font_override("font", Game.font_button)
	press.add_theme_constant_override("outline_size", 6)
	press.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	press.modulate.a = 0.0
	logo_box.add_child(press)

func _layout() -> void:
	var s := get_viewport_rect().size
	var bh := 30.0 if phase < 5 else 0.0
	bar_top.position = Vector2(0, 0)
	bar_top.size = Vector2(s.x, bh)
	bar_bot.position = Vector2(0, s.y - bh)
	bar_bot.size = Vector2(s.x, bh)
	for r in [img_a, img_b]:
		r.pivot_offset = s / 2.0
	caption.position = Vector2(30, s.y - 30.0 - 62.0)
	caption.size = Vector2(s.x - 60, 54)
	tagline.position = Vector2(0, s.y / 2.0 - 24.0)
	tagline.size = Vector2(s.x, 48)
	embers.position = Vector2(s.x * 0.5, s.y + 8)
	embers.emission_rect_extents = Vector2(s.x * 0.55, 6)
	logo_box.position = Vector2.ZERO
	logo_box.size = s
	logo.reset_size()
	logo.size.x = s.x
	logo.position = Vector2(0, s.y * 0.40 - logo.size.y / 2.0)
	logo.pivot_offset = logo.size / 2.0
	logo_glow.size = logo.size
	logo_glow.position = logo.position
	logo_glow.pivot_offset = logo.pivot_offset
	burst.position = Vector2(s.x / 2.0, s.y * 0.40)
	ribbon.reset_size()
	ribbon.position = Vector2((s.x - ribbon.size.x) / 2.0, s.y * 0.40 + 54.0)
	ribbon.pivot_offset = ribbon.size / 2.0
	press.size = Vector2(s.x, 30)
	press.position = Vector2(0, s.y - 64.0)
	skip_l.reset_size()
	skip_l.position = Vector2(14, 6)

func _wait(sec: float) -> bool:
	await get_tree().create_timer(sec).timeout
	return not done and not skipped and is_inside_tree()

func _run() -> void:
	# 0 – tagline out of the dark
	var tag_len := Voice.length_of("narrator", tagline.text)
	var hold := maxf(1.0, tag_len - 0.4)
	var tw := create_tween()
	tw.tween_interval(0.3)
	tw.tween_callback(func(): Voice.play_line("narrator", tagline.text))
	tw.tween_property(tagline, "modulate:a", 1.0, 0.9)
	tw.tween_interval(hold)
	tw.tween_property(tagline, "modulate:a", 0.0, 0.6)
	if not await _wait(1.8 + hold):
		return
	for i in range(SHOTS.size()):
		phase = i + 1
		var len_i := _shot(i)
		if not await _wait(len_i):
			return
	_logo()

func _shot(i: int) -> float:
	var d: Array = SHOTS[i]
	# each shot lasts at least as long as its narrated caption
	var vlen := Voice.length_of("narrator", d[1])
	var shot_len: float = maxf(SHOT_LEN, vlen + 1.0) if Game.voice_on else SHOT_LEN
	var s := get_viewport_rect().size
	var next_img := img_b if front == img_a else img_a
	var prev := front
	next_img.texture = load("res://assets/intro/%s.jpg" % d[0])
	root.move_child(next_img, 2)
	front = next_img
	var z0: float = d[2].x
	var z1: float = d[2].y
	next_img.pivot_offset = s / 2.0
	next_img.scale = Vector2(z0, z0)
	next_img.position = d[3]
	next_img.modulate = Color(1, 1, 1, 0)
	if shot_tw != null and shot_tw.is_valid():
		shot_tw.kill()
	var tw := create_tween().set_parallel(true)
	shot_tw = tw
	tw.tween_property(next_img, "modulate:a", 1.0, 0.7)
	tw.tween_property(next_img, "scale", Vector2(z1, z1), shot_len + 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(next_img, "position", -d[3] as Vector2, shot_len + 0.8).set_trans(Tween.TRANS_SINE)
	if prev != null:
		tw.tween_property(prev, "modulate:a", 0.0, 0.7)
	# caption: soft fade + letter reveal, gone before the next cut
	caption.text = d[1]
	caption.visible_ratio = 0.0
	caption.modulate.a = 1.0
	if cap_tw != null and cap_tw.is_valid():
		cap_tw.kill()
	var ct := create_tween()
	cap_tw = ct
	cap_voiced = false
	ct.tween_interval(0.45)
	if vlen > 0.0 and Game.voice_on:
		# words appear exactly as the narrator says them (see _process)
		ct.tween_callback(func(): cap_voiced = Voice.play_line("narrator", d[1]))
		ct.tween_interval(shot_len - 0.85 - 0.4)
	else:
		ct.tween_property(caption, "visible_ratio", 1.0, 1.1)
		ct.tween_interval(shot_len - 2.3)
	ct.tween_property(caption, "modulate:a", 0.0, 0.4)
	match d[0]:
		"watch":
			_flash(Color(1, 0.85, 0.4), 0.55, 0.5)
			Audio.sfx("teleport", 0.0, -6)
		"gang":
			Audio.sfx("slam", 0.0, -2)
			Audio.sfx("roar", 0.05, -10)
			shake = 7.0
			var rt := create_tween()
			for k in range(3):
				rt.tween_property(tint, "color:a", 0.28, 0.12)
				rt.tween_property(tint, "color:a", 0.0, 0.5)
		"hero":
			Audio.sfx("swing_stick", 0.0, -4)
		_:
			Audio.sfx("chain", 0.0, -14)
	return shot_len

func _flash(c: Color, a: float, dur: float) -> void:
	flash.color = Color(c.r, c.g, c.b, a)
	create_tween().tween_property(flash, "color:a", 0.0, dur)

func _logo() -> void:
	phase = 5
	var s := get_viewport_rect().size
	_flash(Color(1, 0.97, 0.88), 1.0, 0.9)
	Audio.sfx("slam", 0.0, 0)
	Audio.sfx("bomb_boom", 0.0, -8)
	shake = 10.0
	caption.visible = false
	# keep the hero art, darker, as backdrop
	if front != null:
		create_tween().tween_property(front, "modulate", Color(0.42, 0.36, 0.4, 1), 0.6)
	var bt := create_tween().set_parallel(true)
	bt.tween_property(bar_top, "size:y", 0.0, 0.5)
	bt.tween_property(bar_bot, "position:y", s.y, 0.5)
	logo_box.modulate.a = 1.0
	logo.scale = Vector2(3.2, 3.2)
	logo.modulate.a = 0.0
	var lt := create_tween().set_parallel(true)
	lt.tween_property(logo, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	lt.tween_property(logo, "modulate:a", 1.0, 0.18)
	burst.restart()
	burst.emitting = true
	# glow pulse
	logo_glow.modulate = Color(1, 1, 1, 0)
	var gt := create_tween().set_loops()
	gt.tween_property(logo_glow, "modulate:a", 1.0, 1.1).set_trans(Tween.TRANS_SINE)
	gt.tween_property(logo_glow, "modulate:a", 0.35, 1.1).set_trans(Tween.TRANS_SINE)
	# shockwave ring
	var ring := _ring()
	ring.position = Vector2(s.x / 2.0, s.y * 0.40)
	logo_box.add_child(ring)
	logo_box.move_child(ring, 0)
	ring.scale = Vector2(0.2, 0.2)
	var rt := create_tween().set_parallel(true)
	rt.tween_property(ring, "scale", Vector2(5, 5), 0.8).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	rt.tween_property(ring, "modulate:a", 0.0, 0.8)
	# light sweep across the letters
	sweep.position = Vector2(-80, -60)
	var st := create_tween().set_loops()
	st.tween_interval(0.5)
	st.tween_property(sweep, "position:x", logo.size.x + 80.0, 1.1).set_trans(Tween.TRANS_SINE)
	st.tween_interval(1.8)
	st.tween_callback(func(): sweep.position.x = -80.0)
	# ribbon subtitle unfurls
	var ft := create_tween()
	ft.tween_interval(0.55)
	ft.tween_callback(func(): Audio.sfx("clang", 0.0, -8))
	ribbon.scale = Vector2(0.1, 1)
	ft.tween_property(ribbon, "modulate:a", 1.0, 0.1)
	ft.parallel().tween_property(ribbon, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	ft.tween_interval(0.5)
	ft.tween_property(press, "modulate:a", 1.0, 0.4)
	ft.tween_callback(_pulse_press)
	skip_l.visible = false
	await get_tree().create_timer(6.5).timeout
	if Game.autotest != "intro":
		_finish()

func _ring() -> Line2D:
	var l := Line2D.new()
	var pts := PackedVector2Array()
	for i in range(49):
		var a := TAU * i / 48.0
		pts.append(Vector2(cos(a), sin(a)) * 40.0)
	l.points = pts
	l.width = 5.0
	l.default_color = Color(1, 0.85, 0.5, 0.85)
	l.antialiased = true
	return l

func _pulse_press() -> void:
	var pt := create_tween().set_loops()
	pt.tween_property(press, "modulate:a", 0.35, 0.7).set_trans(Tween.TRANS_SINE)
	pt.tween_property(press, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE)

func _process(delta: float) -> void:
	t += delta
	if root == null:
		return
	if shake > 0.0:
		shake = maxf(0.0, shake - delta * 22.0)
		root.position = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
	else:
		root.position = Vector2.ZERO
	if phase >= 5 and logo != null:
		logo_box.position.y = sin(t * 1.4) * 2.0
	if cap_voiced and caption.visible:
		var total := caption.get_total_character_count()
		caption.visible_characters = mini(total, Voice.visible_chars(total)) if Voice.is_playing() else -1

func _finish() -> void:
	if done:
		return
	done = true
	Voice.stop()
	if Game.autotest == "demointro":
		get_tree().quit()
		return
	Audio.sfx("select", 0.0, -4)
	Game.goto_title()

func _input(event: InputEvent) -> void:
	if done or root == null:
		return
	var hit := false
	if event is InputEventScreenTouch and event.pressed:
		hit = true
	elif event is InputEventMouseButton and event.pressed:
		hit = true
	elif event is InputEventKey and event.pressed and not event.echo:
		hit = true
	elif event is InputEventJoypadButton and event.pressed:
		hit = true
	if hit:
		get_viewport().set_input_as_handled()
		if phase < 5:
			# first tap jumps straight to the logo reveal, second one goes to the menu
			_skip_to_logo()
		else:
			_finish()

func _skip_to_logo() -> void:
	if phase >= 5:
		return
	skipped = true
	Voice.stop()
	cap_voiced = false
	if shot_tw != null and shot_tw.is_valid():
		shot_tw.kill()
	img_a.texture = load("res://assets/intro/hero.jpg")
	img_a.modulate.a = 1.0
	img_a.scale = Vector2(1.06, 1.06)
	img_a.position = Vector2.ZERO
	img_b.modulate.a = 0.0
	front = img_a
	tagline.visible = false
	_logo()

func _autotest() -> void:
	DirAccess.make_dir_recursive_absolute("user://shots")
	for k in [["intro_0", 1.4], ["intro_1", 2.0], ["intro_2", 3.6], ["intro_3", 3.4], ["intro_4", 3.7], ["intro_5", 1.6], ["intro_6", 1.6], ["intro_7", 2.2], ["intro_8", 2.6]]:
		await get_tree().create_timer(k[1]).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://shots/%s.png" % k[0])
	print("AUTOTEST intro ok")
	get_tree().quit()
