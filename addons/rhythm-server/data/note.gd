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

func transpose(steps: int):
	pitch += steps
	while pitch > 12:
		pitch -= 12
		octave += 1
	while pitch < 1:
		pitch += 12
		octave -= 1

static func get_total_pitch(_pitch: Pitch, _octave: int) -> int:
	return (_octave * 12) + int(_pitch) - 1

func _to_string() -> String:
	return str(total_pitch)

const STR_TO_PITCH: Dictionary[String, Pitch] = {
	"C": Pitch.C,
	"C#": Pitch.Db,
	"Db": Pitch.Db,
	"D": Pitch.D,
	"D#": Pitch.Eb,
	"Eb": Pitch.Eb,
	"E": Pitch.E,
	"F": Pitch.F,
	"F#": Pitch.Gb,
	"Gb": Pitch.Gb,
	"G": Pitch.G,
	"G#": Pitch.Ab,
	"Ab": Pitch.Ab,
	"A": Pitch.A,
	"A#": Pitch.Bb,
	"Bb": Pitch.Bb,
	"B": Pitch.B,
}

static func from_str(pitch_str: String, octave := 3) -> Note:
	var n := Note.new()
	n.pitch = STR_TO_PITCH.get(pitch_str, Pitch.C)
	n.octave = octave
	return n
