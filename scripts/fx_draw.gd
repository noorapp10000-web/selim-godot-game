extends Control
# Small animated vector widgets used by the v9 UI.
#   "next"    – bouncing gold chevron diamond (dialog: tap to continue)
#   "wave"    – four equaliser bars, alive while a voice line is playing
#   "divider" – gold hairline with a diamond in the middle
#   "rays"    – soft additive god-rays (title screen)

var kind := "next"
var color := Color(0.95, 0.76, 0.44, 1.0)
var active := true
var t := 0.0
var level := 0.0

func _init(k := "next", c := Color(0.95, 0.76, 0.44, 1.0)) -> void:
	kind = k
	color = c
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	t += delta
	level = move_toward(level, 1.0 if active else 0.0, delta * 5.0)
	if kind != "divider":
		queue_redraw()

func _draw() -> void:
	match kind:
		"next":
			if level <= 0.01:
				return
			var y := sin(t * 5.0) * 2.5
			var c := Vector2(size.x / 2.0, size.y / 2.0 + y)
			var col := Color(color, color.a * level)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-6, -3), c + Vector2(0, 3), c + Vector2(6, -3), c + Vector2(0, 0)]), col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-4, -8), c + Vector2(0, -4), c + Vector2(4, -8), c + Vector2(0, -6)]), Color(col, col.a * 0.55))
		"wave":
			for i in range(4):
				var hh := 3.0 + level * (5.0 + 5.0 * absf(sin(t * (7.0 + i * 1.7) + i * 1.3)))
				var x := i * 4.0 + 1.0
				draw_rect(Rect2(x, size.y / 2.0 - hh / 2.0, 2.2, hh), Color(color, 0.35 + 0.65 * level), true)
		"divider":
			var cy := size.y / 2.0
			var col2 := Color(color, 0.0)
			var pts := PackedVector2Array([Vector2(0, cy), Vector2(size.x / 2.0 - 10, cy)])
			draw_polyline_colors(pts, PackedColorArray([col2, color]), 1.0, true)
			pts = PackedVector2Array([Vector2(size.x / 2.0 + 10, cy), Vector2(size.x, cy)])
			draw_polyline_colors(pts, PackedColorArray([color, col2]), 1.0, true)
			var c2 := Vector2(size.x / 2.0, cy)
			draw_colored_polygon(PackedVector2Array([c2 + Vector2(0, -4), c2 + Vector2(4, 0), c2 + Vector2(0, 4), c2 + Vector2(-4, 0)]), color)
			draw_colored_polygon(PackedVector2Array([c2 + Vector2(-9, 0), c2 + Vector2(-6, -2), c2 + Vector2(-3, 0), c2 + Vector2(-6, 2)]), Color(color, 0.6))
			draw_colored_polygon(PackedVector2Array([c2 + Vector2(9, 0), c2 + Vector2(6, -2), c2 + Vector2(3, 0), c2 + Vector2(6, 2)]), Color(color, 0.6))
		"rays":
			var o := Vector2(size.x * 0.72, -size.y * 0.25)
			for i in range(7):
				var a := 1.75 + i * 0.13 + sin(t * 0.25 + i) * 0.03
				var spread := 0.035 + 0.02 * sin(t * 0.4 + i * 2.0)
				var L := size.length() * 1.3
				var p1 := o + Vector2(cos(a - spread), sin(a - spread)) * L
				var p2 := o + Vector2(cos(a + spread), sin(a + spread)) * L
				var al := (0.035 + 0.025 * sin(t * 0.6 + i * 1.7)) * color.a
				draw_polygon(PackedVector2Array([o, p1, p2]), PackedColorArray([Color(color, al * 1.6), Color(color, 0.0), Color(color, 0.0)]))
