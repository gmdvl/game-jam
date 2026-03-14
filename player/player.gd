class_name Player
extends CharacterBody2D

@warning_ignore("unused_signal")
signal coin_collected()
signal health_changed(new_health: int)
signal died()

const WALK_SPEED = 300.0
const ACCELERATION_SPEED = WALK_SPEED * 6.0
const JUMP_VELOCITY = -725.0
const TERMINAL_VELOCITY = 700
const MAX_HEALTH = 5
var health: int = MAX_HEALTH
var _invincible: bool = false

@export var action_suffix: String = ""

var gravity: int = ProjectSettings.get(&"physics/2d/default_gravity")
@onready var platform_detector := $PlatformDetector as RayCast2D
@onready var animation_player := $AnimationPlayer as AnimationPlayer
@onready var shoot_timer := $ShootAnimation as Timer
@onready var sprite := $Sprite2D as Sprite2D
@onready var jump_sound := $Jump as AudioStreamPlayer2D
@onready var gun: Gun = sprite.get_node(^"Gun")
@onready var camera := $Camera as Camera2D
var _double_jump_charged: bool = false


func _physics_process(delta: float) -> void:
	if is_on_floor():
		_double_jump_charged = true
	if Input.is_action_just_pressed("jump" + action_suffix):
		try_jump()
	elif Input.is_action_just_released("jump" + action_suffix) and velocity.y < 0.0:
		velocity.y *= 0.6
	velocity.y = minf(TERMINAL_VELOCITY, velocity.y + gravity * delta)

	var direction := Input.get_axis("move_left" + action_suffix, "move_right" + action_suffix) * WALK_SPEED
	velocity.x = move_toward(velocity.x, direction, ACCELERATION_SPEED * delta)

	if not is_zero_approx(velocity.x):
		if velocity.x > 0.0:
			sprite.scale.x = 1.0
		else:
			sprite.scale.x = -1.0

	floor_stop_on_slope = not platform_detector.is_colliding()
	move_and_slide()

	var is_shooting: bool = false
	if Input.is_action_just_pressed("shoot" + action_suffix):
		is_shooting = gun.shoot(sprite.scale.x)

	var animation := get_new_animation(is_shooting)
	if animation != animation_player.current_animation and shoot_timer.is_stopped():
		if is_shooting:
			shoot_timer.start()
		animation_player.play(animation)


func get_new_animation(is_shooting: bool = false) -> String:
	var animation_new: String
	if is_on_floor():
		if absf(velocity.x) > 0.1:
			animation_new = "run"
		else:
			animation_new = "idle"
	else:
		if velocity.y > 0.0:
			animation_new = "falling"
		else:
			animation_new = "jumping"
	if is_shooting:
		animation_new += "_weapon"
	return animation_new


func try_jump() -> void:
	if is_on_floor():
		jump_sound.pitch_scale = 1.0
	elif _double_jump_charged:
		_double_jump_charged = false
		velocity.x *= 2.5
		jump_sound.pitch_scale = 1.5
	else:
		return
	velocity.y = JUMP_VELOCITY
	jump_sound.play()


func take_damage(amount: int = 1) -> void:
	if _invincible:
		return
	health -= amount
	emit_signal("health_changed", health)
	if health <= 0:
		emit_signal("died")
		die()
		return
	# Flash invincibility
	_invincible = true
	var tween := create_tween()
	for i in 6:
		tween.tween_property(sprite, ^"modulate:a", 0.2, 0.08)
		tween.tween_property(sprite, ^"modulate:a", 1.0, 0.08)
	tween.tween_callback(func() -> void: _invincible = false)


func die() -> void:
	set_physics_process(false)
	visible = false
	var pause_menu := get_tree().get_first_node_in_group("pause_menu") as PauseMenu
	if pause_menu:
		get_tree().paused = true
		pause_menu.open_death()
