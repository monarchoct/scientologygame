extends Node

enum Difficulty { EASY, MEDIUM, HARDCORE }

var current_difficulty: Difficulty = Difficulty.MEDIUM

# Lives per difficulty (HARDCORE = 0 means insta-kill / no respawn)
const LIVES: Dictionary = {
	Difficulty.EASY:     3,
	Difficulty.MEDIUM:   1,
	Difficulty.HARDCORE: 0,
}

# Guard speed multipliers relative to the original BASE_SPEED = 15.0
const SPEED_MULTIPLIER: Dictionary = {
	Difficulty.EASY:     0.55,   # ~8.25 — relatively slow
	Difficulty.MEDIUM:   0.75,   # ~11.25 — a bit faster
	Difficulty.HARDCORE: 1.0,    # 15.0 — original speed
}

func get_lives() -> int:
	return LIVES[current_difficulty]

func get_speed_multiplier() -> float:
	return SPEED_MULTIPLIER[current_difficulty]

func set_difficulty(d: Difficulty) -> void:
	current_difficulty = d
