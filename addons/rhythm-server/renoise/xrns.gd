class_name XRNS
## A script containing several classes for building/reading an XRNS file.

class XRNSFile extends RefCounted:
	
	var global_song_data: XRNSGlobalSongData = null
	var instruments: Array[XRNSInstrument] = []
	var tracks: Array[XRNSTrack] = []
	var patterns: Array[XRNSPattern] = []
	var pattern_sequence: XRNSPatternSequence = null
	
	var bpm_map := {}
	var lpb_map := {}
	var lpb_cache := {}
	var bpm_cache := {}
	
	static func create_from_xml(xml: XMLParser) -> XRNSFile:
		var f := XRNSFile.new()
		
		# Handle XML parsing.
		while xml.read() != ERR_FILE_EOF:
			if XRNS.is_start_element(xml, "GlobalSongData"):
				f.global_song_data = XRNSGlobalSongData.create_from_xml(xml)
			elif XRNS.is_start_element(xml, "Instruments"):
				while true:
					if xml.read() == ERR_FILE_EOF: return f
					XRNS.skip_whitespace(xml)
					if XRNS.is_end_element(xml, "Instruments"): break
					elif XRNS.is_start_element(xml, "Instrument"):
						f.instruments.append(XRNSInstrument.create_from_xml(xml))
				#print('read %s instruments' % f.instruments.size())
			elif XRNS.is_start_element(xml, "Tracks"):
				while true:
					if xml.read() == ERR_FILE_EOF: return f
					XRNS.skip_whitespace(xml)
					if XRNS.is_end_element(xml, "Tracks"): break
					elif XRNS.is_start_element(xml, "SequencerTrack"):
						f.tracks.append(XRNSTrack.create_from_xml(xml))
					elif XRNS.is_start_element(xml, "SequencerMasterTrack"):
						f.tracks.append(XRNSTrack.create_from_xml(xml))
					elif XRNS.is_start_element(xml, "SequencerSendTrack"):
						f.tracks.append(XRNSTrack.create_from_xml(xml))
				#print('read %s tracks' % f.tracks.size())
			elif XRNS.is_start_element(xml, "Patterns"):
				while true:
					if xml.read() == ERR_FILE_EOF: return f
					XRNS.skip_whitespace(xml)
					if XRNS.is_end_element(xml, "Patterns"): break
					elif XRNS.is_start_element(xml, "Pattern"):
						f.patterns.append(XRNSPattern.create_from_xml(xml, f.tracks))
				#print('read %s patterns' % f.patterns.size())
			elif XRNS.is_start_element(xml, "PatternSequence"):
				f.pattern_sequence = XRNSPatternSequence.create_from_xml(xml)
				#print('pattern seq: %s' % [f.pattern_sequence.order])
		
		# We are done.
		f._build_caches()
		return f
	
	func _build_caches():
		bpm_map[0.0] = global_song_data.bpm
		lpb_map[0.0] = global_song_data.lpb

		# pass #1 for LPB
		for track_idx in tracks.size():
			for fx_col in tracks[track_idx].fx_cols:
				var global_line_index := 0
				for pattern_idx in pattern_sequence.order:
					var pattern := patterns[pattern_idx]
					var track := pattern.tracks[track_idx]
					for local_line_idx in track.lines:
						var line := track.lines[local_line_idx]
						if local_line_idx >= pattern.lines:
							continue
						if fx_col not in line.effects:
							continue
						var effect := line.effects[fx_col]
						if effect.number == "ZL":
							var line_index := global_line_index + local_line_idx
							lpb_map[line_index] = effect.value
					global_line_index += pattern.lines

		# pass #2 for BPM
		for track_idx in tracks.size():
			for fx_col in tracks[track_idx].fx_cols:
				var global_line_index := 0
				for pattern_idx in pattern_sequence.order:
					var pattern := patterns[pattern_idx]
					var track := pattern.tracks[track_idx]
					for local_line_idx in track.lines:
						var line := track.lines[local_line_idx]
						if local_line_idx >= pattern.lines:
							continue
						if fx_col not in line.effects:
							continue
						var effect := line.effects[fx_col]
						if effect.number == "ZT":
							var line_index := global_line_index + local_line_idx
							var current_lbp := get_lpb(line_index)
							var time := float(line_index) / float(current_lbp)
							bpm_map[time] = effect.value
					global_line_index += pattern.lines
	
	func get_pattern_start_line(pattern_idx: int) -> int:
		var lines := 0
		for idx in pattern_idx:
			lines += patterns[pattern_sequence.order[idx]].lines
		return lines
	
	func get_pattern_beats(pattern_idx: int) -> float:
		var start_line := get_pattern_start_line(pattern_idx)
		var end_line := get_pattern_start_line(pattern_idx + 1)
		var beats := 0.0
		for line_idx in range(start_line, end_line):
			beats += 1.0 / float(get_lpb(line_idx))
		return beats
	
	func get_lpb(_line_idx: int) -> int:
		if _line_idx not in lpb_cache:
			var max_lpb_index: float = lpb_map.keys().max()
			if _line_idx >= max_lpb_index:
				lpb_cache[_line_idx] = lpb_map[max_lpb_index]
			else:
				var sorted_lpb := lpb_map.keys()
				sorted_lpb.sort()
				for lower_idx in sorted_lpb.size() - 1:
					var lower: int = sorted_lpb[lower_idx]
					var higher: int = sorted_lpb[lower_idx + 1]
					if lower <= _line_idx and _line_idx < higher:
						lpb_cache[_line_idx] = lpb_map[lower]
						break
		
		return lpb_cache[_line_idx]
	
	func get_beat_of_line(_line_idx: int) -> float:
		var beat := 0.0
		for line in _line_idx:
			beat += 1.0 / get_lpb(line)
		return beat
	
	func get_bpm(beat: float) -> float:
		if beat not in bpm_cache:
			var max_bpm_index: float = bpm_map.keys().max()
			if beat >= max_bpm_index:
				bpm_cache[beat] = bpm_map[max_bpm_index]
			else:
				var sorted_bpm := bpm_map.keys()
				sorted_bpm.sort()
				for lower_idx in sorted_bpm.size() - 1:
					var lower: int = sorted_bpm[lower_idx]
					var higher: int = sorted_bpm[lower_idx + 1]
					if lower <= beat and beat < higher:
						bpm_cache[beat] = bpm_map[lower]
						break
		
		return bpm_cache[beat]
	
	func get_line_duration(line_idx: int):
		var beat := get_beat_of_line(line_idx)
		var lpb := get_lpb(line_idx)
		var bpm := get_bpm(beat)
		return (1.0 / (lpb * bpm)) * 60.0
	
	func get_pattern_duration(pattern_idx: int):
		var pattern_id := pattern_sequence.order[pattern_idx]
		var pattern := patterns[pattern_id]
		var start_line := get_pattern_start_line(pattern_idx)
		var end_line := start_line + pattern.lines
		var duration := 0.0
		for line_idx in range(start_line, end_line):
			duration += get_line_duration(line_idx)
		return duration
	
	func get_song_duration() -> float:
		var duration := 0.0
		for pattern_idx in pattern_sequence.order.size():
			duration += get_pattern_duration(pattern_idx)
		return duration
	
	func get_song_beats() -> float:
		var beats := 0.0
		for pattern_idx in pattern_sequence.order.size():
			beats += get_pattern_beats(pattern_idx)
		return beats

class XRNSGlobalSongData extends RefCounted:
	
	var bpm: int = 0
	var lpb: int = 0
	var tpl: int = 0
	
	static func create_from_xml(xml: XMLParser) -> XRNSGlobalSongData:
		var gsd := XRNSGlobalSongData.new()
		while xml.read() != ERR_FILE_EOF:
			if XRNS.is_start_element(xml, "BeatsPerMin"):
				xml.read()
				gsd.bpm = int(xml.get_node_data())
			elif XRNS.is_start_element(xml, "LinesPerBeat"):
				xml.read()
				gsd.lpb = int(xml.get_node_data())
			elif XRNS.is_start_element(xml, "TicksPerLine"):
				xml.read()
				gsd.tpl = int(xml.get_node_data())
			elif XRNS.is_end_element(xml, "GlobalSongData"):
				break
		return gsd

class XRNSInstrument extends RefCounted:
	
	var name: String
	var transpose: int
	
	static func create_from_xml(xml: XMLParser) -> XRNSInstrument:
		var inst := XRNSInstrument.new()
		while xml.read() != ERR_FILE_EOF:
			if XRNS.is_end_element(xml, "Instrument"):
				break
			elif XRNS.is_start_element(xml, "Name"):
				xml.read()
				inst.name = xml.get_node_data()
			elif XRNS.is_start_element(xml, "GlobalProperties"):
				while true:
					if XRNS.is_end_element(xml, "GlobalProperties"): break
					if xml.read() == ERR_FILE_EOF: return inst
					if XRNS.is_start_element(xml, "Transpose"):
						xml.read()
						inst.transpose = int(xml.get_node_data())
			elif XRNS.is_start_element(xml, "PhraseGenerator"):
				xml.skip_section()
			elif XRNS.is_start_element(xml, "SampleGenerator"):
				xml.skip_section()
			elif XRNS.is_start_element(xml, "PluginGenerator"):
				xml.skip_section()
			elif XRNS.is_start_element(xml, "MidiGenerator"):
				xml.skip_section()
		return inst

class XRNSTrack extends RefCounted:
	
	var name: String
	var note_cols: int
	var fx_cols: int
	
	static func create_from_xml(xml: XMLParser) -> XRNSTrack:
		var track := XRNSTrack.new()
		while xml.read() != ERR_FILE_EOF:
			if XRNS.is_end_element(xml, "SequencerTrack"):
				break
			elif XRNS.is_end_element(xml, "SequencerMasterTrack"):
				break
			elif XRNS.is_end_element(xml, "SequencerSendTrack"):
				break
			elif XRNS.is_start_element(xml, "Name"):
				xml.read()
				track.name = xml.get_node_data()
			elif XRNS.is_start_element(xml, "NumberOfVisibleNoteColumns"):
				xml.read()
				track.note_cols = int(xml.get_node_data())
			elif XRNS.is_start_element(xml, "NumberOfVisibleEffectColumns"):
				xml.read()
				track.fx_cols = int(xml.get_node_data())
			elif XRNS.is_start_element(xml, "NoteColumnStates"):
				xml.skip_section()
			elif XRNS.is_start_element(xml, "NoteColumnNames"):
				xml.skip_section()
			elif XRNS.is_start_element(xml, "FilterDevices"):
				xml.skip_section()
		return track

class XRNSPattern extends RefCounted:
	
	class EffectColumn extends RefCounted:
		var number: String
		var value: int
		
		static func create_from_xml(xml: XMLParser) -> EffectColumn:
			var col := EffectColumn.new()
			var real := false
			while xml.read() != ERR_FILE_EOF:
				if XRNS.is_end_element(xml, "EffectColumn"):
					break
				elif XRNS.is_start_element(xml, "Number"):
					real = true
					xml.read()
					col.number = xml.get_node_data()
					#print(col)
				elif XRNS.is_start_element(xml, "Value"):
					real = true
					xml.read()
					col.value = xml.get_node_data().hex_to_int()
			return col if real else null
	
	class NoteColumn extends RefCounted:
		var note: Note
		var inst: int
		var delay: int
		
		static func create_from_xml(xml: XMLParser) -> NoteColumn:
			var col := NoteColumn.new()
			var real := false
			while xml.read() != ERR_FILE_EOF:
				if XRNS.is_end_element(xml, "NoteColumn"):
					break
				elif XRNS.is_start_element(xml, "Note"):
					real = true
					xml.read()
					var note_str: String = xml.get_node_data()
					if note_str != "OFF":
						var octave_str := note_str[-1]
						var pitch_str := note_str.left(2).trim_suffix('-')
						col.note = Note.from_str(pitch_str, int(octave_str))
				elif XRNS.is_start_element(xml, "Instrument"):
					xml.read()
					col.inst = xml.get_node_data().hex_to_int()
				elif XRNS.is_start_element(xml, "Delay"):
					xml.read()
					col.delay = xml.get_node_data().hex_to_int()
			return col if real else null
	
	class Line extends RefCounted:
		var notes: Dictionary[int, NoteColumn] = {}
		var effects: Dictionary[int, EffectColumn] = {}
		
		static func create_from_xml(xml: XMLParser, note_cols: int, fx_cols: int) -> Line:
			var line := Line.new()
			while xml.read() != ERR_FILE_EOF:
				if XRNS.is_end_element(xml, "Line"):
					break
				elif XRNS.is_start_element(xml, "NoteColumns"):
					var _idx := 0
					while true:
						if XRNS.is_end_element(xml, "NoteColumns"): break
						if xml.read() == ERR_FILE_EOF: return line
						if XRNS.is_empty_element(xml, "NoteColumn"):
							_idx += 1
						if XRNS.is_start_element(xml, "NoteColumn") and _idx < note_cols:
							line.notes[_idx] = NoteColumn.create_from_xml(xml)
							_idx += 1
				elif XRNS.is_start_element(xml, "EffectColumns"):
					var _idx := 0
					while true:
						if XRNS.is_end_element(xml, "EffectColumns"): break
						if xml.read() == ERR_FILE_EOF: return line
						if XRNS.is_empty_element(xml, "EffectColumn"):
							_idx += 1
						if XRNS.is_start_element(xml, "EffectColumn") and _idx < fx_cols:
							line.effects[_idx] = EffectColumn.create_from_xml(xml)
							_idx += 1
			return line
	
	class PatternTrack extends RefCounted:
		var lines: Dictionary[int, Line] = {}
		var alias_pattern_index: int = -1
		
		static func create_from_xml(xml: XMLParser, track: XRNSTrack) -> PatternTrack:
			var pattern_track := PatternTrack.new()
			while xml.read() != ERR_FILE_EOF:
				if XRNS.is_end_element(xml, "PatternTrack"):
					break
				elif XRNS.is_end_element(xml, "PatternMasterTrack"):
					break
				elif XRNS.is_end_element(xml, "PatternSendTrack"):
					break
				elif XRNS.is_start_element(xml, "AliasPatternIndex"):
					xml.read()
					pattern_track.alias_pattern_index = int(xml.get_node_data())
				elif XRNS.is_start_element(xml, "Lines"):
					while true:
						if XRNS.is_end_element(xml, "Lines"): break
						if xml.read() == ERR_FILE_EOF: return pattern_track
						if XRNS.is_start_element(xml, "Line"):
							var index_str := xml.get_named_attribute_value_safe("index")
							var index: int = int(index_str) if index_str else 0
							pattern_track.lines[index] = Line.create_from_xml(xml, track.note_cols, track.fx_cols)
			return pattern_track
		
		func get_lines(_xrns: XRNSFile, _track_idx: int) -> Dictionary[int, Line]:
			if alias_pattern_index == -1:
				return lines
			else:
				var p := _xrns.patterns[alias_pattern_index]
				var t := p.tracks[_track_idx]
				return t.get_lines(_xrns, _track_idx)
	
	var lines: int
	var tracks: Array[PatternTrack] = []
	
	static func create_from_xml(xml: XMLParser, tracks: Array[XRNSTrack]) -> XRNSPattern:
		var pattern := XRNSPattern.new()
		var track_idx := -1
		while xml.read() != ERR_FILE_EOF:
			if XRNS.is_end_element(xml, "Pattern"):
				break
			elif XRNS.is_start_element(xml, "NumberOfLines"):
				xml.read()
				pattern.lines = int(xml.get_node_data())
			elif XRNS.is_start_element(xml, "Tracks"):
				while true:
					if XRNS.is_end_element(xml, "Tracks"): break
					if xml.read() == ERR_FILE_EOF: return pattern
					if XRNS.is_start_element(xml, "PatternTrack") or XRNS.is_start_element(xml, "PatternMasterTrack") or XRNS.is_start_element(xml, "PatternSendTrack"):
						track_idx += 1
						pattern.tracks.append(PatternTrack.create_from_xml(xml, tracks[track_idx]))
		return pattern

class XRNSPatternSequence extends RefCounted:
	
	var order: Array[int] = []
	
	static func create_from_xml(xml: XMLParser) -> XRNSPatternSequence:
		var pattern_seq := XRNSPatternSequence.new()
		
		while xml.read() != ERR_FILE_EOF:
			if XRNS.is_end_element(xml, "PatternSequence"):
				break
			elif XRNS.is_start_element(xml, "SequenceEntries"):
				while true:
					if XRNS.is_end_element(xml, "SequenceEntries"): break
					if xml.read() == ERR_FILE_EOF: return pattern_seq
					if XRNS.is_start_element(xml, "Pattern"):
						xml.read()
						pattern_seq.order.append(int(xml.get_node_data()))
		
		return pattern_seq

#region Static Util

static func is_start_element(xml: XMLParser, name: String) -> bool:
	return xml.get_node_type() == XMLParser.NODE_ELEMENT and xml.get_node_name() == name

static func is_end_element(xml: XMLParser, name: String) -> bool:
	return xml.get_node_type() == XMLParser.NODE_ELEMENT_END and xml.get_node_name() == name

static func is_empty_element(xml: XMLParser, name: String) -> bool:
	return xml.get_node_type() == XMLParser.NODE_ELEMENT and xml.get_node_name() == name and xml.is_empty()

static func skip_whitespace(xml: XMLParser):
	while xml.get_node_type() == XMLParser.NODE_TEXT:
		var data := xml.get_node_data()
		match data:
			"\n", "\t", " ":
				xml.read()
			_:
				break

#endregion
