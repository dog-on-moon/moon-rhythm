extends Resource
class_name Hit
## A 'hit' in a song.
## Holds its relative beat in the song along with its release (if defined).
## May also hold a 'note,' reflecting its relative pitch and octave.

## The relative beat in the song that the hit lands on.
@export var beat := 0.0

## The release beat of the hit (if zero, the hit is releaseless).
@export var end := 0.0

## An optional "note" can store pitch and volume data for the hit.
@export var note: Note = null

## Extra information per hit can be defined externally here.
@export var arguments: Dictionary = {}

# do not ask
static func create_from_note(_beat: float, _end: float, _note: Note) -> Hit:
	var h := Hit.new()
	h.beat = _beat
	h.end = _end
	h.note = _note
	return h
