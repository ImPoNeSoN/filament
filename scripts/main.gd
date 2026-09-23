extends Control

const LoomPlay = preload("res://scripts/play.gd")
const BoardScript = preload("res://scripts/board.gd")

const BG := Color("14110e")
const SURFACE := Color("241c16")
const FG := Color("f4ecdf")
const MUTED := Color("b3a28c")
const LINE := Color("3d3228")
const DEEP := Color("0c0a08")

var levels: Array = []
var save := {"cleared": {}, "last": 1}
var loom_id := 1

var home: Control
var atlas: Control
var play: Control
var board: Control
var continue_button: Button
var progress_label: Label
var atlas_list: VBoxContainer
var kicker: Label
var title_label: Label
var rule_label: Label
var status_label: Label
var forecast_label: Label
var undo_button: Button
var hint_button: Button
var reset_button: Button
var win_box: PanelContainer
var win_title: Label
var win_copy: Label
var next_button: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_load_levels()
	_load_save()
	_build()
	_show_home()


func _unhandled_input(event: InputEvent) -> void:
	if not play.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Z:
			board.undo()
		elif event.keycode == KEY_H:
			board.hint()
		elif event.keycode == KEY_ESCAPE:
			_show_home()


func _load_levels() -> void:
	var text := FileAccess.get_file_as_string("res://data/levels.json")
	var data = JSON.parse_string(text)
	for raw in data["levels"]:
		var mods: Array = []
		for row in raw["mods"]:
			var parsed: Array = []
			for token in row:
				parsed.append(_parse_mod(str(token)))
			mods.append(parsed)
		var ends: Array = []
		for pair in raw["ends"]:
			ends.append([_vec(pair[0]), _vec(pair[1])])
		var solution: Array = []
		for path in raw["solution"]:
			var points: Array = []
			for point in path:
				points.append(_vec(point))
			solution.append(points)
		levels.append({
			"id": int(raw["id"]),
			"chapter": int(raw["chapter"]),
			"name": str(raw["name"]),
			"rule": str(raw["rule"]),
			"w": int(raw["w"]),
			"h": int(raw["h"]),
			"fill": bool(raw["fill"]),
			"mods": mods,
			"ends": ends,
			"solution": solution,
		})


func _parse_mod(token: String) -> Dictionary:
	if token == "b":
		return {"k": "block"}
	if token == "h":
		return {"k": "hook"}
	if token == "rh":
		return {"k": "rail", "axis": "h"}
	if token == "rv":
		return {"k": "rail", "axis": "v"}
	if token.begins_with("g"):
		return {"k": "gate", "dir": int(token.substr(1))}
	if token.begins_with("d"):
		var bits := token.substr(1).split(":")
		return {"k": "bead", "pair": int(bits[0]), "n": int(bits[1])}
	return {"k": "open"}


func _vec(pair: Array) -> Vector2i:
	return Vector2i(int(pair[1]), int(pair[0]))


func _load_save() -> void:
	if not FileAccess.file_exists("user://filament-save.json"):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("user://filament-save.json"))
	if typeof(parsed) == TYPE_DICTIONARY and parsed.has("cleared"):
		save = parsed


func _write_save() -> void:
	var file := FileAccess.open("user://filament-save.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save))


func _continue_id() -> int:
	for id in range(1, 101):
		if not save["cleared"].has(str(id)):
			return id
	return 100


func _lit_count() -> int:
	return save["cleared"].size()


func _star_count() -> int:
	var total := 0
	for value in save["cleared"].values():
		total += int(value)
	return total


func _build() -> void:
	var background := ColorRect.new()
	background.color = BG
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	_build_home()
	_build_atlas()
	_build_play()


func _build_home() -> void:
	home = _column(28)
	var k := Label.new()
	k.text = "POCKET PUZZLES"
	k.add_theme_color_override("font_color", MUTED)
	k.add_theme_font_size_override("font_size", 13)
	home.add_child(k)
	var heading := Label.new()
	heading.text = "Filament"
	heading.add_theme_color_override("font_color", FG)
	heading.add_theme_font_size_override("font_size", 56)
	home.add_child(heading)
	var lede := Label.new()
	lede.text = "One hundred looms. Link each sigil to its twin. Every chapter adds a rule, and the weave gets tighter."
	lede.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lede.add_theme_color_override("font_color", MUTED)
	lede.add_theme_font_size_override("font_size", 18)
	home.add_child(lede)
	progress_label = Label.new()
	progress_label.add_theme_color_override("font_color", MUTED)
	home.add_child(progress_label)
	continue_button = _button("Continue", true)
	continue_button.pressed.connect(func() -> void: _open(_continue_id()))
	home.add_child(continue_button)
	var atlas_button := _button("Atlas", false)
	atlas_button.pressed.connect(_show_atlas)
	home.add_child(atlas_button)
	add_child(home)


func _build_atlas() -> void:
	atlas = VBoxContainer.new()
	atlas.set_anchors_preset(Control.PRESET_FULL_RECT)
	atlas.offset_left = 12
	atlas.offset_top = 12
	atlas.offset_right = -12
	atlas.offset_bottom = -12
	atlas.visible = false
	var head := HBoxContainer.new()
	var back := _button("Back", false)
	back.custom_minimum_size = Vector2(96, 44)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(_show_home)
	head.add_child(back)
	var heading := Label.new()
	heading.text = "Atlas"
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading.add_theme_color_override("font_color", FG)
	heading.add_theme_font_size_override("font_size", 28)
	head.add_child(heading)
	atlas.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	atlas_list = VBoxContainer.new()
	atlas_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	atlas_list.add_theme_constant_override("separation", 16)
	scroll.add_child(atlas_list)
	atlas.add_child(scroll)
	add_child(atlas)


func _build_play() -> void:
	play = VBoxContainer.new()
	play.set_anchors_preset(Control.PRESET_FULL_RECT)
	play.offset_left = 8
	play.offset_top = 8
	play.offset_right = -8
	play.offset_bottom = -8
	play.add_theme_constant_override("separation", 8)
	play.visible = false
	var head := HBoxContainer.new()
	var back := _button("Back", false)
	back.custom_minimum_size = Vector2(88, 44)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(_show_home)
	head.add_child(back)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kicker = Label.new()
	kicker.add_theme_color_override("font_color", MUTED)
	kicker.add_theme_font_size_override("font_size", 13)
	title_label = Label.new()
	title_label.add_theme_color_override("font_color", FG)
	title_label.add_theme_font_size_override("font_size", 28)
	titles.add_child(kicker)
	titles.add_child(title_label)
	head.add_child(titles)
	play.add_child(head)
	rule_label = Label.new()
	rule_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rule_label.add_theme_color_override("font_color", FG)
	play.add_child(rule_label)
	board = BoardScript.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.changed.connect(_refresh_play_chrome)
	board.cleared.connect(_on_cleared)
	play.add_child(board)
	status_label = Label.new()
	status_label.add_theme_color_override("font_color", MUTED)
	play.add_child(status_label)
	forecast_label = Label.new()
	forecast_label.add_theme_color_override("font_color", MUTED)
	play.add_child(forecast_label)
	var dock := HBoxContainer.new()
	dock.add_theme_constant_override("separation", 8)
	undo_button = _button("Undo", false)
	hint_button = _button("Hint", false)
	reset_button = _button("Reset", false)
	undo_button.pressed.connect(board.undo)
	hint_button.pressed.connect(board.hint)
	reset_button.pressed.connect(board.reset_board)
	dock.add_child(undo_button)
	dock.add_child(hint_button)
	dock.add_child(reset_button)
	play.add_child(dock)
	add_child(play)
	_build_win()


func _build_win() -> void:
	win_box = PanelContainer.new()
	win_box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	win_box.offset_top = -280
	win_box.offset_left = 12
	win_box.offset_right = -12
	win_box.offset_bottom = -12
	win_box.visible = false
	win_box.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = SURFACE
	style.border_color = LINE
	style.set_border_width_all(1)
	style.set_corner_radius_all(22)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	win_box.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	win_title = Label.new()
	win_title.add_theme_color_override("font_color", FG)
	win_title.add_theme_font_size_override("font_size", 28)
	win_copy = Label.new()
	win_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	win_copy.add_theme_color_override("font_color", MUTED)
	box.add_child(win_title)
	box.add_child(win_copy)
	next_button = _button("Next loom", true)
	next_button.pressed.connect(_next_or_atlas)
	var replay := _button("Replay", false)
	replay.pressed.connect(_replay)
	var to_atlas := _button("Atlas", false)
	to_atlas.pressed.connect(_show_atlas)
	box.add_child(next_button)
	box.add_child(replay)
	box.add_child(to_atlas)
	win_box.add_child(box)
	add_child(win_box)


func _column(margin: int) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = margin
	box.offset_top = margin + 12
	box.offset_right = -margin
	box.offset_bottom = -margin
	box.add_theme_constant_override("separation", 14)
	return box


func _pill(fill: Color, border: Color = Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1 if border.a > 0.0 else 0)
	style.set_corner_radius_all(24)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _button(text: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 48)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 16)
	var fill := FG if primary else SURFACE
	var ink := DEEP if primary else FG
	button.add_theme_color_override("font_color", ink)
	button.add_theme_color_override("font_hover_color", ink)
	button.add_theme_color_override("font_pressed_color", ink)
	button.add_theme_color_override("font_disabled_color", MUTED)
	button.add_theme_stylebox_override("normal", _pill(fill, LINE if not primary else Color(0, 0, 0, 0)))
	button.add_theme_stylebox_override("hover", _pill(fill.darkened(0.06), LINE if not primary else Color(0, 0, 0, 0)))
	button.add_theme_stylebox_override("pressed", _pill(fill.darkened(0.12), LINE if not primary else Color(0, 0, 0, 0)))
	button.add_theme_stylebox_override("disabled", _pill(fill.darkened(0.2), LINE))
	return button


func _show_home() -> void:
	var lit := _lit_count()
	progress_label.text = "%d of 100 lit · %d of 300 stars" % [lit, _star_count()]
	continue_button.text = "Revisit loom 100" if lit >= 100 else "Continue · Loom %d" % _continue_id()
	home.visible = true
	atlas.visible = false
	play.visible = false
	win_box.visible = false


func _show_atlas() -> void:
	_fill_atlas()
	home.visible = false
	atlas.visible = true
	play.visible = false
	win_box.visible = false


func _fill_atlas() -> void:
	for child in atlas_list.get_children():
		child.queue_free()
	var next_id := _continue_id()
	for chapter in 10:
		var first: Dictionary = levels[chapter * 10]
		var name := Label.new()
		name.text = str(first["name"])
		name.add_theme_color_override("font_color", FG)
		name.add_theme_font_size_override("font_size", 22)
		atlas_list.add_child(name)
		var rule := Label.new()
		rule.text = str(first["rule"])
		rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rule.add_theme_color_override("font_color", MUTED)
		atlas_list.add_child(rule)
		var grid := GridContainer.new()
		grid.columns = 5
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for i in 10:
			var id := chapter * 10 + i + 1
			var stars := int(save["cleared"].get(str(id), 0))
			var unlocked := id == 1 or save["cleared"].has(str(id - 1))
			var label := str(id)
			if stars > 0:
				label += "  " + str(stars)
			var pip := _button(label, false)
			pip.disabled = not unlocked
			pip.custom_minimum_size = Vector2(0, 52)
			if id == next_id and stars == 0:
				pip.add_theme_color_override("font_color", FG)
			pip.pressed.connect(_open.bind(id))
			grid.add_child(pip)
		atlas_list.add_child(grid)


func _open(id: int) -> void:
	loom_id = clampi(id, 1, levels.size())
	board.load_level(levels[loom_id - 1])
	win_box.visible = false
	home.visible = false
	atlas.visible = false
	play.visible = true
	_refresh_play_chrome()


func _refresh_play_chrome() -> void:
	var level: Dictionary = levels[loom_id - 1]
	var within := ((loom_id - 1) % 10) + 1
	kicker.text = "%s · %d / 10 · %d×%d" % [level["name"], within, level["w"], level["h"]]
	title_label.text = "Loom %d" % loom_id
	rule_label.text = str(level["rule"])
	status_label.text = board.status_text()
	var words := ["", "One star if you solve now", "Two stars if you solve now", "Three stars if you solve now"]
	forecast_label.text = words[board.forecast()]
	undo_button.disabled = not board.can_undo()
	hint_button.disabled = not board.can_hint()
	reset_button.disabled = not board.can_reset()


func _on_cleared(stars: int) -> void:
	var key := str(loom_id)
	var best := maxi(int(save["cleared"].get(key, 0)), stars)
	save["cleared"][key] = best
	save["last"] = loom_id
	_write_save()
	win_title.text = "Loom %d is lit" % loom_id
	if board.hints == 0:
		win_copy.text = "No hints. Full marks."
	else:
		win_copy.text = "Hints used: %d. Replay if you want them back." % board.hints
	next_button.text = "Back to the atlas" if loom_id >= 100 else "Next loom"
	win_box.visible = true
	_refresh_play_chrome()


func _next_or_atlas() -> void:
	if loom_id >= 100:
		_show_atlas()
	else:
		_open(loom_id + 1)


func _replay() -> void:
	win_box.visible = false
	board.load_level(levels[loom_id - 1])
	_refresh_play_chrome()
