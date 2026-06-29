@tool
extends EditorScript
## Godot Editor: File → Run → bu script
## `assets/audio/sfx/*.wav` placeholder dosyalarını üretir (sentez tonları).
## Gerçek asset bulunca aynı dosya adına .ogg/.wav koy — SoundManager otomatik alır.

const OUT_DIR := "res://assets/audio/sfx/"

const TONES: Dictionary = {
	"ui_click": {"hz": 920.0, "duration": 0.05, "volume": 0.22, "slide_hz": 0.0, "wave": "sine"},
	"ui_confirm": {"hz": 660.0, "duration": 0.07, "volume": 0.24, "slide_hz": 120.0, "wave": "sine"},
	"ui_cancel": {"hz": 340.0, "duration": 0.08, "volume": 0.2, "slide_hz": -80.0, "wave": "triangle"},
	"player_hurt": {"hz": 220.0, "duration": 0.11, "volume": 0.38, "slide_hz": -140.0, "wave": "triangle"},
	"player_death": {"hz": 130.0, "duration": 0.55, "volume": 0.42, "slide_hz": -90.0, "wave": "sine"},
	"door_open": {"hz": 280.0, "duration": 0.22, "volume": 0.32, "slide_hz": 420.0, "wave": "square"},
	"door_locked": {"hz": 160.0, "duration": 0.08, "volume": 0.28, "slide_hz": -60.0, "wave": "square"},
	"combat_hit_light": {"hz": 400.0, "duration": 0.06, "volume": 0.3, "slide_hz": -200.0, "wave": "square"},
	"combat_block": {"hz": 180.0, "duration": 0.09, "volume": 0.35, "slide_hz": 0.0, "wave": "triangle"},
	"pickup": {"hz": 780.0, "duration": 0.09, "volume": 0.26, "slide_hz": 200.0, "wave": "sine"},
	"build_complete": {"hz": 520.0, "duration": 0.18, "volume": 0.3, "slide_hz": 180.0, "wave": "sine"},
	"footstep_player": {"hz": 95.0, "duration": 0.04, "volume": 0.18, "slide_hz": -40.0, "wave": "triangle"},
	"player_attack_light": {"hz": 540.0, "duration": 0.09, "volume": 0.3, "slide_hz": -220.0, "wave": "triangle"},
	"player_attack_heavy": {"hz": 165.0, "duration": 0.16, "volume": 0.42, "slide_hz": -45.0, "wave": "square"},
}


func _run() -> void:
	var abs_dir := ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(abs_dir)
	var music_dir := ProjectSettings.globalize_path("res://assets/audio/music/")
	DirAccess.make_dir_recursive_absolute(music_dir)
	var written: int = 0
	for stem in TONES.keys():
		var out_path: String = OUT_DIR + stem + ".wav"
		if ResourceLoader.exists(out_path):
			print("[AudioPlaceholders] Skip (exists): ", out_path)
			continue
		var wav: AudioStreamWAV = _synthesize(TONES[stem])
		var err := ResourceSaver.save(wav, out_path)
		if err == OK:
			written += 1
			print("[AudioPlaceholders] Wrote: ", out_path)
		else:
			push_error("[AudioPlaceholders] Failed %s err=%s" % [out_path, err])
	print("[AudioPlaceholders] Done. %d new file(s). Replace with real assets anytime." % written)


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
