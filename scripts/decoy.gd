extends Node2D
# Boss shadow clone: "runner" dashes at the player, "caster" stands still and spits venom.
# One hit pops it in a puff of smoke.

const Projectile = preload("res://scripts/projectile.gd")

var level: Node = null
var boss: Node = null
var sheet := "boss7"
var mode := "runner"
var dir := 1
var speed := 150.0
var life := 2.6
var t := 0.0
var shot_t := 0.9
var sprite: AnimatedSprite2D
var popped := false

func _ready() -> void:
	add_to_group("hittable")
	add_to_group("boss_fx")
	sprite = Game.char_sprite(self, sheet, Game.ENEMY_ANIMS, Game.ENEMY_GRID)
	sprite.modulate = Color(0.55, 0.45, 0.85, 0.72)
	sprite.flip_h = dir < 0
	sprite.play("run" if mode == "runner" else "cast")
	z_index = 4

func hurt_rect() -> Rect2:
	return Rect2(global_position + Vector2(-16, -52), Vector2(32, 52))

func take_hit(_d: int, _dir: int, _src: Node) -> void:
	pop()

func pop() -> void:
	if popped:
		return
	popped = true
	remove_from_group("hittable")
	Audio.sfx("teleport", 0.15, -6)
	if level != null:
		Game.spawn_fx(level.entities, "dust", global_position + Vector2(0, -4), false, 2.2)
	var tw := create_tween()
	tw.tween_property(sprite, "modulate:a", 0.0, 0.18)
	tw.tween_callback(queue_free)

func _physics_process(delta: float) -> void:
	if popped:
		return
	t += delta
	sprite.modulate.a = 0.6 + 0.15 * sin(t * 18.0)
	var p = level.player if level != null else null
	if mode == "runner":
		position.x += dir * speed * delta
		if boss != null and is_instance_valid(boss):
			position.x = clampf(position.x, boss.arena_l + 16, boss.arena_r - 16)
		if p != null and not p.dead:
			var d: Vector2 = p.global_position - global_position
			if absf(d.x) < 14.0 and absf(d.y) < 28.0:
				p.hurt(1, global_position.x)
				pop()
				return
	else:
		if p != null:
			dir = int(signf(p.global_position.x - global_position.x)) if absf(p.global_position.x - global_position.x) > 4 else dir
			sprite.flip_h = dir < 0
		shot_t -= delta
		var on_screen := true
		if p != null and p.camera != null:
			var half: float = get_viewport_rect().size.x / p.camera.zoom.x / 2.0
			on_screen = absf(global_position.x - p.camera.get_screen_center_position().x) < half - 10.0
		# illusions only spit venom while they are visible on screen
		if shot_t <= 0.0 and p != null and not p.dead and on_screen:
			shot_t = 1.5
			sprite.play("throw")
			var pr := Projectile.new()
			pr.level = level
			pr.kind = "venom"
			pr.position = global_position + Vector2(dir * 14, -30)
			pr.vel = Vector2(dir * 150.0, -60.0)
			pr.grav = 260.0
			level.entities.add_child(pr)
			Audio.sfx("poison", 0.1, -6)
	if t > life:
		pop()
