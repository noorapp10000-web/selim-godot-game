extends Node2D
# Short-lived boss hazards: venom puddles, grenade fuses/blasts and sun-beam columns.

var level: Node = null
var kind := "puddle"
var t := 0.0
var life := 4.0
var warn := 0.8          # beam telegraph time
var hit_cd := 0.0
var done_hit := false
var sprite: Sprite2D

func _ready() -> void:
	add_to_group("boss_fx")
	z_index = 14
	match kind:
		"puddle":
			life = 4.2
			sprite = _proj2(7, 0.62)
			sprite.position = Vector2(0, -9)
			z_index = 6
		"fuse":
			life = 0.95
			sprite = _proj2(1, 0.3)
			sprite.position = Vector2(0, -6)
		"blast":
			life = 0.4
			Audio.sfx("grenade_boom", 0.1)
			if level != null:
				level.shake(4.0)
				Game.spawn_fx(level.entities, "dust", global_position, false, 3.0)
		"beam":
			life = warn + 0.45

func _proj2(idx: int, sc: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load("res://assets/sprites/proj2.png")
	s.region_enabled = true
	s.region_rect = Rect2(idx * 48, 0, 48, 48)
	s.scale = Vector2(sc, sc)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(s)
	return s

func _physics_process(delta: float) -> void:
	t += delta
	hit_cd -= delta
	var p = level.player if level != null else null
	match kind:
		"puddle":
			sprite.modulate.a = clampf((life - t) / 0.6, 0.0, 1.0) * (0.85 + 0.15 * sin(t * 6.0))
			if p != null and not p.dead and hit_cd <= 0.0:
				var d: Vector2 = p.global_position - global_position
				if absf(d.x) < 15.0 and absf(d.y) < 8.0:
					p.hurt(1, global_position.x)
					hit_cd = 0.9
		"fuse":
			sprite.modulate = Color(2.2, 0.6, 0.5) if int(t * (8.0 + t * 14.0)) % 2 == 0 else Color(1, 1, 1)
		"blast":
			if not done_hit and p != null and not p.dead:
				done_hit = true
				if (p.center() - (global_position + Vector2(0, -10))).length() < 38.0:
					p.hurt(2, global_position.x)
			queue_redraw()
		"beam":
			queue_redraw()
			if t > warn and not done_hit and p != null and not p.dead:
				if absf(p.global_position.x - global_position.x) < 13.0:
					done_hit = true
					p.hurt(1, global_position.x)
			if t > warn and t - delta <= warn:
				Audio.sfx("beam", 0.1, -4)
				if level != null:
					level.shake(2.0)
	if t >= life:
		if kind == "fuse":
			var b = get_script().new()
			b.level = level
			b.kind = "blast"
			b.position = position + Vector2(0, -4)
			get_parent().add_child(b)
		queue_free()

func _draw() -> void:
	match kind:
		"blast":
			var k := clampf(t / 0.3, 0.0, 1.0)
			draw_circle(Vector2(0, -10), 10.0 + 30.0 * k, Color(1.0, 0.75, 0.3, 0.55 * (1.0 - k)))
			draw_circle(Vector2(0, -10), 6.0 + 20.0 * k, Color(1.0, 0.95, 0.7, 0.7 * (1.0 - k)))
		"beam":
			if t < warn:
				var a := 0.25 + 0.35 * absf(sin(t * 14.0))
				draw_rect(Rect2(-2, -300, 4, 300), Color(1.0, 0.85, 0.35, a * 0.6))
				draw_rect(Rect2(-12, -3, 24, 3), Color(1.0, 0.8, 0.3, a))
			else:
				var k := clampf((t - warn) / 0.45, 0.0, 1.0)
				var wdt := 26.0 * (1.0 - k * 0.6)
				draw_rect(Rect2(-wdt / 2.0, -300, wdt, 300), Color(1.0, 0.82, 0.3, 0.55 * (1.0 - k)))
				draw_rect(Rect2(-wdt / 4.0, -300, wdt / 2.0, 300), Color(1.0, 0.98, 0.8, 0.85 * (1.0 - k)))
