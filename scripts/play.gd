extends RefCounted

static func key_of(p: Vector2i) -> String:
	return "%d,%d" % [p.y, p.x]


static func dir_between(a: Vector2i, b: Vector2i) -> int:
	var dr := b.y - a.y
	var dc := b.x - a.x
	if dr == -1 and dc == 0:
		return 0
	if dr == 0 and dc == 1:
		return 1
	if dr == 1 and dc == 0:
		return 2
	if dr == 0 and dc == -1:
		return 3
	return -1


static func axis_of(d: int) -> String:
	return "h" if d == 1 or d == 3 else "v"


static func clone_paths(paths: Array) -> Array:
	var out: Array = []
	for path in paths:
		var copy: Array = []
		for point in path:
			copy.append(point)
		out.append(copy)
	return out


static func fresh_paths(level: Dictionary) -> Array:
	var paths: Array = []
	for _i in level["ends"].size():
		paths.append([])
	return paths


static func same_paths(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if a[i].size() != b[i].size():
			return false
		for j in a[i].size():
			if a[i][j] != b[i][j]:
				return false
	return true


static func mod_at(level: Dictionary, p: Vector2i):
	if p.y < 0 or p.x < 0 or p.y >= int(level["h"]) or p.x >= int(level["w"]):
		return null
	return level["mods"][p.y][p.x]


static func index_of(path: Array, cell: Vector2i) -> int:
	for i in path.size():
		if path[i] == cell:
			return i
	return -1


static func endpoint_at(level: Dictionary, cell: Vector2i) -> int:
	for pair in level["ends"].size():
		var ends: Array = level["ends"][pair]
		if ends[0] == cell or ends[1] == cell:
			return pair
	return -1


static func bead_orders(level: Dictionary, pair: int, path: Array) -> Array:
	var orders: Array = []
	for cell in path:
		var mod = mod_at(level, cell)
		if mod != null and mod["k"] == "bead" and int(mod["pair"]) == pair:
			orders.append(int(mod["n"]))
	return orders


static func required_beads(level: Dictionary, pair: int) -> Array:
	var orders: Array = []
	for row in level["mods"]:
		for mod in row:
			if mod["k"] == "bead" and int(mod["pair"]) == pair:
				orders.append(int(mod["n"]))
	orders.sort()
	return orders


static func step_allowed(level: Dictionary, pair: int, path: Array, to: Vector2i) -> bool:
	if path.is_empty():
		return false
	var from: Vector2i = path[path.size() - 1]
	var dir := dir_between(from, to)
	if dir < 0:
		return false
	if to.y < 0 or to.x < 0 or to.y >= int(level["h"]) or to.x >= int(level["w"]):
		return false
	var dest = mod_at(level, to)
	if dest == null or dest["k"] == "block":
		return false
	if index_of(path, to) >= 0:
		return false
	var own: Array = level["ends"][pair]
	var hits_own: bool = bool(to == own[0]) or bool(to == own[1])
	if hits_own:
		if to == path[0]:
			return false
	elif endpoint_at(level, to) >= 0:
		return false
	if dest["k"] == "gate" and int(dest["dir"]) != dir:
		return false
	if dest["k"] == "rail" and axis_of(dir) != dest["axis"]:
		return false
	if dest["k"] == "bead":
		if int(dest["pair"]) != pair:
			return false
		var have := bead_orders(level, pair, path)
		for i in have.size():
			if int(have[i]) != i + 1:
				return false
		if int(dest["n"]) != have.size() + 1:
			return false
	var from_mod = mod_at(level, from)
	if from_mod != null and (from_mod["k"] == "rail" or from_mod["k"] == "hook"):
		if path.size() < 2:
			return false
		var incoming := dir_between(path[path.size() - 2], from)
		if incoming < 0:
			return false
		if from_mod["k"] == "rail":
			if incoming != dir or axis_of(dir) != from_mod["axis"]:
				return false
		elif incoming == dir:
			return false
	return true


static func grab(level: Dictionary, paths: Array, cell: Vector2i):
	for pair in paths.size():
		var index := index_of(paths[pair], cell)
		if index >= 0:
			var next := clone_paths(paths)
			next[pair] = paths[pair].slice(0, index + 1)
			return {"pair": pair, "paths": next}
	var end := endpoint_at(level, cell)
	if end < 0:
		return null
	var started := clone_paths(paths)
	started[end] = [cell]
	return {"pair": end, "paths": started}


static func extend(level: Dictionary, paths: Array, pair: int, to: Vector2i):
	var path: Array = paths[pair] if pair < paths.size() else []
	var on_self := index_of(path, to)
	if on_self >= 0:
		var cut := clone_paths(paths)
		cut[pair] = path.slice(0, on_self + 1)
		return cut
	if not step_allowed(level, pair, path, to):
		return null
	var next := clone_paths(paths)
	for other in next.size():
		if other == pair:
			continue
		var hit := index_of(next[other], to)
		if hit >= 0:
			next[other] = next[other].slice(0, hit)
	var grown: Array = path.duplicate()
	grown.append(to)
	next[pair] = grown
	return next


static func _path_complete(level: Dictionary, pair: int, path: Array) -> bool:
	var ends: Array = level["ends"][pair]
	if path.size() < 2:
		return false
	var forward: bool = path[0] == ends[0] and path[path.size() - 1] == ends[1]
	var backward: bool = path[0] == ends[1] and path[path.size() - 1] == ends[0]
	if not forward and not backward:
		return false
	for i in range(1, path.size()):
		if not step_allowed(level, pair, path.slice(0, i), path[i]):
			return false
	var need := required_beads(level, pair)
	var got := bead_orders(level, pair, path)
	if got.size() != need.size():
		return false
	for i in need.size():
		if int(got[i]) != int(need[i]):
			return false
	return true


static func evaluate(level: Dictionary, paths: Array) -> Dictionary:
	var ends: Array = level["ends"]
	var total: int = ends.size()
	var seen := {}
	var linked := 0
	var overlap := false
	for pair in total:
		var path: Array = paths[pair] if pair < paths.size() else []
		for cell in path:
			var key := key_of(cell)
			if seen.has(key):
				overlap = true
			seen[key] = true
			var mod = mod_at(level, cell)
			if mod == null or mod["k"] == "block":
				overlap = true
		if _path_complete(level, pair, path):
			linked += 1
	var open_left := 0
	var beads_left := 0
	for r in int(level["h"]):
		for c in int(level["w"]):
			var mod = level["mods"][r][c]
			if mod["k"] == "block":
				continue
			var key := "%d,%d" % [r, c]
			if not seen.has(key):
				open_left += 1
			if mod["k"] == "bead" and not seen.has(key):
				beads_left += 1
	var coverage: bool = (not level["fill"]) or open_left == 0
	var solved: bool = (not overlap) and linked == total and coverage and beads_left == 0
	return {
		"solved": solved,
		"linked": linked,
		"total": total,
		"open_left": open_left if level["fill"] else 0,
		"beads_left": beads_left,
	}


static func apply_hint(level: Dictionary, paths: Array):
	for pair in level["solution"].size():
		var solution: Array = level["solution"][pair]
		var current: Array = paths[pair] if pair < paths.size() else []
		var oriented: Array = solution
		if current.size() > 0 and current[0] == solution[solution.size() - 1]:
			oriented = solution.duplicate()
			oriented.reverse()
		var prefix := 0
		if current.size() > 0 and current[0] == oriented[0]:
			while prefix < current.size() and prefix < oriented.size() and current[prefix] == oriented[prefix]:
				prefix += 1
		if prefix == oriented.size() and current.size() == oriented.size():
			continue
		var length: int = int(mini(2, oriented.size())) if current.is_empty() else int(mini(oriented.size(), prefix + 1))
		var painted: Array = oriented.slice(0, length)
		var unchanged := painted.size() == current.size()
		if unchanged:
			for i in painted.size():
				if painted[i] != current[i]:
					unchanged = false
					break
		if unchanged:
			continue
		var next := clone_paths(paths)
		var used := {}
		for point in painted:
			used[key_of(point)] = true
		for other in next.size():
			if other == pair:
				continue
			var cut := -1
			for i in next[other].size():
				if used.has(key_of(next[other][i])):
					cut = i
					break
			if cut >= 0:
				next[other] = next[other].slice(0, cut)
		next[pair] = painted
		return next
	return null


static func line_cells(from: Vector2i, to: Vector2i) -> Array:
	var cells: Array = []
	var r := from.y
	var c := from.x
	var guard := 0
	while (r != to.y or c != to.x) and guard < 64:
		guard += 1
		var dr := signi(to.y - r)
		var dc := signi(to.x - c)
		if dr != 0 and dc != 0:
			if absi(to.x - c) > absi(to.y - r):
				c += dc
			else:
				r += dr
		else:
			r += dr
			c += dc
		cells.append(Vector2i(c, r))
	return cells


static func stars_for_hints(hints: int) -> int:
	if hints <= 0:
		return 3
	if hints == 1:
		return 2
	return 1
