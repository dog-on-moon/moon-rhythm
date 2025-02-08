extends Node
class_name HitRegister
## A class that handles hit registration with a HitListener.

## Emitted when a hit has been registered.
signal hit_success(hit: Hit)

## Emitted when a hit has been missed.
signal hit_failure(hit: Hit)

@export var track_name: StringName

@export_category("Configuration")
#region
## The name of the input action.
@export var input_action := &"ui_accept"

## The msec window to accept inputs within.
@export var msec_window := 100

## Whether or not hit registration is active.
@export var active := true:
	set(x):
		active = x
		set_process_unhandled_input(x)

## Whether or not we hit everything perfectly.
@export var auto := false
#endregion

## Dictionaries for note input
var hit_times := {}
var last_press_msec := 0

func _ready() -> void:
	assert(track_name, "TrackName undefined")
	RhythmServer.add_down_callback(self, track_name, hit_down, false)

## Look out for any notes we've missed.
func _process(delta: float) -> void:
	for hit in hit_times:
		if has_missed_hit(hit):
			mark_miss(hit)

## Handle receiving an input action.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(input_action):
		last_press_msec = Time.get_ticks_msec()
		for hit in hit_times:
			if has_hit_in_window(hit):
				mark_hit(hit)
				get_viewport().set_input_as_handled()
				break

## When the note is hit down, mark the time when it was to have been hit.
func hit_down(hit: Hit):
	hit_times[hit] = Time.get_ticks_msec() # TODO: make this more precise & exist on the hit object
	if has_hit_in_window(hit):
		mark_hit(hit)

## Marks a hit as being successful.
func mark_hit(hit: Hit):
	hit_success.emit(hit)
	cleanup_hit(hit)
	last_press_msec = 0
	#var offset := (last_press_msec - last_hit_msec)
	#var response := "late" if offset > 0 else "early"
	#print('HIT! ({0}: {1})'.format([response, last_press_msec - last_hit_msec]))

## Marks a hit as being a miss.
func mark_miss(hit: Hit):
	hit_failure.emit(hit)
	cleanup_hit(hit)

func cleanup_hit(hit: Hit):
	hit_times.erase(hit)

## Determines if we have successfully hit in the window.
func has_hit_in_window(hit: Hit) -> bool:
	return (abs(hit_times[hit] - last_press_msec) <= msec_window) or auto

## Determines if we've missed a hit.
func has_missed_hit(hit: Hit) -> bool:
	return (Time.get_ticks_msec() - hit_times[hit]) > msec_window
