extends CanvasLayer
# In-game HUD for phones: status panel, boss bar, toasts, chapter title card, in-level dialogs,
# pause menu and multi-touch controls (floating move stick + big action buttons).

const StoryData = preload("res://scripts/story_data.gd")
const TouchPad = preload("res://scripts/touch_pad.gd")
const DialogBox = preload("res://scripts/dialog_box.gd")
const FxDraw = preload("res://scripts/fx_draw.gd")

var level: Node = null
var root: Control
var status: PanelContainer
var hearts: HBoxContainer
var coin_label: Label
var coin_icon: TextureRect
var gear_label: Label
var boss_box: VBoxContainer
var boss_bar: ProgressBar
var boss_name: Label
var toast_panel: PanelContainer
var toast_label: Label
var toast_tw: Tween
var title_card: Control
var dialog_root: Control
var box: Control
var portrait_frame: PanelContainer
var d_text: Label
var dialog_lines: Array = []
var dialog_i := 0
var dialog_cb: Callable
var dialog_active := false
var typing := false
var type_acc := 0.0
var pause_dim: ColorRect
var pause_panel: PanelContainer
var music_btn: Button
var sfx_btn: Button
var voice_btn: Button
var pause_stats: Label
var pad: Control
var heart_full: AtlasTexture
var heart_empty: AtlasTexture
var t := 0.0
var shown_hp := -1
var shown_max := -1
var foes_panel: PanelContainer
var foes_label: Label
var foes_arrow: Label
var foes_alert := false

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var itex: Texture2D = load("res://assets/sprites/items.png")
	heart_full = AtlasTexture.new()
	heart_full.atlas = itex
	heart_full.region = Rect2(192 + 5, 5, 22, 21)
	heart_empty = AtlasTexture.new()
	heart_empty.atlas = itex
	heart_empty.region = Rect2(256 + 5, 5, 22, 21)
	_build_status()
	_build_boss()
	_build_foes()
	_build_toast()
	_build_title_card()
	pad = TouchPad.new()
	pad.hud = self
	root.add_child(pad)
	_build_dialog()
	_build_pause()
	refresh()
	get_viewport().size_changed.connect(_layout)
	_layout()

# ---------------------------------------------------------------- status panel (portrait, hearts, coins)
func _build_status() -> void:
	status = PanelContainer.new()
	status.add_theme_stylebox_override("panel", Game.ui_box("panel_small", Vector4(9, 7, 12, 7)))
	status.position = Vector2(10, 8)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(status)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.add_child(hb)
	var pf := PanelContainer.new()
	var pfs := Game.style_box(Color(0.12, 0.11, 0.12), Color(1, 1, 1, 0.18), 1, 6)
	pfs.content_margin_left = 0; pfs.content_margin_right = 0; pfs.content_margin_top = 0; pfs.content_margin_bottom = 0
	pf.add_theme_stylebox_override("panel", pfs)
	hb.add_child(pf)
	var face := TextureRect.new()
	face.texture = load("res://assets/art/p_selim.png")
	face.custom_minimum_size = Vector2(40, 40)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	face.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	pf.add_child(face)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 1)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_child(vb)
	hearts = HBoxContainer.new()
	hearts.add_theme_constant_override("separation", 1)
	vb.add_child(hearts)
	var crow := HBoxContainer.new()
	crow.add_theme_constant_override("separation", 3)
	vb.add_child(crow)
	coin_icon = TextureRect.new()
	var cat := AtlasTexture.new()
	cat.atlas = load("res://assets/sprites/items.png")
	cat.region = Rect2(5, 5, 22, 22)
	coin_icon.texture = cat
	coin_icon.custom_minimum_size = Vector2(18, 18)
	coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin_icon.pivot_offset = Vector2(9, 9)
	crow.add_child(coin_icon)
	coin_label = Game.make_label("0", 17, Color(1, 0.86, 0.36), true)
	crow.add_child(coin_label)
	gear_label = Game.make_label("", 10, Color(1, 0.95, 0.82), true)
	crow.add_child(gear_label)

func _build_boss() -> void:
	boss_box = VBoxContainer.new()
	boss_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	boss_box.custom_minimum_size = Vector2(300, 0)
	boss_box.position = Vector2(-150, 68)
	boss_box.add_theme_constant_override("separation", 0)
	boss_box.visible = false
	boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(boss_box)
	boss_name = Game.make_label("", 17, Color(1, 0.82, 0.55), true)
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_box.add_child(boss_name)
	boss_bar = ProgressBar.new()
	boss_bar.custom_minimum_size = Vector2(300, 14)
	boss_bar.show_percentage = false
	boss_bar.fill_mode = ProgressBar.FILL_END_TO_BEGIN
	var bg := Game.tex_box("bar_bg", 5, Vector4(0, 0, 0, 0))
	var fill := Game.tex_box("bar_fill", 2, Vector4(0, 0, 0, 0))
	fill.expand_margin_left = -3; fill.expand_margin_right = -3; fill.expand_margin_top = -3; fill.expand_margin_bottom = -3
	boss_bar.add_theme_stylebox_override("background", bg)
	boss_bar.add_theme_stylebox_override("fill", fill)
	boss_box.add_child(boss_bar)

# Enemies-left chip (top centre). Turns red with a pointer towards the nearest fighter when the
# clear-all barrier before the boss is blocking the way.
func _build_foes() -> void:
	foes_panel = PanelContainer.new()
	foes_panel.add_theme_stylebox_override("panel", Game.kit("panel_small", Vector4(12, 3, 12, 5)))
	foes_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(foes_panel)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foes_panel.add_child(hb)
	foes_label = Game.make_label("", 13, Color(1, 0.93, 0.8), true)
	hb.add_child(foes_label)
	foes_arrow = Game.make_label("", 26, Color(1, 0.4, 0.3), true)
	var tri := Polygon2D.new()
	tri.polygon = PackedVector2Array([Vector2(0, 10), Vector2(16, 0), Vector2(16, 20)])
	tri.color = Color(1, 0.35, 0.25)
	foes_arrow.add_child(tri)
	foes_arrow.visible = false
	foes_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(foes_arrow)

func set_remaining(n: int, alert: bool) -> void:
	if n < 0:
		foes_panel.visible = false
		foes_arrow.visible = false
		return
	foes_panel.visible = true
	foes_alert = alert and n > 0
	foes_label.text = ("الأعداء الباقيين: %d" % n) if n > 0 else "الطريق مفتوح"
	foes_label.add_theme_color_override("font_color", Color(1, 0.55, 0.45) if foes_alert else (Color(0.6, 1, 0.6) if n == 0 else Color(1, 0.93, 0.8)))
	foes_panel.reset_size()
	foes_panel.position = Vector2((get_viewport().get_visible_rect().size.x - foes_panel.size.x) / 2.0, 8)

func _build_toast() -> void:
	toast_panel = PanelContainer.new()
	toast_panel.add_theme_stylebox_override("panel", Game.kit("panel", Vector4(16, 6, 16, 8)))
	toast_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_panel.modulate.a = 0.0
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_panel)
	toast_label = Game.make_label("", 16, Color(1, 0.95, 0.78), true)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_panel.add_child(toast_label)

func _build_title_card() -> void:
	title_card = Control.new()
	title_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_card.modulate.a = 0.0
	root.add_child(title_card)

# ---------------------------------------------------------------- dialog (in-level, boss intros)
func _build_dialog() -> void:
	dialog_root = Control.new()
	dialog_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	dialog_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog_root.visible = false
	root.add_child(dialog_root)
	var shade := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(0, 0, 0, 0.7))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	shade.texture = gt
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.anchor_top = 0.45
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog_root.add_child(shade)
	box = DialogBox.new()
	box.bottom = 8.0
	box.portrait_h = 112.0
	dialog_root.add_child(box)
	d_text = box.text_l
	portrait_frame = box.portrait_frame

func _build_pause() -> void:
	pause_dim = ColorRect.new()
	pause_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/blur_dim.gdshader")
	pause_dim.material = mat
	pause_dim.visible = false
	root.add_child(pause_dim)
	pause_panel = PanelContainer.new()
	pause_panel.add_theme_stylebox_override("panel", Game.kit("panel_crest", Vector4(34, 22, 34, 22)))
	pause_panel.visible = false
	root.add_child(pause_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	pause_panel.add_child(vb)
	var tl := Game.make_label("استراحة", 34, Game.UI_ACCENT, false)
	tl.add_theme_font_override("font", Game.font_callig)
	tl.add_theme_constant_override("outline_size", 0)
	tl.add_theme_constant_override("shadow_offset_y", 2)
	tl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(tl)
	var c: Dictionary = Game.CHAPTERS[Game.chapter]
	var chl := Game.make_label("%s  •  %s" % [c["num"], c["name"]], 15, Game.UI_TEXT, false)
	chl.add_theme_font_override("font", Game.font_button)
	chl.add_theme_constant_override("outline_size", 0)
	chl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(chl)
	var div := FxDraw.new("divider", Game.UI_ACCENT)
	div.custom_minimum_size = Vector2(220, 10)
	div.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(div)
	pause_stats = Game.make_label("", 12, Game.UI_DIM, false)
	pause_stats.add_theme_constant_override("outline_size", 0)
	pause_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(pause_stats)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 2)
	vb.add_child(sp)
	var b1 := Game.make_button("كمّل اللعب", 18, "green")
	b1.custom_minimum_size = Vector2(0, 40)
	b1.pressed.connect(toggle_pause)
	vb.add_child(b1)
	var b2 := Game.make_button("ارجع لنقطة الحفظ", 16)
	b2.pressed.connect(func(): get_tree().paused = false; Audio.set_muffle(false); Voice.set_paused(false); Game.reload_level())
	vb.add_child(b2)
	var b3 := Game.make_button("القائمة الرئيسية", 16)
	b3.pressed.connect(func(): get_tree().paused = false; Audio.set_muffle(false); Voice.set_paused(false); Voice.stop_world(); Game.goto_title())
	vb.add_child(b3)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	vb.add_child(row)
	music_btn = Game.make_button("", 13, "blue")
	music_btn.pressed.connect(func(): Game.music_on = not Game.music_on; Audio.refresh(); Game.save_game(); _pause_labels())
	sfx_btn = Game.make_button("", 13, "blue")
	sfx_btn.pressed.connect(func(): Game.sfx_on = not Game.sfx_on; Game.save_game(); _pause_labels())
	voice_btn = Game.make_button("", 13, "blue")
	voice_btn.pressed.connect(_toggle_voice)
	for bb in [voice_btn, sfx_btn, music_btn]:
		bb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bb.custom_minimum_size = Vector2(0, 32)
		row.add_child(bb)
	pause_panel.custom_minimum_size = Vector2(380, 0)
	_pause_labels()

func _toggle_voice() -> void:
	Game.voice_on = not Game.voice_on
	Game.save_game()
	if not Game.voice_on:
		Voice.stop_world()
	_pause_labels()

func _pause_labels() -> void:
	for pair in [[music_btn, "المزيكا", Game.music_on], [sfx_btn, "المؤثرات", Game.sfx_on], [voice_btn, "الحوار", Game.voice_on]]:
		var b: Button = pair[0]
		b.text = "%s  %s" % [pair[1], "●" if pair[2] else "○"]
		b.add_theme_color_override("font_color", Game.UI_TEXT if pair[2] else Game.UI_DIM)
	if pause_stats != null:
		pause_stats.text = "الفلوس: %d جنيه     •     المستوى: %s     •     الوقعات: %d" % [Game.coins, Game.diff()["name"], Game.deaths]

func _layout() -> void:
	var s := get_viewport().get_visible_rect().size
	var m := 10.0 + maxf(0.0, (s.x - 640.0) * 0.06)
	# keep controls and panels clear of phone notches / rounded corners
	var safe := Game.safe_inset()
	m = maxf(m, maxf(safe.x, safe.z) + 6.0)
	status.position = Vector2(m, 8.0 + safe.y)
	toast_panel.reset_size()
	toast_panel.position = Vector2((get_viewport().get_visible_rect().size.x - toast_panel.size.x) / 2.0, 62)
	if dialog_active:
		_place_line()
	if pause_panel.visible:
		pause_panel.pivot_offset = pause_panel.size / 2.0
	if pause_panel.visible:
		pause_panel.reset_size()
		pause_panel.position = (s - pause_panel.size) / 2.0
	if pad != null:
		pad.layout(s, m)

func refresh() -> void:
	coin_label.text = str(Game.coins)
	var other := ""
	if Game.can_switch():
		other = " / " + str(Game.Catalog.ITEMS[str(Game.loadout[1]) if Game.equipped == str(Game.loadout[0]) else str(Game.loadout[0])]["name"])
	gear_label.text = "  %s%s  إسعاف %d  دخان %d" % [Game.weapon_data()["name"], other, Game.inventory["potion"], Game.inventory["bomb"]]
	if pad != null:
		pad.update_counts()
	if level == null or level.player == null:
		return
	var p = level.player
	if p.hp == shown_hp and p.max_hp == shown_max:
		return
	var lost: bool = shown_hp > p.hp
	shown_hp = p.hp
	shown_max = p.max_hp
	for c in hearts.get_children():
		c.queue_free()
	for i in range(int(ceil(p.max_hp / 2.0))):
		var tr := TextureRect.new()
		tr.texture = heart_full if i * 2 + 2 <= p.hp else heart_empty
		tr.custom_minimum_size = Vector2(22, 21)
		tr.pivot_offset = Vector2(11, 10)
		hearts.add_child(tr)
		if i * 2 + 1 == p.hp:
			var half := TextureRect.new()
			half.texture = heart_full
			half.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			half.size = Vector2(22, 21)
			var clip := Control.new()
			clip.size = Vector2(11, 21)
			clip.clip_contents = true
			clip.add_child(half)
			tr.add_child(clip)
		if lost and i == int(p.hp / 2):
			tr.scale = Vector2(1.6, 1.6)
			var tw := tr.create_tween()
			tw.tween_property(tr, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)

func coin_bump() -> void:
	coin_label.text = str(Game.coins)
	coin_icon.scale = Vector2(1.35, 1.35)
	var tw := coin_icon.create_tween()
	tw.tween_property(coin_icon, "scale", Vector2.ONE, 0.18)

func _process(delta: float) -> void:
	t += delta
	if level != null and level.player != null and not level.player.is_connected("hp_changed", _on_hp):
		level.player.hp_changed.connect(_on_hp)
		refresh()
	if coin_label.text != str(Game.coins):
		coin_bump()
	if foes_alert and level != null and level.player != null and not dialog_active:
		var e = level.nearest_remaining()
		if e != null:
			var left: bool = e.global_position.x < level.player.global_position.x
			var s := get_viewport().get_visible_rect().size
			foes_arrow.visible = true
			foes_arrow.scale = Vector2(1, 1) if left else Vector2(-1, 1)
			foes_arrow.position = Vector2(14.0 if left else s.x - 14.0, s.y * 0.45 + sin(t * 6.0) * 3.0)
			foes_arrow.modulate.a = 0.6 + 0.4 * sin(t * 8.0)
		else:
			foes_arrow.visible = false
	elif foes_arrow.visible:
		foes_arrow.visible = false
	if Input.is_action_just_pressed("pause") and not dialog_active:
		toggle_pause()
	if dialog_active:
		typing = box.typing

func _on_hp(_h: int, _m: int) -> void:
	refresh()

func toggle_pause() -> void:
	if level != null and level.player != null and level.player.dead:
		return
	var p := not get_tree().paused
	get_tree().paused = p
	pause_panel.visible = p
	pause_dim.visible = p
	pad.release_all()
	Audio.set_muffle(p)
	Voice.set_paused(p)
	if not p:
		Audio.sfx("ui_back", 0.0, -4)
	if p:
		_pause_labels()
		(pause_dim.material as ShaderMaterial).set_shader_parameter("amount", 0.0)
		create_tween().tween_method(func(v): (pause_dim.material as ShaderMaterial).set_shader_parameter("amount", v), 0.0, 1.0, 0.25)
		pause_panel.reset_size()
		pause_panel.position = (get_viewport().get_visible_rect().size - pause_panel.size) / 2.0
		pause_panel.pivot_offset = pause_panel.size / 2.0
		pause_panel.scale = Vector2(0.92, 0.92)
		pause_panel.modulate.a = 0.0
		var ptw := create_tween().set_parallel(true)
		ptw.tween_property(pause_panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		ptw.tween_property(pause_panel, "modulate:a", 1.0, 0.12)
		Audio.sfx("ui_open", 0.0, -3)

func toast(txt: String) -> void:
	toast_label.text = txt
	toast_panel.reset_size()
	toast_panel.position = Vector2((get_viewport().get_visible_rect().size.x - toast_panel.size.x) / 2.0, 62)
	if toast_tw != null and toast_tw.is_valid():
		toast_tw.kill()
	toast_panel.modulate.a = 0.0
	toast_panel.scale = Vector2(0.9, 0.9)
	toast_panel.pivot_offset = toast_panel.size / 2.0
	toast_tw = create_tween()
	toast_tw.tween_property(toast_panel, "modulate:a", 1.0, 0.15)
	toast_tw.parallel().tween_property(toast_panel, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)
	toast_tw.tween_interval(2.2)
	toast_tw.tween_property(toast_panel, "modulate:a", 0.0, 0.5)

func bark(speaker: String, text: String) -> void:
	var info: Array = StoryData.SPEAKERS.get(speaker, ["", ""])
	toast("%s: %s" % [info[0], text])
	Voice.play_world(speaker, text)

# cinematic chapter title: gold band across the screen
func show_title(num: String, name: String, place: String) -> void:
	for c in title_card.get_children():
		c.queue_free()
	var band := ColorRect.new()
	band.color = Color(0.03, 0.01, 0.03, 0.72)
	band.set_anchors_preset(Control.PRESET_HCENTER_WIDE)
	band.offset_top = -62
	band.offset_bottom = 58
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_card.add_child(band)
	band.anchor_top = 0.5
	band.anchor_bottom = 0.5
	for yy in [-62, 56]:
		var line := ColorRect.new()
		line.color = Color(Game.UI_ACCENT, 0.55)
		line.set_anchors_preset(Control.PRESET_HCENTER_WIDE)
		line.offset_top = yy
		line.offset_bottom = yy + 1
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_card.add_child(line)
		line.anchor_top = 0.5
		line.anchor_bottom = 0.5
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_CENTER)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 0)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_card.add_child(vb)
	vb.anchor_top = 0.5
	vb.anchor_bottom = 0.5
	var rib := PanelContainer.new()
	rib.add_theme_stylebox_override("panel", Game.ui_box("ribbon", Vector4(54, 3, 54, 9)))
	rib.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rib.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(rib)
	var a := Game.make_label(num, 18, Game.UI_ACCENT, true)
	a.add_theme_font_override("font", Game.font_callig)
	a.add_theme_constant_override("outline_size", 0)
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rib.add_child(a)
	var b := Game.make_label(name, 46, Color(1, 0.96, 0.85), true)
	b.add_theme_constant_override("outline_size", 6)
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	var c2 := Game.make_label("— %s —" % place, 17, Color(1, 0.88, 0.6))
	c2.add_theme_font_override("font", Game.font_callig)
	for l in [b, c2]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(l)
	vb.reset_size()
	vb.position = (get_viewport().get_visible_rect().size - vb.size) / 2.0 + Vector2(0, -4)
	title_card.modulate.a = 0.0
	title_card.scale = Vector2(1, 1)
	b.pivot_offset = b.size / 2.0
	var tw := create_tween()
	tw.tween_interval(0.25)
	tw.tween_property(title_card, "modulate:a", 1.0, 0.5)
	tw.tween_interval(2.2)
	tw.tween_property(title_card, "modulate:a", 0.0, 0.8)

func show_boss(nm: String, hp: int, max_hp: int) -> void:
	boss_name.text = nm
	boss_bar.max_value = max_hp
	boss_bar.value = hp
	boss_box.visible = true
	boss_box.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(boss_box, "modulate:a", 1.0, 0.4)

func set_boss_hp(hp: int, max_hp: int) -> void:
	boss_bar.max_value = max_hp
	var tw := create_tween()
	tw.tween_property(boss_bar, "value", float(maxi(hp, 0)), 0.15)

func hide_boss() -> void:
	boss_box.visible = false

# ---------------------------------------------------------------- dialog
func dialog(lines: Array, cb: Callable) -> void:
	dialog_lines = lines
	dialog_i = 0
	dialog_cb = cb
	dialog_active = true
	Game.dialog_open = true
	for b in get_tree().get_nodes_in_group("speech_bubble"):
		(b as CanvasItem).visible = false
	dialog_root.visible = true
	pad.release_all()
	pad.visible = false
	status.visible = false
	_show_line()

func _show_line() -> void:
	var line: Array = dialog_lines[dialog_i]
	Voice.stop_world()
	_place_line()
	box.show_line(line[0], line[1], "boss_intro")
	typing = true

func _place_line() -> void:
	var s := get_viewport().get_visible_rect().size
	var m := 10.0 + maxf(0.0, (s.x - 640.0) * 0.06)
	var safe := Game.safe_inset()
	m = maxf(m, maxf(safe.x, safe.z) + 6.0)
	box.margin = m + 4.0
	box.bottom = 8.0 + safe.w
	box.layout_box()

func _advance() -> void:
	if box.skip_typing():
		typing = false
		return
	Voice.stop()
	dialog_i += 1
	Audio.sfx("select", 0.05, -6)
	if dialog_i >= dialog_lines.size():
		dialog_active = false
		Game.dialog_open = false
		dialog_root.visible = false
		pad.visible = Game.touch_enabled()
		status.visible = true
		await get_tree().create_timer(0.15).timeout
		if dialog_cb.is_valid():
			dialog_cb.call()
		return
	_show_line()

func _input(event: InputEvent) -> void:
	if not dialog_active:
		return
	var press := false
	if event is InputEventScreenTouch and event.pressed:
		press = true
	elif event.is_action_pressed("accept") or event.is_action_pressed("attack") or event.is_action_pressed("jump"):
		press = true
	if press:
		get_viewport().set_input_as_handled()
		_advance()
