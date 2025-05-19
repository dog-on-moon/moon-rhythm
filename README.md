![screen-shot](https://github.com/dog-on-moon/moon-rhythm/blob/main/readme/banner.png)

# 🌙 moon-rhythm - see more: [moonSuite](https://dog-game.xyz/tools/)

moon-rhythm is a Godot library for synchronizing music to gameplay.

## 🎵 RhythmData

A RhythmData resource stores instrument tracks and BPM mapping.
Each track stores a large array of Hits, which define their timing and playback information.

## 💻 RhythmServer

The RhythmServer is the meat and muscle of the plugin. It provides the ability to link
together a RhythmData class with an AudioStreamPlayer. RhythmServer will then
call function callbacks depending on the chart lined out within RhythmData.

### 🪝 Setup

To begin the RhythmServer's music tracking, you must call the following function:

```gdscript
RhythmServer.add_audio_stream_player(audio_stream_player: Node, rhythm_data: RhythmData)
```

This will allow RhythmServer to begin managing callbacks in regards to the beatmap defined in `RhythmData`, in sync with the `AudioStreamPlayer`.

The musical tracking stops whenever the `AudioStreamPlayer` leaves the tree, or `RhythmServer.remove_audio_stream_player` is called.

### 📞 Callbacks

RhythmServer supports an extreme amount of musical callbacks.
Each one returns a Hit object, which is stored in a Track of a MusicData.

There are two types of callbacks:
1. One-shot (returns a Hit object)
  1. `RhythmServer.add_cue_callback(X)`: Calls the function X beats before any Hit starts playing.
  2. `RhythmServer.add_down_callback`: Calls the function whenever any Hit starts playing.
  3. `RhythmServer.add_up_callback`: Calls the function whenever any Hit is released (only affects hits with defined releases).
  4. `RhythmServer.add_end_callback(X)`: Calls the function X beats after the up callback.
2. Process (returns a Hit object and a delta value for process)
  1. `RhythmServer.add_inbound_callback(X)`: Called for every hit on every frame between their Cue and Down callbacks.
  2. `RhythmServer.add_hold_callback`: Called for every hit on every frame between their Down and Up callbacks.
  3. `RhythmServer.add_outbound_callback(X)`: Called for every hit on every frame between their Up and End callbacks.

All above callback functions have four arguments in common:
- owner: A node associated with this callback.
- track: The track from the RhythmData to filter callbacks for.
- callback: A callable with appropriate arguments to receive the object.
- is_visual: Delays the callback by `RhythmServer.VISUAL_OFFSET` seconds.

In addition (still with me?), there are two extra functions for managing RhythmServer callbacks:

1. `RhythmServer.clear_callbacks(owner: Node)`: Removes all callbacks associated with a Node. Note this is called automatically whenever the Node leaves the scene tree.
2. `RhythmServer.flush_callback_state()`: Flushes all active callback state. This is a bad idea.

### 🙏 API

The RhythmServer also has several functions for accessing its current state.

(For all below functions, if no ASP is defined, the primary ASP is used instead.)

- `RhythmServer.get_current_stream_player() -> Node`: Returns the primary AudioStreamPlayer. If multiple AudioStreamPlayers are setup with the RhythmServer, then this is the initial one.
- `RhythmServer.get_current_beat(is_visual := true, audio_stream_player: Node = null) -> float`: Returns the current beat of the song, with regards to all defined audio/visual offsets.
- `RhythmServer.get_current_time(is_visual := true, audio_stream_player: Node = null) -> float`: Returns the current time in seconds of the song, with regards to all defined audio/visual offsets.
- `RhythmServer.get_current_bpm(is_visual := true, audio_stream_player: Node = null) -> float`: Returns the current BPM of the song, with regards to all defined audio/visual offsets.
- `RhythmServer.get_current_playback_beat(audio_stream_player: Node = null) -> float`: Returns the current beat of the song. Audio/visual offsets are ignored.
- `RhythmServer.get_current_playback_position(audio_stream_player: Node = null) -> float`: Returns the current time in seconds of the song. Audio/visual offsets are ignored.
- `RhythmServer.get_current_playback_bpm(audio_stream_player: Node = null) -> float`: Returns the current BPM of the song. Audio/visual offsets are ignored.
- `RhythmServer.convert_beat_to_time(b: float, audio_stream_player: Node = null) -> float`: Converts a beat to its location in the song as seconds.
- `RhythmServer.convert_time_to_beat(t: float, audio_stream_player: Node = null) -> float`: Converts seconds to its location in the song as beats.
- `RhythmServer.get_track(track_name: StringName) -> Track`: Returns the Track object from an active RhythmData.

### ⌚ Latency

RhythmServer also has two properties available for tuning playback latency of its callbacks.
These are intended to be set externally.

- `RhythmServer.AUDIO_OFFSET`
  - The timing offset between input and audio.
  - This must be calculated with some sort of Input+Audio synchronization test, one which does NOT rely on visual information.
- `RhythmServer.AUDIO_OFFSET`
  - The timing offset between input and visual.
  - This must be calculated with some sort of Input+Visual synchronization test, one which does NOT rely on visual information.

### 🔑 Music "Key"

RhythmServer also has a system to track the current "key" of a song.

If an active RhythmData has a Track where multiple Hits play at the same time,
then the Track's name can be registered at game start by calling `RhythmServer.set_key_track(track_name: StringName)`.

From there, the RhythmServer will keep the current "key" of this Track in memory.
The current "key" of a Track is represented by all of the notes from its most recent concurrence of hits.

(For example, if my Track has 8 Hits that all go off on beat 4, then the RhythmServer's "key" will be set
to the Notes stored in all of those Hits on beat 4.)

Then, the current "key" of the RhythmServer can be accessed in two ways:

1. Attaching to the `RhythmServer.key_changed(track: StringName, notes: Array[Note])` signal.
2. Calling `RhythmServer.get_key(track: StringName) -> Array[Note]`.

## 🐻‍❄️ Nodes

moon-rhythm comes with two nodes by default:

### 🥁 HitRegister

The HitRegister is a basic implementation for accepting InputEvents within a certain,
beat-synced time window.

### 🤖 MusicFSM

MusicFSMs call enter/exit functions into children MusicStates depending on the beat of a song.
Useful for attaching distinct visual states to different phrases in a song.

Node2D and Node3D alternatives are provided.

## 🎛️ Renoise Integration



## Installation

- Add the folder from addons into your project's addons folder.
