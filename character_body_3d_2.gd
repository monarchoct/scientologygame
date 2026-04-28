extends CharacterBody3D

var player = null

var SPEED = 3.0
const ATTACK_RANGE = 1.5

@export var player_path : NodePath

@onready var nav_agent = $NavigationAgent3D

func _ready() -> void:
	player = get_node(player_path)

func _physics_process(delta: float) -> void:
	velocity = Vector3.ZERO
	
	nav_agent.set_target_position(player.global_position)
	var next_nav_point = nav_agent.get_next_path_position()
	velocity = (next_nav_point - global_position).normalized() * SPEED
	
	move_and_slide()
	
func update_target_location(target_location):
	nav_agent.set_target_position(target_location)

func _process(delta):
	if player == null:
		return

	if _target_in_range():
		hit_finished()

func _target_in_range():
	return global_position.distance_to(player.global_position) < ATTACK_RANGE

func hit_finished():
	player.hit()
