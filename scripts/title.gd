extends Control
# Title screen: animated key art, logo, big touch-friendly menu and an illustrated chapter select.

var menu: VBoxContainer
var right: VBoxContainer
var chapters_panel: PanelContainer
var chapters_dim: ColorRect
var bg: TextureRect
var logo: Label
var embers: CPUParticles2D
var settings_panel: PanelContainer
var diff_cards: Array = []
var diff_desc: Label
var diff_chip: Label
var music_btn: Button
var sfx_btn: Button
var voice_btn: Button
var t := 0.0
var logo_glow: Label
var sweep: ColorRect
var head: VBoxContainer
var footer: HBoxContainer
var ver: Label
var wallet_label: Label
var wallet_chip: PanelContainer
var diff_chip_panel: PanelContainer
var diff_sub: Label
# v10: multiple adventures
var new_panel: PanelContainer
var new_name: LineEdit
var new_cards: Array = []
var new_desc: Label
var new_diff := 0
var new_start: Button
var adv_panel: PanelContainer
var adv_list: VBoxContainer
var dlg_dim: ColorRect
var dlg_panel: PanelContainer
var dlg_title: Label
var dlg_body: Label
var dlg_input: LineEdit
var dlg_yes: Button
var dlg_no: Button
var dlg_cb: Callable
const FxDraw = preload("res://scripts/fx_draw.gd")

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg = TextureRect.new()
	bg.texture = load("res://assets/art/title_v8.jpg")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(bg)
	var tw := create_tween().set_loops()
	tw.tween_property(bg, "scale", Vector2(1.06, 1.06), 14.0).set_trans(Tween.TRANS_SINE)
	tw.tween_property(bg, "scale", Vector2(1.0, 1.0), 14.0).set_trans(Tween.TRANS_SINE)
	var grad := TextureRect.new()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0.0), Color(0.03, 0.03, 0.05, 0.15), Color(0.03, 0.03, 0.05, 0.78)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	grad.texture = gt
	grad.set_anchors_preset(Control.PRESET_FULL_RECT)
	grad.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(grad)
	embers = CPUParticles2D.new()
	embers.amount = 34
	embers.lifetime = 6.0
	embers.preprocess = 6.0
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.direction = Vector2(0.3, -1)
	embers.spread = 25.0
	embers.gravity = Vector2(0, -6)
	embers.initial_velocity_min = 8.0
	embers.initial_velocity_max = 22.0
	embers.scale_amount_min = 1.0
	embers.scale_amount_max = 2.5
	embers.color = Color(1, 0.85, 0.6, 0.45)
	var cr := Gradient.new()
	cr.set_color(0, Color(1, 0.8, 0.4, 0.0))
	cr.add_point(0.2, Color(1, 0.75, 0.35, 0.9))
	cr.set_color(cr.get_point_count() - 1, Color(1, 0.5, 0.2, 0.0))
	embers.color_ramp = cr
	add_child(embers)
	# soft god-rays from the moon, vignette and a floor gradient give the key art depth
	var rays := FxDraw.new("rays", Color(1.0, 0.82, 0.55, 1.0))
	rays.set_anchors_preset(Control.PRESET_FULL_RECT)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	rays.material = add
	add_child(rays)
	move_child(rays, 1)
	var vig := TextureRect.new()
	vig.texture = load("res://assets/ui/vignette.png")
	vig.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vig.modulate.a = 0.8
	add_child(vig)
	right = VBoxContainer.new()
	right.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	right.offset_left = -284
	right.offset_right = -30
	right.offset_top = 8
	right.offset_bottom = -26
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 6)
	add_child(right)
	# gold logo with a breathing glow and a light sweep (same language as the opening cinematic)
	head = VBoxContainer.new()
	head.add_theme_constant_override("separation", 0)
	right.add_child(head)
	var logo_wrap := Control.new()
	logo_wrap.custom_minimum_size = Vector2(0, 92)
	logo_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(logo_wrap)
	logo_glow = Game.make_label("سليم", 78, Color(1, 0.7, 0.2, 0.0), true)
	logo_glow.add_theme_constant_override("outline_size", 34)
	logo_glow.add_theme_color_override("font_outline_color", Color(1, 0.72, 0.3, 0.2))
	logo_glow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	logo_glow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	logo_wrap.add_child(logo_glow)
	logo = Game.make_label("سليم", 78, Color(1, 0.84, 0.36), true)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.add_theme_constant_override("outline_size", 16)
	logo.add_theme_color_override("font_outline_color", Color(0.3, 0.05, 0.02))
	logo.add_theme_constant_override("shadow_offset_x", 0)
	logo.add_theme_constant_override("shadow_offset_y", 6)
	logo.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	logo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	logo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	logo.clip_contents = true
	logo_wrap.add_child(logo)
	sweep = ColorRect.new()
	sweep.color = Color(1, 1, 0.9, 0.45)
	sweep.size = Vector2(22, 220)
	sweep.rotation = 0.35
	sweep.position = Vector2(-80, -60)
	sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := CanvasItemMaterial.new()
	sm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sweep.material = sm
	logo.add_child(sweep)
	var t2 := Game.make_label("ساعة أبويا", 25, Game.UI_ACCENT, true)
	t2.add_theme_font_override("font", Game.font_callig)
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t2.add_theme_constant_override("outline_size", 5)
	t2.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.02, 0.8))
	head.add_child(t2)
	var div := FxDraw.new("divider", Game.UI_ACCENT)
	div.custom_minimum_size = Vector2(200, 12)
	div.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	right.add_child(div)
	menu = VBoxContainer.new()
	menu.add_theme_constant_override("separation", 7)
	right.add_child(menu)
	var sp2 := Control.new()
	sp2.custom_minimum_size = Vector2(0, 4)
	right.add_child(sp2)
	# footer chips: wallet + difficulty
	footer = HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 8)
	right.add_child(footer)
	wallet_chip = PanelContainer.new()
	wallet_chip.add_theme_stylebox_override("panel", Game.kit("pill", Vector4(12, 1, 12, 3)))
	footer.add_child(wallet_chip)
	wallet_label = Game.make_label("", 13, Color(1, 0.86, 0.45), true)
	wallet_label.add_theme_constant_override("outline_size", 0)
	wallet_chip.add_child(wallet_label)
	diff_chip_panel = PanelContainer.new()
	diff_chip_panel.add_theme_stylebox_override("panel", Game.kit("pill", Vector4(12, 1, 12, 3)))
	footer.add_child(diff_chip_panel)
	diff_chip = Game.make_label("", 12, Game.UI_DIM, true)
	diff_chip.add_theme_constant_override("outline_size", 0)
	diff_chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	diff_chip_panel.add_child(diff_chip)
	ver = Game.make_label("الإصدار ١٠  •  معمولة بحب في مصر", 10, Color(1, 1, 1, 0.38), false)
	ver.add_theme_constant_override("outline_size", 2)
	add_child(ver)
	_build_menu()
	_build_chapters()
	_build_settings()
	_build_new_adventure()
	_build_adventures()
	_build_dialog()
	Audio.play_music("title")
	get_viewport().size_changed.connect(_layout)
	_layout()
	# intro animation
	_entrance()
	if menu.get_child_count() > 0 and not Game.touch_enabled():
		(menu.get_child(0) as Button).grab_focus()
	if Game.autotest.begins_with("demo="):
		Game.play_story(Game.autotest.substr(5), "title")
	elif Game.autotest != "":
		_autotest()

# Main menu. With an adventure: continue it (name + chapter), start another one, or open the list
# of saved adventures. Without one: a single big "new adventure" button.
func _build_menu() -> void:
	for c in menu.get_children():
		menu.remove_child(c)
		c.queue_free()
	var has := Game.has_adventure()
	if has:
		var c := Game.make_button("", 18, "primary")
		c.custom_minimum_size = Vector2(0, 50)
		var cv := VBoxContainer.new()
		cv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cv.alignment = BoxContainer.ALIGNMENT_CENTER
		cv.add_theme_constant_override("separation", -8)
		cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(cv)
		var c1 := Game.make_label("كمّل الرحلة", 19, Game.UI_INK, false)
		c1.add_theme_font_override("font", Game.font_button)
		var cch: Dictionary = Game.CHAPTERS[Game.chapter]
		var c2 := Game.make_label("%s • %s" % [Game.adv_name, cch["num"]], 12, Color(Game.UI_INK, 0.75), false)
		c2.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		for l in [c1, c2]:
			l.add_theme_constant_override("outline_size", 0)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cv.add_child(l)
		c.pressed.connect(func(): Game.continue_game())
		menu.add_child(c)
	var n := Game.make_button("مغامرة جديدة", 17 if has else 18, "red" if has else "primary")
	n.pressed.connect(_open_new_adventure)
	if Game.adventures.is_empty():
		n.custom_minimum_size = Vector2(0, 46)
		menu.add_child(n)
	else:
		var row0 := HBoxContainer.new()
		row0.add_theme_constant_override("separation", 7)
		menu.add_child(row0)
		var ab := Game.make_button("مغامراتي", 16)
		ab.pressed.connect(_open_adventures)
		for bb in [ab, n]:
			bb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row0.add_child(bb)
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 7)
	menu.add_child(row1)
	var ch := Game.make_button("الفصول", 16)
	ch.pressed.connect(func(): _open_chapters() if Game.has_adventure() else _open_new_adventure())
	var shop := Game.make_button("المتجر", 16)
	shop.pressed.connect(func(): Game.open_shop() if Game.has_adventure() else _open_new_adventure())
	for bb in [shop, ch]:
		bb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row1.add_child(bb)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 7)
	menu.add_child(row2)
	if not OS.has_feature("web") and not OS.has_feature("ios") and not OS.has_feature("android"):
		var q := Game.make_button("خروج", 15, "blue")
		q.pressed.connect(func(): get_tree().quit())
		q.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row2.add_child(q)
	var st := Game.make_button("الإعدادات", 15, "blue")
	st.pressed.connect(_open_settings)
	st.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row2.add_child(st)
	_refresh_footer()

func _refresh_footer() -> void:
	if footer == null or wallet_label == null:
		return
	var has := Game.has_adventure()
	wallet_chip.visible = has
	diff_chip_panel.visible = has
	wallet_label.text = "%d جنيه" % Game.wallet
	diff_chip.text = "المستوى: %s" % Game.diff()["name"]

func _entrance() -> void:
	head.modulate.a = 0.0
	head.pivot_offset = Vector2(127, 60)
	head.scale = Vector2(1.25, 1.25)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(head, "modulate:a", 1.0, 0.5).set_delay(0.15)
	tw.tween_property(head, "scale", Vector2.ONE, 0.6).set_delay(0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var items: Array = []
	for c in menu.get_children():
		items.append(c)
	items.append(footer)
	var k := 0
	for it in items:
		var ci: CanvasItem = it
		ci.modulate.a = 0.0
		var tw2 := create_tween()
		tw2.tween_interval(0.45 + k * 0.08)
		tw2.tween_property(ci, "modulate:a", 1.0, 0.35)
		k += 1
	logo_glow.modulate.a = 0.0
	var gt := create_tween().set_loops()
	gt.tween_property(logo_glow, "modulate:a", 1.0, 1.6).set_trans(Tween.TRANS_SINE)
	gt.tween_property(logo_glow, "modulate:a", 0.3, 1.6).set_trans(Tween.TRANS_SINE)
	var st := create_tween().set_loops()
	st.tween_interval(1.2)
	st.tween_property(sweep, "position:x", 320.0, 1.2).set_trans(Tween.TRANS_SINE)
	st.tween_interval(3.0)
	st.tween_callback(func(): sweep.position.x = -80.0)

func _layout() -> void:
	var s := get_viewport_rect().size
	if ver != null:
		ver.reset_size()
		ver.position = Vector2(14, s.y - ver.size.y - 6)
	bg.pivot_offset = s / 2.0
	embers.position = Vector2(s.x * 0.5, s.y + 10)
	embers.emission_rect_extents = Vector2(s.x * 0.5, 10)
	if chapters_panel.visible:
		chapters_panel.reset_size()
		chapters_panel.position = (s - chapters_panel.size) / 2.0
	for p in [settings_panel, new_panel, adv_panel, dlg_panel]:
		if p != null and p.visible:
			p.reset_size()
			p.position = (s - p.size) / 2.0

func _process(delta: float) -> void:
	t += delta
	pass

func _build_chapters() -> void:
	chapters_dim = ColorRect.new()
	chapters_dim.color = Color(0.02, 0.02, 0.03, 0.72)
	chapters_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	chapters_dim.visible = false
	add_child(chapters_dim)
	chapters_panel = PanelContainer.new()
	chapters_panel.add_theme_stylebox_override("panel", Game.kit("panel_crest", Vector4(26, 20, 26, 18)))
	chapters_panel.visible = false
	add_child(chapters_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	chapters_panel.add_child(vb)
	var tl := Game.make_label("اختار الفصل", 26, Game.UI_ACCENT, false)
	tl.add_theme_font_override("font", Game.font_callig)
	tl.add_theme_constant_override("outline_size", 0)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(tl)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.layout_direction = Control.LAYOUT_DIRECTION_RTL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	vb.add_child(grid)
	for i in range(1, Game.CHAPTER_COUNT + 1):
		var c: Dictionary = Game.CHAPTERS[i]
		var locked := i > Game.unlocked
		var b := Button.new()
		b.custom_minimum_size = Vector2(168, 52)
		b.clip_contents = true
		b.focus_mode = Control.FOCUS_ALL
		var done_ch: bool = i in Game.completed
		var sbn := Game.style_box(Game.UI_CARD, Color(Game.UI_ACCENT, 0.5 if not locked else 0.1), 1, 9)
		sbn.content_margin_left = 0; sbn.content_margin_right = 0; sbn.content_margin_top = 0; sbn.content_margin_bottom = 0
		var sbh := sbn.duplicate()
		sbh.border_color = Game.UI_ACCENT
		sbh.set_border_width_all(2)
		for st in ["normal", "disabled"]:
			b.add_theme_stylebox_override(st, sbn)
		for st in ["hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, sbh)
		var thumb := TextureRect.new()
		thumb.texture = load("res://assets/story/st_ch%d.jpg" % i)
		thumb.set_anchors_preset(Control.PRESET_FULL_RECT)
		thumb.offset_left = 2; thumb.offset_top = 2; thumb.offset_right = -2; thumb.offset_bottom = -2
		thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		thumb.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if locked:
			thumb.modulate = Color(0.25, 0.22, 0.22)
		b.add_child(thumb)
		var shade := ColorRect.new()
		shade.color = Color(0, 0, 0, 0.55)
		shade.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		shade.offset_top = -40; shade.offset_left = 2; shade.offset_right = -2; shade.offset_bottom = -2
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(shade)
		var lb := VBoxContainer.new()
		lb.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		lb.offset_top = -42
		lb.offset_bottom = -2
		lb.add_theme_constant_override("separation", -6)
		lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(lb)
		var l1 := Game.make_label(c["num"], 11, Game.UI_ACCENT, true)
		var l2 := Game.make_label(c["name"] if not locked else "مقفول", 16, Game.UI_TEXT, true)
		for l in [l1, l2]:
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lb.add_child(l)
		if done_ch:
			var badge := PanelContainer.new()
			badge.add_theme_stylebox_override("panel", Game.kit("plate", Vector4(7, 0, 7, 1)))
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			badge.position = Vector2(6, 5)
			var bl := Game.make_label("مكتمل", 9, Game.UI_INK, false)
			bl.add_theme_font_override("font", Game.font_button)
			bl.add_theme_constant_override("outline_size", 0)
			badge.add_child(bl)
			b.add_child(badge)
		b.disabled = locked
		var num := i
		b.pressed.connect(func(): Audio.sfx("select"); Game.start_chapter(num))
		grid.add_child(b)
	var back := Game.make_button("رجوع", 16, "blue")
	back.pressed.connect(_close_panels)
	vb.add_child(back)

# ---------------------------------------------------------------- settings (difficulty + sound)
func _build_settings() -> void:
	settings_panel = PanelContainer.new()
	settings_panel.add_theme_stylebox_override("panel", Game.kit("panel_crest", Vector4(30, 20, 30, 20)))
	settings_panel.visible = false
	add_child(settings_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	settings_panel.add_child(vb)
	var tl := Game.make_label("الإعدادات", 26, Game.UI_ACCENT, false)
	tl.add_theme_font_override("font", Game.font_callig)
	tl.add_theme_constant_override("outline_size", 0)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(tl)
	diff_sub = Game.make_label("مستوى الصعوبة", 13, Game.UI_DIM, true)
	diff_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	diff_sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	diff_sub.custom_minimum_size = Vector2(470, 0)
	vb.add_child(diff_sub)
	var row := HBoxContainer.new()
	row.layout_direction = Control.LAYOUT_DIRECTION_RTL
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(row)
	diff_cards.clear()
	for i in range(Game.DIFFICULTY.size()):
		var idx := i
		var b := _diff_card(i, func(): _ask_difficulty(idx), func(): diff_desc.text = _diff_text(idx))
		row.add_child(b)
		diff_cards.append(b)
	diff_desc = Game.make_label("", 12, Game.UI_DIM)
	diff_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	diff_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	diff_desc.custom_minimum_size = Vector2(470, 36)
	vb.add_child(diff_desc)
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 8)
	vb.add_child(srow)
	music_btn = Game.make_button("", 14, "blue")
	music_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	music_btn.pressed.connect(func(): Game.music_on = not Game.music_on; Audio.refresh(); Game.save_game(); _refresh_settings())
	srow.add_child(music_btn)
	sfx_btn = Game.make_button("", 14, "blue")
	sfx_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sfx_btn.pressed.connect(func(): Game.sfx_on = not Game.sfx_on; Game.save_game(); _refresh_settings())
	srow.add_child(sfx_btn)
	voice_btn = Game.make_button("", 14, "blue")
	voice_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	voice_btn.pressed.connect(func(): Game.voice_on = not Game.voice_on; Game.save_game(); _refresh_settings())
	srow.add_child(voice_btn)
	var hint := Game.make_label("الحوار = أصوات الشخصيات والراوي", 11, Game.UI_DIM, false)
	hint.add_theme_constant_override("outline_size", 0)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(hint)
	var back := Game.make_button("تمام", 16, "primary")
	back.pressed.connect(_close_panels)
	vb.add_child(back)
	_refresh_settings()

# One difficulty card (pips + name). Used by the settings panel and the new-adventure screen.
func _diff_card(i: int, on_press: Callable, on_hover: Callable) -> Button:
	var d: Dictionary = Game.DIFFICULTY[i]
	var b := Button.new()
	b.custom_minimum_size = Vector2(150, 74)
	b.focus_mode = Control.FOCUS_ALL
	b.clip_contents = true
	var col: Color = d["color"]
	var vb2 := VBoxContainer.new()
	vb2.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb2.alignment = BoxContainer.ALIGNMENT_CENTER
	vb2.add_theme_constant_override("separation", -4)
	vb2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(vb2)
	var pips := HBoxContainer.new()
	pips.alignment = BoxContainer.ALIGNMENT_CENTER
	pips.add_theme_constant_override("separation", 4)
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k in range(3):
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(10, 10)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pip.add_theme_stylebox_override("panel", Game.style_box(col if k <= i else Color(0.25, 0.2, 0.2), Color(0, 0, 0, 0.6), 1, 5))
		pips.add_child(pip)
	vb2.add_child(pips)
	var nm := Game.make_label(d["name"], 20, Game.UI_TEXT, true)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb2.add_child(nm)
	b.pressed.connect(func(): Audio.sfx("select"); on_press.call())
	b.mouse_entered.connect(on_hover)
	b.focus_entered.connect(on_hover)
	return b

func _style_cards(cards: Array, selected: int, enabled := true) -> void:
	for i in range(cards.size()):
		var b: Button = cards[i]
		var sel := i == selected and enabled
		var sb := Game.style_box(Game.UI_CARD.lightened(0.05) if sel else Game.UI_CARD, Game.UI_ACCENT if sel else Color(1, 1, 1, 0.12), 2 if sel else 1, 8)
		var sbh := sb.duplicate()
		sbh.border_color = Game.UI_ACCENT
		for st in ["normal", "disabled"]:
			b.add_theme_stylebox_override(st, sb)
		for st in ["hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, sbh)
		b.disabled = not enabled
		b.modulate = Color(1, 1, 1) if sel else (Color(0.75, 0.74, 0.74) if enabled else Color(0.5, 0.5, 0.5, 0.8))

func _diff_text(i: int) -> String:
	return str(Game.DIFFICULTY[i]["desc"])

func _refresh_settings() -> void:
	var has := Game.has_adventure()
	_style_cards(diff_cards, Game.difficulty, has)
	if has:
		diff_sub.text = "مستوى صعوبة «%s»" % Game.adv_name
		diff_desc.text = _diff_text(Game.difficulty)
	else:
		diff_sub.text = "مستوى الصعوبة"
		diff_desc.text = "المستوى بيتحدد لكل مغامرة لوحدها.. ابدأ مغامرة جديدة واختار مستواها."
	for pair in [[music_btn, "المزيكا", Game.music_on], [sfx_btn, "المؤثرات", Game.sfx_on], [voice_btn, "الحوار", Game.voice_on]]:
		var bt: Button = pair[0]
		bt.text = "%s  %s" % [pair[1], "●" if pair[2] else "○"]
		bt.add_theme_color_override("font_color", Game.UI_TEXT if pair[2] else Game.UI_DIM)
	_refresh_footer()

# Changing the difficulty of a running adventure restarts it from chapter 1, so ask first.
func _ask_difficulty(idx: int) -> void:
	if not Game.has_adventure() or idx == Game.difficulty:
		return
	var body := "لو غيّرت المستوى لـ«%s»، مغامرة «%s» هتبدأ من أول فصل من جديد،\nوهيتمسح تقدّمك فيها (الفصول والجنيهات والمشتريات).\nعايز تحتفظ بتقدّمك؟ ابدأ مغامرة جديدة بالمستوى ده." % [Game.DIFFICULTY[idx]["name"], Game.adv_name]
	_dialog("تغيير مستوى الصعوبة؟", body, "غيّر وابدأ من الأول", func(_t):
		Game.restart_with_difficulty(idx)
		_refresh_settings()
		_build_menu()
		menu.visible = false, true)

# ---------------------------------------------------------------- panels
func _make_panel(pad: Vector4) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Game.kit("panel_crest", pad))
	p.visible = false
	add_child(p)
	return p

func _show_panel(p: PanelContainer) -> void:
	Audio.sfx("ui_open", 0.0, -4)
	for q in [chapters_panel, settings_panel, new_panel, adv_panel]:
		if q != p:
			q.visible = false
	p.visible = true
	chapters_dim.visible = true
	p.reset_size()
	p.position = (get_viewport_rect().size - p.size) / 2.0
	p.modulate.a = 0.0
	create_tween().tween_property(p, "modulate:a", 1.0, 0.2)
	menu.visible = false

func _close_panels() -> void:
	for q in [chapters_panel, settings_panel, new_panel, adv_panel]:
		q.visible = false
	chapters_dim.visible = false
	_build_menu()
	menu.visible = true
	if menu.get_child_count() > 0 and not Game.touch_enabled():
		var first := menu.get_child(0)
		if first is Button:
			(first as Button).grab_focus()

func _open_settings() -> void:
	_refresh_settings()
	_show_panel(settings_panel)
	if not Game.touch_enabled() and Game.has_adventure():
		(diff_cards[Game.difficulty] as Button).grab_focus()

func _open_chapters() -> void:
	# chapter cards reflect the active adventure
	chapters_panel.queue_free()
	_build_chapters()
	_show_panel(chapters_panel)

func _make_input(placeholder: String) -> LineEdit:
	var e := LineEdit.new()
	e.max_length = Game.NAME_MAX
	e.placeholder_text = placeholder
	e.alignment = HORIZONTAL_ALIGNMENT_CENTER
	e.custom_minimum_size = Vector2(300, 36)
	e.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	e.add_theme_font_override("font", Game.font_body)
	e.add_theme_font_size_override("font_size", 17)
	e.add_theme_color_override("font_color", Game.UI_TEXT)
	e.add_theme_color_override("font_placeholder_color", Color(Game.UI_DIM, 0.7))
	e.add_theme_color_override("caret_color", Game.UI_ACCENT)
	e.add_theme_color_override("selection_color", Color(Game.UI_ACCENT, 0.35))
	e.add_theme_stylebox_override("normal", Game.kit("slot", Vector4(12, 4, 12, 4)))
	e.add_theme_stylebox_override("focus", Game.kit("slot_on", Vector4(12, 4, 12, 4)))
	e.add_theme_stylebox_override("read_only", Game.kit("slot", Vector4(12, 4, 12, 4)))
	return e

func _panel_title(text: String) -> Label:
	var tl := Game.make_label(text, 26, Game.UI_ACCENT, false)
	tl.add_theme_font_override("font", Game.font_callig)
	tl.add_theme_constant_override("outline_size", 0)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return tl

# ---------------------------------------------------------------- new adventure: name + difficulty
func _build_new_adventure() -> void:
	new_panel = _make_panel(Vector4(30, 18, 30, 18))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	new_panel.add_child(vb)
	vb.add_child(_panel_title("مغامرة جديدة"))
	var nl := Game.make_label("اسم المغامرة", 13, Game.UI_DIM, true)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(nl)
	new_name = _make_input("اكتب اسم للمغامرة")
	new_name.text_submitted.connect(func(_t): _start_new_adventure())
	vb.add_child(new_name)
	var sub := Game.make_label("اختار مستوى الصعوبة", 13, Game.UI_DIM, true)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)
	var row := HBoxContainer.new()
	row.layout_direction = Control.LAYOUT_DIRECTION_RTL
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(row)
	new_cards.clear()
	for i in range(Game.DIFFICULTY.size()):
		var idx := i
		var b := _diff_card(i, func(): new_diff = idx; _refresh_new(), func(): new_desc.text = _diff_text(idx))
		row.add_child(b)
		new_cards.append(b)
	new_desc = Game.make_label("", 12, Game.UI_DIM)
	new_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	new_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	new_desc.custom_minimum_size = Vector2(470, 36)
	vb.add_child(new_desc)
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 8)
	vb.add_child(brow)
	var back := Game.make_button("رجوع", 16, "blue")
	back.pressed.connect(_close_panels)
	new_start = Game.make_button("ابدأ المغامرة", 17, "primary")
	new_start.custom_minimum_size = Vector2(0, 40)
	new_start.pressed.connect(_start_new_adventure)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_start.size_flags_stretch_ratio = 1.6
	brow.add_child(back)
	brow.add_child(new_start)

func _refresh_new() -> void:
	_style_cards(new_cards, new_diff, true)
	if Game.can_add_adventure():
		new_desc.text = _diff_text(new_diff)
		new_start.disabled = false
	else:
		new_desc.text = "وصلت لأقصى عدد مغامرات (%d).. امسح مغامرة قديمة من «مغامراتي» الأول." % Game.MAX_ADVENTURES
		new_start.disabled = true

func _open_new_adventure() -> void:
	new_diff = 0
	new_name.text = Game.default_adventure_name()
	_refresh_new()
	_show_panel(new_panel)
	if not Game.touch_enabled():
		(new_cards[new_diff] as Button).grab_focus()

func _start_new_adventure() -> void:
	if not new_panel.visible or not Game.can_add_adventure():
		return
	Game.create_adventure(new_name.text, new_diff)

# ---------------------------------------------------------------- saved adventures
func _build_adventures() -> void:
	adv_panel = _make_panel(Vector4(24, 16, 24, 16))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	adv_panel.add_child(vb)
	vb.add_child(_panel_title("مغامراتي"))
	var hint := Game.make_label("كل مغامرة ليها اسمها ومستواها وتقدّمها.. كمّل اللي تحبه", 11, Game.UI_DIM, false)
	hint.add_theme_constant_override("outline_size", 0)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(hint)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(520, 196)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	adv_list = VBoxContainer.new()
	adv_list.add_theme_constant_override("separation", 6)
	adv_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(adv_list)
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 8)
	vb.add_child(brow)
	var back := Game.make_button("رجوع", 16, "blue")
	back.pressed.connect(_close_panels)
	var nb := Game.make_button("+ مغامرة جديدة", 16)
	nb.pressed.connect(_open_new_adventure)
	for bb in [back, nb]:
		bb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		brow.add_child(bb)

func _fill_adventures() -> void:
	for c in adv_list.get_children():
		adv_list.remove_child(c)
		c.queue_free()
	for a in Game.list_adventures():
		var id := int(a["id"])
		var active := id == Game.adv_id
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", Game.kit("card_t0_sel" if active else "card_t0", Vector4(12, 6, 10, 6)))
		adv_list.add_child(card)
		var h := HBoxContainer.new()
		h.layout_direction = Control.LAYOUT_DIRECTION_RTL
		h.add_theme_constant_override("separation", 6)
		card.add_child(h)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", -4)
		h.add_child(info)
		var nrow := HBoxContainer.new()
		nrow.layout_direction = Control.LAYOUT_DIRECTION_RTL
		nrow.add_theme_constant_override("separation", 6)
		info.add_child(nrow)
		var nm := Game.make_label(str(a["name"]), 17, Game.UI_TEXT, false)
		nm.add_theme_font_override("font", Game.font_button)
		nm.add_theme_constant_override("outline_size", 0)
		nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nm.clip_text = true
		nm.custom_minimum_size = Vector2(60, 0)
		nm.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		nrow.add_child(nm)
		var dd: Dictionary = Game.DIFFICULTY[int(a["difficulty"])]
		var dl := Game.make_label(str(dd["name"]), 11, dd["color"], true)
		dl.add_theme_constant_override("outline_size", 0)
		var dp := PanelContainer.new()
		dp.add_theme_stylebox_override("panel", Game.kit("pill", Vector4(8, 0, 8, 1)))
		dp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dp.add_child(dl)
		nrow.add_child(dp)
		if active:
			var ap := PanelContainer.new()
			ap.add_theme_stylebox_override("panel", Game.kit("plate", Vector4(7, 0, 7, 1)))
			ap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var al := Game.make_label("الحالية", 9, Game.UI_INK, false)
			al.add_theme_font_override("font", Game.font_button)
			al.add_theme_constant_override("outline_size", 0)
			ap.add_child(al)
			nrow.add_child(ap)
		var ch: Dictionary = Game.CHAPTERS[int(a["chapter"])]
		var det := "%s: %s  •  خلّصت %d من %d  •  %d جنيه" % [ch["num"], ch["name"], int(a["completed"]), Game.CHAPTER_COUNT, int(a["wallet"])]
		var dt := Game.make_label(det, 11, Game.UI_DIM, false)
		dt.add_theme_constant_override("outline_size", 0)
		dt.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		dt.clip_text = true
		dt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		info.add_child(dt)
		var play := Game.make_button("العب", 14, "primary")
		play.custom_minimum_size = Vector2(66, 34)
		play.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		play.pressed.connect(func(): Game.play_adventure(id))
		h.add_child(play)
		var ren := Game.make_button("الاسم", 13, "blue")
		ren.custom_minimum_size = Vector2(58, 34)
		ren.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var cur_name := str(a["name"])
		ren.pressed.connect(func(): _dialog("تغيير اسم المغامرة", "", "حفظ", func(t):
			Game.rename_adventure(id, t)
			_fill_adventures(), false, true, cur_name))
		h.add_child(ren)
		var del := Game.make_button("مسح", 13, "blue")
		del.custom_minimum_size = Vector2(52, 34)
		del.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		del.add_theme_color_override("font_color", Game.UI_BAD)
		del.pressed.connect(func(): _dialog("مسح المغامرة؟", "مغامرة «%s» هتتمسح خالص بكل تقدّمها، ومش هينفع ترجّعها." % cur_name, "امسحها", func(_t):
			Game.delete_adventure(id)
			if Game.adventures.is_empty():
				_close_panels()
			else:
				_fill_adventures()
				adv_panel.reset_size()
				adv_panel.position = (get_viewport_rect().size - adv_panel.size) / 2.0, true))
		h.add_child(del)

func _open_adventures() -> void:
	_fill_adventures()
	_show_panel(adv_panel)

# ---------------------------------------------------------------- confirm / rename dialog (on top of panels)
func _build_dialog() -> void:
	dlg_dim = ColorRect.new()
	dlg_dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dlg_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dlg_dim.visible = false
	add_child(dlg_dim)
	dlg_panel = PanelContainer.new()
	dlg_panel.add_theme_stylebox_override("panel", Game.kit("panel_crest", Vector4(28, 18, 28, 18)))
	dlg_panel.visible = false
	dlg_panel.custom_minimum_size = Vector2(400, 0)
	add_child(dlg_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	dlg_panel.add_child(vb)
	dlg_title = _panel_title("")
	dlg_title.add_theme_font_size_override("font_size", 22)
	vb.add_child(dlg_title)
	dlg_body = Game.make_label("", 13, Game.UI_TEXT, false)
	dlg_body.add_theme_constant_override("outline_size", 0)
	dlg_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dlg_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dlg_body.custom_minimum_size = Vector2(440, 0)
	vb.add_child(dlg_body)
	dlg_input = _make_input("اسم المغامرة")
	dlg_input.text_submitted.connect(func(_t): _dialog_yes())
	vb.add_child(dlg_input)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	vb.add_child(row)
	dlg_no = Game.make_button("إلغاء", 16, "blue")
	dlg_no.pressed.connect(_dialog_close)
	dlg_yes = Game.make_button("تمام", 16, "primary")
	dlg_yes.pressed.connect(_dialog_yes)
	for bb in [dlg_no, dlg_yes]:
		bb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bb.custom_minimum_size = Vector2(0, 38)
		row.add_child(bb)

# body = message; with_input shows a name box (prefilled with text) and passes its text to cb.
func _dialog(title: String, body: String, yes_text: String, cb: Callable, danger := true, with_input := false, text := "") -> void:
	Audio.sfx("ui_open", 0.0, -4)
	dlg_cb = cb
	dlg_title.text = title
	dlg_body.text = body
	dlg_body.visible = body != ""
	dlg_input.visible = with_input
	dlg_input.text = text
	dlg_yes.text = yes_text
	var col := Game.UI_BAD if danger else Game.UI_INK
	dlg_yes.add_theme_color_override("font_color", col)
	dlg_yes.add_theme_color_override("font_hover_color", col)
	dlg_yes.add_theme_color_override("font_focus_color", col)
	dlg_yes.add_theme_color_override("font_pressed_color", col)
	for st in ["normal", "hover", "pressed", "focus"]:
		var k: String = {"normal": "btn", "hover": "btn_hi", "pressed": "btn_press", "focus": "btn_hi"}[st] if not danger else {"normal": "btn_red", "hover": "btn_red_hi", "pressed": "btn_red_press", "focus": "btn_red_hi"}[st]
		dlg_yes.add_theme_stylebox_override(st, Game.kit(k, Vector4(18, 4, 18, 6)))
	dlg_dim.visible = true
	dlg_panel.visible = true
	move_child(dlg_dim, get_child_count() - 1)
	move_child(dlg_panel, get_child_count() - 1)
	dlg_panel.reset_size()
	dlg_panel.position = (get_viewport_rect().size - dlg_panel.size) / 2.0
	dlg_panel.modulate.a = 0.0
	create_tween().tween_property(dlg_panel, "modulate:a", 1.0, 0.15)
	if with_input:
		dlg_input.grab_focus()
		dlg_input.select_all()
	elif not Game.touch_enabled():
		dlg_no.grab_focus()

func _dialog_close() -> void:
	dlg_panel.visible = false
	dlg_dim.visible = false

func _dialog_yes() -> void:
	if not dlg_panel.visible:
		return
	if dlg_input.visible and Game.clean_name(dlg_input.text) == "":
		return
	var cb := dlg_cb
	var t := dlg_input.text
	_dialog_close()
	if cb.is_valid():
		cb.call(t)

func _autotest() -> void:
	await get_tree().create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://shots")
	get_viewport().get_texture().get_image().save_png("user://shots/title.png")
	_open_chapters()
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://shots/title_chapters.png")
	chapters_panel.visible = false
	_open_settings()
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://shots/title_settings.png")
	_open_new_adventure()
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://shots/new_adventure.png")
	new_panel.visible = false
	_open_adventures()
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://shots/my_adventures.png")
	adv_panel.visible = false
	_open_settings()
	_ask_difficulty(1 if Game.difficulty == 0 else 0)
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://shots/settings_warning.png")
	_dialog_close()
	settings_panel.visible = false
	chapters_dim.visible = false
	print("AUTOTEST title ok")
	var m := Game.autotest
	if m.begins_with("shot"):
		var parts := m.substr(4).split("_")
		var n := int(parts[0]) if parts.size() > 0 and parts[0] != "" else 1
		if parts.size() > 1:
			Game.difficulty = clampi(int(parts[1]), 0, 2)
		Game.chapter = n
		Game.clear_checkpoint()
		if n >= 7:
			Game.owned = Game.Catalog.WEAPONS.duplicate()
			Game.equipped = Game.Catalog.WEAPONS[(n - 7) % Game.Catalog.WEAPONS.size()]
			Game.loadout = [Game.equipped, "stick" if Game.equipped != "stick" else "saber"]
			Game.inventory = {"potion": 2, "bomb": 2}
		Game.goto_level()
	elif m == "shop":
		Game.wallet = 520
		Game.unlocked = 8
		Game.open_shop(8)
	elif m == "moves" or m == "ambush":
		Game.chapter = 1 if m == "moves" else 4
		Game.clear_checkpoint()
		Game.goto_level()
	elif m.begins_with("ui"):
		Game.chapter = int(m.substr(2)) if m.length() > 2 else 1
		Game.clear_checkpoint()
		Game.goto_level()
	elif m == "vis":
		Game.chapter = 1
		Game.clear_checkpoint()
		Game.goto_level()
	elif m.begins_with("story"):
		var sid := m.substr(6) if m.length() > 6 else "prologue"
		Game.play_story(sid, "title")
	else:
		get_tree().quit()
