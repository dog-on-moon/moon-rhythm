extends Control

@export var song: AudioStream
@export var rhythm_data: RhythmData

@onready var audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer

func _ready() -> void:
	# Setup callbacks.
	RhythmServer.add_down_callback(self, &"beat", _on_down)
	RhythmServer.set_key_track(&"key")
	RhythmServer.key_updated.connect(key_updated)
	
	# Begin song.
	audio_stream_player.stream = song
	RhythmServer.add_audio_stream_player(audio_stream_player, rhythm_data)
	audio_stream_player.play()

func _on_down(h: Hit):
	print('hit %s' % h.beat)

func key_updated(key_notes: Array[Note]):
	print(key_notes)
