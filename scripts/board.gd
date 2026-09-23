extends Control

signal cleared(stars: int)
signal changed

const LoomPlay = preload("res://scripts/play.gd")

const BG := Color("14110e")
const SURFACE := Color("241c16")
const FG := Color("f4ecdf")
const EMBER := Color("d4654a")
const PAIRS := [
	Color("e2a14a"),
	Color("3aa89a"),
	Color("d4656a"),
	Color("5b92d6"),
	Color("8eae45"),
	Color("b07cc4"),
	Color("e07a3d"),
	Color("5ec4d4"),
]

var level: Dictionary
var paths: Array = []
var active := -1
var hints := 0
var history: Array = []
var won := false

var _dragging := false
var _drag_start := Vector2i(-1, -1)
var _drag_last := Vector2i(-1, -1)
var _drag_moved := false
var _drag_before: Array = []
var _drag_pair := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func load_level(next: Dictionary) -> void:
	level = next
	paths = LoomPlay.fresh_paths(level)
	active = -1
	hints = 0
	history = []
	won = false
	_dragging = false
	queue_redraw()


func can_undo() -> bool:
	return not history.is_empty()


func can_hint() -> bool:
	return not won and LoomPlay.apply_hint(level, paths) != null


func can_reset() -> bool:
	for path in paths:
		if not path.is_empty():
			return true
	return false


func undo() -> void:
	if history.is_empty():
		return
	paths = history.pop_back()
	_sync(false)


func reset_board() -> void:
	var fresh: Array = LoomPlay.fresh_paths(level)
	if LoomPlay.same_paths(fresh, paths):
		return
	history.append(LoomPlay.clone_paths(paths))
	paths = fresh
	active = -1
	_sync(false)


func hint() -> void:
	if won:
		return
	var next = LoomPlay.apply_hint(level, paths)
	if next == null:
		return
	history.append(LoomPlay.clone_paths(paths))
	hints += 1
	paths = next
	_sync(true)


func status_text() -> String:
	var ev: Dictionary = LoomPlay.evaluate(level, paths)
	if ev["solved"]:
		return "Every thread holds."
	var parts := ["%d of %d linked" % [ev["linked"], ev["total"]]]
	if level["fill"]:
		parts.append("%d still dark" % ev["open_left"])
	if int(ev["beads_left"]) > 0:
		parts.append("%d beads left" % ev["beads_left"])
	return " · ".join(parts)


func forecast() -> int:
	return LoomPlay.stars_for_hints(hints)


func _cell_size() -> Vector2:
	return size / Vector2(int(level["w"]), int(level["h"]))


func _cell_at(local: Vector2) -> Vector2i:
	if level.is_empty() or size.x <= 1.0 or size.y <= 1.0:
		return Vector2i(-1, -1)
	if local.x < 0.0 or local.y < 0.0 or local.x > size.x or local.y > size.y:
		return Vector2i(-1, -1)
	var cs := _cell_size()
	var c := clampi(int(local.x / cs.x), 0, int(level["w"]) - 1)
	var r := clampi(int(local.y / cs.y), 0, int(level["h"]) - 1)
	return Vector2i(c, r)


func _center(cell: Vector2i) -> Vector2:
	var cs := _cell_size()
	return cs * Vector2(cell.x + 0.5, cell.y + 0.5)


func _pair_color(pair: int) -> Color:
	return PAIRS[pair % PAIRS.size()]


func _sync(_play_tone: bool) -> void:
	var ev: Dictionary = LoomPlay.evaluate(level, paths)
	var just: bool = bool(ev["solved"]) and not won
	won = bool(ev["solved"])
	queue_redraw()
	changed.emit()
	if just:
		cleared.emit(LoomPlay.stars_for_hints(hints))


func _push_history() -> void:
	history.append(LoomPlay.clone_paths(paths))
	if history.size() > 80:
		history.pop_front()


func _tap(cell: Vector2i) -> void:
	if active >= 0:
		var path: Array = paths[active]
		var index := LoomPlay.index_of(path, cell)
		if index >= 0:
			var cut := LoomPlay.clone_paths(paths)
			cut[active] = path.slice(0, index + 1)
			if not LoomPlay.same_paths(cut, paths):
				_push_history()
				paths = cut
				_sync(true)
			return
		if not path.is_empty() and path[path.size() - 1] != cell:
			var steps: Array = LoomPlay.line_cells(path[path.size() - 1], cell)
			var next = paths
			var ok := not steps.is_empty()
			for step in steps:
				var extended = LoomPlay.extend(level, next, active, step)
				if extended == null:
					ok = false
					break
				next = extended
			if ok and not LoomPlay.same_paths(next, paths):
				_push_history()
				paths = next
				_sync(true)
				return
	var grabbed = LoomPlay.grab(level, paths, cell)
	if grabbed == null:
		return
	active = int(grabbed["pair"])
	if not LoomPlay.same_paths(grabbed["paths"], paths):
		_push_history()
		paths = grabbed["paths"]
		_sync(true)
	else:
		queue_redraw()


func _drag_to(cell: Vector2i) -> void:
	var working = paths
	if _drag_pair < 0:
		var grabbed = LoomPlay.grab(level, working, _drag_start)
		if grabbed == null:
			return
		_drag_pair = int(grabbed["pair"])
		active = _drag_pair
		working = grabbed["paths"]
	var path: Array = working[_drag_pair]
	if path.is_empty():
		return
	var head: Vector2i = path[path.size() - 1]
	if head == cell:
		if not LoomPlay.same_paths(working, paths):
			paths = working
			_sync(false)
		return
	var next = working
	for step in LoomPlay.line_cells(head, cell):
		var extended = LoomPlay.extend(level, next, _drag_pair, step)
		if extended == null:
			break
		next = extended
	if not LoomPlay.same_paths(next, paths):
		paths = next
		_sync(false)


func _gui_input(event: InputEvent) -> void:
	if won or level.is_empty():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var cell := _cell_at(event.position)
		if event.pressed:
			if cell.x < 0:
				return
			_dragging = true
			_drag_start = cell
			_drag_last = cell
			_drag_moved = false
			_drag_before = LoomPlay.clone_paths(paths)
			_drag_pair = -1
		elif _dragging:
			_dragging = false
			if not _drag_moved:
				_tap(_drag_start)
			elif not LoomPlay.same_paths(_drag_before, paths):
				history.append(_drag_before)
				if history.size() > 80:
					history.pop_front()
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var cell := _cell_at(event.position)
		if cell.x < 0 or cell == _drag_last:
			return
		_drag_moved = true
		_drag_last = cell
		_drag_to(cell)
		accept_event()


func _draw() -> void:
	if level.is_empty():
		return
	var w := int(level["w"])
	var h := int(level["h"])
	var cs := _cell_size()
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	var owners := {}
	for pair in paths.size():
		for cell in paths[pair]:
			owners[LoomPlay.key_of(cell)] = pair
	for r in h:
		for c in w:
			var mod = level["mods"][r][c]
			var rect := Rect2(Vector2(c, r) * cs + Vector2(2, 2), cs - Vector2(4, 4))
			var key := "%d,%d" % [r, c]
			if mod["k"] == "block":
				draw_rect(rect, Color("0c0a08"))
				var hatch := Color(0.7, 0.64, 0.55, 0.28)
				draw_line(rect.position, rect.position + rect.size, hatch, 1.0)
				draw_line(rect.position + Vector2(rect.size.x, 0), rect.position + Vector2(0, rect.size.y), hatch, 1.0)
			elif owners.has(key):
				var tint: Color = _pair_color(int(owners[key]))
				tint.a = 0.36
				draw_rect(rect, tint.lerp(SURFACE, 0.45))
			else:
				draw_rect(rect, SURFACE)
	for pair in paths.size():
		var path: Array = paths[pair]
		if path.size() < 2:
			continue
		var points := PackedVector2Array()
		for cell in path:
			points.append(_center(cell))
		draw_polyline(points, _pair_color(pair), maxf(6.0, cs.x * 0.34), true)
	var font := ThemeDB.fallback_font
	var bead_size := int(cs.y * 0.42)
	for r in h:
		for c in w:
			var mod = level["mods"][r][c]
			var center := _center(Vector2i(c, r))
			if mod["k"] == "rail":
				var span := cs.x * 0.28
				var gap := cs.y * 0.12
				if mod["axis"] == "h":
					draw_line(center + Vector2(-span, -gap), center + Vector2(span, -gap), FG, 2.0)
					draw_line(center + Vector2(-span, gap), center + Vector2(span, gap), FG, 2.0)
				else:
					draw_line(center + Vector2(-gap, -span), center + Vector2(-gap, span), FG, 2.0)
					draw_line(center + Vector2(gap, -span), center + Vector2(gap, span), FG, 2.0)
			elif mod["k"] == "hook":
				var arm := cs.x * 0.16
				draw_line(center + Vector2(-arm, -arm), center + Vector2(-arm, arm), EMBER, 2.5)
				draw_line(center + Vector2(-arm, arm), center + Vector2(arm, arm), EMBER, 2.5)
			elif mod["k"] == "gate":
				var tip := cs.x * 0.22
				var base := cs.x * 0.16
				var poly := PackedVector2Array()
				match int(mod["dir"]):
					0:
						poly = PackedVector2Array([center + Vector2(0, -tip), center + Vector2(base, tip * 0.7), center + Vector2(-base, tip * 0.7)])
					1:
						poly = PackedVector2Array([center + Vector2(tip, 0), center + Vector2(-tip * 0.7, -base), center + Vector2(-tip * 0.7, base)])
					2:
						poly = PackedVector2Array([center + Vector2(0, tip), center + Vector2(-base, -tip * 0.7), center + Vector2(base, -tip * 0.7)])
					_:
						poly = PackedVector2Array([center + Vector2(-tip, 0), center + Vector2(tip * 0.7, -base), center + Vector2(tip * 0.7, base)])
				draw_colored_polygon(poly, FG)
			elif mod["k"] == "bead":
				var color := _pair_color(int(mod["pair"]))
				draw_circle(center, cs.x * 0.24, BG)
				draw_arc(center, cs.x * 0.24, 0, TAU, 24, color, 2.0, true)
				draw_string(font, Vector2(c, r) * cs + Vector2(0, cs.y * 0.66), str(int(mod["n"])), HORIZONTAL_ALIGNMENT_CENTER, cs.x, bead_size, color)
	for pair in level["ends"].size():
		var ends: Array = level["ends"][pair]
		var color := _pair_color(pair)
		var done := false
		if paths[pair].size() >= 2:
			var path: Array = paths[pair]
			done = (path[0] == ends[0] and path[path.size() - 1] == ends[1]) or (path[0] == ends[1] and path[path.size() - 1] == ends[0])
		for end in ends:
			var center := _center(end)
			if done:
				draw_arc(center, cs.x * 0.40, 0, TAU, 28, color, 2.0, true)
			draw_circle(center, cs.x * 0.30, color)
			_glyph(pair, center, cs.x * 0.12)
			if active >= 0 and not paths[active].is_empty() and paths[active][paths[active].size() - 1] == end:
				draw_arc(center, cs.x * 0.40, 0, TAU, 28, FG, 1.5, true)


func _glyph(pair: int, center: Vector2, s: float) -> void:
	var ink := Color("14110e")
	match pair % 8:
		0:
			draw_circle(center, s * 0.55, ink)
		1:
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(0, -s), center + Vector2(s, 0), center + Vector2(0, s), center + Vector2(-s, 0)
			]), ink)
		2:
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(0, -s), center + Vector2(s, s * 0.8), center + Vector2(-s, s * 0.8)
			]), ink)
		3:
			draw_rect(Rect2(center - Vector2(s * 0.7, s * 0.7), Vector2(s * 1.4, s * 1.4)), ink)
		4:
			draw_line(center + Vector2(-s, 0), center + Vector2(s, 0), ink, 2.0)
			draw_line(center + Vector2(0, -s), center + Vector2(0, s), ink, 2.0)
		5:
			draw_arc(center, s * 0.7, 0, TAU, 16, ink, 2.0, true)
		6:
			draw_circle(center + Vector2(-s * 0.45, 0), s * 0.35, ink)
			draw_circle(center + Vector2(s * 0.45, 0), s * 0.35, ink)
		_:
			draw_rect(Rect2(center - Vector2(s, s * 0.28), Vector2(s * 2.0, s * 0.56)), ink)
