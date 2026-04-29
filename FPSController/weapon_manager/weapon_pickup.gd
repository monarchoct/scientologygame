class_name WeaponPickup
extends StaticBody3D

@export var weapon: WeaponResource
@export var equip_immediately: bool = true
@export var hide_after_pickup: bool = true
@export var show_weapon_model: bool = true

@onready var interactable_component: InteractableComponent = get_node_or_null("InteractableComponent") as InteractableComponent

func _ready() -> void:
	collision_layer = 1 << 7
	collision_mask = 0
	_ensure_collision_shape()
	_create_weapon_model()

	if interactable_component == null:
		interactable_component = InteractableComponent.new()
		interactable_component.name = "InteractableComponent"
		add_child(interactable_component)

	if not interactable_component.interacted_by_character.is_connected(_on_interacted_by_character):
		interactable_component.interacted_by_character.connect(_on_interacted_by_character)

func _ensure_collision_shape() -> void:
	if find_child("*", "CollisionShape3D", true, false) != null:
		return

	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = 0.65
	collision_shape.shape = sphere_shape
	add_child(collision_shape)

func _create_weapon_model() -> void:
	if not show_weapon_model or weapon == null or weapon.world_model == null:
		return
	if get_node_or_null("WeaponModel") != null:
		return

	var weapon_model := weapon.world_model.instantiate() as Node3D
	if weapon_model == null:
		return
	weapon_model.name = "WeaponModel"
	add_child(weapon_model)
	weapon_model.position = weapon.world_model_pos
	weapon_model.rotation = weapon.world_model_rot
	weapon_model.scale = weapon.world_model_scale

func _on_interacted_by_character(character: CharacterBody3D) -> void:
	var weapon_manager: WeaponManager = _find_weapon_manager(character)
	if weapon_manager == null:
		return

	if weapon_manager.add_weapon(weapon, equip_immediately) and hide_after_pickup:
		queue_free()

func _find_weapon_manager(character: Node) -> WeaponManager:
	if character == null:
		return null

	var direct_child = character.get_node_or_null("WeaponManager")
	if direct_child is WeaponManager:
		return direct_child

	var found = character.find_child("WeaponManager", true, false)
	if found is WeaponManager:
		return found

	return null
