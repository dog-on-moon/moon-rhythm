extends Node
class_name HitRegister
## A class that handles hit registration with a HitListener.

## The beat window to check for inputs within.
## This should be kept as low as possible,
## but should remain above the msec window.
const BEAT_WINDOW := 2.0

## Emitted when a hit has been registered.
signal hit_success(hit: Hit, offset: float)

## Emitted when a hit has been missed.
signal hit_failure(hit: Hit)

@export var track_name: StringName

@export_category("Configuration")
#region
## The name of the input action.
@export var input_action := &"ui_accept"

## The second window to accept inputs within.
@export var second_window := 0.1

## Whether or not hit registration is active.
@export var active := true:
	set(x):
		active = x
		set_process_unhandled_input(x)

## Whether or not we hit everything perfectly.
@export var auto := false
#endregion

## Tracks all hits we're watching for.
var hit_times := {}

func _ready() -> void:
	assert(track_name, "TrackName undefined")
	RhythmServer.add_cue_callback(self, track_name, hit_cue, BEAT_WINDOW, false)

## Look out for any notes we've missed.
func _process(delta: float) -> void:
	var t := RhythmServer.get_current_time(false)
	for hit in hit_times.keys():
		if has_missed_hit(hit, t):
			mark_miss(hit)

## Handle receiving an input action.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(input_action):
		var press_t := RhythmServer.get_current_time(false)
		for hit in hit_times:
			if has_hit_in_window(hit, press_t):
				mark_hit(hit, press_t)
				get_viewport().set_input_as_handled()
				return
		hit_failure.emit(null)
		get_viewport().set_input_as_handled()

func hit_cue(hit: Hit):
	hit_times[hit] = RhythmServer.convert_beat_to_time(hit.beat)

## Marks a hit as being successful.
func mark_hit(hit: Hit, press_t: float):
	hit_success.emit(hit, press_t - RhythmServer.convert_beat_to_time(hit.beat))
	cleanup_hit(hit)
	
	#var response := "late" if _offset > 0 else "early"
	#print('HIT! ({0}: {1})'.format([response, _offset]))

## Marks a hit as being a miss.
func mark_miss(hit: Hit):
	hit_failure.emit(hit)
	cleanup_hit(hit)

func cleanup_hit(hit: Hit):
	hit_times.erase(hit)

## Determines if we have successfully hit in the window.
func has_hit_in_window(hit: Hit, press_t: float) -> bool:
	return (abs(hit_times[hit] - press_t) <= second_window) or auto

## Determines if we've missed a hit.
func has_missed_hit(hit: Hit, current_t: float) -> bool:
	return (current_t - hit_times[hit]) > second_window
