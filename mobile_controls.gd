extends CanvasLayer

#func _ready() -> void:
	#var is_mobile := OS.get_name() in ["Android", "iOS"]
	#var has_touch := DisplayServer.is_touchscreen_available()
#
	#if is_mobile or has_touch:
		#show()
	#else:
		#hide()
		
#extends CanvasLayer
#
#@export var force_show_for_testing: bool = true
#
#func _ready() -> void:
	#var is_mobile := OS.get_name() in ["Android", "iOS"]
	#var has_touch := DisplayServer.is_touchscreen_available()
#
	#visible = force_show_for_testing or is_mobile or has_touch
#
	#print("MobileControls visible: ", visible)
	#print("OS: ", OS.get_name())
	#print("Touch available: ", has_touch)
	#print("InterfaceLayer visible: ", get_parent().visible)
