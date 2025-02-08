@tool
extends EditorPlugin

func _enter_tree():
	add_custom_type("RhytmData", "Resource", preload("data/rhythm_data.gd"), preload("data/rhythm_data.png"))
	add_autoload_singleton("RhythmServer", "rhythm_server.gd")

func _exit_tree():
	remove_custom_type("RhytmData")
	remove_autoload_singleton("RhythmServer")
