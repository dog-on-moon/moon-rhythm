@tool
extends EditorImportPlugin

func _import(source_file, save_path, options, r_platform_variants, r_gen_files):
	# Read XML buffer from .xrns file.
	var zip := ZIPReader.new()
	var err := zip.open(source_file)
	if err != OK:
		return err
	if not zip.file_exists("Song.xml"):
		zip.close()
		return FAILED
	var contents := zip.read_file("Song.xml")
	zip.close()
	if not contents:
		return FAILED
	var xml := XMLParser.new()
	var xml_err := xml.open_buffer(contents)
	if xml_err != OK:
		return xml_err
	
	# Grab options.
	var INSTRUMENT_PREFIX: String = options.instrument_prefix
	var OVERRIDE_BPM: float = options.override_bpm
	var IGNORE_RELEASES: bool = options.ignore_releases
	
	# load XRNS file (beefy)
	#var start := Time.get_ticks_usec()
	var xrns := XRNS.XRNSFile.create_from_xml(xml)
	#var end := Time.get_ticks_usec()
	#print('xrns load time: %s usec' % (end - start))
	
	# Write to rhythm data.
	var rd := RhythmData.new()
	if OVERRIDE_BPM:
		rd.bpm_map[0.0] = OVERRIDE_BPM
	else:
		rd.bpm_map = xrns.bpm_map.duplicate()
	
	if options.auto_beat_track:
		var beat_track := Track.new()
		beat_track.name = "BEAT"
		beat_track.resource_name = beat_track.name
		rd.tracks.append(beat_track)
		
		for beat in floori(xrns.get_song_beats()):
			var hit := Hit.new()
			hit.beat = beat
			beat_track.hits.append(hit)
	
	for inst_idx in xrns.instruments.size():
		var inst := xrns.instruments[inst_idx]
		if INSTRUMENT_PREFIX and not inst.name.begins_with(INSTRUMENT_PREFIX):
			continue
		
		# Create a track for this instrument.
		var track := Track.new()
		track.name = inst.name.trim_prefix(INSTRUMENT_PREFIX)
		track.resource_name = track.name
		rd.tracks.append(track)
		
		# Parse all note data.
		for xrns_track_idx in xrns.tracks.size():
			for note_col in xrns.tracks[xrns_track_idx].note_cols:
				var global_line_idx := 0
				var current_hit: Hit = null
				for pattern_idx in xrns.pattern_sequence.order:
					var pattern := xrns.patterns[pattern_idx]
					var pattern_track := pattern.tracks[xrns_track_idx]
					var lines := pattern_track.get_lines(xrns, xrns_track_idx)
					
					for local_line_idx: int in lines:
						if local_line_idx >= pattern.lines: continue
						
						var line_idx := global_line_idx + local_line_idx
						var current_lbp := xrns.get_lpb(line_idx)
						var line := lines[local_line_idx]
						if note_col not in line.notes:
							continue
						var note := line.notes[note_col]
						var delay_time := float(note.delay) / 256.0
						if not note.note or note.inst != inst_idx:
							if current_hit and not IGNORE_RELEASES:
								current_hit.end = xrns.get_beat_of_line(line_idx) + (delay_time / current_lbp)
								current_hit = null
						elif note.inst == inst_idx:
							current_hit = Hit.create_from_note(
								xrns.get_beat_of_line(line_idx) + (delay_time / current_lbp),
								0.0,
								note.note,
							)
							current_hit.note.transpose(inst.transpose)
							track.hits.append(current_hit)
					
					global_line_idx += pattern.lines
		
		track.sort_hits()
	
	# Save result, we're done!!
	return ResourceSaver.save(rd, "%s.%s" % [save_path, _get_save_extension()])

#region import boilerplate

func _get_importer_name():
	return "rhythmserver"

func _get_visible_name():
	return "RhythmData"

func _get_recognized_extensions():
	return ["xrns"]

func _get_save_extension():
	return "res"

func _get_resource_type():
	return "Resource"

func _get_preset_count():
	return 1

func _get_preset_name(preset_index):
	return "Default"

func _get_import_options(path, preset_index):
	return [
		{
			"name": "instrument_prefix",
			"default_value": "!",
		},
		{
			"name": "auto_beat_track",
			"default_value": false,
		},
		{
			"name": "override_bpm",
			"default_value": 0.0,
		},
		{
			"name": "ignore_releases",
			"default_value": false,
		}
	]

func _get_option_visibility(path, option_name, options):
	return true

func _get_import_order():
	return 0

func _get_priority():
	return 1.0

#endregion
