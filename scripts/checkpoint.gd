extends Node2D
# Checkpoint lantern (fanoos). idx 1 = mid-chapter, idx 2 = right before the boss gate.

var level: Node = null
var idx := 1
var active := false
var sprite: Sprite2D
var t := 0.0
var glow: PointLight2D
var warn_t := 0.0

func _glow_tex() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 64
	gt.height = 64
	return gt

func _ready() -> void:
	sprite = Game.region_sprite("res://assets/sprites/checkpoint.png", Rect2(0, 0, 48, 96))
	sprite.position = Vector2(0, -24)
	glow = PointLight2D.new()
	glow.texture = _glow_tex()
	glow.color = Color(1.0, 0.75, 0.4)
	glow.energy = 0.0
	glow.texture_scale = 1.6
	glow.position = Vector2(0, -38)
	add_child(glow)
	add_child(sprite)
	z_index = -1

func set_active(v: bool) -> void:
	active = v
	sprite.region_rect = Rect2(48 if v else 0, 0, 48, 96)
	if glow != null:
		glow.energy = 1.1 if v else 0.0

func _process(delta: float) -> void:
	t += delta
	if active:
		sprite.region_rect = Rect2(48 + 48 * (int(t * 5) % 2), 0, 48, 96)
		glow.energy = 1.0 + 0.15 * sin(t * 9.0)
		return
	if level == null or level.player == null:
		return
	var p = level.player
	if not p.dead and absf(p.global_position.x - global_position.x) < 16 and absf(p.global_position.y - global_position.y) < 40:
		# the pre-boss lantern only lights once every fighter before the boss barrier is beaten
		if idx == 2 and level.get("barrier_x") != null and float(level.barrier_x) >= 0.0 and not level.barrier_open:
			warn_t -= get_process_delta_time()
			if warn_t <= 0.0 and level.hud != null:
				warn_t = 3.0
				level.hud.toast("خلّص على كل الأعداء الأول عشان الفانوس ينوّر")
			return
		set_active(true)
		if level.has_method("on_checkpoint"):
			level.on_checkpoint(idx)
		else:
			Game.set_checkpoint(idx)
		p.heal(p.max_hp)
		Audio.sfx("checkpoint")
		Game.spawn_fx(get_parent(), "spark", global_position + Vector2(0, -32), false, 2.0)
		if level.hud != null:
			level.hud.toast("تم الحفظ قبل الزعيم! لو وقعت هترجع هنا على طول" if idx == 2 else "تم الحفظ.. الفانوس نوّر! لو وقعت هترجع هنا")
