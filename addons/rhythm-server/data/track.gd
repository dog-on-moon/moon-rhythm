@tool
extends Resource
class_name Track
## An array of hits in a given SongData.
## A SongData may have multiple music lines to keep up with.
## For a song, this may reflect different instruments.
## For a beatmap, this may reflect multiple input lanes.

## The name of the Track.
@export var name := &'Default'

## The hits within the Track.
## These are sorted by beat time.
@export var hits: Array[Hit] = []

func sort_hits():
	hits.sort_custom(
		func (a: Hit, b: Hit):
			return a.beat < b.beat
			)
