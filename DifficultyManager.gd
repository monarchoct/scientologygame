extends Node

enum Difficulty { EASY, MEDIUM, HARDCORE, NIGHTMARE }

var current_difficulty: Difficulty = Difficulty.MEDIUM

const GLOBAL_ENEMY_SPEED_MULTIPLIER: float = 1.08

# Lives per difficulty. Zero means one hit ends the run.
const LIVES: Dictionary = {
	Difficulty.EASY: 3,
	Difficulty.MEDIUM: 2,
	Difficulty.HARDCORE: 0,
	Difficulty.NIGHTMARE: 0,
}

# Guard speed multipliers relative to the original BASE_SPEED = 15.0.
const SPEED_MULTIPLIER: Dictionary = {
	Difficulty.EASY: 0.55,
	Difficulty.MEDIUM: 0.75,
	Difficulty.HARDCORE: 1.2,
	Difficulty.NIGHTMARE: 1.2,
}

func get_lives() -> int:
	return LIVES[current_difficulty]

func get_speed_multiplier() -> float:
	return SPEED_MULTIPLIER[current_difficulty] * GLOBAL_ENEMY_SPEED_MULTIPLIER

func set_difficulty(d: Difficulty) -> void:
	current_difficulty = d
