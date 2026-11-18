extends Control
# Uncle Saber's market (v6). Full-screen showroom:
#  * left: Selim on a lit pedestal in front of the counter, big enough to admire, previewing whatever weapon
#    is selected with a looping showcase of his moves; under him the two loadout slots (only these two
#    weapons are carried into a chapter and can be swapped while playing).
#  * right: tabs, a grid of rarity-framed item cards and a detail panel with stats and actions.
# Prices are steep (see catalog.gd): buying is a real decision.

const Catalog = preload("res://scripts/catalog.gd")
const KEEPER := "عم صابر"
const HELLO := ["أهلاً يا سليم! بضاعتي غالية بس أصلي.", "تعالى يا بطل، الرحلة الجاية محتاجة عدة تقيلة.", "نوّرت الدكان يا ابن الحاج! اختار بعقل.", "الحاجة الحلوة غالية يا سليم.. لم جنيهاتك."]
const SHOWCASE := ["atk1", "atk2", "kick", "atk3", "rhkick", "idle", "upper", "sweep", "idle"]

var tab := "weapon"
var selected := ""
var icons_tex: Texture2D
var bg: TextureRect
var shade: TextureRect
var header: Control
var wallet_box: PanelContainer
var wallet_label: Label
var title_label: Label
var go_btn: Button
var tabs := {}
var grid_root: Control
var cards := {}
var detail: PanelContainer
var d_root: Control
var d_icon_box: Panel
var d_icon: TextureRect
var d_name: Label
var d_tier: Label
var d_desc: Label
var d_extra: Control
var act_main: Button
var act_s1: Button
var act_s2: Button
var stage: Control
var spot: TextureRect
var pedestal: TextureRect
var selim_root: Node2D
var selim: AnimatedSprite2D
var preview_id := ""
var show_i := 0
var show_t := 0.0
var try_tag: Label
var sparkles: CPUParticles2D
var bubble: PanelContainer
var bubble_label: Label
var slots: Array = []
var slot_hint: Label
var t := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icons_tex = load("res://assets/ui/shop_icons_v2.png")
	bg = TextureRect.new()
	bg.texture = load("res://assets/ui/shop_bg_v8.jpg")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	bg.flip_h = false  # keeper and counter already on the left, behind Selim
	add_child(bg)
	shade = TextureRect.new()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.36, 0.5, 1.0])
	g.colors = PackedColorArray([Color(0.02, 0.02, 0.03, 0.10), Color(0.02, 0.02, 0.03, 0.10), Color(0.02, 0.02, 0.03, 0.70), Color(0.02, 0.02, 0.03, 0.82)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	shade.texture = gt
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	_build_stage()
	_build_header()
	_build_tabs()
	grid_root = Control.new()
	grid_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(grid_root)
	_build_detail()
	get_viewport().size_changed.connect(_layout)
	wallet_label.text = "%d جنيه" % Game.wallet
	_layout()
	_select_tab("weapon")
	_say(HELLO[randi() % HELLO.size()])
	Audio.play_music("title")
	if Game.autotest != "":
		_autotest()

# ---------------------------------------------------------------- helpers
func _icon(id: String) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = icons_tex
	at.region = Rect2(int(Catalog.ITEMS[id]["icon"]) * 128, 0, 128, 128)
	return at

func _coin_icon() -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = icons_tex
	at.region = Rect2(6 * 128, 0, 128, 128)
	return at

func _tex_rect(tex: Texture2D, sz: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.texture = tex
	r.size = sz
	r.custom_minimum_size = sz
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

func _lbl(text: String, size: int, col: Color, title := true) -> Label:
	var l := Game.make_label(text, size, col, title)
	if not title:
		l.add_theme_font_override("font", Game.font_body)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _box(name: String, _margin := 14, pad := Vector4(10, 6, 10, 6)) -> StyleBox:
	return Game.kit(name, pad)

func _style_button(b: Button, normal: String, hover: String, disabled := "btn_off", size := 16) -> void:
	var primary := normal.begins_with("btn_buy") or normal == "btn_green"
	b.add_theme_font_override("font", Game.font_button)
	b.add_theme_font_size_override("font_size", size - 1)
	b.add_theme_color_override("font_color", Game.UI_INK if primary else Game.UI_TEXT)
	b.add_theme_color_override("font_hover_color", Game.UI_INK if primary else Color(1, 1, 1))
	b.add_theme_color_override("font_pressed_color", Game.UI_INK if primary else Game.UI_ACCENT)
	b.add_theme_color_override("font_focus_color", Game.UI_INK if primary else Color(1, 1, 1))
	b.add_theme_color_override("font_disabled_color", Color(Game.UI_DIM, 0.75))
	b.add_theme_constant_override("outline_size", 0)
	b.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.02))
	b.add_theme_stylebox_override("normal", _box(normal, 14, Vector4(10, 2, 10, 4)))
	b.add_theme_stylebox_override("hover", _box(hover, 14, Vector4(10, 2, 10, 4)))
	b.add_theme_stylebox_override("pressed", _box(hover, 14, Vector4(10, 3, 10, 3)))
	b.add_theme_stylebox_override("focus", _box(hover, 14, Vector4(10, 2, 10, 4)))
	b.add_theme_stylebox_override("disabled", _box(disabled, 14, Vector4(10, 2, 10, 4)))

func _tab_box(on: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.0)
	sb.border_color = Game.UI_ACCENT if on else Color(1, 1, 1, 0.10)
	sb.border_width_bottom = 2 if on else 1
	sb.content_margin_left = 8; sb.content_margin_right = 8; sb.content_margin_top = 0; sb.content_margin_bottom = 3
	return sb

# soft oval of light under Selim instead of the old ornate pedestal
func _floor_glow() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.88, 0.65, 0.35))
	g.set_color(1, Color(1.0, 0.85, 0.6, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 128
	gt.height = 44
	return gt

# ---------------------------------------------------------------- stage (Selim + loadout)
func _build_stage() -> void:
	stage = Control.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	spot = TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.85, 0.6, 0.22))
	g.set_color(1, Color(1.0, 0.8, 0.5, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.75)
	gt.fill_to = Vector2(1.0, 0.75)
	gt.width = 128
	gt.height = 128
	spot.texture = gt
	spot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	spot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(spot)
	pedestal = _tex_rect(_floor_glow(), Vector2(200, 69))
	stage.add_child(pedestal)
	selim_root = Node2D.new()
	stage.add_child(selim_root)
	selim = AnimatedSprite2D.new()
	selim.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	selim_root.add_child(selim)
	selim.animation_finished.connect(func(): if selim.animation != "idle": selim.play("idle"))
	sparkles = CPUParticles2D.new()
	sparkles.emitting = false
	sparkles.one_shot = true
	sparkles.amount = 40
	sparkles.lifetime = 0.9
	sparkles.explosiveness = 0.9
	sparkles.position = Vector2(0, -70)
	sparkles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	sparkles.emission_sphere_radius = 34.0
	sparkles.direction = Vector2(0, -1)
	sparkles.spread = 180.0
	sparkles.initial_velocity_min = 50.0
	sparkles.initial_velocity_max = 130.0
	sparkles.gravity = Vector2(0, 140)
	sparkles.scale_amount_min = 1.5
	sparkles.scale_amount_max = 3.5
	sparkles.color = Color(1.0, 0.9, 0.7)
	selim_root.add_child(sparkles)
	try_tag = _lbl("معاينة", 12, Game.UI_DIM)
	try_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	try_tag.size = Vector2(100, 18)
	try_tag.visible = false
	stage.add_child(try_tag)
	# keeper speech bubble
	bubble = PanelContainer.new()
	var sb := Game.kit("panel", Vector4(12, 6, 12, 8))
	bubble.add_theme_stylebox_override("panel", sb)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(bubble)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.add_child(v)
	var who := _lbl(KEEPER, 11, Game.UI_ACCENT)
	who.add_theme_constant_override("outline_size", 0)
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(who)
	bubble_label = _lbl("", 12, Game.UI_TEXT, false)
	bubble_label.add_theme_constant_override("outline_size", 0)
	bubble_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bubble_label.custom_minimum_size = Vector2(190, 0)
	bubble_label.add_theme_constant_override("line_spacing", -2)
	v.add_child(bubble_label)
	# loadout slots
	for i in range(Catalog.LOADOUT_SIZE):
		var b := Button.new()
		b.focus_mode = Control.FOCUS_ALL
		b.custom_minimum_size = Vector2(62, 62)
		b.size = Vector2(62, 62)
		var ic := _tex_rect(null, Vector2(48, 48))
		ic.position = Vector2(7, 5)
		ic.name = "Icon"
		b.add_child(ic)
		var num := _lbl(["١", "٢"][i], 12, Game.UI_DIM)
		num.position = Vector2(4, 40)
		num.name = "Num"
		b.add_child(num)
		var cap := _lbl(["السلاح الأول", "السلاح التاني"][i], 10, Game.UI_TEXT)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.size = Vector2(90, 14)
		cap.position = Vector2(-14, 62)
		cap.name = "Cap"
		b.add_child(cap)
		var idx := i
		b.pressed.connect(func(): _slot_pressed(idx))
		stage.add_child(b)
		slots.append(b)
	slot_hint = _lbl("السلاحين دول اللي هتدخل بيهم الفصل", 10, Game.UI_DIM, false)
	slot_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	slot_hint.clip_text = false
	stage.add_child(slot_hint)
	_show_weapon(Game.equipped, false)

func _refresh_slots() -> void:
	for i in range(slots.size()):
		var b: Button = slots[i]
		var id := str(Game.loadout[i])
		var on := id != "" and id == Game.equipped
		var nm := "slot_on" if on else "slot"
		for st in ["normal", "disabled"]:
			b.add_theme_stylebox_override(st, _box(nm, 16, Vector4(0, 0, 0, 0)))
		for st in ["hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, _box("slot_on", 16, Vector4(0, 0, 0, 0)))
		var ic: TextureRect = b.get_node("Icon")
		ic.texture = _icon(id) if id != "" else null
		var cap: Label = b.get_node("Cap")
		cap.text = str(Catalog.ITEMS[id]["name"]) if id != "" else "فاضي"
		cap.add_theme_color_override("font_color", Game.UI_ACCENT if on else (Game.UI_TEXT if id != "" else Game.UI_DIM))

func _slot_pressed(i: int) -> void:
	var id := str(Game.loadout[i])
	_select_tab("weapon")
	if id != "":
		_select(id)
	else:
		_say("الخانة التانية فاضية. اختار سلاح معاك وحطه فيها.")

func _show_weapon(id: String, trying: bool) -> void:
	preview_id = id
	selim.sprite_frames = Game.frames(Game.player_sheet(id), Game.PLAYER_ANIMS, 8, 11)
	var fh: int = selim.sprite_frames.get_meta("fh")
	selim.offset = Vector2(0, -(204.0 - fh / 2.0))
	selim.play("idle")
	try_tag.visible = trying
	show_i = 0
	show_t = 0.9

# ---------------------------------------------------------------- header, tabs, grid, detail
func _build_header() -> void:
	header = Control.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(header)
	title_label = _lbl("دكان عم صابر", 24, Game.UI_TEXT)
	title_label.add_theme_constant_override("outline_size", 0)
	header.add_child(title_label)
	wallet_box = PanelContainer.new()
	wallet_box.add_theme_stylebox_override("panel", _box("price", 11, Vector4(10, 0, 12, 1)))
	wallet_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(wallet_box)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wallet_box.add_child(hb)
	hb.add_child(_tex_rect(_coin_icon(), Vector2(22, 22)))
	wallet_label = _lbl("", 17, Game.UI_ACCENT)
	wallet_label.add_theme_constant_override("outline_size", 0)
	hb.add_child(wallet_label)
	go_btn = Button.new()
	go_btn.text = ("ابدأ %s" % Game.CHAPTERS[Game.shop_next]["num"]) if Game.shop_next > 0 else "رجوع للقائمة"
	go_btn.focus_mode = Control.FOCUS_ALL
	_style_button(go_btn, "btn_green", "btn_green", "btn_off", 15)
	go_btn.pressed.connect(_leave)
	header.add_child(go_btn)

func _build_tabs() -> void:
	for c in Catalog.CATEGORIES:
		var b := Button.new()
		b.text = c[1]
		b.focus_mode = Control.FOCUS_ALL
		b.add_theme_font_override("font", Game.font_button)
		b.add_theme_font_size_override("font_size", 14)
		b.add_theme_constant_override("outline_size", 0)
		b.pressed.connect(func(): Audio.sfx("select", 0.05, -4); _select_tab(str(c[0])))
		add_child(b)
		tabs[c[0]] = b

func _style_tabs() -> void:
	for k in tabs:
		var b: Button = tabs[k]
		var on: bool = k == tab
		var nm := "tab_on" if on else "tab_off"
		for st in ["normal", "disabled", "pressed", "hover", "focus"]:
			b.add_theme_stylebox_override(st, _tab_box(on))
		b.add_theme_color_override("font_color", Game.UI_ACCENT if on else Game.UI_DIM)
		b.add_theme_color_override("font_pressed_color", Game.UI_ACCENT)
		b.add_theme_color_override("font_hover_color", Game.UI_TEXT)
		b.add_theme_color_override("font_focus_color", Game.UI_ACCENT if on else Game.UI_TEXT)

func _build_detail() -> void:
	detail = PanelContainer.new()
	detail.add_theme_stylebox_override("panel", _box("panel_dark", 22, Vector4(0, 0, 0, 0)))
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(detail)
	d_root = Control.new()
	d_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(d_root)
	d_icon_box = Panel.new()
	d_icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d_root.add_child(d_icon_box)
	d_icon = _tex_rect(null, Vector2(60, 60))
	d_root.add_child(d_icon)
	d_name = _lbl("", 18, Game.UI_TEXT)
	d_name.add_theme_constant_override("outline_size", 0)
	d_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	d_root.add_child(d_name)
	d_tier = _lbl("", 11, Color.WHITE)
	d_tier.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	d_root.add_child(d_tier)
	d_desc = _lbl("", 11, Color(Game.UI_TEXT, 0.82), false)
	d_desc.add_theme_constant_override("outline_size", 0)
	d_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	d_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d_desc.add_theme_constant_override("line_spacing", -3)
	d_root.add_child(d_desc)
	d_extra = Control.new()
	d_extra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d_root.add_child(d_extra)
	act_main = Button.new()
	act_main.focus_mode = Control.FOCUS_ALL
	act_main.pressed.connect(_buy)
	d_root.add_child(act_main)
	act_s1 = Button.new()
	act_s1.focus_mode = Control.FOCUS_ALL
	act_s1.pressed.connect(func(): _to_slot(0))
	d_root.add_child(act_s1)
	act_s2 = Button.new()
	act_s2.focus_mode = Control.FOCUS_ALL
	act_s2.pressed.connect(func(): _to_slot(1))
	d_root.add_child(act_s2)
	_style_button(act_s1, "slot", "slot_on", "btn_off", 13)
	_style_button(act_s2, "slot", "slot_on", "btn_off", 13)

# geometry shared by layout and card building
var col_x := 0.0
var col_w := 0.0
var grid_y := 0.0
var card_w := 0.0
var card_h := 72.0
var det_y := 0.0
var det_h := 0.0

func _layout() -> void:
	var s := get_viewport_rect().size
	var m := 8.0
	var stage_w := clampf(s.x * 0.38, 236.0, 330.0)
	col_x = stage_w + m
	col_w = s.x - col_x - m
	# header
	var tw0 := Game.font_title.get_string_size(title_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x + 10.0
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title_label.size = Vector2(tw0, 40)
	title_label.position = Vector2(s.x - tw0 - 12.0, 0.0)
	var ww := Game.font_title.get_string_size(wallet_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x + 6.0 + 22.0 + 4.0 + 22.0
	wallet_box.size = Vector2(ww, 28)
	wallet_box.position = Vector2(title_label.position.x - ww - 10.0, 9.0)
	go_btn.custom_minimum_size = Vector2(0, 32)
	go_btn.reset_size()
	go_btn.position = Vector2(col_x, 6.0)
	# tabs
	var tw := (col_w - 8.0) / 3.0
	var i := 0
	for c in Catalog.CATEGORIES:
		var b: Button = tabs[c[0]]
		b.size = Vector2(tw, 30)
		b.position = Vector2(col_x + col_w - (i + 1) * tw - i * 4.0, 44.0)
		i += 1
	grid_y = 80.0
	card_w = (col_w - 12.0) / 3.0
	card_h = clampf((s.y - 80.0 - 128.0) / 2.0 - 4.0, 64.0, 92.0)
	det_y = grid_y + card_h * 2.0 + 10.0
	det_h = s.y - det_y - m
	detail.position = Vector2(col_x, det_y)
	detail.size = Vector2(col_w, det_h)
	d_root.position = detail.position
	d_root.size = detail.size
	_layout_detail()
	# stage
	var feet := Vector2(stage_w * 0.5 + 4.0, s.y - 98.0)
	var sc := clampf((s.y - 150.0) / 180.0, 1.0, 1.7)
	selim_root.position = feet
	selim_root.scale = Vector2(sc, sc)
	pedestal.size = Vector2(190, 66)
	pedestal.position = feet - Vector2(95, 36)
	spot.size = Vector2(stage_w, s.y * 0.8)
	spot.position = Vector2(feet.x - stage_w / 2.0, feet.y - s.y * 0.62)
	try_tag.position = Vector2(feet.x - 50.0, feet.y - 132.0 * sc - 24.0)
	bubble.reset_size()
	bubble.position = Vector2(m + 4.0, 46.0)
	for k in range(slots.size()):
		var b: Button = slots[k]
		b.position = Vector2(feet.x - 70.0 + k * 78.0, s.y - 90.0)
	slot_hint.size = Vector2(stage_w - 10.0, 12)
	slot_hint.position = Vector2(5.0, s.y - 15.0)
	_rebuild_cards()

func _layout_detail() -> void:
	var w := detail.size.x
	var h := detail.size.y
	var bw := 118.0
	d_icon_box.position = Vector2(w - 76.0, 10.0)
	d_icon_box.size = Vector2(66, 66)
	d_icon.position = Vector2(w - 73.0, 13.0)
	d_icon.size = Vector2(60, 60)
	var tx := bw + 14.0
	var tw := w - 86.0 - tx
	d_name.position = Vector2(tx, 4.0)
	d_name.size = Vector2(tw, 24)
	d_tier.position = Vector2(tx, 26.0)
	d_tier.size = Vector2(tw, 14)
	d_desc.position = Vector2(tx, 40.0)
	d_desc.size = Vector2(tw, 30)
	d_desc.custom_minimum_size = Vector2(tw, 0)
	d_extra.position = Vector2(tx, h - 40.0)
	d_extra.size = Vector2(tw + 70.0, 34)
	act_main.position = Vector2(10.0, 10.0)
	act_main.size = Vector2(bw, 38)
	act_s1.position = Vector2(10.0, h - 44.0)
	act_s1.size = Vector2(bw / 2.0 - 3.0, 34)
	act_s2.position = Vector2(10.0 + bw / 2.0 + 3.0, h - 44.0)
	act_s2.size = Vector2(bw / 2.0 - 3.0, 34)

func _ids(cat: String) -> Array:
	var out := []
	for id in Catalog.ITEMS:
		if Catalog.ITEMS[id]["cat"] == cat:
			out.append(id)
	return out

func _select_tab(cat: String) -> void:
	tab = cat
	_style_tabs()
	_rebuild_cards()
	var ids := _ids(cat)
	var pick: String = ids[0]
	if cat == "weapon":
		pick = Game.equipped
	elif selected in ids:
		pick = selected
	_select(pick)

func _rebuild_cards() -> void:
	for c in grid_root.get_children():
		c.queue_free()
	cards.clear()
	var ids := _ids(tab)
	for i in range(ids.size()):
		var id: String = ids[i]
		var b := _make_card(id)
		var col := i % 3
		var row := i / 3
		b.position = Vector2(col_x + col_w - (col + 1) * card_w - col * 6.0, grid_y + row * (card_h + 6.0))
		grid_root.add_child(b)
		cards[id] = b
		# cards drop in one after another
		b.modulate.a = 0.0
		b.pivot_offset = b.size / 2.0
		b.scale = Vector2(0.92, 0.92)
		var tw := b.create_tween()
		tw.tween_interval(0.03 * i)
		tw.tween_property(b, "modulate:a", 1.0, 0.14)
		tw.parallel().tween_property(b, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK)
	_refresh_cards()

func _make_card(id: String) -> Button:
	var it: Dictionary = Catalog.ITEMS[id]
	var b := Button.new()
	b.focus_mode = Control.FOCUS_ALL
	b.size = Vector2(card_w, card_h)
	b.custom_minimum_size = b.size
	var ic := _tex_rect(_icon(id), Vector2(card_h - 26.0, card_h - 26.0))
	ic.position = Vector2(card_w - ic.size.x - 7.0, 7.0)
	ic.name = "Icon"
	b.add_child(ic)
	var nm := _lbl(str(it["name"]), 12 if card_w < 140.0 else 14, Game.UI_TEXT)
	nm.add_theme_constant_override("outline_size", 0)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	nm.position = Vector2(6.0, 4.0)
	nm.size = Vector2(card_w - ic.size.x - 14.0, 18)
	nm.clip_text = true
	b.add_child(nm)
	var gem := Panel.new()
	gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gem.size = Vector2(8, 8)
	gem.position = Vector2(8.0, card_h - 30.0)
	gem.add_theme_stylebox_override("panel", Game.style_box(Catalog.TIER_COLORS[int(it["tier"])], Color(0, 0, 0, 0.7), 1, 4))
	gem.name = "Gem"
	b.add_child(gem)
	var pips := HBoxContainer.new()
	pips.name = "Pips"
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pips.add_theme_constant_override("separation", 3)
	pips.position = Vector2(20.0, card_h - 32.0)
	b.add_child(pips)
	var tag := PanelContainer.new()
	tag.name = "Tag"
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_theme_stylebox_override("panel", _box("price", 10, Vector4(6, -1, 8, 0)))
	b.add_child(tag)
	var thb := HBoxContainer.new()
	thb.name = "Row"
	thb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thb.add_theme_constant_override("separation", 2)
	tag.add_child(thb)
	var coin := _tex_rect(_coin_icon(), Vector2(14, 14))
	coin.name = "Coin"
	thb.add_child(coin)
	var pl := _lbl("", 12, Game.UI_ACCENT)
	pl.add_theme_constant_override("outline_size", 0)
	pl.name = "Price"
	thb.add_child(pl)
	var lock := ColorRect.new()
	lock.name = "Lock"
	lock.color = Color(0.04, 0.04, 0.05, 0.55)
	lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lock.position = Vector2(4, 4)
	lock.size = b.size - Vector2(8, 8)
	b.add_child(lock)
	var ll := _lbl("", 10, Game.UI_DIM)
	ll.add_theme_constant_override("outline_size", 0)
	ll.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ll.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ll.add_theme_constant_override("line_spacing", -3)
	# lower 60% of the card so the item name on top stays readable
	ll.position = Vector2(0, lock.size.y * 0.36)
	ll.size = Vector2(lock.size.x, lock.size.y * 0.62)
	ll.name = "LockLabel"
	lock.add_child(ll)
	b.pressed.connect(func(): Audio.sfx("select", 0.05, -6); _select(id))
	b.focus_entered.connect(func(): if selected != id: _select(id))
	b.mouse_entered.connect(func(): b.pivot_offset = b.size / 2.0; b.create_tween().tween_property(b, "scale", Vector2(1.04, 1.04), 0.08))
	b.mouse_exited.connect(func(): b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.08))
	return b

func _state(id: String) -> Dictionary:
	# text / colour shown in the card's tag, plus flags used by the detail panel
	var it: Dictionary = Catalog.ITEMS[id]
	var locked := Game.unlocked < int(it["unlock"])
	var r := {"locked": locked, "text": "", "price": false, "col": Game.UI_ACCENT}
	if locked:
		r["text"] = "يفتح في %s" % Game.CHAPTERS[int(it["unlock"])]["num"]
		return r
	if id in Catalog.WEAPONS:
		if id in Game.owned:
			var slot := Game.loadout.find(id)
			if slot >= 0:
				r["text"] = "في الخانة %s" % ["١", "٢"][slot]
				r["col"] = Game.UI_GOOD if id == Game.equipped else Game.UI_TEXT
			else:
				r["text"] = "معاك"
				r["col"] = Game.UI_DIM
			return r
	elif Game.upgrades.has(id):
		if int(Game.upgrades[id]) >= Game.upgrade_max(id):
			r["text"] = "مكتمل"
			r["col"] = Game.UI_GOOD
			return r
	elif Game.inventory.has(id) and int(Game.inventory[id]) >= 5:
		r["text"] = "الشنطة مليانة"
		r["col"] = Game.UI_DIM
		return r
	var p := Game.item_price(id)
	r["price"] = true
	r["text"] = str(p)
	r["col"] = Game.UI_ACCENT if Game.wallet >= p else Game.UI_BAD
	return r

func _refresh_cards() -> void:
	if wallet_label.text != "%d جنيه" % Game.wallet:
		wallet_label.text = "%d جنيه" % Game.wallet
		var ww := Game.font_title.get_string_size(wallet_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x + 54.0
		wallet_box.size = Vector2(ww, 28)
		wallet_box.position.x = title_label.position.x - ww - 10.0
	for id in cards:
		var b: Button = cards[id]
		var it: Dictionary = Catalog.ITEMS[id]
		var st := _state(id)
		var tier := int(it["tier"])
		var sel: bool = id == selected
		var nm := "card_t%d%s" % [tier, "_sel" if sel else ""]
		for k in ["normal", "disabled"]:
			b.add_theme_stylebox_override(k, _box(nm, 18, Vector4(0, 0, 0, 0)))
		for k in ["hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(k, _box("card_t%d_sel" % tier, 18, Vector4(0, 0, 0, 0)))
		var tag: PanelContainer = b.get_node("Tag")
		(tag.get_node("Row/Coin") as TextureRect).visible = bool(st["price"])
		var pl: Label = tag.get_node("Row/Price")
		pl.text = str(st["text"])
		pl.add_theme_color_override("font_color", st["col"])
		tag.visible = not bool(st["locked"])
		tag.reset_size()
		tag.position = Vector2(6.0, card_h - tag.size.y - 6.0)
		var lock: ColorRect = b.get_node("Lock")
		lock.visible = bool(st["locked"])
		(lock.get_node("LockLabel") as Label).text = "مقفول\n" + str(st["text"])
		(b.get_node("Icon") as TextureRect).modulate = Color(0.35, 0.33, 0.33) if bool(st["locked"]) else Color.WHITE
		var pips: HBoxContainer = b.get_node("Pips")
		for c in pips.get_children():
			pips.remove_child(c)
			c.queue_free()
		if Game.upgrades.has(id):
			for k in range(Game.upgrade_max(id)):
				var pip := Panel.new()
				pip.custom_minimum_size = Vector2(9, 9)
				pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
				var on := k < int(Game.upgrades[id])
				pip.add_theme_stylebox_override("panel", Game.style_box(Game.UI_ACCENT if on else Color(1, 1, 1, 0.12), Color(0, 0, 0, 0), 0, 2))
				pips.add_child(pip)
			pips.position = Vector2(card_w - pips.get_child_count() * 12.0 - 8.0, card_h - 17.0)
			(b.get_node("Gem") as Panel).visible = false
		elif Game.inventory.has(id):
			var cnt := _lbl("معاك %d" % int(Game.inventory[id]), 10, Game.UI_DIM)
			pips.add_child(cnt)
			pips.position = Vector2(card_w - 62.0, card_h - 20.0)
	_refresh_slots()

func _select(id: String) -> void:
	selected = id
	var it: Dictionary = Catalog.ITEMS[id]
	var st := _state(id)
	var tier := int(it["tier"])
	var tc: Color = Catalog.TIER_COLORS[tier]
	d_icon.texture = _icon(id)
	d_icon.modulate = Color(0.35, 0.33, 0.33) if bool(st["locked"]) else Color.WHITE
	var ib := Game.style_box(Color(1, 1, 1, 0.05), Color(1, 1, 1, 0.12), 1, 10)
	d_icon_box.add_theme_stylebox_override("panel", ib)
	d_name.text = str(it["name"])
	d_tier.text = Catalog.TIER_NAMES[tier]
	d_tier.add_theme_color_override("font_color", tc)
	d_desc.text = str(it["desc"])
	for c in d_extra.get_children():
		c.queue_free()
	act_s1.visible = false
	act_s2.visible = false
	act_main.visible = true
	act_main.disabled = false
	var main_style := "btn_buy"
	if bool(st["locked"]):
		act_main.text = "مقفول"
		act_main.disabled = true
	elif id in Catalog.WEAPONS:
		_weapon_stats(id)
		if id in Game.owned:
			act_main.text = "في إيدك" if id == Game.equipped else "امسكه"
			act_main.disabled = id == Game.equipped
			main_style = "btn_green"
			act_s1.visible = true
			act_s2.visible = true
			act_s1.text = "خانة ١"
			act_s2.text = "خانة ٢"
			act_s1.disabled = str(Game.loadout[0]) == id
			act_s2.disabled = str(Game.loadout[1]) == id
		else:
			act_main.text = "اشتري  %d" % Game.item_price(id)
			act_main.disabled = Game.wallet < Game.item_price(id)
	elif Game.upgrades.has(id):
		_upgrade_info(id)
		if int(Game.upgrades[id]) >= Game.upgrade_max(id):
			act_main.text = "مكتمل"
			act_main.disabled = true
		else:
			act_main.text = "طوّر  %d" % Game.item_price(id)
			act_main.disabled = Game.wallet < Game.item_price(id)
	else:
		var have := _lbl("معاك في الشنطة: %d من ٥" % int(Game.inventory[id]), 12, Game.UI_DIM, false)
		d_extra.add_child(have)
		if int(Game.inventory[id]) >= 5:
			act_main.text = "مليانة"
			act_main.disabled = true
		else:
			act_main.text = "اشتري  %d" % Game.item_price(id)
			act_main.disabled = Game.wallet < Game.item_price(id)
	_style_button(act_main, main_style, main_style + ("_hi" if main_style == "btn_buy" else ""), "btn_off", 15)
	if id in Catalog.WEAPONS and not bool(st["locked"]):
		_show_weapon(id, id != Game.equipped)
	elif preview_id != Game.equipped:
		_show_weapon(Game.equipped, false)
	_refresh_cards()
	if cards.has(id):
		var b: Button = cards[id]
		b.pivot_offset = b.size / 2.0
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2(1.06, 1.06), 0.07)
		tw.tween_property(b, "scale", Vector2.ONE, 0.12)
	# a fresh look at the item: little pop of the detail icon
	d_icon.pivot_offset = d_icon.size / 2.0
	d_icon.scale = Vector2(0.7, 0.7)
	d_icon.create_tween().tween_property(d_icon, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)

# Damage / reach / speed bars, with a marker for the weapon currently in hand.
func _weapon_stats(id: String) -> void:
	var it: Dictionary = Catalog.ITEMS[id]
	var cur: Dictionary = Catalog.ITEMS[Game.equipped]
	var stats := [["ضرر", float(it["damage"]) + 1.0, float(cur["damage"]) + 1.0, 4.0], ["مدى", float(it["reach"]) + 6.0, float(cur["reach"]) + 6.0, 28.0], ["سرعة", float(it["tempo"]), float(cur["tempo"]), 1.3]]
	var w := d_extra.size.x - 70.0
	var bw := (w - 12.0) / 3.0
	for i in range(3):
		var x := w - (i + 1) * bw - i * 6.0
		var l := _lbl(stats[i][0], 10, Game.UI_DIM)
		l.add_theme_constant_override("outline_size", 0)
		l.position = Vector2(x, 0)
		l.size = Vector2(bw, 14)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		d_extra.add_child(l)
		var back := ColorRect.new()
		back.color = Color(1, 1, 1, 0.08)
		back.position = Vector2(x, 17)
		back.size = Vector2(bw, 7)
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		d_extra.add_child(back)
		var v: float = clampf(stats[i][1] / stats[i][3], 0.05, 1.0)
		var c: float = clampf(stats[i][2] / stats[i][3], 0.05, 1.0)
		var fill := ColorRect.new()
		fill.color = Game.UI_GOOD if v > c + 0.01 else (Game.UI_BAD if v < c - 0.01 else Game.UI_ACCENT)
		fill.position = Vector2(x + bw * (1.0 - v), 17)
		fill.size = Vector2(bw * v, 7)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		d_extra.add_child(fill)
		var mark := ColorRect.new()
		mark.color = Color(1, 1, 1, 0.9)
		mark.position = Vector2(x + bw * (1.0 - c) - 1.0, 15)
		mark.size = Vector2(2, 11)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		d_extra.add_child(mark)

func _upgrade_info(id: String) -> void:
	var lvl := int(Game.upgrades[id])
	var mx := Game.upgrade_max(id)
	var l := _lbl("المستوى %d من %d" % [lvl, mx], 12, Game.UI_DIM)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.size = Vector2(d_extra.size.x - 70.0, 16)
	d_extra.add_child(l)
	var pw := 22.0
	for k in range(mx):
		var pip := Panel.new()
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pip.size = Vector2(pw - 4.0, 9)
		pip.position = Vector2(d_extra.size.x - 70.0 - (k + 1) * pw, 21)
		var tc: Color = Catalog.TIER_COLORS[int(Catalog.ITEMS[id]["tier"])]
		pip.add_theme_stylebox_override("panel", Game.style_box(Game.UI_ACCENT if k < lvl else Color(1, 1, 1, 0.12), Color(0, 0, 0, 0), 0, 3))
		d_extra.add_child(pip)

# ---------------------------------------------------------------- actions
func _buy() -> void:
	var id := selected
	if id == "":
		return
	var it: Dictionary = Catalog.ITEMS[id]
	var price := Game.item_price(id)
	var was_owned: bool = id in Game.owned
	var res := Game.purchase(id)
	match res:
		"تم الشراء":
			Audio.sfx("coin", 0.05)
			Audio.sfx("checkpoint", 0.05, -4)
			_float_text("-%d" % price, wallet_box.position + Vector2(10, 26))
			_bump(wallet_box)
			if id in Catalog.WEAPONS:
				_say("%s بقى بتاعك! حطيته في الخانة بتاعتك." % it["name"])
				_equip_fx(id)
			else:
				_fly_icon(id)
				_say(_supply_line(id))
		"تم التجهيز":
			if not was_owned:
				pass
			_say("%s في إيدك دلوقتي." % it["name"])
			_equip_fx(id)
		_:
			Audio.sfx("hurt", 0.05, -8)
			_say(res + (" ناقصك %d جنيه." % (price - Game.wallet) if res == "الجنيهات مش كفاية" else ""))
			_shake(act_main)
	_select(id)

func _to_slot(slot: int) -> void:
	var id := selected
	if id not in Game.owned:
		return
	Game.set_loadout_slot(slot, id)
	Audio.sfx("weapon_switch", 0.05)
	_say("%s في الخانة %s." % [Catalog.ITEMS[id]["name"], ["الأولى", "التانية"][slot]])
	var b: Button = slots[slot]
	_bump(b)
	_select(id)

func _supply_line(id: String) -> String:
	match id:
		"potion": return "إسعاف في الشنطة. اشربه وقت الزنقة!"
		"bomb": return "قنبلة دخان.. ارميها وسط الزحمة."
		"health": return "قلبك بقى أقوى يا بطل!"
		"power": return "ضرباتك هتبقى تقيلة بجد."
		"armor": return "الجعران هيحميك من ضربات كتير."
		"boots": return "هتجري زي الريح."
		"magnet": return "الجنيهات هتجري عليك من بعيد."
	return "تم!"

func _equip_fx(id: String) -> void:
	_show_weapon(id, false)
	selim.modulate = Color(2.4, 2.1, 1.6)
	create_tween().tween_property(selim, "modulate", Color(1, 1, 1), 0.4)
	sparkles.restart()
	sparkles.emitting = true
	selim.play("rhkick" if selim.sprite_frames.has_animation("rhkick") else "atk3")
	show_t = 1.2

func _fly_icon(id: String) -> void:
	var from: Vector2 = (cards[id] as Button).position + Vector2(card_w - 40.0, 10.0) if cards.has(id) else get_viewport_rect().size / 2.0
	var to := selim_root.position + Vector2(0, -70)
	var ic := _tex_rect(_icon(id), Vector2(40, 40))
	ic.position = from
	ic.z_index = 50
	add_child(ic)
	var tw := create_tween()
	tw.tween_method(func(k: float): ic.position = _bez(from, (from + to) / 2.0 + Vector2(0, -120), to, k), 0.0, 1.0, 0.55).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(ic, "scale", Vector2(0.5, 0.5), 0.55)
	tw.tween_callback(func():
		ic.queue_free()
		sparkles.restart()
		sparkles.emitting = true
		selim.modulate = Color(1.6, 2.0, 1.6)
		create_tween().tween_property(selim, "modulate", Color(1, 1, 1), 0.35))

func _bez(a: Vector2, b: Vector2, c: Vector2, k: float) -> Vector2:
	return a.lerp(b, k).lerp(b.lerp(c, k), k)

func _float_text(txt: String, pos: Vector2) -> void:
	var l := _lbl(txt, 16, Game.UI_BAD)
	l.position = pos
	l.z_index = 60
	add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", pos.y + 26.0, 0.8)
	tw.tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)

func _bump(c: Control) -> void:
	c.pivot_offset = c.size / 2.0
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2(1.15, 1.15), 0.08)
	tw.tween_property(c, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK)

func _say(txt: String) -> void:
	bubble_label.text = txt
	bubble.reset_size()
	bubble.pivot_offset = Vector2(0, bubble.size.y)
	bubble.scale = Vector2(0.85, 0.85)
	create_tween().tween_property(bubble, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK)

func _shake(c: Control) -> void:
	var x := c.position.x
	var tw := create_tween()
	for i in range(4):
		tw.tween_property(c, "position:x", x + (5.0 if i % 2 == 0 else -5.0), 0.04)
	tw.tween_property(c, "position:x", x, 0.04)

func _process(delta: float) -> void:
	t += delta
	spot.modulate.a = 0.85 + 0.15 * sin(t * 2.0)
	try_tag.modulate.a = 0.6 + 0.4 * sin(t * 4.0)
	# showcase loop: Selim shows off his moves with the previewed weapon
	show_t -= delta
	if show_t <= 0.0 and (selim.animation == "idle" or not selim.is_playing()):
		var a: String = SHOWCASE[show_i % SHOWCASE.size()]
		show_i += 1
		show_t = 0.75 if a != "idle" else 1.4
		if selim.sprite_frames.has_animation(a):
			selim.play(a)

func _leave() -> void:
	var next := Game.shop_next
	if next > 0:
		Game.start_chapter(next)
	else:
		Game.goto_title()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_leave()
	elif event.is_action_pressed("weapon"):
		var keys: Array = tabs.keys()
		_select_tab(str(keys[(keys.find(tab) + 1) % keys.size()]))

# ---------------------------------------------------------------- automated screenshots (-- --autotest=shop)
func _autotest() -> void:
	await get_tree().create_timer(1.0).timeout
	var c0: Button = cards.values()[0]
	print("DBG card ", c0.size, " icon ", (c0.get_node("Icon") as Control).size, " ", (c0.get_node("Icon") as Control).get_combined_minimum_size(), " title ", title_label.size, " vp ", get_viewport_rect().size, " scale ", c0.scale)
	await _shot("shop_a")
	Game.wallet = maxi(Game.wallet, 3000)
	Game.unlocked = maxi(Game.unlocked, 8)
	_refresh_cards()
	_select_tab("weapon")
	_select("saber")
	await get_tree().create_timer(0.6).timeout
	await _shot("shop_try")
	_buy()
	await get_tree().create_timer(0.15).timeout
	await _shot("shop_buy")
	await get_tree().create_timer(1.0).timeout
	await _shot("shop")
	_select("spear")
	_buy()
	_select("stick")
	_to_slot(1)
	await get_tree().create_timer(0.5).timeout
	await _shot("shop_slots")
	_select_tab("upgrade")
	_select("health")
	_buy()
	await get_tree().create_timer(0.3).timeout
	await _shot("shop_upgrade")
	await get_tree().create_timer(0.8).timeout
	_select_tab("supply")
	_select("potion")
	_buy()
	await get_tree().create_timer(0.25).timeout
	await _shot("shop_fly")
	await get_tree().create_timer(1.0).timeout
	_select("bomb")
	await _shot("shop_supply")
	print("AUTOTEST shop wallet=", Game.wallet, " equipped=", Game.equipped, " loadout=", Game.loadout, " owned=", Game.owned, " health=", Game.upgrades["health"], " potion=", Game.inventory["potion"])
	get_tree().quit()

func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://shots")
	get_viewport().get_texture().get_image().save_png("user://shots/%s.png" % n)
