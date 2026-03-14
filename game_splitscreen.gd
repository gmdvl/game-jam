extends Game


func _ready() -> void:
	var player_2 := %Player2 as Player
	var viewport_1 := %Viewport1 as SubViewport
	var viewport_2 := %Viewport2 as SubViewport
	viewport_2.world_2d = viewport_1.world_2d
	player_2.camera.custom_viewport = viewport_2
	player_2.camera.make_current()


func _on_player_1_letter_collected(letter: String) -> void:
	pass # Replace with function body.


func _on_player_2_letter_collected(letter: String) -> void:
	pass # Replace with function body.
