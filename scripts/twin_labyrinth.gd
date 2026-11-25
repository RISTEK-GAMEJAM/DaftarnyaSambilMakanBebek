class_name TwinLabyrinth
extends RefCounted

enum Phase { ROLL, MOVE, DUEL, WON }

const Board = preload("res://scripts/labyrinth.gd")
const START := "S"
const SPAWN := "H"
const SAFE := "o"
const EXIT := "E"
const SUITS := ["♣", "♦", "♥", "♠"]
const RANKS := ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]

var _phase := Phase.ROLL
var _dice := Vector2i.ZERO
var _runners: Array[Vector2i] = []
var _snatchers: Array[Vector2i] = []
var _stun := [0, 0]
var _escaped := [false, false]
var _pending_duels: Array[int] = []
var _deck: Array[int] = []
var _player_hand: Array[int] = []
var _snatcher_hand: Array[int] = []
var _duel_results: Array[Dictionary] = []


func _init() -> void:
	for lane in range(2):
		_runners.append(Board.find_tile(lane, START))
		_snatchers.append(Board.find_tile(lane, SPAWN))


func get_state() -> Dictionary:
	return {
		"phase": _phase,
		"dice": _dice,
		"runners": _runners.duplicate(),
		"snatchers": _snatchers.duplicate(),
		"stun": _stun.duplicate(),
		"escaped": _escaped.duplicate(),
		"duel_results": _duel_results.duplicate(true),
	}


func roll_dice() -> bool:
	if _phase != Phase.ROLL:
		return false
	_dice = Vector2i(randi_range(1, 6), randi_range(1, 6))
	_duel_results.clear()
	_phase = Phase.MOVE
	return true


# die_for_a is the index (0 or 1). Each route lists the cells after the runner's current cell.
func move_runners(die_for_a: int, route_a: Array[Vector2i], route_b: Array[Vector2i]) -> bool:
	if _phase != Phase.MOVE or die_for_a < 0 or die_for_a > 1:
		return false
	if not _valid_route(0, route_a, _dice[die_for_a]):
		return false
	if not _valid_route(1, route_b, _dice[1 - die_for_a]):
		return false

	_move_runner(0, route_a)
	_move_runner(1, route_b)

	var echo_a := absi(_dice.x - _dice.y)
	var echo_b := mini(_dice.x, _dice.y) if echo_a != 0 else _dice.x + _dice.y
	_move_snatcher(0, echo_a)
	_move_snatcher(1, echo_b)
	_advance()
	return true


func get_duel() -> Dictionary:
	if _phase != Phase.DUEL:
		return {}
	return {
		"lane": _pending_duels[0],
		"player_cards": _card_names(_player_hand),
		"player_score": _score(_player_hand),
		"snatcher_card": _card_names(_snatcher_hand)[0],
	}


func hit() -> bool:
	if _phase != Phase.DUEL:
		return false
	_player_hand.append(_deck.pop_back())
	if _score(_player_hand) >= 21:
		_resolve_duel()
	return true


func stand() -> bool:
	if _phase != Phase.DUEL:
		return false
	_resolve_duel()
	return true


func _valid_route(lane: int, route: Array[Vector2i], steps: int) -> bool:
	if _escaped[lane]:
		return route.is_empty()
	if route.is_empty() or route.size() > steps:
		return false

	var previous := _runners[lane]
	for index in range(route.size()):
		var cell := route[index]
		var marker := Board.tile(lane, cell)
		if previous.distance_squared_to(cell) != 1 or marker == "#":
			return false
		if marker == EXIT:
			return index == route.size() - 1
		previous = cell
	return route.size() == steps


func _move_runner(lane: int, route: Array[Vector2i]) -> void:
	if route.is_empty():
		return
	_set_runner(lane, route.back())


func _set_runner(lane: int, cell: Vector2i) -> void:
	_runners[lane] = cell
	_escaped[lane] = Board.tile(lane, cell) == EXIT


func _move_snatcher(lane: int, steps: int) -> void:
	if _escaped[lane]:
		return
	var target := _runners[lane]
	var safe := Board.tile(lane, target) == SAFE
	if _stun[lane] > 0:
		_stun[lane] -= 1
	elif steps > 0 and _snatchers[lane] != target:
		var path := Board.shortest_path(lane, _snatchers[lane], target)
		if not path.is_empty():
			_snatchers[lane] = path[mini(steps, path.size()) - 1]
	if not safe and _snatchers[lane] == target:
		_pending_duels.append(lane)


func _advance() -> void:
	while not _pending_duels.is_empty():
		_phase = Phase.DUEL
		_deck.clear()
		for card in range(52):
			_deck.append(card)
		_deck.shuffle()
		_player_hand = [_deck.pop_back(), _deck.pop_back()]
		_snatcher_hand = [_deck.pop_back(), _deck.pop_back()]
		if _score(_player_hand) < 21:
			return
		_finish_duel()
	_phase = Phase.WON if _escaped[0] and _escaped[1] else Phase.ROLL


func _resolve_duel() -> void:
	_finish_duel()
	_advance()


func _finish_duel() -> void:
	var lane: int = _pending_duels.pop_front()
	var player_score := _score(_player_hand)
	if player_score < 21:
		while _score(_snatcher_hand) < 17:
			_snatcher_hand.append(_deck.pop_back())
	var snatcher_score := _score(_snatcher_hand)
	var outcome := "loss"

	if player_score == 21:
		outcome = "blackjack"
		_stun[lane] = 2
		_move_toward_exit(lane, 5)
	elif player_score < 21 and (snatcher_score > 21 or player_score > snatcher_score):
		outcome = "win"
		_stun[lane] = 1
		_move_toward_exit(lane, maxi(0, player_score - snatcher_score))
	else:
		_retreat(lane)

	_duel_results.append({
		"lane": lane,
		"outcome": outcome,
		"player_score": player_score,
		"snatcher_score": snatcher_score,
		"player_cards": _card_names(_player_hand),
		"snatcher_cards": _card_names(_snatcher_hand),
	})


func _move_toward_exit(lane: int, steps: int) -> void:
	var exit_cell := Board.find_tile(lane, EXIT)
	var path := Board.shortest_path(lane, _runners[lane], exit_cell)
	if steps > 0 and not path.is_empty():
		_set_runner(lane, path[mini(steps, path.size()) - 1])


func _retreat(lane: int) -> void:
	var spawn := Board.find_tile(lane, SPAWN)
	var path := Board.shortest_path(lane, _runners[lane], spawn)
	var steps := mini(maxi(_dice.x, _dice.y), path.size())
	if steps == 0:
		return
	_set_runner(lane, path[steps - 1])
	# Place the Snatcher up to two steps behind the runner, bounded by spawn.
	_snatchers[lane] = path[mini(steps + 2, path.size()) - 1]


func _score(hand: Array[int]) -> int:
	var total := 0
	var soft_aces := 0
	for card in hand:
		var rank := card % RANKS.size()
		if rank == 0:
			total += 11
			soft_aces += 1
		else:
			total += mini(rank + 1, 10)
	while total > 21 and soft_aces > 0:
		total -= 10
		soft_aces -= 1
	return total


func _card_names(hand: Array[int]) -> Array[String]:
	var names: Array[String] = []
	for card in hand:
		var rank := card % RANKS.size()
		var suit := floori(float(card) / RANKS.size())
		names.append(RANKS[rank] + SUITS[suit])
	return names
