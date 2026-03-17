class_name Coin
extends Area2D

@export var letter: String = "G"
#@export var letter_texture: Texture2D

@onready var pickup_sound := $Pickup as AudioStreamPlayer2D
#@onready var sprite := $Sprite2D as Sprite2D

var _collected := false

func _on_body_entered(body: Node2D) -> void:
	if _collected:
		return

	if body is Player:
		_collected = true
		set_deferred("monitoring", false)
		set_deferred("monitorable", false)

		if pickup_sound:
			pickup_sound.play()

		(body as Player).collect_letter(letter)

		hide()
		await get_tree().create_timer(0.1).timeout
		queue_free()
