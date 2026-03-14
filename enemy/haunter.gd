class_name Haunter
extends CharacterBody2D

enum State { PATROL, HUNT, DEAD }

const PATROL_SPEED: float  = 60.0
const CHASE_SPEED: float   = 180.0
const SIGHT_RANGE: float   = 280.0
const SIGHT_FOV_DEG: float = 70.0

var _state: State = State.PATROL
var _player: Player = null
var _camera: Camera2D = null
var _saved_limits: Dictionary = {}

@onready var gravity: int = ProjectSettings.get(&"physics/2d/default_gravity") as int
@onready var floor_left: RayCast2D   = $FloorDetectorLeft
@onready var floor_right: RayCast2D  = $FloorDetectorRight
@onready var anim: AnimatedSprite2D  = $AnimatedSprite2D


func _ready() -> void:
	_player = _find_player(get_tree().root)
	if _player:
		_camera = _player.get_node_or_null(^"Camera") as Camera2D
		if _camera:
			_saved_limits = {
				"left":   _camera.limit_left,
				"top":    _camera.limit_top,
				"right":  _camera.limit_right,
				"bottom": _camera.limit_bottom,
			}
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
		_lock_camera()


func _tick_hunt() -> void:
	var dir: Vector2 = (_player.global_position - global_position).normalized()
	velocity = dir * CHASE_SPEED
	move_and_slide()
	for i: int in get_slide_collision_count():
		var col: KinematicCollision2D = get_slide_collision(i)
		if col.get_collider() is Player:
			(col.get_collider() as Player).take_damage()
	_face_velocity()
	_play(&"run")
	_lock_camera()


func destroy() -> void:
	if _state == State.DEAD:
		return
	_state = State.DEAD
	velocity = Vector2.ZERO
	_restore_camera()
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


func _lock_camera() -> void:
	if _camera == null or _player == null:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var px: int = int(_player.global_position.x)
	var py: int = int(_player.global_position.y)
	_camera.limit_left   = px - int(vp.x * 0.5)
	_camera.limit_top    = py - int(vp.y * 0.5)
	_camera.limit_right  = px + int(vp.x * 0.5)
	_camera.limit_bottom = py + int(vp.y * 0.5)


func _restore_camera() -> void:
	if _camera == null or _saved_limits.is_empty():
		return
	_camera.limit_left   = _saved_limits["left"]
	_camera.limit_top    = _saved_limits["top"]
	_camera.limit_right  = _saved_limits["right"]
	_camera.limit_bottom = _saved_limits["bottom"]


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
