## game_state.gd — Autoload singleton
extends Node

enum Mode { SINGLE, SPLIT }

var mode: Mode         = Mode.SINGLE
var current_level_scene: String = "res://level/level.tscn"
var current_seed: int  = -1   # -1 = generate fresh; >=0 = reuse this seed

const SINGLE_WRAPPER     = "res://game_generated.tscn"
const SPLIT_WRAPPER      = "res://game_generated_split.tscn"
const FIRST_LEVEL_SINGLE = "res://game_singleplayer.tscn"
const FIRST_LEVEL_SPLIT  = "res://game_splitscreen.tscn"


## Called when all enemies die — advances to a FRESH generated level.
func go_to_next_generated_level() -> void:
	current_level_scene = "res://level/generated_level.tscn"
	current_seed = -1   # clear so next level gets a new seed
	var wrapper := SPLIT_WRAPPER if mode == Mode.SPLIT else SINGLE_WRAPPER
	get_tree().call_deferred("change_scene_to_file", wrapper)


## Called by the "New Map" button — generates a fresh level, keeping current mode.
func regenerate_level() -> void:
	current_seed = -1
	current_level_scene = "res://level/generated_level.tscn"
	get_tree().paused = false
	var wrapper := SPLIT_WRAPPER if mode == Mode.SPLIT else SINGLE_WRAPPER
	get_tree().call_deferred("change_scene_to_file", wrapper)


## Called by pause menu mode buttons — reloads SAME level in new mode.
func switch_mode(new_mode: Mode) -> void:
	mode = new_mode
	get_tree().paused = false
	var wrapper: String
	if current_level_scene == "res://level/level.tscn":
		# First hand-crafted level — use its dedicated wrapper
		wrapper = FIRST_LEVEL_SPLIT if mode == Mode.SPLIT else FIRST_LEVEL_SINGLE
	else:
		# Generated level — keep current_seed so the same level reloads
		wrapper = SPLIT_WRAPPER if mode == Mode.SPLIT else SINGLE_WRAPPER
	get_tree().call_deferred("change_scene_to_file", wrapper)
