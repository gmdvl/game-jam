class_name Haunter
extends CharacterBody2D

enum State { PATROL, HUNT, PAUSED, DEAD }

const PATROL_SPEED: float  = 60.0
const CHASE_SPEED: float   = 180.0
const SIGHT_RANGE: float   = 280.0
const SIGHT_FOV_DEG: float = 70.0

var _state: State = State.PATROL
var _player: Player = null
var _pause_timer: float = 0.0

@onready var gravity: int = ProjectSettings.get(&"physics/2d/default_gravity") as int
@onready var floor_left: RayCast2D   = $FloorDetectorLeft
@onready var floor_right: RayCast2D  = $FloorDetectorRight
@onready var anim: AnimatedSprite2D  = $AnimatedSprite2D


func _ready() -> void:
	_player = _find_player(get_tree().root)
	velocity.x = PATROL_SPEED


func _physics_process(delta: float) -> void:
	match _state:
		State.PATROL: _tick_patrol(delta)
		State.HUNT:   _tick_hunt()
		State.DEAD:   pass


func _tick_patrol(delta: float) -> void:
	velocity.y += gravity * delta
	if not floor_left.is_colliding():
		velocity.x = PATROL_SPEED
	elif not floor_right.is_colliding():
		velocity.x = -PATROL_SPEED
	if is_on_wall():
		velocity.x = -velocity.x
	move_and_slide()
	_face_velocity()
	_play(&"walk")
	if _player and _can_see_player():
		_state = State.HUNT


func _tick_hunt() -> void:
	if _state == State.PAUSED:
		velocity = Vector2.ZERO
		_play(&"idle")
		_pause_timer -= get_physics_process_delta_time()
		if _pause_timer <= 0.0:
			_state = State.HUNT
		return
	
	var dir: Vector2 = (_player.global_position - global_position).normalized()
	velocity = dir * CHASE_SPEED
	move_and_slide()
	for i: int in get_slide_collision_count():
		var col: KinematicCollision2D = get_slide_collision(i)
		if col.get_collider() is Player:
			_state = State.PAUSED
			_pause_timer = 3.0
			return
	_face_velocity()
	_play(&"run")


func destroy() -> void:
	if _state == State.DEAD:
		return
	_state = State.DEAD
	velocity = Vector2.ZERO
	anim.play(&"die")


func _can_see_player() -> bool:
	var diff: Vector2 = _player.global_position - global_position
	if diff.length() > SIGHT_RANGE:
		return false
	var facing: Vector2 = Vector2(sign(velocity.x) if velocity.x != 0.0 else 1.0, 0.0)
	var angle: float = rad_to_deg(facing.angle_to(diff.normalized()))
	return abs(angle) <= SIGHT_FOV_DEG


func _face_velocity() -> void:
	if velocity.x > 0.1:
		anim.flip_h = false
	elif velocity.x < -0.1:
		anim.flip_h = true


func _play(anim_name: StringName) -> void:
	if anim.animation != anim_name:
		anim.play(anim_name)



func _on_animation_finished() -> void:
	if anim.animation == &"die":
		queue_free()


func _find_player(node: Node) -> Player:
	if node is Player:
		return node as Player
	for child in node.get_children():
		var r: Player = _find_player(child)
		if r:
			return r
	return null
