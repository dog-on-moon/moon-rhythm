extends Node
## An autoload which manages various rhythm signals.
## Accepts a StreamPlayer and respective RhythmData as arguments.

@onready var AUDIO_OUTPUT_LATENCY := AudioServer.get_output_latency()

## The timing offset between input and audio. Set externally
## This must be calculated with some sort of Input+Audio synchronization test,
## one which does NOT rely on visual information.
var AUDIO_OFFSET := 0.0

## The timing offset between input and visual. Set externally.
## This must be calculated with some sort of Input+Visual synchronization test,
## one which does NOT rely on audio.
var VISUAL_OFFSET := 0.0

## The audio server output latency. Set every frame.
var AUDIO_SERVER_OFFSET := 0.0

## Determines if our audio server offset is active.
var use_internal_offset := true

#region AudioStream API

## The current audio streams we are managing.
var _active_streams: Dictionary[Node, RhythmData] = {}

## Adds an audio stream to be managed by the Rhythm Manager.
func add_audio_stream_player(audio_stream_player: Node, rhythm_data: RhythmData):
	assert(
		audio_stream_player is AudioStreamPlayer
		or audio_stream_player is AudioStreamPlayer2D
		or audio_stream_player is AudioStreamPlayer3D
	)
	_active_streams[audio_stream_player] = rhythm_data
	audio_stream_player.tree_exiting.connect(remove_audio_stream_player.bind(audio_stream_player))

## Removes an audio stream from being managed by the Rhythm Manager.
func remove_audio_stream_player(audio_stream_player: Node):
	_active_streams.erase(audio_stream_player)

#endregion

#region Callback API

## One-shot (args: [hit]). Constant time before the note plays
func add_cue_callback(owner: Node, track: StringName, callback: Callable, cue_beats := 0.5, is_visual: bool = true):
	_get_callback_group(CallbackGroupMode.CUE, track, is_visual, cue_beats).add_callback(owner, callback)

## One-shot (args: [hit]). When the note starts playing
func add_down_callback(owner: Node, track: StringName, callback: Callable, is_visual: bool = true):
	_get_callback_group(CallbackGroupMode.DOWN, track, is_visual).add_callback(owner, callback)

## One-shot (args: [hit]). When the note is released
func add_up_callback(owner: Node, track: StringName, callback: Callable, is_visual: bool = true):
	_get_callback_group(CallbackGroupMode.UP, track, is_visual).add_callback(owner, callback)

## One-shot (args: [hit]). Constant time after the note is released
func add_end_callback(owner: Node, track: StringName, callback: Callable, end_beats := 0.5, is_visual: bool = true):
	_get_callback_group(CallbackGroupMode.END, track, is_visual, end_beats).add_callback(owner, callback)

## Process (args: [hit, theta]). Between Cue and Down
func add_inbound_callback(owner: Node, track: StringName, callback: Callable, cue_beats := 0.5, is_visual: bool = true):
	_get_callback_group(CallbackGroupMode.INBOUND, track, is_visual, cue_beats).add_callback(owner, callback)

## Process (args: [hit, theta]). Between Down and Up
func add_hold_callback(owner: Node, track: StringName, callback: Callable, is_visual: bool = true):
	_get_callback_group(CallbackGroupMode.HOLD, track, is_visual).add_callback(owner, callback)

## Process (args: [hit, theta]). Between Up and End
func add_outbound_callback(owner: Node, track: StringName, callback: Callable, end_beats := 0.5, is_visual: bool = true):
	_get_callback_group(CallbackGroupMode.OUTBOUND, track, is_visual, end_beats).add_callback(owner, callback)

func clear_callbacks(owner: Node):
	for cbg in callback_groups:
		cbg.remove_owner(owner)

func flush_callback_state():
	for cbg in callback_groups:
		cbg.flush_callback_state()

#endregion

#region Callback Implementation

enum CallbackGroupMode {
	CUE,		## One-shot (args: [hit]). Constant time before the note plays
	DOWN,	## One-shot (args: [hit]). When the note starts playing
	UP,		## One-shot (args: [hit]). When the note is released
	END,		## One-shot (args: [hit]). Constant time after the note is released
	INBOUND,	## Process (args: [hit, theta]). Between Cue and Down
	HOLD,	## Process (args: [hit, theta]). Between Down and Up
	OUTBOUND	## Process (args: [hit, theta]). Between Up and End
}

## A CallbackGroup stores a group of callbacks that share the same mode, track, and parameters
## of whatever track they are listening to. By clustering together callbacks, we save some
## redundant rhythm processing and call all similar rhythmic callbacks together.
class CallbackGroup:
	var mode: CallbackGroupMode
	var track: StringName
	var is_visual: bool
	var arg := 0.0
	
	var owners: Array[Node] = []
	var callbacks: Array[Callable] = []
	
	var first_hit_index: int = 0
	var next_hit_index: int = 0
	
	var last_t_processed := 0.0
	var song_loops := 0
	var hit_loops_a := 0
	var hit_loops_b := 0
	
	func _init(p_mode: CallbackGroupMode, p_track: StringName, p_is_visual: bool, p_arg := 0.0) -> void:
		mode = p_mode
		track = p_track
		is_visual = p_is_visual
		arg = p_arg
	
	func flush_callback_state():
		first_hit_index = 0
		next_hit_index = 0
		last_t_processed = 0.0
		song_loops = 0
		hit_loops_a = 0
		hit_loops_b = 0
	
	func get_offset() -> float:
		var audio_offset: float = RhythmServer.AUDIO_OFFSET + RhythmServer.AUDIO_SERVER_OFFSET
		if is_visual:
			# We sync visual to the input offset, and then re-adjust with the
			# determined audio offset.
			audio_offset += RhythmServer.VISUAL_OFFSET
		return audio_offset
	
	func add_callback(owner: Node, callback: Callable):
		owners.append(owner)
		callbacks.append(callback)
	
	func cleanup_and_valid() -> bool:
		# Cleanup.
		for i in range(owners.size() - 1, -1, -1):
			if not is_instance_valid(owners[i]):
				owners.pop_at(i)
				callbacks.pop_at(i)
		# Return if valid.
		return owners.size() > 0
	
	func remove_owner(owner: Node):
		var idx := owners.find(owner)
		if idx != -1:
			owners.pop_at(idx)
			callbacks.pop_at(idx)
	
	func perform(args: Array):
		for callback in callbacks:
			callback.callv(args)

var callback_groups: Array[CallbackGroup] = []

func _get_callback_group(mode: CallbackGroupMode, track: StringName, is_visual: bool, arg := 0.0):
	for cbg in callback_groups:
		if cbg.track == track and cbg.mode == mode and is_equal_approx(cbg.arg, arg):
			return cbg
	var cbg := CallbackGroup.new(mode, track, is_visual, arg)
	callback_groups.append(cbg)
	return cbg

#endregion

#region Internal Process

func _process(delta):
	# Calculate audio server delay.
	if use_internal_offset:
		var new_offset := AudioServer.get_time_since_last_mix() - AUDIO_OUTPUT_LATENCY
		AUDIO_SERVER_OFFSET = maxf(
			# If our offset is going down, ensure we only go down by up to delta.
			# (This prevents a "time travel" bug in our offsets.)
			move_toward(AUDIO_SERVER_OFFSET, new_offset, delta),
			# But if our offset went up, just use that.
			new_offset,
		)
	else:
		AUDIO_SERVER_OFFSET = 0.0
	
	# Get timing constants relative to the song.
	for audio_stream in _active_streams:
		var stream: AudioStream = audio_stream.stream
		var rhythm_data: RhythmData = _active_streams[audio_stream]
		var base_t: float = audio_stream.get_playback_position()
		var duration: float = audio_stream.stream.get_length()
		
		# Iterate over all of our callables.
		for callgroup in callback_groups.duplicate():
			# Check cleanliness.
			if not callgroup.cleanup_and_valid():
				callback_groups.erase(callgroup)
				continue
			
			# Get the track associated with this callgroup.
			var track: Track = rhythm_data.get_track(callgroup.track)
			if not track:
				continue
			
			# Get the timing value for this callgroup.
			var t: float = base_t + callgroup.get_offset()
			
			# Count the number of times we've really looped the song.
			if callgroup.last_t_processed > base_t:
				callgroup.song_loops += 1
			callgroup.last_t_processed = base_t
			
			# Get the beat for this callgroup.
			var beat: float = rhythm_data.get_beat(stream, t)
			var loop_beat: float = rhythm_data.get_beat(stream, t - duration)      # the beat we'll be at after we loop
			var pre_loop_beat: float = rhythm_data.get_beat(stream, t + duration)  # the beat we were at before we looped
			
			# Do a different action per callgroup.
			var total_hits := track.hits.size()
			match callgroup.mode:
				# One-shot cue manufacturing
				CallbackGroupMode.CUE, CallbackGroupMode.DOWN, CallbackGroupMode.UP, CallbackGroupMode.END:
					# Have we reached the next hit cue yet?
					while true:
						# Determine the hit and target time.
						var hit: Hit = track.hits[callgroup.next_hit_index]
						var target_beat := 0.0
						match callgroup.mode:
							CallbackGroupMode.CUE:
								target_beat = hit.beat - callgroup.arg
							CallbackGroupMode.DOWN:
								target_beat = hit.beat
							CallbackGroupMode.UP:
								target_beat = (hit.end if hit.end else hit.beat)
							CallbackGroupMode.END:
								target_beat = (hit.end if hit.end else hit.beat) + callgroup.arg
						
						# If we've exceeded that time, perform callgroup and run it again.
						var check_beat := (
							pre_loop_beat if callgroup.song_loops > callgroup.hit_loops_a
							else (
								loop_beat if callgroup.song_loops < callgroup.hit_loops_a
								else beat
							)
						)
						if check_beat > target_beat:
							callgroup.perform([hit])
							callgroup.next_hit_index += 1
							if callgroup.next_hit_index >= total_hits:
								# We've exceeded all of the hits, so go back to 0.
								callgroup.next_hit_index = 0
								callgroup.hit_loops_a += 1
								break
						else:
							break
				
				# Process state manufacturing
				_:
					# Update our first hit index.
					while true:
						var hit: Hit = track.hits[callgroup.first_hit_index]
						var end_beat := _get_end_beat(hit, callgroup)
						var check_beat := (
							pre_loop_beat if callgroup.song_loops > callgroup.hit_loops_a
							else (
								loop_beat if callgroup.song_loops < callgroup.hit_loops_a
								else beat
							)
						)
						if check_beat > end_beat:
							callgroup.first_hit_index += 1
							if callgroup.first_hit_index >= total_hits:
								# We've exceeded all of the hits, so our first index
								# will be starting back at zero.
								callgroup.first_hit_index = 0
								callgroup.hit_loops_a += 1
								break
						else:
							# Our beat has not exceeded the end of this hit.
							# So we'll keep accounting for it within our process.
							break
					
					# Update our next hit index.
					while true:
						var hit: Hit = track.hits[callgroup.next_hit_index]
						var start_beat := _get_start_beat(hit, callgroup)
						var check_beat := (
							pre_loop_beat if callgroup.song_loops > callgroup.hit_loops_b
							else (
								loop_beat if callgroup.song_loops < callgroup.hit_loops_b
								else beat
							)
						)
						if check_beat > start_beat:
							callgroup.next_hit_index += 1
							if callgroup.next_hit_index >= total_hits:
								# The next hit index has exceeded all hits,
								# so flip it back to the start.
								callgroup.next_hit_index = 0
								callgroup.hit_loops_b += 1
								break
						else:
							# Our beat does not account for the start of this beat.
							# So we won't account for it within our processes.
							break
					
					# Grab the hits we care about.
					var hits_we_care_about: Array = []
					if callgroup.first_hit_index > callgroup.next_hit_index:
						hits_we_care_about = track.hits.slice(callgroup.first_hit_index, total_hits) + track.hits.slice(0, callgroup.next_hit_index)
					else:
						hits_we_care_about = track.hits.slice(callgroup.first_hit_index, callgroup.next_hit_index)
					
					# Call the beats from the start to the end or true end.
					for hit in hits_we_care_about:
						# Determine our beat ranges.
						var start_beat := _get_start_beat(hit, callgroup)
						var end_beat := _get_end_beat(hit, callgroup)
						
						# If we're within range, perform the callgroup.
						# TODO - is there a better way to check these?
						if beat >= start_beat and beat <= end_beat:
							var theta := inverse_lerp(start_beat, end_beat, beat)
							callgroup.perform([hit, theta])
						elif loop_beat >= start_beat and loop_beat <= end_beat:
							var theta := inverse_lerp(start_beat, end_beat, loop_beat)
							callgroup.perform([hit, theta])
						elif pre_loop_beat >= start_beat and pre_loop_beat <= end_beat:
							var theta := inverse_lerp(start_beat, end_beat, pre_loop_beat)
							callgroup.perform([hit, theta])

func _get_start_beat(hit: Hit, callgroup: CallbackGroup) -> float:
	match callgroup.mode:
		CallbackGroupMode.INBOUND:
			return hit.beat - callgroup.arg
		CallbackGroupMode.HOLD:
			return hit.beat
		CallbackGroupMode.OUTBOUND:
			return (hit.end if hit.end else hit.beat)
	return 0.0

func _get_end_beat(hit: Hit, callgroup: CallbackGroup) -> float:
	match callgroup.mode:
		CallbackGroupMode.INBOUND:
			return hit.beat
		CallbackGroupMode.HOLD:
			return (hit.end if hit.end else hit.beat)
		CallbackGroupMode.OUTBOUND:
			return (hit.end if hit.end else hit.beat) + callgroup.arg
	return 0.0

#endregion

#region Time Getters
func get_visual_beat(audio_stream_player: Node) -> float:
	assert(audio_stream_player in _active_streams)
	var t: float = audio_stream_player.get_playback_position() + AUDIO_OFFSET + AUDIO_SERVER_OFFSET + VISUAL_OFFSET
	var d: RhythmData = _active_streams[audio_stream_player]
	return d.get_beat(audio_stream_player.stream, t)

func get_visual_bpm(audio_stream_player: Node) -> float:
	var t: float = audio_stream_player.get_playback_position() + AUDIO_OFFSET + AUDIO_SERVER_OFFSET + VISUAL_OFFSET
	var d: RhythmData = _active_streams[audio_stream_player]
	return d.get_bpm(d.get_beat(audio_stream_player.stream, t))
#endregion
