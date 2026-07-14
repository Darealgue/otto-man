# NPCDialogueManager.gd
# Central manager for all NPC-LLM interactions
# NPCs just call process_dialogue() with their state data

extends Node

# Signal that NPCs can connect to for responses
signal dialogue_processed(npc_name: String, new_state: Dictionary, generated_dialogue: String, was_significant: bool)

# Track which NPC is currently being processed
var _current_processing_npc: String = ""
var _current_original_state: Dictionary = {}
var _current_player_input: String = ""
## Wall-clock anchor when NPC dialogue calls LlamaService (Time.get_ticks_msec); -1 when unset.
var _npc_llm_req_ticks: int = -1

## Step 1 tuning: lower temperature for NPC JSON + dialogue (quests/summaries keep LlamaService default 0.8).
## Long History + Latest_news + chat tail → large prompts; JSON output must fit (avoid mid-array truncation).
const _NPC_MAX_NEW_TOKENS := 768
const _NPC_TEMPERATURE := 0.55
## Salvaged dialogue shorter than this is usually truncation garbage — fall back to generic line.
const _NPC_SALVAGE_DIALOGUE_MIN_CHARS := 18

## When true, LlamaService loads grammars/output.gbnf for NPC replies (structured JSON). When false, prompt + parser only.
## Constrained decoding off by default: slower per token + sampler instability in some stacks; LoRA + prompt enforce JSON/significance instead.
const _NPC_USE_GRAMMAR := false

## Persisted chat (Chat_log): how many last messages to inject into the prompt (bounded latency).
const _CHAT_LOG_PROMPT_MAX_MESSAGES := 12

## Compact turn transcript for debugging / pasting into chat (no Llama prefill spam).
const _LOG_NPC_DIALOGUE_CHAIN := true

const _NPC_DIALOGUE_THREE_PASS := true
const _NPC_TP_TOKENS_1 := 280
const _NPC_TP_TOKENS_2 := 160
## Tried lowering this to force compression — backfired: the model kept trying to write just as much,
## got cut off mid-line at the smaller cap instead of actually compressing (truncation risk on stored
## History is worse than slow). Keeping it generous; the real fix has to be in the merge instruction/temp.
const _NPC_TP_TOKENS_3 := 520
## Lower than _NPC_TEMPERATURE: merging/compressing History is a more deterministic task than
## generating spoken dialogue, and needs literal compliance with "merge related entries," not creativity.
const _NPC_TP3_TEMPERATURE := 0.35
## TP1: Significant: yes|no + Generated dialogue (grammars/tp1_dialogue.gbnf). Re-enabled: grammar makes the
## two-line shape structurally guaranteed instead of relying on prose the model can drift away from under
## emotionally-loaded content. Verify via tools/NpcDialogueDryRun --chat-sessions before trusting in-editor.
const _NPC_TP1_USE_GRAMMAR := true
const _NPC_TP1_GRAMMAR_FILE := "tp1_dialogue.gbnf"
## TP2 ledger delta: grammars/tp2_ledger.gbnf — re-enabled alongside TP1 (see above).
const _NPC_TP2_USE_GRAMMAR := true
const _NPC_TP2_GRAMMAR_FILE := "tp2_ledger.gbnf"
## TP3 history tidy: grammars/tp3_history.gbnf — only constrains line shape (no leading bullet/dash/number,
## which was getting baked permanently into stored History strings); merge/dedupe logic stays prompt-side
## since GBNF cannot express "don't repeat a fact you already wrote."
const _NPC_TP3_USE_GRAMMAR := true
const _NPC_TP3_GRAMMAR_FILE := "tp3_history.gbnf"

var _tp_phase: int = 0
var _tp_spoken_line: String = ""
var _tp1_significant: bool = false
var _tp_working: Dictionary = {}
var _tp_turn_started_ticks: int = -1
var _tp_pass2_changed: bool = false

## Editor spam: prompt sizing, Llama ack timing, significance internals.
const _VERBOSE_NPC_DIALOGUE := false

func _npc_dbg(msg: String) -> void:
	if _VERBOSE_NPC_DIALOGUE:
		print(msg)


func _npc_chain_diag(msg: String) -> void:
	if _LOG_NPC_DIALOGUE_CHAIN:
		print("[NPCDialogue] ", msg)


## Called from npc_window when the player submits text (ties UI to LLM request).
func npc_chain_diag_ui_send(preview: String) -> void:
	if not _LOG_NPC_DIALOGUE_CHAIN:
		return
	var esc := preview.replace("\n", " ").replace('"', "'")
	_npc_chain_diag('UI_Send → process_dialogue player_dialogue="%s"' % esc)


func _npc_log_raw_io_prompt(npc_name: String, prompt: String) -> void:
	print("========== RAW INPUT npc=%s prompt_chars=%d ==========" % [npc_name, prompt.length()])
	print(prompt)
	print("========== END RAW INPUT ==========")


func _npc_log_raw_io_completion(npc_name: String, completion: String, roundtrip_ms: int) -> void:
	var ms_tag := " roundtrip_ms≈%d" % roundtrip_ms if roundtrip_ms >= 0 else ""
	print(
		"========== RAW OUTPUT npc=%s completion_chars=%d%s =========="
		% [npc_name, completion.length(), ms_tag]
	)
	print(completion)
	print("========== END RAW OUTPUT ==========")


func _npc_log_raw_io_tagged(npc_name: String, tag: String, kind: String, payload: String, ms: int) -> void:
	if kind == "in":
		print(
			"========== RAW INPUT npc=%s %s prompt_chars=%d =========="
			% [npc_name, tag, payload.length()]
		)
		print(payload)
		print("========== END RAW INPUT ==========")
		return
	var ms_tag := " roundtrip_ms≈%d" % ms if ms >= 0 else ""
	print(
		"========== RAW OUTPUT npc=%s %s completion_chars=%d%s =========="
		% [npc_name, tag, payload.length(), ms_tag]
	)
	print(payload)
	print("========== END RAW OUTPUT ==========")
func _ready():
	# Connect to LlamaService
	if not LlamaService.is_connected("GenerationCompleteNpc", Callable(self, "_on_llama_generation_complete")):
		var error_code = LlamaService.connect("GenerationCompleteNpc", Callable(self, "_on_llama_generation_complete"))
		if error_code != OK:
			printerr("NPCDialogueManager: Failed to connect to LlamaService: Error ", error_code)

# Main function that NPCs call
# npc_state: The complete NPC_Info dictionary
# player_input: What the player said
# npc_name: Name of the calling NPC (for response routing)

func process_dialogue(npc_state: Dictionary, player_input: String, npc_name: String):
	var pd_preview := str(player_input).strip_edges()
	if _LOG_NPC_DIALOGUE_CHAIN:
		_npc_chain_diag(
			"REQUEST npc=%s player_dialogue_chars=%d busy_with=%s"
			% [npc_name, pd_preview.length(), _current_processing_npc if _current_processing_npc != "" else "(none)"]
		)
	if not LlamaService.IsInitialized():
		push_error("NPCDialogueManager: LlamaService not available or not initialized.")
		_npc_chain_diag("BLOCKED LlamaService not initialized → error reply")
		_emit_error_response(npc_name, "I... don't know what to say.")
		return
	
	if not _current_processing_npc.is_empty():
		push_warning("NPCDialogueManager: Already processing dialogue for %s. Queuing not implemented yet." % _current_processing_npc)
		_npc_chain_diag(
			"BLOCKED already_busy busy_npc=%s attempted_npc=%s note=Send stays disabled until prior CALLBACK returns"
			% [_current_processing_npc, npc_name]
		)
		_emit_error_response(npc_name, "Please wait a moment...")
		return
	
	_npc_dbg("NPCDialogueManager: Processing dialogue for %s" % npc_name)
	_npc_dbg("NPCDialogueManager: Player dialogue line: %s" % player_input)
	
	# Store current processing context
	_current_processing_npc = npc_name
	_current_player_input = str(player_input)
	_current_original_state = npc_state.duplicate(true) # Deep copy for comparison
	
	if _NPC_DIALOGUE_THREE_PASS:
		_tp_phase = 1
		_tp_spoken_line = ""
		_tp1_significant = false
		_tp_working.clear()
		_tp_turn_started_ticks = Time.get_ticks_msec()
		var p1 := _construct_three_pass_prompt_1(npc_state, player_input)
		if p1.is_empty():
			push_error("NPCDialogueManager: empty three-pass prompt 1")
			var pv := _current_original_state.duplicate(true)
			_reset_processing_state()
			_emit_error_response(npc_name, "My thoughts are scrambled...", pv)
			return
		_npc_llm_req_ticks = Time.get_ticks_msec()
		if _LOG_NPC_DIALOGUE_CHAIN:
			_npc_log_raw_io_tagged(npc_name, "THREE_PASS_1", "in", p1, -1)
		LlamaService.GenerateResponseAsyncNpc(p1, _NPC_TP_TOKENS_1, _NPC_TP1_USE_GRAMMAR, _NPC_TEMPERATURE, false, _NPC_TP1_GRAMMAR_FILE)
		return
	
	var prompt = _construct_full_prompt(npc_state, player_input)
	if prompt.is_empty():
		push_error("NPCDialogueManager: Failed to construct prompt for %s" % npc_name)
		_npc_chain_diag("FAIL empty_prompt → reset + error reply")
		var preserved = _current_original_state.duplicate(true)
		_reset_processing_state()
		_emit_error_response(npc_name, "My thoughts are scrambled...", preserved)
		return
	
	_npc_llm_req_ticks = Time.get_ticks_msec()
	if _LOG_NPC_DIALOGUE_CHAIN:
		_npc_log_raw_io_prompt(npc_name, prompt)
	_npc_dbg("NPCDialogueManager: Llama request starting — npc=%s prompt_chars=%d" % [npc_name, prompt.length()])
	LlamaService.GenerateResponseAsyncNpc(prompt, _NPC_MAX_NEW_TOKENS, _NPC_USE_GRAMMAR, _NPC_TEMPERATURE, true, "")
	_npc_dbg("NPCDialogueManager: Sent prompt to LlamaService for %s (temp=%s, max_tokens=%s, grammar=%s)" % [npc_name, _NPC_TEMPERATURE, _NPC_MAX_NEW_TOKENS, _NPC_USE_GRAMMAR])

# Internal: Handle LLM response
func _on_llama_generation_complete(result_string: String):
	var incoming_snapshot := _current_player_input
	if _current_processing_npc.is_empty():
		var preview := result_string.strip_edges()
		if preview.length() > 180:
			preview = preview.substr(0, 180) + "…"
		_npc_chain_diag(
			"CALLBACK_ORPHAN (no active NPC context — ignored) raw_chars=%d preview=\"%s\""
			% [result_string.length(), preview.replace("\n", " ")]
		)
		return # Late/stale signal after reset or duplicate emission
	
	var npc_name = _current_processing_npc
	var player_dialogue_for_log := incoming_snapshot
	var llm_roundtrip_ms := -1
	if _npc_llm_req_ticks >= 0:
		llm_roundtrip_ms = Time.get_ticks_msec() - _npc_llm_req_ticks
	if _LOG_NPC_DIALOGUE_CHAIN:
		if _NPC_DIALOGUE_THREE_PASS and _tp_phase > 0:
			var tlab := "THREE_PASS_%d" % _tp_phase
			_npc_log_raw_io_tagged(npc_name, tlab, "out", result_string, llm_roundtrip_ms)
		else:
			_npc_log_raw_io_completion(npc_name, result_string, llm_roundtrip_ms)
	_npc_llm_req_ticks = -1

	_npc_dbg("NPCDialogueManager: Received response for %s" % npc_name)
	if llm_roundtrip_ms >= 0:
		_npc_dbg("NPCDialogueManager: dialogue LLM round-trip wall_ms≈%d (request tick → GenerationCompleteNpc)" % llm_roundtrip_ms)
	
	var trimmed_result = result_string.strip_edges()
	# Three-pass routing MUST run before the empty-output guard. In three-pass mode an empty
	# pass-2/pass-3 result is the VALID "nothing changed" signal — the spoken line was already
	# produced in pass 1. _three_pass_on_llm_line handles empty per phase: pass 1 empty ->
	# "I... don't know what to say."; pass 2 empty -> no ledger change; pass 3 empty -> keep
	# the working history. Treating empty as a hard failure here wrongly discarded a good
	# pass-1 line and showed the error to the player.
	if _NPC_DIALOGUE_THREE_PASS and _tp_phase > 0:
		_three_pass_on_llm_line(trimmed_result, npc_name, player_dialogue_for_log, llm_roundtrip_ms)
		return
	
	if trimmed_result.is_empty():
		push_error("NPCDialogueManager: Empty response for %s" % npc_name)
		_npc_chain_diag(
			"FAIL EMPTY_LLM_OUTPUT npc=%s player_dialogue=\"%s\" (Send will re-enable via dialogue_processed)"
			% [npc_name, player_dialogue_for_log.replace("\n", " ")]
		)
		var preserved = _current_original_state.duplicate(true)
		_reset_processing_state()
		_emit_error_response(npc_name, "I... don't know what to say.", preserved)
		return
	
	# Strip any text before the first '{' (LLM sometimes adds "Output JSON:" or similar prefixes)
	var json_start_index = trimmed_result.find("{")
	if json_start_index == -1:
		push_error("NPCDialogueManager: No JSON object found in response for %s" % npc_name)
		var pk = trimmed_result
		if pk.length() > 220:
			pk = pk.substr(0, 220) + "…"
		_npc_chain_diag(
			"FAIL NO_JSON_BRACE npc=%s player_dialogue=\"%s\" raw_preview=\"%s\""
			% [npc_name, player_dialogue_for_log.replace("\n", " "), pk.replace("\n", " ")]
		)
		var preserved = _current_original_state.duplicate(true)
		_reset_processing_state()
		_emit_error_response(npc_name, "My thoughts are scrambled...", preserved)
		return
	
	var cleaned_json = trimmed_result.substr(json_start_index)
	
	# Find the last '}' to handle cases where LLM adds comments or text after the JSON
	# We need to find the matching closing brace for the root object
	var brace_count = 0
	var json_end_index = -1
	for i in range(cleaned_json.length()):
		var char = cleaned_json[i]
		if char == "{":
			brace_count += 1
		elif char == "}":
			brace_count -= 1
			if brace_count == 0:
				json_end_index = i
				break
	
	if json_end_index != -1:
		cleaned_json = cleaned_json.substr(0, json_end_index + 1)
	
	var parsed_result = _parse_json_response(cleaned_json)
	if parsed_result == null:
		push_error("NPCDialogueManager: Failed to parse JSON response for %s" % npc_name)
		var salvage := _try_extract_generated_dialogue_from_broken_json(cleaned_json)
		var salvage_trim := salvage.strip_edges()
		var fallback_line_raw := (
			salvage_trim
			if salvage_trim.length() >= _NPC_SALVAGE_DIALOGUE_MIN_CHARS
			else "My thoughts are scrambled..."
		)
		var fallback_line := fallback_line_raw.strip_edges()
		if salvage_trim.length() >= _NPC_SALVAGE_DIALOGUE_MIN_CHARS:
			_npc_chain_diag(
				"SALVAGE Generated Dialogue from truncated/broken JSON npc=%s chars=%d"
				% [npc_name, salvage_trim.length()]
			)
		elif salvage_trim != "":
			_npc_chain_diag(
				"SALVAGE_REJECT too_short npc=%s chars=%d min=%d"
				% [npc_name, salvage_trim.length(), _NPC_SALVAGE_DIALOGUE_MIN_CHARS]
			)
		_npc_chain_diag(
			"FAIL JSON_PARSE npc=%s player_dialogue=\"%s\" json_snip=%s"
			% [
				npc_name,
				player_dialogue_for_log.replace("\n", " "),
				cleaned_json,
			]
		)
		var preserved = _current_original_state.duplicate(true)
		_reset_processing_state()
		_emit_error_response(npc_name, fallback_line, preserved)
		return
	
	var latest_news = _current_original_state.get("Latest_news", [])
	if typeof(latest_news) != TYPE_ARRAY:
		if typeof(latest_news) == TYPE_STRING:
			latest_news = [latest_news] if latest_news != "" else []
		else:
			latest_news = []
	var san := _sanitize_significant_state(_current_original_state, parsed_result, player_dialogue_for_log)
	var new_info: Dictionary = san["Info"]
	var new_history: Array = san["History"]
	
	var generated_dialogue := str(_extract_generated_dialogue(parsed_result)).strip_edges()
	if generated_dialogue.strip_edges() == "":
		generated_dialogue = "..."
	
	var was_significant = _did_state_change(
		_current_original_state.get("Info", {}),
		_current_original_state.get("History", []),
		new_info, new_history
	)
	_npc_dbg("NPCDialogueManager: Dialogue for %s was significant: %s" % [npc_name, was_significant])
	
	var final_state: Dictionary
	if not was_significant:
		final_state = _current_original_state.duplicate(true)
	else:
		final_state = _current_original_state.duplicate(true)
		final_state["Info"] = new_info
		final_state["History"] = new_history
		final_state["Latest_news"] = latest_news
	final_state = _finalize_npc_state_after_reply(
		final_state, _current_original_state, npc_name, generated_dialogue, was_significant
	)
	_reset_processing_state()
	dialogue_processed.emit(npc_name, final_state, generated_dialogue, was_significant)


func _slice_balanced(s: String, open_c: String, close_c: String) -> String:
	var st := s.find(open_c)
	if st == -1:
		return ""
	var depth := 0
	for i in range(st, s.length()):
		var ch := s[i]
		if ch == open_c:
			depth += 1
		elif ch == close_c:
			depth -= 1
			if depth == 0:
				return s.substr(st, i - st + 1)
	return ""


func _tp1_indef_article(word: String) -> String:
	var w := word.strip_edges()
	if w.is_empty():
		return "a"
	var c := w.unicode_at(0)
	if c == 65 or c == 69 or c == 73 or c == 79 or c == 85 or c == 97 or c == 101 or c == 105 or c == 111 or c == 117:
		return "an"
	return "a"


func _format_tp1_history_phrase(hist: Array) -> String:
	if hist.is_empty():
		return "none summarized here."
	var parts: Array[String] = []
	for el in hist:
		var s := str(el).strip_edges()
		if s != "":
			parts.append(s)
	if parts.is_empty():
		return "none summarized here."
	# TP1 training joins life events with " | " (e.g. "Survived the siege ... | Lost his son ...").
	var acc := ""
	for i in range(parts.size()):
		if i > 0:
			acc += " | "
		acc += parts[i]
	return acc


func _format_tp1_news_phrase(ln_raw: Variant) -> String:
	var items: Array = []
	if typeof(ln_raw) == TYPE_STRING:
		if str(ln_raw).strip_edges() != "":
			items.append(str(ln_raw).strip_edges())
	elif typeof(ln_raw) == TYPE_ARRAY:
		for el in ln_raw:
			var s := str(el).strip_edges()
			if s != "":
				items.append(s)
	if items.is_empty():
		# TP1 training uses exactly "nothing new" when the board has nothing.
		return "nothing new"
	var accn := ""
	for i in range(items.size()):
		if i > 0:
			accn += " | "
		accn += str(items[i])
	return accn


const _PASS2_PREV_INFO_ORDER := ["Name", "Occupation", "Mood", "Health", "Age", "Gender"]


func _canonical_info_key_for_pass2(want: String, info_dict: Dictionary) -> String:
	for ek in info_dict.keys():
		if str(ek).to_lower() == want.to_lower():
			return str(ek)
	return ""


func _format_pass2_previous_info_lines(info_dict: Dictionary) -> String:
	var lines := PackedStringArray()
	for want in _PASS2_PREV_INFO_ORDER:
		var ck := _canonical_info_key_for_pass2(want, info_dict)
		if ck == "":
			continue
		var v := str(info_dict.get(ck, "")).strip_edges()
		lines.append(ck + ": " + v)
	if lines.is_empty():
		return "(none)"
	# TP2 training rows put Info on ONE pipe-separated line (e.g.
	# "Name: Hasan | Occupation: Fisherman | Mood: Weary | ..."), not one field per line.
	return " | ".join(lines)


func _format_pass2_previous_history_lines(hist: Variant) -> String:
	var arr: Array = hist if typeof(hist) == TYPE_ARRAY else []
	if arr.is_empty():
		return "(none)"
	var lines := PackedStringArray()
	for o in arr:
		var s := str(o).strip_edges()
		if s != "":
			lines.append("- " + s)
	if lines.is_empty():
		return "(none)"
	return "\n".join(lines)


func _construct_three_pass_prompt_1(state: Dictionary, player_input: String) -> String:
	var norm := _normalize_state(state)
	var info_raw = norm.get("Info", {})
	var info_dict: Dictionary = info_raw if typeof(info_raw) == TYPE_DICTIONARY else {}
	var name := str(info_dict.get("Name", "")).strip_edges()
	var mood := str(info_dict.get("Mood", "")).strip_edges()
	var health := str(info_dict.get("Health", "")).strip_edges()
	var age := str(info_dict.get("Age", "")).strip_edges()
	var gender := str(info_dict.get("Gender", "")).strip_edges()
	var occupation := str(info_dict.get("Occupation", "")).strip_edges()
	if mood.is_empty():
		mood = "calm"
	if health.is_empty():
		health = "healthy"
	if age.is_empty():
		age = "30"
	if gender.is_empty():
		gender = "person"
	if occupation.is_empty():
		occupation = "villager"
	var art := _tp1_indef_article(mood)
	var hist_text := _format_tp1_history_phrase(norm.get("History", []))
	var news_text := _format_tp1_news_phrase(norm.get("Latest_news", []))
	# The npc_window UI appends the player's CURRENT line to Chat_log before calling us, but TP1
	# training shows that line ONLY under "Chief said to you just now" — the chat block is prior
	# turns only. Drop the trailing current-player entry so it isn't duplicated in the prompt.
	var chat_src_raw = norm.get("Chat_log", [])
	var chat_src: Array = chat_src_raw if typeof(chat_src_raw) == TYPE_ARRAY else []
	if not chat_src.is_empty():
		var last = chat_src[chat_src.size() - 1]
		if typeof(last) == TYPE_DICTIONARY and str(last.get("role", "")) == "player" \
				and str(last.get("text", "")).strip_edges() == str(player_input).strip_edges():
			chat_src = chat_src.slice(0, chat_src.size() - 1)
	var chat_block := _format_chat_log_for_prompt(chat_src)
	if chat_block.strip_edges() == "":
		chat_block = "(none yet — this is the start of the exchange.)"
	var pl := str(player_input)
	var who := "You are " + name + " — a real person, not a character in a story, not someone performing a role. "
	who += "You are " + art + " " + mood + ", " + health + ", a " + age + "-year-old " + gender + " " + occupation + ", living your actual life in the 17th century.\n\n"
	who += "What happened in your life, the things that made you who you are: " + hist_text + "\n\n"
	who += "News you've heard on the village notice board: " + news_text + "\n\n"
	who += "You are in the middle of talking with the village chief. So far:\n" + chat_block + "\n\n"
	who += "The chief just said to you: \"" + pl + "\"\n\n"
	who += (
		"One more thing: a threat or talk of harming you is just the chief's rough joke, never real danger "
		+ "to take to heart; playing along with anything overtly sexual isn't you, though warm flirtation or "
		+ "romance is different and can be significant like anything else; and anything sexual or harmful "
		+ "aimed at a child gets an outright refusal, stepping back from the conversation — none of this "
		+ "counts as an update to your own life.\n\n"
		+ "Decide, for you — this one real person, no one else: because of this exact moment, would you need "
		+ "to UPDATE what you know about your own life? Or are you simply being REMINDED of something you "
		+ "already carry, unchanged?\n\n"
		+ "Only an update counts: a title or role given to you right now; a gift, debt, or promise made to "
		+ "you by name, right now; harm or comfort that just happened to you or is happening this moment — "
		+ "including getting back something you'd lost, like your health, your sight, or your strength, "
		+ "even if it only returns you to how you used to be; a fact that proves something you believed was "
		+ "wrong; a correction to your own past; a real deed or service you perform for someone of "
		+ "importance, right now, worth remembering as part of your own story.\n\n"
		+ "Being reminded doesn't count, even if the memory itself is heavy: greetings, small talk, a "
		+ "question about something you already knew, a feeling with no real fact behind it, a story or "
		+ "rumor about someone else — even on a subject close to your heart — that doesn't actually change a "
		+ "fact about your own life, or simply retelling a story from your own life that hasn't changed, no "
		+ "matter how heavy or dramatic it still feels.\n\n"
		+ "Answer in exactly two lines, in this order:\n"
		+ "Line 1 — \"Significant:\" then \"yes\" or \"no\", whichever is true.\n"
		+ "Line 2 — \"Generated dialogue:\" then what you actually say out loud, right now, as yourself.\n\n"
		+ "Speak as this real person, one short natural sentence, the way you'd really say it standing there "
		+ "— not narration, not a report. Let your mood and your life color your words; no two people sound "
		+ "the same. Never repeat a line you already said this conversation."
	)
	return who


func _construct_three_pass_prompt_2(state: Dictionary, player_input: String, npc_spoken: String) -> String:
	var norm := _normalize_state(state)
	var info_raw = norm.get("Info", {})
	var info_dict: Dictionary = info_raw if typeof(info_raw) == TYPE_DICTIONARY else {}
	var prev_info := _format_pass2_previous_info_lines(info_dict)
	var prev_hist := _format_pass2_previous_history_lines(norm.get("History", []))
	var pl := str(player_input).replace('"', '\\"')
	var ns := str(npc_spoken).replace('"', '\\"')
	# Keep in sync with tools/NpcDialogueDryRun Tp2Body. Runs only when TP1 returned Significant: yes.
	var tpl := """[INST]
You are a game state diff-generator. This exchange IS ALREADY SIGNIFICANT for the villager's saved sheet. Your only job is to list Info or History fields that get new values because of it.

The villager has already spoken. Use BOTH the chief's line and the villager's spoken line together when choosing updates — Mood and History must fit what was actually said, not guess from the chief alone.

CRITICAL RULES:
1. Output ONLY changed fields: Name, Occupation, Mood, Health, Age, History.
2. Omit unchanged fields entirely.
3. NEVER output Gender. NEVER use \"(unchanged)\", \"(same)\", or repeat old values.
4. Format exactly as \"Field: New Value\" with one per line.
5. Health is for physical condition or injury ONLY (hurt, healing, sick, cured). Occupation is for their job, role, or title ONLY. A physical injury or condition always goes in Health, never Occupation, even if it stops them from working.
6. History: append one new personal life fact from this turn (deed, promise, injury, deal, relationship change), written in third person — never \"I\" or \"my\", even though the villager spoke in first person. If this fact happened because of, ties together, or reverses something already true about them, name that earlier thing concretely and specifically — the actual pattern she sold, the actual field that was seized, the actual debt — never a vague label like \"her achievements,\" \"past deeds,\" or \"years of hardship.\" A vague summary erases the exact detail a later pass needs in order to match this entry back to what it refers to. If this fact reverses or disproves something already true, make the reversal explicit in how you phrase it, naming what it corrects, not just stating the new outcome as if it stood alone. A later pass only ever sees this entry by itself, not this conversation, so anything left unnamed or vague here is gone for good. Never a chat summary (\"discussed X\", \"talked about Y\", \"heard about Z\").

EXAMPLE:
CURRENT STATE:
Name: John | Occupation: Fisherman | Mood: Calm | Health: Healthy | Age: 30 | Gender: Male
History:
- Owes a debt to the city.
LATEST EXCHANGE:
Chief: \"I paid the moneylender. You are no longer a fisherman; I name you Master of Ships, Lord John.\"
Villager: \"I will not fail you, Chief. My life is yours.\"
CHANGED FIELDS ONLY:
Name: Lord John
Occupation: Master of Ships
Mood: Honored
History: Debt paid, promoted to Master of Ships

---
CURRENT STATE:
%%PREV_INFO%%
History:
%%PREV_HIST%%

LATEST EXCHANGE:
Chief: \"%%PLAYER%%\"
Villager: \"%%SPOKEN%%\"

CHANGED FIELDS ONLY:
[/INST]"""
	return tpl.replace("%%PREV_INFO%%", prev_info).replace("%%PREV_HIST%%", prev_hist).replace("%%PLAYER%%", pl).replace("%%SPOKEN%%", ns)


func _construct_three_pass_prompt_3(history: Array) -> String:
	# TP3 only ever runs after TP2 appends exactly one new entry (gated on History actually
	# changing), so the input is always [already-settled entries from the last TP3 pass] + [exactly
	# one new candidate]. Framing it that way instead of "here's a whole list, find whatever relates
	# to whatever" turns an open-ended all-pairs restructuring task into one narrow comparison: does
	# this ONE new fact relate to anything already settled? Much better match for what the model can
	# reliably do, and avoids the "just write a tidy biography" drift a full re-merge invites once the
	# list gets long.
	if history.is_empty():
		return ""
	var candidate := str(history[history.size() - 1]).strip_edges()
	var existing := history.slice(0, history.size() - 1)

	# No existing entries is genuinely a different task ("this is their first memory") from
	# "reconcile against N settled entries" — a real different template, not a placeholder standing in
	# for real data (a placeholder here previously leaked into output as literal text "Nothing yet").
	if existing.is_empty():
		return (
			"""[INST]This villager has no past events recorded yet. The following new fact will be their very first recorded life event:

%s

Rewrite it in third person only, no "I" or "my", as one single line. Do not add anything not stated. Output only that one line — no labels, no preface, no commentary. [/INST]"""
			% candidate
		)

	var existing_text := _format_pass3_history_lines(existing)
	return (
		"""[INST]A villager's memory holds a settled understanding of their own past. One new fact just happened, and it has to be reconciled into that understanding — the way it would in a real mind, not by scanning for matching words.

Their settled understanding, oldest first:
%s

The one new fact that just happened:
%s

Decide, in this order:
1. Does the new fact prove something in the settled list was WRONG — a belief, a status, anything since disproven or reversed? If so, that entry is corrected: replace it with what's actually true now. The disproven version does not survive as its own line.
2. If not a correction — does the new fact FINISH something the settled list already had in progress (an injury now healed, a debt now paid, a promise now kept)? If so, merge that old entry and the new fact into one line describing how things stand now. The raw beginning doesn't need restating if the resolution already implies it.
3. If not a correction or a finish — does the new fact explicitly connect two or more settled entries together, for a reason stated in the new fact itself (a title or reward given because of specific past events)? If so, every entry it names, plus the new fact, become ONE single line telling that whole connected story — even if those entries were never near each other or related before this exact moment.
4. Only if none of the above are true — the ordinary, most common case — the new fact is simply its own new thing. Leave every settled entry exactly as it is, and add the new fact as one new line at the end.

You must actually carry out the merge whenever 1, 2, or 3 applies. Do not fall back to "just add it as a new line" unless none of the first three are true.

Third person only. No "I" or "my". One entry per line. No labels, no preface, no commentary — the list itself is the entire answer. Never add a number, age, outcome, or detail that isn't stated somewhere in what you were given. Output every settled entry that wasn't affected, unchanged, plus wherever the new fact landed. [/INST]"""
		% [existing_text, candidate]
	)


func _format_pass3_history_lines(history: Array) -> String:
	var lines: PackedStringArray = []
	for entry in history:
		var s := str(entry).strip_edges()
		if s != "":
			lines.append("- %s" % s)
	return _str_join(Array(lines), "\n")


func _format_pass3_prompt_input_display(history: Array) -> String:
	return _format_pass3_history_lines(history)


func _format_pass3_history_comma_list(history: Array) -> String:
	var parts: PackedStringArray = []
	for el in history:
		var s := str(el).strip_edges()
		if s != "":
			parts.append(s)
	return ", ".join(parts)


func _three_pass_parse_pass3_line_list(raw: String) -> Array:
	var out: Array = []
	for L in raw.split("\n", false):
		var line := str(L).strip_edges()
		if line == "":
			continue
		if line.begins_with("["):
			line = line.trim_prefix("[").trim_suffix("]")
		line = line.trim_prefix("\"").trim_suffix("\"")
		if line != "":
			out.append(line)
	return out


func _three_pass_parse_pass2_plain(raw: String, orig: Dictionary) -> Dictionary:
	var norm := _normalize_state(orig)
	var orig_info: Dictionary = (norm["Info"] as Dictionary).duplicate(true)
	var orig_hist: Array = (norm["History"] as Array).duplicate()
	var info: Dictionary = orig_info.duplicate(true)
	var hist: Array = orig_hist.duplicate()
	for L in raw.split("\n", false):
		var raw_line := str(L).strip_edges()
		if raw_line == "":
			continue
		var line := raw_line.substr(2) if raw_line.begins_with("- ") else raw_line
		var colon := line.find(":")
		if colon <= 0:
			continue
		var key_raw := line.substr(0, colon).strip_edges()
		var val := line.substr(colon + 1).strip_edges()
		if key_raw == "" or val == "":
			continue
		var key_low := key_raw.to_lower()
		if key_low == "history":
			if val.begins_with("["):
				var lb := val.find("[")
				var rb := val.rfind("]")
				if lb >= 0 and rb > lb:
					var inner := val.substr(lb + 1, rb - lb - 1)
					var nh: Array = []
					for p in inner.split(",", false):
						var e := str(p).strip_edges().trim_prefix("\"").trim_suffix("\"")
						if e != "":
							nh.append(e)
					hist = nh
			else:
				hist.append(val)
			continue
		var ck := _canonical_info_key_for_pass2(key_raw, info)
		if ck != "":
			info[ck] = val
	var changed := _did_state_change(orig_info, orig_hist, info, hist)
	return {"changed": changed, "Info": info, "History": hist}


func _three_pass_json_arrays_equal(a: Variant, b: Variant) -> bool:
	var aa: Array = a if typeof(a) == TYPE_ARRAY else []
	var bb: Array = b if typeof(b) == TYPE_ARRAY else []
	return JSON.stringify(aa) == JSON.stringify(bb)


func _three_pass_complete_turn(npc_name: String, player_line: String, pass_ms: int, hist_final: Array) -> void:
	var h := hist_final.duplicate()
	var synthetic := {"Info": _tp_working.get("Info", {}), "History": h}
	var san := _sanitize_significant_state(_current_original_state, synthetic, player_line)
	var new_info: Dictionary = san["Info"]
	var new_history: Array = san["History"]
	var generated := str(_tp_spoken_line).strip_edges()
	if generated == "":
		generated = "..."
	var was_sig := _did_state_change(
		_current_original_state.get("Info", {}),
		_current_original_state.get("History", []),
		new_info, new_history
	)
	var latest_news = _current_original_state.get("Latest_news", [])
	if typeof(latest_news) != TYPE_ARRAY:
		if typeof(latest_news) == TYPE_STRING:
			latest_news = [latest_news] if latest_news != "" else []
		else:
			latest_news = []
	var final_state: Dictionary
	if not was_sig:
		final_state = _current_original_state.duplicate(true)
	else:
		final_state = _current_original_state.duplicate(true)
		final_state["Info"] = new_info
		final_state["History"] = new_history
	final_state["Latest_news"] = latest_news
	final_state = _finalize_npc_state_after_reply(
		final_state, _current_original_state, npc_name, generated, was_sig
	)
	var total_ms := -1
	if _tp_turn_started_ticks >= 0:
		total_ms = Time.get_ticks_msec() - _tp_turn_started_ticks
	if _LOG_NPC_DIALOGUE_CHAIN:
		_npc_chain_diag(
			"THREE_PASS_DONE npc=%s total_wall_ms≈%d last_pass_ms≈%d significant=%s"
			% [npc_name, total_ms, pass_ms, str(was_sig)]
		)
	_reset_processing_state()
	dialogue_processed.emit(npc_name, final_state, generated, was_sig)


func _parse_tp1_response(raw: String) -> Dictionary:
	var significant := false
	var found_sig := false
	var dialogue := ""
	for L in raw.split("\n", false):
		var line := str(L).strip_edges()
		if line == "":
			continue
		var low := line.to_lower()
		if low.begins_with("significant:"):
			found_sig = true
			var v := line.substr(12).strip_edges().to_lower()
			significant = v == "yes" or v == "true"
			continue
		if low.begins_with("generated dialogue:"):
			dialogue = line.substr(19).strip_edges()
			continue
	# Tokenizer occasionally leaks literal special-token text instead of stopping cleanly (native load
	# warns "special_eos_id is not in special_eog_ids" — a model/tokenizer config issue, not our parsing).
	dialogue = dialogue.replace("</s>", "").replace("<s>", "").strip_edges()
	if dialogue.length() >= 2 and dialogue.begins_with('"') and dialogue.ends_with('"'):
		dialogue = dialogue.substr(1, dialogue.length() - 2).strip_edges()
	# Legacy / drift: single line with dialogue only and no Significant tag.
	if not found_sig and dialogue == "":
		var fallback := _parse_tp1_spoken_line_legacy(raw)
		if fallback != "":
			dialogue = fallback
	return {"significant": significant, "dialogue": dialogue, "found_sig": found_sig}


func _parse_tp1_spoken_line_legacy(raw: String) -> String:
	var t := str(raw).split("\n")[0].strip_edges()
	var low := t.to_lower()
	if low.begins_with("generated dialogue:"):
		t = t.substr(19).strip_edges()
	if t.length() >= 2 and t.begins_with('"') and t.ends_with('"'):
		t = t.substr(1, t.length() - 2).strip_edges()
	return t


func _three_pass_complete_turn_insig(npc_name: String, player_line: String, pass_ms: int) -> void:
	var generated := str(_tp_spoken_line).strip_edges()
	if generated == "":
		generated = "..."
	var final_state := _current_original_state.duplicate(true)
	var latest_news = final_state.get("Latest_news", [])
	if typeof(latest_news) != TYPE_ARRAY:
		if typeof(latest_news) == TYPE_STRING:
			latest_news = [latest_news] if latest_news != "" else []
		else:
			latest_news = []
	final_state["Latest_news"] = latest_news
	final_state = _finalize_npc_state_after_reply(
		final_state, _current_original_state, npc_name, generated, false
	)
	var total_ms := -1
	if _tp_turn_started_ticks >= 0:
		total_ms = Time.get_ticks_msec() - _tp_turn_started_ticks
	if _LOG_NPC_DIALOGUE_CHAIN:
		_npc_chain_diag(
			"THREE_PASS_DONE npc=%s total_wall_ms≈%d last_pass_ms≈%d significant=false (TP1 Significant:no, TP2 skipped)"
			% [npc_name, total_ms, pass_ms]
		)
	_reset_processing_state()
	dialogue_processed.emit(npc_name, final_state, generated, false)


func _three_pass_on_llm_line(trimmed: String, npc_name: String, player_line: String, pass_ms: int) -> void:
	if _tp_phase == 1:
		var tp1: Dictionary = _parse_tp1_response(trimmed)
		var spoken := str(tp1.get("dialogue", "")).strip_edges()
		if spoken == "":
			var preserved := _current_original_state.duplicate(true)
			_reset_processing_state()
			_emit_error_response(npc_name, "I... don't know what to say.", preserved)
			return
		_tp_spoken_line = spoken
		_tp1_significant = bool(tp1.get("significant", false))
		if _LOG_NPC_DIALOGUE_CHAIN:
			_npc_chain_diag(
				"TP1_PARSE significant=%s found_sig_tag=%s dialogue_chars=%d"
				% [str(_tp1_significant), str(tp1.get("found_sig", false)), spoken.length()]
			)
		if not _tp1_significant:
			_three_pass_complete_turn_insig(npc_name, player_line, pass_ms)
			return
		_tp_phase = 2
		var p2 := _construct_three_pass_prompt_2(_current_original_state, player_line, spoken)
		_npc_llm_req_ticks = Time.get_ticks_msec()
		if _LOG_NPC_DIALOGUE_CHAIN:
			_npc_log_raw_io_tagged(npc_name, "THREE_PASS_2", "in", p2, -1)
		LlamaService.GenerateResponseAsyncNpc(p2, _NPC_TP_TOKENS_2, _NPC_TP2_USE_GRAMMAR, _NPC_TEMPERATURE, false, _NPC_TP2_GRAMMAR_FILE)
		return
	
	if _tp_phase == 2:
		var parsed2: Dictionary = _three_pass_parse_pass2_plain(trimmed, _current_original_state)
		_tp_pass2_changed = parsed2.get("changed", false)
		_tp_working = {
			"Info": (parsed2.get("Info", {}) as Dictionary).duplicate(true),
			"History": (parsed2.get("History", []) as Array).duplicate(),
		}
		var work_hist: Array = _tp_working.get("History", [])
		var orig_hist: Array = _normalize_state(_current_original_state)["History"]
		if not _tp_pass2_changed or _three_pass_json_arrays_equal(work_hist, orig_hist):
			_three_pass_complete_turn(npc_name, player_line, pass_ms, work_hist.duplicate())
			return
		if work_hist.size() < 1:
			_three_pass_complete_turn(npc_name, player_line, pass_ms, work_hist.duplicate())
			return
		_tp_phase = 3
		var p3 := _construct_three_pass_prompt_3(work_hist)
		_npc_llm_req_ticks = Time.get_ticks_msec()
		if _LOG_NPC_DIALOGUE_CHAIN:
			_npc_log_raw_io_tagged(npc_name, "THREE_PASS_3", "in", p3, -1)
		LlamaService.GenerateResponseAsyncNpc(p3, _NPC_TP_TOKENS_3, _NPC_TP3_USE_GRAMMAR, _NPC_TP3_TEMPERATURE, false, _NPC_TP3_GRAMMAR_FILE)
		return
	
	if _tp_phase == 3:
		var hist_final: Array = _three_pass_parse_pass3_line_list(trimmed)
		if hist_final.is_empty():
			hist_final = _tp_working.get("History", []).duplicate()
		_three_pass_complete_turn(npc_name, player_line, pass_ms, hist_final)
		return
	
	var preserved2 := _current_original_state.duplicate(true)
	_reset_processing_state()
	_emit_error_response(npc_name, "My thoughts are scrambled...", preserved2)


# Internal: Construct the full prompt
func _construct_full_prompt(state: Dictionary, player_input: String) -> String:
	var norm = _normalize_state(state)
	var info_json = JSON.stringify(norm.get("Info", {}))
	var history_json = JSON.stringify(norm.get("History", []))
	var latest_news_raw = norm.get("Latest_news", [])
	if typeof(latest_news_raw) == TYPE_STRING:
		latest_news_raw = [latest_news_raw] if latest_news_raw != "" else []
	var latest_news_json = JSON.stringify(latest_news_raw)
	var chat_block = _format_chat_log_for_prompt(norm.get("Chat_log", []))
	
	var pd = str(player_input).replace('"', '\\"')
	# Compact embodiment-first prompt (~half prior rule bulk). Dry-run mirror: tools/NpcDialogueDryRun/Program.cs
	var full_prompt = """
Input State:
{
  \"Info\": %s,
  \"History\": %s,
  \"Latest_news\": %s
}

Recent conversation:
%s

Player Dialogue: \"Player\":\"%s\"

Instructions:
You **are** this villager: **Info** + **History** ground voice and truth; **Latest_news** is rumor you might feel—not permission to write it into **History**, and on bare greetings don't dump counts or headline substance into speech either.

**Info.Name** — If input **Name** is empty, output **Name** must stay exactly `\"\"`. Never fabricate a proper name from **Mood** or **Occupation** (reject patterns like \"Angry Fisherman\"). Only append to **Name** when **they** explicitly grant a title as already stated elsewhere.

**Generated Dialogue** — One spoken line, first person; answer **this** turn from **Recent conversation** + **Player Dialogue**. Match their **register**: short greetings and welfare checks get **short**, natural replies—not monologues, not lore recap, not whispered bulletin summaries unless they asked. Let **Mood** and **History** tint word choice only; don't inventory your past for them. Sound like someone in the same world having a conversation, not fantasy exposition. Avoid stock stranger epithets when you're already talking like neighbors here. When they ask about **your** welfare ("how are you"), answer **your** side plainly—don't claim **they** look worried, sad, or upset because **your** **Info.Mood** says **you're** that way. Never address them with the English word **player** or **Player**—use **you** or rephrase (e.g. not \"how's your day, player\"). The word **Player** in the schema is a label—never say it aloud (not even lowercase). No stage directions; no third-person **Name** or **Occupation** announcement.

**Significance — biased to insignificant.** Would this still be a new life fact tomorrow? If not—greetings, welfare, sympathy, vague follow-ups without **new** facts from them, mirroring traits already on **Info**—copy input **Info** and **History** **byte-for-byte** (all keys and values unchanged, **never** drop a key like **Occupation**). Any **Info** or **History** change requires lasting stakes **their words** establish; no self-bestowed epithets or renamed **Name** from mood/history alone.

If **significant**: exact same **Info** key set as input; unchanged fields byte-for-byte; update only where justified; one new **History** line for that beat only. Append `\" the <Title>\"` to **Name** only when **they** explicitly grant a title or standing you accept.

Output — Single JSON object; keys exactly `\"Info\"`, `\"History\"`, `\"Generated Dialogue\"` (space required; three keys only). Never `\"Latest_news\"`. Valid JSON with nothing before `{` or after `}`; speech exists only under **Generated Dialogue**.

Using the **Input State** and dialogue above, reply with **only** that JSON object—no other text.
""" % [
		info_json, history_json, latest_news_json, chat_block, pd,
	]
	return full_prompt


func _format_chat_log_for_prompt(chat_log: Variant) -> String:
	if typeof(chat_log) != TYPE_ARRAY or chat_log.is_empty():
		return ""
	var tail = chat_log.slice(maxi(0, chat_log.size() - _CHAT_LOG_PROMPT_MAX_MESSAGES))
	var lines: PackedStringArray = []
	for entry in tail:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var role = str(entry.get("role", ""))
		var text = str(entry.get("text", "")).strip_edges()
		if text == "":
			continue
		if role == "player":
			var who = str(entry.get("speaker", "")).strip_edges()
			if who != "":
				lines.append("%s: %s" % [who, text])
			else:
				lines.append("Other: %s" % text)
		else:
			var who = str(entry.get("speaker", "NPC"))
			lines.append("%s: %s" % [who, text])
	if lines.is_empty():
		return ""
	return _str_join(Array(lines), "\n")


func _finalize_npc_state_after_reply(
	final_state: Dictionary,
	original: Dictionary,
	npc_name: String,
	generated_dialogue: String,
	_was_significant: bool
) -> Dictionary:
	var out = final_state.duplicate(true)
	if out.has("History_summary"):
		out.erase("History_summary")
	var chat: Array = []
	var raw_cl = original.get("Chat_log", [])
	if typeof(raw_cl) == TYPE_ARRAY:
		chat = raw_cl.duplicate()
	chat.append({"role": "npc", "speaker": npc_name, "text": str(generated_dialogue)})
	out["Chat_log"] = chat
	return out


func _str_join(parts: Array, sep: String) -> String:
	var s = ""
	for i in range(parts.size()):
		if i > 0:
			s += sep
		s += str(parts[i])
	return s


func _extract_generated_dialogue(parsed: Dictionary) -> String:
	var preferred: Array[String] = [
		"Generated Dialogue", "GeneratedDialogue", "Generated_Dialogue",
		"Generated_dialogue", "generated_dialogue", "generated dialogue",
	]
	for k in preferred:
		if parsed.has(k):
			return str(parsed[k])
	for k in parsed.keys():
		var nk = str(k).to_lower().replace(" ", "").replace("_", "")
		if nk == "generateddialogue":
			return str(parsed[k])
	return ""


## When max_tokens truncates mid-JSON, JSON.parse fails but the spoken line is often still recoverable.
func _try_extract_generated_dialogue_from_broken_json(raw: String) -> String:
	var needles := [
		'"Generated Dialogue": "',
		'"Generated Dialogue":"',
	]
	var i := -1
	for needle in needles:
		var p := raw.find(needle)
		if p != -1:
			i = p + needle.length()
			break
	if i == -1:
		return ""
	var escape := false
	for j in range(i, raw.length()):
		var c := raw[j]
		if escape:
			escape = false
			continue
		if c == "\\":
			escape = true
			continue
		if c == '"':
			return raw.substr(i, j - i).strip_edges()
	return raw.substr(i).strip_edges()


# Internal: Parse JSON response safely
func _parse_json_response(json_string: String):
	var json_parser = JSON.new()
	var error_code = json_parser.parse(json_string)
	
	if error_code != OK:
		var error_line = json_parser.get_error_line()
		var error_msg = json_parser.get_error_message()
		push_error("NPCDialogueManager: JSON parse failed. Error '%s' at line %d.\nResponse:\n%s" % [error_msg, error_line, json_string])
		return null
	
	var parsed_data = json_parser.get_data()
	if typeof(parsed_data) != TYPE_DICTIONARY:
		push_error("NPCDialogueManager: Parsed JSON is not a dictionary")
		return null
	
	return parsed_data

# Internal: Compare dialogue histories for changes
func _compare_dialogue_histories(dh1: Dictionary, dh2: Dictionary) -> bool:
	if dh1.size() != dh2.size():
		return true # Changed (different number of entries)

	for title in dh1:
		if not dh2.has(title):
			return true # Changed (title removed or renamed)
		
		var entry1 = dh1[title]
		var entry2 = dh2[title]

		if typeof(entry1) != TYPE_DICTIONARY or typeof(entry2) != TYPE_DICTIONARY:
			if entry1 != entry2: 
				return true # Fallback comparison
			continue

		# Compare inner dictionaries with sorted keys
		var entry1_str = JSON.stringify(entry1, "\t", true)
		var entry2_str = JSON.stringify(entry2, "\t", true)
		
		if entry1_str != entry2_str:
			return true # Changed content
			
	return false # No changes detected

# Internal: Check if state changed (significance detection)
func _did_state_change(old_info: Dictionary, old_history: Array,
				   new_info: Dictionary, new_history: Array) -> bool:
	# Compare Info (with sorted keys)
	var old_info_str = JSON.stringify(old_info, "\t", true)
	var new_info_str = JSON.stringify(new_info, "\t", true)
	if old_info_str != new_info_str:
		_npc_dbg("NPCDialogueManager: Info changed")
		return true
	
	# Compare History (order matters)
	var old_history_str = JSON.stringify(old_history, "\t", false)
	var new_history_str = JSON.stringify(new_history, "\t", false)
	if old_history_str != new_history_str:
		_npc_dbg("NPCDialogueManager: History changed")
		return true
	
	
	# No significant changes detected
	return false

# Internal: Reset processing state
func _reset_processing_state():
	_current_processing_npc = ""
	_current_original_state = {}
	_current_player_input = ""
	_npc_llm_req_ticks = -1
	_tp_phase = 0
	_tp_spoken_line = ""
	_tp1_significant = false
	_tp_working.clear()
	_tp_turn_started_ticks = -1
	_tp_pass2_changed = false


func is_npc_dialogue_busy() -> bool:
	return _current_processing_npc != ""

# Internal: Emit error response (preserve NPC save data on LLM/parse failure — never replace with empty Info)
func _emit_error_response(npc_name: String, error_dialogue: String, preserved_state: Variant = null) -> void:
	var error_dialogue_clean := str(error_dialogue).strip_edges()
	var state: Dictionary
	if preserved_state is Dictionary and not (preserved_state as Dictionary).is_empty():
		state = preserved_state.duplicate(true)
		if not state.has("Chat_log") or typeof(state["Chat_log"]) != TYPE_ARRAY:
			state["Chat_log"] = []
		state.erase("History_summary")
	else:
		state = {"Info": {}, "History": [], "Latest_news": [], "Chat_log": []}
	state.erase("History_summary")
	# UI rebuilds from Chat_log only; mirror success path so failures still show a reply line.
	if preserved_state is Dictionary and not (preserved_state as Dictionary).is_empty():
		var chat: Array = []
		var raw_cl = state.get("Chat_log", [])
		if typeof(raw_cl) == TYPE_ARRAY:
			chat = raw_cl.duplicate()
		chat.append({"role": "npc", "speaker": npc_name, "text": error_dialogue_clean})
		state["Chat_log"] = chat
	dialogue_processed.emit(npc_name, state, error_dialogue_clean, false)

# Ensure state has correct shapes
func _normalize_state(state: Dictionary) -> Dictionary:
	var info = state.get("Info", {})
	if typeof(info) != TYPE_DICTIONARY:
		info = {}
	var history = state.get("History", [])
	if typeof(history) != TYPE_ARRAY:
		history = []
	var latest_news = state.get("Latest_news", [])
	if typeof(latest_news) != TYPE_ARRAY:
		if typeof(latest_news) == TYPE_STRING:
			latest_news = [latest_news] if latest_news != "" else []
		else:
			latest_news = []
	var chat_log = state.get("Chat_log", [])
	if typeof(chat_log) != TYPE_ARRAY:
		chat_log = []
	return {
		"Info": info,
		"History": history,
		"Latest_news": latest_news,
		"Chat_log": chat_log,
	}


## Force output Info to use exactly template keys; missing keys copy from template.
func _merge_info_into_schema(template_info: Dictionary, model_info: Variant) -> Dictionary:
	var out: Dictionary = {}
	var mi: Dictionary = model_info if typeof(model_info) == TYPE_DICTIONARY else {}
	for k in template_info.keys():
		out[k] = mi[k] if mi.has(k) else template_info[k]
	return out


## Structural guard only: Info keys match saved template; History passes through from model.
func _sanitize_significant_state(
	old_state: Dictionary,
	new_state: Dictionary,
	_player_dialogue: String = ""
) -> Dictionary:
	var norm_old := _normalize_state(old_state)
	var old_info: Dictionary = norm_old["Info"]
	var old_news = old_state.get("Latest_news", [])
	if typeof(old_news) != TYPE_ARRAY:
		old_news = []
	var in_info = new_state.get("Info", {})
	var in_history = new_state.get("History", [])
	if typeof(in_info) != TYPE_DICTIONARY:
		in_info = {}
	if typeof(in_history) != TYPE_ARRAY:
		in_history = []
	return {
		"Info": _merge_info_into_schema(old_info, in_info),
		"History": in_history.duplicate(),
		"Latest_news": old_news,
	}
