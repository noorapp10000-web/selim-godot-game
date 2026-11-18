extends AnimatableBody2D
# Horizontally moving one-way platform (3 tiles).

var origin := Vector2.ZERO
var amp := 44.0
var spd := 1.3
var t := 0.0

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	origin = position
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(48, 8)
	cs.shape = rs
	cs.position = Vector2(0, 4)
	cs.one_way_collision = true
	add_child(cs)
	for i in range(3):
		var s: Sprite2D = Game.region_sprite("res://assets/sprites/tiles_ch%d.png" % Game.chapter, Rect2(128, 0, 32, 32))
		s.position = Vector2(-16 + i * 16, 8)
		add_child(s)

func _physics_process(delta: float) -> void:
	t += delta
	position = origin + Vector2(sin(t * spd) * amp, 0)
