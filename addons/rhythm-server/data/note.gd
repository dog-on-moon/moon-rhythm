extends Resource
class_name Note
## A single music note.
## Holds pitch, octave, and (optional) playback effects.

const TWELVTH_ROOT := pow(2.0, 1.0 / 12.0)

## An enum representing each pitch.
## Contains a null value for pitchless.
enum Pitch {
	Null,
	C, Db, D, Eb,
	E, F, Gb, G,
	Ab, A, Bb, B,
}

## The pitch of the note, relative to C.
## Pitchless notes have a null pitch.
@export var pitch := Pitch.Null

## The octave of the note.
@export var octave := 0

## The volume of the note.
@export var volume := 1.0

var total_pitch: int:
	get: return get_total_pitch(pitch, octave)

func get_pitch_scale(root_pitch := Pitch.C, root_octave := 3) -> float:
	var dist := total_pitch - get_total_pitch(root_pitch, root_octave)
	return pow(TWELVTH_ROOT, dist)

static func get_total_pitch(_pitch: Pitch, _octave: int) -> int:
	return (_octave * 12) + int(_pitch) - 1

func _to_string() -> String:
	return str(total_pitch)
