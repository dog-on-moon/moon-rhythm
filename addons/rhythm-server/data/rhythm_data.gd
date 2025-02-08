extends Resource
class_name RhythmData
## Stores rhythmic data to be associated with an active audio stream.

## All hit tracks in the song.
@export var tracks: Array[Track] = []

## A map of BPM changes within the song.
## Stores beats to BPM (so, define a 0 key)
@export var bpm_map: Dictionary = {}

var _track_map: Dictionary = {}

func get_track(name: StringName) -> Track:
	if not _track_map:
		for track in tracks:
			_track_map[track.name] = track
	return _track_map.get(name)

const MINUTES_PER_SECOND := 1.0 / 60.0

## From a given time, return the current 'beat'
## that we are on in the song.
func get_beat(audio_stream: AudioStream, t: float, return_time := false) -> float:
	# Get the bpm map, set appropriate defaults.
	if not bpm_map:
		return 0.0
	if not audio_stream:
		return 0.0
	if bpm_map.size() == 1:
		var bpm: float = bpm_map.values()[0]
		var bps := bpm * MINUTES_PER_SECOND
		if not return_time:
			# seconds => beats
			return bps * t
			pass
		else:
			# beats => seconds
			var spb := 1.0 / bps
			return spb * t
	
	# Investigate each pair of BPM, grab the timing if we're in-between there.
	var song_duration := audio_stream.get_length()
	var beat_keys := bpm_map.keys()
	var curr_t := 0.0
	for idx in bpm_map.size():
		var is_last_idx := (idx == (bpm_map.size() - 1))
		
		# Determine the timing for this bpm.
		var this_beat: float = beat_keys[idx]
		var bpm: float = bpm_map[this_beat]
		var bps := bpm * MINUTES_PER_SECOND
		var spb := 1.0 / bps
		
		# Calculate the amount of time that'll pass between now and the next beat.
		var next_beat: float = beat_keys[idx + 1] if not is_last_idx else (
			# If we're on our last index, the next_beat will be the last beat of the song.
			this_beat + ((song_duration - curr_t) * bps)
		)
		var time_delta := (next_beat - this_beat) * spb
		
		# Is our goal time within our timeframe? (or the song doesn't end?)
		if (((curr_t + time_delta) < t) if not return_time else (next_beat < t)) and not is_last_idx:
			# Our goal time is not in this timeframe, so accumulate
			curr_t += time_delta
		else:
			# The timeframe is good, so determine the delta that gets us there.
			if not return_time:
				var beat_delta := inverse_lerp(curr_t, curr_t + time_delta, t)
				return lerp(this_beat, next_beat, beat_delta)
			else:
				var beat_delta := inverse_lerp(this_beat, next_beat, t)
				return lerp(curr_t, curr_t + time_delta, beat_delta)
	
	assert(false)
	return 0.0

## From a given beat, return the current 'time' that it is in the song.
func get_time(audio_stream: AudioStream, b: float) -> float:
	return get_beat(audio_stream, b, true)

## Returns the BPM at a given beat.
func get_bpm(b: float) -> float:
	if not bpm_map:
		return 0.0
	if bpm_map.size() == 1:
		return bpm_map.values()[0]
	
	var beat_keys := bpm_map.keys()
	for idx in bpm_map.size():
		var is_last_idx := (idx == (bpm_map.size() - 1))
		var this_beat: float = beat_keys[idx]
		var bpm: float = bpm_map[this_beat]
		if is_last_idx:
			return bpm
		else:
			var next_beat: float = beat_keys[idx + 1]
			if b >= this_beat and b < next_beat:
				return bpm
	
	assert(false)
	return 0.0
