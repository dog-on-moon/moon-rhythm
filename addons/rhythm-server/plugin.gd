@tool
extends EditorPlugin

const RenoiseImportPlugin = preload("res://addons/rhythm-server/renoise/import_plugin.gd")
var renoise_import_plugin: RenoiseImportPlugin

func _enter_tree():
	add_custom_type("RhythmData", "Resource", preload("data/rhythm_data.gd"), preload("data/rhythm_data.png"))
	add_autoload_singleton("RhythmServer", "rhythm_server.gd")
	
	renoise_import_plugin = RenoiseImportPlugin.new()
	add_import_plugin(renoise_import_plugin)

func _exit_tree():
	remove_custom_type("RhythmData")
	remove_autoload_singleton("RhythmServer")
	
	remove_import_plugin(renoise_import_plugin)
	renoise_import_plugin = null
