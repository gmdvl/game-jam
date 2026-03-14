class_name EnemyBullet
extends RigidBody2D

@onready var animation_player := $AnimationPlayer as AnimationPlayer

func destroy() -> void:
	queue_free()

func _on_body_entered(body: Node) -> void:
	print("Enemy bullet collided with: ", body.name)

	if body is Player:
		print("Player hit!")
		(body as Player).take_damage(1)
		queue_free()
	
func _ready():
	$Sprite2D.modulate = Color(1, 0, 0)
