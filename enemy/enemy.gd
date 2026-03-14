class_name Enemy
extends CharacterBody2D

enum State {
	IDLE,
	WALKING,
	DEAD,
}

const WALK_SPEED = 22.0
const SHOOT_RANGE = 260.0

var _state := State.WALKING
var _direction := 1

@onready var gravity: int = ProjectSettings.get(&"physics/2d/default_gravity")
@onready var platform_detector := $PlatformDetector as RayCast2D
@onready var floor_detector_left := $FloorDetectorLeft as RayCast2D
@onready var floor_detector_right := $FloorDetectorRight as RayCast2D
@onready var sprite := $Sprite2D as Sprite2D
@onready var animation_player := $AnimationPlayer as AnimationPlayer
@onready var decision_timer := $DecisionTimer as Timer
@onready var explosion := $Explosion
@onready var hit_sound := $Hit as AudioStreamPlayer2D
@onready var explode_sound := $Explode as AudioStreamPlayer2D
@onready var gun = get_node_or_null("Sprite2D/Gun")

func _ready() -> void:
	randomize()
	_choose_next_action()

func _physics_process(delta: float) -> void:
	if _state == State.DEAD:
		velocity.y += gravity * delta
		move_and_slide()
		_update_sprite_direction()
		_update_animation()
		return

	velocity.y += gravity * delta

	var target_player := _get_closest_player()
	var player_in_range := false

	if target_player:
		var distance_to_player := global_position.distance_to(target_player.global_position)
		player_in_range = distance_to_player <= SHOOT_RANGE

	if player_in_range and target_player:
		var dx := target_player.global_position.x - global_position.x

		if dx > 0.0:
			_direction = 1
		elif dx < 0.0:
			_direction = -1

		velocity.x = 0.0

		if gun:
			gun.shoot(_direction)
	else:
		if _state == State.WALKING:
			velocity.x = _direction * WALK_SPEED

			if _direction < 0 and not floor_detector_left.is_colliding():
				_direction = 1
			elif _direction > 0 and not floor_detector_right.is_colliding():
				_direction = -1

			if is_on_wall():
				_direction *= -1

		elif _state == State.IDLE:
			velocity.x = 0.0

	floor_stop_on_slope = not platform_detector.is_colliding()
	move_and_slide()

	_update_sprite_direction()
	_update_animation()

func _get_closest_player() -> Player:
	var players := get_tree().get_nodes_in_group("player")
	var closest_player: Player = null
	var closest_distance := INF

	for node in players:
		if node is Player:
			var player := node as Player
			var distance := global_position.distance_to(player.global_position)

			if distance < closest_distance:
				closest_distance = distance
				closest_player = player

	return closest_player

func _choose_next_action() -> void:
	if _state == State.DEAD:
		return

	var roll := randf()

	if roll < 0.55:
		_state = State.WALKING
	elif roll < 0.8:
		_state = State.IDLE
	else:
		_state = State.WALKING
		_direction *= -1

	decision_timer.wait_time = randf_range(0.8, 2.2)
	decision_timer.start()

func _on_decision_timer_timeout() -> void:
	_choose_next_action()

func _update_sprite_direction() -> void:
	if _direction > 0:
		sprite.scale.x = 0.8
	elif _direction < 0:
		sprite.scale.x = -0.8

func _update_animation() -> void:
	var animation := get_new_animation()
	if animation != animation_player.current_animation:
		animation_player.play(animation)

func destroy() -> void:
	if _state == State.DEAD:
		return

	_state = State.DEAD
	velocity = Vector2.ZERO
	decision_timer.stop()

	if hit_sound:
		hit_sound.play()
	if explode_sound:
		explode_sound.play()
	if explosion and explosion.has_method("restart"):
		explosion.restart()

	_update_animation()

func get_new_animation() -> StringName:
	if _state == State.DEAD:
		return &"destroy"
	elif absf(velocity.x) > 0.1:
		return &"walk"
	else:
		return &"idle"
