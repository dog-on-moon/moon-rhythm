extends Resource
class_name Note
## A single music note.
## Holds pitch, octave, and (optional) playback effects.

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
	get:
		return (octave * 12) + int(pitch) - 1

func _to_string() -> String:
	return str(total_pitch)
