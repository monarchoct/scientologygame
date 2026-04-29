class_name WeaponManager
extends Node3D

const BASE_ALBEDO_TEXTURE_META := &"base_albedo_texture"

@export var allow_shoot : bool = true

@export var current_weapon : WeaponResource :
	set(v):
		if v != current_weapon:
			if current_weapon:
				current_weapon.is_equipped = false
			current_weapon = v;
			if is_inside_tree():
				update_weapon_model()
@export var equipped_weapons : Array[WeaponResource]

@export var player : CharacterBody3D
@export var bullet_raycast : RayCast3D

@export var animation_tree : AnimationTree

@export var view_model_container : Node3D
@export var world_model_container : Node3D

var current_weapon_view_model : Node3D
var current_weapon_world_model : Node3D

var current_weapon_view_model_muzzle : Node3D
var current_weapon_world_model_muzzle : Node3D
var base_equipped_weapon_resources: Array[WeaponResource] = []

@onready var audio_stream_player = $AudioStreamPlayer3D

func _remember_base_loadout() -> void:
	if not base_equipped_weapon_resources.is_empty():
		return
	for weapon in equipped_weapons:
		if weapon != null:
			base_equipped_weapon_resources.append(weapon)
	if current_weapon != null and not base_equipped_weapon_resources.has(current_weapon):
		base_equipped_weapon_resources.push_front(current_weapon)

func _make_runtime_weapon(weapon: WeaponResource) -> WeaponResource:
	if weapon == null:
		return null
	var runtime_weapon := weapon.duplicate(true) as WeaponResource
	if runtime_weapon == null:
		return null
	runtime_weapon.reset_ammo()
	runtime_weapon.weapon_manager = self
	return runtime_weapon

func _make_runtime_loadout() -> void:
	var starting_weapon := current_weapon
	var runtime_weapons: Array[WeaponResource] = []
	for weapon in equipped_weapons:
		var runtime_weapon := _make_runtime_weapon(weapon)
		if runtime_weapon != null:
			runtime_weapons.append(runtime_weapon)
	equipped_weapons = runtime_weapons

	current_weapon = null
	for weapon in equipped_weapons:
		if starting_weapon != null and (weapon.resource_path == starting_weapon.resource_path or weapon.name == starting_weapon.name):
			current_weapon = weapon
			return
	if equipped_weapons.size() > 0:
		current_weapon = equipped_weapons[0]

func apply_named_loadout(weapon_names: PackedStringArray) -> void:
	_remember_base_loadout()
	var selected_weapons: Array[WeaponResource] = []
	for weapon in base_equipped_weapon_resources:
		if weapon == null:
			continue
		if weapon_names.is_empty() or weapon_names.has(weapon.name):
			selected_weapons.append(weapon)

	if selected_weapons.is_empty():
		return

	var runtime_weapons: Array[WeaponResource] = []
	for weapon in selected_weapons:
		var runtime_weapon := _make_runtime_weapon(weapon)
		if runtime_weapon != null:
			runtime_weapons.append(runtime_weapon)

	if runtime_weapons.is_empty():
		return

	equipped_weapons = runtime_weapons
	current_weapon = equipped_weapons[0]

func has_weapon(weapon: WeaponResource) -> bool:
	if weapon == null:
		return false
	for equipped_weapon in equipped_weapons:
		if equipped_weapon == weapon or equipped_weapon.resource_path == weapon.resource_path or equipped_weapon.name == weapon.name:
			return true
	return false

func add_weapon(weapon: WeaponResource, equip_immediately: bool = true) -> bool:
	if weapon == null or has_weapon(weapon):
		return false

	var runtime_weapon := _make_runtime_weapon(weapon)
	if runtime_weapon == null:
		return false

	equipped_weapons.append(runtime_weapon)
	if equip_immediately:
		current_weapon = runtime_weapon
	return true

func update_weapon_model() -> void:
	if current_weapon_view_model != null and is_instance_valid(current_weapon_view_model):
		current_weapon_view_model.queue_free()
		current_weapon_view_model.get_parent().remove_child(current_weapon_view_model)
	if current_weapon_world_model != null and is_instance_valid(current_weapon_world_model):
		current_weapon_world_model.queue_free()
		current_weapon_world_model.get_parent().remove_child(current_weapon_world_model)
	if current_weapon != null:
		current_weapon.weapon_manager = self
		if view_model_container and current_weapon.view_model:
			current_weapon_view_model = current_weapon.view_model.instantiate()
			view_model_container.add_child(current_weapon_view_model)
			current_weapon_view_model.position = current_weapon.view_model_pos
			current_weapon_view_model.rotation = current_weapon.view_model_rot
			current_weapon_view_model.scale = current_weapon.view_model_scale
			apply_clip_and_fov_shader_to_view_model(current_weapon_view_model)
			if current_weapon_view_model.get_node_or_null("AnimationPlayer"):
				current_weapon_view_model.get_node_or_null("AnimationPlayer").connect("current_animation_changed", current_anim_changed)
		if world_model_container and current_weapon.world_model:
			current_weapon_world_model = current_weapon.world_model.instantiate()
			world_model_container.add_child(current_weapon_world_model)
			current_weapon_world_model.position = current_weapon.world_model_pos
			current_weapon_world_model.rotation = current_weapon.world_model_rot
			current_weapon_world_model.scale = current_weapon.world_model_scale
		apply_equipped_knife_skin()
		current_weapon.is_equipped = true
		if player.has_method("update_view_and_world_model_masks"):
			player.update_view_and_world_model_masks()
	current_weapon_view_model_muzzle = view_model_container.find_child("Muzzle", true, false) if current_weapon_view_model else null
	current_weapon_world_model_muzzle = world_model_container.find_child("Muzzle", true, false) if current_weapon_world_model else null

func apply_equipped_knife_skin() -> void:
	if current_weapon == null or current_weapon.name.to_lower() != "knife":
		return

	var player_profile := get_node_or_null("/root/PlayerProfile")
	if player_profile == null or not player_profile.has_method("get_equipped_knife_skin_color"):
		return

	var skin_color: Color = player_profile.call("get_equipped_knife_skin_color") as Color
	var skin_texture: Texture2D = null
	if player_profile.has_method("get_equipped_knife_skin_texture_path"):
		var texture_path: String = str(player_profile.call("get_equipped_knife_skin_texture_path"))
		if texture_path != "":
			skin_texture = load(texture_path) as Texture2D
	_apply_knife_skin_to_weapon_model(current_weapon_view_model, skin_color, skin_texture)
	_apply_knife_skin_to_weapon_model(current_weapon_world_model, skin_color, skin_texture)

func _apply_knife_skin_to_weapon_model(model: Node3D, skin_color: Color, skin_texture: Texture2D) -> void:
	if model == null:
		return

	var mesh_instances := model.find_children("*", "MeshInstance3D", true, false)
	if model is MeshInstance3D:
		mesh_instances.push_back(model)

	for mesh_instance in mesh_instances:
		var mesh_node := mesh_instance as MeshInstance3D
		if mesh_node.mesh == null:
			continue
		mesh_node.mesh = mesh_node.mesh.duplicate()
		for surface_idx in range(mesh_node.mesh.get_surface_count()):
			var material := mesh_node.mesh.surface_get_material(surface_idx)
			if material == null:
				continue
			if not _should_apply_knife_skin_to_surface(mesh_node):
				continue
			var local_material := material.duplicate()
			if local_material is ShaderMaterial:
				var shader_material := local_material as ShaderMaterial
				if not shader_material.has_meta(BASE_ALBEDO_TEXTURE_META):
					shader_material.set_meta(BASE_ALBEDO_TEXTURE_META, shader_material.get_shader_parameter("texture_albedo"))
				shader_material.set_shader_parameter("albedo", skin_color)
				shader_material.set_shader_parameter("texture_albedo", skin_texture)
				shader_material.set_shader_parameter("use_albedo_texture", skin_texture != null)
				_make_knife_shader_material_clean(shader_material)
			elif local_material is BaseMaterial3D:
				var base_material := local_material as BaseMaterial3D
				if not base_material.has_meta(BASE_ALBEDO_TEXTURE_META):
					base_material.set_meta(BASE_ALBEDO_TEXTURE_META, base_material.albedo_texture)
				base_material.albedo_color = skin_color
				base_material.albedo_texture = skin_texture
				_make_knife_base_material_clean(base_material)
			mesh_node.mesh.surface_set_material(surface_idx, local_material)

func _should_apply_knife_skin_to_surface(mesh_node: MeshInstance3D) -> bool:
	var mesh_name := String(mesh_node.name).to_lower()
	for blocked_name in ["arm", "hand", "body", "player", "droid", "robot", "base_mesh", "sleeve"]:
		if mesh_name.contains(blocked_name):
			return false
	for knife_name in ["knife", "blade"]:
		if mesh_name.contains(knife_name):
			return true
	return false

## Call this function on any node to apply the weapon_clip_and_fov_shader.gdshader to all meshes within it.
func apply_clip_and_fov_shader_to_view_model(node3d : Node3D, fov_or_negative_for_unchanged = -1.0):
	var all_mesh_instances = node3d.find_children("*", "MeshInstance3D")
	if node3d is MeshInstance3D:
		all_mesh_instances.push_back(node3d)
	for mesh_instance in all_mesh_instances:
		var mesh = mesh_instance.mesh
		# Important to turn shadow casting off for view model or will cause issues with both
		# view model, casting shadows on itself once unclipped, & also will look weird casting on world.
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for surface_idx in mesh.get_surface_count():
			var base_mat = mesh.surface_get_material(surface_idx)
			if not base_mat is BaseMaterial3D: continue
			var weapon_shader_material := ShaderMaterial.new()
			weapon_shader_material.shader = preload("res://FPSController/weapon_manager/weapon_clip_and_fov_shader.gdshader")
			weapon_shader_material.set_shader_parameter("texture_albedo", base_mat.albedo_texture)
			weapon_shader_material.set_shader_parameter("texture_metallic", base_mat.metallic_texture)
			weapon_shader_material.set_shader_parameter("texture_roughness", base_mat.roughness_texture)
			weapon_shader_material.set_shader_parameter("texture_normal", base_mat.normal_texture)
			weapon_shader_material.set_shader_parameter("albedo", base_mat.albedo_color)
			weapon_shader_material.set_shader_parameter("metallic", base_mat.metallic)
			weapon_shader_material.set_shader_parameter("specular", base_mat.metallic_specular)
			weapon_shader_material.set_shader_parameter("roughness", base_mat.roughness)
			weapon_shader_material.set_shader_parameter("viewmodel_fov", fov_or_negative_for_unchanged)
			var tex_channels = { 0: Vector4(1., 0., 0., 0.), 1: Vector4(0., 1., 0., 0.), 2: Vector4(0., 0., 1., 0.), 3: Vector4(1., 0., 0., 1.), 4: Vector4() }
			weapon_shader_material.set_shader_parameter("metallic_texture_channel", tex_channels[base_mat.metallic_texture_channel])
			if _is_current_weapon_knife() and _should_apply_knife_skin_to_surface(mesh_instance):
				_make_knife_shader_material_clean(weapon_shader_material)
			mesh.surface_set_material(surface_idx, weapon_shader_material)

func _is_current_weapon_knife() -> bool:
	return current_weapon != null and current_weapon.name.to_lower() == "knife"

func _make_knife_shader_material_clean(material: ShaderMaterial) -> void:
	material.set_shader_parameter("use_material_maps", false)
	material.set_shader_parameter("texture_metallic", null)
	material.set_shader_parameter("texture_roughness", null)
	material.set_shader_parameter("texture_normal", null)
	material.set_shader_parameter("metallic", 0.0)
	material.set_shader_parameter("specular", 0.25)
	material.set_shader_parameter("roughness", 0.72)
	material.set_shader_parameter("normal_scale", 0.0)

func _make_knife_base_material_clean(material: BaseMaterial3D) -> void:
	material.metallic = 0.0
	material.metallic_texture = null
	material.roughness = 0.72
	material.roughness_texture = null
	material.normal_enabled = false
	material.normal_texture = null
	material.metallic_specular = 0.25

func play_sound(sound : AudioStream, volume_db: float = 0.0):
	if sound:
		if audio_stream_player.stream != sound:
			audio_stream_player.stream = sound
		audio_stream_player.volume_db = volume_db
		audio_stream_player.play()

func stop_sounds():
	audio_stream_player.stop()

func update_weapon_hold_anims():
	animation_tree.set("parameters/WeaponHoldBlend2/blend_amount", 1.0 if current_weapon else 0.0)
	var state_machine_playback : AnimationNodeStateMachinePlayback = animation_tree.get("parameters/WeaponHoldStateMachine/playback")
	if current_weapon.hold_style == WeaponResource.CharacterHoldStyle.BAZOOKA:
		state_machine_playback.travel("Bazooka")
	elif current_weapon.hold_style == WeaponResource.CharacterHoldStyle.SMG:
		state_machine_playback.travel("SMG")
	elif current_weapon.hold_style == WeaponResource.CharacterHoldStyle.KNIFE:
		state_machine_playback.travel("Knife")
	elif current_weapon.hold_style == WeaponResource.CharacterHoldStyle.PISTOL:
		state_machine_playback.travel("Pistol")
	elif current_weapon.hold_style == WeaponResource.CharacterHoldStyle.GRENADE:
		state_machine_playback.travel("Grenade")

func trigger_weapon_shoot_world_anim():
	if not animation_tree: return
	var state_machine_playback : AnimationNodeStateMachinePlayback = animation_tree.get("parameters/WeaponHoldStateMachine/playback")
	var weapon = state_machine_playback.get_current_node()
	var stand_state = "Crouched" if player.is_crouched else "Standing"
	var cur_playback : AnimationNodeStateMachinePlayback = animation_tree.get("parameters/WeaponHoldStateMachine/"+weapon+"/"+stand_state+"/playback")
	if cur_playback:
		cur_playback.start("Shoot")

var last_played_anim : String = ""
var current_anim_finished_callback
var current_anim_cancelled_callback
func play_anim(name : String, finished_callback = null, cancelled_callback = null):
	var anim_player : AnimationPlayer = current_weapon_view_model.get_node_or_null("AnimationPlayer")
	
	if last_played_anim and get_anim() == last_played_anim and current_anim_cancelled_callback is Callable:
		current_anim_cancelled_callback.call() # Last anim didn't finish yet
	
	if not anim_player or not anim_player.has_animation(name):
		if finished_callback is Callable:
			finished_callback.call() # Treat empty animations as finishing immediately
		return
	
	current_anim_finished_callback = finished_callback
	current_anim_cancelled_callback = cancelled_callback
	last_played_anim = name
	anim_player.clear_queue()
	anim_player.seek(0.0)
	anim_player.play(name)

func queue_anim(name : String):
	var anim_player : AnimationPlayer = current_weapon_view_model.get_node_or_null("AnimationPlayer")
	if not anim_player: return
	anim_player.queue(name)

func current_anim_changed(new_anim : StringName):
	var anim_player : AnimationPlayer = current_weapon_view_model.get_node_or_null("AnimationPlayer")
	if new_anim != last_played_anim and current_anim_finished_callback is Callable:
		current_anim_finished_callback.call()
	last_played_anim = anim_player.current_animation
	if last_played_anim != anim_player.current_animation:
		current_anim_finished_callback = null
		current_anim_cancelled_callback = null

func get_anim() -> String:
	var anim_player : AnimationPlayer = current_weapon_view_model.get_node_or_null("AnimationPlayer")
	if not anim_player: return ""
	return anim_player.current_animation

func show_muzzle_flash():
	if current_weapon_view_model_muzzle:
		$ViewMuzzleFlash.emitting = true
	if current_weapon_world_model_muzzle:
		$WorldMuzzleFlash.emitting = true

func make_bullet_trail(target_pos : Vector3):
	if current_weapon_view_model_muzzle == null:
		return
	var muzzle = current_weapon_view_model_muzzle
	var bullet_dir = (target_pos - muzzle.global_position).normalized()
	var start_pos = muzzle.global_position + bullet_dir*0.25
	if (target_pos - start_pos).length() > 3.0:
		var bullet_tracer = preload("res://FPSController/weapon_manager/bullet_tracer.tscn").instantiate()
		player.add_sibling(bullet_tracer)
		bullet_tracer.global_position = start_pos
		bullet_tracer.target_pos = target_pos
		bullet_tracer.look_at(target_pos)

var heat : float = 0.0
func apply_recoil():
	var spray_recoil := Vector2.ZERO
	if current_weapon.spray_pattern:
		spray_recoil = current_weapon.spray_pattern.get_point_position(int(heat) % current_weapon.spray_pattern.point_count) * 0.0002
	var random_recoil := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 0.01
	var recoil = spray_recoil + random_recoil
	player.add_recoil(-recoil.y, -recoil.x)
	heat += 1.0

func get_current_recoil():
	return player.get_current_recoil() if player.has_method("get_current_recoil") else Vector2()

func _unhandled_input(event):
	if current_weapon and is_inside_tree() and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if event.is_action_pressed("shoot") and allow_shoot:
			current_weapon.trigger_down = true
		elif event.is_action_released("shoot"):
			current_weapon.trigger_down = false
		
		if event.is_action_pressed("reload"):
			current_weapon.reload_pressed()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_remember_base_loadout()
	_make_runtime_loadout()
	update_weapon_model()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	update_weapon_hold_anims()
	if current_weapon:
		current_weapon.on_process(delta)
	if current_weapon_view_model_muzzle:
		$ViewMuzzleFlash.global_position = current_weapon_view_model_muzzle.global_position
	if current_weapon_world_model_muzzle:
		$WorldMuzzleFlash.global_position = current_weapon_world_model_muzzle.global_position
	heat = max(0.0, heat - delta * 10.0)
