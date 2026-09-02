extends Node
## Single source of truth for whether AI-powered villager dialogue is on.
##
## The game ships WITHOUT the language model. Everything except NPC conversation and battle
## narration works identically either way, so this manager only ever answers three questions:
##   1. Can AI villagers run right now?            -> is_available()
##   2. Should we offer the player the download?   -> should_show_offer()
##   3. What did the player already decide?        -> has_choice_been_made() / is_enabled_by_player()
##
## Editor vs exported build is checked FIRST everywhere it matters. In the editor the model is read
## from res://models/ exactly as it always has been, the offer screen never appears, and the
## downloader never runs — development is completely unaffected by any of this.

## Shared with LocaleManager / SoundManager / InputManager / SettingsMenu. Reading and re-saving
## through ConfigFile preserves every other section, so writing here cannot clobber their keys.
const SETTINGS_PATH := "user://settings.cfg"
const SECTION := "ai"
## True once the player has answered the offer screen, whichever way they answered. Prevents nagging.
const KEY_CHOICE_MADE := "choice_made"
## The player's preference. Distinct from "is the model on disk" — someone may own the model but
## switch villagers off for performance, and that choice has to survive restarts.
const KEY_ENABLED := "enabled"

## Number of "this villager cannot speak" narration variants in strings.csv
## (ai.npc.silent.1 ... ai.npc.silent.N). Picked at random so repeat visits are not identical.
const SILENT_LINE_COUNT := 4
## Same idea for the skipped battle narration (ai.battle.silent.1 ... N).
const SILENT_BATTLE_LINE_COUNT := 2

# =============================================================================
#  TEMPORARY — SET BACK TO false BEFORE ANY EXPORT
# =============================================================================
# Added 2026-08-20 so the AI offer screen can be reviewed in the editor without exporting.
# While true, the offer screen is forced to appear on every cold start EVEN THOUGH the editor is
# running and the model is present, and the player's answer is deliberately NOT written to
# settings.cfg. That second part matters: without it, clicking "Skip for Now" once would store
# enabled=false and silently switch villager dialogue off for every other editor test afterwards.
#
# Flip to false to restore real behaviour (editor never shows the offer).
# See docs/AI_VILLAGERS_TEST_CHECKLIST.md.
const _PREVIEW_OFFER_IN_EDITOR := false

## Fires while the model is downloading, so a progress indicator can follow it.
signal download_progress(downloaded_bytes: int, total_bytes: int)
## success=false carries a short machine-readable reason (see AiModelDownloader).
signal download_finished(success: bool, reason: String)

## Fires once the model has finished loading and villagers can actually talk. Mid-session, this
## is the moment the game changes from "silent villagers" to "living villagers".
signal villagers_awakened

const _DOWNLOADER_SCRIPT := preload("res://autoload/AiModelDownloader.gd")
const _CHIP_SCRIPT := preload("res://ui/AiVillagersChip.gd")

var _rng := RandomNumberGenerator.new()
var _downloader: Node = null
var _chip: CanvasLayer = null
## Mirrors the chip's current mode so it is only told about genuine changes. Calling its
## show_* methods every frame would reset the download-rate samples continuously and make the
## time estimate useless.
var _chip_mode := ""


func _ready() -> void:
	_rng.randomize()
	# Deferred so LlamaService has finished its own _ready() before we ask it anything.
	_maybe_resume_download.call_deferred()
	_watch_startup_model_load.call_deferred()


## LlamaService artık modeli açılışta ARKA PLANDA yüklüyor (bkz. LlamaService._Ready).
## Yükleme bitene kadar oyun tamamen oynanabilir, sadece AI köylüler cevap veremez; bu
## süre boyunca chip'i "loading" yapıp bitişini dinliyoruz ki oyuncu neden konuşamadığını
## anlasın. Eskiden yükleme ana iş parçacığındaydı ve oyun zaten açılmıyordu, o yüzden
## böyle bir geri bildirime gerek yoktu.
func _watch_startup_model_load() -> void:
	if not is_model_present():
		return
	var service := _llama()
	if service == null:
		return
	if bool(_llama_call("IsInitialized", false)):
		return
	if not service.is_connected("ModelLoadComplete", _on_model_load_complete):
		service.connect("ModelLoadComplete", _on_model_load_complete)
	_set_chip_mode("loading")


## Picks an interrupted download back up on the next launch. Conditions are deliberately strict:
## exported build only, the player already said yes, and the model is still missing. A part-file
## is not required — someone who accepted the offer and quit before any bytes arrived should
## still get their download.
func _maybe_resume_download() -> void:
	if is_editor():
		return
	if not has_choice_been_made():
		return
	if not is_enabled_by_player():
		return
	if is_model_present():
		return
	request_download()


## Starts or resumes the model download. Called by the offer screen and by Settings.
## Does nothing in the editor: development must never pull 7.5 GB.
func request_download() -> void:
	var testing := bool(_DOWNLOADER_SCRIPT.TEST_MODE)

	if is_editor() and not testing:
		print("[AiVillagers] Editor build — download request ignored by design.")
		return
	if is_model_present() and not testing:
		return

	var target := ""
	if testing:
		# Test downloads land in user:// under their own name, never in the models folder and
		# never as a .gguf — a finished test must not leave anything LlamaService would load.
		target = ProjectSettings.globalize_path("user://").path_join(
			str(_DOWNLOADER_SCRIPT.TEST_FILE_NAME)
		)
		print("[AiVillagers] TEST MODE: downloading a small sample file to %s" % target)
	else:
		target = get_model_file_path()
	if target == "":
		push_error("[AiVillagers] Cannot download: model path unavailable (LlamaService missing?).")
		return

	_ensure_downloader()
	if _downloader.call("is_running"):
		return

	if testing and FileAccess.file_exists(target):
		# Each test run should exercise the real thing. Without this, a leftover file from a
		# previous run makes start() report "already present" and nothing is actually tested.
		DirAccess.remove_absolute(target)

	# Chip state is set BEFORE start() on purpose. start() can complete synchronously (the file
	# is already on disk, or it fails immediately), which emits download_finished right here —
	# and that handler sets the final chip state. Setting "downloading" afterwards would stomp
	# on it and leave the chip stuck showing a download that already ended.
	_set_chip_mode("downloading")
	set_process(true)
	_downloader.call("start", target)


func pause_download() -> void:
	if _downloader != null:
		_downloader.call("pause")


## Discards partial bytes as well as stopping. For an explicit player cancel, not for errors.
func cancel_download() -> void:
	if _downloader != null:
		_downloader.call("cancel")


func is_downloading() -> bool:
	return _downloader != null and bool(_downloader.call("is_running"))


## 0.0 - 1.0.
func get_download_progress() -> float:
	if _downloader == null:
		return 0.0
	return float(_downloader.call("get_progress"))


func get_downloaded_bytes() -> int:
	if _downloader == null:
		return 0
	return int(_downloader.call("get_downloaded_bytes"))


func get_total_bytes() -> int:
	if _downloader == null:
		return _DOWNLOADER_SCRIPT.EXPECTED_TOTAL_BYTES
	return int(_downloader.call("get_total_bytes"))


func _ensure_downloader() -> void:
	if _downloader != null and is_instance_valid(_downloader):
		return
	_downloader = Node.new()
	_downloader.set_script(_DOWNLOADER_SCRIPT)
	_downloader.name = "AiModelDownloader"
	add_child(_downloader)
	_downloader.connect("progress_changed", _on_download_progress)
	_downloader.connect("download_finished", _on_download_finished)


func _on_download_progress(downloaded_bytes: int, total_bytes: int) -> void:
	download_progress.emit(downloaded_bytes, total_bytes)


func _on_download_finished(success: bool, reason: String) -> void:
	set_process(false)
	if success:
		print("[AiVillagers] Model download complete (%s). Loading model..." % reason)
		_set_chip_mode("loading")
		_begin_model_load()
	else:
		push_warning("[AiVillagers] Model download stopped: %s" % reason)
		_set_chip_mode("failed")
	download_finished.emit(success, reason)


## Loads the freshly downloaded model without a restart. The load itself happens on a worker
## thread inside LlamaService (see InitializeAsync) because reading ~7 GB and pushing it to the
## GPU on the main thread would freeze the game for tens of seconds.
func _begin_model_load() -> void:
	if bool(_DOWNLOADER_SCRIPT.TEST_MODE):
		# The test file is not a model; loading it would fail noisily and prove nothing.
		print("[AiVillagers] TEST MODE: download verified. Skipping model load.")
		_set_chip_mode("ready")
		return
	var service := _llama()
	if service == null or not service.has_method("InitializeAsync"):
		push_warning("[AiVillagers] LlamaService cannot load on demand; a restart will be needed.")
		_set_chip_mode("failed")
		return
	if not service.is_connected("ModelLoadComplete", _on_model_load_complete):
		service.connect("ModelLoadComplete", _on_model_load_complete)
	service.call("InitializeAsync")


func _on_model_load_complete(success: bool) -> void:
	if success:
		print("[AiVillagers] Model loaded. Villagers can speak.")
		_set_chip_mode("ready")
		villagers_awakened.emit()
	else:
		push_error("[AiVillagers] Model failed to load after download.")
		_set_chip_mode("failed")


# --- progress chip ---

## Created lazily and only when there is something to show, so the editor and no-AI sessions
## never carry an extra CanvasLayer around.
func _ensure_chip() -> void:
	if _chip != null and is_instance_valid(_chip):
		return
	_chip = CanvasLayer.new()
	_chip.set_script(_CHIP_SCRIPT)
	_chip.name = "AiVillagersChip"
	add_child(_chip)


func _set_chip_mode(mode: String) -> void:
	if mode == _chip_mode:
		return
	_chip_mode = mode
	if mode == "":
		if _chip != null and is_instance_valid(_chip):
			_chip.call("hide_chip")
		return
	_ensure_chip()
	match mode:
		"downloading":
			_chip.call("show_downloading")
		"verifying":
			_chip.call("show_verifying")
		"loading":
			_chip.call("show_loading")
		"ready":
			_chip.call("show_ready")
		"failed":
			_chip.call("show_failed")


## Polls the downloader so the chip can switch between downloading and verifying. The downloader
## does not signal that transition, and polling one boolean per frame is cheaper than threading a
## signal through for it.
func _process(_delta: float) -> void:
	if _downloader == null or not is_instance_valid(_downloader):
		set_process(false)
		return
	if bool(_downloader.call("is_verifying")):
		_set_chip_mode("verifying")
	elif bool(_downloader.call("is_running")):
		_set_chip_mode("downloading")
	else:
		# Nothing is in flight any more. Stop polling and leave the chip alone: whichever
		# terminal state _on_download_finished set is the correct one, and overwriting it here
		# is exactly what previously left the chip frozen at 0 bytes.
		set_process(false)


## True while the freshly downloaded model is being loaded into memory.
func is_loading_model() -> bool:
	return _chip_mode == "loading"


## Turns AI villagers on or off from Settings.
##
## Turning ON does the right thing for whichever state the machine is in: start downloading if
## the model is missing, or load it on demand if it is already on disk but not in memory.
## Turning OFF stops any transfer and cleans up after it.
func set_enabled(enabled: bool) -> void:
	set_player_choice(enabled)
	if not enabled:
		return
	if not is_model_present():
		request_download()
		return
	if not bool(_llama_call("IsInitialized", false)):
		_set_chip_mode("loading")
		_begin_model_load()


## Deletes the downloaded model and any partial transfer, freeing the disk space.
##
## Also switches the preference off. Without that, the auto-resume on the next launch would see
## "enabled, model missing" and immediately start re-downloading the 7.5 GB the player just
## deliberately deleted.
func delete_model() -> void:
	if _downloader != null and is_instance_valid(_downloader):
		_downloader.call("cancel")
	set_process(false)
	_set_chip_mode("")

	var path := get_model_file_path()
	if path != "" and FileAccess.file_exists(path):
		var err := DirAccess.remove_absolute(path)
		if err != OK:
			push_error("[AiVillagers] Could not delete %s (error %d)" % [path, err])
		else:
			print("[AiVillagers] Deleted model file.")
	set_player_choice(false)


## 0.0 - 1.0 through the post-download hash check.
func get_verify_progress() -> float:
	if _downloader == null:
		return 0.0
	return float(_downloader.call("get_verify_progress"))


## LlamaService is a C# autoload. It is fetched by node path rather than referenced as a global
## identifier so this script still parses standalone under `--check-only` (a bare `LlamaService`
## reference reports "Identifier not found" there, which masks any real errors behind it), and so a
## missing or renamed autoload degrades to "AI unavailable" instead of crashing.
func _llama() -> Node:
	return get_node_or_null("/root/LlamaService")


## Calls a LlamaService method if the service and that method both exist, else returns `fallback`.
func _llama_call(method: String, fallback: Variant) -> Variant:
	var service := _llama()
	if service == null or not service.has_method(method):
		return fallback
	return service.call(method)


## True when running from the Godot editor rather than an exported build. Every download and
## offer-screen path is gated on this being false.
func is_editor() -> bool:
	return OS.has_feature("editor")


## Whether the GGUF is on disk. Cheap file check, does not attempt to load the model.
## Delegates to LlamaService so the path logic lives in exactly one place.
func is_model_present() -> bool:
	return bool(_llama_call("HasModelFile", false))


## Absolute path the model is expected at. This is the download target in exported builds.
func get_model_file_path() -> String:
	return str(_llama_call("ModelFilePath", ""))


## Absolute directory the model belongs in.
func get_model_directory() -> String:
	return str(_llama_call("ModelDirectory", ""))


## The real runtime truth: the model actually loaded and inference can run. Callers that are about
## to generate dialogue should use this rather than is_model_present(), because a file can exist on
## disk and still fail to load (corrupt download, out of VRAM).
func is_available() -> bool:
	if not bool(_llama_call("IsInitialized", false)):
		return false
	# A player who owns the model but switched villagers off must stay switched off.
	return is_enabled_by_player()


## The player's stored preference. Defaults to true so that simply having the model present is
## enough to get talking villagers — the "off" state has to be chosen deliberately.
func is_enabled_by_player() -> bool:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return true
	return bool(config.get_value(SECTION, KEY_ENABLED, true))


## True once the player has answered the offer screen either way.
func has_choice_been_made() -> bool:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return false
	return bool(config.get_value(SECTION, KEY_CHOICE_MADE, false))


## Records the player's answer. Loading before saving keeps every other system's settings intact.
func set_player_choice(enabled: bool) -> void:
	# Editor preview must never write anything: storing enabled=false here would switch villager
	# dialogue off for every later editor session, which looks exactly like a bug.
	if is_editor_preview():
		print("[AiVillagers] Editor preview: choice NOT saved (would have been enabled=%s)." % enabled)
		return
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)  # Missing file is fine; we are about to create it.
	config.set_value(SECTION, KEY_CHOICE_MADE, true)
	config.set_value(SECTION, KEY_ENABLED, enabled)
	var err := config.save(SETTINGS_PATH)
	if err != OK:
		push_error("[AiVillagers] Could not save AI preference to %s (error %d)" % [SETTINGS_PATH, err])

	# Switching AI villagers off must not leave a multi-GB half-finished file sitting in AppData
	# forever. Stop the transfer and clean up after it.
	if not enabled and _downloader != null and is_instance_valid(_downloader):
		_downloader.call("cancel")
		set_process(false)
		_set_chip_mode("")


## Whether to show the one-time offer screen.
##
## Never in the editor. Never when the model is already on disk — someone who placed a 7.5 GB file
## themselves does not need to be asked what it is. Never once the player has already answered.
func should_show_offer() -> bool:
	if is_editor_preview():
		return true
	if is_editor():
		return false
	if is_model_present():
		return false
	return not has_choice_been_made()


## True only while the temporary editor preview of the offer screen is switched on.
## Real builds can never enter this state: it requires both the const above and running in-editor.
func is_editor_preview() -> bool:
	return _PREVIEW_OFFER_IN_EDITOR and is_editor()


## A random "this villager cannot speak" narration line, already translated.
## Returned WITHOUT a speaker prefix: the villager is not talking, this is narration about them.
func get_silent_villager_line(npc_name: String) -> String:
	var index := _rng.randi_range(1, SILENT_LINE_COUNT)
	var line := tr("ai.npc.silent.%d" % index)
	return line.replace("{name}", npc_name)


## A random replacement for the battle chronicle that the model would have written.
func get_silent_battle_line() -> String:
	var index := _rng.randi_range(1, SILENT_BATTLE_LINE_COUNT)
	return tr("ai.battle.silent.%d" % index)
