class_name PauseMenu
extends Control

enum MenuMode {
	PAUSE,
	DEATH,
}

@export var fade_in_duration := 0.3
@export var fade_out_duration := 0.2

var _mode: MenuMode = MenuMode.PAUSE

@onready var center_cont := $ColorRect/CenterContainer as CenterContainer
@onready var title_label := center_cont.get_node(^"VBoxContainer/Label") as Label
@onready var resume_button := center_cont.get_node(^"VBoxContainer/ResumeButton") as Button
@onready var splitscreen_button := center_cont.get_node_or_null(^"VBoxContainer/SplitscreenButton") as Button
@onready var coins_counter := $ColorRect/CoinsCounter as CoinsCounter

func _ready() -> void:
	hide()

func close() -> void:
	var tween := create_tween()
	get_tree().paused = false
	tween.tween_property(
			self,
			^"modulate:a",
			0.0,
			fade_out_duration
		).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(
			center_cont,
			^"anchor_bottom",
			0.5,
			fade_out_duration
		).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(hide)

func open() -> void:
	_mode = MenuMode.PAUSE
	title_label.text = "GAME PAUSED"
	resume_button.text = "RESUME"
	if splitscreen_button:
		splitscreen_button.show()

	show()
	resume_button.grab_focus()

	modulate.a = 0.0
	center_cont.anchor_bottom = 0.5
	var tween := create_tween()
	tween.tween_property(
			self,
			^"modulate:a",
			1.0,
			fade_in_duration
		).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(
			center_cont,
			^"anchor_bottom",
			1.0,
			fade_out_duration
		).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func open_death() -> void:
	_mode = MenuMode.DEATH
	title_label.text = "HARD LUCK!"
	resume_button.text = "RESTART"
	if splitscreen_button:
		splitscreen_button.hide()

	show()
	resume_button.grab_focus()

	modulate.a = 0.0
	center_cont.anchor_bottom = 0.5
	var tween := create_tween()
	tween.tween_property(
			self,
			^"modulate:a",
			1.0,
			fade_in_duration
		).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(
			center_cont,
			^"anchor_bottom",
			1.0,
			fade_out_duration
		).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _on_coin_collected() -> void:
	coins_counter.collect_coin()

func _on_resume_button_pressed() -> void:
	if _mode == MenuMode.DEATH:
		get_tree().paused = false
		get_tree().reload_current_scene()
	else:
		close()

func _on_singleplayer_button_pressed() -> void:
	if visible:
		GameState.switch_mode(GameState.Mode.SINGLE)

func _on_splitscreen_button_pressed() -> void:
	if visible:
		GameState.switch_mode(GameState.Mode.SPLIT)


func _on_new_map_button_pressed() -> void:
	if visible:
		GameState.regenerate_level()

func _on_quit_button_pressed() -> void:
	if visible:
		get_tree().quit()
