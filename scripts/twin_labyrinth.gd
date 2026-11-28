class_name TwinLabyrinth
extends RefCounted

enum Phase { ROLL, MOVE, DUEL, WON, LOST }

const Board = preload("res://scripts/labyrinth.gd")
const START := "S"
const SPAWN := "H"
const SAFE := "o"
const EXIT := "E"
const SUITS := ["♣", "♦", "♥", "♠"]
const RANKS_24 := ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10"]
const TARGET_24 := 24

var _layouts: Array = []
var _phase := Phase.ROLL
var _dice := Vector2i.ZERO
var _round := 1
var _active_lane := 0
var _turns_left := 0
var _has_stepped := false
var _duel_interrupts_move := false
var _last_duel_round := [0, 0]
var _chase_limit: int
var _runners: Array[Vector2i] = []
var _exits: Array[Vector2i] = []
var _snatchers: Array[Vector2i] = []
var _locked_gates: Array[Dictionary] = [{}, {}]
var _active_plates: Array[Dictionary] = [{}, {}]
var _safe_spots: Array[Dictionary] = [{}, {}]
var _stun := [0, 0]
var _escaped := [false, false]
var _captured := [false, false]
var _lost: bool = false
var _lost_lane: int = -1
var _pending_duels: Array[int] = []
var _duel_cards: Array[Dictionary] = []
var _duel_solution_hint: String = ""
var _duel_results: Array[Dictionary] = []
var _last_snatcher_paths: Array = [[], []]
var _last_duel_move: Dictionary = {}


func _init(custom_layouts: Array = [], chase_limit: int = 12) -> void:
	_layouts = custom_layouts if custom_layouts.size() == 2 else Board.LAYOUTS
	_chase_limit = chase_limit
	for lane in range(2):
		_runners.append(Board.find_tile(lane, START, _layouts))
		_exits.append(Board.find_tile(lane, EXIT, _layouts))
		_snatchers.append(Board.find_tile(lane, SPAWN, _layouts))
		for marker: String in Board.GATE_MARKERS:
			for cell in Board.find_all_tiles(lane, marker, _layouts):
				_locked_gates[lane][cell] = marker
		for cell in Board.find_all_tiles(lane, SAFE, _layouts):
			_safe_spots[lane][cell] = true


func get_layouts() -> Array:
	return _layouts


func get_echo_steps() -> Vector2i:
	if _dice == Vector2i.ZERO:
		return Vector2i.ZERO
	var echo_a := absi(_dice.x - _dice.y)
	var echo_b := mini(_dice.x, _dice.y) if echo_a != 0 else _dice.x + _dice.y
	return Vector2i(echo_a, echo_b)


func get_state() -> Dictionary:
	return {
		"phase": _phase,
		"round": _round,
		"active_lane": _active_lane,
		"turns_left": _turns_left,
		"dice": _dice,
		"echo_steps": get_echo_steps(),
		"runners": _runners.duplicate(),
		"snatchers": _snatchers.duplicate(),
		"locked_gates": _locked_gates.duplicate(true),
		"active_plates": _active_plates.duplicate(true),
		"safe_spots": _safe_spots.duplicate(true),
		"stun": _stun.duplicate(),
		"escaped": _escaped.duplicate(),
		"captured": _captured.duplicate(),
		"lost_lane": _lost_lane,
		"pending_duels": _pending_duels.duplicate(),
		"duel_results": _duel_results.duplicate(true),
		"last_snatcher_paths": _last_snatcher_paths.duplicate(true),
		"last_duel_move": _last_duel_move.duplicate(true),
	}


func roll_dice() -> bool:
	if _phase != Phase.ROLL:
		return false
	_dice = Vector2i(randi_range(1, 6), randi_range(1, 6))
	_turns_left = _dice.x + _dice.y
	_duel_results.clear()
	_last_snatcher_paths = [[], []]
	_last_duel_move = {}
	_phase = Phase.MOVE
	return true


func can_preview() -> bool:
	return _round == 1 and _active_lane == 0 and not _has_stepped and (_phase == Phase.ROLL or _phase == Phase.MOVE)


func available_steps() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if _phase != Phase.MOVE or should_end_turn():
		return cells
	for direction in Board.DIRECTIONS:
		var cell: Vector2i = _runners[_active_lane] + direction
		if _runner_can_enter(_active_lane, cell):
			cells.append(cell)
	return cells


func needs_partner_help_at_exit() -> bool:
	return not _can_escape(_active_lane) and _runners[_active_lane].distance_squared_to(_exits[_active_lane]) == 1


func _can_escape(lane: int) -> bool:
	return _locked_gates[1 - lane].is_empty()


func _runner_can_enter(lane: int, cell: Vector2i) -> bool:
	return Board.tile(lane, cell, _layouts) != "#" and not _locked_gates[lane].has(cell) and (cell != _exits[lane] or _can_escape(lane))


func should_end_turn() -> bool:
	return _phase == Phase.MOVE and (_turns_left == 0 or _escaped[_active_lane] or _captured[_active_lane])


func can_end_turn() -> bool:
	return _phase == Phase.MOVE and (_active_lane == 0 or should_end_turn())


func step_runner(cell: Vector2i) -> bool:
	if cell not in available_steps():
		return false

	_has_stepped = true
	_turns_left -= 1
	_set_runner(_active_lane, cell)
	if _escaped[0] and _escaped[1]:
		_phase = Phase.WON
	elif not _escaped[_active_lane] and cell == _snatchers[_active_lane] and _stun[_active_lane] == 0:
		_queue_duel(_active_lane)
		_duel_interrupts_move = true
		_advance()
	return true


func end_turn() -> bool:
	if not can_end_turn():
		return false
	if _active_lane == 0:
		_active_lane = 1
		return true

	_turns_left = 0
	var echo := get_echo_steps()
	for lane in range(2):
		_move_snatcher(lane, mini(echo[lane], _chase_limit))
	_advance()
	return true


func get_duel() -> Dictionary:
	if _phase != Phase.DUEL:
		return {}
	return {
		"lane": _pending_duels[0],
		"cards": _duel_cards.duplicate(true),
		"solution_hint": _duel_solution_hint,
	}


func resolve_duel_24(won: bool, fast_bonus: bool = false, player_expr: String = "") -> bool:
	if _phase != Phase.DUEL:
		return false
	_finish_duel_24(won, fast_bonus, player_expr)
	_advance()
	return true


func _set_runner(lane: int, cell: Vector2i) -> void:
	var previous := _runners[lane]
	if previous != cell:
		_safe_spots[lane].erase(previous)
	_runners[lane] = cell
	var marker := Board.tile(lane, cell, _layouts)
	_escaped[lane] = marker == EXIT and _can_escape(lane)
	var plate_index: int = Board.PLATE_MARKERS.find(marker)
	if plate_index >= 0 and not _active_plates[lane].has(cell):
		_active_plates[lane][cell] = true
		var other_gates := _locked_gates[1 - lane]
		var gate_marker: String = Board.GATE_MARKERS[plate_index]
		for gate_cell: Vector2i in other_gates.keys():
			if other_gates[gate_cell] == gate_marker:
				other_gates.erase(gate_cell)


func _blocked_for_snatcher(lane: int) -> Dictionary:
	return _locked_gates[lane].merged(_safe_spots[lane])


func _move_snatcher(lane: int, steps: int) -> void:
	var walked: Array[Vector2i] = []
	_last_snatcher_paths[lane] = walked
	if _escaped[lane] or _last_duel_round[lane] == _round:
		return
	if _captured[lane]:
		_queue_duel(lane)
		return
	if _stun[lane] > 0:
		_stun[lane] -= 1
		return

	var target := _runners[lane]
	var start := _snatchers[lane]
	if steps > 0 and start != target:
		var path := Board.shortest_path(lane, start, target, _layouts, "", _blocked_for_snatcher(lane))
		if path.is_empty():
			# When a Safe Spot cuts off the target, approach only as far as its near edge.
			path = Board.shortest_path(lane, start, target, _layouts, "", _locked_gates[lane])
		for index in range(mini(steps, path.size())):
			var cell := path[index]
			if _safe_spots[lane].has(cell):
				break
			walked.append(cell)
			_snatchers[lane] = cell
	if _snatchers[lane] == target:
		_queue_duel(lane)


func _queue_duel(lane: int) -> void:
	_captured[lane] = true
	_last_duel_round[lane] = _round
	_pending_duels.append(lane)


func _advance() -> void:
	if _lost:
		_pending_duels.clear()
		_phase = Phase.LOST
		return
	if not _pending_duels.is_empty():
		_phase = Phase.DUEL
		_deal_solvable_24()
		return
	if _escaped[0] and _escaped[1]:
		_phase = Phase.WON
	elif _duel_interrupts_move:
		_phase = Phase.MOVE
		_duel_interrupts_move = false
	else:
		_phase = Phase.ROLL
		_round += 1
		_active_lane = 0


func _deal_solvable_24() -> void:
	# Draw 4 cards (A=1..10 across 4 suits) guaranteed to have a valid Game 24 solution.
	for _attempt in range(80):
		var deck: Array[int] = []
		for i in range(40):
			deck.append(i)
		deck.shuffle()

		var cards: Array[Dictionary] = []
		var vals: Array[int] = []
		for k in range(4):
			var id := deck[k]
			var rank_idx := id % RANKS_24.size()
			var suit_idx := floori(float(id) / float(RANKS_24.size()))
			var val := rank_idx + 1
			vals.append(val)
			cards.append({
				"label": RANKS_24[rank_idx] + SUITS[suit_idx],
				"value": val,
			})

		var sol := find_solution_24(vals)
		if sol != "":
			_duel_cards = cards
			_duel_solution_hint = sol
			return

	# Fallback guaranteed solvable hand (6, 4, 2, 1)
	_duel_cards = [
		{"label": "6♠", "value": 6},
		{"label": "4♥", "value": 4},
		{"label": "2♦", "value": 2},
		{"label": "A♣", "value": 1},
	]
	_duel_solution_hint = "(6 × 4) × (2 - 1)"


func _finish_duel_24(won: bool, fast_bonus: bool, player_expr: String) -> void:
	var lane: int = _pending_duels.pop_front()
	var outcome := "loss"
	var runner_path: Array[Vector2i] = []
	var snatcher_path: Array[Vector2i] = []
	var triggered_game_over := false

	if won and fast_bonus:
		outcome = "fast_win"
		_captured[lane] = false
		_stun[lane] = 2
		runner_path = _move_toward_exit(lane, 4)
	elif won:
		outcome = "win"
		_captured[lane] = false
		_stun[lane] = 1
		runner_path = _move_toward_exit(lane, 2)
	else:
		# Loss: Elf stays wrapped in Snatcher's tail and is dragged toward SpawnSnatcher!
		_captured[lane] = true
		var drag_result := _drag_toward_lair(lane)
		runner_path = drag_result["path"]
		snatcher_path = drag_result["path"].duplicate()
		triggered_game_over = drag_result["reached_lair"]
		if triggered_game_over:
			_lost = true
			_lost_lane = lane

	_last_duel_move = {
		"lane": lane,
		"outcome": outcome,
		"runner_path": runner_path,
		"snatcher_path": snatcher_path,
		"game_over": triggered_game_over,
	}

	_duel_results.append({
		"lane": lane,
		"outcome": outcome,
		"cards": _duel_cards.duplicate(true),
		"player_expr": player_expr,
		"solution_hint": _duel_solution_hint,
		"runner_path": runner_path.duplicate(),
		"snatcher_path": snatcher_path.duplicate(),
		"game_over": triggered_game_over,
	})


func _move_toward_exit(lane: int, steps: int) -> Array[Vector2i]:
	var walked: Array[Vector2i] = []
	var exit_cell := _exits[lane]
	var path := Board.shortest_path(lane, _runners[lane], exit_cell, _layouts, "", _locked_gates[lane])
	if path.is_empty():
		path = Board.shortest_path(lane, _runners[lane], exit_cell, _layouts)
	for index in range(mini(steps, path.size())):
		var cell := path[index]
		if not _runner_can_enter(lane, cell):
			break
		_set_runner(lane, cell)
		walked.append(cell)
	return walked


func _drag_toward_lair(lane: int) -> Dictionary:
	var walked: Array[Vector2i] = []
	var spawn := Board.find_tile(lane, SPAWN, _layouts)
	if _runners[lane] == spawn:
		_snatchers[lane] = spawn
		return {"path": walked, "reached_lair": true}

	var path := Board.shortest_path(lane, _runners[lane], spawn, _layouts, "", _blocked_for_snatcher(lane))
	var steps := mini(maxi(_dice.x, _dice.y), path.size())
	if steps > 0:
		for i in range(steps):
			walked.append(path[i])
		var dest := path[steps - 1]
		_runners[lane] = dest
		_snatchers[lane] = dest
	return {
		"path": walked,
		"reached_lair": _runners[lane] == spawn,
	}


# --- Exact rational arithmetic helpers for Game 24 ---

static func _gcd(a: int, b: int) -> int:
	var x := absi(a)
	var y := absi(b)
	while y != 0:
		var tmp := x % y
		x = y
		y = tmp
	return maxi(x, 1)


static func rat_make(num: int, den: int = 1) -> Vector2i:
	if den < 0:
		num = -num
		den = -den
	if num == 0:
		return Vector2i(0, 1)
	var g := _gcd(num, den)
	return Vector2i(num / g, den / g)


static func rat_apply(a: Vector2i, b: Vector2i, op: String) -> Vector2i:
	match op:
		"+":
			return rat_make(a.x * b.y + b.x * a.y, a.y * b.y)
		"-":
			return rat_make(a.x * b.y - b.x * a.y, a.y * b.y)
		"*", "×":
			return rat_make(a.x * b.x, a.y * b.y)
		"/", "÷", ":":
			if b.x == 0:
				return Vector2i(0, 0) # invalid division by zero
			return rat_make(a.x * b.y, a.y * b.x)
	return Vector2i(0, 0)


static func rat_format(r: Vector2i) -> String:
	if r.y == 1:
		return str(r.x)
	return "%d/%d" % [r.x, r.y]


static func rat_is_24(r: Vector2i) -> bool:
	return r.y == 1 and r.x == TARGET_24


static func find_solution_24(values: Array[int]) -> String:
	var items: Array[Dictionary] = []
	for v in values:
		items.append({"rat": rat_make(v, 1), "expr": str(v)})
	return _solve_24_recursive(items)


static func _solve_24_recursive(items: Array[Dictionary]) -> String:
	if items.size() == 1:
		var r: Vector2i = items[0]["rat"]
		return String(items[0]["expr"]) if rat_is_24(r) else ""

	var n := items.size()
	for i in range(n):
		for j in range(i + 1, n):
			var rest: Array[Dictionary] = []
			for k in range(n):
				if k != i and k != j:
					rest.append(items[k])

			var a: Vector2i = items[i]["rat"]
			var b: Vector2i = items[j]["rat"]
			var ea: String = items[i]["expr"]
			var eb: String = items[j]["expr"]

			var candidates: Array[Dictionary] = [
				{"rat": rat_apply(a, b, "+"), "expr": "(%s + %s)" % [ea, eb]},
				{"rat": rat_apply(a, b, "*"), "expr": "(%s × %s)" % [ea, eb]},
				{"rat": rat_apply(a, b, "-"), "expr": "(%s - %s)" % [ea, eb]},
				{"rat": rat_apply(b, a, "-"), "expr": "(%s - %s)" % [eb, ea]},
			]
			if b.x != 0:
				candidates.append({"rat": rat_apply(a, b, ":"), "expr": "(%s : %s)" % [ea, eb]})
			if a.x != 0:
				candidates.append({"rat": rat_apply(b, a, ":"), "expr": "(%s : %s)" % [eb, ea]})

			for cand in candidates:
				var cr: Vector2i = cand["rat"]
				if cr.y == 0:
					continue
				var next_items := rest.duplicate()
				next_items.append(cand)
				var found := _solve_24_recursive(next_items)
				if found != "":
					return found
	return ""
