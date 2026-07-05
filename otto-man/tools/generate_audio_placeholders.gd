@tool
extends EditorScript
## Godot Editor: File → Run → bu script
## `assets/audio/` placeholder wav üretir. Mevcut dosyaların üzerine yazmaz.

const AudioPlaceholderTones = preload("res://tools/audio_placeholder_tones.gd")

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"


func _run() -> void:
	_generate_folder(SFX_DIR, AudioPlaceholderTones.SFX_STEMS)
	_generate_folder(MUSIC_DIR, AudioPlaceholderTones.MUSIC_STEMS)
	print("[AudioPlaceholders] Done.")


func _generate_folder(out_dir: String, tones: Dictionary) -> void:
	var abs_dir := ProjectSettings.globalize_path(out_dir)
	DirAccess.make_dir_recursive_absolute(abs_dir)
	var written: int = 0
	for stem in tones.keys():
		var out_path: String = out_dir + stem + ".wav"
		if ResourceLoader.exists(out_path):
			print("[AudioPlaceholders] Skip (exists): ", out_path)
			continue
		var wav: AudioStreamWAV = _synthesize(tones[stem])
		var err := ResourceSaver.save(wav, out_path)
		if err == OK:
			written += 1
			print("[AudioPlaceholders] Wrote: ", out_path)
		else:
			push_error("[AudioPlaceholders] Failed %s err=%s" % [out_path, err])
	print("[AudioPlaceholders] %s -> %d new file(s)" % [out_dir, written])


func _synthesize(def: Dictionary) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = maxf(0.03, float(def.get("duration", 0.1)))
	var base_hz: float = float(def.get("hz", 440.0))
	var slide_hz: float = float(def.get("slide_hz", 0.0))
	var volume: float = clampf(float(def.get("volume", 0.3)), 0.01, 1.0)
	var wave: String = String(def.get("wave", "sine"))
	var sample_count: int = maxi(1, int(sample_rate * duration))
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for i in sample_count:
		var t: float = float(i) / float(sample_rate)
		var progress: float = float(i) / float(maxi(1, sample_count - 1))
		var hz: float = base_hz + slide_hz * progress
		var envelope: float = (1.0 - progress) * (1.0 - progress * 0.35)
		var phase: float = TAU * hz * t
		var sample: float = 0.0
		match wave:
			"square":
				sample = 1.0 if fmod(phase, TAU) < PI else -1.0
			"triangle":
				var p := fmod(phase, TAU) / TAU
				sample = 4.0 * abs(p - 0.5) - 1.0
			_:
				sample = sin(phase)
		sample *= envelope * volume
		var s16: int = int(clampf(sample * 32767.0, -32768.0, 32767.0))
		data[i * 2] = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	return wav
