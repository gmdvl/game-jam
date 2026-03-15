extends Node2D

const LIMIT_LEFT   = -315
const LIMIT_TOP    = -250
const LIMIT_RIGHT  = 955
const LIMIT_BOTTOM = 690


func _ready() -> void:
	GameState.current_level_scene = "res://level/level.tscn"

	for player in get_tree().get_nodes_in_group("players"):
		var camera: Camera2D = player.get_node_or_null(^"Camera")
		if camera:
			camera.limit_left   = LIMIT_LEFT
			camera.limit_top    = LIMIT_TOP
			camera.limit_right  = LIMIT_RIGHT
			camera.limit_bottom = LIMIT_BOTTOM

	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.enemy_died.connect(_on_enemy_died)


func _on_enemy_died() -> void:
	await get_tree().process_frame
	var remaining: int = get_tree().get_nodes_in_group("enemies").size()
	print("Enemies remaining: ", remaining)
	if remaining == 0:
		_go_to_next_level()


func _go_to_next_level() -> void:
	GameState.go_to_next_generated_level()
