@icon("res://addons/moon-rhythm/data/rhythm_data.png")
extends Node3D
class_name MusicFSM3D

const DEBUG_PRINT := false

var _states: Array[MusicState3D] = []

func _enter_tree():
	child_entered_tree.connect(_add_state)
	child_exiting_tree.connect(_remove_state)
	
	RhythmServer.add_down_callback(self, &"BEAT", _on_beat_internal)

func _ready() -> void:
	# Determine the initial state best contender.
	var current_beat := RhythmServer.get_current_beat()
	var best_state: MusicState3D = null
	var best_state_beat := -1.0
	var best_hit: Hit = null
	
	for state: MusicState3D in _states:
		# Find the associated track.
		var track := RhythmServer.get_track(state.track_name)
		var cue_beats := state.cue_beats
		var cueable := not is_zero_approx(cue_beats)
		if not track:
			continue
		
		# Iterate over the track hits, attempting to see if it is the best contender.
		for hit in track.hits:
			var hits_are_valid := false
			var hit_beat := hit.beat
			
			if cueable:
				var cue_beat := hit_beat - cue_beats
				if cue_beat > best_state_beat and cue_beat < current_beat:
					best_state = state
					best_state_beat = cue_beat
					hits_are_valid = true
					best_hit = hit
			
			if not hits_are_valid and hit_beat > best_state_beat and hit_beat < current_beat:
				best_state = state
				best_state_beat = hit_beat
				hits_are_valid = true
				best_hit = hit
			
			if not hits_are_valid:
				break
	
	# Enter the best state.
	if best_state:
		if not best_state.is_node_ready():
			await best_state.ready
		_on_state_cue(best_hit, best_state)

func _on_beat_internal(h: Hit):
	if current_state:
		current_state.on_beat(h.beat - current_state.start_beat)

func _add_state(s: Node):
	if s is MusicState3D:
		s.cued.connect(_on_state_cue.bind(s))
		_states.append(s)

func _remove_state(s: Node):
	if s is MusicState3D:
		s.cued.disconnect(_on_state_cue.bind(s))
		_states.erase(s)

signal state_changed(state: MusicState3D)
var current_state: MusicState3D = null

func _on_state_cue(h: Hit, state: MusicState3D):
	if not (h.note and h.note.total_pitch == state.pitch_filter):
		return
	if state == current_state:
		return
	if current_state:
		current_state._exit()
		current_state.active = false
	current_state = state
	current_state.active = true
	current_state.start_beat = h.beat
	if DEBUG_PRINT:
		print('(%s) Cueing state %s' % [get_instance_id(), state.name])
	state._enter()
	if is_equal_approx(h.beat, roundf(h.beat)):
		state.on_beat(0.0)
