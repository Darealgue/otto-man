extends Node
## Background download of the language model. Never blocks gameplay.
##
## Uses HTTPClient rather than HTTPRequest on purpose: HTTPRequest's download_file always
## truncates the target, so a 7.5 GB transfer could never resume after a quit or a dropped
## connection. HTTPClient lets us send a Range header and append, which is the whole point.
##
## Bytes land in "<model>.gguf.part" and the file is renamed to its real name only after the
## byte count matches exactly. A half-finished file can therefore never be mistaken for a
## working model by LlamaService, which only ever looks for the final name.

## Emitted every frame that bytes arrive. total_bytes is 0 until the server reports a length.
signal progress_changed(downloaded_bytes: int, total_bytes: int)
## success=false carries a short reason for the UI. Fires exactly once per download attempt.
signal download_finished(success: bool, reason: String)

const MODEL_HOST := "huggingface.co"
## Pinned to an immutable commit rather than /resolve/main/. The repo is a third party's; if they
## ever re-quantize and replace the file, "main" would silently start serving DIFFERENT weights,
## and every prompt and grammar in this game is tuned to these exact weights. A commit SHA cannot
## change under us. Repo: bartowski/Mistral-Nemo-Instruct-2407-GGUF, commit dated 2024-11-05.
const MODEL_PATH := "/bartowski/Mistral-Nemo-Instruct-2407-GGUF/resolve/a2dd64a0a76ea1bdb2bb6ab6fa5496b003c7c908/Mistral-Nemo-Instruct-2407-Q4_K_M.gguf"
## The exact size of the known-good model. Confirmed three ways: the local working copy, the
## server's Content-Length on /main, and the server's Content-Length on the pinned commit.
## ENFORCED, not advisory — see _read_total_length(). If the server ever reports a different
## length, the download is refused rather than quietly installing weights we did not tune for.
const EXPECTED_TOTAL_BYTES := 7477208192
## SHA-256 of the exact weights this game was tuned against. Confirmed independently three ways:
## hashing the known-good local dev copy, Hugging Face's published lfs.oid for the pinned commit,
## and the pinned commit's Content-Length. Verified after every download; a mismatch means the
## bytes are not this model (tampering, a bad mirror, silent corruption) and the file is deleted
## rather than handed to llama.cpp.
## NOTE: this is NOT the ETag. HF serves this repo from Xet storage, whose ETag is a different
## content hash (xetHash) entirely — do not "fix" this constant to the ETag value.
const EXPECTED_SHA256 := "7c1a10d202d8788dbe5628dc962254d10654c853cae6aaeca0618f05490d4a46"
## Bytes hashed per frame during verification. Same reasoning as MAX_BYTES_PER_FRAME: a single
## blocking pass over 7.5 GB would freeze the game for the better part of a minute.
const VERIFY_BYTES_PER_FRAME := 8 * 1024 * 1024

# =============================================================================
#  TEMPORARY TEST MODE — SET TO false BEFORE ANY EXPORT
# =============================================================================
# Downloads a small real file from the SAME repository instead of the model, so the whole
# mechanism (TLS connect, Hugging Face's 302 to its CDN, ranged resume, .part handling, hash
# verification, rename) can be proven in the editor without pulling 7.5 GB.
#
# Deliberately throttled: the test file is only 6.7 MB and would finish in well under a second
# on a decent connection, which shows nothing. The throttle stretches it to roughly five
# seconds so the progress chip is actually observable.
#
# The test file is saved under its own name and is NEVER renamed to the model's filename, so a
# successful test cannot leave something behind that LlamaService would try to load.
const TEST_MODE := false
const TEST_PATH := "/bartowski/Mistral-Nemo-Instruct-2407-GGUF/resolve/a2dd64a0a76ea1bdb2bb6ab6fa5496b003c7c908/Mistral-Nemo-Instruct-2407.imatrix"
const TEST_TOTAL_BYTES := 7054418
const TEST_SHA256 := "e4a024a3550a134fa76de0b4f55296f79f35719b00c71fbe1416f8c2df7328ef"
## 6.7 MB split across ~5 seconds at 60 fps.
const TEST_BYTES_PER_FRAME := 24000
## Filename the test writes to. Not a .gguf on purpose.
const TEST_FILE_NAME := "__download_test.bin"
## At the normal 8 MB/frame the 6.7 MB test file hashes in a single frame, so the verification
## step flashes past invisibly. Throttled here purely so that stage can actually be observed.
## The real model takes roughly 15 seconds to hash and needs no such help.
const TEST_VERIFY_BYTES_PER_FRAME := 60000
## The real flush interval is 16 MB, which the 6.7 MB test file would never reach — meaning no
## .meta sidecar would ever be written and the unclean-exit resume path would go untested.
## Small enough here that several flushes happen across the ~5 second test run.
const TEST_FLUSH_INTERVAL_BYTES := 1024 * 1024


## The request path in use. Test mode swaps in a small file from the same repo.
static func active_path() -> String:
	return TEST_PATH if TEST_MODE else MODEL_PATH


## The exact expected byte count for whichever file is being fetched.
static func active_total_bytes() -> int:
	return TEST_TOTAL_BYTES if TEST_MODE else EXPECTED_TOTAL_BYTES


## The expected SHA-256 for whichever file is being fetched.
static func active_sha256() -> String:
	return TEST_SHA256 if TEST_MODE else EXPECTED_SHA256


static func active_bytes_per_frame() -> int:
	return TEST_BYTES_PER_FRAME if TEST_MODE else MAX_BYTES_PER_FRAME


static func active_verify_bytes_per_frame() -> int:
	return TEST_VERIFY_BYTES_PER_FRAME if TEST_MODE else VERIFY_BYTES_PER_FRAME


static func active_flush_interval() -> int:
	return TEST_FLUSH_INTERVAL_BYTES if TEST_MODE else FLUSH_INTERVAL_BYTES
## huggingface.co 302s to a CDN host, and that CDN may redirect again.
const MAX_REDIRECTS := 5
## Ceiling on bytes appended per frame. Without this, a fast connection would let one frame
## drain a huge buffer and visibly hitch the game.
const MAX_BYTES_PER_FRAME := 4 * 1024 * 1024
## Flush this often so an unexpected quit costs seconds of progress, not the whole transfer.
const FLUSH_INTERVAL_BYTES := 16 * 1024 * 1024

enum State { IDLE, CONNECTING, REQUESTING, DOWNLOADING, VERIFYING, FAILED, DONE }

var _state: int = State.IDLE
var _http: HTTPClient = null
var _file: FileAccess = null
var _host := ""
var _path := ""
var _port := 443
var _use_tls := true
var _redirects := 0
var _downloaded := 0
var _total := 0
var _resume_offset := 0
var _bytes_since_flush := 0
var _part_path := ""
var _final_path := ""
var _paused := false
## Verification pass state. The hash is computed in slices across frames rather than in one
## blocking call, so the game keeps running while a 7.5 GB file is checked.
var _hasher: HashingContext = null
var _verify_file: FileAccess = null
var _verify_read := 0
var _verify_total := 0


func _ready() -> void:
	set_process(false)


func is_running() -> bool:
	return (
		_state == State.CONNECTING
		or _state == State.REQUESTING
		or _state == State.DOWNLOADING
		or _state == State.VERIFYING
	)


## True while the finished file is being hash-checked. Worth showing in the UI: it happens after
## the bar reaches 100% and takes a noticeable moment on a file this size.
func is_verifying() -> bool:
	return _state == State.VERIFYING


## 0.0 - 1.0 through the verification pass.
func get_verify_progress() -> float:
	if _verify_total <= 0:
		return 0.0
	return clampf(float(_verify_read) / float(_verify_total), 0.0, 1.0)


func is_paused() -> bool:
	return _paused


func get_downloaded_bytes() -> int:
	return _downloaded


func get_total_bytes() -> int:
	return _total if _total > 0 else active_total_bytes()


## 0.0 - 1.0. Falls back to the known file size before the server reports one, so the bar never
## sits at zero while connecting.
func get_progress() -> float:
	var total := get_total_bytes()
	if total <= 0:
		return 0.0
	return clampf(float(_downloaded) / float(total), 0.0, 1.0)


## Begins (or resumes) the download. Safe to call when already running — it does nothing.
func start(final_path: String) -> void:
	if is_running():
		return
	if final_path.strip_edges() == "":
		_fail("no_target_path")
		return

	_final_path = final_path
	_part_path = final_path + ".part"
	_paused = false
	_redirects = 0
	_bytes_since_flush = 0
	_total = 0

	var dir := _final_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		var mk := DirAccess.make_dir_recursive_absolute(dir)
		if mk != OK:
			_fail("cannot_create_folder")
			return

	# Someone may have dropped the finished file in manually while we were idle.
	if FileAccess.file_exists(_final_path):
		_state = State.DONE
		download_finished.emit(true, "already_present")
		return

	_resume_offset = _safe_resume_offset()
	_downloaded = _resume_offset

	_host = MODEL_HOST
	_path = active_path()
	_port = 443
	_use_tls = true
	_begin_connection()


## Works out how many bytes of the existing .part file can be trusted.
##
## Answers the alt-F4 question directly. If the process is killed mid-write the tail of .part can
## be a torn, partially-written buffer, and resuming from its raw length would splice that damage
## permanently into the file. So every flush also records the flushed byte count in a tiny
## sidecar, and on resume the .part is truncated back to that known-good boundary. At worst the
## player loses the seconds of data since the last flush, never the whole download.
##
## The SHA-256 check still runs at the end regardless — this just makes it far less likely to
## fail and force a 7.5 GB re-download.
func _safe_resume_offset() -> int:
	if not FileAccess.file_exists(_part_path):
		_delete_meta()
		return 0

	var probe := FileAccess.open(_part_path, FileAccess.READ)
	if probe == null:
		return 0
	var on_disk := int(probe.get_length())
	probe.close()

	var flushed := _read_meta()
	if flushed <= 0:
		# No sidecar (older partial file, or the meta write itself failed). Trust the file and
		# let the hash check be the safety net.
		return on_disk
	if flushed >= on_disk:
		return on_disk

	# Trim the unflushed tail.
	var trim := FileAccess.open(_part_path, FileAccess.READ_WRITE)
	if trim == null:
		return on_disk
	trim.resize(flushed)
	trim.close()
	print("[AiModelDownloader] Trimmed %d unflushed byte(s) after an unclean exit." % (on_disk - flushed))
	return flushed


func _meta_path() -> String:
	return _part_path + ".meta"


func _read_meta() -> int:
	var path := _meta_path()
	if _part_path == "" or not FileAccess.file_exists(path):
		return 0
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return 0
	var text := f.get_as_text().strip_edges()
	f.close()
	if not text.is_valid_int():
		return 0
	return int(text)


func _write_meta(bytes: int) -> void:
	if _part_path == "":
		return
	var f := FileAccess.open(_meta_path(), FileAccess.WRITE)
	if f == null:
		return
	f.store_string(str(bytes))
	f.flush()
	f.close()


func _delete_meta() -> void:
	if _part_path == "":
		return
	var path := _meta_path()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


## Removes the partial download and its sidecar. Used on cancel, on verification failure, and
## when the player switches AI villagers off — no orphaned multi-GB files left behind.
func discard_partial() -> void:
	if _part_path != "" and FileAccess.file_exists(_part_path):
		DirAccess.remove_absolute(_part_path)
	_delete_meta()
	_downloaded = 0


## Stops without deleting anything, so start() later picks up where this left off.
func pause() -> void:
	if not is_running():
		return
	_paused = true
	_teardown_connection()
	# Flushing and recording the boundary here means a deliberate pause never loses bytes, unlike
	# an unclean exit.
	if _file != null:
		_file.flush()
		_write_meta(_downloaded)
	_close_file()
	_state = State.IDLE
	set_process(false)


## Stops AND discards partial bytes. Use for an explicit player cancel, not for errors.
func cancel() -> void:
	_teardown_connection()
	_close_file()
	_close_verify()
	_state = State.IDLE
	_paused = false
	set_process(false)
	discard_partial()


func _begin_connection() -> void:
	_teardown_connection()
	_http = HTTPClient.new()
	var tls := TLSOptions.client() if _use_tls else null
	var err := _http.connect_to_host(_host, _port, tls)
	if err != OK:
		_fail("cannot_reach_server")
		return
	_state = State.CONNECTING
	set_process(true)


func _process(_delta: float) -> void:
	# Verification happens after the connection is already torn down, so it must run before the
	# _http null-check below rather than being gated behind it.
	if _state == State.VERIFYING:
		_tick_verifying()
		return

	if _http == null:
		set_process(false)
		return

	var poll_err := _http.poll()
	if poll_err != OK and _state != State.DOWNLOADING:
		_fail("connection_lost")
		return

	match _state:
		State.CONNECTING:
			_tick_connecting()
		State.REQUESTING:
			_tick_requesting()
		State.DOWNLOADING:
			_tick_downloading()


func _tick_connecting() -> void:
	var status := _http.get_status()
	if status == HTTPClient.STATUS_RESOLVING or status == HTTPClient.STATUS_CONNECTING:
		return
	if status != HTTPClient.STATUS_CONNECTED:
		_fail("cannot_reach_server")
		return

	var headers := PackedStringArray([
		"User-Agent: RogueHarem/1.0 (Godot)",
		"Accept: */*",
	])
	# Resume exactly where the .part file stopped. The server advertises Accept-Ranges: bytes,
	# so this comes back as 206 Partial Content rather than a fresh 200.
	if _resume_offset > 0:
		headers.append("Range: bytes=%d-" % _resume_offset)

	var err := _http.request(HTTPClient.METHOD_GET, _path, headers)
	if err != OK:
		_fail("request_failed")
		return
	_state = State.REQUESTING


func _tick_requesting() -> void:
	var status := _http.get_status()
	if status == HTTPClient.STATUS_REQUESTING:
		return
	if not _http.has_response():
		_fail("no_response")
		return

	var code := _http.get_response_code()
	var response_headers := _http.get_response_headers_as_dictionary()

	# Hugging Face 302s to its CDN; follow it by hand since HTTPClient does not.
	if code in [301, 302, 303, 307, 308]:
		_follow_redirect(response_headers)
		return

	# 416 means our .part is already >= the full length: treat it as a finished body and let
	# the size check below decide whether it is genuinely complete or corrupt.
	if code == 416:
		_close_file()
		_finalize()
		return

	if code != 200 and code != 206:
		_fail("http_%d" % code)
		return

	# A 200 to a ranged request means the server ignored the Range and is sending the whole
	# file, so the existing partial bytes are worthless and must not be appended to.
	if code == 200 and _resume_offset > 0:
		_resume_offset = 0
		_downloaded = 0
		if FileAccess.file_exists(_part_path):
			DirAccess.remove_absolute(_part_path)

	_total = _read_total_length(response_headers, code)

	# Fail closed on an unexpected size. Reaching here means the pinned commit URL returned
	# something other than the model we tuned against — a moved/replaced file, or an error page
	# served with a 200. Installing it would be worse than not having AI villagers at all.
	if _total > 0 and _total != active_total_bytes():
		push_error(
			"[AiModelDownloader] Server reported %d bytes, expected %d. Refusing to download."
			% [_total, active_total_bytes()]
		)
		discard_partial()
		_fail("unexpected_file")
		return

	if not _open_part_file():
		return

	_state = State.DOWNLOADING
	progress_changed.emit(_downloaded, get_total_bytes())


## Content-Length is the REMAINING bytes on a 206, not the file size, so the resume offset has
## to be added back to get a total the progress bar can use.
func _read_total_length(response_headers: Dictionary, code: int) -> int:
	var length := 0
	for key in response_headers.keys():
		if str(key).to_lower() == "content-length":
			length = int(str(response_headers[key]))
			break
	if length <= 0:
		return 0
	if code == 206:
		return _resume_offset + length
	return length


func _follow_redirect(response_headers: Dictionary) -> void:
	_redirects += 1
	if _redirects > MAX_REDIRECTS:
		_fail("too_many_redirects")
		return
	var location := ""
	for key in response_headers.keys():
		if str(key).to_lower() == "location":
			location = str(response_headers[key])
			break
	if location.strip_edges() == "":
		_fail("bad_redirect")
		return
	if not _apply_url(location):
		_fail("bad_redirect")
		return
	_begin_connection()


## Splits an absolute URL into host/port/path. Relative Locations keep the current host.
func _apply_url(url: String) -> bool:
	url = url.strip_edges()
	if url.begins_with("/"):
		_path = url
		return true

	var scheme_end := url.find("://")
	if scheme_end < 0:
		return false
	var scheme := url.substr(0, scheme_end).to_lower()
	if scheme != "http" and scheme != "https":
		return false
	_use_tls = scheme == "https"

	var rest := url.substr(scheme_end + 3)
	var slash := rest.find("/")
	var authority := rest if slash < 0 else rest.substr(0, slash)
	_path = "/" if slash < 0 else rest.substr(slash)

	var colon := authority.rfind(":")
	if colon > 0:
		_host = authority.substr(0, colon)
		_port = int(authority.substr(colon + 1))
	else:
		_host = authority
		_port = 443 if _use_tls else 80
	return _host != ""


func _open_part_file() -> bool:
	_close_file()
	if _resume_offset > 0 and FileAccess.file_exists(_part_path):
		_file = FileAccess.open(_part_path, FileAccess.READ_WRITE)
		if _file == null:
			_fail("cannot_write_file")
			return false
		_file.seek_end()
	else:
		_file = FileAccess.open(_part_path, FileAccess.WRITE)
		if _file == null:
			_fail("cannot_write_file")
			return false
	return true


func _tick_downloading() -> void:
	var status := _http.get_status()
	var pulled := 0

	var frame_budget := active_bytes_per_frame()
	while pulled < frame_budget:
		if _http.get_status() != HTTPClient.STATUS_BODY:
			break
		_http.poll()
		var chunk := _http.read_response_body_chunk()
		if chunk.size() == 0:
			break
		_file.store_buffer(chunk)
		pulled += chunk.size()
		_downloaded += chunk.size()
		_bytes_since_flush += chunk.size()

	if _bytes_since_flush >= active_flush_interval():
		_file.flush()
		_bytes_since_flush = 0
		# Record the boundary only AFTER the flush, so the sidecar can never claim more bytes
		# are safely on disk than actually are.
		_write_meta(_downloaded)

	if pulled > 0:
		progress_changed.emit(_downloaded, get_total_bytes())

	status = _http.get_status()
	if status == HTTPClient.STATUS_BODY:
		return
	if status == HTTPClient.STATUS_CONNECTED or status == HTTPClient.STATUS_DISCONNECTED:
		_close_file()
		_finalize()
		return
	# Any other status here means the connection died mid-body. The .part file is kept so the
	# next start() resumes instead of restarting.
	_close_file()
	_fail("connection_lost")


## Renames .part to the real filename only when the byte count is exactly right. Truncation is
## the realistic corruption mode for an interrupted HTTP transfer, and an exact-size check
## catches it; llama.cpp's own load then acts as the structural check on top of that.
func _finalize() -> void:
	_teardown_connection()
	set_process(false)

	if not FileAccess.file_exists(_part_path):
		_fail("file_missing_after_download")
		return

	var probe := FileAccess.open(_part_path, FileAccess.READ)
	if probe == null:
		_fail("cannot_verify_file")
		return
	var actual := int(probe.get_length())
	probe.close()

	var expected := get_total_bytes()
	if actual != expected:
		# Short file: keep it and let the next attempt resume from here.
		if actual < expected:
			_state = State.IDLE
			download_finished.emit(false, "incomplete")
			return
		# Longer than expected means the .part is genuinely wrong, not resumable.
		DirAccess.remove_absolute(_part_path)
		_downloaded = 0
		_fail("size_mismatch")
		return

	_begin_verification()


## Hashes the completed .part before it is allowed to become the real model file.
##
## Size alone only proves the transfer was not truncated. This proves the bytes are the exact
## weights the game was tuned against — the defence against a tampered file, a bad mirror, or
## silent disk corruption. Done in slices across frames; a blocking pass over 7.5 GB would freeze
## the game for close to a minute.
func _begin_verification() -> void:
	_verify_file = FileAccess.open(_part_path, FileAccess.READ)
	if _verify_file == null:
		_fail("cannot_verify_file")
		return
	_hasher = HashingContext.new()
	if _hasher.start(HashingContext.HASH_SHA256) != OK:
		_close_verify()
		_fail("cannot_verify_file")
		return
	_verify_total = int(_verify_file.get_length())
	_verify_read = 0
	_state = State.VERIFYING
	set_process(true)


func _tick_verifying() -> void:
	if _verify_file == null or _hasher == null:
		_fail("cannot_verify_file")
		return

	var budget := active_verify_bytes_per_frame()
	while budget > 0 and _verify_read < _verify_total:
		var want: int = mini(budget, _verify_total - _verify_read)
		var buf := _verify_file.get_buffer(want)
		if buf.size() == 0:
			break
		if _hasher.update(buf) != OK:
			_close_verify()
			_fail("cannot_verify_file")
			return
		_verify_read += buf.size()
		budget -= buf.size()

	if _verify_read < _verify_total:
		return

	var digest := _hasher.finish().hex_encode().to_lower()
	_close_verify()
	set_process(false)

	if digest != active_sha256():
		push_error(
			"[AiModelDownloader] SHA-256 mismatch. Got %s, expected %s. Deleting file."
			% [digest, active_sha256()]
		)
		discard_partial()
		_fail("hash_mismatch")
		return

	if FileAccess.file_exists(_final_path):
		DirAccess.remove_absolute(_final_path)
	var err := DirAccess.rename_absolute(_part_path, _final_path)
	if err != OK:
		_fail("cannot_rename_file")
		return

	_delete_meta()
	_state = State.DONE
	download_finished.emit(true, "ok")


func _close_verify() -> void:
	if _verify_file != null:
		_verify_file.close()
		_verify_file = null
	_hasher = null


func _fail(reason: String) -> void:
	_teardown_connection()
	_close_file()
	_close_verify()
	set_process(false)
	_state = State.FAILED
	push_warning("[AiModelDownloader] failed: %s" % reason)
	download_finished.emit(false, reason)


func _teardown_connection() -> void:
	if _http != null:
		_http.close()
		_http = null


func _close_file() -> void:
	if _file != null:
		_file.flush()
		_file.close()
		_file = null
