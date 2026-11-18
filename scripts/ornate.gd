extends StyleBox
# v9 premium panel style: a flat glass box (StyleBoxFlat underneath) plus vector ornaments
# drawn straight onto the canvas – a chamfered gold inner frame, diamond studs with short
# rays in the corners and an optional eight-point star crest on the top edge.
# Being a StyleBox it works everywhere a panel/button style does and stays sharp at any DPI.

var base: StyleBoxFlat
var gold := Color(0.95, 0.76, 0.44, 0.85)
var inset := 6.0
var cut := 7.0
var crest := false
var studs := true
var frame := true
var ray := 22.0

func setup(b: StyleBoxFlat, g: Color, with_crest := false, ins := 6.0) -> StyleBox:
	base = b
	gold = g
	crest = with_crest
	inset = ins
	content_margin_left = b.content_margin_left
	content_margin_right = b.content_margin_right
	content_margin_top = b.content_margin_top
	content_margin_bottom = b.content_margin_bottom
	return self

static func star(c: Vector2, r_out: float, r_in: float, points := 8) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(points * 2):
		var a := PI * i / points - PI / 2.0
		var r := r_out if i % 2 == 0 else r_in
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts

static func diamond(c: Vector2, r: float) -> PackedVector2Array:
	return PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])

func _line(ci: RID, a: Vector2, b: Vector2, c0: Color, c1: Color, w := 1.0) -> void:
	RenderingServer.canvas_item_add_polyline(ci, PackedVector2Array([a, b]), PackedColorArray([c0, c1]), w, true)

func _draw(ci: RID, rect: Rect2) -> void:
	if base != null:
		base.draw(ci, rect)
	var w := rect.size.x
	var h := rect.size.y
	if w < 40 or h < 24:
		return
	var o := rect.position
	var a := inset
	var c := cut
	var col := gold
	var faint := Color(gold.r, gold.g, gold.b, gold.a * 0.26)
	var clear := Color(gold.r, gold.g, gold.b, 0.0)
	if frame:
		var pts := PackedVector2Array([
			Vector2(a + c, a), Vector2(w - a - c, a), Vector2(w - a, a + c), Vector2(w - a, h - a - c),
			Vector2(w - a - c, h - a), Vector2(a + c, h - a), Vector2(a, h - a - c), Vector2(a, a + c), Vector2(a + c, a)])
		for i in range(pts.size()):
			pts[i] += o
		var cols := PackedColorArray()
		for i in range(pts.size()):
			cols.append(faint)
		RenderingServer.canvas_item_add_polyline(ci, pts, cols, 1.0, true)
	if studs:
		var rr := minf(ray, minf(w, h) * 0.22)
		for p0 in [Vector2(a, a), Vector2(w - a, a), Vector2(a, h - a), Vector2(w - a, h - a)]:
			var p: Vector2 = o + p0
			var sx := 1.0 if p0.x < w / 2.0 else -1.0
			var sy := 1.0 if p0.y < h / 2.0 else -1.0
			RenderingServer.canvas_item_add_polygon(ci, diamond(p, 3.0), PackedColorArray([col]))
			_line(ci, p + Vector2(6 * sx, 0), p + Vector2(rr * 1.4 * sx, 0), col, clear)
			_line(ci, p + Vector2(0, 6 * sy), p + Vector2(0, rr * sy), col, clear)
	if crest:
		var cc := o + Vector2(w / 2.0, 0.0)
		var span := minf(150.0, w * 0.32)
		_line(ci, cc + Vector2(-13, 0), cc + Vector2(-span, 0), col, clear, 1.2)
		_line(ci, cc + Vector2(13, 0), cc + Vector2(span, 0), col, clear, 1.2)
		var st := star(cc, 9.5, 4.8, 8)
		RenderingServer.canvas_item_add_polygon(ci, st, PackedColorArray([Color(0.08, 0.05, 0.06, 1.0)]))
		var stc := st.duplicate()
		stc.append(st[0])
		var cols2 := PackedColorArray()
		for i in range(stc.size()):
			cols2.append(col)
		RenderingServer.canvas_item_add_polyline(ci, stc, cols2, 1.3, true)
		RenderingServer.canvas_item_add_polygon(ci, diamond(cc, 2.8), PackedColorArray([col]))
