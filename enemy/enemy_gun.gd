class_name EnemyGun
extends Marker2D

const BULLET_VELOCITY = 850.0
const BULLET_SCENE = preload("res://enemy/enemy_bullet.tscn")

@onready var sound_shoot := $Shoot as AudioStreamPlayer2D
@onready var timer := $Cooldown as Timer

func shoot(direction: float = 1.0) -> bool:
	if not timer.is_stopped():
		return false

	var bullet := BULLET_SCENE.instantiate() as EnemyBullet
	bullet.global_position = global_position
	bullet.linear_velocity = Vector2(direction * BULLET_VELOCITY, 0.0)

	var enemy := get_parent().get_parent()
	bullet.add_collision_exception_with(enemy)

	bullet.set_as_top_level(true)
	add_child(bullet)

	sound_shoot.play()
	timer.start()
	return true
