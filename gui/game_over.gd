class_name GameOver
extends Control

func _ready() -> void:
	hide()

func show_game_over() -> void:
	show()
	get_tree().paused = true

func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://game_singleplayer.tscn")

func _on_quit_pressed() -> void:
	get_tree().paused = false
	get_tree().quit()
