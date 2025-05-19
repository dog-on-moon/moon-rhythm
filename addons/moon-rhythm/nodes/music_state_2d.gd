@icon("res://addons/moon-rhythm/data/rhythm_data.png")
extends Node2D
class_name MusicState2D
## A state node for a MusicFSM.
## Listens to hits on a certain track, filtering by their Note data.

signal cued(h: Hit)

@onready var fsm: MusicFSM2D = get_parent()

## The track to listen to for state entry.
@export var track_name := &""

## The pitch filter to listen to from Track notes (C0 = 0, C#0 = 1, etc)
@export_range(0, 120, 1) var pitch_filter := 0

## Number of beats in advance to cue this state's entry.
@export_range(0.0, 8.0, 0.001, "or_greater") var cue_beats := 0.0

## Are the cue callback hits linked to visual or input synchronization?
@export var is_visual := true

var active := false

var start_beat := -1.0  # set by FSM

@onready var _setup = __setup()
func __setup():
	if not is_zero_approx(cue_beats):
		RhythmServer.add_cue_callback(self, track_name, cued.emit, cue_beats, is_visual)
	else:
		RhythmServer.add_down_callback(self, track_name, cued.emit, is_visual)

## Called from FSM when the filtered note begins in cue_beats.
func _enter():
	pass

## Called from FSM when this state ends (and another one will soon begin)
func _exit():
	pass

## Called X beats away from the start beat.
## (This can be negative during a cue frame)
func on_beat(x: float):
	pass
