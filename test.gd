extends Control

const TEST_RHYTHM_DATA = preload("res://test_rhythm_data.tres")
const TEST_SONG = preload("res://test_song.wav")

@onready var audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer

func _ready() -> void:
	# Setup callbacks.
	RhythmServer.add_down_callback(self, &"BEAT", _on_down)
	
	# Begin song.
	audio_stream_player.stream = TEST_SONG
	RhythmServer.add_audio_stream_player(audio_stream_player, TEST_RHYTHM_DATA)
	audio_stream_player.play()

func _on_down(h: Hit):
	print('hit %s' % h.beat)
